# 006 — Threading Architecture Walkthrough

A six-part guided tour of the threading model defined in
`004-architecture.md` and seeded by issue 102. Read 004 first for the
authoritative spec; this document is the companion narrative — the same
material chunked for a reader building intuition step by step. Parts
1–4 walk the design as committed for Phase 1; parts 5–6 explore what
that design enables (implications) and how to actually build and test
it (implementations).

The six parts:

1. The two-thread split and the boundary
2. The snapshot handoff (double-buffer + swap)
3. The input queue (semantic events + shift-chain IDs)
4. Slice-by-tenths parallel batching + merge step (pool-readiness)
5. Implications — what this design buys you downstream
6. Implementations — how to actually build and test it

---

## Part 1/4 — Two threads, one boundary

The whole design starts from a single decision: **the renderer and the simulation must not share game state directly.** Everything else is consequence.

### The two threads

There are *three threads of attention but two real OS threads*:

- **Main thread** — owns the raylib window. Each frame it does three things, in this order:
  1. polls raylib input and translates it into *semantic* events (not "key W is down" but `MOVE_ORDER(x,y,chain_id)`),
  2. pushes those events onto the input queue,
  3. reads the latest published snapshot and renders it.
  It never reads or writes simulation state. It doesn't even know what a unit *is* internally — only what's in the snapshot struct.

- **Simulation thread** — owns *all* game state. Runs a fixed-rate tick loop (`SIM_TICK_HZ` in `010-config.h`, e.g. 60Hz). Each tick:
  1. drains the input queue,
  2. applies events to state,
  3. runs systems (movement, combat, projectiles, factories),
  4. builds a fresh snapshot in a back buffer,
  5. swaps front/back snapshot pointers under a lock,
  6. sleeps until the next tick boundary.

The "third thread of attention" is the input pipeline — it's logically its own flow, but it lives inside the main thread's frame loop; it doesn't need its own OS thread.

### The boundary: exactly two locks

This is the part worth memorizing, because it's the entire concurrency surface of the program:

- **Mutex 1 — input queue** (`040-input.c`). Main thread holds it briefly to push; sim thread holds it briefly to drain. Fixed-capacity ring; producer never blocks meaningfully.
- **Mutex 2 — snapshot pointer swap** (`110-snapshot.c`). Sim thread holds it for the duration of a *pointer swap* (front ↔ back). Main thread holds it just long enough to grab the front pointer. The actual snapshot bytes are never copied across threads — only ownership of which buffer is "current" flips.

That's it. Nothing else is shared. The terrain heightmap is built once at startup and treated as read-only thereafter; raylib's GL state lives entirely on the main thread; simulation arrays live entirely on the sim thread. There is no third synchronization primitive anywhere in Phase 1.

### Why this shape

The properties that fall out of these two threads + two locks:

- **Render decouples from sim load.** If a tick stalls (the issue suggests deliberately `usleep`-ing 100ms inside one tick as a sanity test), the main thread still has a valid front snapshot to render — the marker pauses for a tick, but camera/zoom stay smooth. That test is the litmus that the decoupling actually holds.
- **No dropped inputs.** The queue absorbs bursts; the sim drains whatever accumulated since last tick.
- **Every tick is a pure function of `(prior state, drained input events)`.** This is what makes future replay/test harnesses possible without redesign — and it's also what makes the slice-by-tenths parallelization (part 4) safe.

### What's *not* in this part

- The shape of the snapshot struct itself — that's part 2.
- Why input events carry `shift_chain_id` — part 3.
- How the sim tick internally splits work across (eventual) pool workers — part 4. In Phase 1 the sim thread does all the work serially; the pool (`libs/900-task-pool.h`) exists but issue 102 explicitly does *not* use it. The two pthreads here are the *containers* a pool would later live inside, not callers of it.

---

## Part 2/4 — The snapshot handoff

The snapshot is the **only** mechanism by which simulation state crosses to the renderer. If you understand this one struct and its swap, you understand half the program.

### What a snapshot is

A snapshot is a **flat, copyable struct** — no pointers into sim-owned memory, no live references, nothing the renderer could follow back into simulation territory. Conceptually it holds:

- arrays of unit positions, orientations, health, unit identifiers,
- the projectile array (positions, velocities, lifetimes),
- current orders / order chains (so the renderer can draw waypoint lines),
- the current selection,
- factories and their rally chains.

It is **sized for the maximum unit count** (`MAX_UNITS` in `010-config.h`) — fixed capacity, no allocation per tick. The sim writes into pre-allocated arrays and the renderer reads from pre-allocated arrays. No malloc on the hot path, ever.

### Double buffering

Two snapshot buffers exist at all times — call them A and B. At any instant:

- one is the **front** (what the renderer is allowed to read),
- the other is the **back** (what the sim is currently writing into).

A tick looks like:

1. Sim writes a fresh snapshot into the back buffer (no lock — nobody else touches back).
2. Sim takes the snapshot mutex, swaps the two pointers (`front ↔ back`), releases.
3. What was the back buffer is now the front; what was the front is now the back, and the *next* tick will overwrite it.

The renderer side:

1. Take the snapshot mutex, copy the *front pointer* into a local variable, release.
2. Render from that pointer for the rest of the frame.

### Why this is fast

The lock is held for **a pointer swap** on the sim side and **a pointer read** on the render side. That's nanoseconds. The actual snapshot bytes — kilobytes of unit/projectile arrays — are never copied across the boundary and never contended. The renderer reads a buffer that the sim has promised not to touch until *after* the next swap.

Crucially: the renderer can hold onto its front pointer for an entire frame without blocking the sim, because the sim only writes to back. The two threads operate on disjoint memory between swaps.

### "Possibly one tick old, which is fine"

The architecture doc calls this out explicitly: the front snapshot the renderer sees might be from the tick that just ended, or from one tick ago if the sim is mid-write. Either way, the renderer never blocks waiting for fresh data, and never sees a torn half-written snapshot. At 60Hz sim and 144Hz render, several frames will redraw the same snapshot — that's the expected, correct behavior. Interpolation between snapshots is a *future* optimization, not part of Phase 1.

### What it protects against

- **No torn reads.** The swap is atomic at the pointer level — the renderer either sees the old snapshot in full or the new snapshot in full, never a mix.
- **No stalls.** The renderer always has *something* valid to draw. Even if the sim does a 100ms tick, the renderer keeps redrawing the most recent front.
- **No simulation→render coupling.** The renderer literally cannot reach into sim state; the type system makes it inexpressible. Conversely, nothing the renderer does (camera moves, frame drops) can perturb simulation determinism.

### What's *not* in the snapshot

- Camera state — that lives entirely on the main thread; it isn't sim state.
- Input state (key-down, mouse-down) — the main thread translates those into events before they cross the boundary.
- Anything raylib-specific (textures, models, GL handles) — those are render-thread-only resources, looked up *by id* from the snapshot's unit type identifiers.

This is what `src/110-snapshot.c` / `.h` will own per issue 102, step 2: the buffer pair, the mutex, and the two primitives `snapshot_publish()` (sim-side, swap) and `snapshot_acquire()` (render-side, grab front pointer).

---

## Part 3/4 — The input queue and shift-chain IDs

If part 2 is "how state flows sim→render," part 3 is the mirror: **how intent flows main→sim**. Same shape (one mutex, fixed-capacity buffer, no shared pointers), different content.

### Why a queue at all

The naïve alternative would be: main thread sets some "pending order" globals, sim thread reads them. That falls apart immediately — the sim ticks at a fixed rate (60Hz), the main thread polls input at frame rate (often 144Hz+), and a single tick boundary might span *multiple* user actions. A click followed 3ms later by a shift-click must both reach the sim, in order, even if they happened between two ticks.

So: a **fixed-capacity ring queue** of events, protected by one mutex. Main thread pushes; sim thread drains the entire queue at the start of each tick. Bursts are absorbed by the ring; nothing is dropped under normal load.

### Semantic, not raw

This is the part of the design that does the most work. The queue does **not** carry "key W went down" or "mouse moved to (x,y)". It carries **already-interpreted game intentions**:

- `SELECT_RECT(x0,y0,x1,y1)` — completed drag rectangle on mouse release.
- `SELECT_CLICK(x,y)` — single click without drag.
- `MOVE_ORDER(world_x, world_y, shift_chain_id)` — right-click, already raycast through the camera into world coordinates.
- `FACTORY_PLACE(world_x, world_y)` — placement-mode confirmation.
- `RALLY_DRAG_START(factory_id)` / `RALLY_DRAG_MOVE(x,y)` / `RALLY_DRAG_COMMIT(shift_chain_id)`.

Two important consequences:

1. **The sim has no concept of a mouse, a key, or a screen.** It receives world coordinates and entity ids. This is what lets the simulation be deterministic and replay-friendly — you could feed it a recorded event log and get bit-identical results.
2. **The camera lives entirely on the main thread.** The screen→world raycast is done on the main thread *before* the event is enqueued, using the heightmap (which is read-only-shared, built once at startup). The sim never sees the camera.

This is what the doc means by "the main thread is *stateless about the game* — it only knows about windowing, input mapping, and chain-id bookkeeping."

### Shift-chain IDs — the one piece of cross-thread bookkeeping

This is the subtle bit. When you shift-click to chain waypoints, the sim needs to know "this `MOVE_ORDER` extends the previous chain" vs. "this is a fresh chain." But the sim doesn't see your shift key — it only sees the events you enqueue. So:

- Each time the user **presses-and-holds shift**, the main thread allocates a fresh `shift_chain_id` (a monotonically increasing integer).
- Every order event emitted *while shift remains held* carries that same id.
- When shift is **released**, the id is closed; the next press allocates a new one.

When the sim drains events:

- Two `MOVE_ORDER`s with the same `shift_chain_id` → same chain, append in arrival order.
- A `MOVE_ORDER` with a `shift_chain_id` it hasn't seen before → start a new chain (and replace any existing one for the affected units).
- A `MOVE_ORDER` with `shift_chain_id == 0` (or whatever sentinel "no shift") → a singleton chain that replaces.

The beauty: the main thread holds **no game state** to do this. It tracks one integer counter and one "currently-open id, or none." That's it. The sim thread holds **no input/keyboard state** to interpret it — it just compares ids it receives to ids it has already seen for that selection. Each side's bookkeeping is local to itself.

The same scheme generalizes to rally-chain dragging on factories (`RALLY_DRAG_*` events share a `shift_chain_id` for shift-extending an existing rally chain).

### What the boundary looks like end-to-end

Putting parts 1–3 together, one full round trip:

1. User right-clicks at screen `(450, 320)` while holding shift.
2. Main thread, in its frame loop:
   - notes shift is held → uses current `shift_chain_id`,
   - raycasts `(450, 320)` through the camera against the heightmap → world `(x, y)`,
   - takes the input-queue mutex, pushes `MOVE_ORDER(x, y, chain_id)`, releases.
3. Some milliseconds later, the sim thread starts a tick:
   - takes the input-queue mutex, drains all pending events into a local list, releases,
   - sees the `MOVE_ORDER`, recognizes the chain id, appends a waypoint to the chain for the currently-selected units,
   - runs movement / combat / projectiles,
   - writes a new snapshot to back, swaps front/back under the snapshot mutex.
4. The next render frame:
   - takes the snapshot mutex, grabs the front pointer, releases,
   - draws units at their new positions and the order chain as a polyline.

Two locks, both held for trivial durations, and a clean data boundary. That's the whole concurrency story for Phase 1.

### What's *not* in this part

- *Inside* the sim tick, how the per-unit work (movement, LoS, firing, projectile integration) is structured so it can later be parallelized across pool workers without locks. That's part 4 — slice-by-tenths and the merge step.

---

## Part 4/4 — Slice-by-tenths and the merge step

This is the part that's **not yet in use** in Phase 1, but every per-unit subsystem is *designed* so adopting it later is a mechanical change instead of a redesign. The lever already exists — `libs/900-task-pool.h` shipped via issue 122 — issue 102 just doesn't pull it.

### The orchestrator vs. the executor

Recap: the sim thread is one OS thread that owns all game state. But "owning" doesn't mean "doing all the work." The sim thread is the **orchestrator** of a tick — it decides what runs when, owns the mutation order, and runs the merge step. It doesn't have to be the sole *executor*.

When the pool is adopted, "the sim" becomes a logical group of N+1 threads:

- 1 orchestrator (the original sim thread — still owns the snapshot publish, still drains the input queue, still runs the merge),
- N pool workers (run parallel-for slices and self-rescheduling per-entity tasks).

The orchestrator-vs-workers split is purely internal to the sim side of the boundary. The main thread doesn't notice and doesn't need the pool — its work (raylib polling, rendering) is inherently single-threaded.

### Split-by-tenths

When the sim runs a per-unit pass over `N` units, the pass is structured as ~10 independent task closures, each operating on a contiguous slice of the unit array — `[0, N/10)`, `[N/10, 2N/10)`, …, `[9N/10, N)`. Each task only touches its own slice (and per-task scratch memory).

Why ten and not "one task per unit"? Two reasons:

1. **Amortizes scheduling overhead.** A pool dispatch costs more than processing a single unit; ten chunky tasks beat 1000 tiny ones for cache and dispatch cost.
2. **Keeps the slicing trivial.** Ten is a knob, not a load-balancing algorithm. If a slice is uneven, the next tick rebalances naturally because units don't move between slots.

In Phase 1 the iteration code is already slice-shaped — it just runs serially. The change to parallelize is `for (slice) { ... }` → `for (slice) { task_pool_spawn(...) } task_pool_join_all()`. That's the win the design is buying.

### The two rules that make slice-disjoint safe

For zero-lock parallel work, every per-unit subsystem must obey:

1. **Slice-disjoint writes.** A task may only mutate the unit whose slot it is processing, plus its own per-task scratch buffer. Cross-unit writes — "shooter A causes target B to take damage" — are *not* allowed inside the parallel pass.
2. **Read-only shared input.** The terrain heightmap, the previous tick's snapshot (used for LoS / target acquisition reads), and any tick-constant data are read-only during the pass.

Rule 1 is the hard one, because real game logic *is* full of cross-unit effects. The escape hatch: **intent records.**

### Intent records

When unit A does something that affects unit B, the slice processing A doesn't write to B's slot. Instead it appends a small intent record to its **per-task scratch buffer**:

- "Apply 1 damage to unit B at projectile lifetime t" → damage intent.
- "Spawn a projectile from unit A toward (x,y)" → projectile-spawn intent.
- "Mark unit A as having no valid target this tick" → miss-memory intent.

Each task writes only into its own scratch list. Different tasks may emit intents pointing at the *same* target B, but they don't collide because each task writes to its own list.

After all tasks finish, the orchestrator collects every per-task scratch list, **sorts the combined intents deterministically** (e.g. by `(shooter_id, target_id, projectile_id)`), and applies them in order — single-threaded.

### The merge step

This single-threaded pass at the end of each tick is where every cross-unit mutation actually lands:

- damage intents → subtract HP, set kill flags,
- projectile-spawn intents → flush into the projectile pool,
- death intents → free unit slots / mark for cleanup.

Two properties fall out of doing it this way:

1. **Determinism independent of dispatch order.** Because intents are sorted before application, it doesn't matter whether worker 3 finished slice 7 before or after worker 1 finished slice 2. The final state is identical regardless of how the pool happened to schedule the slices. This is what preserves the "tick = pure function of (prior state, drained input)" property that makes replay possible.
2. **No locks during application.** Only one thread is running during the merge — the orchestrator. So the "expensive" mutations (HP, kill flags, projectile-array growth) need no synchronization either. The cost is one extra pass; the gain is the entire parallel pass needing zero locks.

### Concrete subsystems in Phase 1

The doc lays this out as a table — these are the parallel-pass passes per tick:

| Subsystem              | Per-tick work                              | Cross-unit effect (→ intent)          |
| ---------------------- | ------------------------------------------ | ------------------------------------- |
| Movement               | Advance toward chain head                  | None — slice-disjoint                |
| HP regeneration        | +0.02 HP per regen tick boundary           | None — slice-disjoint                |
| LoS / target acquisition | For each unit, find nearest visible enemy | Reads only — slice-disjoint          |
| Firing                 | Decide whether to spawn a projectile       | Per-task projectile-spawn list        |
| Projectile integration | Advance, hit-check                         | Per-task damage-intent list           |
| Apply damage           | (the merge step itself)                    | Single-threaded, mutates HP / deaths |

Movement and HP regen are pure slice-disjoint — they don't even need the intent mechanism, because they only mutate `units[i]`. LoS reads enemy positions but writes only to `units[i].current_target`. Firing and projectile integration are the two that emit intents.

### Why this is the *whole* design

The two-thread architecture (parts 1–3) gives you a clean boundary between sim and render with two trivial locks. The slice-by-tenths design (part 4) gives you a path to scale the sim across cores **without** introducing any new locks or synchronization beyond what the pool already provides internally — because the parallel pass is read-only-shared + slice-disjoint-write, and all cross-cutting mutation is funneled through a single-threaded merge.

So the lock count, end-to-end:

- 1 mutex for the input queue (main ↔ sim),
- 1 mutex for the snapshot pointer swap (sim ↔ main),
- 0 additional locks for the eventual parallel sim work.

That last zero is the entire point of designing the per-unit subsystems this way from the start, even when they run serially in Phase 1. Retrofitting locks into a system that wasn't designed slice-disjoint is painful; designing slice-disjoint and then *not yet* parallelizing is free.

---

## Part 5/6 — Implications: what this design buys you downstream

Parts 1–4 described the architecture as it serves Phase 1 — render decoupled from sim, two locks, pool-ready slicing. The deeper payoff is the doors this design leaves open. None of these are committed work, but each one becomes *cheap* because of decisions made now.

### Determinism as a load-bearing property

"Each tick is a pure function of `(prior state, drained input events)`" reads like a nice-to-have, but it's the property that unlocks four separate features:

- **Replay.** Record `(initial state, input event log)` to disk; replay later by re-running the sim against the same events. The renderer doesn't need to be involved — replays can be regenerated headlessly to make new gameplay videos at higher render quality, or to debug a player report frame-by-frame.
- **Regression tests.** A test harness can spin up a sim thread, feed it a scripted event log, and assert against the resulting snapshot. No raylib, no window, no human. Combat balance changes ("does javelin TTK still equal 4 ticks at range R?") become unit tests.
- **Network rollback.** If/when multiplayer happens, the sim's purity means lockstep or rollback netcode is a natural fit. Each peer runs the same deterministic sim against the same input event stream. Rollback = restore prior snapshot, replay events with a corrected late-arriving event mixed in. The architecture is already shaped for this; you'd add network code as another producer to the input queue.
- **AI training environments.** Headless sim ticks as fast as the CPU allows because nothing waits on the GPU. A bot training loop could run thousands of matches per minute against scripted input streams.

The cost of preserving determinism is real (no `time(NULL)` in sim code, no thread-id-dependent ordering, no float NaN drift between platforms). But the architecture has already paid that cost in its design — the merge step's deterministic intent sort is the load-bearing piece.

### Sim rate as a tuning dial

Because render is decoupled from sim, `SIM_TICK_HZ` becomes a true tunable, not an architectural commitment:

- A 30Hz sim with render-side interpolation looks identical to a 60Hz sim at 144Hz render, but burns half the simulation cost. Useful on lower-end hardware or when unit counts grow.
- A 120Hz sim makes fast projectiles feel cleaner (the javelin spends more ticks in flight, hit-checks are tighter) at the cost of doubled sim work.
- Even a *variable* sim rate is possible — render never notices, since it always reads the latest snapshot.

This is the opposite of game architectures that bake the sim rate into rendering (e.g. running physics inside the render loop). Decoupling early is what keeps this dial real.

### Headless sim as a first-class artifact

The sim thread doesn't link against raylib. That's not an accident; it's a commitment. Two consequences:

- **The sim binary can ship without graphics.** A `sim-only` build target — same `120-sim.c`, same `010-config.h`, but `001-main.c` replaced with a tiny driver that pipes events from stdin and snapshots to stdout — gives you a CLI sim. Test harnesses, AI evaluators, and dedicated multiplayer servers all reuse the same simulation code.
- **The simulation never accidentally calls a render function.** The compiler enforces it: `100-render.c` is the only file that includes raylib's drawing API. If `050-units.c` ever tried to call `DrawCube`, the link would fail before the bug reached a player. The thread boundary is also a *build boundary*.

### The snapshot as a serialization format

A snapshot is already a flat, copyable struct sized for `MAX_UNITS`. That makes it almost trivially:

- **A save format.** Writing a snapshot to disk is `fwrite(front_snapshot, sizeof(snapshot_t), 1, fp);`. Loading is the inverse plus rebuilding any derived state (which there shouldn't be much of — the snapshot is meant to be self-contained for rendering, and "self-contained for rendering" extrapolates well to "self-contained for resume").
- **A network packet shape.** UDP-friendly because it's bounded in size. Even compressed delta-encoded, the baseline of "a snapshot is N kilobytes" is the unit of network sync work.
- **A debug oracle.** Dump snapshots every K ticks, diff them against expected fixtures, find the exact tick where divergence began.

None of this is Phase 1 work, but the architecture made it possible without redesign.

### The intent pattern generalizes

The "produce intents in a parallel pass, sort and apply single-threaded" pattern from part 4 isn't unique to combat damage. Anywhere a parallel pass needs to cause a cross-cutting effect, the same shape applies:

- **Factory production** — each factory's per-tick task emits a "spawn unit" intent into a per-task list; the merge applies them in deterministic order (which matters for slot-allocation determinism if multiple factories complete on the same tick).
- **Pathfinding requests** — a unit decides "I need a path from A to B" → emits a path-request intent → the merge step (or a dedicated pathing pass) services them, possibly in parallel itself with a different slicing.
- **Audio events** — "play 'unit takes damage' sample" → intent → main thread reads them off a separate ring queue and dispatches to the audio system.

Once you see the pattern, it's hard to unsee. It's the same shape as message-passing concurrency, but applied within a single thread's view of the sim — communication via append-only buffers, mutation via a single sequencer.

### Backpressure and load behavior

A nice property of this design is what *doesn't* happen under load:

- **Render slowdown ≠ sim slowdown.** If the GPU is saturated and frames take 50ms each, the sim still ticks at 60Hz. Nothing in the gameplay simulation cares.
- **Sim slowdown ≠ render slowdown.** If a tick takes 80ms (longer than the 16.67ms tick budget at 60Hz), the renderer keeps drawing the most recent snapshot. The game *feels* paused for that tick rather than freezing the whole window.
- **Input burst ≠ dropped inputs.** Up to the queue's capacity, bursts are absorbed. Beyond capacity (which would require thousands of queued events — implausible from a single human user) you have a real problem, but it's a single number to monitor and tune.

Compare to the failure modes of a single-threaded "render and sim in the same loop" design: GPU stalls cause input lag, sim work skips frames, and the user sees stutter. The decoupling here means failure modes are *isolated* to the affected subsystem.

---

## Part 6/6 — Implementations: how to actually build and test it

Now for the concrete how. Parts 1–5 described shapes; this is sizes, code patterns, and the things to instrument when you turn the design on.

### Sizing the snapshot

Every snapshot field has a fixed cap from `010-config.h`. A worked example:

- `MAX_UNITS = 1024`, per-unit struct ≈ 64 bytes (position, orientation, hp, type, target_id, current_order_idx, etc.) → 64 KB unit array.
- `MAX_PROJECTILES = 4096`, per-projectile ≈ 32 bytes → 128 KB projectile array.
- Order chains: `MAX_UNITS × MAX_WAYPOINTS_PER_CHAIN` (say 32) × 8 bytes per waypoint → 256 KB.
- Selection bitmap: `MAX_UNITS / 8` = 128 bytes.
- Factories: small fixed cap, negligible.

Total: under a megabyte per snapshot, two snapshots = under 2 MB. That fits in L2 on a modern CPU. The point isn't the absolute number — it's that you can compute it from `010-config.h` constants and budget for it deterministically. A snapshot that grows unboundedly with play time is a snapshot that will eventually break the design.

### Sizing intent scratch buffers

Each pool task gets a per-task scratch buffer for its intents. Sizing rule: **the worst-case intent count for the slice's units in one tick.**

- Damage intents: at most one per projectile that hit something this tick. Per-task cap = `MAX_PROJECTILES / N_TASKS` × safety margin.
- Spawn intents: at most one per unit that fired this tick. Per-task cap = slice size (every unit in the slice firing).
- Sized at task creation, never grown during the pass. If a task overflows, it's a bug in the cap math, and it should assert loudly rather than silently drop or realloc.

Intent buffers are *per-task*, allocated when the task is dispatched and freed (or returned to a pool) when it completes. This keeps allocation off the per-tick hot path and avoids any cross-task contention on a shared allocator.

### The serial-to-parallel migration

In Phase 1, every per-unit subsystem runs serially but is already shaped for slicing. The code today looks like:

```c
for (int slice = 0; slice < N_SLICES; slice++) {
    int lo = slice * MAX_UNITS / N_SLICES;
    int hi = (slice + 1) * MAX_UNITS / N_SLICES;
    movement_pass(units, lo, hi, intent_scratch[slice]);
}
merge_intents(intent_scratch, N_SLICES);
```

When the pool is adopted (a future issue, not 102), it becomes:

```c
for (int slice = 0; slice < N_SLICES; slice++) {
    int lo = slice * MAX_UNITS / N_SLICES;
    int hi = (slice + 1) * MAX_UNITS / N_SLICES;
    task_pool_spawn(pool, movement_pass_task, &args[slice]);
}
task_pool_join_all(pool);
merge_intents(intent_scratch, N_SLICES);
```

The merge step is unchanged. The pass function is unchanged. Only the dispatch loop changed. This is the *mechanical* migration the design protects.

The one thing to watch in the migration: `movement_pass` must already not capture state across slice boundaries. If it accidentally reads `units[hi]` at the boundary of the *next* slice (e.g., for "look at neighbor" logic), it reads correctly serially but breaks under parallel dispatch. Static analysis or a debug-build assertion that tracks read addresses against `[lo, hi)` catches this early.

### Where the orchestrator lives in code

Today, "the orchestrator" is just the body of `sim_thread_main()` in `120-sim.c`. After pool adoption, it stays exactly that — the function that calls `task_pool_spawn` and `task_pool_join_all`, then runs the merge. This matters because it means the pool isn't a separate "sim subsystem" with its own lifecycle; it's a tool the existing sim thread reaches for during a pass and puts back when the pass is done.

The pool itself is created once at startup (in `001-main.c` or `120-sim.c`'s init) and lives for the program's lifetime. Workers are persistent threads. No per-tick thread creation, no per-tick allocation.

### Testing the design

A handful of tests are cheap and high-signal:

1. **The 100ms usleep test.** From issue 102's notes: deliberately `usleep(100000)` inside one sim tick. Camera should remain smooth, marker should pause for one tick. If camera stutters, the snapshot/lock design is wrong.
2. **Replay equivalence.** Run the sim with input log L → snapshot S1 at tick T. Run again with the same L → snapshot S2 at tick T. `memcmp(S1, S2) == 0`. If it ever isn't, you have non-determinism (uninitialized field, hash-table iteration order, float associativity from parallel reduction, etc.).
3. **Slice-count invariance.** Run with `N_SLICES = 1` (effectively serial) → snapshot S1. Run with `N_SLICES = 10` → snapshot S2. `memcmp(S1, S2) == 0`. This proves the merge sort is canonical and the parallel pass has no order dependencies leaking through.
4. **Queue overflow behavior.** Push events faster than the sim drains them until the queue saturates. The producer should block briefly (or assert), never silently drop. Whichever choice the implementation makes, the test pins it.
5. **Snapshot age bound.** Instrument "ticks since last snapshot publish" on the render side. Under normal load this should be 0–1. If it climbs into double digits, the sim is falling behind and something is wrong.

### What to instrument from day one

The design's failure modes are mostly *invisible* without instrumentation, because both threads keep running. Cheap counters that pay for themselves:

- **Tick duration histogram.** Each tick records its wall-clock duration. A sudden bimodal distribution (most ticks at 5ms, occasional tick at 80ms) usually means GC-style pressure somewhere — a list growing, a buffer reallocating, a cache miss explosion.
- **Input queue high-water mark.** Largest queue depth observed since startup. If it ever crosses ~50% of capacity, the queue cap needs to grow or an upstream rate-limit is missing.
- **Snapshot publish rate.** Snapshots published per wall-clock second. Should equal `SIM_TICK_HZ` ± noise. Drops indicate sim stalls.
- **Render frame rate.** Already free from raylib. Compare against snapshot publish rate to spot decoupling failures.

These are four integers. They cost nothing to maintain and make the difference between "the game feels weird" and "tick 4127 took 92ms because the projectile array hit its cap and we silently allocated."

### Edge cases worth pre-thinking

- **Unit death during a tick.** A damage intent kills unit B. Other intents in the same tick might target B. Resolution: the merge step processes intents in deterministic order; later intents targeting a dead unit see HP = 0 and skip. The unit slot isn't reused until the *next* tick at earliest.
- **Projectile array fills up.** If `MAX_PROJECTILES` is exceeded, spawn intents at the merge step are dropped (with a debug-build assert). The cap should be sized for worst-case sustained fire across `MAX_UNITS`, with margin.
- **Input queue full.** Either block the producer (back-pressure into the input thread, which is the main thread — bad, causes frame stutter) or drop with logging (loses inputs, but main thread keeps drawing). The right answer depends on policy; pick one and stick to it. Sizing the queue for ~1 second of bursty input avoids hitting either case in practice.
- **Sim falls behind.** If a tick takes longer than the budget, do you skip a tick to catch up, or run them back-to-back? "Run back-to-back, but cap the catch-up at 4 ticks per render frame" is a common middle ground — recovers from brief spikes without entering a death spiral where catching up makes catching up harder.

### The minimum to call it done

Issue 102's bar is modest: a placeholder marker moves in a circle, driven by the sim thread, while camera input stays responsive. That's the smallest test of the architecture. Everything in this walkthrough is what the design *makes possible* once that bar is met — but the bar itself is achievable in a few hundred lines of code, because the design's surface area is small. Two threads, two locks, two snapshot buffers, one input queue. The complexity lives in the *discipline* of using it correctly, not in the primitives themselves.
