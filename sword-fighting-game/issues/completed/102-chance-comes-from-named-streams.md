# 102 — Chance Comes From Named Streams

| | |
| --- | --- |
| Phase | 1 — The spine |
| Blocked by | 101 |
| Blocks | 204, 206, 303, 304, 404, 504 |
| Files | `src/003-random-streams.lua` |

## Current behavior

Built as described in `src/003-random-streams.lua`. The FNV prime multiply
is done as a shift plus a small multiply, because a plain multiply of a
32-bit value by the prime passes 2^53 inside a double and loses bits. Each
stream steps past its first eight outputs, so neighbouring seeds give
unrelated battles. A helper adds a set's draw counts into the receipt's
totals. Tested in tests/031-the-spine.lua.

## Intended behavior

There is no global random generator and nothing reads the clock. A run has one
seed. Each system draws from its own named stream made from the seed and the
stream's name: `movement`, `hits`, `minds`, `ranged`, `campaign`, `scenery`,
`perks`. Changing how often the minds roll therefore cannot change which
swings are parried.

A stream is a 32-bit xorshift generator (shift triple 13, 17, 5) whose start
state is the seed mixed with an FNV-style hash of the name, with zero (the
generator's fixed point) redirected to a fixed odd constant. It offers: the
next float in [0, 1), an integer between two bounds, a chance(p) test, and a
pick from a list. Each stream counts its draws, which the receipt reports.

Bit operations use LuaJIT's `bit` library; under plain Lua 5.1 a tiny
pure-Lua replacement is not provided, because the project targets LuaJIT.

## Suggested implementation steps

1. Write the stream and the set-of-streams constructor.
2. Test: two streams from one seed differ; one stream from one seed repeats
   exactly; the float is always in [0, 1); the mean of many floats is near a
   half.
