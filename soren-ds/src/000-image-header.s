/*
 * 000-image-header.s — the sixty-four-byte recognition envelope
 * at the start of the kernel image.
 *
 * ROCKNIX's u-boot launches kernels through its booti command,
 * which reads the first sixty-four bytes of the image and looks
 * for the magic four-byte sequence "ARM\x64" at offset 56. If
 * the magic is there, booti loads the image and jumps to byte
 * zero of it; if not, booti refuses. The header below carries
 * that magic plus a handful of metadata fields booti reads to
 * size its in-memory copy.
 *
 * The first eight bytes of the header are also code, so that
 * either path the bootloader can take ends at our _start:
 *
 *   - If the bootloader calls booti, booti uses the magic at
 *     offset 56 to recognise us, loads the whole image to its
 *     configured load address, and jumps to byte zero. Byte
 *     zero is a NOP, which executes harmlessly; byte four is
 *     a branch to _start at byte sixty-four.
 *   - If something else jumps directly to byte zero without
 *     reading the header at all, the same path runs: NOP, then
 *     branch to _start.
 *
 * The role of this file is purely envelope. Nothing here
 * initializes hardware, sets the stack, or runs project code.
 * After the branch lands at _start (in 001-boot.s) the kernel
 * proper takes over.
 *
 * Byte layout (Linux invented the format; the name "ARM64 Linux
 * Image header" is historical, not a runtime indicator — see
 * issue 103c):
 *
 *   0-3   NOP
 *   4-7   branch to _start
 *   8-15  text_offset (zero; aarch64 ignores this field)
 *   16-23 image_size in bytes from the start of the header
 *         through the end of .bss — booti uses this to know
 *         how much RAM to reserve
 *   24-31 flags. We use 0x0a:
 *           bit 0 clear   → little-endian image
 *           bits 1-2 = 01 → 4 KiB page size
 *           bit 3 set     → load address is flexible (the
 *                           bootloader places us where its
 *                           configured kernel_addr_r points,
 *                           which on RK356x targets is
 *                           0x00280000 — our linker-pinned
 *                           load address)
 *   32-55 reserved (zero)
 *   56-59 magic "ARM\x64" — the four bytes booti's
 *         recognition check actually inspects
 *   60-63 reserved (zero)
 *
 * The linker script places this section at the start of the
 * loaded image, before .text._start, so the header lives at
 * the load address and _start lives sixty-four bytes after.
 */

.section .image_header, "ax"
.global image_header
image_header:
    nop                                    /*  0- 3  harmless landing if a bootloader jumps to byte 0 */
    b       _start                         /*  4- 7  jump to real entry at byte 64 */
    .quad   0                              /*  8-15  text_offset (ignored on aarch64) */
    .quad   __image_size_bytes             /* 16-23  image_size — linker fills this in */
    .quad   0x000000000000000a             /* 24-31  flags: LE / 4 KiB pages / placement flexible */
    .quad   0                              /* 32-39  reserved */
    .quad   0                              /* 40-47  reserved */
    .quad   0                              /* 48-55  reserved */
    .byte   'A', 'R', 'M', 0x64            /* 56-59  recognition magic "ARM\x64" */
    .long   0                              /* 60-63  reserved (PE-COFF offset slot, unused) */
