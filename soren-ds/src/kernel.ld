/*
 * kernel.ld — linker script for the Soren DS kernel image
 *
 * Layout: text, rodata, data, bss, then a small reserved kernel
 * stack at the high end. Everything lives at a single contiguous
 * region starting at the kernel's load address. The load address
 * is a placeholder for what u-boot on the Anbernic RG DS will
 * hand off to (RK3568 Android boot.img kernels typically land at
 * 0x00280000); the real value is pinned when issue 110b wraps
 * this image in the boot.img Anbernic's u-boot reads.
 *
 * ENTRY(_start) tells the linker which symbol is the program
 * entry, not where it lives in memory. The address of _start
 * ends up at the offset of its enclosing section in the loaded
 * image — which the KEEP() below pins at the very top of .text,
 * so _start's runtime address equals the load address.
 */

ENTRY(_start)

SECTIONS
{
    . = 0x00280000;

    .text : ALIGN(8) {
        /* Pin _start at the very top of .text so the entry
         * symbol's address matches the load address. The
         * boot code in 001-boot.s places _start in its own
         * .text._start section so this KEEP() can find it. */
        KEEP(*(.text._start))
        *(.text*)
    }

    .rodata : ALIGN(8) {
        *(.rodata*)
    }

    .data : ALIGN(8) {
        *(.data*)
    }

    .bss : ALIGN(8) {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    }

    /* Kernel stack — 16 KB. AAPCS64 requires 16-byte stack
     * alignment at function entry; we align both __stack_bottom
     * and __stack_top to 16. Stack grows downward from
     * __stack_top through __stack_bottom. */
    . = ALIGN(16);
    __stack_bottom = .;
    . += 16 * 1024;
    __stack_top = .;

    /DISCARD/ : {
        *(.note*)
        *(.comment)
        *(.eh_frame*)
    }
}
