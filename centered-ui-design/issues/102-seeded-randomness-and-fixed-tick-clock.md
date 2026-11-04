# 102 — Seeded randomness and the fixed-tick clock

**Phase:** 1 — The world beneath
**Blocked by:** 101

**Blocks**: 103, 108, 601, 701, 801
**Related documents:** docs/datapath-world-tick.md, docs/architecture.md

## Current Behavior

No simulation exists.

## Intended Behavior

- The simulation advances in fixed steps (20 per second of game time by
  default, from `input/`), independent of frame rate. The view may draw at
  any rate; the simulation catches up by running whole ticks, never partial
  ones.
- Randomness comes from named streams (combat, terrain, offers, AI), each
  seeded from the game seed and the stream's name, using a generator whose
  output is identical on every machine (a small integer-only generator such
  as xorshift written with LuaJIT's `bit` library — not `math.random`, whose
  output differs between builds).
- Same seed + same command list = identical world, every time. A test runs a
  tick loop twice and compares world checksums.

## Suggested Implementation Steps

1. `src/003-the-random-streams.lua`: a stream is a table holding generator
   state (unsigned 32-bit numbers); functions to draw an integer in a range
   and a fraction 0–1.
2. `src/004-the-clock.lua`: tick counter, accumulator of real time, a step
   function that runs zero or more whole ticks.
3. `src/005-world-checksum.lua`: fold every number in the world into one
   checksum, in a fixed key order (sorted, never `pairs` order).
4. Tests: stream reproducibility, stream independence (drawing from one does
   not shift another), double-run checksum equality.
