# 206 — Keep something

## Current behavior

**Done, and tested with `205`** — `src/076` keeps, `src/078` checks, 28 of
28 on 2026-08-02 across both tickets, because they only work together.

Blocks and an extent, with no filesystem: the machine can build one if it
wants one, and building one into the seed would decide on its behalf how it
organises itself. It claims an extent, writes a mark, and finds that mark
again on a machine that has forgotten everything — and will not write over
the mark itself, which is the storage layer's version of the rule that a
machine must protect its own author.

A read-only medium refuses rather than pretending. That is the expected
case, not an exceptional one, since the seed is meant to be plugged into
machine after machine unchanged.

A mark naming a different device is reported rather than adopted: a disk
cloned from another machine carries one, and adopting it would mean two
machines writing over each other with nothing saying so.

**One defect worth keeping.** The mark was parsed with a pattern, and it has
hyphens in it — a hyphen in a Lua pattern is a quantifier, so the pattern
matched nothing, every field came back empty, and every claim looked like a
stranger's. It surfaced only because the refusal tried to name whose it was.
It is parsed by lines now.

Still to do, and belonging elsewhere: **moving in.** Writing the engine, the
weights and the text to claimed storage and handing control to that copy
needs a real machine to hand control to, and that is `601`.

## Intended behavior

Reading and writing persistent storage, so the machine can move in (`docs/003`)
and so the intent notes of `205` have somewhere to land.

## Suggested implementation steps

1. Reach storage through a standard class interface rather than a part-specific
   driver. This is not a preference — it is what makes the whole sequence
   possible. Operating an unknown device safely requires writing a note first, and
   writing a note requires storage, and the circle only opens because storage
   almost always answers to something standard. The seed therefore carries this
   one driver rather than expecting the machine to explore its way in.
2. **Target the interfaces real hardware uses, not the emulator's convenient
   one.** An emulator offers a paravirtual block device — a queue in memory and
   two registers — that is far simpler than anything on a real board, and taking
   it would mean the emulator loop and the hardware loop exercise different code
   from the first day. Emulators also model the real interfaces, so declining the
   easy one costs configuration rather than work. Write against those, and use the
   paravirtual device only as a known-good comparison when something is wrong.
2. Provide read and write of blocks, and a way to ask how large the device is and
   whether it can be written at all. A read-only delivery medium is the expected
   case (`docs/003`) and must be reported rather than discovered by a write that
   silently does nothing.
3. Provide enumeration: which storage devices exist, how large, how fast, whether
   removable. The machine chooses where to move in from this, and "least likely to
   be unplugged" cannot be judged without it.
4. Support the move: writing a copy of the engine, weights and text payload to
   chosen storage, and handing control to that copy. The window in which the
   machine exists in two places or neither is the one failure this design cannot
   help with, so it should be as short as the medium allows and its boundaries
   should be obvious in the code.
5. Do not build a filesystem. The machine can build one if it wants one. What the
   seed needs is blocks, an extent it owns, and the ability to find that extent
   again on the next boot.

## Blocks

`205`, and all of phase 6.

## Blocked by

`203`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — moving in, and why the seed stays a seed.
