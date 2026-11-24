\# ECE 520 Lab 4 — Custom AXI4-Lite IP



\## Project Overview



This project implements and verifies three AXI-connected FPGA peripherals on the Digilent Zybo Z7-10 using AMD Vivado and Vitis 2023.1.



The system consists of a custom 16-bit multiplier written in Verilog, an AXI BRAM Controller with Block Memory Generator, and a custom AXI4-Lite FIFO peripheral written in VHDL. The Zynq ARM Cortex-A9 processor communicates with these peripherals through memory-mapped AXI transactions.



\## Hardware Platform



\- Board: Zybo Z7-10

\- FPGA: XC7Z010CLG400-1

\- Tools: Vivado 2023.1, Vitis 2023.1

\- FPGA fabric clock: 50 MHz

\- Multiplier base address: `0x43C00000`

\- BRAM base address: `0x40000000`

\- FIFO base address: `0x43C10000`



\## Verification



\*\*Multiplier:\*\* Verified using RTL simulation and an ARM C application running on the physical Zybo.



\*\*BRAM:\*\* Performed 32 hardware multiplications from 1×1 through 32×32, stored the products in BRAM, then read and verified all 32 entries. Result: PASS.



\*\*FIFO simulation:\*\* Used a self-checking VHDL testbench to simulate AXI4-Lite transactions, register accesses, reset, FIFO ordering, full and empty conditions, overflow, and underflow. Result: PASS at 19.36 µs.



\*\*FIFO hardware:\*\* Used a C application on the Zynq ARM processor to configure and reset the FIFO, write 32 values (`0x1200`–`0x121F`), verify the full condition, read all values back in order, and test overflow and underflow. Result: 32/32 PASS.



\## Resource Utilization (Post-Implementation)



| Resource | Used | Utilization |

|---|---:|---:|

| Slice LUTs | 1,891 | 10.74% |

| Slice Registers | 2,546 | 7.23% |

| Block RAM tiles | 16.5 | 27.50% |

| DSP48E1 | 1 | 1.25% |



\## Timing Results



\- Clock frequency: 50 MHz

\- Clock period: 20 ns

\- Worst setup slack: +9.866 ns

\- Total negative slack: 0 ns

\- Worst hold slack: +0.042 ns

\- All specified timing constraints met.



\## Repository Contents



\- `src/` — HDL design files

\- `ip\_repo/` — Packaged AXI IP definitions and source files

\- `sim/` — FIFO AXI simulation testbench

\- `vitis/` — ARM C verification applications

\- `scripts/` — Vivado project and simulation scripts

\- `vivado/` — Block design source

\- `reports/` — Synthesis, utilization, and timing reports

\- `screenshots/` — Hardware and simulation evidence



\## Results



The multiplier, BRAM, and FIFO were successfully verified on the physical Zybo Z7-10. The final FIFO hardware demonstration returned all 32 words in the expected order, with no reported errors.

