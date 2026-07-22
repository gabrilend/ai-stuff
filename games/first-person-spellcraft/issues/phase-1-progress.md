# Phase 1 — Engine Foundation · progress

> The living status index for phase 1. Phase 1 is the taproot: the SoraMech-style
> dataflow engine everything else grows from. Per house convention this file
> stays in `issues/` even after the phase completes, and is updated each time an
> issue is completed.
>
> Goal of the phase: a player can stand in a square room, look around a
> first-person view, and move — with every later system (mice, spells, puzzles,
> the Dungeon Master) plugging into seams this phase exposes. Architecture is
> recorded in issue `101`: a **pure-C SoraMech-style dataflow substrate** rendered
> by **raylib**.

## Status

| Issue | What | State |
|---|---|---|
| `101` | Engine architecture & framework decision | decision recorded (pure C + raylib + dataflow); proving program pending |
| `102` | Core loop & program lifecycle | **in progress** — substrate done (`102a`); lifecycle/window/`main()` remain |
| `102a` | **Dataflow substrate — slots, pool, dispatch** | ✅ **complete** |
| `103` | Square-room world data model | open |
| `104a` / `104b` | Renderer (raylib data-driven scene; supersedes the old software rasterizer) | open (to be revised per `101`) |
| `105` | Player movement & wall collision | open |
| `106` | Platforming: gravity, jumping, vertical collision | open |
| `107` | Engine seams & the phase-1 capstone demo | open |

## Completed

### `102a` — Dataflow substrate (slots, pool, dispatch)

The concurrent core of the whole engine, built and proven headless before any
window exists:

- **Slots** (`libs/engine-core/slot`) — the wires: thread-safe fixed-cell ring
  buffers in three flavors (FIFO queue, latest-wins, atomic counter), tear-free
  under concurrency.
- **Pool** (`libs/task-pool/pool`) — the threads: workers running boxes, with
  self-spawn (the heartbeat/iterator mechanism) proven.
- **Dispatch** (`libs/engine-core/graph`) — the graph turning: trigger-on-ready
  firing with a single-spawn gate and a race-free clear-then-recheck, proven by a
  self-checking mouse round-trip (20,000 differentials conserved exactly vs. an
  independent authoritative sum; 40/40 under stress).

This unblocks the rest of `102` (the lifecycle bookends, the raylib window +
dedicated render thread, the story `main()`), after which the phase can move on
to the world model (`103`), the renderer (`104`), and movement (`105`/`106`).

## What phase 1 proves when it's done

The phase-1 capstone demo (`107`) will show the dual-mouse body moving in a
square room, exercising this substrate — the pool turning a live graph, mice
driving a pose through drain-and-sum, the renderables reaching raylib — as one
running program, not just green test output.
