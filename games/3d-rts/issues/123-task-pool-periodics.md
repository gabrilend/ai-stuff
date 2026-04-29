# 123 — Task pool: library-managed periodics (frame-based)

## Status

**Future work.** Captured during the iteration-4 design conversation
(2026-04-28); not part of iter4 itself. The original `promote_if_late`
flag idea on `pool_spawn` was deferred to here because the library
role wasn't yet clear and no real caller exists. Once issue 107's
movement task or another periodic shows what it actually needs, this
issue defines the interface.

## Why frames, not microseconds

Earlier conversation suggested microseconds. On reflection, frames
are the right unit:

- Game cadence is frame-bound, not wall-time-bound. A task that
  needs to "run roughly every render tick" is naturally expressed
  in frames.
- Frame counters are monotonic, cheap to read, and don't require
  `clock_gettime` syscalls.
- The cycler's natural rhythm is already discrete; frames map onto
  it cleanly.

## Current behavior

There is no library notion of periodicity. A task that wants to
re-run periodically does so manually: at the end of its action
chain, it calls `pool_spawn` to create the next iteration.

Self-rescheduling tasks must:
1. Decide their own next-iteration priority.
2. Track their own arrival timestamps if they care about latency.
3. Re-spawn with all the same actions and args each time.

This works but is repetitive boilerplate at every periodic site.

## Intended behavior

The library accepts a per-task periodicity spec at spawn time:

```c
typedef struct {
    int every_n_frames;     // target cadence: re-run every N frames.
    int max_slack_frames;   // if a run is more than this many frames late,
                            //   library promotes priority by one for the
                            //   next iteration (sticky until a run lands
                            //   on time again).
    int floor_priority;     // never auto-promote past this.
} task_periodic_spec_t;

task_id_t pool_spawn_periodic(task_pool_t *pool,
                               const action_fn_t *actions,
                               void *const      *action_args,
                               int               n_actions,
                               int               initial_priority,
                               task_periodic_spec_t  spec);
```

The library:

1. Increments a frame counter on each frame boundary (driven by the
   game loop calling `pool_advance_frame(pool)`).
2. Tracks the last-completion frame number for each periodic task.
3. When a periodic task completes, schedules a re-spawn at frame
   `last_completion + every_n_frames`. The re-spawn happens by
   inserting a marker into a per-frame "due" list.
4. If the actual completion frame exceeds the target by more than
   `max_slack_frames`, bumps `initial_priority` by one for the
   next spawn (sticky promotion until the task starts landing on
   time again).
5. Auto-demote-on-block (already in iter4) still applies.

## Suggested implementation steps

1. Add `int frame` field to `task_pool_t`. Add
   `void pool_advance_frame(task_pool_t *pool)` — called by the
   game loop once per render tick.
2. Add `task_periodic_spec_t` typedef and `pool_spawn_periodic`
   public API.
3. Internally, periodic tasks have an extra "rescheduler" action
   appended to their actions array (similar in spirit to the
   iter3-era synthetic dep-check, but for re-spawning rather than
   waiting). The rescheduler computes the next spawn frame and
   priority based on this iteration's actual completion frame
   versus target.
4. The pool maintains a small "frame-ordered due list" — tasks
   waiting for their target frame to arrive. Each call to
   `pool_advance_frame` walks tasks whose target frame ≤ current,
   pushes them onto the ready queue at their current priority.
5. Update `tests/000-index.md` blind-spot list to remove
   "periodics" once tests cover this.

## Tests

- `tests/NN-task-pool-periodic-cadence.c` — periodic at cadence
  N; assert it runs ~`total_frames / N` times across a fixed
  number of frame advances.
- `tests/NN-task-pool-periodic-slack-promote.c` — periodic with
  small `max_slack_frames` under artificial load; assert priority
  rises after slack is exceeded.

## Related

- `114-coroutine-pool-library.md` — the deferred `promote_if_late`
  flag idea originated there. This issue subsumes it.
- `107-unit-movement-on-terrain.md` — likely the first periodic
  consumer (per-tick movement update). When 107 transitions onto
  the pool, its requirements will pin down details here.

## Out of scope

- Wall-time-based periodicity. If real-time deadlines matter
  (e.g., audio), a separate mechanism applies; this one is for
  game-tick cadence.
- Adaptive cadence (e.g., "run more often when there's load to
  spare"). Initial design is fixed-N; adaptive can come later.
