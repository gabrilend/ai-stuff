/*
 * kernel.ld — linker script for the Soren DS kernel image
 *
 * Layout: a sixty-four-byte recognition header from
 * 000-image-header.s, then text, rodata, data, bss, then a
 * small reserved kernel stack at the high end. Everything
 * lives at a single contiguous region starting at the
 * kernel's load address.
 *
 * The load address is 0x00280000, the conventional Rockchip
 * kernel load on the RK356x family. Both ROCKNIX's u-boot
 * (which launches us during SD-card development boot) and
 * Anbernic's u-boot (which will launch us once 110b
 * overwrites the eMMC's boot partition) load to this address,
 * so the same kernel image works on either path.
 *
 * ENTRY(_start) tells the linker which symbol is the program
 * entry, not where it lives in memory. The address of _start
 * ends up at the load address plus sixty-four bytes — sixty-
 * four for the recognition header pinned ahead of .text by
 * the .image_header section below, plus zero offset within
 * .text where the KEEP() places _start at the top. The branch
 * in the header at byte four reaches _start; that is how
 * control passes from the header bytes to actual project
 * code.
 */

ENTRY(_start)

SECTIONS
{
    . = 0x00280000;
    __image_start = .;

    .image_header : ALIGN(8) {
        /* Sixty-four bytes from 000-image-header.s. Lives at
         * the load address so the bootloader's recognition
         * check at offset 56 (the "ARM\x64" magic) finds
         * what it expects, and so the branch at byte 4 of
         * the header is at a known relative offset to
         * _start. */
        KEEP(*(.image_header))
    }

    .text : ALIGN(8) {
        /* Pin _start at the top of .text so the recognition
         * header's branch at byte 4 lands on the first
         * instruction of the boot code in 001-boot.s. The
         * boot code places _start in its own .text._start
         * section so this KEEP() can find it independently
         * of source-file ordering. */
        KEEP(*(.text._start))
        *(.text*)
    }

    .vectors : ALIGN(2048) {
        /* aarch64 requires VBAR_EL1 to point at a 2 KB-
         * aligned table of sixteen 128-byte vectors. Keeping
         * the table in its own output section means the
         * 2 KB alignment requirement does not propagate
         * back to .text — without this, .text would itself
         * need 2 KB alignment and _start would land far
         * from the recognition header instead of at byte
         * sixty-four. */
        KEEP(*(.vectors))
    }

    .rodata : ALIGN(8) {
        *(.rodata*)
    }

    .data : ALIGN(8) {
        *(.data*)
    }

    /* End of the on-disk kernel image. Everything from the
     * load address through here is bytes the bootloader must
     * copy from its source (the SD partition, the eMMC boot
     * partition, or whatever future paths arrive) into RAM;
     * everything after here (.bss and the kernel stack) is
     * zero-init memory that the boot code in 001-boot.s
     * establishes at runtime. The eMMC-write code in
     * 013-boot-image.c reads this symbol to size the Android
     * boot.img it builds. */
    . = ALIGN(8);
    __image_end = .;

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

    /* Recognition-header image_size field. The bootloader
     * reads this from byte 16 of the loaded image and uses it
     * to know how much RAM the kernel needs reserved for it,
     * including .bss — distinct from the on-disk image size
     * (__image_end - __image_start). The header source file
     * references this symbol; the linker substitutes its
     * value at link time. */
    __image_size_bytes = __bss_end - __image_start;

    /DISCARD/ : {
        *(.note*)
        *(.comment)
        *(.eh_frame*)
    }
}
