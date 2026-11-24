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
 * ECE 520 LAB 4 - AXI Multiplier + BRAM
 * Student: Hamza
 *
 * Performs 32 hardware multiplications.
 * Stores the results in FPGA Block RAM.
 * Reads back and verifies all 32 results.
 */

#include "platform.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "sleep.h"

#define MULT_BASE      0x43C00000U
#define BRAM_BASE      0x40000000U

#define MULT_REG_A     (MULT_BASE + 0x00U)
#define MULT_REG_B     (MULT_BASE + 0x04U)
#define MULT_REG_RESULT (MULT_BASE + 0x08U)

#define NUM_TESTS 32U

int main(void)
{
    u32 i;
    u32 product;
    u32 stored;
    u32 expected;
    u32 errors = 0U;

    init_platform();

    xil_printf("\r\n========================================\r\n");
    xil_printf("ECE 520 LAB 4 - AXI MULTIPLIER + BRAM\r\n");
    xil_printf("Student: Hamza\r\n");
    xil_printf("========================================\r\n");

    xil_printf("\r\nSTEP 1: Calculating and storing products\r\n");

    for (i = 1U; i <= NUM_TESTS; i++)
    {
        // Write operands to custom AXI multiplier.
        Xil_Out32(MULT_REG_A, i);
        Xil_Out32(MULT_REG_B, i);

        // Give the registered multiplier time to update.
        usleep(10);

        // Read the product from the multiplier.
        product = Xil_In32(MULT_REG_RESULT);

        // Store the product in BRAM.
        // Each entry uses 4 bytes (32 bits).
        Xil_Out32(BRAM_BASE + ((i - 1U) * 4U), product);

        xil_printf("%d x %d = %d\r\n",
                   (int)i, (int)i, (int)product);
    }

    xil_printf("\r\nSTEP 2: Reading and verifying BRAM\r\n");

    for (i = 0U; i < NUM_TESTS; i++)
    {
        stored = Xil_In32(BRAM_BASE + (i * 4U));
        expected = (i + 1U) * (i + 1U);

        xil_printf("BRAM[%d] = %d",
                   (int)i, (int)stored);

        if (stored == expected)
        {
            xil_printf("  PASS\r\n");
        }
        else
        {
            errors++;
            xil_printf("  FAIL (expected %d)\r\n",
                       (int)expected);
        }
    }

    xil_printf("\r\n========================================\r\n");

    if (errors == 0U)
    {
        xil_printf("RESULT: PASS - ALL 32 BRAM ENTRIES\r\n");
    }
    else
    {
        xil_printf("RESULT: FAIL - %d ERRORS\r\n", (int)errors);
    }

    xil_printf("========================================\r\n");

    cleanup_platform();

    return 0;
}
