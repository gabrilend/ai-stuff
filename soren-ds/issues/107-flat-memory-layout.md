# 107 — Flat memory layout

## Current behavior

The kernel boots and can write to a debug channel, but the project
has no documented or enforced layout of physical RAM. The kernel
itself sits at the load address from 103, but where the stacks
live, where the heap starts, and which regions are reserved for
hardware (the display controller's framebuffer, for instance) are
not yet committed.

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
