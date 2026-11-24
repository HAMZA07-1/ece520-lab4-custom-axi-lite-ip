/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>

#include "platform.h"
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"

/*
 * ECE 520 Lab 4
 * Custom 16-bit AXI-Lite Multiplier
 *
 * Register offsets:
 * 0x00 = Operand A
 * 0x04 = Operand B
 * 0x08 = Product
 */

#define MULT_BASE 0x43C00000U
#define REG_A       (MULT_BASE + 0x00U)
#define REG_B       (MULT_BASE + 0x04U)
#define REG_PRODUCT (MULT_BASE + 0x08U)

int main(void)
{
    u32 a;
    u32 b;
    u32 product;

    init_platform();

    xil_printf("\r\n================================\r\n");
    xil_printf("ECE 520 LAB 4 - AXI MULTIPLIER\r\n");
    xil_printf("================================\r\n");

    // Write operands to the custom AXI-Lite peripheral
    Xil_Out32(REG_A, 8U);
    Xil_Out32(REG_B, 8U);

    // Allow the registered multiplier to update
    usleep(10);

    // Read operands and computed product
    a = Xil_In32(REG_A) & 0xFFFFU;
    b = Xil_In32(REG_B) & 0xFFFFU;
    product = Xil_In32(REG_PRODUCT);

    xil_printf("Operand A = %u\r\n", (unsigned int)a);
    xil_printf("Operand B = %u\r\n", (unsigned int)b);
    xil_printf("Product   = %u\r\n", (unsigned int)product);

    if ((a == 8U) && (b == 8U) && (product == 64U))
    {
        xil_printf("RESULT: PASS\r\n");
    }
    else

    {
        xil_printf("RESULT: FAIL\r\n");
    }

    xil_printf("================================\r\n");

    cleanup_platform();
    return 0;
}
