# 102a — Dataflow Substrate (slots, pool, dispatch)

> **Phase:** 1 (Engine Foundation) · **Sub-issue of:** `102` (core loop &
> lifecycle) · **Depends on:** `101` (the pure-C SoraMech-style + raylib
> decision) · **Blocks:** the rest of `102` (window, render thread, story
> `main()`) and every box any later phase writes · **Difficulty:** high (the
> concurrent core) · **Kind:** load-bearing mechanism · **Status:** COMPLETE.

The engine is a SoraMech-style dataflow machine (issue `101`): C boxes that fire
when their inputs are ready, values flowing through shared-memory ring buffers, a
long-running circular map that never quiesces. This sub-issue builds the three
foundational pieces that make that machine run — the **wires**, the **threads**,
and the **rule that turns the graph** — as a headless, testable core, before any
window or hardware exists.

## Current Behavior

Complete and tested, all headless. Three pieces:

- **The wires** — `libs/engine-core/slot.{c,h}`. A thread-safe pool of small
  ring-buffer slots carrying fixed-size struct values. Three flavors: a FIFO
  `queue` (drain-and-sum), a `latest`-wins single cell (the render blackboard;
  its whole-struct copy under the slot lock makes reads tear-free), and an atomic
  `counter` (fan-out index dispensing). Per-slot `atomic_flag` spinlock + atomic
  fetch-add, modelled on SoraMech's `009-slot-store.c` but lean: typed fixed
  cells, no byte-blob/large-value/dual-ring/tagged machinery.
- **The threads** — `libs/task-pool/pool.{c,h}`. N workers pulling tasks off one
  FIFO queue; tasks may spawn tasks (including themselves), which is how a box
  re-arms. Lean vs. SoraMech's pool: no per-worker language-spec init, no
  priority queue, tuned for a game that never quiesces.
- **The rule** — `libs/engine-core/graph.{c,h}`. The trigger-on-ready dispatch: a
  box fires when all its input ports hold a value, runs on the pool, then wakes
  the downstream boxes that just became ready; source boxes re-arm themselves
  (the frame-clock heartbeat). Correct under threads via a single-spawn atomic
  gate and a clear-then-recheck step that closes the missed-wakeup race.

Each piece carries its `.info.md` and a regression prover. The provers pass,
including the self-checking **mouse round-trip** (`graph-test.c`): a
`heartbeat → mouse → pose` graph where the mouse emits differentials
deterministic in the tick number, so pose's drain-and-summed position is checked
against an INDEPENDENT authoritative sum — agreement is only possible if the
dispatch conserved every value across every interleaving. 40/40 under stress.

## Intended Behavior

Exactly the above: a language-uniform (pure C) dataflow substrate on which every
later system is written as a box. Values move only through slots; the only
threads are the pool workers (plus, later, the one dedicated render thread that
GL affinity forces — not part of this sub-issue). The substrate knows nothing of
mice, spells, or rendering; it only guarantees that wires deliver values, that
boxes fire when ready, and that the graph keeps turning until a quit signal.

## Suggested Implementation Steps (as built)

1. **Slot store** — typed fixed-cell ring with three flavors; per-slot spinlock
   for the rings, atomic fetch-add for the counter; `push` refuses on a full
   queue (backlog is a signal, not silently dropped); `drain` empties a queue for
   drain-and-sum. Prove single-thread contract + threaded exactness (8 producers)
   + zero torn reads (concurrent writers on a latest slot).
2. **Worker pool** — workers + FIFO queue + two non-nesting locks (queue,
   in-flight tally); spawn increments the tally before the task can run so a
   quiescence waiter never sees a false zero. Prove fan-out, self-spawn (the
   heartbeat/iterator shape), and spawn-from-inside-a-task.
3. **Dispatch** — box model (function + input slots + downstream list + atomic
   gate; a wire is a shared slot id); `box_kick` CAS-gates the spawn; the action
   runs the box, wakes ready downstream boxes, and re-arms (source) or
   clears-then-rechecks (input-driven). Prove with the mouse round-trip against an
   authoritative sum; stress 40×.

## Deprecated / removed

The pure-Lua reference slot (`src/soramech/000-ring-buffer-slot.lua` + its info)
that prototyped the slot contract before the pure-C pivot was translated into
`slot.c` and removed. It was never committed.

## Relevant files

- `libs/engine-core/slot.{c,h}` + `slot.info.md` + `slot-test.c`
- `libs/task-pool/pool.{c,h}` + `pool.info.md` + `pool-test.c`
- `libs/engine-core/graph.{c,h}` + `graph.info.md` + `graph-test.c`
- `docs/soramech-notes.md` — patterns 2 (transport), 3 (drain-and-sum), 4
  (ownership publish), 6 (heartbeat) are realized here.

## Remaining in the parent (`102`), NOT this sub-issue

The lifecycle bookends (read `input/` first, write `output/goodbye` last), the
raylib window + dedicated always-unblocked render thread, and the
story-structured `main()` that wires and runs the real game graph.
