/*
 * 000-main.c — placeholder entry point so the build system has
 *              something to compile and link.
 *
 * Issue 103 only needs SOMETHING to feed through the compile-and-link
 * pipeline; the linker has to resolve the _start symbol named by
 * kernel.ld. Issue 104 replaces this with the real reset vector,
 * stack setup, and C-entry handoff.
 *
 * Until 104 lands, _start sits in a low-power wait loop. If the
 * device ever boots this image (it won't, until 104+ provide the
 * boot environment), the cores spin in WFI doing nothing observable.
 * Strictly safer than letting execution fall off the end of the
 * function into whatever bytes happen to follow.
 */

void _start(void)
{
    while (1) {
        /* Wait for interrupt. On a Cortex-A55 this drops the core
         * to a low-power state until an interrupt or event arrives.
         * Since we haven't configured any interrupt sources yet
         * (104 / 105 will), the core stays here forever. */
        __asm__ volatile ("wfi");
    }
}
