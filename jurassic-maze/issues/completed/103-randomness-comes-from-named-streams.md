# 103 — Randomness Comes From Named Streams

| | |
| --- | --- |
| Phase | 1 — The Stone |
| Blocked by | nothing |
| Blocks | 104, 105, 106, 307, 404, 407, 604 |
| Reads | [randomness comes from named streams](../docs/005-randomness-comes-from-named-streams.md) |
| Open questions | none |

## Current behavior

Thirteen named streams, xorshift32 through LuaJIT's `bit` library, each seeded by
hashing its own name together with the run's seed so that two streams of one seed
do not start in the same place.

The determinism test draws fifty values from every stream two ways — each stream
to exhaustion in turn, then round-robin in the opposite order with seven extra
draws from the camera in every round — and asserts every other stream comes out
identical. It also asserts the camera *did* diverge, because otherwise the test
would be passing on the strength of nothing being connected to anything.

`shuffle` walks downward, which is the version that is uniform; walking upward and
drawing from the whole range is the common mistake and is not. A ten-thousand-run
check on five items holds every position to within a few percent of a fifth.

## Intended behavior

A small set of **named seeded generators**, each advancing only when its own
system draws from it. No global generator, and nothing takes a number from the
clock.

The property being bought is that the sequence a given system draws from a given
seed is stable no matter what else in the project is edited. Without it, a change
to how a creature idles shifts every later draw and the maze itself moves.

The generator is xorshift32 through LuaJIT's `bit` library. The shift triple
**13, 17, 5** is Marsaglia's and is not a knob; changing any of the three
silently shortens the period enormously. **Zero is the fixed point** and produces
zeros forever — reachable only if a seed equals a stream name's hash, rare and
utterly baffling to debug, so it is redirected rather than left as a trap.

The streams are listed in
[the document](../docs/005-randomness-comes-from-named-streams.md). The one rule
that is easy to get wrong: **the `camera` stream exists and the simulation never
reads it.** A viewer drawing from a simulation stream makes the simulation depend
on whether anybody is watching.

## Suggested implementation steps

1. Write the stream: a table with `name`, `state`, `count`, and the methods
   `next_raw`, `next_float`, `next_below`, `next_between`, `pick` and `shuffle`.
   Everything built on `next_raw`.
2. Seed a stream by hashing its name together with the run's seed, so that two
   streams of one seed do not start in the same place.
3. Write `make_set(seed)` returning every stream the project uses, so that
   nothing constructs a stream inline and nothing is unnamed.
4. Accept `next_below`'s modulo bias deliberately, and write down why in a
   comment: with limits in the low hundreds against a 2^31 span the bias is
   under one part in ten million, and rejection sampling would make the number of
   generator steps depend on the values drawn — which would make a recorded run
   depend on them too.
5. Write the determinism test: build two sets from one seed, draw a thousand
   values from each stream in a different interleaving, assert the per-stream
   sequences are identical.
6. Write the grep test that fails if `math.random` appears anywhere under `src/`.

## Related documents and tools

- [Randomness comes from named streams](../docs/005-randomness-comes-from-named-streams.md)
- [Ways this could go wrong](../docs/027-ways-this-could-go-wrong.md) — determinism rots quietly
