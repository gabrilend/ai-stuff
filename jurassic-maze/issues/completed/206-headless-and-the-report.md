# 206 — Headless, And The Report

| | |
| --- | --- |
| Phase | 2 — The Eye |
| Blocked by | 108 |
| Blocks | 307, and every test after |
| Reads | [seeing it without a window](../docs/009-seeing-it-without-a-window.md) |
| Open questions | none |

## Current behavior

`047-the-headless-runner.lua` runs the whole thing under bare luajit and
`048-the-report.lua` gathers the numbers. `./run-maze --headless` is the front
door and `./run-many-mazes` is the sweep, one worker per core less two, with rows
written to the RAM tier as they finish so a sweep that is killed half way through
still leaves what it had done.

Distance is reported **per locomotion kind**, which is the measurement that
matters: a total that looks healthy can hide a whole locomotion row that stopped
moving anything.

The grep test in `tests/052-layering.lua` covers the engine, `math.random`, and
the camera stream, over every file under `src/`.

## Intended behavior

The whole thing runs under bare `luajit` with no graphics module loaded at all,
and prints a table of numbers.

This is the issue that makes the project testable. A simulation observed only by
a person watching has no tests, because "did that look right" is not an
assertion. Headless turns every property of a run into a number:

| Reported | Why it is a number worth having |
| --- | --- |
| bodies that never moved | one is a stuck body; forty is a broken rule |
| bodies that left the world | must be zero — the rim exists so that it is |
| distance travelled, per locomotion kind | a kind whose number collapses has stopped working, invisibly, in a window full of kinds that still work |
| deepest and highest layer visited | whether the staircases are used at all |
| bodies inside stone | must be zero. The guard against the worst bug in the project. |
| largest spatial bucket | a number that climbs means the meet pass is becoming quadratic |
| abandoned pathfinding searches | a search that failed silently is a body standing still for no reason |
| ticks spent per pass | where the time goes, without a profiler |
| the seed and every parameter | so the run can be had again |

And `./run-many-mazes`, which runs a great many of these with one worker per core
and prints the table you read in the morning.

## Suggested implementation steps

1. Write the report as a table of named numbers built up during the run, not as
   printed prose. The terminal viewer, the phase demo and the sweep all consume
   it.
2. Write the accumulators into the tick passes themselves, guarded by a flag, so
   a headless run measures and a windowed run does not pay for it.
3. Write the runner: parse arguments, build the world, run to a tick count,
   print. No engine import anywhere in its require chain.
4. Write the grep test that fails if any simulation file mentions the engine by
   name. Crude, and it catches this exact mistake.
5. Write the sweep as a worker-per-core fan-out over seeds, each writing its
   report to the RAM tier at `tmp/shared-memory/`, with the parent collating.
6. Write the determinism test on top of this: one seed, two runs, compare a
   checksum of every body's position after some thousands of ticks.
7. The last thing a run does is write goodbye to `output/`.

## Related documents and tools

- [Seeing it without a window](../docs/009-seeing-it-without-a-window.md)
- [Ways this could go wrong](../docs/027-ways-this-could-go-wrong.md)
