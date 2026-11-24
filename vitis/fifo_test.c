/* ECE 520/L Lab 4 - software test for the custom AXI4-Lite FIFO.
 * Replace FIFO_BASE using Vivado Address Editor before compiling.
 */
#include "platform.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "sleep.h"

#define FIFO_BASE 0x43C10000U  /* REPLACE WITH YOUR ACTUAL AXI BASE ADDRESS */
#if FIFO_BASE == 0xFFFFFFFFU
#error "Set FIFO_BASE to the address of sc_fifo_axi_0 in Vivado Address Editor"
#endif

#define FPGA_REV_REG  (FIFO_BASE + 0x00U)
#define FIFO_RST_REG  (FIFO_BASE + 0x04U)
#define WR_DATA_REG   (FIFO_BASE + 0x08U)
#define RD_REQ_REG    (FIFO_BASE + 0x0CU)
#define RD_DATA_REG   (FIFO_BASE + 0x10U)
#define STATUS_REG    (FIFO_BASE + 0x14U)
#define COUNT_REG     (FIFO_BASE + 0x18U)
#define CONFIG_REG    (FIFO_BASE + 0x1CU)
#define THRESH_REG    (FIFO_BASE + 0x20U)

#define RD_VALID_MASK 0x10U
#define FULL_MASK     0x02U
#define EMPTY_MASK    0x01U

static u32 wait_read_valid(void)
{
    u32 attempts;
    for (attempts = 0U; attempts < 100000U; ++attempts) {
        if ((Xil_In32(STATUS_REG) & RD_VALID_MASK) != 0U) {
            return 1U;
        }
    }
    return 0U;
}

int main(void)
{
    u32 i, rev, cfg, thresh, status, count, readback;
    u32 errors = 0U;
    init_platform();

    xil_printf("\r\n===========================================\r\n");
    xil_printf("ECE 520 LAB 4 - CUSTOM AXI-LITE FIFO\r\n");
    xil_printf("Student: Hamza\r\n");
    xil_printf("===========================================\r\n");

    rev    = Xil_In32(FPGA_REV_REG);
    cfg    = Xil_In32(CONFIG_REG);
    thresh = Xil_In32(THRESH_REG);
    xil_printf("REV=0x%08x CONFIG=0x%08x THRESH=0x%08x\r\n",
               (unsigned int)rev, (unsigned int)cfg, (unsigned int)thresh);
    if (rev != 0x52000004U || cfg != 0x01002010U || thresh != 0x001F0001U) {
        errors++;
        xil_printf("ERROR: Configuration/revision mismatch\r\n");
    }

    Xil_Out32(FIFO_RST_REG, 1U);
    status = Xil_In32(STATUS_REG);
    count  = Xil_In32(COUNT_REG);
    xil_printf("After reset: STATUS=0x%08x COUNT=%u\r\n",
               (unsigned int)status, (unsigned int)count);
    if ((status & 0x1FU) != 0x05U || count != 0U) errors++;

    xil_printf("\r\nWriting 32 values:\r\n");
    for (i = 0U; i < 32U; ++i) {
        Xil_Out32(WR_DATA_REG, 0x1200U + i);
        count = Xil_In32(COUNT_REG);
        if (count != i + 1U) {
            ++errors;
            xil_printf("WRITE %u: count mismatch, got %u\r\n",
                       (unsigned int)i, (unsigned int)count);
        }
    }
    status = Xil_In32(STATUS_REG);
    xil_printf("After 32 writes: STATUS=0x%08x COUNT=%u\r\n",
               (unsigned int)status, (unsigned int)Xil_In32(COUNT_REG));
    if ((status & FULL_MASK) == 0U) errors++;

    Xil_Out32(WR_DATA_REG, 0xBEEFU);  /* Overflow must be ignored. */
    if (Xil_In32(COUNT_REG) != 32U) errors++;

    xil_printf("\r\nReading and verifying 32 values:\r\n");
    for (i = 0U; i < 32U; ++i) {
        Xil_Out32(RD_REQ_REG, 1U);
        if (wait_read_valid() == 0U) {
            ++errors;
            xil_printf("READ %u: TIMEOUT waiting for RD_VALID\r\n", (unsigned int)i);
            break;
        }
        readback = Xil_In32(RD_DATA_REG) & 0xFFFFU;
        xil_printf("FIFO[%u] = 0x%04x %s\r\n",
                   (unsigned int)i, (unsigned int)readback,
                   (readback == (0x1200U + i)) ? "PASS" : "FAIL");
        if (readback != (0x1200U + i)) errors++;
    }

    count = Xil_In32(COUNT_REG);
    status = Xil_In32(STATUS_REG);
    if (count != 0U || (status & EMPTY_MASK) == 0U) errors++;

    Xil_Out32(RD_REQ_REG, 1U);  /* Empty read must be ignored. */
    status = Xil_In32(STATUS_REG);
    if ((status & RD_VALID_MASK) != 0U || Xil_In32(COUNT_REG) != 0U) errors++;

    xil_printf("\r\n===========================================\r\n");
    if (errors == 0U) {
        xil_printf("RESULT: PASS - 32/32 FIFO READS\r\n");
    } else {
        xil_printf("RESULT: FAIL - %u ERRORS\r\n", (unsigned int)errors);
    }
    xil_printf("===========================================\r\n");
    cleanup_platform();
    return 0;
}
