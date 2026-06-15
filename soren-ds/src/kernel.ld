/*
 * kernel.ld — linker script for the Soren DS kernel image
 *
 * Layout: text, rodata, data, bss in that order at the kernel's load
 * address. The load address is a placeholder for what u-boot on the
 * Anbernic RG DS will hand off to (RK3568 Android boot.img kernels
 * typically land at 0x00280000); the real value is pinned when issue
 * 110b wraps this image in the boot.img Anbernic's u-boot reads.
 *
 * ENTRY(_start) tells the linker which symbol is the program entry,
 * not where it lives in memory. The address of _start ends up at
 * whatever offset its enclosing section is mapped to.
 */

ENTRY(_start)

SECTIONS
{
    . = 0x00280000;

    .text : ALIGN(8) {
        /* Pin _start at the very top of .text so the entry symbol's
         * address matches the load address — useful for u-boot and
         * for any later boot.img wrapper that wants kernel_addr to
         * equal the address of code execution. */
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

    /DISCARD/ : {
        *(.note*)
        *(.comment)
        *(.eh_frame*)
    }
}
