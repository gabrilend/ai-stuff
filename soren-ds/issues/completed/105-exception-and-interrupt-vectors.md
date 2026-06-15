# 105 — Exception and interrupt vectors

## Current behavior

The kernel installs a 2 KB-aligned, sixteen-entry exception
vector table on boot. `src/005-vectors.s` defines the table at
`vector_table`; each entry puts a numeric index in `x0` (so we
can tell which vector type fired) and branches to a common
`panic_stub` that captures the faulting PC (from `ELR_EL1`) and
the exception syndrome (from `ESR_EL1`) and calls into the C
`panic_handler` in `src/006-panic.c` with three arguments.

The C panic handler is marked `noreturn`, sets the LED pattern
for `STAGE_PANIC_GENERIC` (green and amber off, red solid), and
sits in WFI forever. The captured exception state is currently
unused — issue 110's USB CDC-ACM stream is the channel future
panic versions will write the vector / PC / syndrome through;
until then, the red LED is the only output.

The boot code in `src/001-boot.s` installs the table by
writing its address into `VBAR_EL1` between zeroing `.bss` and
branching into C. Synchronous exceptions (bad pointers,
undefined instructions, alignment faults) are not maskable by
DAIF; the existing DAIF mask in boot stays put for IRQ / FIQ /
SError, which have no real handlers yet and would just panic
anyway if delivered.

Disassembly confirms the layout: `vector_table` at `0x00280800`
(the first 2 KB-aligned address inside `.text` after the boot
code, the LED driver, and the PWM driver), entries every `0x80`
bytes through `0x00280f80`, `common_panic` at `0x00281000`
exactly where the table ends.

## Intended behavior

A vector table is installed at the address the CPU expects for
exception entry. Every vector points to a handler that, for now,
captures the exception type and the program counter at the point
of failure, sets the panic LED pattern from 106 (so the device's
LEDs make the failure visible without any cable), optionally
writes a text description through the USB CDC-ACM stream from 110
if that channel has been initialized at the moment of panic, and
halts the CPU. The reset vector remains the boot code from 104.

We do not yet handle interrupts usefully; the interrupt vector
also routes to the panic handler. Phase 2 will replace that with
real interrupt dispatching when the threading core needs it.

The point of this issue is not to handle exceptions gracefully; it
is to make sure a misbehaving piece of code produces a *legible
failure* rather than a silent hang. Debugging a system without
this is much harder than debugging one with it.

## Suggested implementation steps

1. Write the vector table in assembly. Each entry jumps to a
   common panic stub.
2. Write the panic stub in C. It accepts the exception type and
   the saved program counter, sets the panic LED pattern, writes
   the text description through CDC-ACM if available, and enters
   an infinite loop.
3. Install the vector table at boot time by setting the chip's
   vector base register from the boot code in 104.

## Related documents

- `docs/002-roadmap.md` — phase 1.
- `docs/003-threading-model.md` — phase 2 will revisit interrupt
  dispatch when threading needs it.

## Blocked by

104, 106 (the panic stub uses the LED). 110 enriches the panic
output with text when it is available but is not strictly
required for the handler to function.
