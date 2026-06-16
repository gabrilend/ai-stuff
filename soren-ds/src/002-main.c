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

/* Forward declarations from the LED driver in 004-led.c. */
extern void led_init(void);
extern void led_set_stage(int stage);

/* Forward declarations from the page allocator in 008-allocator.c. */
extern void allocator_init(void);
extern void allocator_check_or_panic(void);

/* Forward declarations from the USB stack. */
extern int usb_init(void);                  /* 009-usb.c */
extern int usb_endpoint_zero_bringup(void); /* 010-usb-enumeration.c */
extern void usb_poll(void);                 /* 010-usb-enumeration.c */

/* Forward declaration from 013-boot-image.c. */
extern int write_kernel_to_emmc_boot_partition(void);

#include <stdint.h>

#define STAGE_KERNEL_MAIN     0
#define STAGE_PANIC_GENERIC   1
#define STAGE_USB_CONTROLLER  2

void kernel_main(void)
{
    /* Bring up the LED driver and signal "kernel_main reached"
     * before anything else. If anything fails after this point,
     * the developer can decode at least "we got to kernel_main"
     * from the LED pattern per the diagnostic-codes table. */
    led_init();
    led_set_stage(STAGE_KERNEL_MAIN);

    /* Initialize the page allocator and run its self-test. The
     * self-test confirms the bitmap math hands out distinct
     * page-aligned addresses and reuses freed pages. On failure
     * the call does not return — it lights the panic LED and
     * parks the core. */
    allocator_init();
    allocator_check_or_panic();

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

    /* Flash trigger — check the START button (GPIO3 PB1, active
     * low per the device tree). If it is held down at boot, the
     * kernel writes itself to the eMMC's boot partition through
     * issue 110b's function, lights the "panic" pattern on
     * failure or stays at "USB controller alive" on success
     * (the developer power-cycles to boot from eMMC). The full
     * runtime USB-C re-flash protocol is deferred to a phase 2
     * extension; this minimal trigger is enough to bootstrap
     * the device's eMMC from "Anbernic Android" to "SoreOS." */
    {
        volatile uint32_t *gpio3_ext_port = (volatile uint32_t *)0xFE760070u;
        uint32_t gpio3_value = *gpio3_ext_port;
        if ((gpio3_value & (1u << 9)) == 0) {
            /* START is pressed (active low). Trigger the
             * one-shot eMMC overwrite. */
            if (write_kernel_to_emmc_boot_partition() != 0) {
                led_set_stage(STAGE_PANIC_GENERIC);
                while (1) { __asm__ volatile ("wfi"); }
            }
            /* eMMC now has the kernel. Park the core; the user
             * power-cycles to boot from eMMC. */
            while (1) { __asm__ volatile ("wfi"); }
        }
    }

    while (1) {
        /* Service the USB event ring on every pass. The kernel
         * has nothing else to do until later issues land; polling
         * is the right scheduling discipline for this phase. */
        usb_poll();
    }
}
