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

    /* --- GPIO LED probe (issue 103e — TEMPORARY diagnostic) ---
     *
     * Drive the three indicator LED pins directly through the GPIO
     * controller, before stack / .bss / vector-table setup and
     * before any C code. The goal is to answer one question on
     * hardware: did the kernel reach _start at all? Until we know
     * the answer to that, every downstream symptom is ambiguous.
     *
     * The three LEDs are wired to chip pins GPIO0_C4 (green / power),
     * GPIO0_C5 (amber / charging), and GPIO0_C6 (red / status), per
     * the upstream device tree. The PWM-driven LED layer further
     * down assumes the bootloader has routed those pins to PWM
     * output and that the PWM1 controller is clocked; the first SD
     * boot test after the load-address fix produced no LED activity,
     * so at least one of those assumptions is false. This probe
     * bypasses both of them — it routes the pins to plain GPIO and
     * drives them from the GPIO controller, which is in the chip's
     * always-on PMU clock subtree and needs no clock enable.
     *
     * Four writes do the work:
     *
     *   PMU_GRF + 0x14  pin-mux high-half register for GPIO0_C.
     *                   Clears the four-bit function fields for
     *                   pins C4 / C5 / C6 (bits 0-11 of the low
     *                   half) to zero, which is plain GPIO. The
     *                   function field for C7 (bits 12-15) is left
     *                   alone.
     *   GPIO0  + 0x0c  data-direction register, high half (pins
     *                   16-31). Bits 4, 5, 6 (pins 20, 21, 22 =
     *                   C4, C5, C6) set to one — outputs.
     *   GPIO0  + 0x04  data register, high half. Same three bits
     *                   set to one — driven high.
     *   GPIO0  + 0x04  same register, same three bits set to zero
     *                   after a long busy-wait — driven low.
     *   GPIO0  + 0x04  same register, three bits set to one again
     *                   after a shorter busy-wait — back high.
     *
     * The visible result is a wink: lights on, lights off after a
     * couple of seconds, lights back on and stay on through the
     * rest of the boot. The wink is asymmetric so the developer
     * can tell it from any static state the bootloader may have
     * left behind.
     *
     * All three peripheral writes use the chip-family's write-mask
     * convention. The upper sixteen bits of each thirty-two-bit
     * write select which lower-sixteen bits the hardware actually
     * updates; bits the mask does not pick stay unchanged. This
     * lets the probe touch the three pins it cares about without
     * disturbing the fourth pin sharing each register or any other
     * config bits the bootloader may have set.
     *
     * Lifetime: this is a one-shot diagnostic that lives at the top
     * of _start only until we know the kernel reaches it. Once the
     * yes/no answer is in, this whole block comes out and the
     * downstream PWM-driven LED layer comes back into reach. While
     * it is here, led_hello and led_set_stage cannot light the
     * LEDs at all — the pins are owned by the GPIO controller, not
     * the PWM controller.
     */

    /* PMU_GRF_GPIO0C_IOMUX_H = 0x0FFF0000.
     * Mask: bits 0-11 in the low half (bits 16-27 in the write).
     * Value: zero — pin function 0 = GPIO, applied to C4/C5/C6. */
    movz    w0, #0x0FFF, lsl #16
    movz    x1, #0x0014
    movk    x1, #0xFDC2, lsl #16
    str     w0, [x1]

    /* GPIO0_SWPORT_DDR_H = 0x00700070.
     * Mask: bits 4-6 in the low half (bits 20-22 in the write).
     * Value: ones — direction = output for pins 20/21/22. */
    movz    w0, #0x0070
    movk    w0, #0x0070, lsl #16
    movz    x1, #0x000C
    movk    x1, #0xFDD6, lsl #16
    str     w0, [x1]

    /* GPIO0_SWPORT_DR_H = 0x00700070.
     * Same bit selection as DDR; ones in the value half drive
     * the three pins high. */
    movz    w0, #0x0070
    movk    w0, #0x0070, lsl #16
    movz    x1, #0x0004
    movk    x1, #0xFDD6, lsl #16
    str     w0, [x1]

    /* Long busy-wait. About 1.8 seconds at the chip's 1.8 GHz
     * operating point (the bootloader's usual handoff frequency);
     * about a minute at the chip's 24 MHz crystal — still finite,
     * still observable. The loop is two instructions of arithmetic
     * and a backward branch, which we cost at roughly one cycle
     * per iteration. */
    movz    w2, #0xC000, lsl #16
10: subs    w2, w2, #1
    b.ne    10b

    /* Drive the three pins low. Mask half preserved; value half is
     * zero, so the bits the mask names go to zero. */
    movz    w0, #0x0070, lsl #16
    str     w0, [x1]

    /* Shorter busy-wait so the dark phase is visibly briefer than
     * the bright phase — gives the wink an asymmetric shape. */
    movz    w2, #0x6000, lsl #16
11: subs    w2, w2, #1
    b.ne    11b

    /* Back high, and leave them there. The kernel continues from
     * here and the LEDs stay on through whatever happens next. */
    movz    w0, #0x0070
    movk    w0, #0x0070, lsl #16
    str     w0, [x1]
    /* --- end of probe --- */

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
