# 601 — First light

## Current behavior

Every part of the seed has been built and tested alone. Nothing has been tested
as a seed.

**And as of 2026-08-08 there is a named reason it cannot be, which is better than
the general unease above.** A built image carries five regions at block
boundaries and no partition table, no filesystem and no file — while firmware
opens *one file on a FAT filesystem*. So there is nothing on a built image for a
firmware to find, and the switch cannot be thrown yet no matter what else is
ready. That is `502`'s near work.

The reason it went unnoticed is the thing this ticket was written to expect. Its
table below predicts failures in the *seams* rather than the parts, because every
part was tested alone under emulation. This is one of those seams, and it was
invisible for the reason the table gives: both halves were right about their own
half. The builder's layout matched what the engine looks for exactly. Nobody
asked the firmware, which is the component that has to find the first byte, and
the emulated boards never needed it to — they boot from a host directory the
emulator turns into a filesystem (`018`), so a built image has never been the
thing under test.

**What that changes about the plan below: the first light attempt gets one step
earlier than step one.** Before watching a serial port, build an image and
require a firmware to open it. If that fails, nothing downstream is diagnosable.

## Intended behavior

A card goes into a computer with nothing on it. Power arrives. The machine says
what processor it found, starts the matching engine, locates its own weights,
reports how much memory it has, and produces a token.

That is the whole of phases 1 through 5, proved in one motion, and it is the
first moment this project has anything rather than parts.

## Suggested implementation steps

1. Do it on the first target architecture before attempting the other two. When it
   fails it will fail for reasons that have nothing to do with the architecture,
   and finding those on one board is cheaper than on three.
2. Watch the serial port for the whole sequence. Every step from `402` and `102`
   narrates itself, and the last line before silence is the diagnosis.
3. Expect the failures to be in the seams rather than in the parts. Every part was
   tested alone under emulation; what has never been tested is the joins between
   them. The likely ones, in the order they will hurt:

   | | Why emulation missed it |
   |---|---|
   | Offsets the builder and the engine disagree about | Both were right about their own half |
   | Firmware handing over in a state nobody tested against | Emulated firmware is tidier — interrupts, processor mode, cache state |
   | Memory the map calls usable that is not | Real maps have holes in awkward places; emulated ones do not |
   | Unaligned access that a real processor refuses | Some emulators tolerate what some hardware faults on |
   | Initialisation waits that are too short | Timing is meaningless under emulation, so a wrong wait passes |

4. **Narrate more than feels reasonable.** The last thing drawn before the machine
   stops is the entire diagnosis. Verbose by default at first light; quieten it
   afterward, never before.
4. Record the time from power to first token. It is the number that says whether
   this is a computer or a demonstration.
5. Then repeat on the other two architectures, and on a board with no display, and
   on a board with no storage attached. The last is the case `docs/003` names as
   unresolved — every step after moving in assumes moving in finished — and this
   is where it stops being theoretical.

## Leave the card in

Nothing in this ticket removes the delivery medium, and nothing should. While it
is plugged in, the original of everything the machine was told is still readable
from it, so a machine that has overwritten its own instruction can be recovered
rather than reflashed (`docs/003`). Pulling it belongs to `602`, and only once
somebody has decided the machine is walking on its own.

## Blocks

`602`.

## Blocked by

`503`, and therefore everything.

## Related documents

`docs/003-datapath-the-bootstrap.md`, `docs/010-datapath-the-mind.md`.
