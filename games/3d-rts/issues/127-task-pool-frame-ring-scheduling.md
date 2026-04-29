# 127 — Task pool: frame-ring scheduling

## Status

TODO. Next concrete piece of work after 107 lands. Direct successor
to issue 123 (which is now superseded — periodics are subsumed by
this design as "schedule into frame N+k").

## Why this exists

Issue 107's Shape B movement (per-unit self-rescheduling tasks at
priority 2) exposed a fundamental architectural problem with
self-rescheduling-at-max-rate: **timestamp-based motion is
mathematically correct under variable cadence, but cadence
variability is unbounded.** A worker thread can be off-CPU for
1-3 seconds when the system is contended; when it resumes, the
unit's next step has to cover that real-time delta in one frame.
The result is a visual snap from old position to new position,
with no smooth interpolation.

This is not a small bug. It's the architecture announcing that
"poll as fast as possible, math will fix it" doesn't work when
the underlying scheduling is non-uniform. The fix is to bound
cadence variability — make `dt` approximately constant by
locking task execution to frame boundaries.

## Snap reproduction (motivating example, captured 2026-04-29)

- 6 units, press T, all get random targets via
  `units_set_target` → `pool_spawn` per unit.
- 5 units move smoothly toward their new targets.
- 1 unit stays visually stationary for 1-3 seconds, then snaps
  (instantly translates and rotates) to a new position.
- Fans run at full speed while units are moving.

Root cause: in `move_advance`, `now = GetTime()` is captured at
the start of the action; the action does its arithmetic; at the
end, `u->last_update_t = now` writes that *start-of-action* `now`
value. If the OS preempts the worker between the capture and the
write (as happens occasionally on a contended system), real-time
advances during the preemption but the captured `now` does not.
The next iteration sees `dt = GetTime() - last_update_t` of 1-3
seconds, computes a correct-but-large step, and the unit teleports.

No band-aid in this layer fixes the issue without losing physical
correctness:
- "Read GetTime() at end of action" → drops the preempted time;
  unit covers less total distance.
- "Cap dt at 100ms" → same thing, more aggressively.

The only correct fix: bound how often the action runs. If
movement runs exactly once per frame and frame rate is bounded
(`SetTargetFPS(60)`), `dt ≈ 16.67ms ± small jitter`. No
accumulation, no snap, no lost distance.

## Intended design

A **ring of frame slots**, each slot itself containing the same
ten priority queues we have today. Concretely on `task_pool_t`:

```c
#define FRAME_RING_SIZE 8        // tunable — how many frames of lookahead
struct task_pool {
    // ... existing fields except the queue arrays ...
    struct {
        struct task **queues[N_PRIORITIES + 1];
        int queue_lens[N_PRIORITIES + 1];
        int queue_caps[N_PRIORITIES + 1];
        int n_ready_total;
    } frames[FRAME_RING_SIZE];
    int current_frame;             // index into frames[]; the slot workers drain.
    int next_frame_offset;         // == 1 typically — "next frame" is current+1 mod size.
};
```

Workers only pop from `frames[current_frame]`. New spawns always
land in `frames[(current_frame + offset) % FRAME_RING_SIZE]`,
where `offset >= 1` (the rule below).

### Spawning rules

- **`pool_spawn(...)`** — implicit "schedule for next frame."
  Lands in `frames[(current_frame + 1) % SIZE]`. Cannot land in
  the current frame; mid-frame work is what *this* frame's tasks
  scheduled *previously*, not what just-spawned tasks request.
- **`pool_spawn_in(N, ...)`** — schedule N frames from now. N=1
  is the default. N=0 is rejected (or interpreted as N=1; TBD).
  N=2 is "two frames out." N is *relative*, never an absolute
  frame counter — relative makes sense regardless of how many
  frames have run, doesn't require user to track a global counter.
- **`pool_spawn_in_current(...)`** — escape hatch for code that
  legitimately wants to land in the current frame (e.g., a task
  that needs to react to user input *this* frame, like a click
  handler). Used sparingly. Could be omitted entirely from the
  initial implementation if we don't need it.

### Frame advance

Main thread calls `pool_advance_frame(pool)` after the render
loop's `EndDrawing()` to mark "this frame is done; please move on."

Two possible behaviors when the current slot still has unfinished
work:

1. **Stall (recommended).** `pool_advance_frame` blocks until the
   current slot is fully drained (n_ready_total == 0 across all
   priorities AND no parked tasks waiting on tasks in this slot).
   Main thread keeps rendering — animations, particles, camera
   pan — but game-logic frame doesn't advance until this frame's
   logic is done. This is the model that makes lockstep multiplayer
   determinism possible: all clients agree on logic-frame N's
   complete state before advancing to N+1.

2. Auto-promote leftover tasks to next frame. Simpler, but mixes
   frame budgets and breaks determinism. Rejected.

Stall behavior is preferred. If the game routinely overflows its
frame budget, that's a profiling problem, not a scheduling one —
fix it by speeding up the offending tasks.

### Multiplayer determinism (motivating future use case)

Frame-locked task execution means: given the same input at the
start of frame N, all clients produce the same end-of-frame N
state. Clients can't have one client's logic "race ahead" because
its CPU is faster — every client waits for its own frame N tasks
to drain before advancing. Then they exchange inputs for frame
N+1. Standard lockstep model. The frame-ring design is the natural
fit; a polling pool would have to be retrofitted.

## What stays the same

- Public API for action contracts (`task_ctx_t`, `action_fn_t`,
  `ACT_*` enum values, `slot_status_t`).
- Parking on blocked-target (iter4.5 semantics). Parked tasks are
  not in any frame slot; they're attached to their blocker's
  waiters list. When woken, they get pushed to a frame's queue
  (current frame? next frame? — design decision pending).
- Result-slot semantics, refcounting, registry.

## What changes

- `pool_spawn` signature gains a "frame offset" or grows
  `pool_spawn_in(offset, ...)` as a sibling. Default is `+1`.
- `pool_advance_frame` is new public API.
- The "queue" inside `task_pool_t` becomes per-frame. Internal
  representation grows; public API barely changes.
- Self-rescheduling tasks (movement) call `pool_spawn_in(1, ...)`
  in their reschedule action. Each iteration runs once per frame.
- The cycler runs *within* a single frame's queues, not across
  frames. Same logic, just per-slot.

## Suggested implementation steps

1. Add `frames[FRAME_RING_SIZE]` to `task_pool_t`. Move the
   existing per-priority queue fields into the struct.
2. Add `current_frame` and the offset / advance functions.
3. Rewrite `queue_push` to accept a target frame (defaults to
   `current+1`). Workers' `ready_pop_locked` reads from
   `frames[current_frame]` only.
4. Add `pool_advance_frame(pool)` that stalls until current
   slot drains, then bumps `current_frame`.
5. Update `pool_spawn` signature (and / or add `pool_spawn_in`).
6. Update `040-game-pool` wrapper to expose the new API.
7. Update `001-main.c` to call `pool_advance_frame` in the
   per-frame loop.
8. Update `050-units.c` so movement reschedule uses
   `pool_spawn_in(1, ...)`.
9. Verify: snap is gone. Fans no longer run at full speed during
   movement (CPU drops to "6 tasks × 60Hz = 360 iterations/s"
   instead of "hundreds of thousands per second").
10. Update tests: rewrite test 005 (priority cycler) to advance
    frames; add a frame-ring-specific test
    (`tests/NN-task-pool-frame-bucket.c`).

## Open design questions for implementation time

- **Where do woken parked tasks land?** Current frame (run this
  frame) or next frame (deferred)? Probably next frame for
  consistency.
- **What's the right `FRAME_RING_SIZE`?** 8 is a guess. A periodic
  scheduling 5 frames out needs SIZE >= 5. Larger sizes cost
  memory (one set of queue arrays per slot). 16 might be safer
  default.
- **`pool_advance_frame` stall semantics under shutdown.** If
  the pool is shutting down with pending frame work, do we drain
  or leak? Per `pool_destroy`'s existing contract, leak.
- **Interaction with promote-on-blocked-target (iter4.5).**
  Promoting a task from priority 7 to 6 within the same frame
  works the same. Promotion *across* frames doesn't make sense
  — a task in next-frame's slot can't be promoted into this
  frame's queue (we'd race against the drain). Document.

## Related

- `123-task-pool-periodics.md` — superseded by this issue.
  Periodics ("run every N frames") become a one-line idiom under
  this design: a self-rescheduling task uses `pool_spawn_in(N,
  ...)` in its reschedule action.
- `124-task-pool-stable-indices.md` — independent, exploratory.
  May or may not be wanted; not blocked by this issue.
- `completed/107-unit-movement-on-terrain.md` — movement is the
  first real caller; the snap captured here is the motivating
  problem.
- `completed/114-coroutine-pool-library.md` — the iter4.5 task
  pool design that this issue extends.

## Out of scope

- Run-task-end-to-end (no inter-action re-push). That's a
  separate iter5+ idea, not bundled here.
- Stable-index task storage (issue 124). Independent.
- API hardening (issue 125). Independent.
