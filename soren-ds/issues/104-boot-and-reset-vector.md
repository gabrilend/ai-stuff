# 104 — Boot and reset vector

## Current behavior

The build system from 103 produces a kernel image, but the image
contains no code that knows how to take control after the device's
firmware hands off. There is no defined entry point at the
load address, no stack pointer setup, and no transition from the
chip's reset state to a state where C code is safe to run.

## Intended behavior

The very first instructions of the kernel image, at the address
the firmware jumps to after reset, perform the minimum setup
needed before C code can run:

- Set the stack pointer to a kernel stack defined in the linker
  script.
- Zero the BSS section so static variables start as zero.
- Disable interrupts (we don't have handlers yet).
- Set the processor mode appropriately for kernel code.
- Jump to a C entry function named `kernel_main`.

`kernel_main` exists in C and, for now, does nothing but loop
forever. It is the place all later phase 1 work will be added.

## Suggested implementation steps

1. Write the boot code in ARM assembly as `src/001-boot.s`. Keep it
   as small as possible — only what cannot be done from C.
2. Define `kernel_main` in `src/002-main.c`. It contains an empty
   infinite loop for now.
3. Update the linker script to mark the boot code as the entry
   point and place it at the expected load address.
4. Build the image and confirm it links without errors.

## Related documents

- `docs/002-roadmap.md` — phase 1.

## Blocked by

103.

## Blocks

105, 106.
