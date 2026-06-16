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

    /* --- GPIO LED color-cycling probe (issue 103e — TEMPORARY) ---
     *
     * Drive the three indicator LED pins directly through the GPIO
     * controller, before stack / .bss / vector-table setup and
     * before any C code. The earlier wink-pattern iteration of this
     * probe already confirmed the kernel reaches _start; the
     * cycling iteration is here because the first hardware run
     * showed two amber-colored lights when all three pins were
     * driven high together. The chip-side device tree claims three
     * pins routed to three physically distinct LEDs in three
     * different colors (green / amber / red), and that does not
     * match what the eye saw. The cycle answers which pin lights
     * which physical thing.
     *
     * The three pins are GPIO0_C4 (claimed green / power),
     * GPIO0_C5 (claimed amber / charging), and GPIO0_C6 (claimed
     * red / status). Each phase of the cycle drives one pin high
     * with the other two held low, then a phase drives all three
     * together, then a phase drives all three off. The developer
     * watches and reports which physical light is lit during each
     * phase and what color it appears.
     *
     * The whole cycle loops forever. Power-cycle the device to
     * stop. The rest of _start (stack, .bss zero, vector table,
     * branch to C) does not run while the probe is in place; this
     * file is, for now, a dedicated LED-cycling fixture rather
     * than a kernel.
     *
     * Three setup writes get the pins owned by the GPIO controller
     * and configured as outputs:
     *
     *   PMU_GRF + 0x14  pin-mux high-half register for GPIO0_C.
     *                   Clears the function fields for C4/C5/C6 to
     *                   zero (plain GPIO). The bootloader may have
     *                   left them in any function; this guarantees
     *                   the GPIO controller owns them.
     *   GPIO0  + 0x0c  data-direction high half. Marks pins
     *                   20/21/22 (= C4/C5/C6) as outputs.
     *
     * Then the cycle begins. Each phase writes a value to
     * GPIO0 + 0x04 (data register high half) that drives exactly
     * the pins it wants high and exactly the pins it wants low.
     * Each write uses the chip-family's write-mask convention —
     * upper sixteen bits mask, lower sixteen bits data — so only
     * the three pins we care about are touched and the fourth pin
     * sharing the register stays untouched.
     *
     * Phase timings are uniform — about 1.8 seconds at the chip's
     * 1.8 GHz operating point, longer at the crystal frequency —
     * so the developer's eye has a steady rhythm to anchor on.
     */

    /* Setup write 1: route C4/C5/C6 to function 0 (GPIO). */
    movz    w0, #0x0FFF, lsl #16
    movz    x1, #0x0014
    movk    x1, #0xFDC2, lsl #16
    str     w0, [x1]

    /* Setup write 2: mark C4/C5/C6 as outputs in GPIO0. */
    movz    w0, #0x0070
    movk    w0, #0x0070, lsl #16
    movz    x1, #0x000C
    movk    x1, #0xFDD6, lsl #16
    str     w0, [x1]

    /* Build the GPIO0 data-register high-half address once and
     * leave it in x1 through every phase below. */
    movz    x1, #0x0004
    movk    x1, #0xFDD6, lsl #16

.Lcolor_cycle:
    /* Phase 1 — C4 alone (the device tree's "green" pin).
     * Mask = bits 4/5/6 in the low half (0x70 << 16), value bits
     * 4 = 1, 5 = 0, 6 = 0 → low half = 0x10. */
    mov     w0, #0x0010
    movk    w0, #0x0070, lsl #16
    str     w0, [x1]
    movz    w2, #0xC000, lsl #16
10: subs    w2, w2, #1
    b.ne    10b

    /* Phase 2 — C5 alone (the device tree's "amber" pin).
     * Same mask; low half = 0x20 (bit 5). */
    mov     w0, #0x0020
    movk    w0, #0x0070, lsl #16
    str     w0, [x1]
    movz    w2, #0xC000, lsl #16
11: subs    w2, w2, #1
    b.ne    11b

    /* Phase 3 — C6 alone (the device tree's "red" pin).
     * Same mask; low half = 0x40 (bit 6). */
    mov     w0, #0x0040
    movk    w0, #0x0070, lsl #16
    str     w0, [x1]
    movz    w2, #0xC000, lsl #16
12: subs    w2, w2, #1
    b.ne    12b

    /* Phase 4 — all three high together.
     * Same mask; low half = 0x70 (bits 4/5/6). */
    mov     w0, #0x0070
    movk    w0, #0x0070, lsl #16
    str     w0, [x1]
    movz    w2, #0xC000, lsl #16
13: subs    w2, w2, #1
    b.ne    13b

    /* Phase 5 — all three off.
     * Mask half only; low half = 0 clears the three pins. */
    movz    w0, #0x0070, lsl #16
    str     w0, [x1]
    movz    w2, #0xC000, lsl #16
14: subs    w2, w2, #1
    b.ne    14b

    b       .Lcolor_cycle
    /* --- end of probe; rest of _start is unreachable here --- */

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
    /* Install the exception vector table from 005-vectors.s.
     * After this, any synchronous fault, undefined instruction,
     * or other exception takes the panic path through 006-panic.c
     * rather than producing undefined behavior. Synchronous
     * exceptions are not maskable by DAIF, so installing the
     * table is enough to catch them. IRQ / FIQ / SError stay
     * masked until later phase 1 issues have handlers worth
     * routing them to. */
    ldr     x0, =vector_table
    msr     vbar_el1, x0

    /* Hand off to C. kernel_main is not expected to return. */
    bl      kernel_main

    /* If it does return, sit in low-power wait. */
3:
    wfi
    b       3b
