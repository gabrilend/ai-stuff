# Issue 515: The Render Graph on the Ceramic Engine

**Phase:** 5 - Rendering
**Type:** Implementation (a bounded experiment beside the existing renderer)
**Priority:** Medium
**Dependencies:** 508 (the vertical slice), 512 (the thread pool it is measured against)
**Related:** 512f (the thread pool's own integration), W08 (the server, also planned as a soramech map)

---

## Current Behavior

The renderer (`src/render/`) is C on raylib, with Lua game logic behind a
slot bridge. Its concurrency is hand-written threading: an updater, a worker
pool fed through a ring buffer (512), a sync stage, and the draw thread,
which only reads. Nothing in it uses the ceramic engine
(`/home/ritz/programming/ai-playground/minimal-soramech/`, "soramech"),
where a program is C functions ("boxes") wired together by a readable map
file, and a station runs when every one of its inputs holds a value.

The owner (2026-09-25) wants the engine built "in a ceramic style", to learn
the core engine and to improve soramech itself through its first graphical
program, while "paying special attention to Raylib's single-threaded render
thread nature".

**Measured so far (515a, 515g):**
- **Box size.** Per-frame work must be handed in to the task queue in
  chunks (8 to 64 units a task) or as one batch per frame. One task per
  unit, handed in one at a time, costs half a frame on the stock engine.
- **The engine copy.** The kept copy in `src/render/ceramic/engine/` hands
  work in without a lock, counts collected results after they land, hands a
  frame in as one batch (`cera_map_deliver_arguments`), and wakes only
  sleeping workers. 515b builds on this copy.
- **The benchmark.** A hand-written loop whose threads take work from a
  shared counter is the fastest way measured, about a tenth faster than the
  engine's best. That's the floor the ceramic path is measured against.
- **The first real frame (515b).** A raylib host hands 2,048 units in to
  the engine each frame and draws them. The engine's part takes about
  0.15 ms and drawing about 1.3 ms. The graph is not the bottleneck; drawing
  one call per unit is.
- **Against the strongest hand-written design (515j),** a job system with
  dependency counts and stealing, the graph matched it on average on a
  fabricated frame and kept steadier worst frames.

## Intended Behavior

A second, experimental render path, which draws the same scene as the current
renderer, measured against it on the same machine. The existing renderer
stays the working one until this one matches or beats it.

**The design, as decided with the owner (2026-09-25):**

1. **The host owns the window.** Raylib's drawing calls must come from the
   thread that owns the OpenGL context, and a ceramic station may run on any
   worker. So drawing is never a station. The raylib main thread is the
   host, and each frame it:
   - delivers the frame's inputs into the map's marked argument ports;
   - collects results from its marked output ports;
   - draws.

   The graph is the worker side (the engine's embedding interface: deliver
   an argument, collect a result).
2. **Draw whatever is there, every frame.** The owner: "render whatever data
   is present in the shared memory no matter what each frame. That part
   should be responsive and consistent." The visual state lives in a
   **mailbox triple buffer**:
   - one buffer is being drawn, one holds the latest complete state, and one
     is being written;
   - finishing a write swaps it with "latest complete" in one atomic
     exchange, and starting a draw does the same.

   Neither side ever waits, a half-written state is never seen, and it adds
   no queue delay: a newer state replaces an older waiting one, it doesn't
   line up behind it.
3. **As little delay as possible.** The owner: "We might just prefer as low
   latency as possible!"
   - **Extrapolate, don't interpolate.** Each unit's record holds its last
     known position, velocity, facing, animation and the time that was true.
     The draw computes "now" from it.
   - **Camera and cursor never enter the pipeline:** they are computed on
     the draw thread at the last moment.
   - **The newest state is taken as late as possible** before the frame is
     submitted.
4. **The client is a renderer; the truth is the server's.** The owner: "the
   actual code is running primarily on the server. Everything the client has
   displayed can be CORRECTED by the server at an arbitrary timescale."
   - **Local answers:** the player's own orders get an immediate response
     (click marker, acknowledgement voice, the unit turning and starting its
     predicted path).
   - **Corrections always snap**, in the frame they arrive: position, and
     animation at the correct moment of the true animation. Nothing is
     blended. The owner, on a predicted swing whose target the server says
     was already dead: "cancel the swing mid-air. We should always update to
     the correct state as soon as possible rather than continue delaying the
     truth."
   - Offline, the local simulation plays the server's part, at its fixed
     tick rate.
5. **Large read-only data travels as an id, not a copy.**
   - Meshes, textures, bind poses and animation tracks live in an asset
     table. Stations carry a small number naming an entry.
   - The table can grow while the graph runs. The owner: "the graph doesn't
     freeze, but the table can grow."
   - It is append-only: entries never change or move (blocks, never
     reallocated). An entry is published by one atomic count increase after
     it is complete, and only the host (the one thread allowed to upload to
     the GPU) writes it.
   - Decoding a new model's bytes is a station; uploading and appending are
     the host's, between frames.
6. **Per-frame work in big boxes.** Every ceramic task allocates, copies and
   queues, so work is chunked (tens of tasks per frame, not one per bone).
   Whether per-frame copies are a real cost is measured first (515a), not
   assumed.

**Standing tasks, a proposal for soramech rather than a change to our copy:**
per-frame work may be better as a task that stays in existence and is
re-queued each tick, reading frozen assets and writing only its own slice of
the buffer being written, with no copy. It is re-queued only when finished,
and skipped for that tick when still running. That degrades gracefully:
because the math is based on elapsed time, a slow machine updates less often
but still correctly. It's written up for the soramech project, with its
owner's say, and adopted here only once it exists there.

## Sub-Issues

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| 515a | copy-cost-benchmark | None | Measure what a ceramic task per unit costs at render sizes (2 KB of bone matrices per unit, hundreds of units, 60 per second) against a plain loop and the 512 pool |
| 515b | ceramic-host-loop | 515a | A kept copy of the engine's two files; a raylib program whose main loop delivers, collects and draws, with a map of placeholder stations |
| 515c | mailbox-triple-buffer | 515b | The three-buffer mailbox of per-unit visual records, with its two atomic swaps, and tests that a draw never sees a half-written state |
| 515d | extrapolate-predict-snap | 515c | Drawing "now" from each record; local order answers; corrections that snap, with the swing case as a test |
| 515e | growing-asset-table | 515b | The append-only, block-based asset table with published ids; a decode station, and upload and append on the host |
| 515g | lock-free-task-queue | 515a | A kept copy of the engine with a lock-free task queue (slot sequence numbers, batched hand-in, wake-only-sleepers) and collection counted after the copy; measured against the stock engine, then reported to soramech |
| 515h | a-frame-as-a-graph | 515g | A fabricated realistic frame (uneven stages that depend on each other, irregular pathfinding, background decoding) run serially, hand-written stage by stage, and as a ceramic map: the engine's flexibility, measured |
| 515i | destinations-a-station-may-name | 515g, 515h | Several task queues in the kept copy (soramech 107's model): a station may name one, workers serve an ordered list, and a program naming none behaves as before; measured on the 515h frame |
| 515j | stronger-hand-written-opponents | 515h, 515i | A hand-written job system with dependency counts and work stealing, and spin-then-sleep barriers, measured against the ceramic graph on the 515h frame |
| 515f | measured-against-the-pool | 515c, 515d, 515e | The same scene on both paths: frame time, time on the draw thread, core use. The verdict on the experiment |

Execution order: 515a → 515g → 515h → 515b → (515c, 515e in parallel) → 515d → 515f

## Suggested Implementation Steps

1. 515a first: its numbers decide how big the boxes must be.
2. Keep a copy of `cera.c` / `cera.h` in the project, with the soramech
   commit it came from, updated deliberately (the engine was made to leave
   home as two files).
3. Build 515b–515e as a separate program in `src/render/ceramic/`, sharing
   nothing mutable with the current renderer.
4. 515f compares the two paths; the verdict and its numbers go into this
   issue.

## Acceptance Criteria

- [ ] Each sub-issue complete
- [ ] The verdict recorded, with the measurements that support it
- [ ] What the experiment taught written up for soramech (gather of many
      results into one, standing tasks, the growing table), with its owner

## Related Documents

- `docs/render-architecture.md`, `docs/render-system-multithreading.md`,
  `docs/render-threading-v2.md` (the design this is measured against)
- `/home/ritz/programming/ai-playground/minimal-soramech/README.md`
- `/home/ritz/programming/ai-playground/minimal-soramech/docs/058-guarantees.md`
  (the engine's promises, including "not for timing-critical work", which
  this experiment tests)

## Open Questions

1. Does the soramech project want the standing-task proposal, and the gather
   primitive? (Its owner decides; nothing is written into that repository
   without asking.)
