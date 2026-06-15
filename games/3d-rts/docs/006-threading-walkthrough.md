# 006 — Threading Architecture Walkthrough

A six-part guided tour of the threading model. `004-architecture.md`
is the spec; this document is the narrative companion that threads
through the spec, the issue files, and the implementation library
in the order a new reader needs to build mental model.

Each part begins with a **status line** distinguishing what's
*designed but not built*, what's *built and adopted*, and what's
*being redesigned to fix a bug*. The threading model is not a
single deliverable — it's a stack of decisions, some of which are
real on disk today and some of which are still on paper. Readers
who skip the status lines will conflate the plan with the reality.

The six parts:

1. The two-thread split and the boundary — *designed (102), not built*
2. The snapshot handoff — *designed (102), not built*
3. The input queue — *designed (102), not built*
4. The task pool reality — *built (114, 122) and adopted (107); redesign in flight (127)*
5. Modifier-ring batching — *design pattern, not yet built; aligns with 127*
6. Implications and implementation — *running notes*

---

## Part 1/6 — Two threads, one boundary

**Status:** Designed in `issues/102-threading-model.md`. **Not yet
built.** The current binary runs everything on the main thread;
issue 102's two-pthread split is what *will* exist. Movement
nevertheless already runs on the task pool today — see Part 4.

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
  3. runs systems (movement, combat, projectiles, factories) — possibly delegating per-unit work to the task pool from Part 4,
  4. builds a fresh snapshot in a back buffer,
  5. swaps front/back snapshot pointers under a lock,
  6. sleeps until the next tick boundary.

The "third thread of attention" is the input pipeline — it's logically its own flow, but it lives inside the main thread's frame loop; it doesn't need its own OS thread.

### The boundary: exactly two locks (at this layer)

This is the part worth memorizing, because it's the entire concurrency surface of the *main↔sim* boundary:

- **Mutex 1 — input queue** (`040-input.c`). Main thread holds it briefly to push; sim thread holds it briefly to drain. Fixed-capacity ring; producer never blocks meaningfully.
- **Mutex 2 — snapshot pointer swap** (`110-snapshot.c`). Sim thread holds it for the duration of a *pointer swap* (front ↔ back). Main thread holds it just long enough to grab the front pointer. The actual snapshot bytes are never copied across threads — only ownership of which buffer is "current" flips.

The task pool (Part 4) introduces additional locks *inside the sim
side* of the boundary — `reg_lk` (registry) and `qlk` (ready queue),
plus per-task atomics. Those don't cross the main↔sim boundary;
they're internal to the sim's own execution model.

Beyond those, nothing is shared. The terrain heightmap is built once at startup and treated as read-only thereafter; raylib's GL state lives entirely on the main thread; simulation arrays live entirely on the sim thread (with the pool's worker threads being part of "the sim side" of the boundary).

### Why this shape

The properties that fall out of two threads + two locks:

- **Render decouples from sim load.** If a tick stalls (the issue suggests deliberately `usleep`-ing 100ms inside one tick as a sanity test), the main thread still has a valid front snapshot to render — the marker pauses for a tick, but camera/zoom stay smooth. That test is the litmus that the decoupling actually holds.
- **No dropped inputs.** The queue absorbs bursts; the sim drains whatever accumulated since last tick.
- **Every tick is a pure function of `(prior state, drained input events)`.** This is what makes future replay/test harnesses possible without redesign — and it's also what makes the parallel work inside the sim (Part 4) safe.

### What's *not* in this part

- The shape of the snapshot struct itself — Part 2.
- Why input events carry `shift_chain_id` — Part 3.
- *How* the sim tick internally executes work — Part 4 (and it's not the slice-by-tenths shape `004-architecture.md` originally documented; the project chose a different shape, see Part 4).

---

## Part 2/6 — The snapshot handoff

**Status:** Designed in `issues/102-threading-model.md`. **Not yet
built.** As of 107's completion log, the renderer reads unit state
directly from the unit pool with inline extrapolation between task
updates (`render_pos = u->position + heading * speed * cos²(err) * (render_now - last_update_t)`).
This is acknowledged-temporary; the snapshot indirection from this
part replaces it when 102 lands.

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

The architecture doc calls this out explicitly: the front snapshot the renderer sees might be from the tick that just ended, or from one tick ago if the sim is mid-write. Either way, the renderer never blocks waiting for fresh data, and never sees a torn half-written snapshot. At 60Hz sim and 144Hz render, several frames will redraw the same snapshot — that's the expected, correct behavior. Interpolation between snapshots is a *future* optimization; the inline extrapolation 107 ships today is the placeholder until the snapshot itself lands.

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

## Part 3/6 — The input queue and shift-chain IDs

**Status:** Designed in `issues/102-threading-model.md`. **Not yet
built.** The current binary's main loop reads input and acts on
state inline. Phase 1 gameplay issues 108–119 will demand semantic
events as they land; that's the trigger that pulls 102 forward.

If part 2 is "how state flows sim→render," part 3 is the mirror: **how intent flows main→sim**. Same shape (one mutex, fixed-capacity buffer, no shared pointers), different content.

### Why a queue at all

The naïve alternative would be: main thread sets some "pending order" globals, sim thread reads them. That falls apart immediately — the sim ticks at a fixed rate (60Hz), the main thread polls input at frame rate (often 144Hz+), and a single tick boundary might span *multiple* user actions. A click followed 3ms later by a shift-click must both reach the sim, in order, even if they happened between two ticks.

So: a **fixed-capacity ring queue** of events, protected by one mutex. Main thread pushes; sim thread drains the entire queue at the start of each tick. Bursts are absorbed by the ring; nothing is dropped under normal load. This capacity is larger than you'd expect, because memory is cheap and we want to ensure there's no overwrites.

### Semantic, not raw

This is the part of the design that does the most work. The queue does **not** carry "key W went down" or "mouse moved to (x,y)". It carries **already-interpreted game intentions**:

-- this isn't true. We should recieve the input from the user in the raylib thread, then write it to a mailbox for each type of input in use. the E key. The mouse position. Etc. Each render tick, we write whatever is in the raylib input queue straight to the array of ring-buffers, each for each key, each input item thing. We may end up writing more than one. Well, depends on how raylib's input buffer is implemented... 

-- anyway we should have the inputs just passed straight to the thread-pool ready-task-list. The function they should run is essentially: "mouse_update_position()" or "E_key_pressed()" all defined in the same file with the same semantics. Each one corresponds to various game activities, which are stored as a pointer to a "key_activity" datastructure. This datastructure is pulled from a config file, and can be edited while in-game - simply update what happens when you press what keys in what context. Ideally, with a keyboard command (like ctrl+shift+spacebar+right-shift+enter) that says "whatever I press next is the new keybind for the most recent input action I did" then if there's modifiers held down, even keys like abcde's, it'll record them as chord keys that trigger particular events. These are created and managed dynamically - programmatically generated and managed in the raylib thread. They won't change very often, but they will trigger constantly as the user is inputting all of their commands.

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

... huh? that doesn't seem right. What the hey.

- Every order event emitted *while shift remains held* carries that same id.
- When shift is **released**, the id is closed; the next press allocates a new one.

When the sim drains events:

- Two `MOVE_ORDER`s with the same `shift_chain_id` → same chain, append in arrival order.
- A `MOVE_ORDER` with a `shift_chain_id` it hasn't seen before → start a new chain (and replace any existing one for the affected units).
- A `MOVE_ORDER` with `shift_chain_id == 0` (or whatever sentinel "no shift") → a singleton chain that replaces.

The beauty: the main thread holds **no game state** to do this. It tracks one integer counter and one "currently-open id, or none." That's it. The sim thread holds **no input/keyboard state** to interpret it — it just compares ids it receives to ids it has already seen for that selection. Each side's bookkeeping is local to itself.

The same scheme generalizes to rally-chain dragging on factories (`RALLY_DRAG_*` events share a `shift_chain_id` for shift-extending an existing rally chain).

the integer counter should intentionally stack overflow when it wants to wrap around. It should be unsigned. Nobody's going to queue up 60 bazillion movement orders. It's fine.

### What the boundary looks like end-to-end (once 102 lands)

Putting parts 1–3 together, one full round trip:

1. User right-clicks at screen `(450, 320)` while holding shift.
2. Main thread, in its frame loop:
   - notes shift is held → uses current `shift_chain_id`,
   - raycasts `(450, 320)` through the camera against the heightmap → world `(x, y)`,
   - takes the input-queue mutex, pushes `MOVE_ORDER(x, y, chain_id)`, releases.
3. Some milliseconds later, the sim thread starts a tick:
   - takes the input-queue mutex, drains all pending events into a local list, releases,
   - sees the `MOVE_ORDER`, recognizes the chain id, appends a waypoint to the chain for the currently-selected units,
   - dispatches per-unit work to the task pool (Part 4),
   - writes a new snapshot to back, swaps front/back under the snapshot mutex.
4. The next render frame:
   - takes the snapshot mutex, grabs the front pointer, releases,
   - draws units at their new positions and the order chain as a polyline.

Two locks at the boundary, both held for trivial durations, and a clean data boundary. That's the concurrency story for the *main↔sim split*. The story *inside* the sim is Part 4.

---

## Part 4/6 — The task pool reality

**Status:** Library shipped (`libs/900-task-pool.{h,c}`, issue 114
iter4.5). Wired into the game build as a process-wide singleton
(issue 122, `src/040-game-pool`, 4 workers). Adopted by movement
in Shape B (issue 107 re-open, completion 2026-04-29). **Bug-driven
redesign in flight (issue 127):** Shape B exposed a "snap"
problem when the OS preempts a worker mid-action; the fix is to
make the pool *frame-locked* rather than free-running.

This is the part where the original walkthrough (commit
`b2207e86`, drafted from issue 102 alone) got most things wrong.
The pool isn't coroutines, the sim isn't fully serial, and the
adopted parallel pattern isn't slice-by-tenths.

### What the pool actually is

Five iterations of design (recorded in issue 114's "Design
evolution" section) landed at: **action-array tasks with parking
on a per-blocker waiters list.** Concretely:

- **A task is a flat array of small atomic functions.** Each
  function ("action") returns one of `ACT_ADVANCE` (next
  index), `ACT_JUMP` (to a named index), `ACT_BLOCK` (suspend
  on another task's GUID; resume at the same index when woken),
  `ACT_DONE` (skip remaining actions). The "resume point" is a
  single `unsigned int current_index` — trivially serializable,
  naturally re-enterable. No `swapcontext`, no per-task stacks,
  no trampoline. Standard C function calls only.
- **Per-action arguments and per-action results** live in
  parallel arrays alongside the actions array. Each result slot
  is write-once by convention; reading uses
  `pool_result_slot(pool, id, slot, &out)` which returns a
  `slot_status_t` enum (`SLOT_PENDING`, `SLOT_FILLED`,
  `SLOT_OUT_OF_RANGE`, `SLOT_UNKNOWN_ID`) so callers can
  distinguish "action k hasn't run yet" from "action k ran and
  legitimately wrote NULL."
- **A GUID registry** (open-addressed hashmap, capacity 4096)
  maps `task_id_t` (uint64) to `task_t *` with refcounts. Every
  external handle is a GUID; the pool never hands out raw
  pointers.
- **Ten priority queues**, indexed 1 (highest) to 10 (lowest).
  A *cycler* picks which queue to consult next, following the
  pattern `1; 1,2; 1,2,3; …; 1..10` and repeating. Period is
  54 steps. High priorities dominate without starving low ones.
  Empty queues at the current step are skipped; the cycler
  still advances.
- **Parking on waiters[].** When an action returns `ACT_BLOCK`
  with a target GUID, the worker appends the blocked task's id
  to the *target's* waiters[] array and sets the blocked
  task's state to `TASK_PARKED`. The parked task is in no
  queue and consumes zero CPU. When the target eventually
  reaches DONE, the worker walks the waiters[] and pushes
  each waiter back onto its priority queue. Iter4.5 tests
  reduced parking-related polling from ~113k retries to
  exactly 1.
- **Promote-on-blocked-target.** When task A parks on B, if B
  is in the ready queue at priority p > 1, the worker promotes
  B to p−1 (toward higher priority). A unparks sooner because
  B runs sooner. Demote-on-block was tried (iter4) and deleted
  (iter4.5) — parking made it pointless.
- **Self-rescheduling pattern.** A task's last action enqueues
  a fresh copy of itself via `pool_spawn`. One-line idiom for
  per-frame update loops without holding a worker hostage.

The library has no dependency on raylib or game state. It's
exercised by 9 tests in `tests/` covering sequential actions,
cross-task result-slot waits, mid-task park/wake, self-
rescheduling, priority cycling, result slots, parking promote
semantics, slot-status disambiguation, and many-waiter bursts.

actions get GUID's of other tasks which may block them when the tasks are
created. You will always know when a blockable task is being made exactly
which task it is that might block it - so multiple tasks can interleave.
when there are no reference counts remaining, a task can be cleaned.

### How the pool is integrated

Issue 122 (completed 2026-04-28) wired the library into the game
build. `Makefile` now compiles `libs/900-task-pool.c` alongside
`src/*.c` and adds `-I.../libs -D_XOPEN_SOURCE=600`. A thin
wrapper `src/040-game-pool.{h,c}` exposes a process-wide
singleton:

- `game_pool_init(N)` — called once after `units_init`. Creates
  the pool with N workers. Default N=4 (typical desktop has
  4–16 cores; profiling will dictate any change).
- `game_pool()` — returns the singleton handle.
- `game_pool_shutdown()` — destroys it before
  `terrain_shutdown` / `CloseWindow`.

This issue deliberately did *not* migrate any game system to use
the pool. The first migration (issue 107 re-open) followed
immediately; subsequent adoptions land with the issues that
introduce their systems (113 combat / HP regen, 112 projectile
arc, 116 factory production).

### Shape A vs Shape B — and why Shape B won for movement

`docs/004-architecture.md` describes a slice-by-tenths
parallel-for pattern: split a per-unit pass into ~10 contiguous
slices, dispatch each slice as a task, run the merge step after
join. That's Shape A — the originally-planned shape, still the
right choice for a per-tick batched system.

Issue 107 (Shape B) shipped a different shape for movement:
**per-unit self-rescheduling tasks.** Each unit with an active
target owns a movement task that re-enqueues itself each tick:

```
movement_task_actions = [
    [0] move_advance       // read target, slew yaw, step forward, resnap Z, arrival check
    [1] move_reschedule    // if still moving: spawn next iteration; else clear movement_task_id
]
```

these types of actions can't add new actions to their own task, but they can
create new tasks with whatever types of motions they're programmed to remote.

Why Shape B was chosen for movement:

- The user's stated preference for "self-rescheduling for things
  like walking toward a location" is direct guidance.
- **Stationary units consume zero scheduler time.** A
  slice-by-tenths pass iterates every unit every tick whether
  it's moving or not; per-unit tasks only exist for units with
  active orders.
- The per-tick task-struct overhead (one `task_t` per moving
  unit per tick) is bounded and acceptable at Phase 1 unit
  counts (six initially; hundreds after factory production).
- Switching to Shape A later is mechanical — the action
  body is already a function of (unit, dt) — if profiling
  ever shows per-unit task overhead dominating.

Shape A remains the right fit for systems where every entity
*does* need updating every tick (HP regen on all units; LoS
scans). Shape B is the right fit for systems where only a
fraction of entities are active in any given tick. Adoption is
per-system; future migrations will pick a shape per their
profile.

### Timestamp-based motion

Shape B's movement task uses `last_update_t` (double, seconds,
via raylib's `GetTime()`):

```
move_advance:
    now = GetTime()
    dt = now - u->last_update_t
    apply turn (UNIT_TURN_RATE * dt, capped by remaining error)
    apply forward step (UNIT_SPEED * dt * cos²(angular_error))
    resnap Z to terrain
    arrival check (clears has_target within UNIT_REACH_RADIUS)
    u->last_update_t = now
    return ACT_ADVANCE
```

The point of timestamp-based motion: a task that runs every
tick at priority 2 produces the same total displacement as a
task that runs every fifth tick at priority 10 — it just steps
in larger chunks. Scheduler-induced cadence variation is
absorbed by the math.

### The snap — and why timestamp-based motion alone isn't enough

Shape B shipped with a known issue: with 6 units and `T` to
scatter, 5 move smoothly while 1 stays visually stationary for
1–3 seconds, then teleports. Fans run at full speed during
movement.

Root cause: `move_advance` captures `now = GetTime()` at the
*start* of the action, runs its arithmetic, and writes
`u->last_update_t = now` at the *end*. If the OS preempts the
worker thread between the capture and the write, real time
advances during the preemption but the captured `now` does not.
The next iteration sees `dt = GetTime() - last_update_t` of
1–3 seconds and computes a correct-but-large step.

This isn't a movement bug — it's the *architecture* announcing
that "poll as fast as possible, math will fix it" doesn't work
when the underlying scheduling is non-uniform. Two band-aids
considered and rejected:

- "Read `GetTime()` at end of action" → drops the preempted
  time; unit covers less than physically correct distance.
- "Cap dt at 100ms" → same, more aggressively. Bad for combat
  hit-detection correctness.

The accurate fix is to bound how often the action runs. That's
issue 127.

### Frame-ring scheduling (issue 127, in flight)

Replace the single set of priority queues with a **ring of
frame slots**, each containing its own ten priority queues.
Workers only pop from `frames[current_frame]`. Spawns default
to `frames[(current_frame + 1) % SIZE]`. Three spawn variants:

- `pool_spawn(...)` — implicit "schedule for next frame."
  Cannot land in the current frame.
- `pool_spawn_in(N, ...)` — schedule N frames out (relative).
  N=1 is the default. N=0 is rejected.
- `pool_spawn_in_current(...)` — escape hatch for input
  handlers that legitimately need to react this frame.

Main thread calls `pool_advance_frame(pool)` after
`EndDrawing()`. The call **stalls** until the current slot is
fully drained (empty across all priorities AND no parked
tasks waiting on tasks in this slot). Only then does
`current_frame` advance.

What this fixes:

- Movement runs exactly once per frame. With `SetTargetFPS(60)`,
  `dt ≈ 16.67ms ± small jitter`. No 1–3 second snaps; lost
  preemption time becomes part of the next normally-sized
  frame's `dt`, capped by the frame budget itself.
- The cycler still runs *within* a single frame's queues —
  same logic, scoped per-slot.
- Periodics ("run every N frames") become a one-line idiom:
  the reschedule action calls `pool_spawn_in(N, ...)`. Issue
  123's dedicated periodics design is **superseded** by this.
- The same stall semantics make lockstep multiplayer
  determinism a natural fit later: every client agrees on
  end-of-frame-N state before exchanging inputs for N+1.

What stays the same:

- Action-array tasks, GUIDs, refcounts.
- Parking on waiters[], promote-on-blocked-target.
- Result slots and `slot_status_t`.
- Self-rescheduling pattern (just calls `pool_spawn_in(1, ...)`
  instead of `pool_spawn(...)`).

### The other open task-pool issues

- **123 — periodics.** Superseded by 127.
- **124 — stable-index task storage.** Exploratory iter5;
  user explicitly pushed back on pre-planning it. May land if
  cheap live-task iteration becomes a real need.
- **125 — API hardening.** Future pass: abort-on-unknown-id
  for `pool_is_done`/`pool_ref`/`pool_unref`/`pool_result_slot`,
  wrapper-struct `task_id_t` to enforce move-vs-clone, hide
  `park`/`wake` behind named internal helpers. None of these
  change mechanics; they sharpen edges.

### What's *not* in this part

- The merge step from `004-architecture.md` (intent records,
  deterministic sort, single-threaded apply). Movement under
  Shape B doesn't use it — the action is slice-disjoint to
  begin with (each task touches one unit). Combat and damage
  in 113/112 will need it because cross-unit effects are
  unavoidable. The intent-records pattern is the right shape
  for those passes; it just hasn't been exercised yet.
- The modifier-domain extension of intent records — Part 5.

---

## Part 5/6 — Modifier-ring batching

**Status:** Design pattern, captured here. **Not yet built.**
Aligns naturally with the frame-ring delivery from Part 4 (issue
127). The pattern generalizes the merge-step from
`004-architecture.md` to the *modifier* domain (e.g. "+20%
speed," "1.3× damage," "regen rate +0.05/s").

### The pattern

Each tick, the totals of modifiers being applied to each unit are
*accumulated* during the frame's parallel pass and *applied* at
the start of the next frame. Modifier intents are written to a
**separate memory location**, one slot per frame index in the
frame ring, so accumulation in frame N doesn't perturb the
modifiers being applied to units mid-frame N.

Conceptually, alongside the frame ring's task queues:

```
struct frame_slot {
    /* (existing) ten priority queues for tasks scheduled this frame */
    /* ... */

    /* (new) modifier intents accumulated by tasks running in this frame */
    modifier_intent_t *intents;
    int                n_intents;
    int                cap_intents;
};
```

The flow:

1. During frame N execution, any task that wants to apply a
   modifier (e.g., a "speed boost" buff task, a "damage taken
   modifier" effect) appends an intent into `frames[N].intents`.
   Each intent is small: `{ target_unit_id, modifier_kind,
   value }`.
2. At the start of frame N+1 (just after `pool_advance_frame`
   has stalled-and-flipped), a single-threaded sweep folds
   `frames[N].intents` into per-unit modifier sums. Multiple
   `+X%` intents into the same target sum naturally; conflicts
   between modifier kinds resolve via a fixed application
   order.
3. Frame N+1's tasks read the freshly-applied modifiers when
   they run. They emit their *own* intents into
   `frames[N+1].intents` for frame N+2 to consume.

This is the merge-step pattern from `004-architecture.md`
(produce intents in a parallel pass, apply single-threaded)
delivered through the frame ring instead of through a
within-tick collect-and-merge.

### Why a *ring* (not just "next tick")

The frame ring is already a circular structure (Part 4). Use the
same circular indexing for modifier accumulation, and a
nice-to-have property falls out: **long-running modifier
computations get a free deadline equal to the ring period.**

Concrete: suppose computing a particular modifier is
unexpectedly expensive — say, an AoE damage modifier that walks
nearby units. The task computing it spans more than one frame.
The modifier ring's slots are stable for `FRAME_RING_SIZE`
frames; by the time the ring has cycled back to the same slot
index, the long-running computation is "probably done." The
sweep at apply-time does a cheap "are you done?" check on the
intent. If yes, fold it in. If no — for the genuinely
restricted cases — it continues into the next ring revolution
and slots in then. Long-tasked projects ring-cycle quicker and
sooner; short ones finish before their slot is needed.

This is the user's framing: *"write to a different memory
location ring buffer style and it works out easy. The long ones
will be done by the time it's back to the beginning of the ring
buffer. Odds are, if they aren't completed, it's just a quick
check to validate — are you done? if no, because it was one of
the restricted ones, then they'll continue on their way."*

### Why this is the right shape for "+X%" modifiers specifically

- **Commutative and associative within a frame.** Three sources
  of "+10% speed" applied in any order produce the same result.
  Accumulating into a sum is the natural operation; no
  tie-breaking needed.
- **Bounded blast radius per modifier kind.** A speed modifier
  doesn't interact with a damage modifier; per-kind sums in
  the apply sweep are independent.
- **Deterministic.** Sums of floats committed in the same
  application order produce the same result on every machine.
  The sweep applies in `(target_id, modifier_kind)` order;
  iterating intents is incidental, the *fold* is canonical.

### Concrete fits

- **Speed modifiers.** Buffs ("+20% speed for 5 seconds"),
  debuffs (slow on hit), terrain effects (mud halves speed).
- **Damage multipliers.** Crit chance, armor piercing,
  distance falloff — anything that scales projectile damage
  before HP application.
- **Regen rate modifiers.** Stacked regen buffs from multiple
  factories.
- **Accuracy bonuses.** Stationary aim bonus, supporting-fire
  bonus from nearby units.

All of these are "+X%" or "×K" effects; all of them
naturally sum or multiply into a per-unit, per-kind slot.

### How it differs from the existing intent-records pattern

`docs/004-architecture.md` describes intents that target
*single fields* (HP delta, kill flag, projectile spawn).
Modifier-ring intents target *modifier accumulators* —
they don't decide a final value, they contribute to one. The
apply sweep doesn't choose; it sums.

This means modifier intents *can* be applied in any order
without changing the result, which is what makes them
parallelization-friendly. The only ordered sweep is the
single-threaded one at frame-N+1 start, and even there the
order is canonical (target_id, kind), not arrival.

### What's *not* in this part

- The implementation. No code yet. Issue 127 is the natural
  carrier for the modifier ring's data structures (since it
  already adds the frame ring); a follow-up issue will
  formalize the modifier intent struct and the apply sweep
  when the first concrete consumer arrives. Likely candidates:
  speed buffs (Phase 2 ability work), damage multipliers
  (issue 113 combat).

---

## Part 6/6 — Implications and implementation notes

### What this design buys you downstream

- **Determinism is load-bearing.** Each tick is a pure function
  of `(prior state, drained input events)`. That property
  unlocks replay (record events, replay later), regression
  tests (scripted event log → assert against snapshot), network
  rollback (lockstep multiplayer is a natural fit; the
  frame-ring stall in Part 4 is exactly the synchronization
  point lockstep needs), and AI training environments (headless
  sim ticks as fast as the CPU allows).

- **Sim rate is a tuning dial.** Render is decoupled from sim
  (Part 1). `SIM_TICK_HZ` and the frame-ring period (Part 4)
  are independent levers. A 30Hz sim with render-side
  interpolation looks identical to a 60Hz sim at 144Hz render
  but burns half the simulation cost. Useful as unit counts
  grow.

- **Headless sim as a first-class artifact.** The sim thread
  doesn't link against raylib. A `sim-only` build target
  reuses `120-sim.c` + `010-config.h` + the task pool with a
  driver that pipes events from stdin and snapshots to stdout.
  Test harnesses, AI evaluators, and dedicated multiplayer
  servers all share simulation code.

- **The snapshot as a serialization format.** Once 102 lands,
  the snapshot is a flat copyable struct sized for `MAX_UNITS`.
  Save/load is `fwrite`/`fread`. UDP-friendly because bounded
  in size. Diffable for debug oracles ("dump every K ticks,
  find the tick where divergence began").

- **The intent / modifier patterns generalize.** Combat damage
  intents (Part 4 caveat), modifier-ring sums (Part 5), audio
  events (a separate ring queue main-thread-bound), pathfinding
  requests (per-unit task emits a request intent; a dedicated
  pathing pass services them). Once you see "produce intents
  in parallel, apply single-threaded in a deterministic
  order," it's hard to unsee.

### What's actually been tested

Pool library (`tests/` in the project, all passing as of
2026-04-29):

| Test | Behavior covered |
| --- | --- |
| 001 | N-action task runs in order; args route correctly |
| 002 | Cross-task result-slot wait via `pool_result_slot` + `ACT_BLOCK` |
| 003 | Mid-task block parks, wakes, resumes at same `current_index` |
| 004 | Self-rescheduling pattern reaches its termination condition |
| 005 | Priority cycler: high priorities complete sooner on average |
| 006 | Result slots readable by next action and externally |
| 007 | Block promotes blocker; A's priority unchanged (parking, not demote) |
| 008 | `result_filled` distinguishes "ran and wrote NULL" from "didn't run" |
| 009 | 50 waiters on one blocker — all 50 wake when blocker finishes |

Game integration: build is clean under `-Wall -Wextra
-Wpedantic -std=c11`; binary launches; raylib reports 6.0; no
crash on shutdown (issue 122 verification). Movement under
Shape B: visual confirmation of smooth turn-then-walk on six
units; the snap is the one known regression (driving 127).

What's *not* tested yet:

- 102's two-pthread split (issue still TODO).
- Snapshot publish/acquire (same — issue 102 prerequisite).
- Frame-ring scheduling (issue 127 in flight).
- Modifier-ring batching (Part 5 — pattern only).
- Mass scatter under load (only six units exist; 116's factory
  production will populate the test).

### What to instrument when 102 + 127 land

Cheap counters that pay for themselves:

- **Tick duration histogram.** Each sim tick records its
  wall-clock duration. Bimodal distributions usually mean
  GC-style pressure — a list growing, a buffer reallocating,
  a cache miss explosion.
- **Frame-budget overrun.** When `pool_advance_frame` stalls,
  log how long it stalled. Persistent overruns mean a frame
  is too expensive; profiling tells you which task.
- **Cadence histogram per task type.** For self-rescheduling
  tasks, the gap between consecutive runs of the same task.
  Under the frame-ring, this should be exactly one frame
  ± jitter; outliers are the bug 127 was built to surface.
- **Parked task census.** Number of tasks in `TASK_PARKED`
  state. A growing parked count means dependency chains are
  serializing; might be load, might be a missing wakeup.
- **Input queue high-water mark.** Largest queue depth
  observed since startup. Crossing 50% capacity means the
  cap needs to grow or an upstream rate-limit is missing.
- **Snapshot publish rate vs render frame rate.** Should
  equal `SIM_TICK_HZ` ± noise. Drops indicate sim stalls
  the renderer is hiding via stale-snapshot redraws.

### The minimum to call the architecture done

A reader who's followed parts 1–5 should be able to point at
each issue's status line in this document and tell whether
it's plan, build, or fix-in-flight. The architecture is
"done" when:

- 102 lands → boundary becomes real, snapshot exists,
  semantic events flow.
- 127 lands → cadence is bounded, the snap is gone,
  periodics are a one-line idiom.
- Modifier-ring (Part 5) lands when its first concrete
  consumer arrives — likely a speed buff or damage modifier
  in Phase 2 or issue 113's combat.
- 124 / 125 land *if and when* profiling or operational
  experience justifies them.

The complexity lives in the *discipline* of using these
primitives correctly, not in the primitives themselves. Two
threads, two boundary locks, two snapshot buffers, one input
queue, an action-array task pool with parking, a frame ring
that bounds cadence, and a modifier ring that delivers
"+X%" effects with one-frame latency. That is the whole
architecture, and most of it is already real.
