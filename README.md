## **ECE 520 Lab 4 - Custom AXI-Lite IP**

Hamza Sulehria

Zybo Z7-10 | Vivado and Vitis 2023.1 | Verilog, VHDL, C



**Overview**

For this lab, I built a Zynq-based system with three memory-mapped peripherals: a 16-bit multiplier, block RAM, and a custom FIFO. The ARM processor accesses each peripheral over AXI. I wrote the multiplier in Verilog, integrated the AXI BRAM Controller and Block Memory Generator, and wrapped my VHDL FIFO with an AXI4-Lite interface.



I verified the design in simulation and then tested it on the physical Zybo Z7-10. The final design was implemented at 50 MHz and met its timing constraints.



#### **Hardware design**

The final block design contains:

\- Zynq-7000 Processing System, running bare-metal C applications

\- AXI interconnect, connecting the processor to the peripherals

\- Custom AXI4-Lite multiplier, using 16-bit unsigned operands

\- AXI BRAM Controller and Block Memory Generator

\- Custom AXI4-Lite FIFO, built around the VHDL FIFO from Lab 3

The multiplier and FIFO are independent peripherals. The C application controls them by reading and writing their registers. In the BRAM test, the processor reads each multiplication result and writes it into BRAM; the multiplier does not write to BRAM directly.



**Address map**

\- Multiplier: 0x43C00000

\- FIFO: 0x43C10000

\- BRAM: 0x40000000



**Multiplier register offsets:**

\- 0x00 - Operand A (16-bit input)

\- 0x04 - Operand B (16-bit input)

\- 0x08 - Product (32-bit output)



#### **FIFO design**

The FIFO stores 32 words of 16 bits each. It uses a one-cycle read latency, an almost-empty threshold of 1, and an almost-full threshold of 31. The AXI wrapper provides reset, write, read-request, and status registers.



**FIFO register offsets:**

\- 0x00 - Revision ID (read only)

\- 0x04 - FIFO reset (write only)

\- 0x08 - Write data, lower 16 bits (write only)

\- 0x0C - Read request, bit 0 (write only)

\- 0x10 - Read data, lower 16 bits (read only)

\- 0x14 - Status (read only)

\- 0x18 - Data count (read only)

\- 0x1C - FIFO configuration (read only)

\- 0x20 - Almost-empty and almost-full thresholds (read only)

\- 0x24 through 0x3C - Reserved, read as zero



**Status bits:**

\- Bit 4 - Read valid

\- Bit 3 - Almost full

\- Bit 2 - Almost empty

\- Bit 1 - Full

\- Bit 0 - Empty



An AXI write generates a single FIFO write or read-request pulse. To read a value, the software requests a read, polls the read-valid status bit, and then reads the data register. This avoids treating a read request as if its data were available immediately.



#### **Testing**



**Multiplier**

I first tested the multiplier through simulation, then used a bare-metal C program to write the operands and read the product over AXI. One hardware test used 8 and 8 and returned 64 (PASS).



**Multiplier with BRAM**

The C program multiplied the integers 1 through 32 by themselves. It stored each result in BRAM, then read all 32 entries back and compared them against the expected squares. All 32 comparisons passed.



**FIFO AXI simulation**

The self-checking VHDL testbench in sim/tb\_sc\_fifo\_axi.vhd exercises AXI4-Lite register accesses, FIFO reset, 32 writes and reads, FIFO ordering, status flags, overflow, and underflow.



Simulation result: PASS at 19,360 ns (19.36 us).



**FIFO hardware test**

The Zynq ARM processor ran vitis/fifo\_test.c on the physical board. The test:

1\. Read the revision, configuration, and threshold registers.

2\. Reset the FIFO and checked that the count was zero.

3\. Wrote 32 values from 0x1200 to 0x121F.

4\. Confirmed the full condition and a count of 32.

5\. Checked that an extra write did not increase the count.

6\. Read all 32 values back, checking each against the expected value.

7\. Checked the empty and underflow behavior.

Observed register values:

\- Revision: 0x52000004

\- Configuration: 0x01002010

\- Thresholds: 0x001F0001

\- Status after reset: 0x00000005 (empty and almost empty)

\- Status after 32 writes: 0x0000000A (full and almost full)

Hardware result: PASS - 32/32 FIFO reads.



#### **FPGA utilization and timing**

Target device: XC7Z010CLG400-1 (Zybo Z7-10)



Post-synthesis utilization:

\- 2,110 LUTs (11.99%)

\- 2,974 slice registers (8.45%)

\- 16.5 block RAM tiles (27.50%)

\- 1 DSP48E1 (1.25%)



Post-implementation utilization:

\- 1,891 LUTs (10.74%)

\- 2,546 slice registers (7.23%)

\- 16.5 block RAM tiles (27.50%)

\- 1 DSP48E1 (1.25%)



Post-route timing at 50 MHz (20 ns period):

\- Worst setup slack: +9.866 ns

\- Total negative slack: 0.000 ns

\- Worst hold slack: +0.042 ns

\- Failing setup and hold endpoints: 0

Vivado reported that all user-specified timing constraints were met. The full reports are saved in reports/.



#### **Repository contents**

\- src/ - Multiplier and FIFO RTL, including their AXI wrappers

\- ip\_repo/ - Packaged Vivado IP cores and metadata

\- sim/ - Self-checking FIFO AXI testbench

\- vitis/ - Bare-metal C tests for multiplier, BRAM, and FIFO

\- scripts/ - Vivado project, block-design, and simulation Tcl scripts

\- vivado/ - Saved Vivado block design

\- reports/ - Synthesis, implementation, and timing reports

\- screenshots/ - Screenshots from the lab demonstration (added separately)



#### **Running the design**

The project was built using Vivado and Vitis 2023.1 for the Zybo Z7-10. The packaged IP cores are under ip\_repo/, and the final block design is under vivado/. Tcl exports are provided in scripts/.



To reproduce the hardware test, create or open the Vivado project, make the packaged IP available to Vivado, generate the bitstream, and program the Zybo. Build and download the appropriate C application using Vitis or XSCT. Open the board's serial port at 115200 baud, 8 data bits, no parity, and 1 stop bit to view the results.



The Tcl exports reflect the original Windows setup. Some paths may need to be adjusted on another computer; a clean rebuild from these exported scripts has not been independently verified.



#### **Result**

The multiplier and BRAM tests passed on hardware, and the FIFO returned all 32 test words in order. The FIFO AXI simulation passed, and the routed FPGA design met the 50 MHz timing constraints.

