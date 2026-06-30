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

/* Main clock-and-reset unit register pairs that feed the eMMC
 * controller. The five eMMC clocks (ACLK / HCLK / BCLK / CCLK /
 * TCLK) live at CLKGATE_CON(9) bits 5-9; the five matching
 * soft-resets live at SOFTRST_CON(7) at the same bit positions.
 * The chip-family write-mask convention applies: upper sixteen
 * bits mask which lower-sixteen bits change. See
 * docs/017-clocks-and-timers.md for the catalogue. */
#define CRU_CLKGATE_CON_9  0xFDD20324u
#define CRU_SOFTRST_CON_7  0xFDD2041Cu
#define EMMC_CLOCK_BITS    0x03E0u    /* bits 5-9 cover all 5 clocks */

/* CCLK_EMMC source mux — CLKSEL_CON(28) at 0xFDD20170, field
 * cclk_emmc_sel in bits 14:12. On the SD-boot path the bootloader
 * never configures this mux, so it sits at its 24 MHz reset
 * default (sel=000) even though the SDHCI CAPABILITIES register
 * advertises a 200 MHz base clock. Our SDHCI clock-divider math
 * assumes the advertised 200 MHz, so without setting the mux the
 * actual card clock runs ~8x too slow. We set sel=001
 * (clk_gpll_div_200m) so the real base matches the advertised
 * one. Confirmed against RK3568 TRM Part 1 Chapter 2 — see
 * docs/017-clocks-and-timers.md. */
#define CRU_CLKSEL_CON_28  0xFDD20170u
#define CCLK_EMMC_SEL_MASK (0x7u << 12)
/* CCLK_EMMC source mux options (cclk_emmc_sel, bits 14:12). The
 * mux selects a pre-divided tap directly — there is no separate
 * divider field. We drive CCLK_EMMC *itself* at the card clock
 * rate, matching u-boot's rockchip_sdhci.c (which uses
 * clk_set_rate on this clock rather than the SDHCI internal
 * divider). This sidesteps the open question of whether the
 * dwcmshc honours the SDHCI divider at all — with the card clock
 * coming straight from CCLK, the divider value no longer
 * matters. */
#define CCLK_EMMC_SEL_24M  (0x0u << 12)  /* xin_osc0 — 24 MHz, transfer (legacy <=26 MHz) */
#define CCLK_EMMC_SEL_375K (0x5u << 12)  /* clk_osc0_div_375k — identification */

/* SDHCI capabilities register — the diagnostic discriminator we
 * read after CRU bring-up. A successful read sees a non-zero
 * value; 0x00000000 means the BCLK reset is still asserted;
 * 0xFFFFFFFF means the AHB clock is still gated. */
#define SDHCI_CAPABILITIES 0x40

/* dwcmshc vendor-area offsets. The Rockchip variant of the
 * SDHCI controller carries a few extra registers at base+0x500
 * for the host-control-3 register and base+0x808/0x80C for the
 * DLL phase shifters. Bring-up only needs three clearing writes
 * to unstick any state u-boot left behind; the DLL itself stays
 * untouched until a later issue brings up HS200/HS400. */
#define DWCMSHC_HOST_CTRL3       (0x500 + 0x08)  /* offset 0x508 */
#define DWCMSHC_EMMC_CONTROL     0x52C
#define DWCMSHC_EMMC_DLL_CTRL    0x800
#define DWCMSHC_EMMC_DLL_RXCLK   0x804
#define DWCMSHC_EMMC_DLL_TXCLK   0x808
#define DWCMSHC_EMMC_DLL_STRBIN  0x80C

/* DWCMSHC_EMMC_CONTROL (EMMC_EMMC_CTRL, 0x52C) bits — now
 * confirmed against RK3568 TRM Part 2 Chapter 7. Reset value
 * 0x0C (bits 2 and 3 set). See docs/018-emmc-host-controller.md.
 *
 *   bit 0  CARD_IS_EMMC — tells the dwcmshc the connected device
 *          follows the eMMC spec rather than the SD spec. Reset 0,
 *          so we must set it.
 *   bit 1  DISABLE_DATA_CRC_CHK — bus-test only; leave 0.
 *   bit 2  EMMC_RST_N — card hardware-reset output. Reset value 1
 *          = reset DEASSERTED (card running). An earlier theory
 *          that the card was being held in reset was WRONG: this
 *          bit is 1 at reset, so the card is not held in reset.
 *          (The earlier code guessed "HW_RESET = bit 12", which
 *          is actually the CQE prefetch field — unrelated.)
 *   bit 3  EMMC_RST_N_OE — reset-pin output enable. Reset 1.
 *   bit 8  ENH_STROBE_ENABLE — HS400 only.
 *
 * The card never being held in reset means the floating-bus
 * 0xFFFFFFFF symptom is NOT a card-reset problem. Its real cause
 * is the RX clock inversion documented at DWCMSHC_EMMC_DLL_RXCLK
 * below. */
#define DWCMSHC_CARD_IS_EMMC (1u << 0)
#define DWCMSHC_EMMC_RST_N    (1u << 2)  /* card hardware-reset output (1=deasserted) */
#define DWCMSHC_EMMC_RST_N_OE (1u << 3)  /* reset-pin output enable */

/* DLL configuration for the low-speed identification clock.
 *
 * THE missing piece, found by reading u-boot's rockchip_sdhci.c
 * (the driver that successfully probes this exact eMMC). At card
 * clocks below 100 MHz the DLL cannot lock, and the dwcmshc will
 * not generate valid sample/drive clocks unless the DLL is put
 * into BYPASS mode with the START bit set. Writing the DLL
 * registers to 0 (as earlier versions did) leaves the
 * sample/drive clock path dead, so the card never sees a usable
 * clock and never responds — the floating-bus 0xFFFFFFFF symptom.
 *
 * u-boot's rk3568 config_dll for clock < 100 MHz writes exactly:
 *   DLL_CTRL   = BYPASS | START          = 0x01000001
 *   DLL_RXCLK  = ORI_GATE                = 0x80000000
 *   DLL_TXCLK  = 0
 *   DLL_STRBIN = DLYENA | DELAY_NUM_SEL | (0x10 << 16) = 0x0C100000
 *
 * (Note: DLL_RXCLK bit 31 / ORI_GATE is marked "reserved" in the
 * TRM register table, but u-boot writes it and the hardware needs
 * it — the working driver is ground truth over the doc here.) */
#define DWCMSHC_DLL_START              (1u << 0)
#define DWCMSHC_DLL_BYPASS             (1u << 24)
#define DWCMSHC_DLL_DLYENA             (1u << 27)
#define DWCMSHC_DLL_RXCLK_ORI_GATE     (1u << 31)
#define DWCMSHC_DLL_STRBIN_DELAY_SEL   (1u << 26)
#define DWCMSHC_DLL_STRBIN_DELAY_NUM   (0x10u << 16)

#define DWCMSHC_DLL_CTRL_LOWSPEED   (DWCMSHC_DLL_BYPASS | DWCMSHC_DLL_START)
#define DWCMSHC_DLL_RXCLK_LOWSPEED  (DWCMSHC_DLL_RXCLK_ORI_GATE)
#define DWCMSHC_DLL_STRBIN_LOWSPEED (DWCMSHC_DLL_DLYENA \
                                     | DWCMSHC_DLL_STRBIN_DELAY_SEL \
                                     | DWCMSHC_DLL_STRBIN_DELAY_NUM)
#define DWCMSHC_HW_RESET     (1u << 12)

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

/* Power-control bits. The slot voltage selector lives in bits
 * 3:1 of the POWER_CONTROL register: 111 = 3.3V, 110 = 3.0V,
 * 101 = 1.8V. The first phase-1 hardware test (whose CAPABILITIES
 * register read returned 0x226DC881) confirmed this board's
 * slot supports only 3.0V — bit 25 set, bits 24 and 26 clear.
 * Writing 3.3V to POWER_CONTROL on a slot that doesn't support
 * 3.3V results in the slot not powering up at all, the card
 * having no VCC, and every command silently going into a dead
 * bus. So 3.0V is what we use. */
#define POWER_ON               (1u << 0)
#define POWER_VOLTAGE_3V3      (7u << 1)  /* 0x0E — historical, unused */
#define POWER_VOLTAGE_3V0      (6u << 1)  /* 0x0C — the one this slot supports */
#define POWER_VOLTAGE_1V8      (5u << 1)  /* 0x0A — for HS200/HS400 later */

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

/* Push a single 32-bit word through debug_write as
 * `0xXXXXXXXX\r\n`. Used during bring-up debugging to dump
 * register contents. */
static void debug_write_hex32(uint32_t value)
{
    static const char *digits = "0123456789ABCDEF";
    char buf[13];
    buf[0]  = '0';
    buf[1]  = 'x';
    for (int i = 0; i < 8; i++) {
        buf[2 + i] = digits[(value >> ((7 - i) * 4)) & 0xFu];
    }
    buf[10] = '\r';
    buf[11] = '\n';
    buf[12] = '\0';
    debug_write(buf);
}

/* Route the eMMC pins to the eMMC controller. On the SD-card
 * boot path the bootloader never uses the eMMC, so it never
 * touches the eMMC pin multiplexer either — the eight data
 * lines, CLK, CMD, DataStrobe, and RSTn arrive at our kernel
 * still wired to the GPIO function. The SDHCI controller can
 * issue commands and drive its internal state perfectly, but
 * the pads it drives aren't connected to the eMMC die on the
 * other side of the package, so the card never sees anything
 * and every response register reads back as the all-ones
 * floating-bus pattern.
 *
 * Pin assignments come directly from the rk3568-anbernic-rg-ds
 * device tree's pinctrl/emmc section. All pins live in GPIO1
 * and route to function 1 on the IOMUX:
 *
 *   GPIO1_B4..B7 + GPIO1_C0..C3 — data lines D0..D7
 *   GPIO1_C4                    — CMD
 *   GPIO1_C5                    — CLK
 *   GPIO1_C6                    — DataStrobe
 *   GPIO1_C7                    — RSTn
 *
 * The IOMUX registers live in the main GRF at 0xFDC6_0000;
 * each register covers four pins. The Rockchip write-mask
 * convention applies: upper 16 bits select which lower 16
 * bits change. Within each pin's nibble, bits 2:0 hold the
 * function selector and bit 3 is a per-pin reserved/config
 * slot we deliberately leave alone — mask 0x7777 covers the
 * function bits without touching the reserved bit. Value
 * 0x1111 puts function 1 in each pin's slot, so the combined
 * mask+value to set four pins is 0x77771111. */
#define GRF_BASE              0xFDC60000u
#define GRF_GPIO1B_IOMUX_H    (GRF_BASE + 0x0Cu)
#define GRF_GPIO1C_IOMUX_L    (GRF_BASE + 0x10u)
#define GRF_GPIO1C_IOMUX_H    (GRF_BASE + 0x14u)

/* PULL register offsets — CONFIRMED against RK3568 TRM Part 1
 * Chapter 3 (see docs/019-board-pinmux.md). The pull-bias block
 * starts at GRF + 0x80; one register per 8-pin group; two bits
 * per pin (00 = none, 01 = pull-up, 10 = pull-down). Reset
 * value of GPIO1B_P is 0x55AA, GPIO1C_P is 0xA955 — the BootROM
 * has already set pull-ups on the eMMC pins, so our writes here
 * are belt-and-braces rather than strictly necessary. */
#define GRF_GPIO1B_P          (GRF_BASE + 0x84u)
#define GRF_GPIO1C_P          (GRF_BASE + 0x88u)

/* These two offsets (0xC4 / 0xC8) are NOT drive-strength — they
 * are the pad INPUT-ENABLE registers (GRF_GPIO1x_IE), per TRM
 * Part 1 Chapter 3. An earlier version of this driver wrote
 * drive-strength bit patterns here, which can clear the input-
 * enable on the eMMC data/CMD pins and leave the controller
 * unable to read the card's responses — a second, self-inflicted
 * cause of the floating-bus 0xFFFFFFFF symptom on top of the RX-
 * clock-inversion root cause. We now leave these registers at
 * their reset default and only read them for diagnostics. */
#define GRF_GPIO1B_IE         (GRF_BASE + 0xC4u)
#define GRF_GPIO1C_IE         (GRF_BASE + 0xC8u)

/* The real drive-strength block ("DS") starts at GRF + 0x200;
 * four registers per 8-pin group, each covering two pins, six
 * thermometer-coded bits per pin (levels 0-5). The eMMC data
 * pins B4-B7 reset to level 3 (register value 0x0F0F), which is
 * already strong enough for the identification-rate bus, so
 * phase-1 leaves drive strength at its reset default and only
 * reads these for diagnostics. Offsets: GPIO1B_DS_2 covers
 * B4/B5, DS_3 covers B6/B7, GPIO1C_DS_0 covers C0/C1. */
#define GRF_GPIO1B_DS_2       (GRF_BASE + 0x218u)
#define GRF_GPIO1C_DS_0       (GRF_BASE + 0x220u)

/* Configure pull-bias and drive-strength on the eMMC pin set.
 * The device tree marks D0..D7, CMD, and CLK as
 * `pcfg-pull-up-drv-level-2` (internal pull-up enabled, drive
 * strength level 2 of 4); DataStrobe and RSTn are
 * `pcfg-pull-none` and we leave their bits alone.
 *
 * Without this configuration the eMMC pins are at the chip's
 * post-reset default — drive strength almost certainly the
 * minimum, pull bias often disabled. CMD line floating means
 * the controller can't reliably detect the card's response;
 * weak data-line drive means the card might not see CMDs at
 * all even when the controller is sending them correctly.
 *
 * Mask + value for an 8-pin group register (16 bits used in
 * low half, 2 bits per pin):
 *
 *   "all pins to function-2" = 0xAAAA  (binary 10 per nibble bit-pair)
 *   "pull-up on all pins"    = 0x5555  (binary 01 per nibble bit-pair)
 *
 * eMMC pin layout within the GPIO1 banks:
 *   B group: B4..B7 = D0..D3 (eMMC data)
 *   C group: C0..C3 = D4..D7 (eMMC data)
 *             C4 = CMD
 *             C5 = CLK
 *             C6 = DataStrobe (leave alone)
 *             C7 = RSTn       (leave alone)
 *
 * So we need to touch bits 9:8 through 15:14 in group B (pins
 * B4..B7) and bits 1:0 through 11:10 in group C (pins C0..C5).
 *
 * Group B touched bits: 0xFF00 (4 pins × 2 bits, in bits 8-15).
 * Group C touched bits: 0x0FFF (6 pins × 2 bits, in bits 0-11).
 */
static void emmc_pad_config_setup(void)
{
    /* Pull-up on the eMMC data/CMD/CLK pins. The BootROM has
     * already done this (reset defaults plus its own SD-boot
     * setup leave the pins pulled up), so these writes are
     * confirmation, not correction. Two bits per pin, value
     * 01 = pull-up.
     *   B group: touch B4..B7 (bits 15:8), value 0x5500.
     *   C group: touch C0..C5 (bits 11:0), value 0x0555. */
    mmio_write32(GRF_GPIO1B_P, 0xFF005500u);
    mmio_write32(GRF_GPIO1C_P, 0x0FFF0555u);

    /* Drive strength is deliberately left at its reset default
     * (level 3 on the data pins) — see the DS-register comment
     * above. We do NOT write the input-enable registers at
     * 0xC4/0xC8; an earlier version did, mistaking them for
     * drive-strength, which could disable the pins' input
     * buffers.
     *
     * Diagnostic readback of the pad registers, reading the
     * CORRECT registers this time: pull (0x84/0x88), the real
     * drive-strength block (0x218/0x220), and the input-enable
     * registers (0xC4/0xC8) we now leave alone — so a future
     * regression that clobbers them is visible. */
    debug_write("[emmc] pad config readback\r\n");
    debug_write("[emmc]   GPIO1B_P=");
    debug_write_hex32(mmio_read32(GRF_GPIO1B_P));
    debug_write("[emmc]   GPIO1C_P=");
    debug_write_hex32(mmio_read32(GRF_GPIO1C_P));
    debug_write("[emmc]   GPIO1B_DS_2=");
    debug_write_hex32(mmio_read32(GRF_GPIO1B_DS_2));
    debug_write("[emmc]   GPIO1C_DS_0=");
    debug_write_hex32(mmio_read32(GRF_GPIO1C_DS_0));
    debug_write("[emmc]   GPIO1B_IE=");
    debug_write_hex32(mmio_read32(GRF_GPIO1B_IE));
    debug_write("[emmc]   GPIO1C_IE=");
    debug_write_hex32(mmio_read32(GRF_GPIO1C_IE));
}

static void emmc_pinmux_setup(void)
{
    mmio_write32(GRF_GPIO1B_IOMUX_H, 0x77771111u);  /* D0..D3 */
    mmio_write32(GRF_GPIO1C_IOMUX_L, 0x77771111u);  /* D4..D7 */
    mmio_write32(GRF_GPIO1C_IOMUX_H, 0x77771111u);  /* CMD, CLK, DS, RSTn */

    /* Read back so the log shows what landed. If our writes are
     * being silently dropped (wrong GRF base, missing PMU GRF
     * write-enable, wrong register offset) the readback values
     * stay at their pre-write defaults. A successful write to
     * function 1 on all four pins reads back as a value whose
     * low 16 bits contain 0x1111 in the function-bit positions
     * (low 3 of each nibble). The high 16 bits read as 0
     * because the write-mask half is write-only. */
    debug_write("[emmc]   GPIO1B_IOMUX_H=");
    debug_write_hex32(mmio_read32(GRF_GPIO1B_IOMUX_H));
    debug_write("[emmc]   GPIO1C_IOMUX_L=");
    debug_write_hex32(mmio_read32(GRF_GPIO1C_IOMUX_L));
    debug_write("[emmc]   GPIO1C_IOMUX_H=");
    debug_write_hex32(mmio_read32(GRF_GPIO1C_IOMUX_H));
}

/* Wake the eMMC host out of the CRU's gated/asserted post-reset
 * state. The bootloader leaves the controller in an inconsistent
 * shape on the SD-card boot path — ROCKNIX's u-boot loads the
 * kernel from the SD card, not the eMMC, so it never touches the
 * eMMC controller's clock or reset registers. The first MMIO
 * access into the controller then panics in one of three ways:
 * 0x00000000 reads (block reset asserted), 0xFFFFFFFF reads (AHB
 * clock gated), or a stalled bus the trust-firmware catches and
 * resets us on. Ungating all five clocks at once, pulsing all
 * five resets at once, and then verifying the controller's
 * capabilities register comes back with a sensible value gives
 * the rest of the bring-up a predictable starting point.
 *
 * The BCLK (block) reset is the one most commonly missed by
 * partial bring-up sequences; deasserting only the AHB and CCLK
 * resets is enough to make register reads succeed but leaves
 * writes silently dropping. Doing all five together avoids that
 * trap. */
static int emmc_cru_bring_up(void)
{
    /* Ungate all five clocks: ACLK / HCLK / BCLK / CCLK / TCLK
     * at CLKGATE_CON(9) bits 5-9. Write-mask convention: upper
     * 16 bits mask, lower 16 bits value. Clearing the bits
     * ungates the clock; setting them gates it. We want them
     * ungated, so the lower half is zero with the mask covering
     * all five bits. */
    mmio_write32(CRU_CLKGATE_CON_9, ((uint32_t)EMMC_CLOCK_BITS) << 16);

    /* Drive CCLK_EMMC directly at the 375 kHz identification rate
     * (clk_osc0_div_375k). The card clock comes straight from this
     * mux, so it is ~375 kHz regardless of what the SDHCI divider
     * does — the point of matching u-boot's clocking model. The
     * transfer phase later switches this mux to 24 MHz. */
    mmio_write32(CRU_CLKSEL_CON_28,
                 (CCLK_EMMC_SEL_MASK << 16) | CCLK_EMMC_SEL_375K);

    /* Assert all five resets, then deassert. A short delay
     * between the assert and the deassert gives the controller
     * a few cycles to actually see the reset edge. */
    mmio_write32(CRU_SOFTRST_CON_7,
                 (((uint32_t)EMMC_CLOCK_BITS) << 16) | EMMC_CLOCK_BITS);
    delay_loops(1000);
    mmio_write32(CRU_SOFTRST_CON_7,
                 ((uint32_t)EMMC_CLOCK_BITS) << 16);

    /* Diagnostic discriminator. The capabilities register is a
     * cheap MMIO read that tells us whether the controller is
     * actually reachable. Non-zero means the bus came up; the
     * two failure modes are both legible patterns. */
    uint32_t caps = mmio_read32(SDHCI_BASE + SDHCI_CAPABILITIES);
    if (caps == 0x00000000u) {
        debug_write("[emmc] capabilities read 0 — BCLK reset stuck asserted\r\n");
        return -1;
    }
    if (caps == 0xFFFFFFFFu) {
        debug_write("[emmc] capabilities read ones — AHB clock still gated\r\n");
        return -2;
    }
    return 0;
}

/* Configure the dwcmshc Rockchip vendor-area registers. Runs
 * AFTER the SDHCI software reset (matching upstream Linux, where
 * the DLL/RX-clock setup happens in the post-reset set_clock
 * path) so none of these writes are wiped by SOFT_RESET_ALL.
 *
 * The critical write here is the RX clock source: at reset the
 * RX clock is INVERTED, so the controller samples card responses
 * on the wrong edge and reads floating-bus 0xFFFFFFFF for every
 * response even though the card is answering. Setting the
 * no-inverter bit is the fix for the phase-1 eMMC bring-up. */
static void dwcmshc_vendor_config(void)
{
    /* HOST_CTRL3 is a single byte inside a wider word; a 32-bit
     * write clobbers neighbour bytes. Byte-width write disables
     * the command-conflict-check logic. */
    mmio_write8(SDHCI_BASE + DWCMSHC_HOST_CTRL3, 0);

    /* DLL: the low-speed (identification clock) configuration
     * that u-boot's rockchip_sdhci.c applies — DLL in BYPASS+START
     * mode, RX clock gated to its origin, STRBIN delay enabled.
     * Writing these to 0 (as we did for many iterations) left the
     * sample/drive clock path dead and the card silent; this is
     * the actual fix. */
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_CTRL,
                 DWCMSHC_DLL_CTRL_LOWSPEED);
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_RXCLK,
                 DWCMSHC_DLL_RXCLK_LOWSPEED);
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_TXCLK, 0);
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_STRBIN,
                 DWCMSHC_DLL_STRBIN_LOWSPEED);

    /* Tell the controller this is an eMMC (bit 0). Leave the
     * card hardware-reset bits at their reset default (RST_N
     * deasserted, OE on) — u-boot's known-good path does not
     * pulse RST_n, and our own earlier pulse experiment confirmed
     * it had no effect. */
    uint32_t ctrl = mmio_read32(SDHCI_BASE + DWCMSHC_EMMC_CONTROL);
    ctrl |= DWCMSHC_CARD_IS_EMMC;
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_CONTROL, ctrl);

    debug_write("[emmc]   EMMC_CONTROL=");
    debug_write_hex32(mmio_read32(SDHCI_BASE + DWCMSHC_EMMC_CONTROL));
    debug_write("[emmc]   DLL_CTRL=");
    debug_write_hex32(mmio_read32(SDHCI_BASE + DWCMSHC_EMMC_DLL_CTRL));
    debug_write("[emmc]   DLL_RXCLK=");
    debug_write_hex32(mmio_read32(SDHCI_BASE + DWCMSHC_EMMC_DLL_RXCLK));
}

/* Deep diagnostic dump of every controller-side register that
 * could plausibly tell us why the eMMC card is silent. Run
 * after the SDHCI software reset and the post-reset writes but
 * before issuing any card commands. The goal is to give the
 * developer a single block of register snapshots that answers
 * questions like "what does the controller think the base clock
 * is" / "does the controller think a card is present" / "is the
 * voltage rail it expects matched" — questions that have been
 * answered by guesswork up to now. */
static void emmc_dump_controller_state(void)
{
    debug_write("[emmc] --- controller diagnostic dump ---\r\n");
    debug_write("[emmc]   CAPABILITIES=");
    debug_write_hex32(mmio_read32(SDHCI_BASE + SDHCI_CAPABILITIES));
    debug_write("[emmc]   CAPABILITIES_HIGH=");
    debug_write_hex32(mmio_read32(SDHCI_BASE + SDHCI_CAPABILITIES + 4));
    debug_write("[emmc]   HOST_CONTROL_1=");
    debug_write_hex32((uint32_t)mmio_read8(SDHCI_BASE + SDHCI_HOST_CONTROL_1));
    debug_write("[emmc]   POWER_CONTROL=");
    debug_write_hex32((uint32_t)mmio_read8(SDHCI_BASE + SDHCI_POWER_CONTROL));
    debug_write("[emmc]   CLOCK_CONTROL=");
    debug_write_hex32((uint32_t)mmio_read16(SDHCI_BASE + SDHCI_CLOCK_CONTROL));
    debug_write("[emmc]   INT_ENABLE=");
    debug_write_hex32(mmio_read32(SDHCI_BASE + SDHCI_INT_ENABLE));
    debug_write("[emmc]   PRESENT_STATE=");
    debug_write_hex32(mmio_read32(SDHCI_BASE + SDHCI_PRESENT_STATE));
    debug_write("[emmc]   HOST_CTRL3=");
    debug_write_hex32(mmio_read32(SDHCI_BASE + DWCMSHC_HOST_CTRL3));
    /* SDHCI version register at offset 0xFE — bits 7:0 are the
     * vendor version, bits 15:8 the spec version. */
    debug_write("[emmc]   SDHCI_VERSION=");
    debug_write_hex32((uint32_t)mmio_read16(SDHCI_BASE + 0xFE));
    debug_write("[emmc] --- end dump ---\r\n");
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

    /* Wait for the command-complete interrupt status bit. Three
     * distinct failure modes worth distinguishing in the log:
     *
     *   -2 = the controller raised the composite error interrupt
     *        (bit 15). One of the specific command-error bits
     *        (16=CMD_TIMEOUT, 17=CMD_CRC, 18=END_BIT, 19=INDEX)
     *        is set in the high half of INT_STATUS; the log
     *        message names the one that fired.
     *
     *   -3 = budget exhausted, neither error nor complete fired.
     *        The status bit just never appeared. Most likely
     *        cause is that the Normal Interrupt Status Enable
     *        register (offset 0x34) was cleared by SOFT_RESET_ALL
     *        and never re-set, so COMMAND_COMPLETE silently can't
     *        surface in INT_STATUS even though the command itself
     *        was sent fine. Less likely cause: the card-detect
     *        logic thinks the slot is empty and the controller
     *        refuses to drive commands.
     */
    budget = 100000;
    while (1) {
        uint32_t status = mmio_read32(SDHCI_BASE + SDHCI_INT_STATUS);
        if (status & INT_ERROR) {
            if (status & (1u << 16)) debug_write("[emmc]   cmd_timeout\r\n");
            if (status & (1u << 17)) debug_write("[emmc]   cmd_crc\r\n");
            if (status & (1u << 18)) debug_write("[emmc]   cmd_end_bit\r\n");
            if (status & (1u << 19)) debug_write("[emmc]   cmd_index\r\n");
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

/* Drain all four response words for a 136-bit (R2) response.
 * The card's CID lives across these four words. Some SDHCI
 * implementations require the host to read the full response
 * before the next command's response slot is armed; ignoring
 * the upper words can leave the controller in a state where
 * the next CMD's response timer never starts. */
static void sdhci_drain_response_r2(uint32_t out[4])
{
    out[0] = mmio_read32(SDHCI_BASE + SDHCI_RESPONSE +  0);
    out[1] = mmio_read32(SDHCI_BASE + SDHCI_RESPONSE +  4);
    out[2] = mmio_read32(SDHCI_BASE + SDHCI_RESPONSE +  8);
    out[3] = mmio_read32(SDHCI_BASE + SDHCI_RESPONSE + 12);
}

/* Internal copy of the card's relative address — assigned by us
 * during initialization, used as the argument to CMD7 and any
 * command that addresses a specific card. */
static uint32_t card_rca;

/* Full initialization sequence following the JEDEC eMMC spec. */
static int emmc_initialize(void)
{
    /* Pinmux first. Without this the controller drives commands
     * into pads still wired to GPIO function, the card never
     * sees them, and every response register reads as the
     * floating-bus all-ones pattern. */
    debug_write("[emmc] pinmux...\r\n");
    emmc_pinmux_setup();

    /* Then the pin pull-bias and drive-strength config. The
     * IOMUX writes alone get us the controller-pad routing but
     * leave the pads at chip-default drive strength (typically
     * the lowest level) and with pull bias disabled. The CMD
     * line floating means the card's R1 / R2 / R6 responses
     * can't be reliably detected, even when the controller is
     * sending CMDs correctly. */
    emmc_pad_config_setup();

    /* CRU clocks and resets next — without this the controller
     * is unreachable on the SD-card boot path. */
    debug_write("[emmc] CRU bring-up...\r\n");
    if (emmc_cru_bring_up() != 0) {
        return -100;
    }

    debug_write("[emmc] resetting controller...\r\n");
    if (sdhci_reset(SOFT_RESET_ALL) != 0) {
        debug_write("[emmc] controller reset timed out\r\n");
        return -1;
    }

    /* Configure the Rockchip vendor-area registers AFTER the
     * SDHCI reset (so the reset can't wipe them). This includes
     * the RX-clock-non-inverted write that fixes response
     * sampling — the root-cause fix for the floating-bus
     * 0xFFFFFFFF symptom. */
    dwcmshc_vendor_config();

    /* Post-reset register state the SDHCI spec assumes is set
     * before the first command. SOFT_RESET_ALL clears every
     * register except the capabilities readouts, so without
     * these three writes the controller is technically alive but
     * deaf and blind:
     *
     *   - INT_ENABLE (Normal Interrupt Status Enable, offset
     *     0x34). The SDHCI spec is explicit: "If any of the
     *     Normal Interrupt Status is not set to 1, the
     *     corresponding interrupt status is masked." Without
     *     this write the COMMAND_COMPLETE bit will not appear in
     *     INT_STATUS no matter what the bus does — every command
     *     will look like a timeout. The previous CMD0 failure
     *     traced almost certainly to here.
     *
     *   - HOST_CONTROL_1 (offset 0x28). Bits 6 and 7 control
     *     card-detect: bit 7 = 1 means "use the Card Detect
     *     Test Level register", bit 6 = 1 means "test level says
     *     card is present." eMMC has no CD pin so the controller
     *     sees the line floating; without these bits set, the
     *     controller refuses to drive commands.
     *
     *   - TIMEOUT_CTRL (offset 0x2E). The data-transfer timeout
     *     value: 0x0E is the maximum (2^27 SD-clocks). Affects
     *     CMD17/CMD24 later, not CMD0; included here for
     *     completeness so we don't need to revisit the bring-up
     *     sequence later. */
    mmio_write32(SDHCI_BASE + SDHCI_INT_ENABLE, 0xFFFFFFFFu);
    mmio_write8(SDHCI_BASE + SDHCI_HOST_CONTROL_1, 0xC0);
    mmio_write8(SDHCI_BASE + SDHCI_TIMEOUT_CTRL, 0x0E);

    /* Power-cycle the slot. Driving POWER_CONTROL to 0 cuts VCC
     * to the card, the wait gives the card's internal state
     * machines time to drop, then writing 0x0D brings VCC back
     * up at 3.0 V. This forces a known post-power-on state on
     * the card regardless of whatever the BootROM's eMMC-boot
     * attempt or a previous kernel boot may have left behind.
     *
     * Without this, on the SD-card boot path the eMMC card has
     * been powered for the full life of the boot session;
     * commands like CMD0 only put the card into Idle if the
     * card is already in a state where it accepts CMD0, which
     * isn't guaranteed if a previous attempt to read from the
     * card walked it into Ident or Stand-by state. */
    mmio_write8(SDHCI_BASE + SDHCI_POWER_CONTROL, 0);
    delay_loops(100000);
    mmio_write8(SDHCI_BASE + SDHCI_POWER_CONTROL, POWER_VOLTAGE_3V0 | POWER_ON);
    delay_loops(100000);

    /* Diagnostic dump before any card command goes out. The
     * answers we're looking for: what does CAPABILITIES say the
     * base clock is (bits 22:16, in MHz), does HOST_CONTROL_1
     * actually hold 0xC0 (card-detect test level worked), is
     * POWER_CONTROL holding the value we wrote, is CLOCK_CONTROL
     * showing internal+SD clock enabled. */
    emmc_dump_controller_state();

    /* Identification clock. CCLK_EMMC is now driven directly at
     * 375 kHz by the CRU mux (set in emmc_cru_bring_up), so the
     * card clock equals CCLK and the SDHCI divider is pass-through
     * (0 = no division). This is the key change being tested: if
     * the dwcmshc ignores the SDHCI internal divider and clocks
     * the card straight from CCLK, then every earlier flash (CCLK
     * = 200 MHz, divider 0xFF) was clocking the card at 200 MHz —
     * far too fast to ever respond. Driving CCLK low removes that
     * variable entirely. */
    debug_write("[emmc] setting identification clock (CCLK=375kHz, div=0)...\r\n");
    if (sdhci_set_clock(0) != 0) {
        debug_write("[emmc] clock stabilize timeout\r\n");
        return -2;
    }

    /* Verify the clock register holds what we expect. The
     * 16-bit CLOCK_CONTROL after sdhci_set_clock should show:
     *   bit 0 = 1 (internal clock enable)
     *   bit 1 = 1 (internal clock stable)
     *   bit 2 = 1 (SD clock enable)
     *   bits 15:8 = our divisor
     * Anything else points at a clock-config bug. */
    debug_write("[emmc]   CLOCK_CONTROL=");
    debug_write_hex32((uint32_t)mmio_read16(SDHCI_BASE + SDHCI_CLOCK_CONTROL));
    debug_write("[emmc]   POWER_CONTROL=");
    debug_write_hex32((uint32_t)mmio_read8(SDHCI_BASE + SDHCI_POWER_CONTROL));

    /* The eMMC spec requires 74 clock cycles at the bus rate
     * after clock-enable before the first command. At our 400
     * kHz identification rate that's 185 microseconds; at our
     * boot CPU clock, 100,000 nops is well over that. Without
     * this delay the very first CMD0 can fire before the card
     * has finished its own internal reset. */
    delay_loops(100000);

    /* eMMC4.4+ pre-idle: CMD0 with argument 0xF0F0F0F0 forces
     * the card from any state (Ident, Stand-by, Trans, etc.)
     * back to the pre-idle state, from which the next CMD0
     * with the normal argument 0 puts it into Idle. Without
     * this dance, a card already past Idle from a previous
     * boot session ignores the plain CMD0. The transport may
     * fail here if the card is in a state that doesn't
     * recognise the special argument; we ignore the result
     * and proceed to the regular CMD0 either way. */
    debug_write("[emmc] CMD0 pre-idle (arg 0xF0F0F0F0)...\r\n");
    (void)sdhci_send_command(CMD_IDX(0), 0xF0F0F0F0u);
    delay_loops(10000);

    /* CMD0: go-idle-state. Failure here is the most useful
     * thing to discriminate by return code — emit a message
     * with the actual return value so the next failure tells
     * us exactly where to look. */
    debug_write("[emmc] CMD0 go-idle...\r\n");
    int cmd0_status = sdhci_send_command(CMD_IDX(0), 0);
    if (cmd0_status != 0) {
        if (cmd0_status == -1) {
            debug_write("[emmc] CMD0 — CMD/DAT inhibit never cleared\r\n");
        } else if (cmd0_status == -2) {
            debug_write("[emmc] CMD0 — controller raised error bit\r\n");
        } else if (cmd0_status == -3) {
            debug_write("[emmc] CMD0 — neither error nor complete (INT_ENABLE issue)\r\n");
        }
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

    /* Drain the full 136-bit CID. Two reasons: (a) some SDHCI
     * implementations need the host to read the upper response
     * words before the next response slot is armed, and a
     * dwcmshc that wedges on this is consistent with what the
     * "CMD3 cmd_timeout immediately after CMD2 succeeds" symptom
     * looks like from outside; (b) the first response word makes
     * a useful diagnostic — a plausible non-zero value confirms
     * the card actually broadcast its CID, while all-zeros or
     * all-ones would mean CMD2 succeeded electrically but the
     * card never spoke. */
    uint32_t cid[4];
    sdhci_drain_response_r2(cid);
    debug_write("[emmc]   CID[0]=");
    debug_write_hex32(cid[0]);

    /* If the card actually responded, CID[0] is a real card
     * value (containing parts of PSN / PRV / MDT bits) — almost
     * certainly not all-ones. An all-ones read is the floating-
     * bus pattern that says "the controller's COMMAND_COMPLETE
     * fired on command-sent, but no card was on the wire to
     * answer." Catch it explicitly rather than letting CMD3
     * blow up with a less-clear error. */
    if (cid[0] == 0xFFFFFFFFu) {
        debug_write("[emmc] CMD2 — floating-bus CID, card not responding\r\n");
        return -6;
    }

    /* Give the card a moment to settle in Identification state
     * before we ask it to transition to Stand-by via CMD3. The
     * JEDEC spec does not strictly require this delay but cards
     * with marginal internal logic can need it. */
    delay_loops(100000);

    /* CMD3: set-relative-addr. We assign RCA = 1. */
    debug_write("[emmc] CMD3 set-relative-addr...\r\n");
    card_rca = 1;
    int cmd3_status = sdhci_send_command(CMD_IDX(3)
                                         | CMD_RESPONSE_LEN_48
                                         | CMD_CRC_CHECK
                                         | CMD_INDEX_CHECK,
                                         card_rca << 16);
    if (cmd3_status != 0) {
        debug_write("[emmc]   PRESENT_STATE=");
        debug_write_hex32(mmio_read32(SDHCI_BASE + SDHCI_PRESENT_STATE));
        debug_write("[emmc]   INT_STATUS=");
        debug_write_hex32(mmio_read32(SDHCI_BASE + SDHCI_INT_STATUS));
        debug_write("[emmc] CMD3 failed\r\n");
        return -7;
    }
    debug_write("[emmc]   RESP0=");
    debug_write_hex32(sdhci_read_response_word0());

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

    /* Bump to a transfer-mode rate. We drive CCLK_EMMC directly
     * (same model as identification): switch the mux to 24 MHz
     * (xin_osc0) and keep the SDHCI divider at pass-through. The
     * card stays in backward-compatible (legacy) mode — we issue
     * no CMD6 high-speed switch — and legacy tops out at 26 MHz,
     * so 24 MHz is a safe, in-spec transfer clock. The DLL stays
     * in BYPASS mode, valid for all card clocks below 100 MHz. */
    debug_write("[emmc] switching to transfer clock (CCLK=24MHz, div=0)...\r\n");
    mmio_write32(CRU_CLKSEL_CON_28,
                 (CCLK_EMMC_SEL_MASK << 16) | CCLK_EMMC_SEL_24M);
    if (sdhci_set_clock(0) != 0) {
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

    /* Wait for transfer-complete OR a data error. Checking the error
     * bit here matters: a mis-sampled high-speed read (HS200/HS400) can
     * finish the data phase with a CRC mismatch, and without this check
     * it would slip through as a clean rc 0. INT_ERROR (bit 15) is the
     * composite error flag; the high half of INT_STATUS names which one
     * (bit 21 data-CRC, 22 data-end-bit, 20 data-timeout). */
    budget = 1000000;
    for (;;) {
        uint32_t st = mmio_read32(SDHCI_BASE + SDHCI_INT_STATUS);
        if (st & INT_ERROR) {
            debug_write("[emmc]   read DATA ERROR, INT_STATUS=");
            debug_write_hex32(st);
            debug_write("\r\n");
            mmio_write32(SDHCI_BASE + SDHCI_INT_STATUS, 0xFFFFFFFFu);
            return -4;
        }
        if (st & INT_XFER_COMPLETE) {
            break;
        }
        if (budget-- == 0) {
            return -3;
        }
    }
    mmio_write32(SDHCI_BASE + SDHCI_INT_STATUS, INT_XFER_COMPLETE);
    return 0;
}

/* Read the card's 512-byte EXT_CSD (Extended Card-Specific Data) — its
 * configuration-and-capabilities table. CMD8 SEND_EXT_CSD returns it as
 * a data block, so this is mechanically identical to emmc_read_block
 * (CMD17): command index 8 instead of 17, and a stuff-bits (0) argument
 * instead of a block address. The interesting bytes are DEVICE_TYPE
 * (196 — which speed modes the card advertises), HS_TIMING (185), and
 * BUS_WIDTH (183). Reading this is the first step of the HS200 bring-up
 * (110j): you do not switch a card into a mode it does not advertise. */
int emmc_read_ext_csd(uint8_t *buffer)
{
    mmio_write16(SDHCI_BASE + SDHCI_BLOCK_SIZE, EMMC_BLOCK_SIZE);
    mmio_write16(SDHCI_BASE + SDHCI_BLOCK_COUNT, 1);
    mmio_write16(SDHCI_BASE + SDHCI_TRANSFER_MODE, XFER_DAT_DIRECTION_READ);

    if (sdhci_send_command(CMD_IDX(8)
                           | CMD_RESPONSE_LEN_48
                           | CMD_DATA_PRESENT
                           | CMD_CRC_CHECK | CMD_INDEX_CHECK,
                           0) != 0) {
        return -1;
    }

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

/* ===================================================================
 * High-speed bring-up: HS200 (stage A) and HS400 (stage B) — issue 110j
 *
 * The legacy path above leaves the card at 1-bit / 24 MHz. This layer
 * walks it up to the fast modes the card advertises (EXT_CSD DEVICE_TYPE
 * bit 4 = HS200 @ 1.8 V, bit 6 = HS400 @ 1.8 V, both confirmed on this
 * board). It is additive — emmc_initialize() and the legacy read/write
 * path are untouched, so a failure here cannot regress the working slow
 * path.
 *
 * Every magic number below is derived from u-boot's rockchip_sdhci.c
 * (rk3568_data + rk3568_sdhci_config_dll, in tmp/uboot-ref/); the
 * bit-by-bit derivations live in issues/110j. The DLL words fold the
 * rk3568 tap numbers into the layout that driver builds, with
 * dll_tap_value = 0 (rk3568 has no FLAG_TAPVALUE_FROM_SW) and the RX
 * no-inverter bit set (rk3568 has FLAG_INVERTER_FLAG_IN_RXCLK).
 * =================================================================== */

/* SDHCI Host Control 2 (0x3E, 16-bit): UHS speed-mode select + 1.8 V. */
#define SDHCI_HOST_CONTROL2    0x3E
#define HC2_UHS_MASK           0x0007u
#define HC2_UHS_HS_SDR25       0x0001u   /* the HS (<=52 MHz) step-down */
#define HC2_UHS_HS200          0x0003u   /* SDR104 encoding = eMMC HS200 */
#define HC2_UHS_HS400          0x0007u   /* dwcmshc vendor HS400 mode */
#define HC2_VDD_180            0x0008u   /* 1.8 V signalling enable */
#define HC2_EXEC_TUNING        0x0040u   /* start tuning (self-clears) */
#define HC2_TUNED_CLK          0x0080u   /* tuning locked a sampling point */

/* HOST_CONTROL_1 (0x28) data-bus width: bit 5 (8-bit "extended data
 * width") overrides bit 1 (4-bit). */
#define HC1_BUS_WIDTH_8BIT     (1u << 5)

/* CCLK_EMMC source mux: the 200 MHz tap (clk_gpll_div_200m, sel=001) —
 * the same tap the emmc-dll-tune probe drove with 0x70001000. */
#define CCLK_EMMC_SEL_200M     (0x1u << 12)

/* dwcmshc DLL vendor-area registers used only at high speed. */
#define DWCMSHC_EMMC_AT_CTRL     0x540
#define DWCMSHC_EMMC_DLL_CMDOUT  0x810
#define DWCMSHC_EMMC_DLL_STATUS0 0x840
#define DLL_CTRL_RESET         (1u << 1)
#define DLL_LOCKED             (1u << 8)
#define DLL_TIMEOUT            (1u << 9)

/* Pre-computed locked-DLL register words (rk3568). Derivations in the
 * section header above and issue 110j. */
#define DLL_AT_CTRL_VAL        0x001F0000u  /* pre/post change dly 3 + tune-clk-stop */
#define DLL_START_VAL          0x00050201u  /* start-point 5, increment 2, START */
#define DLL_RXCLK_HS_VAL       0xA8000000u  /* DLYENA | ORI_GATE | NO_INVERTER */
#define DLL_TXCLK_HS200_VAL    0x29000010u  /* DLYENA | FROM_SW | NO_INVERTER | tap 0x10 */
#define DLL_TXCLK_HS400_VAL    0x29000008u  /* ... tap 0x8 */
#define DLL_STRBIN_HS_VAL      0x09000004u  /* DLYENA | FROM_SW | tap 0x4 */
#define DLL_CMDOUT_HS400_VAL   0x59000008u  /* SRC_CLK_NEG | BOTH_EDGE | DLYENA | FROM_SW | tap 0x8 */

/* EXT_CSD byte indices and the values we CMD6-SWITCH them to. */
#define EXTCSD_BUS_WIDTH       183u
#define EXTCSD_HS_TIMING       185u
#define BUSW_8BIT_SDR          2u
#define BUSW_8BIT_DDR          6u
#define HSTIMING_HS            1u
#define HSTIMING_HS200         2u
#define HSTIMING_HS400         3u

/* CMD6 SWITCH argument, "Write Byte" access (0b11): set EXT_CSD[index]
 * to value. arg = [25:24]=3 access | [23:16]=index | [15:8]=value. */
#define CMD6_WRITE_BYTE(index, value) \
    ((3u << 24) | ((uint32_t)(index) << 16) | ((uint32_t)(value) << 8))

/* CMD6 SWITCH — change one EXT_CSD byte. R1b: the card holds DAT0 low
 * (busy) while it applies the change. Issue the command, wait the busy
 * out (present-state DAT line frees), then CMD13 SEND_STATUS to confirm
 * the card didn't reject it (status bit 7 = SWITCH_ERROR). Returns 0 on
 * a clean switch. */
static int emmc_switch(uint8_t index, uint8_t value)
{
    if (sdhci_send_command(CMD_IDX(6)
                           | CMD_RESPONSE_LEN_48_BSY
                           | CMD_CRC_CHECK | CMD_INDEX_CHECK,
                           CMD6_WRITE_BYTE(index, value)) != 0) {
        return -1;
    }
    /* Wait out the R1b busy: DAT_INHIBIT stays set while DAT0 is held. */
    uint32_t budget = 1000000;
    while (mmio_read32(SDHCI_BASE + SDHCI_PRESENT_STATE) & PSTATE_DAT_INHIBIT) {
        if (budget-- == 0) {
            debug_write("[emmc]   switch busy never cleared\r\n");
            return -2;
        }
    }
    /* CMD13: read card status; bit 7 (SWITCH_ERROR) means rejection. If
     * CMD13 itself fails to send, the busy already cleared, so treat the
     * switch as applied. */
    if (sdhci_send_command(CMD_IDX(13)
                           | CMD_RESPONSE_LEN_48 | CMD_CRC_CHECK | CMD_INDEX_CHECK,
                           card_rca << 16) == 0) {
        uint32_t status = sdhci_read_response_word0();
        if (status & (1u << 7)) {
            debug_write("[emmc]   SWITCH_ERROR in card status\r\n");
            return -3;
        }
    }
    return 0;
}

/* Card + host to an 8-bit data bus. Card side is a CMD6 to EXT_CSD
 * BUS_WIDTH; host side sets HOST_CONTROL_1 bit 5, preserving the
 * card-detect bits set during init. `ddr` selects 8-bit DDR (HS400)
 * over 8-bit SDR (HS200). */
static int emmc_set_bus_width_8bit(int ddr)
{
    if (emmc_switch(EXTCSD_BUS_WIDTH, ddr ? BUSW_8BIT_DDR : BUSW_8BIT_SDR) != 0) {
        return -1;
    }
    uint8_t hc1 = mmio_read8(SDHCI_BASE + SDHCI_HOST_CONTROL_1);
    hc1 |= HC1_BUS_WIDTH_8BIT;
    mmio_write8(SDHCI_BASE + SDHCI_HOST_CONTROL_1, hc1);
    return 0;
}

/* Set HOST_CONTROL_2's UHS mode field, keeping 1.8 V signalling on (the
 * board's VCCQ is fixed at 1.8 V, so we run 1.8 V from HS200 onward). */
static void emmc_set_host_mode(uint16_t uhs)
{
    uint16_t hc2 = mmio_read16(SDHCI_BASE + SDHCI_HOST_CONTROL2);
    hc2 &= ~HC2_UHS_MASK;
    hc2 |= (uhs & HC2_UHS_MASK) | HC2_VDD_180;
    mmio_write16(SDHCI_BASE + SDHCI_HOST_CONTROL2, hc2);
}

/* Point CCLK_EMMC at its 200 MHz tap and restabilise the SD clock. The
 * card clock comes straight from CCLK (the driver's clocking model), so
 * the SDHCI divider stays pass-through (0). */
static int emmc_set_clock_200mhz(void)
{
    mmio_write16(SDHCI_BASE + SDHCI_CLOCK_CONTROL, 0);   /* stop card clock */
    mmio_write32(CRU_CLKSEL_CON_28,
                 (CCLK_EMMC_SEL_MASK << 16) | CCLK_EMMC_SEL_200M);
    return sdhci_set_clock(0);
}

/* Low-speed (bypass) DLL config — the same words emmc_initialize applies,
 * factored out so the HS400 step-down (which passes briefly through a
 * <100 MHz High-Speed window to reconfigure the bus to DDR) can restore
 * bypass before re-locking at HS400. */
static void emmc_config_dll_bypass(void)
{
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_CTRL,   DWCMSHC_DLL_CTRL_LOWSPEED);
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_RXCLK,  DWCMSHC_DLL_RXCLK_LOWSPEED);
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_TXCLK,  0);
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_STRBIN, DWCMSHC_DLL_STRBIN_LOWSPEED);
}

/* Lock the DLL for >=100 MHz and program the sample (RX), drive (TX),
 * strobe-in, and — for HS400 — command-out tap delays. Returns 0 with
 * the DLL locked, -1 if it never locks. Mirrors the clock>=100 MHz
 * branch of rk3568_sdhci_config_dll. */
static int emmc_config_dll_locked(int hs400)
{
    /* Reset the DLL, release, then start it (start-point 5, inc 2). */
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_CTRL, DLL_CTRL_RESET);
    delay_loops(2000);
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_CTRL, 0);
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_AT_CTRL, DLL_AT_CTRL_VAL);
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_CTRL, DLL_START_VAL);

    /* Poll for lock (bit 8 set, timeout bit 9 clear). */
    uint32_t budget = 100000;
    uint32_t st = 0;
    while (budget--) {
        st = mmio_read32(SDHCI_BASE + DWCMSHC_EMMC_DLL_STATUS0);
        if ((st & DLL_LOCKED) && !(st & DLL_TIMEOUT)) {
            break;
        }
        delay_loops(64);
    }
    debug_write("[emmc]   DLL_STATUS0=");
    debug_write_hex32(st);
    if (!((st & DLL_LOCKED) && !(st & DLL_TIMEOUT))) {
        debug_write("[emmc]   DLL did not lock\r\n");
        return -1;
    }

    /* Program the tap delays. RX/STRBIN are common; TX differs by mode,
     * and HS400 adds the command-output path (negative + both edges). */
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_RXCLK, DLL_RXCLK_HS_VAL);
    if (hs400) {
        mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_CMDOUT, DLL_CMDOUT_HS400_VAL);
        mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_TXCLK, DLL_TXCLK_HS400_VAL);
    } else {
        mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_TXCLK, DLL_TXCLK_HS200_VAL);
    }
    mmio_write32(SDHCI_BASE + DWCMSHC_EMMC_DLL_STRBIN, DLL_STRBIN_HS_VAL);
    return 0;
}

/* Run the controller's HS200 sampling tuning. Set EXEC_TUNING, then send
 * CMD21 (SEND_TUNING_BLOCK; 128-byte pattern on an 8-bit bus) up to 40
 * times while the controller sweeps the sampling phase; it clears
 * EXEC_TUNING and sets TUNED_CLK when it locks one in. Returns 0 if
 * TUNED_CLK is set; negative if tuning never converged (sampling then
 * falls back to the DLL-derived point, so the caller treats this as a
 * warning, not a hard failure, on the first bring-up). */
static int emmc_execute_tuning(void)
{
    uint16_t hc2 = mmio_read16(SDHCI_BASE + SDHCI_HOST_CONTROL2);
    hc2 |= HC2_EXEC_TUNING;
    mmio_write16(SDHCI_BASE + SDHCI_HOST_CONTROL2, hc2);

    int i;
    for (i = 0; i < 40; i++) {
        mmio_write16(SDHCI_BASE + SDHCI_BLOCK_SIZE, 128);
        mmio_write16(SDHCI_BASE + SDHCI_BLOCK_COUNT, 1);
        mmio_write16(SDHCI_BASE + SDHCI_TRANSFER_MODE, XFER_DAT_DIRECTION_READ);
        (void)sdhci_send_command(CMD_IDX(21)
                                 | CMD_RESPONSE_LEN_48 | CMD_DATA_PRESENT | CMD_CRC_CHECK,
                                 0);
        hc2 = mmio_read16(SDHCI_BASE + SDHCI_HOST_CONTROL2);
        if (!(hc2 & HC2_EXEC_TUNING)) {
            break;   /* controller converged (or gave up) */
        }
    }
    debug_write("[emmc]   tuning loops=");
    debug_write_hex32((uint32_t)i);
    debug_write("[emmc]   HOST_CONTROL2=");
    debug_write_hex32((uint32_t)hc2);
    if (hc2 & HC2_EXEC_TUNING) {
        /* Never cleared — abandon tuning cleanly so the bus is usable. */
        hc2 &= ~(HC2_EXEC_TUNING | HC2_TUNED_CLK);
        mmio_write16(SDHCI_BASE + SDHCI_HOST_CONTROL2, hc2);
        return -1;
    }
    return (hc2 & HC2_TUNED_CLK) ? 0 : -2;
}

/* Stage A — take the card from legacy transfer state up to HS200: 8-bit
 * SDR bus, HS200 timing, 200 MHz, DLL locked, sampling tuned. Call after
 * emmc_init(). Returns 0 on success. */
int emmc_switch_hs200(void)
{
    debug_write("[emmc] === HS200 bring-up ===\r\n");

    debug_write("[emmc] CMD6 BUS_WIDTH = 8-bit SDR\r\n");
    if (emmc_set_bus_width_8bit(0) != 0) {
        debug_write("[emmc] HS200: bus-width switch failed\r\n");
        return -1;
    }
    debug_write("[emmc] CMD6 HS_TIMING = HS200\r\n");
    if (emmc_switch(EXTCSD_HS_TIMING, HSTIMING_HS200) != 0) {
        debug_write("[emmc] HS200: timing switch failed\r\n");
        return -2;
    }
    emmc_set_host_mode(HC2_UHS_HS200);
    debug_write("[emmc] clock -> 200 MHz\r\n");
    if (emmc_set_clock_200mhz() != 0) {
        debug_write("[emmc] HS200: 200 MHz clock failed\r\n");
        return -3;
    }
    if (emmc_config_dll_locked(0) != 0) {
        return -4;
    }
    debug_write("[emmc] HS200 tuning (CMD21)\r\n");
    (void)emmc_execute_tuning();   /* DLL is a usable fallback if it misses */
    debug_write("[emmc] === HS200 ready ===\r\n");
    return 0;
}

/* Stage B — from a working HS200 state, transition to HS400: step down
 * through High-Speed to reconfigure the bus to DDR, switch the card and
 * host to HS400, raise to 200 MHz DDR, re-lock the DLL with the HS400
 * taps + the data-strobe path. Call only after emmc_switch_hs200()
 * succeeded. Returns 0 on success. */
int emmc_switch_hs400(void)
{
    debug_write("[emmc] === HS400 transition ===\r\n");

    /* 1. Drop to High-Speed (<=52 MHz). The spec routes HS200 -> HS400
     * through HS so the bus can be reconfigured to DDR. Restore the
     * bypass DLL and a 24 MHz clock for the switch commands. */
    debug_write("[emmc] CMD6 HS_TIMING = HS (step down)\r\n");
    if (emmc_switch(EXTCSD_HS_TIMING, HSTIMING_HS) != 0) {
        debug_write("[emmc] HS400: HS step-down failed\r\n");
        return -1;
    }
    emmc_set_host_mode(HC2_UHS_HS_SDR25);
    mmio_write16(SDHCI_BASE + SDHCI_CLOCK_CONTROL, 0);
    mmio_write32(CRU_CLKSEL_CON_28, (CCLK_EMMC_SEL_MASK << 16) | CCLK_EMMC_SEL_24M);
    (void)sdhci_set_clock(0);
    emmc_config_dll_bypass();

    /* 2. DDR 8-bit bus. */
    debug_write("[emmc] CMD6 BUS_WIDTH = 8-bit DDR\r\n");
    if (emmc_set_bus_width_8bit(1) != 0) {
        debug_write("[emmc] HS400: DDR bus-width failed\r\n");
        return -2;
    }
    /* 3. HS400 card timing. */
    debug_write("[emmc] CMD6 HS_TIMING = HS400\r\n");
    if (emmc_switch(EXTCSD_HS_TIMING, HSTIMING_HS400) != 0) {
        debug_write("[emmc] HS400: timing switch failed\r\n");
        return -3;
    }
    /* 4. Host to HS400 + 200 MHz DDR. */
    emmc_set_host_mode(HC2_UHS_HS400);
    debug_write("[emmc] clock -> 200 MHz DDR\r\n");
    if (emmc_set_clock_200mhz() != 0) {
        debug_write("[emmc] HS400: 200 MHz clock failed\r\n");
        return -4;
    }
    /* 5. Re-lock the DLL with the HS400 taps + the command-output and
     * data-strobe paths. */
    if (emmc_config_dll_locked(1) != 0) {
        return -5;
    }
    debug_write("[emmc] === HS400 ready ===\r\n");
    return 0;
}

/* Verify the fast read returns correct data: read a fixed NON-ZERO
 * block and log a position-sensitive fingerprint of it. Run at each
 * speed (legacy / HS200 / HS400); the fingerprints must all match, be
 * non-zero, and carry rc 0 (no error bit) for the fast read to be
 * proven byte-identical to the slow one. This is the discriminating
 * check that word0 of an all-zero block 0 could not give. LBA 64 is the
 * Rockchip idbloader — guaranteed non-zero on a card that boots. */
#define EMMC_VERIFY_LBA 64u
void emmc_verify(void)
{
    static uint8_t blk[EMMC_BLOCK_SIZE];
    int rc = emmc_read_block(EMMC_VERIFY_LBA, blk);
    uint32_t fp = 0;
    int nonzero = 0;
    for (uint32_t i = 0; i < EMMC_BLOCK_SIZE; i += 4) {
        uint32_t w = ((uint32_t)blk[i]) | ((uint32_t)blk[i + 1] << 8)
                   | ((uint32_t)blk[i + 2] << 16) | ((uint32_t)blk[i + 3] << 24);
        fp = ((fp << 1) | (fp >> 31)) ^ w;   /* rotate-then-xor: order matters */
        if (w != 0u) nonzero = 1;
    }
    debug_write("[emmc] verify LBA 64: rc=");
    debug_write_hex32((uint32_t)rc);
    debug_write(" fingerprint=");
    debug_write_hex32(fp);
    debug_write(nonzero ? " (non-zero)\r\n" : " (ALL-ZERO: pick another LBA)\r\n");
}

/* Public entry: bring up the eMMC controller and the card. */
int emmc_init(void)
{
    return emmc_initialize();
}
