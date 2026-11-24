**# ECE 520 Lab 4 — Custom AXI4-Lite IP on Zynq-7000**



**\*\*FPGA-Based Multiplier, Block RAM, and FIFO System\*\***



**\*\*Student:\*\* Hamza Sulehria**  

**\*\*Target Board:\*\* Digilent Zybo Z7-10**  

**\*\*FPGA:\*\* Xilinx Zynq-7010 (XC7Z010CLG400-1)**  

**\*\*Development Tools:\*\* Vivado and Vitis 2023.1**  

**\*\*Languages:\*\* Verilog, VHDL, C, Tcl**



\## 1. Project Overview



This project demonstrates the design, integration, simulation, implementation, and hardware verification of custom AXI4-Lite peripherals on a Zynq-7000 FPGA development board.



The project integrates three hardware components into a processor-controlled system:



1\. \*\*Custom 16-bit multiplier:\*\* A Verilog hardware accelerator accessed through AXI4-Lite registers.

2\. \*\*AXI-connected Block RAM:\*\* Memory accessible to the ARM processor through an AXI BRAM Controller.

3\. \*\*Custom AXI4-Lite FIFO:\*\* A VHDL peripheral using a synchronous 16-bit-wide, 32-entry FIFO with software-accessible control and status registers.



The ARM Cortex-A9 processor communicates with these peripherals through memory-mapped AXI transactions.



The project was verified through RTL simulation, self-checking testbenches, C software applications, and execution on the physical Zybo Z7-10 board.



\## 2. System Architecture



\### Hardware components



| Component | Function |

|---|---|

| Zynq Processing System | Runs bare-metal C test applications |

| AXI Interconnect | Routes processor transactions to memory-mapped peripherals |

| Custom Multiplier AXI IP | Computes unsigned 16-bit multiplication |

| AXI BRAM Controller | Provides AXI access to FPGA block memory |

| Block Memory Generator | Stores multiplication results for readback |

| Custom FIFO AXI IP | Buffers 16-bit data and provides FIFO control/status registers |



All custom AXI peripheral logic operates using the 50 MHz FPGA fabric clock.



\### AXI communication



The Zynq ARM processor acts as the AXI master. Each hardware peripheral is mapped into the processor's address space.



For a write operation, the processor sends a register address and data through the AXI interconnect. For a read operation, the selected peripheral returns register data through the AXI read channel.



The FIFO's internal memory is separate from the larger AXI Block Memory Generator used in the multiplier/BRAM exercise.



\## 3. Memory-Mapped Address Assignments



| Peripheral | Base Address |

|---|---|

| AXI Multiplier | `0x43C00000` |

| Custom FIFO AXI IP | `0x43C10000` |

| AXI BRAM Controller | `0x40000000` |



\### Multiplier registers



| Offset | Register | Function |

|---|---|---|

| `0x00` | Operand A | First 16-bit unsigned operand |

| `0x04` | Operand B | Second 16-bit unsigned operand |

| `0x08` | Product | 32-bit multiplication result |



The processor writes the operands and reads the product through the AXI4-Lite interface.



\## 4. Custom FIFO AXI IP



The FIFO peripheral was implemented in VHDL and packaged as a reusable Vivado custom AXI4-Lite IP core.



\### FIFO configuration



| Parameter | Value |

|---|---|

| Data width | 16 bits |

| FIFO depth | 32 entries |

| Read latency | 1 cycle |

| Almost-empty threshold | 1 |

| Almost-full threshold | 31 |

| Interface | AXI4-Lite |

| Clock frequency | 50 MHz |



The AXI interface uses a synchronous active-low reset, while the internal FIFO uses an active-high synchronous reset. The wrapper provides the required reset control.



\### FIFO register map



All registers are accessed through 32-bit AXI4-Lite transactions.



| Offset | Register | Access | Description |

|---|---|---|---|

| `0x00` | FPGA\_REV\_REG | RO | Peripheral identification |

| `0x04` | FIFO\_RST\_REG | WO | Software reset |

| `0x08` | WR\_DATA\_REG | WO | Write one 16-bit FIFO value |

| `0x0C` | RD\_REQ\_REG | WO | Request one FIFO read |

| `0x10` | RD\_DATA\_REG | RO | Registered FIFO read data |

| `0x14` | STATUS\_REG | RO | FIFO status and read-valid flags |

| `0x18` | DATA\_COUNT\_REG | RO | Number of stored words |

| `0x1C` | CONFIG\_REG | RO | FIFO configuration |

| `0x20` | THRESHOLD\_REG | RO | Almost-full and almost-empty thresholds |

| `0x24–0x3C` | Reserved | RO | Reserved offsets read as zero |



\### STATUS\_REG bit definitions



| Bit | Signal | Meaning |

|---|---|---|

| 4 | RD\_VALID | A requested FIFO read has completed |

| 3 | ALMOST\_FULL | Occupancy has reached the almost-full threshold |

| 2 | ALMOST\_EMPTY | Occupancy is at or below the almost-empty threshold |

| 1 | FULL | FIFO contains 32 entries |

| 0 | EMPTY | FIFO contains no entries |



After reset, the expected status is `0x00000005`, indicating `EMPTY=1` and `ALMOST\_EMPTY=1`.



After filling the FIFO with 32 words, the observed status is `0x0000000A`, indicating `FULL=1` and `ALMOST\_FULL=1`.



\### FIFO transaction behavior



The AXI wrapper converts software write commands into one-cycle FIFO control pulses. This prevents a single AXI register transaction from generating repeated FIFO writes or reads.



For reading, software sends a request through RD\_REQ\_REG, polls STATUS\_REG until RD\_VALID is asserted, and then reads the result from RD\_DATA\_REG.



The FIFO maintains first-in, first-out ordering.



\## 5. Verification Methodology



Verification was conducted at both simulation and physical-hardware levels.



\### 5.1 Multiplier verification



The multiplier was tested using an RTL testbench and a processor-based C program.



The C program writes operands into memory-mapped AXI registers and checks the returned product.



A physical hardware test using operands 8 and 8 returned a product of 64 and reported PASS.



\### 5.2 Multiplier and BRAM verification



A second C application performs 32 multiplications using values 1 through 32.



For each input, the processor writes the operands to the multiplier, reads the product, and stores it in the AXI-connected BRAM.



The application subsequently reads all 32 results from BRAM and checks them against their expected squares.



\*\*Hardware result:\*\* All 32 BRAM readback comparisons passed.



\### 5.3 FIFO AXI simulation



A self-checking VHDL testbench was developed to simulate AXI4-Lite transactions with the FIFO peripheral.



The testbench verifies:



\- Register-map behavior

\- Software reset

\- FIFO data writes

\- FIFO data reads and read-valid behavior

\- First-in, first-out ordering

\- Full and empty status flags

\- Almost-full and almost-empty behavior

\- Overflow protection

\- Underflow protection



\*\*Simulation result:\*\* PASS at 19,360 ns (19.36 µs).



\### 5.4 FIFO hardware verification



A bare-metal C application was executed on the Zynq ARM processor.



The software test performs the following operations:



1\. Reads the FIFO revision, configuration, and threshold registers.

2\. Resets the FIFO and checks that the occupancy count is zero.

3\. Writes 32 consecutive values, from `0x1200` through `0x121F`.

4\. Checks that DATA\_COUNT\_REG reads 32 and FULL is asserted.

5\. Tests overflow protection by attempting an additional write while full.

6\. Requests and reads all 32 FIFO entries.

7\. Compares each returned value against the expected data.

8\. Tests empty-FIFO and underflow behavior.



The hardware returned:



| Register | Observed Value |

|---|---|

| FPGA\_REV\_REG | `0x52000004` |

| CONFIG\_REG | `0x01002010` |

| THRESHOLD\_REG | `0x001F0001` |

| Status after reset | `0x00000005` |

| Count after reset | `0` |

| Status after 32 writes | `0x0000000A` |

| Count after 32 writes | `32` |



\*\*Final hardware result: PASS — 32/32 FIFO reads.\*\*



The returned sequence matched the original write sequence exactly, demonstrating correct FIFO ordering.



\## 6. FPGA Resource Utilization



\### Synthesis results



| Resource | Used | Available | Utilization |

|---|---:|---:|---:|

| Slice LUTs | 2,110 | 17,600 | 11.99% |

| Slice Registers | 2,974 | 35,200 | 8.45% |

| Block RAM Tiles | 16.5 | 60 | 27.50% |

| DSP48E1 | 1 | 80 | 1.25% |



\### Final implementation results



| Resource | Used | Available | Utilization |

|---|---:|---:|---:|

| Slice LUTs | 1,891 | 17,600 | 10.74% |

| Slice Registers | 2,546 | 35,200 | 7.23% |

| Block RAM Tiles | 16.5 | 60 | 27.50% |

| DSP48E1 | 1 | 80 | 1.25% |



Resource utilization decreased between synthesis and implementation as Vivado applied additional optimization.



The design uses one DSP48E1 arithmetic primitive and a total of 16 RAMB36E1 blocks plus one RAMB18E1 block.



The implemented system fits within the FPGA resource limits.



\## 7. Timing Analysis



Timing analysis was performed on the fully routed design.



| Timing Metric | Result |

|---|---:|

| Clock Frequency | 50 MHz |

| Clock Period | 20.000 ns |

| Worst Setup Slack | +9.866 ns |

| Total Negative Slack | 0.000 ns |

| Worst Hold Slack | +0.042 ns |

| Total Hold Slack Violations | 0 |

| Failing Setup Endpoints | 0 |

| Failing Hold Endpoints | 0 |



\*\*Vivado result: All user-specified timing constraints are met.\*\*



The reported setup and hold slack are positive, indicating that the routed design meets the specified 50 MHz clock timing requirements.



\## 8. Repository Organization



| Directory | Contents |

|---|---|

| `src/` | Verilog and VHDL hardware source files |

| `ip\_repo/` | Packaged custom AXI IP cores and metadata |

| `sim/` | FIFO AXI self-checking VHDL testbench |

| `vitis/` | Multiplier, multiplier/BRAM, and FIFO C programs |

| `scripts/` | Vivado project-generation and simulation Tcl scripts |

| `vivado/` | Final Vivado Block Design |

| `reports/` | Synthesis, implementation utilization, and timing reports |

| `screenshots/` | Vivado and hardware demonstration evidence |



\### Important source files



\- `multiplier\_16\_bit.v` — unsigned multiplication logic

\- `mult\_16\_bit\_v1\_0\_S00\_AXI.v` — multiplier AXI register interface

\- `sc\_fifo.vhd` — FIFO storage and control logic

\- `sc\_fifo\_axi\_v1\_0\_S00\_AXI.vhd` — FIFO AXI register interface

\- `sc\_fifo\_axi\_v1\_0.vhd` — FIFO AXI peripheral top level

\- `tb\_sc\_fifo\_axi.vhd` — self-checking FIFO AXI simulation

\- `fifo\_test.c` — ARM-based FIFO hardware verification



\## 9. Reproducing the Project



\### Requirements



\- AMD Vivado 2023.1

\- AMD Vitis / XSCT 2023.1

\- Zybo Z7-10 development board

\- USB-JTAG and USB-UART connectivity

\- Serial terminal such as PuTTY



\### FPGA design



The final design is based on `mult\_bd\_hs` in Vivado.



The packaged AXI IP cores are included in `ip\_repo/`, while the design and project Tcl scripts are in `scripts/`.



On a different computer, project paths and IP repository locations may need to be adjusted before regenerating the design. The supplied scripts have not been independently validated as a clean, one-command rebuild.



\### Simulation



Open the FIFO simulation setup, compile the VHDL source files and testbench, and run the behavioral simulation.



The expected testbench result is:



`PASS: AXI FIFO register map, 32 writes/reads, flags, reset and overflow/underflow`



\### Hardware verification



Generate and program the bitstream for the final Vivado design.



Run the corresponding bare-metal C application on the ARM processor using Vitis/XSCT.



Monitor serial output through the board's USB-UART connection at 115200 baud, 8 data bits, no parity, and 1 stop bit.



The FIFO test is successful when all 32 values are read back correctly and the application reports:



`RESULT: PASS - 32/32 FIFO READS`



\## 10. Results and Conclusion



This project successfully demonstrates custom AXI4-Lite peripheral development from RTL implementation through physical FPGA verification.



The multiplier produced correct arithmetic results, the BRAM stored and returned all 32 tested multiplication products, and the VHDL FIFO successfully handled 32 writes and reads while preserving data ordering.



The custom FIFO was verified using both an AXI transaction-level VHDL testbench and a C application running on the physical Zynq processor.



Finally, Vivado implementation reports confirmed that the complete design fits within the Zybo Z7-10 FPGA resources and meets the specified timing constraints at 50 MHz.

