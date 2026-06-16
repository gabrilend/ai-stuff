# 103c — Kernel image gains the bootloader-recognition header

## Current behavior

The build system (issue 103) produces `output/kernel.img` as
the raw output of `objcopy -O binary` from the linked ELF.
The image is just text + rodata + data, no header, no magic
bytes anywhere. The first four bytes are the encoding of
`msr DAIFSet, #0xF` — the first instruction of `_start` —
because the linker script pins `_start` at the very top of
`.text`.

ROCKNIX's u-boot on the SD card launches kernels through the
extlinux flow (the `LINUX` directive in `extlinux.conf`),
which calls u-boot's `booti` command. `booti` reads the first
64 bytes of the image and looks for the magic bytes `ARM\x64`
at offset 56 — the standardised header u-boot uses to
recognise a valid kernel image. Without that header at the
start of `kernel.img`, ROCKNIX's u-boot refuses to launch our
kernel, and the SD card boot chain stops there.

## Intended behavior

The build system emits `output/kernel.img` with a 64-byte
recognition header at the start. The bytes are arranged so
that:

- Offset 0: a 4-byte NOP. If the bootloader jumps directly to
  the start of the image (rather than calling `booti`), the
  NOP executes harmlessly and control falls through.
- Offset 4: a 4-byte branch instruction that jumps to our
  `_start` at offset 64.
- Offsets 8-15: text_offset, zero. (Ignored on aarch64.)
- Offsets 16-23: image_size in bytes, little-endian. The
  bootloader uses this to size the in-memory region it
  reserves for the image. Computed from a linker symbol that
  measures the distance from the load address through the end
  of `.bss`.
- Offsets 24-31: flags, little-endian. We use
  `0x000000000000000a` (little-endian image, 4 KB page size,
  any-2MB-aligned load address acceptable).
- Offsets 32-55: reserved, zero.
- Offsets 56-59: magic `ARM\x64` — the only bytes the
  bootloader's recognition check actually inspects.
- Offsets 60-63: reserved (a PE-COFF offset slot we don't
  use), zero.

`_start` lives at offset 64 in the resulting image. The
kernel's load address stays at `0x00280000`; the bootloader
loads the whole image (header + code) there and jumps to it.
The CPU executes the NOP at offset 0, the branch at offset 4,
and lands at `_start` at offset 64. Two instructions of
glue, then our existing boot code runs unchanged.

After this issue closes, `xxd output/kernel.img` shows the
header at the top, `ARM\x64` at offset 56, and the familiar
`msr DAIFSet` encoding at offset 64.

## Why this header, and why this is not "running Linux"

The header's full name is "ARM64 Linux Image header" because
Linux invented the format. The name is historical — the
header is a bootloader data-format convention, not a runtime
indicator. The bytes do not invoke Linux services, link
against a Linux kernel, or constrain what our kernel does
after byte 64. Other operating systems (BSDs, microkernels,
bare-metal payloads) prepend the same 64 bytes for the same
reason: u-boot's `booti` is the loader path their target
bootloader exposes, and `booti` recognises images by this
header.

Structurally the role is identical to the Android boot.img
envelope (issue 110b) we will eventually use on the eMMC
side: a small bag of bytes at the start of the image whose
only purpose is to satisfy one specific bootloader's
recognition check. Different bootloader, different envelope,
same idea.

## Implementation steps

1. Add a new assembly source file (`src/000-image-header.s`,
   choosing index 0 so it sorts before the existing boot code)
   that places a section named `.image_header` containing the
   64 bytes described above. The branch at offset 4 is written
   as `b _start` so the assembler computes the offset; if the
   linker places `.image_header` immediately before `_start`,
   the branch lands correctly.
2. Update `src/kernel.ld` to place `.image_header` at the very
   start of the loaded image, before `.text._start`. Currently
   the linker script puts `_start` at the load address; the
   new layout puts the header at the load address and `_start`
   64 bytes later. Add a linker symbol `__image_size_bytes`
   measuring `__bss_end - <load_address>`; reference it from
   the header source so the image_size field reflects the
   actual runtime footprint.
3. Break the exception vector table out of `.text` into its
   own output section. aarch64 requires the vector table at a
   2 KB-aligned address; if it shares an output section with
   `.text._start`, that 2 KB alignment requirement propagates
   to the whole output section and pushes `_start` ~2 KB
   away from the recognition header. Rename the section in
   `src/005-vectors.s` from `.text.vectors` to `.vectors`,
   and add a `.vectors : ALIGN(2048)` output section in
   `kernel.ld` after `.text`. The `vector_table` symbol stays
   global, so its address resolves regardless of which section
   it lives in.
4. Verify by inspection: `xxd output/kernel.img | head -4`
   shows the NOP at offset 0, a branch at offset 4 whose
   offset reaches byte 64, `ARM\x64` at offset 56, and the
   first instruction of `_start` (the encoding of
   `msr DAIFSet, #0xF`, bytes `df 4f 03 d5`) at offset 64.
5. Build the kernel under the cross-toolchain; confirm the
   ELF still links and the resulting `kernel.img` boots when
   103b's bootable-SD assembler lands and we flash a card.

## Things this issue deliberately does not do

- *Validate the image runs on hardware.* That happens when
  103b's bootable-SD assembler lands and we flash a card.
  This issue stops at "image has the correct header bytes."
- *Wrap the kernel for Anbernic's u-boot.* The Android boot.img
  envelope is a separate concern (issue 110b) for the eMMC
  side. This header is for ROCKNIX's u-boot on the SD card.
- *Change the kernel's load address.* `_start`'s in-memory
  address shifts by 64 bytes, but the load address itself
  remains `0x00280000`. The header lives in the same memory
  region the kernel runs from.

## Related documents

- `docs/014-hardware-overview.md` — boot chain stages and
  what each one expects to find at its handoff.
- `notes/safety/000-bricking-and-recovery.md` — why getting
  the boot chain right matters and what happens when it fails.

## Blocked by

103 (the build system this issue extends).

## Blocks

103b (the SD card assembler treats `kernel.img` as a blob
loadable by `booti`; the header must already be in place
when the assembler reads the image).

## Parent

103.
