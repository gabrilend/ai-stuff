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

#define STAGE_KERNEL_MAIN 0

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

    while (1) {
        /* Wait for interrupt — low-power loop until later issues
         * give kernel_main something to do. Issue 109 brings up
         * the USB controller; 111a brings up the display; the
         * rest of phase 1 fills in everything else. */
        __asm__ volatile ("wfi");
    }
}
