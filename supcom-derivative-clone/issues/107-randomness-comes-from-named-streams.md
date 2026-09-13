# 107 — Randomness comes from named streams

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 101 |
| Blocks | 109, 403 |
| Reads | [the tick and the timers](../docs/003-the-tick-and-the-timers.md) |
| Open questions | none |

## Current behavior

Nothing. The tick document names the rule — every random draw names its stream
— and nothing draws. The phase 1 test program looks for a source file whose
stem is `random-streams` and asserts that two streams with different names
are independent and that the same name gives the same sequence.

## Intended behavior

There is no global random generator anywhere in the project. Every random use
opens a **stream by name**, and every stream is seeded from the match seed and
its own name, so that:

- the same seed produces the same sequence in every stream, on every machine;
- adding a new random use is adding a new name, and it does not disturb any
  existing stream's sequence — which is what keeps a replay recorded before the
  addition valid afterwards;
- a stream is drawn from in array order by the system that owns it, so the
  sequence of draws is the same on every worker count.

The generator uses only thirty-two-bit operations through the `bit` library, so
the handheld's C computes the same values: the seed and the name's bytes are
folded into a starting state by a small hash, and each draw advances the state
by a shift-and-xor step. `next_integer(stream, below)` returns an integer from
zero up to but not including `below`; `next_double(stream)` returns a double in
the unit interval from the same thirty-two bits.

Streams live in the world as flat arrays of state, one row per named stream,
so that the snapshot's hash covers them and a replay resumes them. The names in
use at the moment of writing: `roster-hurt`, `cloud-round`, `report-order`. The
dunes do not use a stream — their noise is a hash of position — and that is on
purpose, so the field never depends on draw order.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "Every random draw names its stream." random-streams`.
2. Write the seeding hash: fold the seed and each byte of the name; reject a
   state of zero, which the shift-and-xor step would never leave.
3. Write `open(seed, name)`, `next_integer(stream, below)`, and
   `next_double(stream)`, each a folded function over the stream's state.
4. Write the table of stream names and add the stream group to the world's
   layout.
5. Fill the companion, and put the generator's exact steps in it so the
   handheld's box can be checked against the same words.

## Related documents and tools

- [The tick and the timers](../docs/003-the-tick-and-the-timers.md)
- [Other players](../docs/011-other-players.md), which needs every machine to draw alike
- The test program: [the dunes and the clock](../tests/019-the-dunes-and-the-clock.lua)

## Still open

Nothing beyond the questions in the table.
