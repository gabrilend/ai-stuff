# 105 — Exception and interrupt vectors

## Current behavior

The kernel boots from reset (104) but has no exception or interrupt
vector table installed. If any exception fires (an undefined
instruction, a data abort, a prefetch abort, an interrupt request)
the CPU's behavior is undefined — most likely an immediate hang or
silent reboot, with no diagnostic information.

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
