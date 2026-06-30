/*
 * 015-sdmmc.c — external microSD card block driver (SDMMC0 / DW MSHC)
 *
 * Brings up the RK3568's SDMMC0 controller — a Synopsys DesignWare
 * Mobile Storage Host Controller (DW MSHC), unrelated to the SDHCI
 * host we drive the internal eMMC with. The IP is different, the
 * register set is different, the command-issue model is different.
 * Nothing in 012-emmc.c is reusable here.
 *
 * The driver brings the controller up in polled, blocking, single-
 * block read-and-write mode. It uses the SD card initialization
 * sequence (CMD0, CMD8, ACMD41-loop, CMD2, CMD3, CMD9, CMD7) which
 * differs from the eMMC sequence in three places:
 *
 *   - CMD8 (SEND_IF_COND) is required by the SD spec to confirm
 *     2.0+ compatibility before ACMD41 is meaningful. The eMMC
 *     spec has no equivalent — CMD8 there means SEND_EXT_CSD,
 *     which is a different thing entirely.
 *   - ACMD41 (SD_SEND_OP_COND) replaces CMD1 (eMMC's SEND_OP_COND).
 *     ACMD41 is an application command: each invocation is
 *     preceded by CMD55 (APP_CMD).
 *   - CMD3 publishes the card's chosen RCA; the eMMC equivalent
 *     assigns the host's chosen RCA. The semantic of the same
 *     command number is inverted between the two specs.
 *
 * The transfer mechanism is different too — DW MSHC streams data
 * through a memory-mapped FIFO at a high offset within the
 * register window, rather than SDHCI's separate buffer-data port.
 *
 * This file is purposefully shaped to mirror 012-emmc.c in
 * structure so the same caller can use either driver. The block
 * size is the SD spec's fixed 512 bytes, matching what 012-emmc.c
 * exposes.
 */

#include <stdint.h>

extern void debug_write(const char *text);

#define SDMMC0_BASE 0xFE2B0000u

/* Main clock-and-reset unit register pairs that feed the SDMMC0
 * controller. The two SDMMC0 clocks (HCLK_SDMMC0 / CLK_SDMMC0)
 * live at CLKGATE_CON(15) bits 0-1; the two matching soft-resets
 * (SRST_H_SDMMC0 / SRST_SDMMC0) live at SOFTRST_CON(13) bits 3-4.
 * The bit positions deliberately differ between the two
 * registers — one of the small inconsistencies the RK3568 CRU
 * lays on top of an otherwise regular pattern. See
 * docs/017-clocks-and-timers.md for the catalogue. */
#define CRU_CLKGATE_CON_15 0xFDD2033Cu
#define CRU_SOFTRST_CON_13 0xFDD20434u
#define SDMMC0_CLOCK_BITS  0x0003u   /* CLKGATE_CON(15) bits 0-1 */
#define SDMMC0_RESET_BITS  0x0018u   /* SOFTRST_CON(13) bits 3-4 */

/* The controller's hardware-config register — read-only, holds a
 * constant the chip designer baked in. We read it after the CRU
 * bring-up as a diagnostic discriminator: a sensible value means
 * the bus came up, ones means the AHB clock is still gated, zero
 * means the controller block is still in reset. */
#define DW_HCON          0x70

/* DW MSHC register offsets per upstream Linux drivers/mmc/host/dw_mmc.h. */
#define DW_CTRL          0x00
#define DW_PWREN         0x04
#define DW_CLKDIV        0x08
#define DW_CLKSRC        0x0C
#define DW_CLKENA        0x10
#define DW_TMOUT         0x14
#define DW_CTYPE         0x18
#define DW_BLKSIZ        0x1C
#define DW_BYTCNT        0x20
#define DW_INTMASK       0x24
#define DW_CMDARG        0x28
#define DW_CMD           0x2C
#define DW_RESP0         0x30
#define DW_RESP1         0x34
#define DW_RESP2         0x38
#define DW_RESP3         0x3C
#define DW_RINTSTS       0x44
#define DW_STATUS        0x48
#define DW_FIFOTH        0x4C
#define DW_CDETECT       0x50

/* DW MSHC FIFO data port. Lives at offset 0x200 in the modern
 * variants the RK3568 uses (rev 2+); older controllers had it at
 * 0x100. We use 0x200. */
#define DW_DATA          0x200

/* CTRL register bits. */
#define CTRL_CONTROLLER_RESET (1u << 0)
#define CTRL_FIFO_RESET       (1u << 1)
#define CTRL_DMA_RESET        (1u << 2)

/* CMD register bits. */
#define CMD_INDEX(n)               ((n) & 0x3F)
#define CMD_RESPONSE_EXPECT        (1u << 6)
#define CMD_RESPONSE_LENGTH_LONG   (1u << 7)
#define CMD_CHECK_RESPONSE_CRC     (1u << 8)
#define CMD_DATA_EXPECTED          (1u << 9)
#define CMD_WRITE                  (1u << 10)
#define CMD_WAIT_PRV_DATA_COMPLETE (1u << 13)
#define CMD_SEND_INITIALIZATION    (1u << 15)
#define CMD_USE_HOLD_REG           (1u << 29)
#define CMD_UPDATE_CLOCK_ONLY      (1u << 21)
#define CMD_START_CMD              (1u << 31)

/* RINTSTS bits. */
#define INT_RESP_ERR          (1u << 1)
#define INT_CMD_DONE          (1u << 2)
#define INT_DATA_OVER         (1u << 3)
#define INT_TX_DATA_REQ       (1u << 4)
#define INT_RX_DATA_REQ       (1u << 5)
#define INT_RESP_CRC_ERR      (1u << 6)
#define INT_DATA_CRC_ERR      (1u << 7)
#define INT_RESP_TIMEOUT      (1u << 8)
#define INT_DATA_READ_TIMEOUT (1u << 9)
#define INT_DATA_STARV        (1u << 10)
#define INT_FIFO_UN_OV        (1u << 11)
#define INT_HW_LOCKED_WERR    (1u << 12)
#define INT_START_BIT_ERR     (1u << 13)
#define INT_END_BIT_ERR       (1u << 15)
#define INT_ERROR_MASK ( \
    INT_RESP_ERR | INT_RESP_CRC_ERR | INT_DATA_CRC_ERR \
    | INT_RESP_TIMEOUT | INT_DATA_READ_TIMEOUT | INT_DATA_STARV \
    | INT_FIFO_UN_OV | INT_HW_LOCKED_WERR | INT_START_BIT_ERR \
    | INT_END_BIT_ERR)

/* STATUS register bits. */
#define STATUS_DATA_BUSY      (1u << 9)
#define STATUS_FIFO_COUNT_SHIFT 17
#define STATUS_FIFO_COUNT_MASK  (0x1FFFu << STATUS_FIFO_COUNT_SHIFT)

/* MMIO helpers. */
static inline void mmio_write32(uintptr_t a, uint32_t v) { *(volatile uint32_t *)a = v; }
static inline uint32_t mmio_read32(uintptr_t a) { return *(volatile uint32_t *)a; }

static void delay_loops(uint32_t n)
{
    while (n--) {
        __asm__ volatile ("nop");
    }
}

/* Track the card's RCA — published by the card in response to
 * CMD3, used as the upper 16 bits of the argument to commands
 * that address a specific card (CMD7, CMD9, etc.). */
static uint32_t sd_card_rca;

/* Wake the SDMMC0 controller out of the CRU's gated/asserted
 * post-reset state. Unlike the eMMC's intermittent failure,
 * SDMMC0 panics on first MMIO every time on the SD-card boot
 * path: u-boot doesn't talk to the SDMMC0 controller at all (it
 * reads the kernel from the SD card via the BootROM's fixed-
 * offset reads, bypassing the protocol stack entirely), so the
 * controller arrives at our kernel exactly as the chip reset
 * left it — clocks gated, resets asserted, every register read
 * either zero or all-ones.
 *
 * Both clocks and both resets are essential. The SDMMC0_DRV and
 * SDMMC0_SAMPLE clocks are phase shifters on top of CLK_SDMMC0
 * and are programmed during tuning, not bring-up. */
static int sdmmc_cru_bring_up(void)
{
    /* Ungate HCLK_SDMMC0 / CLK_SDMMC0. Mask covers bits 0-1,
     * value half is zero (clearing the gate bits ungates). */
    mmio_write32(CRU_CLKGATE_CON_15,
                 ((uint32_t)SDMMC0_CLOCK_BITS) << 16);

    /* Assert and then deassert SRST_H_SDMMC0 / SRST_SDMMC0. */
    mmio_write32(CRU_SOFTRST_CON_13,
                 (((uint32_t)SDMMC0_RESET_BITS) << 16) | SDMMC0_RESET_BITS);
    delay_loops(1000);
    mmio_write32(CRU_SOFTRST_CON_13,
                 ((uint32_t)SDMMC0_RESET_BITS) << 16);

    /* Diagnostic discriminator — HCON should read a sensible
     * controller-config constant (~0x0003_E47A on this chip).
     * The two failure modes both produce legible patterns. */
    uint32_t hcon = mmio_read32(SDMMC0_BASE + DW_HCON);
    if (hcon == 0x00000000u) {
        debug_write("[sdmmc] HCON reads 0 — SDMMC0 reset stuck asserted\r\n");
        return -1;
    }
    if (hcon == 0xFFFFFFFFu) {
        debug_write("[sdmmc] HCON reads ones — AHB clock still gated\r\n");
        return -2;
    }
    return 0;
}

/* Wait for the controller's busy state to clear after a clock-
 * update command. */
static int wait_command_complete(void)
{
    uint32_t budget = 1000000;
    while (mmio_read32(SDMMC0_BASE + DW_CMD) & CMD_START_CMD) {
        if (budget-- == 0) {
            return -1;
        }
    }
    return 0;
}

/* Issue a clock-update command (no actual SD command goes out,
 * the controller just refreshes its internal clock-config registers
 * to the card). This must be done after every CLKDIV / CLKENA
 * change. */
static int update_clock(void)
{
    mmio_write32(SDMMC0_BASE + DW_CMDARG, 0);
    mmio_write32(SDMMC0_BASE + DW_CMD,
                 CMD_UPDATE_CLOCK_ONLY
                 | CMD_WAIT_PRV_DATA_COMPLETE
                 | CMD_START_CMD);
    return wait_command_complete();
}

/* Set the SD card clock divider. The DW MSHC formula is
 * f_card = f_src / (2 * divisor). Common values:
 *
 *   divisor 63 → ~400 kHz at f_src = 50 MHz (identification rate)
 *   divisor 1  → 25 MHz at f_src = 50 MHz (default-speed transfer)
 */
static int set_clock_divider(uint32_t divisor)
{
    /* Disable the card clock while we change the divisor. */
    mmio_write32(SDMMC0_BASE + DW_CLKENA, 0);
    if (update_clock() != 0) {
        return -1;
    }
    mmio_write32(SDMMC0_BASE + DW_CLKDIV, divisor);
    if (update_clock() != 0) {
        return -2;
    }
    /* Re-enable the card clock. */
    mmio_write32(SDMMC0_BASE + DW_CLKENA, 1);
    if (update_clock() != 0) {
        return -3;
    }
    return 0;
}

/* Reset the controller — both the host machine and the FIFO. */
static int sdmmc_reset(void)
{
    mmio_write32(SDMMC0_BASE + DW_CTRL,
                 CTRL_CONTROLLER_RESET | CTRL_FIFO_RESET | CTRL_DMA_RESET);
    uint32_t budget = 100000;
    while (mmio_read32(SDMMC0_BASE + DW_CTRL)
           & (CTRL_CONTROLLER_RESET | CTRL_FIFO_RESET | CTRL_DMA_RESET)) {
        if (budget-- == 0) {
            return -1;
        }
    }
    return 0;
}

/* Wait for an SD command to complete and return cleanly. Clears
 * any error flags before waiting and reports the first error if
 * one fires. */
static int wait_command_response(int data_expected)
{
    /* Clear any prior interrupt-status bits. */
    mmio_write32(SDMMC0_BASE + DW_RINTSTS, 0xFFFFFFFFu);

    uint32_t budget = 1000000;
    while (1) {
        uint32_t status = mmio_read32(SDMMC0_BASE + DW_RINTSTS);
        if (status & INT_ERROR_MASK) {
            return -1;
        }
        if (status & INT_CMD_DONE) {
            if (!data_expected) {
                mmio_write32(SDMMC0_BASE + DW_RINTSTS, INT_CMD_DONE);
                return 0;
            }
            mmio_write32(SDMMC0_BASE + DW_RINTSTS, INT_CMD_DONE);
            /* Caller now handles the data phase. */
            return 0;
        }
        if (budget-- == 0) {
            return -2;
        }
    }
}

/* Issue an SD command. Caller specifies the command index, the
 * argument, and a bitmask of response/data flags. */
static int sd_send_command(uint32_t index, uint32_t arg, uint32_t flags)
{
    /* Wait for any prior data activity to settle. */
    uint32_t budget = 1000000;
    while (mmio_read32(SDMMC0_BASE + DW_STATUS) & STATUS_DATA_BUSY) {
        if (budget-- == 0) {
            return -1;
        }
    }

    mmio_write32(SDMMC0_BASE + DW_CMDARG, arg);
    mmio_write32(SDMMC0_BASE + DW_CMD,
                 CMD_INDEX(index)
                 | flags
                 | CMD_USE_HOLD_REG
                 | CMD_START_CMD);

    int data_expected = (flags & CMD_DATA_EXPECTED) ? 1 : 0;
    return wait_command_response(data_expected);
}

/* Initialize the SD card following the SD spec's card-init
 * sequence. */
static int sd_initialize_card(void)
{
    /* CRU clocks and resets first — without this every controller
     * MMIO panics on the SD-card boot path. */
    debug_write("[sdmmc] CRU bring-up...\r\n");
    if (sdmmc_cru_bring_up() != 0) {
        return -100;
    }

    debug_write("[sdmmc] resetting controller...\r\n");
    if (sdmmc_reset() != 0) {
        debug_write("[sdmmc] controller reset failed\r\n");
        return -1;
    }

    /* Clear RINTSTS *before* any other code can read it. The DW
     * MSHC's interrupt-status bits survive controller reset. Any
     * bits set when the chip came out of reset would otherwise
     * make the very first command's CMD_DONE poll fire on stale
     * state — the driver would think the command succeeded
     * before the controller had even seen it. Writing ones to
     * RINTSTS clears the bits in the W1C register. */
    mmio_write32(SDMMC0_BASE + DW_RINTSTS, 0xFFFFFFFFu);

    /* Mask all interrupts — we poll instead. */
    mmio_write32(SDMMC0_BASE + DW_INTMASK, 0);

    /* Timeouts — generous. */
    mmio_write32(SDMMC0_BASE + DW_TMOUT, 0xFFFFFFFFu);

    /* FIFO threshold. Value comes from upstream Linux's setup
     * for this controller variant: fifo-depth is 0x100, RX
     * watermark is fifo-depth/2 - 1 = 0x7F, TX watermark is
     * fifo-depth/2 = 0x80, multiple-transaction-size 2 sits in
     * bits 28-30 as 0x2. Composite value 0x207F_0080.
     *
     * Without this write the controller works on register
     * access but data transfers stall — the FIFO never signals
     * "ready to be drained" or "ready to be filled" at the
     * thresholds the rest of the code expects. */
    mmio_write32(SDMMC0_BASE + DW_FIFOTH, 0x207F0080u);

    /* Power the card slot. */
    mmio_write32(SDMMC0_BASE + DW_PWREN, 1);
    delay_loops(100000);

    /* 1-bit bus during identification. */
    mmio_write32(SDMMC0_BASE + DW_CTYPE, 0);

    debug_write("[sdmmc] identification clock...\r\n");
    if (set_clock_divider(63) != 0) {
        debug_write("[sdmmc] identification clock setup failed\r\n");
        return -2;
    }

    /* CMD0: GO_IDLE_STATE. No response expected. */
    debug_write("[sdmmc] CMD0 go-idle...\r\n");
    if (sd_send_command(0, 0,
                        CMD_SEND_INITIALIZATION) != 0) {
        debug_write("[sdmmc] CMD0 failed\r\n");
        return -3;
    }
    delay_loops(10000);

    /* CMD8: SEND_IF_COND. Argument: 0x1AA = (3.3 V supported,
     * check pattern 0xAA). A response of 0x1AA echoes our pattern,
     * indicating the card supports SD spec 2.0+. */
    debug_write("[sdmmc] CMD8 send-if-cond...\r\n");
    if (sd_send_command(8, 0x1AA,
                        CMD_RESPONSE_EXPECT
                        | CMD_CHECK_RESPONSE_CRC) != 0) {
        debug_write("[sdmmc] CMD8 failed; old SD card?\r\n");
        /* Continue anyway — pre-2.0 SD cards just don't respond. */
    }

    /* ACMD41: SD_SEND_OP_COND. Wrap in CMD55 (APP_CMD) each
     * iteration. Argument 0x40FF8000: HCS=1 (host supports
     * high-capacity), voltage window 3.0-3.6 V. Loop until the
     * card's busy bit (bit 31 of the OCR response) clears. */
    debug_write("[sdmmc] ACMD41 op-cond loop...\r\n");
    uint32_t budget = 1000;
    while (budget--) {
        /* CMD55 with the as-yet-unassigned RCA = 0. */
        if (sd_send_command(55, 0,
                            CMD_RESPONSE_EXPECT
                            | CMD_CHECK_RESPONSE_CRC) != 0) {
            debug_write("[sdmmc] CMD55 failed\r\n");
            return -4;
        }
        /* ACMD41 (sent as CMD41 — the previous CMD55 marks it as
         * an app command). The response is the OCR with no CRC. */
        if (sd_send_command(41, 0x40FF8000,
                            CMD_RESPONSE_EXPECT) != 0) {
            debug_write("[sdmmc] ACMD41 failed\r\n");
            return -5;
        }
        uint32_t ocr = mmio_read32(SDMMC0_BASE + DW_RESP0);
        if (ocr & 0x80000000u) {
            break;
        }
        delay_loops(10000);
    }
    if (budget == 0) {
        debug_write("[sdmmc] card never ready\r\n");
        return -6;
    }

    /* CMD2: ALL_SEND_CID. 136-bit response. */
    debug_write("[sdmmc] CMD2 all-send-cid...\r\n");
    if (sd_send_command(2, 0,
                        CMD_RESPONSE_EXPECT
                        | CMD_RESPONSE_LENGTH_LONG
                        | CMD_CHECK_RESPONSE_CRC) != 0) {
        debug_write("[sdmmc] CMD2 failed\r\n");
        return -7;
    }

    /* CMD3: SEND_RELATIVE_ADDR. The card publishes its RCA in the
     * upper 16 bits of the response. */
    debug_write("[sdmmc] CMD3 send-relative-addr...\r\n");
    if (sd_send_command(3, 0,
                        CMD_RESPONSE_EXPECT
                        | CMD_CHECK_RESPONSE_CRC) != 0) {
        debug_write("[sdmmc] CMD3 failed\r\n");
        return -8;
    }
    sd_card_rca = mmio_read32(SDMMC0_BASE + DW_RESP0) >> 16;

    /* CMD9: SEND_CSD. We don't parse the CSD for phase 1 but we
     * issue it because some controllers require it before
     * transferring to the data-transfer state. */
    debug_write("[sdmmc] CMD9 send-csd...\r\n");
    if (sd_send_command(9, sd_card_rca << 16,
                        CMD_RESPONSE_EXPECT
                        | CMD_RESPONSE_LENGTH_LONG
                        | CMD_CHECK_RESPONSE_CRC) != 0) {
        debug_write("[sdmmc] CMD9 failed\r\n");
        return -9;
    }

    /* CMD7: SELECT_CARD. After this the card is in transfer
     * state and ready for read / write commands. */
    debug_write("[sdmmc] CMD7 select-card...\r\n");
    if (sd_send_command(7, sd_card_rca << 16,
                        CMD_RESPONSE_EXPECT
                        | CMD_CHECK_RESPONSE_CRC) != 0) {
        debug_write("[sdmmc] CMD7 failed\r\n");
        return -10;
    }

    /* Bump the clock to a transfer-mode rate. */
    debug_write("[sdmmc] transfer clock...\r\n");
    if (set_clock_divider(1) != 0) {
        debug_write("[sdmmc] transfer clock setup failed\r\n");
        return -11;
    }

    debug_write("[sdmmc] init complete\r\n");
    return 0;
}

#define SD_BLOCK_SIZE 512u

int sd_read_block(uint32_t lba, uint8_t *buffer)
{
    mmio_write32(SDMMC0_BASE + DW_BLKSIZ, SD_BLOCK_SIZE);
    mmio_write32(SDMMC0_BASE + DW_BYTCNT, SD_BLOCK_SIZE);

    if (sd_send_command(17, lba,
                        CMD_RESPONSE_EXPECT
                        | CMD_CHECK_RESPONSE_CRC
                        | CMD_DATA_EXPECTED) != 0) {
        return -1;
    }

    /* Drain the FIFO. Wait for RX_DATA_REQ or DATA_OVER. */
    uint32_t words_read = 0;
    const uint32_t words_total = SD_BLOCK_SIZE / 4;
    uint32_t budget = 10000000;
    while (words_read < words_total) {
        uint32_t status = mmio_read32(SDMMC0_BASE + DW_STATUS);
        uint32_t fifo_count = (status & STATUS_FIFO_COUNT_MASK)
                              >> STATUS_FIFO_COUNT_SHIFT;
        if (fifo_count > 0) {
            uint32_t word = mmio_read32(SDMMC0_BASE + DW_DATA);
            buffer[words_read * 4 + 0] = (uint8_t)(word & 0xFFu);
            buffer[words_read * 4 + 1] = (uint8_t)((word >> 8) & 0xFFu);
            buffer[words_read * 4 + 2] = (uint8_t)((word >> 16) & 0xFFu);
            buffer[words_read * 4 + 3] = (uint8_t)((word >> 24) & 0xFFu);
            words_read++;
        } else if (budget-- == 0) {
            return -2;
        }
    }

    /* Wait for DATA_OVER. */
    budget = 1000000;
    while (!(mmio_read32(SDMMC0_BASE + DW_RINTSTS) & INT_DATA_OVER)) {
        if (budget-- == 0) {
            return -3;
        }
    }
    mmio_write32(SDMMC0_BASE + DW_RINTSTS, INT_DATA_OVER);
    return 0;
}

int sd_write_block(uint32_t lba, const uint8_t *buffer)
{
    mmio_write32(SDMMC0_BASE + DW_BLKSIZ, SD_BLOCK_SIZE);
    mmio_write32(SDMMC0_BASE + DW_BYTCNT, SD_BLOCK_SIZE);

    if (sd_send_command(24, lba,
                        CMD_RESPONSE_EXPECT
                        | CMD_CHECK_RESPONSE_CRC
                        | CMD_DATA_EXPECTED
                        | CMD_WRITE) != 0) {
        return -1;
    }

    /* Fill the FIFO. */
    uint32_t words_written = 0;
    const uint32_t words_total = SD_BLOCK_SIZE / 4;
    uint32_t budget = 10000000;
    while (words_written < words_total) {
        uint32_t status = mmio_read32(SDMMC0_BASE + DW_STATUS);
        uint32_t fifo_count = (status & STATUS_FIFO_COUNT_MASK)
                              >> STATUS_FIFO_COUNT_SHIFT;
        /* For a 16-entry FIFO (typical), check it's not full. The
         * exact size lives in HCON but we use a conservative
         * inequality. */
        if (fifo_count < 16) {
            uint32_t word = ((uint32_t)buffer[words_written * 4 + 0])
                          | ((uint32_t)buffer[words_written * 4 + 1] << 8)
                          | ((uint32_t)buffer[words_written * 4 + 2] << 16)
                          | ((uint32_t)buffer[words_written * 4 + 3] << 24);
            mmio_write32(SDMMC0_BASE + DW_DATA, word);
            words_written++;
        } else if (budget-- == 0) {
            return -2;
        }
    }

    /* Wait for DATA_OVER. */
    budget = 1000000;
    while (!(mmio_read32(SDMMC0_BASE + DW_RINTSTS) & INT_DATA_OVER)) {
        if (budget-- == 0) {
            return -3;
        }
    }
    mmio_write32(SDMMC0_BASE + DW_RINTSTS, INT_DATA_OVER);
    return 0;
}

int sd_init(void)
{
    return sd_initialize_card();
}
