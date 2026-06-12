# 211 — Phase 2 demo: torture test

## Current behavior

Issues 201 through 210 produce a working threading core: cores
are up, workers are running, tasks flow through the queue, slot
values flow through the gathering function, the box descriptor
table holds a test library, and the worker scheduling loop runs
boxes from that library. But there is no map that actually
exercises this at scale — no automated way to put the system
under enough load to prove that it survives.

## Intended behavior

A torture-test map composed of test-library boxes (208) generates
millions of small tasks across every core. The map's shape:

```
constant-thousand → (fan to N inc boxes) → (chain of M inc boxes) → discard
```

where N is the worker count (every worker has at least one box
to chew on) and M is large enough that the chain produces a
meaningful per-task cost without each task being trivial.
Specifically the demo spins up two copies of this shape running
in parallel maps on the same worker pool, so the queue stays hot.

The demo verifies:

- **No lost fires.** The discard box at the end of each chain
  counts the values it consumed. The expected count is exactly
  the number of values the constant-thousand source emitted
  times the fan-out times the iterations. The demo asserts the
  counted total matches.
- **No incorrect values.** Each fan-out chain produces a known
  arithmetic progression. The discard box also accumulates the
  sum of values it consumed; the demo asserts the sum matches
  the closed-form expected sum.
- **Multi-spawn under load.** With every box multi-spawn, the
  same box function should run concurrently on multiple workers
  during the test. The demo's per-worker throughput numbers,
  reported through the CDC-ACM stream, should show every worker
  busy.
- **No memory ordering bugs.** A second variant of the chain
  uses a sequence of `noop` boxes carrying a payload value with
  a deliberate "before" and "after" pair the consumer expects
  to see in order. If the release/acquire ordering from 207 is
  wrong, the consumer would occasionally see "after" before
  "before"; the demo asserts it never does.

A script at `issues/completed/demos/phase-2/run.sh` builds the
kernel image, flashes it through the chip ROM recovery tool,
opens the USB CDC-ACM stream, watches for the demo's reported
counts and sums, and reports pass or fail with the per-worker
throughput numbers. The script follows the project convention
of a hard-coded `${DIR}` at the top, accepting an override as the
first argument, and using paths relative to `${DIR}` throughout.

The wall-clock time the demo takes to drain the torture map is
the load number every later phase paces its threading-core work
against. A regression here is a regression in the substrate.

## Suggested implementation steps

1. The torture map's box-list JSON (statically embedded in the
   kernel for phase 2 — the SD card loader is phase 4).
2. The map loader stub — for phase 2, accept an in-memory map
   shape and assemble its slots and gathering atomics.
3. `run_torture_demo()` — kick the entry boxes, watch for the
   discard's counter to hit the expected value, report.
4. The shell script wrapping the build / flash / stream / verify.

## Related documents

- `docs/002-roadmap.md` — phase 2 demo description.
- `docs/003-threading-model.md` — what the demo proves.

## Blocked by

All of 201 through 210.

## Closes

Phase 2.
