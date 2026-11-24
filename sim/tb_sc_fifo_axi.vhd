-- ECE 520/L Lab 4 self-checking VHDL testbench for AXI4-Lite FIFO IP.
-- Simulates independent AXI channels, 32 writes, overflow, 32 reads,
-- underflow, reset, status/config/threshold registers, and RO/WO behavior.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sc_fifo_axi is
end entity;

architecture sim of tb_sc_fifo_axi is
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz
    signal clk : std_logic := '0';
    signal rstn : std_logic := '0';

    signal awaddr  : std_logic_vector(5 downto 0) := (others => '0');
    signal awprot  : std_logic_vector(2 downto 0) := (others => '0');
    signal awvalid : std_logic := '0';
    signal awready : std_logic;
    signal wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal wstrb   : std_logic_vector(3 downto 0) := (others => '0');
    signal wvalid  : std_logic := '0';
    signal wready  : std_logic;
    signal bresp   : std_logic_vector(1 downto 0);
    signal bvalid  : std_logic;
    signal bready  : std_logic := '0';
    signal araddr  : std_logic_vector(5 downto 0) := (others => '0');
    signal arprot  : std_logic_vector(2 downto 0) := (others => '0');
    signal arvalid : std_logic := '0';
    signal arready : std_logic;
    signal rdata   : std_logic_vector(31 downto 0);
    signal rresp   : std_logic_vector(1 downto 0);
    signal rvalid  : std_logic;
    signal rready  : std_logic := '0';
begin
    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.sc_fifo_axi_v1_0
        port map (
            s00_axi_aclk=>clk, s00_axi_aresetn=>rstn,
            s00_axi_awaddr=>awaddr, s00_axi_awprot=>awprot,
            s00_axi_awvalid=>awvalid, s00_axi_awready=>awready,
            s00_axi_wdata=>wdata, s00_axi_wstrb=>wstrb,
            s00_axi_wvalid=>wvalid, s00_axi_wready=>wready,
            s00_axi_bresp=>bresp, s00_axi_bvalid=>bvalid,
            s00_axi_bready=>bready,
            s00_axi_araddr=>araddr, s00_axi_arprot=>arprot,
            s00_axi_arvalid=>arvalid, s00_axi_arready=>arready,
            s00_axi_rdata=>rdata, s00_axi_rresp=>rresp,
            s00_axi_rvalid=>rvalid, s00_axi_rready=>rready
        );

    process
        procedure axi_write(addr : natural; value : std_logic_vector(31 downto 0)) is
            variable addr_done : boolean := false;
            variable data_done : boolean := false;
        begin
            wait until falling_edge(clk);
            awaddr <= std_logic_vector(to_unsigned(addr, 6));
            wdata <= value;
            wstrb <= "1111";
            awvalid <= '1';
            wvalid <= '1';
            bready <= '0';
            while not (addr_done and data_done) loop
                wait until rising_edge(clk);
                if awready = '1' then addr_done := true; end if;
                if wready = '1' then data_done := true; end if;
                wait until falling_edge(clk);
                if addr_done then awvalid <= '0'; end if;
                if data_done then wvalid <= '0'; end if;
            end loop;
            while bvalid /= '1' loop
                wait until rising_edge(clk);
            end loop;
            assert bresp = "00" report "AXI write response not OKAY" severity failure;
            wait until falling_edge(clk);
            bready <= '1';
            wait until rising_edge(clk);
            wait until falling_edge(clk);
            bready <= '0';
        end procedure;

        procedure axi_read(addr : natural; variable value : out std_logic_vector(31 downto 0)) is
        begin
            wait until falling_edge(clk);
            araddr <= std_logic_vector(to_unsigned(addr, 6));
            arvalid <= '1';
            rready <= '0';
            loop
                wait until rising_edge(clk);
                exit when arready = '1';
            end loop;
            wait until falling_edge(clk);
            arvalid <= '0';
            while rvalid /= '1' loop
                wait until rising_edge(clk);
            end loop;
            assert rresp = "00" report "AXI read response not OKAY" severity failure;
            value := rdata;
            wait until falling_edge(clk);
            rready <= '1';
            wait until rising_edge(clk);
            wait until falling_edge(clk);
            rready <= '0';
        end procedure;

        procedure expect_read(addr : natural; expected : std_logic_vector(31 downto 0)) is
            variable v : std_logic_vector(31 downto 0);
        begin
            axi_read(addr, v);
            assert v = expected
                report "Mismatch at register byte offset " & integer'image(addr) &
                       ": got " & integer'image(to_integer(unsigned(v(15 downto 0)))) &
                       ", expected low16 " & integer'image(to_integer(unsigned(expected(15 downto 0))))
                severity failure;
        end procedure;

        variable v : std_logic_vector(31 downto 0);
        variable rd_seen : boolean;
    begin
        wait for CLK_PERIOD * 5;
        wait until falling_edge(clk);
        rstn <= '1';
        wait for CLK_PERIOD * 3;

        -- Default register values and read-only behavior.
        expect_read(16#00#, x"52000004");
        expect_read(16#14#, x"00000005");
        expect_read(16#18#, x"00000000");
        expect_read(16#1C#, x"01002010");
        expect_read(16#20#, x"001F0001");
        expect_read(16#04#, x"00000000");
        expect_read(16#08#, x"00000000");
        expect_read(16#0C#, x"00000000");
        expect_read(16#24#, x"00000000");
        expect_read(16#3C#, x"00000000");
        axi_write(16#00#, x"DEADBEEF");
        expect_read(16#00#, x"52000004");
        axi_write(16#14#, x"FFFFFFFF");
        expect_read(16#14#, x"00000005");

        -- An empty FIFO ignores a read command.
        axi_write(16#0C#, x"00000001");
        expect_read(16#14#, x"00000005");

        -- Write 32 different 16-bit words. Each command must push only once.
        for i in 0 to 31 loop
            axi_write(16#08#, std_logic_vector(to_unsigned(16#1200# + i, 32)));
            expect_read(16#18#, std_logic_vector(to_unsigned(i + 1, 32)));
        end loop;
        expect_read(16#14#, x"0000000A"); -- FULL and ALMOST_FULL.

        -- Overflow must leave count and old data unchanged.
        axi_write(16#08#, x"0000BEEF");
        expect_read(16#18#, x"00000020");

        -- Pop all 32 in FIFO order (registered output, poll RD_VALID).
        for i in 0 to 31 loop
            axi_write(16#0C#, x"00000001");
            rd_seen := false;
            for poll in 0 to 30 loop
                axi_read(16#14#, v);
                if v(4) = '1' then
                    rd_seen := true;
                    exit;
                end if;
            end loop;
            assert rd_seen report "Timed out waiting for RD_VALID" severity failure;
            expect_read(16#10#, std_logic_vector(to_unsigned(16#1200# + i, 32)));
            expect_read(16#18#, std_logic_vector(to_unsigned(31 - i, 32)));
        end loop;
        expect_read(16#18#, x"00000000");
        -- The last successfully popped word leaves RD_VALID set until next request.
        expect_read(16#14#, x"00000015");

        -- Underflow clears RD_VALID and leaves FIFO empty.
        axi_write(16#0C#, x"00000001");
        expect_read(16#14#, x"00000005");

        -- Write again, then software-reset and check all relevant state.
        axi_write(16#08#, x"0000AAAA");
        expect_read(16#18#, x"00000001");
        axi_write(16#04#, x"00000001");
        expect_read(16#18#, x"00000000");
        expect_read(16#14#, x"00000005");
        expect_read(16#10#, x"00000000");
        expect_read(16#04#, x"00000000");

        report "PASS: AXI FIFO register map, 32 writes/reads, flags, reset and overflow/underflow" severity note;
        wait;
    end process;

    process
    begin
        wait for 3 ms;
        assert false report "TESTBENCH TIMEOUT (AXI deadlock or missing response)" severity failure;
        wait;
    end process;
end architecture sim;
