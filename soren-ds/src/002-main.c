/*
 * 002-main.c — kernel_main: the first C function the kernel runs.
 *
 * Reachable from the boot code in 001-boot.s after the stack
 * pointer is set, .bss is zeroed, and the exception vector table
 * is installed. Per the non-returning expectation in the boot
 * code, kernel_main never returns; if it does, the boot code
 * drops the core to WFI.
 *
 * Currently kernel_main does the minimum needed to signal "we
 * made it this far" and to bring up the subsystems other phase 1
 * issues depend on:
 *
 *   - LED driver (issue 106): so the device has a voice from
 *     boot onward.
 *   - Stage signal (issue 106): so a developer staring at the
 *     LEDs can tell roughly where the kernel is.
 *   - Page allocator (issue 108): so any later code that needs
 *     memory can ask for it. No callers yet; the call is here
 *     for the dependency to be available.
 *
 * Then drops into a low-power wait loop until later issues give
 * the kernel something to do here.
 *
 * The LED pattern at the moment of WFI is documented in
 * docs/015-led-diagnostic-codes.md.
 */

#include <stdint.h>

/* Forward declarations from the LED driver in 004-led.c. */
extern void led_init(void);
extern void led_hello(void);
extern void led_set_stage(int stage);
extern int  led_current_stage(void);
extern void led_set(int color, int on);  /* for 103g checkpoints */

/* Forward declarations from the page allocator in 008-allocator.c. */
extern void allocator_init(void);
extern void allocator_check_or_panic(void);

/* Forward declarations from the USB stack. */
extern int usb_init(void);                  /* 009-usb.c */
extern int usb_endpoint_zero_bringup(void); /* 010-usb-enumeration.c */
extern void usb_poll(void);                 /* 010-usb-enumeration.c */

/* Forward declarations. */
extern int  write_kernel_to_emmc_boot_partition(void); /* 013-boot-image.c */
extern int  emmc_init(void);                            /* 012-emmc.c */
extern void emmc_dump_to_debug(uint32_t start_lba,
                               uint32_t count);          /* 014-emmc-probe.c */
extern int  sd_init(void);                              /* 015-sdmmc.c */
extern int  sd_write_block(uint32_t lba,
                           const uint8_t *buffer);       /* 015-sdmmc.c */
extern int  emmc_backup_to_sd(uint32_t emmc_start_lba,
                              uint32_t sd_start_lba,
                              uint32_t sector_count);    /* 016-emmc-backup.c */
extern void debug_log_init(void);                       /* 017-debug-log.c */
extern void debug_log_flush(void);                      /* 017-debug-log.c */
extern void run_bringup_test_suite(void);               /* 018-bringup-test-suite.c */
#ifdef SOREN_PROBES
extern int  probe_engine_run(void);                     /* 019-probe-engine.c */
#endif

#define STAGE_KERNEL_MAIN     0
#define STAGE_PANIC_GENERIC   1
#define STAGE_USB_CONTROLLER  2
#define STAGE_USB_ENUMERATED  3
#define STAGE_BACKUP_COMPLETE 4

/* delay_busy — block for roughly the given number of CPU cycles.
 *
 * Phase 1 has no clock source yet (interrupts are masked until the
 * timer driver lands), so timed pauses are done by counting nops
 * in a volatile-counter loop. The "cycles" parameter is an
 * approximation — the actual wall-clock duration depends on what
 * frequency the bootloader booted us at.
 *
 * The watchdog pet inside the loop is the phase-1 mechanism that
 * keeps the chip's hardware watchdog alive (issue 103g). The
 * watchdog's BSP-default timeout is a few seconds; a delay that
 * runs longer than the timeout without petting would let the
 * watchdog fire and reset the chip. Petting at the start of every
 * delay and once every 65,536 iterations thereafter (a few
 * milliseconds at the chip's actual clock speed, comfortably
 * inside the timeout) keeps the counter fresh through any delay
 * this function might be asked to perform. The pet is a single
 * write of the byte value 0x76 to the watchdog's counter-restart
 * register (offset 0x0C from the watchdog's 0xFE600000 base).
 *
 * The `volatile` qualifier on the counter stops the compiler from
 * collapsing the loop as dead code; the inline assembly nop gives
 * each iteration a guaranteed unit of work and prevents the loop
 * body from being further reduced. */
void delay_busy(uint64_t cycles)
{
    volatile uint64_t remaining = cycles;
    *(volatile uint32_t *)0xFE60000Cu = 0x76u;
    while (remaining--) {
        if ((remaining & 0xFFFFu) == 0u) {
            *(volatile uint32_t *)0xFE60000Cu = 0x76u;
        }
        __asm__ volatile ("nop");
    }
}

void kernel_main(void)
{
    /* Silence the chip's watchdog before anything else — issue
     * 103g, phase 1.
     *
     * The Rockchip BSP boot blobs that run before u-boot proper
     * (the DDR-init trust-firmware) enable the chip's watchdog
     * hardware block as a safety net against their own
     * bring-up hangs. The mainline u-boot they launch into does
     * not disable the watchdog before booti — the upstream
     * Linux kernel takes over feeding it from its own watchdog
     * subsystem once the dw_wdt driver probes, several seconds
     * into Linux boot. Our kernel has no equivalent feeding
     * mechanism in phase 1, so the watchdog's BSP-default
     * timeout (a few seconds) fires before kernel_main can
     * complete its earliest work, the chip resets, and the
     * boot chain re-runs from the top. The visible symptom
     * during phase-1 hardware testing was a "two amber lights,
     * dark, green flash, two amber" cycle on the indicator
     * lights, repeating every few seconds.
     *
     * The DesignWare watchdog IP cannot be disabled by writing
     * to its own control register once it has been enabled —
     * the upstream driver's comments are explicit about this.
     * The only way to silence it from software is to put the
     * entire hardware block through a reset cycle via the
     * main clock-and-reset unit's soft-reset register. The
     * watchdog's SRST_WDT_NS soft-reset bit (reset ID 138,
     * which lives in bit 10 of SOFTRST_CON(8) at 0xFDD20420)
     * is asserted and then deasserted; the hardware block
     * goes back to its post-reset state with the enable bit
     * clear and the countdown not running, and stays there
     * for the rest of the kernel's lifetime.
     *
     * Both writes use the chip-family's write-mask convention
     * (upper sixteen bits select which lower-sixteen bits
     * change; bits the mask does not pick stay unchanged):
     *   0x04000400 — mask bit 10, value bit 10 set (assert)
     *   0x04000000 — mask bit 10, value bit 10 clear (deassert)
     *
     * Phase 2 or 3 replaces this silence with an explicit
     * re-enable and a soramech-scheduled petting task that
     * makes the watchdog the safety net it was designed to
     * be. See issue 103g and docs/017-clocks-and-timers.md
     * for the broader story. */
    *(volatile uint32_t *)0xFDD20420u = 0x04000400u;
    *(volatile uint32_t *)0xFDD20420u = 0x04000000u;

    /* Pet the chip's watchdog immediately, before any later
     * code can take long enough to let the watchdog fire. The
     * pet here resets the counter; the petting woven into
     * delay_busy keeps the counter fresh through every later
     * delay; the petting loop at the end of kernel_main keeps
     * it fresh while the kernel sits idle. Phase 2 or 3
     * replaces all of this with a soramech-scheduled periodic
     * pet task per issue 103g. */
    *(volatile uint32_t *)0xFE60000Cu = 0x76u;

    /* Bring up the LED driver and signal "kernel_main reached"
     * before anything else. If anything fails after this point,
     * the developer can decode at least "we got to kernel_main"
     * from the LED pattern per the diagnostic-codes table. The
     * hello flash before the stage signal makes the "kernel
     * reached kernel_main" message visible independent of
     * whatever LED state the bootloader handed off — see
     * issue 106a for why this matters. */
    led_init();
    led_hello();
    led_set_stage(STAGE_KERNEL_MAIN);

    /* Initialize the page allocator and run its self-test. The
     * self-test confirms the bitmap math hands out distinct
     * page-aligned addresses and reuses freed pages. On failure
     * the call does not return — it lights the panic LED and
     * parks the core. */
    allocator_init();
    allocator_check_or_panic();

    /* Bring up the USB 2.0 PHY and the DWC3 controller in
     * device mode. The clock-and-reset work the SD-card path's
     * bootloader does not do for us now lives at the top of
     * usb_init itself (the 109a reopen). On success, advance the
     * LED stage so the developer can see the controller is alive
     * without needing a host computer attached yet. On failure
     * (controller did not identify), drop into the generic panic
     * pattern. */
    if (usb_init() != 0) {
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { delay_busy(1000000); }
    }
    led_set_stage(STAGE_USB_CONTROLLER);

    /* USB endpoint zero configuration is *deferred* — see issue
     * 109b. kernel_main does not depend on it; debug_write
     * fans out to the SD-backed log regardless.
     *
     * The eMMC bring-up is now working (issue 110a resolved: the
     * dwcmshc ignores the SDHCI clock divider, so the card clock
     * is driven directly from the CRU mux). With the eMMC
     * readable, this is the real eMMC-to-SD backup the whole
     * effort was for (issue 110e) — pull the stock boot chain and
     * partition table off the internal eMMC so it can be analysed
     * host-side and, eventually, restored. The earlier
     * bring-up test suite (issue 110h) stays in the tree and will
     * become a callable target of the probe engine (110i). */

    /* Bring the SD card up first so the debug log has a backing
     * surface for everything after it. */
    if (sd_init() != 0) {
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { delay_busy(1000000); }
    }
    /* Checkpoint A — SD up. Top green + bottom amber. */
    led_set(0, 1); led_set(1, 1); led_set(2, 0);

    debug_log_init();

#ifdef SOREN_PROBES
    /* Diagnostic (--probes) build: the hardware-probe battery is
     * compiled in (issue 110i). Run every #AUTO-marked probe in
     * priority order, flush the results to the SD-backed log, and
     * park — the log is the deliverable. A normal build omits this
     * whole block, so a production image carries no probe code at all
     * and falls straight through to the eMMC backup below. (The old
     * design read the probe off the card at boot; it is now compiled
     * in, because a build flag is already a rebuild — see 110i.) */
    if (probe_engine_run()) {
        debug_log_flush();
        led_set_stage(STAGE_BACKUP_COMPLETE);
        while (1) { delay_busy(1000000); }
    }
#endif

    /* Bring up the eMMC. */
    if (emmc_init() != 0) {
        debug_log_flush();
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { delay_busy(1000000); }
    }
    /* Checkpoint B — eMMC up. Top yellow-amber + bottom dark. */
    led_set(0, 1); led_set(1, 0); led_set(2, 1);

    /* Back to the bottom-amber stage so the backup heartbeat
     * (a blinking bottom amber, one step per ~10 MB) reads
     * cleanly during the multi-minute copy. */
    led_set_stage(STAGE_USB_CONTROLLER);

    /* Copy the first 200 MB of the eMMC (LBA 0 onward) to the
     * microSD's reserved region at LBA 0x200000 (~1 GB in, clear
     * of the boot region and the debug log at 0x400000). 200 MB
     * = 409,600 sectors; at the legacy-mode 1-bit/24 MHz PIO rate
     * (~3 MB/s) that is on the order of a minute. This captures
     * the GPT, the Rockchip idbloader/u-boot/trust blobs, and the
     * start of the stock partitions — enough to read the real
     * layout and confirm the copy carries genuine card content
     * (not the stale SD data the pre-fix runs produced). The full
     * multi-GB stock-OS pull waits on the high-speed eMMC path
     * (8-bit bus + HS200 + DMA), a later issue. */
    if (emmc_backup_to_sd(0, 0x200000, 409600) != 0) {
        debug_log_flush();
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { delay_busy(1000000); }
    }
    debug_log_flush();
    led_set_stage(STAGE_BACKUP_COMPLETE);

    while (1) { delay_busy(1000000); }
}
