# 601 — First light

## Current behavior

Every part of the seed has been built and tested alone. Nothing has been tested
as a seed.

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
3. Expect the failures to be in the seams rather than in the parts: offsets that
   the builder and the engine disagree about, firmware handing over in a state
   nobody tested against, memory that the map says is usable and is not.
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
