/*
 * 001-boot.s — kernel entry: the first instructions the device runs.
 *
 * The linker script pins _start at the kernel load address. Whoever
 * hands control off to us (Anbernic's u-boot, in the eventual flow)
 * jumps here. We assume aarch64 mode with a single core (core 0)
 * executing — secondary cores are parked by the bootloader per the
 * Linux aarch64 boot protocol and are not touched until phase 2's
 * multi-core bring-up.
 *
 * The minimum set of work this file must do before C code is safe
 * to run:
 *
 *   1. Mask all asynchronous exceptions. We have no handlers
 *      configured yet — issue 105 wires those up. An interrupt
 *      arriving here would jump to an undefined address.
 *
 *   2. Set the stack pointer to the top of the stack region the
 *      linker script reserves. C ABI assumes a usable stack at
 *      function entry; without this every C call would write into
 *      whatever bytes happen to be at SP's reset value.
 *
 *   3. Zero the .bss section so C statics with no initializer come
 *      up as zero. The C standard guarantees this; the silicon
 *      doesn't.
 *
 *   4. Branch to kernel_main, the C entry. AAPCS64 calling
 *      convention; the stack is 16-byte aligned by the linker
 *      script's placement of __stack_top.
 *
 * If kernel_main ever returns we drop into a low-power wait loop —
 * the safest thing to do when there is nowhere meaningful to go.
 */

.section .text._start, "ax"
.global _start
_start:
    /* Mask Debug / SError / IRQ / FIQ. DAIFSet is a special-purpose
     * register where setting bits masks the corresponding exception
     * source; the four-bit value 0xF covers all four masks. */
    msr     DAIFSet, #0xF

    /* Stack pointer. The linker places __stack_top above a 16 KB
     * region reserved after .bss. Stack grows downward from here. */
    ldr     x0, =__stack_top
    mov     sp, x0

    /* Zero .bss between the symbols the linker script defines.
     * Stores eight bytes per iteration; BSS is 8-byte aligned. */
    ldr     x0, =__bss_start
    ldr     x1, =__bss_end
1:
    cmp     x0, x1
    b.hs    2f
    str     xzr, [x0], #8
    b       1b
2:
    /* Hand off to C. kernel_main is not expected to return. */
    bl      kernel_main

    /* If it does return, sit in low-power wait. */
3:
    wfi
    b       3b
