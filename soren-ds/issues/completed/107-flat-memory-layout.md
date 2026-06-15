# 107 — Flat memory layout

## Current behavior

The chip's full physical address space — DRAM, peripheral
register windows, and the gaps between them — is documented in
`docs/016-physical-memory-map.md`. The chunk of that map the
kernel's allocator actually reaches for is exposed at runtime
through three small functions in `src/007-memory.c`:

- `memory_pool_base()` returns the first page-aligned address
  above the kernel image and its reserved stack (one page above
  `__stack_top`, the linker symbol that already marks the top
  of the kernel's reserved stack region).
- `memory_pool_end()` returns the page-aligned end of populated
  DRAM (`0xC0000000` for the 3 GB Anbernic RG DS).
- `memory_pool_size()` returns the difference between them.

The reserved-by-lower-layer-firmware slice below the kernel
(`0x00000000` through `0x00280000`, covering BL31 / ATF and
Anbernic's u-boot) is documented in the memory-map doc but does
not surface in the kernel's exported functions because the
kernel allocator never approaches it — `__stack_top` is well
above that boundary.

What deliberately stays deferred to a later issue: the boot-time
dump that the original behaviour sketch proposed. Without the
USB CDC-ACM channel from 110, the only output channel is the
LED, and "the memory layout was committed" is implicit in the
kernel reaching `kernel_main` — the LED stage already says it.
A richer dump lands when 110 brings up a text channel that can
actually display the layout.

## Intended behavior

A small header file under `src/` defines named constants for every
region of physical RAM:

- The kernel image region (text, rodata, data, BSS).
- The kernel stack region.
- The heap region, where 108's allocator will hand out pages.
- Any hardware-reserved regions discovered in 101.

The linker script from 103 is updated to use these named regions
consistently. A boot-time dump of the layout is emitted through
whichever diagnostic channel is up at the moment the dump runs:
if the USB CDC-ACM serial port from 110 is already initialized,
the dump streams its full text there; otherwise the dump
collapses to a short LED-pattern code from 106 acknowledging that
the layout was committed. Either way a developer can confirm the
kernel believes the RAM looks the way we expect.

This is step one of the graduated memory model described in
`docs/007-memory-model.md`: a single flat physical address space,
no MMU, no translation. The same memory layout will still be
valid in step two (phase 9), with the MMU added on top to enforce
which regions each app can touch.

## Suggested implementation steps

1. From 101's findings, write `src/003-memory-layout.h` defining
   the regions as named constants.
2. Update the linker script to match.
3. In `kernel_main`, write a boot-time dump function. The function
   calls `debug_write` (110) if the serial channel is up; if it is
   not, the function falls through to setting a short LED-pattern
   stage code (106) instead. The function does not require the
   serial channel to exist.

## Related documents

- `docs/007-memory-model.md`.

## Blocked by

101, 106.

## Blocks

108.
