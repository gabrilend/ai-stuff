# 801 — The simulation is a map of boxes

| | |
| --- | --- |
| Phase | 8 — The Handheld |
| Blocked by | 109, 209 |
| Blocks | 802, 805 |
| Reads | [the handheld](../docs/012-the-handheld.md) |
| Open questions | F2 |

## Current behavior

Nothing runs on the handheld. The simulation, once phases 1 through 3 are
built, is a LuaJIT program: an ordered table of systems, each a function over
flat arrays, sliced across a thread pool (issue 209) and fingerprinted every
tick (issue 109).

`tests/026-the-handheld.lua` asserts, on the Lua, the one property this issue
needs before a line of C is written: **every system in the tick is a pure
function that writes only its declared slice** — calling it twice on copies of
the same world produces the same world both times, and nothing outside the
slice changed. The direction is set (G1): hand-ported C boxes with the Lua as
the reference. The engine the boxes run on is pinned in `input/dependencies`
and lands in `libs/` as `900-cera.c` and `901-cera.h` through
`./install-dependencies`.

## Intended behavior

A `maps/` directory holding the simulation as a **map**, and a `src/boxes/`
directory holding the systems as **boxes**, in the format the ceramic core
engine reads:

- A box is a plain C function that takes arguments by value, returns one value,
  and **may not remember anything between calls** — no statics, no globals.
  Memory belongs to the station, which holds a value the box's own output is
  wired back into.
- A map is a text file of station lines. A station line is its kind, a name,
  and the box it places as `file.c:function`. Under it, `in N - other.M` runs a
  wire from another station's exit into input N; `out N - other.M` says the same
  from this side, so every wire is written at both ends; `in N = value` parks a
  constant; and `N$` marks a port as the map's argument or result.
- A station runs when, and only when, every input port holds a value, on a pool
  of workers. That is the whole scheduler, and it is the thread pool from issue
  209 with the slicing made explicit in the wiring.

The tick becomes a ring of stations in the order the dispatch table already
lists them — commands, income, construction, emit, move, claim, aim, fire, land,
die, the cloud, consequences, snapshot — each taking the world as its input and
returning it as its output, the last wired back into the first. The world is
one value flowing round the ring; a system that writes only its slice is a box
that returns the same value with one region changed. Sliced systems become
several stations over ranges, fanned out and rejoined, exactly as the pool
already runs them.

The Lua is the reference. Each box is ported one at a time, and a test runs the
Lua tick and the engine's map on the same seed for a run of ticks and compares
hashes after every one. A box whose hash diverges is a box that remembered
something, or a floating-point operation the two do differently — which is
also how F2 gets its evidence.

The map runs on the desktop first, through the engine's own build, before any
of it goes near the device.

## Suggested implementation steps

1. Run `./install-dependencies` so the engine's two files are in `libs/`.
2. Write the purity test in `tests/026-the-handheld.lua` against the Lua
   systems, and make every system pass it before porting any.
3. Make `maps/` and `src/boxes/`, and write `the-tick.map` with one station per
   system in the dispatch table's order, the world as the ring's value, and
   `0$` on the first station's input and the last station's output.
4. Port the world's flat arrays as one C struct with the same fields, sizes
   read from the catalogue at map load, zero everywhere.
5. Port the systems one at a time, foundations first: timers, streams, the
   door, then move, claim, aim, fire, land, die. After each, run the hash
   comparison against the Lua for a run of ticks.
6. Port the fingerprint last, and assert it equals the Lua's over a whole
   headless match.
7. Record what the desktop engine build reports for cores busy and memory
   flat, the same numbers the sibling project paces its own phases against.

## Related documents and tools

- [The handheld](../docs/012-the-handheld.md)
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md) — the
  systems this issue ports
- `../input/dependencies` — where the engine is pinned
- `tests/026-the-handheld.lua`

## Still open

- **F2.** Whether doubles agree across a desktop and the handheld's cores. The
  hash comparison in step 5 finds out on the desktop engine first; the device
  answers it for real in issue 806.
- Whether the world flows round the ring as one value or is split into the
  per-system slices at the map level so the engine can copy less. The engine
  copies each input into the task; a whole world per station per tick is the
  simple version and may be the slow one.
