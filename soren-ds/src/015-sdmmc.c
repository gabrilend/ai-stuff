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

/* SDMMC0 data-FIFO depth, in 32-bit words: 256 for this RK3568 variant,
 * NOT the 16 an earlier PIO loop assumed. It is the depth the FIFOTH we
 * program (0x207F0080) implies — RX watermark 0x7F, so depth = (0x7F+1)*2
 * = 256 (docs/020-sdmmc0-host-controller.md). The old 16 was a safe
 * under-fill: it never overflows, it just throttled PIO writes. DMA (issue
 * 110m) is the real transfer path, so this only tightens the fallback. */
#define SD_FIFO_DEPTH    256u

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

/* The card's CSD (Card-Specific Data), 128 bits, captured verbatim from the
 * CMD9 long response during init while the card is in stand-by state (CMD9
 * is only valid there, before CMD7 selects the card). sd_csd[3] is the
 * most-significant word (CSD[127:96]) down to sd_csd[0] (CSD[31:0]);
 * sd_sector_count() decodes the card's capacity from it. */
static uint32_t sd_csd[4];

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

    /* CMD9: SEND_CSD (long response). Issued in stand-by state — the only
     * state CMD9 is valid in — both because some controllers want it before
     * the data-transfer state AND because its response IS the card's CSD,
     * which sd_sector_count() reads the capacity from. Stash the four
     * response words now; after CMD7 the card leaves stand-by and CMD9 can
     * no longer be re-issued cleanly. */
    debug_write("[sdmmc] CMD9 send-csd...\r\n");
    if (sd_send_command(9, sd_card_rca << 16,
                        CMD_RESPONSE_EXPECT
                        | CMD_RESPONSE_LENGTH_LONG
                        | CMD_CHECK_RESPONSE_CRC) != 0) {
        debug_write("[sdmmc] CMD9 failed\r\n");
        return -9;
    }
    sd_csd[0] = mmio_read32(SDMMC0_BASE + DW_RESP0);
    sd_csd[1] = mmio_read32(SDMMC0_BASE + DW_RESP1);
    sd_csd[2] = mmio_read32(SDMMC0_BASE + DW_RESP2);
    sd_csd[3] = mmio_read32(SDMMC0_BASE + DW_RESP3);

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
        /* Fill while the FIFO has room (depth SD_FIFO_DEPTH words). */
        if (fifo_count < SD_FIFO_DEPTH) {
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

/* {{{ sd_log_byte() — log "label=0xXX" for a single byte */
static void sd_log_byte(const char *label, uint8_t v)
{
    static const char d[] = "0123456789ABCDEF";
    char b[5];
    b[0] = '0'; b[1] = 'x';
    b[2] = d[(v >> 4) & 0xFu];
    b[3] = d[v & 0xFu];
    b[4] = 0;
    debug_write(label);
    debug_write(b);
    debug_write("\r\n");
}
/* }}} */

/* {{{ sd_read_small() — a command with a small data-phase read
 * Like sd_read_block, but for the few-byte register reads the capability
 * probe needs (SCR 8B, SD_STATUS 64B, SWITCH_FUNC 64B): set the byte
 * count, fire the command with DATA_EXPECTED, drain that many bytes out
 * of the FIFO, wait for DATA_OVER. */
static int sd_read_small(uint32_t index, uint32_t arg, uint32_t flags,
                         uint8_t *buf, uint32_t bytes)
{
    mmio_write32(SDMMC0_BASE + DW_BLKSIZ, bytes);
    mmio_write32(SDMMC0_BASE + DW_BYTCNT, bytes);
    if (sd_send_command(index, arg, flags | CMD_DATA_EXPECTED) != 0) {
        return -1;
    }
    uint32_t words = (bytes + 3u) / 4u;
    uint32_t got = 0;
    uint32_t budget = 10000000;
    while (got < words) {
        uint32_t status = mmio_read32(SDMMC0_BASE + DW_STATUS);
        uint32_t fc = (status & STATUS_FIFO_COUNT_MASK) >> STATUS_FIFO_COUNT_SHIFT;
        if (fc > 0) {
            uint32_t w = mmio_read32(SDMMC0_BASE + DW_DATA);
            buf[got * 4 + 0] = (uint8_t)(w & 0xFFu);
            buf[got * 4 + 1] = (uint8_t)((w >> 8) & 0xFFu);
            buf[got * 4 + 2] = (uint8_t)((w >> 16) & 0xFFu);
            buf[got * 4 + 3] = (uint8_t)((w >> 24) & 0xFFu);
            got++;
        } else if (budget-- == 0) {
            return -2;
        }
    }
    budget = 1000000;
    while (!(mmio_read32(SDMMC0_BASE + DW_RINTSTS) & INT_DATA_OVER)) {
        if (budget-- == 0) {
            return -3;
        }
    }
    mmio_write32(SDMMC0_BASE + DW_RINTSTS, INT_DATA_OVER);
    return 0;
}
/* }}} */

/* {{{ sd_probe_capabilities() — read what the card can do (issue 110l)
 *
 * The "dynamically probe the card" step for the SD fast path: before we
 * ever switch the card to a faster mode, ask it what it supports — the
 * same shape as reading the eMMC's EXT_CSD before HS200. Three tiny
 * data-phase reads:
 *   - SCR (ACMD51, 8B): SD spec version and bus widths (is 4-bit there?).
 *   - SD_STATUS (ACMD13, 64B): the card's WRITE speed class and UHS
 *     grade — the card's own sustained-write ceiling, which together
 *     with the bus rate and the host's top mode are the three speeds we
 *     take the lowest of.
 *   - SWITCH_FUNC query (CMD6 mode 0, 64B): which access modes the card
 *     offers (SDR12 / HS-SDR25 / SDR50 / SDR104 / DDR50).
 *
 * Read-only: CMD6 mode 0 only QUERIES, it does not switch. Each field is
 * logged as a raw byte next to its decode, because the exact bit/byte
 * offsets are easy to get wrong blind and the raw byte is ground truth
 * (it also confirms the controller's FIFO byte order). The actual mode
 * switch is the next stage of 110l. */
void sd_probe_capabilities(void)
{
    static uint8_t buf[64];
    int rc;

    debug_write("[sdmmc] --- card capability probe ---\r\n");

    /* SCR via ACMD51 (CMD55 first — it is an application command). */
    if (sd_send_command(55, sd_card_rca << 16,
                        CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC) == 0) {
        rc = sd_read_small(51, 0,
                           CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC, buf, 8);
        sd_log_byte("[sdmmc] SCR rc=", (uint8_t)rc);
        if (rc == 0) {
            sd_log_byte("[sdmmc]   SCR[0] (low nibble = SD_SPEC)=", buf[0]);
            sd_log_byte("[sdmmc]   SCR[1] (bit2 = 4-bit bus)=", buf[1]);
            debug_write((buf[1] & 0x04u)
                        ? "[sdmmc]   -> 4-bit bus supported\r\n"
                        : "[sdmmc]   -> 4-bit NOT advertised\r\n");
            /* SCR[2] bit7 = SD_SPEC3: with SD_SPEC=2 it distinguishes an
             * SD 3.0+ (UHS-capable) card from a plain SD 2.0. Without this
             * byte you cannot tell a UHS card from a High-Speed-only one at
             * 3.3V, because the SWITCH_FUNC group-1 view shows only the
             * 3.3V modes either way (the 110l capability-decode gap). */
            sd_log_byte("[sdmmc]   SCR[2] (bit7 = SD_SPEC3)=", buf[2]);
            debug_write((buf[2] & 0x80u)
                        ? "[sdmmc]   -> SD 3.0+ (UHS-capable spec generation)\r\n"
                        : "[sdmmc]   -> SD 2.0 (no UHS)\r\n");
        }
    }

    /* SD_STATUS via ACMD13 (CMD55 first). */
    if (sd_send_command(55, sd_card_rca << 16,
                        CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC) == 0) {
        rc = sd_read_small(13, 0,
                           CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC, buf, 64);
        sd_log_byte("[sdmmc] SD_STATUS rc=", (uint8_t)rc);
        if (rc == 0) {
            /* SPEED_CLASS byte 8 (0..4 = Class 0/2/4/6/10); UHS grade in
             * byte 14 high nibble (1 = U1 10MB/s, 3 = U3 30MB/s); video
             * class byte 16. The card's guaranteed write rate is here. */
            sd_log_byte("[sdmmc]   SPEED_CLASS[8]=", buf[8]);
            sd_log_byte("[sdmmc]   UHS_GRADE[14]=", buf[14]);
            /* Decode the HIGH nibble (the low nibble is UHS_AU_SIZE): e.g.
             * 0x39 -> grade 3 = U3. Logging the raw byte alone reads like
             * "0x39" and invites misreading a U3 card as non-UHS. */
            debug_write((buf[14] >> 4) == 3u
                        ? "[sdmmc]   -> UHS grade U3 (>=30 MB/s sustained write)\r\n"
                      : (buf[14] >> 4) == 1u
                        ? "[sdmmc]   -> UHS grade U1 (>=10 MB/s)\r\n"
                        : "[sdmmc]   -> UHS grade 0 (no UHS speed class)\r\n");
            sd_log_byte("[sdmmc]   VIDEO_CLASS[16]=", buf[16]);
        }
    }

    /* SWITCH_FUNC query (CMD6 mode 0 — not an app command, no CMD55). */
    rc = sd_read_small(6, 0x00FFFFFFu,
                       CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC, buf, 64);
    sd_log_byte("[sdmmc] SWITCH_FUNC query rc=", (uint8_t)rc);
    if (rc == 0) {
        /* Access-mode support bitmap at byte 13: bit0 SDR12, bit1
         * HS/SDR25, bit2 SDR50, bit3 SDR104, bit4 DDR50. */
        sd_log_byte("[sdmmc]   GRP1_SUPPORT[12]=", buf[12]);
        sd_log_byte("[sdmmc]   GRP1_SUPPORT[13]=", buf[13]);
        uint8_t s = buf[13];
        debug_write("[sdmmc]   modes:");
        if (s & 0x01u) debug_write(" SDR12");
        if (s & 0x02u) debug_write(" HS/SDR25");
        if (s & 0x04u) debug_write(" SDR50");
        if (s & 0x08u) debug_write(" SDR104");
        if (s & 0x10u) debug_write(" DDR50");
        debug_write("\r\n");
    }

    debug_write("[sdmmc] --- end capability probe ---\r\n");
}
/* }}} */

/* {{{ sd_log_hex32() — log "label=0xXXXXXXXX" */
static void sd_log_hex32(const char *label, uint32_t v)
{
    static const char d[] = "0123456789ABCDEF";
    char b[11];
    b[0] = '0'; b[1] = 'x';
    for (int i = 0; i < 8; i++) {
        b[2 + i] = d[(v >> ((7 - i) * 4)) & 0xFu];
    }
    b[10] = 0;
    debug_write(label);
    debug_write(b);
    debug_write("\r\n");
}
/* }}} */

/* {{{ microSD IDMAC (DMA) read — issue 110m
 *
 * The DW MSHC's Internal DMA Controller moves data between the card and a
 * RAM buffer described by a descriptor, instead of the CPU draining the
 * FIFO word by word. Distilled from RK3568 TRM 6.3.3 (see issue 110m):
 *   - descriptor (32-bit, 16 bytes): DES0 control (OWN|FS|LD), DES1 size
 *     (BS1[12:0], <= 8 KB), DES2 buffer address, DES3 next/buffer-2.
 *   - CTRL bit25 enables the IDMAC; BMOD @0x80 bus mode (SWR/FB/DE);
 *     DBADDR @0x88 descriptor base; completion shows as DATA_OVER.
 * When the IDMAC is enabled the FIFO can't be reached through the slave
 * path, so we disable it again after the transfer so the PIO calls work. */
#define DW_BMOD                 0x80
#define DW_DBADDR               0x88
#define DW_IDINTEN              0x90
#define CTRL_USE_INTERNAL_DMAC  (1u << 25)
#define BMOD_SWR                (1u << 0)
#define BMOD_FB                 (1u << 1)
#define BMOD_DE                 (1u << 7)
#define IDMAC_DES0_LD           (1u << 2)
#define IDMAC_DES0_FS           (1u << 3)
#define IDMAC_DES0_CH           (1u << 4)   /* DES3 is the next-descriptor address (chained) */
#define IDMAC_DES0_OWN          (1u << 31)
#define CMD_SEND_AUTO_STOP      (1u << 12)  /* DW MSHC CMD reg: auto-CMD12 after a multi-block */
#define IDMAC_DESC_MAX_BYTES    4096u       /* 8 blocks/descriptor; BS1 is 13-bit (<= 8191 bytes) */
#define SD_IDMAC_MAX_DESC       20u         /* covers a 128-block dump chunk (16 descriptors) + margin */

struct idmac_desc {
    uint32_t des0;   /* control: OWN(31) FS(3) LD(2) */
    uint32_t des1;   /* BS1[12:0] buffer-1 byte size */
    uint32_t des2;   /* buffer-1 physical address */
    uint32_t des3;   /* next desc / buffer-2 (unused for one descriptor) */
};
static struct idmac_desc sd_idmac_table[SD_IDMAC_MAX_DESC] __attribute__((aligned(8)));

/* Multi-block SD write via the IDMAC — the dump's write side. One CMD25
 * (WRITE_MULTIPLE_BLOCK) writes the whole run; a chain of descriptors
 * (each <= 8 KB, the 13-bit BS1 limit) describes the RAM buffer, and the
 * controller's auto-stop sends the trailing CMD12. This amortizes the
 * command + engine setup over the run instead of paying it per block.
 * `count` up to SD_IDMAC_MAX_DESC * 8 blocks. Returns 0 on success. */
int sd_write_blocks_dma(uint32_t lba, uint32_t count, const uint8_t *buffer)
{
    if (count == 0u) {
        return 0;
    }
    uint32_t total_bytes = count * SD_BLOCK_SIZE;
    uint32_t ndesc = (total_bytes + IDMAC_DESC_MAX_BYTES - 1u) / IDMAC_DESC_MAX_BYTES;
    if (ndesc > SD_IDMAC_MAX_DESC) {
        return -10;                                       /* run too big for the table */
    }

    /* Build the descriptor chain: each covers up to 8 KB of the buffer,
     * DES3 points at the next, FS on the first, LD on the last. */
    uint32_t off = 0;
    for (uint32_t i = 0; i < ndesc; i++) {
        uint32_t bytes = (total_bytes - off < IDMAC_DESC_MAX_BYTES)
                         ? (total_bytes - off) : IDMAC_DESC_MAX_BYTES;
        uint32_t d0 = IDMAC_DES0_OWN | IDMAC_DES0_CH;
        if (i == 0u)          d0 |= IDMAC_DES0_FS;
        if (i == ndesc - 1u)  d0 |= IDMAC_DES0_LD;
        sd_idmac_table[i].des0 = d0;
        sd_idmac_table[i].des1 = bytes;                   /* BS1 */
        sd_idmac_table[i].des2 = (uint32_t)(uintptr_t)(buffer + off);
        sd_idmac_table[i].des3 = (i == ndesc - 1u)
                                 ? 0u
                                 : (uint32_t)(uintptr_t)&sd_idmac_table[i + 1u];
        off += bytes;
    }

    uint32_t ctrl = mmio_read32(SDMMC0_BASE + DW_CTRL);

    /* Reset, then enable the IDMAC and point it at the head of the chain. */
    mmio_write32(SDMMC0_BASE + DW_BMOD, BMOD_SWR);
    delay_loops(1000);
    mmio_write32(SDMMC0_BASE + DW_CTRL, ctrl | CTRL_USE_INTERNAL_DMAC);
    mmio_write32(SDMMC0_BASE + DW_IDINTEN, 0);
    mmio_write32(SDMMC0_BASE + DW_DBADDR, (uint32_t)(uintptr_t)sd_idmac_table);
    mmio_write32(SDMMC0_BASE + DW_BMOD, BMOD_DE | BMOD_FB);

    mmio_write32(SDMMC0_BASE + DW_BLKSIZ, SD_BLOCK_SIZE);
    mmio_write32(SDMMC0_BASE + DW_BYTCNT, total_bytes);

    int rc = 0;
    if (sd_send_command(25, lba,                          /* WRITE_MULTIPLE_BLOCK */
                        CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC
                        | CMD_DATA_EXPECTED | CMD_WRITE | CMD_SEND_AUTO_STOP) != 0) {
        rc = -1;
    } else {
        /* The IDMAC streams the whole run RAM->card; wait for DATA_OVER
         * (the auto-stop CMD12 follows), watching the error mask. */
        uint32_t budget = 20000000;
        for (;;) {
            uint32_t rint = mmio_read32(SDMMC0_BASE + DW_RINTSTS);
            if (rint & INT_ERROR_MASK) {
                sd_log_hex32("[sdmmc]   IDMAC multi-write error RINTSTS=", rint);
                rc = -2;
                break;
            }
            if (rint & INT_DATA_OVER) {
                break;
            }
            if (budget-- == 0u) {
                rc = -3;
                break;
            }
        }
        mmio_write32(SDMMC0_BASE + DW_RINTSTS, INT_DATA_OVER);
    }

    /* Disable the IDMAC so the PIO (slave-FIFO) calls work again. */
    mmio_write32(SDMMC0_BASE + DW_BMOD, 0);
    mmio_write32(SDMMC0_BASE + DW_CTRL, ctrl);
    return rc;
}

/* Validate the IDMAC WRITE — the direction the eMMC dump actually needs.
 * Plain PIO writes are already proven (every boot's debug log, and the
 * backup); what's unproven is the DMA *engine*. Fill a buffer with a
 * non-zero, position-dependent pattern, write it to a safe reserved SD
 * region via the IDMAC, read it back through the proven PIO path, and
 * compare BYTE FOR BYTE — plus an explicit "read-back isn't all zeros"
 * guard. (An earlier version compared a weak fingerprint that folded a
 * structured pattern to 0, so "0 == 0" passed vacuously; a byte compare
 * with a non-zero guard can't be fooled that way.) The first word of each
 * buffer is logged raw so the pattern is visible in the log. */
#define SD_DMA_TEST_LBA    0x300000u  /* reserved: clear of boot, backup (0x200000), log (0x400000) */
#define SD_DMA_TEST_BLOCKS 24u        /* 24 blocks = 3 chained IDMAC descriptors (8 each) -> exercises a middle link */
static uint8_t sd_dma_wr_buf[SD_DMA_TEST_BLOCKS * SD_BLOCK_SIZE] __attribute__((aligned(8)));
static uint8_t sd_dma_rb_buf[SD_DMA_TEST_BLOCKS * SD_BLOCK_SIZE] __attribute__((aligned(8)));

static uint32_t sd_word0(const uint8_t *b)
{
    return ((uint32_t)b[0]) | ((uint32_t)b[1] << 8)
         | ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

/* Validate the multi-block IDMAC WRITE (the dump's write path) — fill a
 * 24-block buffer with a non-zero position-dependent pattern, write it in
 * one chained CMD25, read it all back through the proven PIO path, and
 * compare byte for byte (with a non-zero guard). 24 blocks spans three
 * chained descriptors, so a broken chain link shows up. */
void sd_dma_write_test(void)
{
    uint32_t nbytes = SD_DMA_TEST_BLOCKS * SD_BLOCK_SIZE;
    debug_write("[sdmmc] --- IDMAC multi-block write test (24 blocks, DMA write -> PIO read-back) ---\r\n");
    for (uint32_t i = 0; i < nbytes; i++) {
        sd_dma_wr_buf[i] = (uint8_t)(0xA5u ^ (i * 13u));   /* non-zero, position-dependent */
        sd_dma_rb_buf[i] = 0u;                             /* so a no-op read shows as zeros */
    }
    int rw = sd_write_blocks_dma(SD_DMA_TEST_LBA, SD_DMA_TEST_BLOCKS, sd_dma_wr_buf);
    int rr = 0;
    for (uint32_t b = 0; b < SD_DMA_TEST_BLOCKS && rr == 0; b++) {
        rr = sd_read_block(SD_DMA_TEST_LBA + b, sd_dma_rb_buf + b * SD_BLOCK_SIZE);
    }

    int match = 1, nonzero = 0;
    for (uint32_t i = 0; i < nbytes; i++) {
        if (sd_dma_rb_buf[i] != sd_dma_wr_buf[i]) match = 0;
        if (sd_dma_rb_buf[i] != 0u) nonzero = 1;
    }

    sd_log_byte("[sdmmc]   DMA multi-write rc=", (uint8_t)rw);
    sd_log_byte("[sdmmc]   PIO read-back rc=", (uint8_t)rr);
    sd_log_hex32("[sdmmc]   wrote    [0..3]=", sd_word0(sd_dma_wr_buf));
    sd_log_hex32("[sdmmc]   readback [0..3]=", sd_word0(sd_dma_rb_buf));
    if (rw == 0 && rr == 0 && match && nonzero) {
        debug_write("[sdmmc]   IDMAC MULTI-BLOCK WRITE OK (24 blocks read back correct)\r\n");
    } else if (!nonzero) {
        debug_write("[sdmmc]   INCONCLUSIVE: read-back all zeros (DMA write did not land)\r\n");
    } else {
        debug_write("[sdmmc]   IDMAC MULTI-BLOCK WRITE MISMATCH\r\n");
    }
}
/* }}} */

/* {{{ dynamic SD speed select — pick the safe minimum and apply it (110l)
 *
 * Instead of hardcoding a bus speed, read what the card supports, compare
 * it to the host's ceiling at the current signalling voltage, and switch
 * the bus to the safe minimum of the two — logging all the inputs and the
 * choice so the decision is visible (that visibility is the point; a fixed
 * speed tells us nothing). At 3.3 V (no voltage switch yet) the host
 * ceiling is High-Speed (50 MHz); UHS (SDR50/104) needs a 1.8 V switch,
 * and the card only advertises UHS after that anyway. So the picker lands
 * on the fastest of {default, High-Speed} the card offers, at 4-bit if the
 * card has it — and extends to UHS for free once the voltage switch
 * exists: same min-of-ceilings logic, one more ceiling. */

/* ACMD6 SET_BUS_WIDTH to 4-bit (arg 2), then the DW MSHC CTYPE to 4-bit. */
static int sd_set_bus_width_4bit(void)
{
    if (sd_send_command(55, sd_card_rca << 16,
                        CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC) != 0) {
        return -1;
    }
    if (sd_send_command(6, 0x2u,                       /* ACMD6 arg 2 = 4-bit */
                        CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC) != 0) {
        return -2;
    }
    mmio_write32(SDMMC0_BASE + DW_CTYPE, 1u);          /* card 0 -> 4-bit */
    return 0;
}

/* CMD6 SWITCH_FUNC (mode 1 = set) group 1 -> function 1 (High-Speed), then
 * raise the host clock to 50 MHz (CLKDIV divisor 0 = f_src, undivided). */
static int sd_switch_high_speed(void)
{
    static uint8_t status[64];
    int rc = sd_read_small(6, 0x80FFFFF1u,             /* set group1=HS, other groups no-change */
                           CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC, status, 64);
    if (rc != 0) {
        return rc;
    }
    return set_clock_divider(0);                        /* 50 MHz */
}

/* {{{ sd_sector_count() — card capacity in 512-byte sectors, from the CSD */
/* Decode the card's capacity from the CSD captured at init. Only the CSD
 * version-2 layout (SDHC/SDXC — every card larger than 2 GB) is decoded,
 * which is all a modern dump target will be. Returns 0 for "unknown" (not
 * v2, or an implausible result) so callers fall back rather than trust a
 * bad number.
 *
 * CSD v2 (SD Physical Layer spec, CSD Register Version 2.0):
 *   CSD_STRUCTURE = CSD[127:126]   (1 = version 2)
 *   C_SIZE        = CSD[69:48]     (22 bits)
 *   capacity      = (C_SIZE + 1) x 512 KB = (C_SIZE + 1) x 1024 sectors
 * With sd_csd[3]=CSD[127:96] down to sd_csd[0]=CSD[31:0]:
 *   CSD_STRUCTURE = sd_csd[3] >> 30
 *   C_SIZE        = ((sd_csd[2] & 0x3F) << 16) | (sd_csd[1] >> 16)
 *
 * The raw words are logged next to the decode on purpose: the bit/byte
 * alignment of a long response out of this controller is exactly the kind
 * of thing that is easy to get wrong blind, so the first hardware run must
 * confirm the printed capacity matches the known card before this number is
 * trusted to gate a real transfer. Until then a caller treats 0 as unknown
 * and falls back loudly. */
uint32_t sd_sector_count(void)
{
    uint32_t structure = sd_csd[3] >> 30;
    uint32_t c_size    = ((sd_csd[2] & 0x3Fu) << 16) | (sd_csd[1] >> 16);
    uint32_t sectors   = (structure == 1u) ? ((c_size + 1u) * 1024u) : 0u;

    debug_write("[sdmmc] --- SD capacity (from CSD) ---\r\n");
    sd_log_hex32("[sdmmc]   CSD[127:96]=", sd_csd[3]);
    sd_log_hex32("[sdmmc]   CSD[95:64] =", sd_csd[2]);
    sd_log_hex32("[sdmmc]   CSD[63:32] =", sd_csd[1]);
    sd_log_hex32("[sdmmc]   CSD[31:0]  =", sd_csd[0]);
    sd_log_hex32("[sdmmc]   CSD_STRUCTURE=", structure);
    sd_log_hex32("[sdmmc]   C_SIZE=", c_size);
    sd_log_hex32("[sdmmc]   -> sectors=", sectors);

    /* Sanity floor: any real dump-target card dwarfs ~512 MB. Below it, the
     * decode (or the card) is wrong — report unknown so the caller falls
     * back loudly instead of truncating a good dump on a bad number. */
    if (sectors != 0u && sectors < 0x00100000u) {
        debug_write("[sdmmc]   CSD decode implausible -> capacity UNKNOWN\r\n");
        return 0u;
    }
    return sectors;
}
/* }}} */

/* The picker: read the card's ceilings, weigh against the host's, apply
 * the safe minimum. */
void sd_select_speed(void)
{
    static uint8_t buf[64];
    int four_bit = 0, high_speed = 0;

    debug_write("[sdmmc] --- dynamic speed select ---\r\n");

    /* Card ceilings: SCR bit2 = 4-bit support; SWITCH_FUNC query group-1
     * byte 13 bit1 = High-Speed support. */
    if (sd_send_command(55, sd_card_rca << 16,
                        CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC) == 0
        && sd_read_small(51, 0,
                         CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC, buf, 8) == 0) {
        four_bit = (buf[1] & 0x04u) ? 1 : 0;
    }
    if (sd_read_small(6, 0x00FFFFFFu,
                      CMD_RESPONSE_EXPECT | CMD_CHECK_RESPONSE_CRC, buf, 64) == 0) {
        high_speed = (buf[13] & 0x02u) ? 1 : 0;
    }

    debug_write(four_bit ? "[sdmmc]   card width: 4-bit"
                         : "[sdmmc]   card width: 1-bit only");
    debug_write(high_speed ? ", card speed: up to High-Speed\r\n"
                           : ", card speed: default only\r\n");
    debug_write("[sdmmc]   host ceiling @3.3V: High-Speed (UHS needs 1.8V switch, not built)\r\n");

    /* Apply the safe minimum. */
    if (four_bit) {
        debug_write((sd_set_bus_width_4bit() == 0)
                    ? "[sdmmc]   -> applied: 4-bit bus\r\n"
                    : "[sdmmc]   -> 4-bit switch FAILED\r\n");
    }
    if (high_speed) {
        debug_write((sd_switch_high_speed() == 0)
                    ? "[sdmmc]   -> applied: High-Speed (50 MHz)\r\n"
                    : "[sdmmc]   -> High-Speed switch FAILED\r\n");
    } else {
        debug_write("[sdmmc]   -> staying at default speed (25 MHz)\r\n");
    }
    debug_write("[sdmmc] --- speed select done ---\r\n");
}
/* }}} */

int sd_init(void)
{
    return sd_initialize_card();
}
