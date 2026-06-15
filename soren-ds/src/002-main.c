/*
 * 002-main.c — kernel_main: the first C function the kernel runs.
 *
 * Reachable from the boot code in 001-boot.s after the stack
 * pointer is set and the .bss section is zeroed. Per the
 * non-returning expectation in the boot code, kernel_main never
 * returns; if it does, the boot code drops the core to WFI.
 *
 * Currently kernel_main does the minimum needed to signal "we
 * made it this far": bring up the LED driver, set the LED pattern
 * for STAGE_KERNEL_MAIN (green + amber on), then drop into a
 * low-power wait loop until later issues give the kernel something
 * to do here.
 *
 * The LED pattern is documented in docs/015-led-diagnostic-codes.md.
 */

/* Forward declarations from the LED driver in 004-led.c. */
extern void led_init(void);
extern void led_set_stage(int stage);

#define STAGE_KERNEL_MAIN 0

void kernel_main(void)
{
    /* First thing we do: light the "kernel is alive" pattern.
     * If anything in here faults, the LEDs do not change from
     * whatever the bootloader left, and the developer can decode
     * "kernel reached _start but not kernel_main" from the LEDs
     * per the diagnostic-codes table. */
    led_init();
    led_set_stage(STAGE_KERNEL_MAIN);

    while (1) {
        /* Wait for interrupt — low-power loop until later issues
         * give kernel_main something to do. Issue 105 wires up
         * exception handlers; 106 (this) lights the LEDs; the
         * rest of phase 1 fills in everything else. */
        __asm__ volatile ("wfi");
    }
}
