-- ECE 520/L Lab 4: 32-bit AXI4-Lite slave for the Lab 3 VHDL FIFO.
-- 16 register slots (0x00 through 0x3C). Compliant independent AW/W handshakes.
-- A FIFO write/read/reset request generates exactly one clock-wide pulse.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fifo_math_pkg.all;

entity sc_fifo_axi_v1_0_S00_AXI is
    generic (
        C_S_AXI_DATA_WIDTH          : integer := 32;
        C_S_AXI_ADDR_WIDTH          : integer := 6;
        FIFO_WIDTH                  : positive := 16;
        FIFO_DEPTH                  : positive := 32;
        FIFO_ALMOST_EMPTY_THRESHOLD : natural := 1;
        FIFO_ALMOST_FULL_THRESHOLD  : natural := 31;
        FIFO_READ_LATENCY           : positive := 1
    );
    port (
        S_AXI_ACLK    : in  std_logic;
        S_AXI_ARESETN : in  std_logic;
        S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
        S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_AWVALID : in  std_logic;
        S_AXI_AWREADY : out std_logic;
        S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
        S_AXI_WSTRB   : in  std_logic_vector(C_S_AXI_DATA_WIDTH/8 - 1 downto 0);
        S_AXI_WVALID  : in  std_logic;
        S_AXI_WREADY  : out std_logic;
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in  std_logic;
        S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
        S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
        S_AXI_ARVALID : in  std_logic;
        S_AXI_ARREADY : out std_logic;
        S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in  std_logic
    );
end entity sc_fifo_axi_v1_0_S00_AXI;

architecture rtl of sc_fifo_axi_v1_0_S00_AXI is
    -- The fixed Lab 4 register map is 32-bit wide.
    constant REG_REV       : natural := 0;
    constant REG_FIFO_RST  : natural := 1;
    constant REG_WR_DATA   : natural := 2;
    constant REG_RD_REQ    : natural := 3;
    constant REG_RD_DATA   : natural := 4;
    constant REG_STATUS    : natural := 5;
    constant REG_COUNT     : natural := 6;
    constant REG_CONFIG    : natural := 7;
    constant REG_THRESHOLD : natural := 8;

    -- This function prevents the upper bits of a 64K AXI aperture aliasing
    -- the first 16 registers. Misaligned/unknown offsets read 0 and ignore writes.
    function decode_reg(addr : std_logic_vector) return integer is
    begin
        if addr(1 downto 0) /= "00" then
            return -1;
        end if;
        -- At 6-bit AXI address width the entire range is 0x00..0x3F.
        -- For wider addresses, offsets >= 0x40 must NOT alias lower regs.
        if addr'length > 6 then
            for bit_num in 6 to addr'left loop
                if addr(bit_num) /= '0' then
                    return -1;
                end if;
            end loop;
        end if;
        return to_integer(unsigned(addr(5 downto 2)));
    end function;

    constant FIFO_CONFIG_VALUE : std_logic_vector(31 downto 0) :=
        "0000" & std_logic_vector(to_unsigned(FIFO_READ_LATENCY, 4)) &
        std_logic_vector(to_unsigned(FIFO_DEPTH, 16)) &
        std_logic_vector(to_unsigned(FIFO_WIDTH, 8));
    constant FIFO_THRESHOLD_VALUE : std_logic_vector(31 downto 0) :=
        std_logic_vector(to_unsigned(FIFO_ALMOST_FULL_THRESHOLD, 16)) &
        std_logic_vector(to_unsigned(FIFO_ALMOST_EMPTY_THRESHOLD, 16));

    signal aw_pending    : std_logic := '0';
    signal w_pending     : std_logic := '0';
    signal awaddr_hold   : std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal wdata_hold    : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal wstrb_hold    : std_logic_vector(C_S_AXI_DATA_WIDTH/8 - 1 downto 0) := (others => '0');
    signal bvalid_reg    : std_logic := '0';
    signal rvalid_reg    : std_logic := '0';
    signal rdata_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal awready_int   : std_logic;
    signal wready_int    : std_logic;
    signal arready_int   : std_logic;

    signal fifo_din      : std_logic_vector(FIFO_WIDTH - 1 downto 0) := (others => '0');
    signal fifo_dout     : std_logic_vector(FIFO_WIDTH - 1 downto 0);
    signal fifo_count    : std_logic_vector(clog2(FIFO_DEPTH + 1) - 1 downto 0);
    signal fifo_full     : std_logic;
    signal fifo_empty    : std_logic;
    signal fifo_afull    : std_logic;
    signal fifo_aempty   : std_logic;
    signal fifo_valid    : std_logic;
    signal fifo_rst_pulse : std_logic := '0';
    signal fifo_wr_pulse  : std_logic := '0';
    signal fifo_rd_pulse  : std_logic := '0';
    signal fifo_srst      : std_logic;
    signal fifo_read_data : std_logic_vector(FIFO_WIDTH - 1 downto 0) := (others => '0');
    signal fifo_rd_valid  : std_logic := '0';

begin
    assert C_S_AXI_DATA_WIDTH = 32 report "AXI data width must be 32." severity failure;
    assert C_S_AXI_ADDR_WIDTH >= 6 report "AXI address width must be >= 6." severity failure;
    assert FIFO_WIDTH <= 32 report "FIFO_WIDTH must be <= 32." severity failure;
    assert FIFO_DEPTH <= 65535 report "FIFO_DEPTH must fit CONFIG_REG." severity failure;
    assert FIFO_READ_LATENCY <= 8 report "Read latency must be <= 8." severity failure;

    -- AW and W may arrive in different cycles. They are buffered separately.
    awready_int <= '1' when aw_pending = '0' and bvalid_reg = '0' else '0';
    wready_int  <= '1' when w_pending  = '0' and bvalid_reg = '0' else '0';
    arready_int <= '1' when rvalid_reg = '0' else '0';

    S_AXI_AWREADY <= awready_int;
    S_AXI_WREADY  <= wready_int;
    S_AXI_BVALID  <= bvalid_reg;
    S_AXI_BRESP   <= "00";  -- OKAY
    S_AXI_ARREADY <= arready_int;
    S_AXI_RVALID  <= rvalid_reg;
    S_AXI_RRESP   <= "00";  -- OKAY
    S_AXI_RDATA   <= rdata_reg;

    -- FIFO reset is synchronous inside sc_fifo; the global AXI reset
    -- is also presented as an active-high FIFO reset.
    fifo_srst <= (not S_AXI_ARESETN) or fifo_rst_pulse;

    fifo_inst : entity work.sc_fifo
        generic map (
            WIDTH                  => FIFO_WIDTH,
            DEPTH                  => FIFO_DEPTH,
            ALMOST_EMPTY_THRESHOLD => FIFO_ALMOST_EMPTY_THRESHOLD,
            ALMOST_FULL_THRESHOLD  => FIFO_ALMOST_FULL_THRESHOLD,
            READ_LATENCY           => FIFO_READ_LATENCY
        )
        port map (
            CLK => S_AXI_ACLK,
            SRST => fifo_srst,
            DIN => fifo_din,
            WR_EN => fifo_wr_pulse,
            RD_EN => fifo_rd_pulse,
            DOUT => fifo_dout,
            FULL => fifo_full,
            EMPTY => fifo_empty,
            ALMOST_FULL => fifo_afull,
            ALMOST_EMPTY => fifo_aempty,
            VALID => fifo_valid,
            DATA_COUNT => fifo_count
        );

    -- AXI write logic and FIFO read-result capture.
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                aw_pending <= '0';
                w_pending <= '0';
                awaddr_hold <= (others => '0');
                wdata_hold <= (others => '0');
                wstrb_hold <= (others => '0');
                bvalid_reg <= '0';
                fifo_din <= (others => '0');
                fifo_rst_pulse <= '0';
                fifo_wr_pulse <= '0';
                fifo_rd_pulse <= '0';
                fifo_read_data <= (others => '0');
                fifo_rd_valid <= '0';
            else
                -- Self-clearing one-clock pulses.
                fifo_rst_pulse <= '0';
                fifo_wr_pulse <= '0';
                fifo_rd_pulse <= '0';

                -- Latch any new AXI write address and data independently.
                if S_AXI_AWVALID = '1' and awready_int = '1' then
                    awaddr_hold <= S_AXI_AWADDR;
                    aw_pending <= '1';
                end if;
                if S_AXI_WVALID = '1' and wready_int = '1' then
                    wdata_hold <= S_AXI_WDATA;
                    wstrb_hold <= S_AXI_WSTRB;
                    w_pending <= '1';
                end if;

                -- Process exactly one command after collecting both channels.
                if aw_pending = '1' and w_pending = '1' and bvalid_reg = '0' then
                    case decode_reg(awaddr_hold) is
                        when REG_FIFO_RST =>
                            if wstrb_hold(0) = '1' and wdata_hold(0) = '1' then
                                fifo_rst_pulse <= '1';
                            end if;
                        when REG_WR_DATA =>
                            -- Byte strobes are honored; any asserted byte lane
                            -- is one FIFO push. Disabled byte lanes are zeroed.
                            if unsigned(wstrb_hold) /= 0 then
                                for bit_num in 0 to FIFO_WIDTH - 1 loop
                                    if wstrb_hold(bit_num/8) = '1' then
                                        fifo_din(bit_num) <= wdata_hold(bit_num);
                                    else
                                        fifo_din(bit_num) <= '0';
                                    end if;
                                end loop;
                                fifo_wr_pulse <= '1';
                            end if;
                        when REG_RD_REQ =>
                            if wstrb_hold(0) = '1' and wdata_hold(0) = '1' then
                                fifo_rd_pulse <= '1';
                                fifo_rd_valid <= '0';
                            end if;
                        when others =>
                            null;  -- All read-only and reserved registers ignore writes.
                    end case;
                    aw_pending <= '0';
                    w_pending <= '0';
                    bvalid_reg <= '1';
                elsif bvalid_reg = '1' and S_AXI_BREADY = '1' then
                    bvalid_reg <= '0';
                end if;

                -- valid from sc_fifo is delayed by READ_LATENCY clocks.
                -- Capture only when valid; reading RD_DATA does not pop.
                if fifo_valid = '1' then
                    fifo_read_data <= fifo_dout;
                    fifo_rd_valid <= '1';
                end if;
                -- Reset has priority over a coincident old valid pulse.
                if fifo_rst_pulse = '1' then
                    fifo_read_data <= (others => '0');
                    fifo_rd_valid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- AXI read response. A captured result stays stable until RREADY.
    process (S_AXI_ACLK)
        variable rd_value : std_logic_vector(31 downto 0);
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                rvalid_reg <= '0';
                rdata_reg <= (others => '0');
            else
                if S_AXI_ARVALID = '1' and arready_int = '1' then
                    rd_value := (others => '0');
                    case decode_reg(S_AXI_ARADDR) is
                        when REG_REV =>
                            rd_value := x"52000004";
                        when REG_RD_DATA =>
                            rd_value(FIFO_WIDTH - 1 downto 0) := fifo_read_data;
                        when REG_STATUS =>
                            rd_value(4) := fifo_rd_valid;
                            rd_value(3) := fifo_afull;
                            rd_value(2) := fifo_aempty;
                            rd_value(1) := fifo_full;
                            rd_value(0) := fifo_empty;
                        when REG_COUNT =>
                            rd_value := std_logic_vector(resize(unsigned(fifo_count), 32));
                        when REG_CONFIG =>
                            rd_value := FIFO_CONFIG_VALUE;
                        when REG_THRESHOLD =>
                            rd_value := FIFO_THRESHOLD_VALUE;
                        when others =>
                            null; -- WO and reserved offsets read zero.
                    end case;
                    rdata_reg <= rd_value;
                    rvalid_reg <= '1';
                elsif rvalid_reg = '1' and S_AXI_RREADY = '1' then
                    rvalid_reg <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
