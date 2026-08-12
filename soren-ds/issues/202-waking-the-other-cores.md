# 202 — Waking the other cores

## Current behavior

**Three of the four cores have never executed a single instruction of
our code.**

Phase 1 ran entirely on core zero. The other three are where the boot
firmware left them: powered but parked, each spinning in firmware or
held in a low-power state, waiting for someone to tell them an address
to jump to. They are not asleep in any sense this project's engine
understands — they have no stack, no identity, and no entry point.

## Intended behavior

**Four cores, each with a stack, each arriving at the same C function,
each knowing which one it is.**

This is the bare-metal form of the thing the other project gets for
free by asking the operating system for four threads. There is no
operating system, so the whole of it is ours: the release, the stack,
the identity, and the starting gate.

```
   core 0 ──── already running (phase 1)
                │
                ├── release core 1 ─→ stub ─→ per-core setup ─→ ┐
                ├── release core 2 ─→ stub ─→ per-core setup ─→ ┤
                └── release core 3 ─→ stub ─→ per-core setup ─→ ┤
                                                                │
                       all four wait at the gate  ←─────────────┘
                                    │
                       gate opens once  ─→  the run loop (205)
```

**What each core needs before it may run C at all:**

| needs | why | where it comes from |
|---|---|---|
| a stack | C cannot execute without one | one region per core out of 108's pool |
| the exception vector base | a fault on core 2 must reach our handlers, not nothing | the same table 105 installed on core zero |
| its own identity number | statistics, and knowing which stack is whose | passed in at release, kept in a per-core register |
| the caches on | 201's table is per-core state, not global | each core sets its own enable bit against the shared table |

That last row is the one that is easy to get wrong. The translation
table is one table in memory shared by everyone, but the register that
points at it and the bit that switches it on are **per-core**. Core 1
waking up with the caches off, against a table core 0 built, sees a
different machine than its siblings — and sees none of their writes.

**A starting gate, not a free-for-all.** Every core waits at a barrier
until all four have arrived, and only then is the gate opened. Without
it, core 1 can be deep in the run loop while core 3 is still setting up
its stack, and anything that must happen once between "the cores exist"
and "work begins" has nowhere to go. The gate is where the first map is
placed.

**Core zero becomes an ordinary worker.** It has no special role after
the gate opens. Keeping it as a supervisor would mean one core in four
not doing work, and the thing this whole phase is for is that no core
sits idle while something is ready to run.

## Suggested implementation steps

1. Determine from 101's findings how a secondary core is released on
   this chip, and write down which of the two it is. Either the secure
   firmware already resident below us answers the standard
   power-control call with a core number and an entry address, or the
   release is a direct write to the chip's power-management registers.
   The first is far preferable if it is available, because the firmware
   already handles the power sequencing.
2. A short assembly stub, entered by a freshly-released core: set the
   stack pointer from a per-core table, set the vector base, enable the
   caches against 201's table, then call into C with the core number as
   the argument.
3. Per-core stack regions carved from 108's pool before any core is
   released, with a guard region below each so a runaway stack faults
   rather than eating its neighbour.
4. The barrier, and a separate call to open it.
5. Each core reports in over the USB serial line with its number and
   its stack address, so the boot log answers "did all four arrive"
   without any guessing.

## Open questions

- *Which exception level do we start at?* This decides whether the
  standard power-control call is even reachable, and whether each core
  needs its own copy of the setup or inherits some of it. 101's notes
  may already answer it; the boot log will if they do not.
- *How large is a stack?* A box function is ordinary C and deep
  recursion is not part of the design, but the delivery walk runs on a
  worker's stack and fan-out is unbounded. Sizing wants a measurement
  from 211 rather than a guess here.
- *Does a core that fails to arrive stop the boot?* Three cores working
  is better than none, but a silent three-out-of-four is exactly the
  kind of degradation that gets discovered as a performance mystery
  months later. Leaning toward: report loudly, park, and require the
  count to match.

## Blocked by

201 (the caches must be on before four cores share memory), 105
(vector table), 108 (stacks).

## Blocks

Every issue from 204 onward.

## Related

- [201 — The memory map that turns the caches on](201-the-memory-map-that-turns-the-caches-on.md)
- [201a — Run the CPU at its rated speed](201a-cpu-clock-bring-up.md),
  which wants the cores at full speed once they are awake
- [205 — Workers and the run loop](205-workers-and-the-run-loop.md),
  what a core does after the gate opens
