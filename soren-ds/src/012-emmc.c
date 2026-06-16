/*
 * 012-emmc.c — internal eMMC block driver
 *
 * Brings the RK3568's dedicated SDHCI controller (at MMIO base
 * 0xFE310000) up to a state where the kernel can read and write
 * 512-byte blocks of the internal eMMC. Polled and blocking — no
 * DMA, no interrupts. Each public call is one transaction.
 *
 * The two layers:
 *
 *   1. SDHCI register dance. The host controller's register set is
 *      specified by the SD Host Controller Standard Specification.
 *      The Rockchip implementation follows that specification's
 *      offsets and bit positions. We bring the controller out of
 *      reset, set its internal clock divider to a frequency the
 *      card will accept during identification (around 400 kHz),
 *      power-cycle the card slot, then bump the clock back up to
 *      a transfer-mode rate once identification finishes.
 *
 *   2. JEDEC eMMC initialization protocol. The standard CMD0
 *      through CMD7 sequence: reset the card, ask it for its
 *      operating conditions, retrieve its identifying numbers,
 *      assign it a relative address on the bus, read its capacity
 *      information, and select it into the transfer state where
 *      single-block reads and writes work.
 *
 * Phase 1's use of this driver is exactly what 110b needs — write
 * the kernel image to the eMMC's boot partition and read it back
 * to verify. Phase 4 and beyond layer a filesystem over the same
 * block interface; the driver itself doesn't change.
 *
 * Diagnostic output through the CDC-ACM channel from 110 narrates
 * each step of bring-up. A failure leaves a descriptive message
 * on the channel and the function returns non-zero so the caller
 * can decide whether to panic.
 */

#include <stdint.h>

extern void debug_write(const char *text);

/* SDHCI controller MMIO base — per docs/016-physical-memory-map.md
 * the dedicated eMMC host on the RK3568. */
#define SDHCI_BASE         0xFE310000u

/* SDHCI register offsets from the SD Host Controller Standard
 * Specification, chapter 2. */
#define SDHCI_DMA_ADDRESS    0x00
#define SDHCI_BLOCK_SIZE     0x04  /* 16-bit */
#define SDHCI_BLOCK_COUNT    0x06  /* 16-bit */
#define SDHCI_ARGUMENT       0x08
#define SDHCI_TRANSFER_MODE  0x0C  /* 16-bit */
#define SDHCI_COMMAND        0x0E  /* 16-bit */
#define SDHCI_RESPONSE       0x10  /* 16 bytes */
#define SDHCI_BUFFER_PORT    0x20
#define SDHCI_PRESENT_STATE  0x24
#define SDHCI_HOST_CONTROL_1 0x28  /* 8-bit */
#define SDHCI_POWER_CONTROL  0x29  /* 8-bit */
#define SDHCI_CLOCK_CONTROL  0x2C  /* 16-bit */
#define SDHCI_TIMEOUT_CTRL   0x2E  /* 8-bit */
#define SDHCI_SOFT_RESET     0x2F  /* 8-bit */
#define SDHCI_INT_STATUS     0x30
#define SDHCI_INT_ENABLE     0x34
#define SDHCI_SIGNAL_ENABLE  0x38

/* Present-state bits we poll on. */
#define PSTATE_CMD_INHIBIT     (1u << 0)
#define PSTATE_DAT_INHIBIT     (1u << 1)
#define PSTATE_BUFFER_READ_RDY (1u << 11)
#define PSTATE_BUFFER_WRITE_RDY (1u << 10)

/* Clock-control bits. */
#define CLOCK_INTERNAL_EN      (1u << 0)
#define CLOCK_INTERNAL_STABLE  (1u << 1)
#define CLOCK_SD_EN            (1u << 2)
/* The divider lives in bits 15:8 plus the extended bits 7:6. We
 * use simple powers of two; 0x80 = divide-by-256, 0x01 = divide-
 * by-2, 0x00 = identity (1:1). */

/* Power-control bits. */
#define POWER_ON               (1u << 0)
#define POWER_VOLTAGE_3V3      (7u << 1)

/* Software-reset bits. */
#define SOFT_RESET_ALL         (1u << 0)
#define SOFT_RESET_CMD         (1u << 1)
#define SOFT_RESET_DAT         (1u << 2)

/* Transfer-mode bits. */
#define XFER_DAT_DIRECTION_READ (1u << 4)
#define XFER_DAT_PRESENT       (1u << 5)  /* enabled via command register */

/* Command-register encoding: bits 13:8 hold the command index,
 * bits 7:0 hold response type, data flag, and check bits. */
#define CMD_IDX(n)             ((n) << 8)
#define CMD_DATA_PRESENT       (1u << 5)
#define CMD_INDEX_CHECK        (1u << 4)
#define CMD_CRC_CHECK          (1u << 3)
#define CMD_RESPONSE_LEN_136   (1u << 0)
#define CMD_RESPONSE_LEN_48    (2u << 0)
#define CMD_RESPONSE_LEN_48_BSY (3u << 0)

/* Interrupt-status bits we watch. */
#define INT_COMMAND_COMPLETE   (1u << 0)
#define INT_XFER_COMPLETE      (1u << 1)
#define INT_BUFFER_READ_RDY    (1u << 5)
#define INT_BUFFER_WRITE_RDY   (1u << 4)
#define INT_ERROR              (1u << 15)

/* MMIO helpers. */
static inline void mmio_write32(uintptr_t a, uint32_t v) { *(volatile uint32_t *)a = v; }
static inline uint32_t mmio_read32(uintptr_t a) { return *(volatile uint32_t *)a; }
static inline void mmio_write16(uintptr_t a, uint16_t v) { *(volatile uint16_t *)a = v; }
static inline uint16_t mmio_read16(uintptr_t a) { return *(volatile uint16_t *)a; }
static inline void mmio_write8(uintptr_t a, uint8_t v) { *(volatile uint8_t *)a = v; }
static inline uint8_t mmio_read8(uintptr_t a) { return *(volatile uint8_t *)a; }

static void delay_loops(uint32_t n)
{
    while (n--) {
        __asm__ volatile ("nop");
    }
}

/* Software-reset the controller (or just CMD or DAT parts of it).
 * The reset bit clears itself when the reset completes. */
static int sdhci_reset(uint8_t which)
{
    mmio_write8(SDHCI_BASE + SDHCI_SOFT_RESET, which);
    uint32_t budget = 100000;
    while (mmio_read8(SDHCI_BASE + SDHCI_SOFT_RESET) & which) {
        if (budget-- == 0) {
            return -1;
        }
    }
    return 0;
}

/* Configure the controller's internal SD clock with a divisor.
 * `divisor` is the value placed in bits 15:8 (powers of two: 0x80
 * gives ~400 kHz from a base clock of about 200 MHz, 0x01 gives
 * the base clock divided by 2). */
static int sdhci_set_clock(uint8_t divisor)
{
    /* Stop the SD clock while changing the divisor. */
    mmio_write16(SDHCI_BASE + SDHCI_CLOCK_CONTROL, 0);

    uint16_t clk = ((uint16_t)divisor << 8) | CLOCK_INTERNAL_EN;
    mmio_write16(SDHCI_BASE + SDHCI_CLOCK_CONTROL, clk);

    /* Wait for the internal clock to stabilize. */
    uint32_t budget = 100000;
    while (!(mmio_read16(SDHCI_BASE + SDHCI_CLOCK_CONTROL) & CLOCK_INTERNAL_STABLE)) {
        if (budget-- == 0) {
            return -1;
        }
    }

    /* Now enable the SD clock to the card. */
    clk |= CLOCK_SD_EN;
    mmio_write16(SDHCI_BASE + SDHCI_CLOCK_CONTROL, clk);
    return 0;
}

/* Issue an SD/eMMC command. Returns 0 on success or non-zero on
 * error or timeout. */
static int sdhci_send_command(uint16_t cmd_reg, uint32_t arg)
{
    /* Wait for the controller to be ready to accept a new
     * command — both CMD and DAT lines must be free. */
    uint32_t budget = 100000;
    while (mmio_read32(SDHCI_BASE + SDHCI_PRESENT_STATE)
           & (PSTATE_CMD_INHIBIT | PSTATE_DAT_INHIBIT)) {
        if (budget-- == 0) {
            return -1;
        }
    }

    /* Clear interrupt status and write the command. */
    mmio_write32(SDHCI_BASE + SDHCI_INT_STATUS, 0xFFFFFFFFu);
    mmio_write32(SDHCI_BASE + SDHCI_ARGUMENT, arg);
    mmio_write16(SDHCI_BASE + SDHCI_COMMAND, cmd_reg);

    /* Wait for the command-complete interrupt status bit. */
    budget = 100000;
    while (1) {
        uint32_t status = mmio_read32(SDHCI_BASE + SDHCI_INT_STATUS);
        if (status & INT_ERROR) {
            return -2;
        }
        if (status & INT_COMMAND_COMPLETE) {
            return 0;
        }
        if (budget-- == 0) {
            return -3;
        }
    }
}

/* Read the response after a command. Some responses are 48 bits
 * (CMD3, CMD7, CMD17, CMD24), one is 136 bits (CMD2, CMD9). For
 * phase 1's modest needs we read the first response word, which
 * carries the card status for most R1 responses. */
static uint32_t sdhci_read_response_word0(void)
{
    return mmio_read32(SDHCI_BASE + SDHCI_RESPONSE);
}

/* Internal copy of the card's relative address — assigned by us
 * during initialization, used as the argument to CMD7 and any
 * command that addresses a specific card. */
static uint32_t card_rca;

/* Full initialization sequence following the JEDEC eMMC spec. */
static int emmc_initialize(void)
{
    debug_write("[emmc] resetting controller...\r\n");
    if (sdhci_reset(SOFT_RESET_ALL) != 0) {
        debug_write("[emmc] controller reset timed out\r\n");
        return -1;
    }

    /* Power the card slot at 3.3 V. */
    mmio_write8(SDHCI_BASE + SDHCI_POWER_CONTROL, POWER_VOLTAGE_3V3 | POWER_ON);
    delay_loops(100000);

    debug_write("[emmc] setting identification clock...\r\n");
    if (sdhci_set_clock(0x80) != 0) {
        debug_write("[emmc] clock stabilize timeout\r\n");
        return -2;
    }

    /* CMD0: go-idle-state. */
    debug_write("[emmc] CMD0 go-idle...\r\n");
    if (sdhci_send_command(CMD_IDX(0), 0) != 0) {
        debug_write("[emmc] CMD0 failed\r\n");
        return -3;
    }
    delay_loops(10000);

    /* CMD1: send-op-cond, asking for ~3.3 V operation. The card
     * loops back as busy until it is ready. */
    debug_write("[emmc] CMD1 send-op-cond...\r\n");
    uint32_t budget = 1000;
    while (budget--) {
        if (sdhci_send_command(CMD_IDX(1)
                               | CMD_RESPONSE_LEN_48, 0x40FF8000) != 0) {
            debug_write("[emmc] CMD1 transport failed\r\n");
            return -4;
        }
        uint32_t ocr = sdhci_read_response_word0();
        if (ocr & 0x80000000u) {
            break;
        }
        delay_loops(10000);
    }
    if (budget == 0) {
        debug_write("[emmc] CMD1 card never ready\r\n");
        return -5;
    }

    /* CMD2: all-send-cid. The response identifies the card. */
    debug_write("[emmc] CMD2 all-send-cid...\r\n");
    if (sdhci_send_command(CMD_IDX(2)
                           | CMD_RESPONSE_LEN_136 | CMD_CRC_CHECK, 0) != 0) {
        debug_write("[emmc] CMD2 failed\r\n");
        return -6;
    }

    /* CMD3: set-relative-addr. We assign RCA = 1. */
    debug_write("[emmc] CMD3 set-relative-addr...\r\n");
    card_rca = 1;
    if (sdhci_send_command(CMD_IDX(3)
                           | CMD_RESPONSE_LEN_48 | CMD_CRC_CHECK | CMD_INDEX_CHECK,
                           card_rca << 16) != 0) {
        debug_write("[emmc] CMD3 failed\r\n");
        return -7;
    }

    /* CMD9: send-csd. The CSD describes capacity, block size, and
     * timing. We don't yet parse it for phase 1's purposes — the
     * eMMC sector size is fixed at 512 bytes by the JEDEC spec. */
    debug_write("[emmc] CMD9 send-csd...\r\n");
    if (sdhci_send_command(CMD_IDX(9)
                           | CMD_RESPONSE_LEN_136 | CMD_CRC_CHECK,
                           card_rca << 16) != 0) {
        debug_write("[emmc] CMD9 failed\r\n");
        return -8;
    }

    /* CMD7: select-card. After this the card is in transfer state
     * and ready for read/write commands. */
    debug_write("[emmc] CMD7 select-card...\r\n");
    if (sdhci_send_command(CMD_IDX(7)
                           | CMD_RESPONSE_LEN_48_BSY | CMD_CRC_CHECK | CMD_INDEX_CHECK,
                           card_rca << 16) != 0) {
        debug_write("[emmc] CMD7 failed\r\n");
        return -9;
    }

    /* Bump the clock to a transfer-mode rate. Power-of-two
     * divisors only here — 0x01 gives base/2 which on this
     * controller's typical 200 MHz input is about 25 MHz, well
     * within compatibility-mode limits. High-speed switching
     * via CMD6 is left to a later issue. */
    debug_write("[emmc] switching to transfer clock...\r\n");
    if (sdhci_set_clock(0x01) != 0) {
        debug_write("[emmc] transfer-clock stabilize timeout\r\n");
        return -10;
    }

    debug_write("[emmc] init complete\r\n");
    return 0;
}

/* Block size — fixed at the eMMC standard. */
#define EMMC_BLOCK_SIZE 512u

/* Read one block. Buffer must have room for 512 bytes. */
int emmc_read_block(uint32_t lba, uint8_t *buffer)
{
    mmio_write16(SDHCI_BASE + SDHCI_BLOCK_SIZE, EMMC_BLOCK_SIZE);
    mmio_write16(SDHCI_BASE + SDHCI_BLOCK_COUNT, 1);
    mmio_write16(SDHCI_BASE + SDHCI_TRANSFER_MODE,
                 XFER_DAT_DIRECTION_READ);

    /* CMD17: read-single-block. The argument is the block address
     * — modern eMMCs use block (not byte) addressing. */
    if (sdhci_send_command(CMD_IDX(17)
                           | CMD_RESPONSE_LEN_48
                           | CMD_DATA_PRESENT
                           | CMD_CRC_CHECK | CMD_INDEX_CHECK,
                           lba) != 0) {
        return -1;
    }

    /* Wait for the buffer-read-ready state, then drain the data
     * port in 32-bit words into the caller's buffer. */
    uint32_t budget = 1000000;
    while (!(mmio_read32(SDHCI_BASE + SDHCI_PRESENT_STATE)
             & PSTATE_BUFFER_READ_RDY)) {
        if (budget-- == 0) {
            return -2;
        }
    }
    for (uint32_t i = 0; i < EMMC_BLOCK_SIZE / 4; i++) {
        uint32_t word = mmio_read32(SDHCI_BASE + SDHCI_BUFFER_PORT);
        buffer[i * 4 + 0] = (uint8_t)(word & 0xFFu);
        buffer[i * 4 + 1] = (uint8_t)((word >> 8) & 0xFFu);
        buffer[i * 4 + 2] = (uint8_t)((word >> 16) & 0xFFu);
        buffer[i * 4 + 3] = (uint8_t)((word >> 24) & 0xFFu);
    }

    /* Wait for transfer-complete. */
    budget = 1000000;
    while (!(mmio_read32(SDHCI_BASE + SDHCI_INT_STATUS) & INT_XFER_COMPLETE)) {
        if (budget-- == 0) {
            return -3;
        }
    }
    mmio_write32(SDHCI_BASE + SDHCI_INT_STATUS, INT_XFER_COMPLETE);
    return 0;
}

/* Write one block. */
int emmc_write_block(uint32_t lba, const uint8_t *buffer)
{
    mmio_write16(SDHCI_BASE + SDHCI_BLOCK_SIZE, EMMC_BLOCK_SIZE);
    mmio_write16(SDHCI_BASE + SDHCI_BLOCK_COUNT, 1);
    mmio_write16(SDHCI_BASE + SDHCI_TRANSFER_MODE, 0);  /* write direction */

    if (sdhci_send_command(CMD_IDX(24)
                           | CMD_RESPONSE_LEN_48
                           | CMD_DATA_PRESENT
                           | CMD_CRC_CHECK | CMD_INDEX_CHECK,
                           lba) != 0) {
        return -1;
    }

    uint32_t budget = 1000000;
    while (!(mmio_read32(SDHCI_BASE + SDHCI_PRESENT_STATE)
             & PSTATE_BUFFER_WRITE_RDY)) {
        if (budget-- == 0) {
            return -2;
        }
    }
    for (uint32_t i = 0; i < EMMC_BLOCK_SIZE / 4; i++) {
        uint32_t word = ((uint32_t)buffer[i * 4 + 0])
                      | ((uint32_t)buffer[i * 4 + 1] << 8)
                      | ((uint32_t)buffer[i * 4 + 2] << 16)
                      | ((uint32_t)buffer[i * 4 + 3] << 24);
        mmio_write32(SDHCI_BASE + SDHCI_BUFFER_PORT, word);
    }

    budget = 1000000;
    while (!(mmio_read32(SDHCI_BASE + SDHCI_INT_STATUS) & INT_XFER_COMPLETE)) {
        if (budget-- == 0) {
            return -3;
        }
    }
    mmio_write32(SDHCI_BASE + SDHCI_INT_STATUS, INT_XFER_COMPLETE);
    return 0;
}

/* Public entry: bring up the eMMC controller and the card. */
int emmc_init(void)
{
    return emmc_initialize();
}
