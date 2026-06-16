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
extern int  emmc_backup_to_sd(uint32_t emmc_start_lba,
                              uint32_t sd_start_lba,
                              uint32_t sector_count);    /* 016-emmc-backup.c */
extern void debug_log_init(void);                       /* 017-debug-log.c */
extern void debug_log_flush(void);                      /* 017-debug-log.c */

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

    /* Step-by-step diagnostic checkpoints (issue 103g —
     * TEMPORARY). The previous round reached
     * STAGE_USB_CONTROLLER then cycled, which means one of the
     * post-USB-controller bring-up steps is the fault. Same
     * two unused two-light combinations the USB-side
     * diagnostic used:
     *
     *   Checkpoint A — about to configure USB endpoint zero.
     *                  LEDs: top green, bottom amber.
     *   Checkpoint B — about to bring up the eMMC controller.
     *                  LEDs: top yellow-amber, bottom dark.
     *
     * If the cycle's last visible LED is checkpoint A, the
     * endpoint-zero configuration is the fault site. If
     * checkpoint B, the endpoint-zero work succeeded but the
     * eMMC bring-up faulted. If the LED gets past checkpoint B
     * to a steady state (either STAGE_PANIC_GENERIC from a
     * clean panic in eMMC, SD, or debug-log init, or a held
     * checkpoint B if there is no LED change after, or
     * STAGE_USB_CONTROLLER again somehow), we know the eMMC
     * bring-up at least started successfully and the fault is
     * downstream.
     *
     * The SD and debug-log bring-up stay skipped for this
     * iteration so a fault in those does not muddle the
     * endpoint-zero / eMMC diagnostic. */
    led_set(0, 1); led_set(1, 1); led_set(2, 0);   /* CP A: top green + bottom amber */
    delay_busy(3500000);
    if (usb_endpoint_zero_bringup() != 0) {
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { delay_busy(1000000); }
    }

    led_set(0, 1); led_set(1, 0); led_set(2, 1);   /* CP B: top yellow + bottom dark */
    delay_busy(3500000);
    if (emmc_init() != 0) {
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { delay_busy(1000000); }
    }

    /* SD and debug-log bring-up skipped for this iteration —
     * the diagnostic above isolates endpoint-zero and the
     * eMMC bring-up; SD and debug-log come back in the next
     * round once these two are confirmed.
     *
     * The kernel sits here with checkpoint B's LED pattern
     * still set (top yellow-amber + bottom dark) if it got
     * past both bring-ups successfully — that pattern held
     * indefinitely is the "all good" signal for this round. */
    while (1) { delay_busy(1000000); }

    /* (Code below is unreachable while the petting wait loop
     * above is in place. Restored next iteration.) */
    if (sd_init() != 0) {
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { delay_busy(1000000); }
    }
    debug_log_init();

    /* Bring up the USB 2.0 PHY and the DWC3 controller in
     * device mode. On success, advance the LED stage so the
     * developer can see the controller is alive without needing
     * a host computer attached yet. On failure (controller did
     * not identify), drop into the generic panic pattern. */
    if (usb_init() != 0) {
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { __asm__ volatile ("wfi"); }
    }
    led_set_stage(STAGE_USB_CONTROLLER);

    /* Configure endpoint zero and start the controller. After
     * this returns successfully, the host can drive bus reset
     * and start enumeration. usb_poll services control transfers
     * from the main loop below. */
    if (usb_endpoint_zero_bringup() != 0) {
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { __asm__ volatile ("wfi"); }
    }

    /* The START-button bootstrap-flash trigger that issue 110d
     * documents lived here in commit history but is removed
     * pending 110e — until the eMMC writer's boot-partition LBA
     * is confirmed against the real partition table, invoking
     * the writer could corrupt u-boot. The flash trigger comes
     * back when 110e closes with the LBA verified. */

    /* Issue 110e: copy the first 200 MB of the eMMC to a
     * reserved region of the microSD card so the partition
     * table can be analyzed host-side after the card is pulled.
     * The reserved region starts at SD LBA 0x200000 (~1 GB
     * offset) — well above where the BootROM looks for a
     * bootable loader, leaving the SD card still bootable for
     * subsequent test cycles. Two hundred megabytes is 409,600
     * sectors at 512 bytes each. */
    if (emmc_init() != 0) {
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { __asm__ volatile ("wfi"); }
    }
    if (sd_init() != 0) {
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { __asm__ volatile ("wfi"); }
    }
    /* Bring up the SD-card-backed debug log now that the SD card
     * is writable. Every subsequent `debug_write` call also
     * appends to a ring buffer that periodically flushes to a
     * reserved region of the SD card. After the card is pulled
     * the developer can `dd` the region off the card and read it
     * as plain text. */
    debug_log_init();

    /* Copy the entire eMMC to the microSD card. The eMMC is
     * 32 GB = 67,108,864 sectors of 512 bytes. The microSD card
     * is at least 256 GB per the developer's setup. Reserved
     * region starts at SD LBA 0x200000 (~1 GB offset) so the
     * BootROM-relevant low sectors stay untouched and the SD
     * card remains bootable for subsequent test cycles. */
    if (emmc_backup_to_sd(0, 0x200000, 67108864) != 0) {
        debug_log_flush();
        led_set_stage(STAGE_PANIC_GENERIC);
        while (1) { __asm__ volatile ("wfi"); }
    }
    /* Final flush of the SD log before the success signal — make
     * sure the bring-up narration is on the card before the
     * developer powers off. */
    debug_log_flush();
    led_set_stage(STAGE_BACKUP_COMPLETE);

    while (1) {
        /* Service the USB event ring on every pass. The kernel
         * has nothing else to do until later issues land; polling
         * is the right scheduling discipline for this phase. */
        usb_poll();
    }
}
