# 105 — The tick is a dispatch table

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 104 |
| Blocks | 106, 108, 109, 110, 209 |
| Reads | [the tick and the timers](../../docs/003-the-tick-and-the-timers.md) |
| Open questions | B4 |

## Current behavior

Built. `src/031-the-tick.lua` holds `SYSTEMS`, all thirteen rows in the
documented order; `advance` brings every counter up to the tick, runs the rows,
and counts the tick. Rows whose systems are not built yet name the issue that
builds them. `assemble` and `ticks_of` exist. Ten thousand empty ticks take a few
hundredths of a second.

## Intended behavior

One tick is one pass over an **ordered table of systems**, and the order is
data. `SYSTEMS` is an array of rows; each row is a name, a function that takes
the world and returns nothing, and a flag saying whether the thread pool may
slice it by unit range. `advance(world)` walks the rows from one to the last,
calls each, and increments the tick. That is the whole heartbeat.

**Adding a system is adding a row.** The issue that builds a system adds its
row in the documented position; a system that is not in the table does not
run, and there is no other way to run one. In this phase the table holds only
the rows this phase builds — the command door, the claim pass, the snapshot —
and the documented order is a relative order that later rows slot into.

`assemble(modules, parameters)` is the one place the world is put together:
it allocates the arrays through the world module, raises the field through the
dune tool, opens the named streams, and wires each system's row to the module
that provides it. It returns a world ready for its first tick. The cast is
loaded by stem, so no module names another by number.

`advance(world)` returns whether the match continues. In this phase nothing
ends it; the rule that does arrives with the command truck.

Seconds exist only in the catalogue. One function here, `ticks_of(seconds)`,
converts them at load using the ticks-per-second parameter, and no rule ever
reads a clock.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "The heartbeat: an ordered table of systems." the-tick`.
2. Write the `SYSTEMS` table with its three rows for this phase, each a folded
   function, in the documented positions.
3. Write `advance(world)`: walk the table, then increment the tick, then return
   whether the match continues.
4. Write the loader that finds a module by stem in `src/` and refuses on zero or
   two matches — the same rule the test harness uses.
5. Write `assemble(modules, parameters)` as the sequence above, refusing if any
   module a row needs is absent.
6. Write `ticks_of(seconds)`.
7. Fill the companion, listing the rows and their positions.

## What happened

- **All thirteen rows exist now, and the ten unbuilt ones say so.** The phase 1
  test asserts the full documented order, not only this phase's rows. A row not
  yet built carries `waiting_for` with its issue number and runs nothing; the
  issue that builds a system replaces that with the module's stem and export,
  and from then on a missing module is refused when the tick is loaded, by
  name. So nothing is ever skipped silently, and the order is whole from the
  first tick.
- **Counters are brought up before the rows run**, in `COUNTERS` order, so the
  increment of now is settled before any system reads it.
- **`assemble(modules, parameters)`** takes a list of stems the caller needs and
  returns the validated world and those modules keyed by stem, refusing an
  absent one by name. The world's own allocate raises the field and seeds the
  streams, because the tests allocate worlds directly.
- **`ticks_of` lives in the timers** and the tick passes the match's rate in;
  the world needs it while making counters, before there is a tick. The rate
  is `ticks_per_second` in a new catalogue table, `assets/034-the-rules.lua`,
  added to the contract table with its stem.
- The tick also passes the world's loader through as `load` and `load_asset`.

## Related documents and tools

- [The tick and the timers](../../docs/003-the-tick-and-the-timers.md)
- [The shape of the code](../../docs/013-the-shape-of-the-code.md)
- The test program: [the dunes and the clock](../../tests/019-the-dunes-and-the-clock.lua)

## Still open

- B4: ticks per second. The working ruling is ten — enough that a shell's flight
  is several ticks, few enough that ten thousand matches overnight is a real
  number. It is a parameter and nothing structural depends on it.
