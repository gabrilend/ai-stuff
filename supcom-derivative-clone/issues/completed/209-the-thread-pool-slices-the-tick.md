# 209 — The thread pool slices the tick

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 105, 201 |
| Blocks | 801 |
| Reads | [the tick and the timers](../../docs/003-the-tick-and-the-timers.md) |
| Open questions | none |

## Current behavior

Built. `src/049-thread-pool.lua` splits the unit rows into contiguous ranges
and runs each sliceable tick row over them through a backend. The default and
only backend built is `serial`. `advance` runs move, sight-and-aim and fire
through it. The worker count comes from `input/workers` (a number or `cores`)
or `--workers`, and the headless report prints it. One seed gives the same
fingerprints at one worker and at seven, and `trace_writes` / `outside` check
that every sliceable row writes only its own range.

## Intended behavior

**The tick is sliced across a pool of workers from the first system, not
later.** A program that was single-threaded first has a hundred quiet
assumptions that a pool breaks one at a time; a program written under the pool's
rule from the start has none.

The rule the pool enforces: **a sliced system may read anything and write only
its own slice.** A slice is a range of unit rows. The move pass, the aim pass,
and the fire pass each read the world and write only the rows in their range
(and, for fire, their own range of the shot buffer). Everything that writes
across rows — landing, dying, claiming, the cloud's rounds, the occupancy
rebuild — is **unsliced** and runs on one worker in a fixed order.

Which systems are sliceable is declared in the tick's dispatch table (issue
105): each row carries a flag, and the pool reads the flag rather than guessing.
A system that is flagged sliced and writes outside its range is a bug the phase 8
test catches: run the system twice on copies of the same world and compare; run
it on one slice and check that no row outside the slice changed.

The pool itself is small: a worker count read from the machine's core count at
start (overridable from `input/` for the reproducibility test, which runs with
one worker and with many and expects the same hash), a way to split a count of
rows into that many ranges, and a way to run one system over every range and
wait for all of them. On a computer the workers are LuaJIT threads through the
engine's threading or the vendored threading library; on the handheld they are
the runtime's own pool, and the systems are boxes — which is why 801 rests on
this.

**Determinism does not depend on the pool.** Sliced systems write only their own
rows, so the result of a tick is the same for one worker or eight, and the
reproducibility test asserts it. Anything that would make the answer depend on
which worker finished first is, by construction, an unsliced system.

## Suggested implementation steps

1. Claim `src/NNN-thread-pool.lua` with `./new-source-file thread-pool`.
2. Write `slice(count, workers)`: ranges of rows, as balanced as integer
   division allows, returned as a flat array of starts and ends.
3. Write `run_sliced(system, world)`: hands each range to a worker, waits, and
   returns; with one worker it is a plain loop, so a test can run the same
   system both ways.
4. Add the `sliced` flag to the tick's dispatch table rows and make `advance`
   (issue 105) call `run_sliced` for flagged rows and the system directly for
   the rest.
5. Read the worker count from `input/workers`, defaulting to the core count, and
   record it in the match report.
6. Write the phase 8 property as a helper the test can call on any system:
   copy the world, run on one slice, diff every array outside the slice, and
   name the first row that changed.

## What happened

- **The pool is an interface with a serial backend**, the default and the only
  one built. The hot path is Lua, and a threaded backend means vendoring effil
  or lanes into libs/, which is an open item for Ritz. Such a backend would join
  `BACKENDS` and change nothing else. It would have to keep the fire pass's
  shots in row order, for instance by giving each range its own stretch of the
  queue and joining them lowest first.
- **`slice` returns pairs `{first, last}`**, as the test reads them, rather than
  the flat array step 2 suggests.
- **A sliceable row may have a `before` step**, an unsliced pass its slices
  read, run once by `run_sliced`. The move pass's occupancy is the one case;
  movement exports it as `move_pass_before`.
- **The flag already existed** in the dispatch table (`sliceable`); `advance` and
  `advance_timed` now send flagged rows through `run_sliced`.
- **`input/workers`** is a new input file, a number or `cores` (the default, and
  also what an absent file means), read through `getconf`. `--workers` beats it,
  and the report has a `workers` line. The count is a process setting and not
  part of the world, so it is outside the fingerprint.
- **Step 6's helper is `outside`**, which names the first unit row written
  outside a range. `trace_writes` sees slots whose value changed, the only
  writes another worker could notice.
- **The reproducibility test** plays a 23-unit fight for 400 ticks at one worker
  and at seven and compares every tenth tick's fingerprint, as the coordinator
  asked.

## Related documents and tools

- [the tick and the timers](../../docs/003-the-tick-and-the-timers.md) — the thread pool section
- [the handheld](../../docs/012-the-handheld.md) — why a sliced system is a box
- [the shape of the code](../../docs/013-the-shape-of-the-code.md)
- `tests/020-things-that-roll-fly-and-sail.lua`, `tests/026-the-handheld.lua`

## Still open

Nothing beyond the questions in the table. Which threading library the computer
build uses is a dependency question for the manifest in `input/dependencies`,
not a design question; the exports are the same over any of them.
