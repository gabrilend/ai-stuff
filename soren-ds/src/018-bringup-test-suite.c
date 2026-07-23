/*
 * 018-bringup-test-suite.c — phase-1 hardware bring-up test runner.
 *
 * Replaces the panic-on-first-failure sequence kernel_main used to
 * run with a small test runner that walks through every bring-up
 * step independently. Each step is a function returning zero on
 * success or a distinct non-zero value on failure; the runner
 * narrates each entry through debug_write, counts failures, and
 * continues past failures rather than parking the kernel.
 *
 * The list runs twice. For controller bring-up code that resets
 * the controller on every entry, both iterations should be
 * identical; a difference between them is itself a useful signal
 * about timing or initialization order.
 *
 * The eventual production kernel_main flow has no test suite; this
 * file exists for the duration of phase-1 bring-up and is expected
 * to be removed once the underlying controllers come up reliably.
 * See issue 110h for the design notes.
 */

#include <stdint.h>

/* The forward-declared interfaces the suite drives. Each lives in
 * its own source file; we resolve them at link time rather than
 * pulling in a header tree for a temporary suite. */
extern void debug_write(const char *text);
extern void debug_log_init(void);
extern void debug_log_flush(void);

extern int  sd_init(void);
extern int  sd_read_block(uint32_t lba, uint8_t *buffer);
extern int  sd_write_block(uint32_t lba, const uint8_t *buffer);

extern int  emmc_init(void);
extern int  emmc_read_block(uint32_t lba, uint8_t *buffer);

extern int  usb_endpoint_zero_bringup(void);

extern void led_set(int color, int on);
extern void led_set_stage(int stage);
extern void delay_busy(uint64_t cycles);

/* The same boot-stage enum values 002-main.c uses. We keep them
 * local rather than including a shared header because the LED
 * vocabulary is tiny and these two are the only ones we touch. */
#define STAGE_PANIC_GENERIC   1
#define STAGE_BACKUP_COMPLETE 4

/* A safe SD LBA the round-trip test can write to without
 * disturbing anything the bootloader or backup writer cares
 * about. 0x200000 is the same LBA the eMMC backup writer uses
 * as its destination — ~1 GB into the card, well clear of the
 * BootROM's read range and the bootable partition. */
#define TEST_SD_BUFFER_LBA 0x200000u

/* A small helper that turns an unsigned 32-bit value into a
 * decimal string and pushes it through debug_write. Used to log
 * iteration numbers and failure return codes. */
static void debug_write_uint(uint32_t value)
{
    char buf[12];
    int pos = 10;
    buf[11] = 0;
    if (value == 0) {
        buf[pos--] = '0';
    } else {
        while (value > 0u) {
            buf[pos--] = (char)('0' + (value % 10u));
            value /= 10u;
        }
    }
    debug_write(&buf[pos + 1]);
}

/* Same shape for signed values, since test return codes are
 * typically small negative integers identifying which branch of
 * the failing function returned. */
static void debug_write_int(int value)
{
    if (value < 0) {
        debug_write("-");
        debug_write_uint((uint32_t)(-value));
    } else {
        debug_write_uint((uint32_t)value);
    }
}

/* ---- The individual tests ---- */

/* Each test wrapper returns 0 on success or a non-zero value
 * the runner narrates as the failure code. We keep the wrappers
 * minimal: they exist mostly to give every entry the same
 * (void) -> int shape the runner expects. */

static int test_sd_init(void)
{
    return sd_init();
}

static int test_debug_log_init(void)
{
    /* debug_log_init has a log_ready guard; the second iteration
     * is a no-op. We still log a wrapper around it so the test
     * list reads uniformly. */
    debug_log_init();
    return 0;
}

static int test_emmc_init(void)
{
    return emmc_init();
}

/* Static scratch space for the round-trip test. .bss-allocated
 * so we don't pay the allocator on every call; safe because the
 * suite is single-threaded and the buffers are only touched
 * inside this one test. */
static uint8_t roundtrip_out[512];
static uint8_t roundtrip_in[512];

static int test_sd_roundtrip(void)
{
    /* Fill the out-buffer with a distinguishable pattern — XOR
     * the byte index with 0xA5 so neither all-zeros nor all-ones
     * matches the success case. */
    for (int i = 0; i < 512; i++) {
        roundtrip_out[i] = (uint8_t)(i ^ 0xA5);
    }

    int rc = sd_write_block(TEST_SD_BUFFER_LBA, roundtrip_out);
    if (rc != 0) {
        return -10 + rc;  /* -11, -12, -13 from sd_write_block's three failures */
    }

    /* Pre-fill in-buffer with a different pattern so a phantom
     * "success" where the read silently does nothing is visible
     * as a compare failure rather than a spurious pass. */
    for (int i = 0; i < 512; i++) {
        roundtrip_in[i] = 0xFFu;
    }

    rc = sd_read_block(TEST_SD_BUFFER_LBA, roundtrip_in);
    if (rc != 0) {
        return -20 + rc;
    }

    for (int i = 0; i < 512; i++) {
        if (roundtrip_in[i] != roundtrip_out[i]) {
            return -30;
        }
    }
    return 0;
}

/* Static scratch for the eMMC read test. Same reasoning. */
static uint8_t emmc_read_buf[512];

static int test_emmc_read_block_0(void)
{
    return emmc_read_block(0, emmc_read_buf);
}

/* ---- Read-only system probe ----
 *
 * Dumps registers we've never touched but want to understand:
 * the PMU CRU clock-gate registers (so 106c can find PWM1's
 * gate bit), the USB2 PHY GRF (so 109a can find the PHY power-
 * down register), and a handful of main-CRU clock-selector
 * registers (so we can see what source CCLK_EMMC is actually
 * running off and at what divider).
 *
 * Pure read-only. Cannot affect any peripheral state. Picks
 * up info we'd otherwise have to gather across multiple
 * separate experiments.
 *
 * The MMIO helpers are inline so we don't add another shared
 * header just for the suite. */
static inline uint32_t probe_read32(uintptr_t addr)
{
    return *(volatile uint32_t *)addr;
}

static void probe_dump(const char *label, uintptr_t addr)
{
    debug_write("[probe] ");
    debug_write(label);
    debug_write(" = ");
    /* Inline the hex format so we don't need another file-scope
     * helper. */
    static const char digits[] = "0123456789ABCDEF";
    uint32_t v = probe_read32(addr);
    char buf[13];
    buf[0] = '0'; buf[1] = 'x';
    for (int i = 0; i < 8; i++) {
        buf[2 + i] = digits[(v >> ((7 - i) * 4)) & 0xFu];
    }
    buf[10] = '\r'; buf[11] = '\n'; buf[12] = '\0';
    debug_write(buf);
}

static int test_system_probe(void)
{
    debug_write("[probe] --- PMU CRU clock-gates (covers PWM1 for 106c) ---\r\n");
    /* PMU CRU at 0xFDD40000. The 0x180 sweep from the previous
     * flash returned all zeros, so CLKGATE_CON isn't there.
     * The main CRU has its CLKGATE_CON registers at offset
     * 0x300+ (CRU + 0x300 = CLKGATE_CON_0, +0x304 = CON_1,
     * etc. — confirmed by our existing eMMC bring-up using
     * 0xFDD20324 = main CRU + 0x324 = CON_9). Try the same
     * 0x300-base in PMU CRU. */
    probe_dump("PMU_CRU + 0x300", 0xFDD40300u);
    probe_dump("PMU_CRU + 0x304", 0xFDD40304u);
    probe_dump("PMU_CRU + 0x308", 0xFDD40308u);
    probe_dump("PMU_CRU + 0x30C", 0xFDD4030Cu);
    probe_dump("PMU_CRU + 0x310", 0xFDD40310u);

    /* Also check the SOFTRST_CON family in PMU CRU. In main
     * CRU the SOFTRST_CON registers are at 0x400+. */
    probe_dump("PMU_CRU + 0x400", 0xFDD40400u);
    probe_dump("PMU_CRU + 0x404", 0xFDD40404u);
    probe_dump("PMU_CRU + 0x408", 0xFDD40408u);

    debug_write("[probe] --- USB2 PHY 0 GRF (covers 109a PHY power-down) ---\r\n");
    /* USB2 PHY 0 GRF at 0xFDCA0000, per the device tree. The
     * window is 8 KB; the PHY-control registers (USBOTG, USBHOST,
     * USBINT) live in the first 256 bytes typically. Dump the
     * first chunk. */
    probe_dump("USB2PHY0_GRF + 0x000", 0xFDCA0000u);
    probe_dump("USB2PHY0_GRF + 0x004", 0xFDCA0004u);
    probe_dump("USB2PHY0_GRF + 0x008", 0xFDCA0008u);
    probe_dump("USB2PHY0_GRF + 0x00C", 0xFDCA000Cu);
    probe_dump("USB2PHY0_GRF + 0x010", 0xFDCA0010u);
    probe_dump("USB2PHY0_GRF + 0x040", 0xFDCA0040u);
    probe_dump("USB2PHY0_GRF + 0x044", 0xFDCA0044u);

    debug_write("[probe] --- main CRU clock-selectors (CCLK_EMMC source) ---\r\n");
    /* Main CRU at 0xFDD20000. CLKSEL_CON registers start at
     * 0x100. The one for CCLK_EMMC is somewhere in the 0x10A0
     * region (above the SDMMC selectors); sweep a wide range. */
    probe_dump("CRU_CLKSEL_CON28 (0x170)", 0xFDD20170u);
    probe_dump("CRU_CLKSEL_CON30 (0x178)", 0xFDD20178u);
    probe_dump("CRU_CLKSEL_CON78 (0x238)", 0xFDD20238u);
    probe_dump("CRU_CLKSEL_CON80 (0x240)", 0xFDD20240u);
    debug_write("[probe] --- end ---\r\n");
    return 0;  /* probe never "fails" */
}

/* ---- The runner ---- */

typedef struct {
    const char *name;
    int (*fn)(void);
} test_entry_t;

/* The list runs top to bottom. Ordering matters only for tests
 * with dependencies — sd_roundtrip needs sd_init to have just
 * passed, emmc_read_block_0 needs emmc_init to have just
 * passed. Independent tests are placed in the order most useful
 * to bring up first. */
static const test_entry_t suite[] = {
    { "sd_init",            test_sd_init },
    { "debug_log_init",     test_debug_log_init },
    /* system_probe runs early so its dumps land in the log
     * even if a later test hangs. Read-only — never fails. */
    { "system_probe",       test_system_probe },
    { "emmc_init",          test_emmc_init },
    { "sd_roundtrip",       test_sd_roundtrip },
    { "emmc_read_block_0",  test_emmc_read_block_0 },
    /* usb_ep0_bringup is parked. The 109b reopen documents an
     * internal polling-loop hang; running it here blocks
     * iteration 2 of the suite from ever starting, which costs
     * us the per-iteration timing data the second pass is
     * supposed to produce. Bring this entry back when 109b's
     * fix lands. */
};
static const unsigned suite_count = sizeof(suite) / sizeof(suite[0]);

/* Cumulative fail count across both iterations. The end-of-suite
 * LED decision reads this value. */
static int fail_count;

/* Public entry. Initializes the log buffer first thing — the
 * buffer accumulates in DRAM and only flushes to SD once
 * sd_init has succeeded, so initializing it early is harmless
 * and means sd_init's own narration lands in the log too. */
void run_bringup_test_suite(void)
{
    debug_log_init();

    debug_write("\r\n[suite] phase-1 bring-up test suite starting\r\n");
    fail_count = 0;

    for (unsigned iter = 1u; iter <= 2u; iter++) {
        debug_write("\r\n[suite] iteration ");
        debug_write_uint(iter);
        debug_write(" of 2\r\n");

        for (unsigned i = 0; i < suite_count; i++) {
            debug_write("[suite]   ");
            debug_write(suite[i].name);
            debug_write(": running\r\n");

            int rc = suite[i].fn();

            debug_write("[suite]   ");
            debug_write(suite[i].name);
            if (rc == 0) {
                debug_write(": PASS\r\n");
            } else {
                debug_write(": FAIL rc=");
                debug_write_int(rc);
                debug_write("\r\n");
                fail_count++;
            }
            /* Force a flush at the end of each test so a hang
             * inside the next test leaves a complete record up
             * to this point on the SD card. */
            debug_log_flush();
        }
    }

    debug_write("\r\n[suite] done. fail_count=");
    debug_write_uint((uint32_t)fail_count);
    debug_write("\r\n");
    debug_log_flush();

    /* Final LED state. The any-fail case uses STAGE_PANIC_GENERIC
     * (top red, bottom dark) plus a slow amber heartbeat on the
     * bottom so the developer can distinguish "tests done, some
     * failed" from "kernel hung mid-suite." */
    if (fail_count == 0) {
        led_set_stage(STAGE_BACKUP_COMPLETE);
        while (1) {
            delay_busy(1000000);
        }
    } else {
        led_set_stage(STAGE_PANIC_GENERIC);
        int amber_on = 0;
        while (1) {
            amber_on = !amber_on;
            led_set(1, amber_on);   /* LED_AMBER = 1, see 004-led.c */
            delay_busy(2000000);
        }
    }
}
