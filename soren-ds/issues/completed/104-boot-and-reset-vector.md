# 104 — Boot and reset vector

## Current behavior

The kernel's entry point is in place. `src/001-boot.s` defines
`_start` at the linker-script's load address — the first thing
the firmware reaches. It masks Debug / SError / IRQ / FIQ
through DAIFSet, loads the stack pointer from `__stack_top` (a
16 KB region the linker reserves above .bss), zeroes the .bss
section between `__bss_start` and `__bss_end`, and branches into
`kernel_main` in `src/002-main.c`. If `kernel_main` ever
returns, the boot code spins in WFI rather than letting
execution fall off into undefined bytes.

`kernel_main` itself is the simplest possible function:
an infinite WFI loop. Every later phase 1 issue adds something
inside it or in code it calls. The kernel image is 88 bytes —
the boot setup, the kernel_main body, and the linker-pinned
pool of address constants.

Disassembly confirms `_start` sits at exactly the load address
(`0x00280000`), `kernel_main` is reachable from the boot code,
and the stack top symbol resolves to 16 KB above .bss as the
linker script specifies.

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
