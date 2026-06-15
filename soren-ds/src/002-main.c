/*
 * 002-main.c — kernel_main: the first C function the kernel runs.
 *
 * Issue 104 needs only an existence proof: kernel_main lives, is
 * reachable from the boot code in 001-boot.s, and does not return.
 * Every later phase 1 issue adds something inside this function or
 * one it calls into.
 *
 * For now, kernel_main does the simplest safe thing — drop the core
 * into a low-power wait loop. Issue 105 adds the exception vector
 * table the kernel will then need; 106 lights an LED as the first
 * observable signal that the kernel made it this far.
 */

void kernel_main(void)
{
    while (1) {
        /* Wait for interrupt: drop the core to a low-power state
         * until an interrupt or event arrives. No interrupt sources
         * are configured yet (issue 105 starts on that), so the
         * core stays here indefinitely. */
        __asm__ volatile ("wfi");
    }
}
