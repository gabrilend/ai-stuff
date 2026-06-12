# 201 — Multi-core bring-up

## Current behavior

Phase 1 brought up the device on core zero only. The chip has
more cores than that — the exact count is in 101's findings — but
they sit in their post-reset hold state, parked on whatever the
chip's secondary-CPU mailbox or holding pen mechanism is, waiting
for a write from core zero that tells them where to jump.

## Intended behavior

Every CPU core the chip exposes is awake and executing kernel
code. Each non-zero core has been:

- Released from its hold state by writing its entry address to
  the chip's secondary-startup mailbox (the specific register
  depends on the chip; 101 documents it).
- Pointed at a small bootstrap stub that runs the same per-core
  setup core zero already ran in phase 1 — vector base register,
  stack pointer, processor mode — and then jumps into the C
  worker entry function from 202.

A boot-time confirmation reports each core's id and its current
program counter through the USB CDC-ACM stream from 110. A
developer can read the boot log and verify all expected cores
checked in.

## Suggested implementation steps

1. `bring_up_secondary_cores()` — read core count from chip, loop.
2. `secondary_core_entry_stub` — assembly, per-core setup.
3. `secondary_core_report_in()` — write core id to debug stream.
4. From `kernel_main`, after phase 1's display work, call (1).

## Related documents

- `docs/003-threading-model.md`.
- `docs/001-architecture-overview.md` — the C bottom that this
  bring-up belongs to.

## Blocked by

101 (chip-specific secondary-startup mechanism), 104 (boot
infrastructure), 108 (per-core stacks need allocation), 110
(check-in messages go out the serial stream).

## Blocks

202, every phase 2 issue.
