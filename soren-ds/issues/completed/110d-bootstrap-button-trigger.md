# 110d — Bootstrap eMMC-overwrite trigger (button held at boot)

## Current behavior

`kernel_main` in `src/002-main.c` reads GPIO3 pin PB1 — the
START button per the device tree — immediately after the USB
controller bring-up. If the button reads active-low (pressed at
boot), the kernel calls into `write_kernel_to_emmc_boot_partition`
from 110b and parks the core; the developer power-cycles the
device, which then boots from the eMMC standalone.

The mechanism is a recovery-net for the case where the USB-C
runtime re-flash protocol from 110c is not available — either
because 110c is not yet implemented, or because USB connectivity
is broken on a particular device. It bootstraps the eMMC from
"Anbernic Android" to "SoreOS" the first time without requiring
a working USB-C flash channel.

The flash trigger does not run automatically. The kernel reads
the GPIO state only at the one specific moment after USB
controller bring-up; the rest of the time START is just a
regular gameplay button per `docs/004-input-model.md`.

## Why this is its own issue rather than scoped under 110c

Re-flashing the eMMC has two natural mechanisms with very
different shapes:

- **Runtime re-flash through the USB connection** (110c). The
  daily iteration loop the project committed to. Requires a
  full USB-C protocol layer on both ends — host tool, kernel-
  side accumulator, signing handshake.

- **One-shot button-held bootstrap** (this issue). The recovery-
  net for situations where the USB-C path is broken or has not
  been built yet. A few GPIO reads and a call into the writer.
  Simpler, smaller code surface, no protocol layer.

Pushing both under one issue would have meant either gating the
button trigger on the protocol existing first (wrong — the
button trigger is exactly what saves us when the protocol does
not work), or treating the button trigger as a "stub" of the
protocol (wrong — they are two different things, both useful).
Splitting cleanly lets each close on its own evidence.

## Current safety caveat

The eMMC writer that this trigger calls into uses a hard-coded
boot-partition LBA placeholder (`0x4000`). Until 110e closes by
confirming the LBA against the real eMMC's GPT, the writer can
land kernel bytes in the wrong eMMC region — potentially
corrupting u-boot. The button-trigger code path is therefore
left in place but unsafe to invoke until 110e closes. The
project's first hardware test should not hold the START button.

## Closing evidence

The kernel builds with the GPIO read and the call into 110b's
writer wired in. Disassembly confirms the GPIO base address and
bit-mask in the generated code match GPIO3 PB1.

The trigger has not been exercised on real hardware because
real-hardware testing is gated on 110e completing first.

## Choice of button

The vision document `docs/004-input-model.md` assigns START a
gameplay role. Reading it at boot is a footgun — a developer
who happens to be holding START during power-on triggers a
flash they did not intend.

A future revision can change the trigger to a less-likely-to-
be-held combination (for example, holding L1+L2+R1+R2 together
during power-on, which is impossible to do accidentally during
normal use). For phase 1's purposes the trigger exists; the
specific button is a footnote.

## Related documents

- `notes/safety/000-bricking-and-recovery.md` — recovery story
  if the trigger writes to the wrong eMMC region.
- `docs/004-input-model.md` — the assignment of START in the
  vision; the button-as-trigger usage is in tension with that
  and is acknowledged above.

## Blocked by

110b (the writer this trigger invokes).

## Blocks

Nothing in phase 1. This is a recovery-net, not on any other
issue's critical path.
