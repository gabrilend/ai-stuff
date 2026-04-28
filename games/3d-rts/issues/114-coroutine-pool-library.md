# 114 — Coroutine Pool Library (M:N over pthreads)

## Status

TODO

## Current behavior

`libs/` is empty. The project's only described concurrency primitives
are the two dedicated pthreads from issue 102 (main + sim) and the two
mutexes that guard the input queue and snapshot pointer swap.

There is no general-purpose mechanism for spawning many cooperative
tasks onto a small set of OS threads — every concurrent piece of work
would need its own bespoke thread, queue, and lifecycle.

## Intended behavior

`libs/` contains a small, self-contained C library that multiplexes
many coroutines onto a fixed pool of pthreads. A consumer can:

- Create a pool of N worker pthreads.
- Spawn coroutines onto the pool. Each runs on its own ucontext stack.
- Cooperatively yield from inside a coroutine to release the worker.
- Join on a coroutine to wait for completion.
- Destroy the pool and reclaim resources.

The library has no dependency on raylib, no dependency on game state,
and no global mutable state aside from the per-thread "currently-running
coroutine" pointer that the yield primitive needs.

The library is **available** to the rest of the project but **not yet
adopted** by it. The two-thread architecture in `docs/004-architecture.md`
remains the design of record. See "Why this exists separately from 102"
below.

## Suggested implementation steps

1. Create `libs/900-coroutine-pool.h` declaring the public API:
   `cpool_create`, `cpool_destroy`, `cpool_spawn`, `co_yield`, `co_join`,
   plus the opaque `cpool_t` and `co_t` handle types.
2. Create `libs/900-coroutine-pool.c` implementing the worker loop,
   the FIFO ready queue (mutex + condvar), the ucontext-based stack
   switch, and the coroutine lifecycle (READY → RUNNING → DONE, with
   join handshake).
3. Create `libs/900-coroutine-pool.info.md` listing each external
   function with its inputs, outputs, and call-site constraints (e.g.
   `co_yield` is only valid from inside a coroutine running on a worker).
4. Add a `libs/` section to `docs/000-table-of-contents.md` so the new
   files are discoverable.
5. Add a "Related libraries" cross-reference to
   `issues/102-threading-model.md` pointing at this library, with a
   sentence explaining that adoption is a separate decision.

## Mechanical description

A worker pthread is a scheduler loop. Each iteration:

1. Pop the next ready coroutine off the shared FIFO (block on a condvar
   if the queue is empty).
2. `swapcontext` from the worker's own scheduler context into the
   coroutine's ucontext. The coroutine now runs on its own stack on
   this OS thread.
3. The coroutine runs until it either calls `co_yield` (which
   `swapcontext`s back to the worker) or returns from its top-level
   function (which falls through `uc_link` back to the worker).
4. The worker inspects a `finished` flag set by the trampoline. If
   set, it takes the coroutine's lock, marks it `DONE`, and broadcasts
   to any joiner. If not set, it re-pushes the coroutine onto the
   ready queue.

`co_yield` is implemented as a `swapcontext` from the current
coroutine's context back to a thread-local "scheduler context"
established by the worker before each `swapcontext` in. The
thread-local also names the currently-running coroutine, so
`co_yield` does not need its handle as an argument.

The ready queue is a mutex-guarded singly-linked list with one
condvar. A condvar broadcast signals workers to re-check the queue.
`shutdown` is a flag plus a broadcast.

Pointer-into-ucontext: `makecontext` only accepts `int`-sized
arguments, so the coroutine handle pointer is split into two
`unsigned int` halves (high/low) and reassembled inside the
trampoline. This is the standard portable workaround on 64-bit
platforms.

## Why this exists separately from 102

Issue 102 commits to *exactly two* pthreads with a clear data
boundary. The argument for the two-thread design is that game state
is owned by one thread and the rendering-thread reads only a
snapshot; introducing more threads would require either re-locking
game state or replicating snapshots.

A coroutine pool is the right tool when many tasks need to share a
small thread budget without per-task pthreads. Concrete fits inside
this project would be:

- Parallel per-tick subsystems inside the sim thread (LOS checks,
  projectile integration, AI evaluation) — but only if profiling
  shows the sim thread is CPU-bound.
- A future asset/audio loader that wants to overlap I/O with sim work
  without dedicating a permanent thread to each loader.

Adopting it for any of those is a *separate* design decision,
deserving its own issue. This issue only delivers the library.

## Related documents

- `docs/003-tech-stack.md` — pthreads is the threading primitive of
  record; this library is built on top of it, not in place of it.
- `docs/004-architecture.md` — current two-thread design.
- `issues/102-threading-model.md` — the issue that lands the two
  pthreads this library would, in some hypothetical future, multiplex.

## Notes

`ucontext.h` is marked obsolete in POSIX 2008 but remains present
and functional on glibc/Linux, which is the project's target. If the
project ever needs to run elsewhere, the stack-switch primitive
becomes the only file that needs replacing — the queue, scheduler
loop, and public API stay the same. That is part of the reason the
stack-switch happens in exactly one function.

A future enhancement could replace the single-mutex FIFO with a
per-worker runqueue plus work stealing, which is what Go's runtime
and Tokio's multi-thread executor do. The single queue is the
simplest version that demonstrates the model and is sufficient until
profiling justifies the more complex design.

## Deprecation candidates

- `tmp/test-coroutine-pool.c` — the smoke test used to validate the
  initial implementation (5 coroutines × 3 yields → 15 ticks, exit 0
  under `-Wall -Wextra -Wpedantic`). Removed during this issue (no
  longer present in the working tree).
- `tmp/test-task-pool.c` — the second-generation combined smoke test
  for the action-array design. Superseded by the per-behavior test
  files in `tests/` (see "Permanent test layout" section below).
  Removed during this issue.

---

## Design evolution

This issue's title and original "Intended behavior" describe a
*coroutine* pool. The library that actually shipped under
`libs/900-task-pool.*` is structurally different — an action-array
task pool with a dependency-driven waiting queue. Per the
append-only rule, the original direction is preserved above; this
section records why the design changed and what each iteration
contributed.

### Iteration 1 — coroutines on pthreads (built, then replaced)

A direct M:N coroutine scheduler. Each task was a single
`void(*)(void*)` running on its own `ucontext_t` stack. `co_yield`
called `swapcontext` to suspend, returning control to the worker;
the worker re-queued the coroutine. `co_join` blocked until the
coroutine returned.

Components: `cpool_t` (pool struct), `co_t` (coroutine handle),
shared FIFO ready queue, per-coroutine 64KB stack, trampoline that
reassembled a 64-bit pointer from two `int`-halves (the standard
`makecontext` workaround), join handshake using a `finished` flag
plus a per-coroutine condvar.

Why it was replaced: review surfaced three classes of complexity that
the project did not actually need.

1. The `swapcontext` machinery — saving and restoring a full CPU
   register frame plus a private stack — exists *exclusively* to
   support pausing mid-function. The project's concrete needs (a
   thread pool for fan-out work in the sim tick) do not require
   pausing mid-function; they require running tasks to completion.
2. The trampoline's pointer-splitting trick is only necessary
   because `makecontext` accepts `int`-sized varargs. Without
   `makecontext`, the trick is unnecessary.
3. The `finished`-flag join handshake exists because the worker is
   running on the coroutine's *own stack* via `swapcontext`; freeing
   the coroutine struct (which owns the stack) too eagerly would
   corrupt the worker. Plain function calls run on the worker's own
   pthread stack; the handshake collapses to "set DONE flag, signal
   condvar."

### Iteration 2 — plain task pool with continuation-passing (designed, not built)

A worker pops tasks of type `void *(*)(task_id_t self, void *arg)`
and runs them to completion. To express "wait for another task,"
callers split their function at the wait point: the second half
becomes a separate task spawned with the awaited GUID as a
dependency (`pool_spawn_after`). Continuations are written by hand;
the scheduler enforces that a dependent task does not enter the
ready queue until all its dependencies are DONE.

Components: GUID registry (`uint64_t` IDs from an atomic counter,
open-addressed hashmap), per-task atomic refcount, ten priority
queues with the ordering pattern `1; 1,2; 1,2,3; ...; 1..10` so
high-priority tasks dominate without starving low-priority ones,
waiting queue for tasks whose dependencies are unmet, scanner task
that promotes ready waiters when any dep completes.

Why it was replaced: the manual continuation pattern requires the
caller to package locals into a struct, write a second function, and
remember to spawn it with the right deps. Each split point is a new
function definition. For game-action sequences that naturally split
into many small steps (create projectile → orient → show → launch →
schedule arc update), this is more verbose than the work warrants.

### Iteration 3 — action-array tasks (built, shipped)

A task body is a flat array of atomic action functions. Each action
returns one of `ACT_ADVANCE` (next index), `ACT_JUMP` (to a named
index), `ACT_BLOCK` (suspend on a GUID, resume at the same index),
`ACT_DONE` (skip remaining actions). The "resume point" is a single
`unsigned int` (`current_index`), trivially serializable, naturally
re-enterable. Per-action args live in a parallel array set at spawn;
per-action results live in a separate write-once result-slots array.
Block-and-resume is the natural two-action pattern: `[spawn_subtask,
check_or_block]`.

The action-array design also unifies "up-front dependencies" and
"mid-task BLOCK" into a single `wait_set` field on the task. The
scanner only knows about `wait_set`; whichever code path populated
it is irrelevant.

Why this iteration shipped:

1. Flat, inspectable task bodies (an array of function pointers is
   loggable, replayable, debug-printable in one line).
2. No re-execution waste: the resume index points exactly where the
   task left off.
3. No coroutine machinery: no per-task stacks, no register-save, no
   trampoline. Standard C function calls only.
4. No new mechanisms beyond what the task pool already needed —
   matches the user's stated preference for "force ourselves to use
   fewer mechanics."
5. Self-rescheduling pattern (a task's last action enqueues a fresh
   copy of itself) becomes a one-line idiom for per-frame update
   loops without holding a worker hostage.

## Final delivered design

The library is at `libs/900-task-pool.{h,c,info.md}`. Major
components:

- **GUID registry**: `uint64_t` IDs from an atomic counter, looked
  up via an open-addressed hashmap keyed on `id & (capacity-1)`.
  Each entry is a `task_t *` with refcount.
- **Refcounting**: every `task_t` carries an atomic refcount. The
  pool registry holds one reference; each external `pool_ref`
  bumps; `pool_unref` drops. Free at zero.
- **Action-array execution**: `task->actions[]` of length
  `n_actions`, parallel `task->action_args[]` for per-action inputs,
  parallel `task->result_slots[]` for per-action outputs. Each slot
  is write-once by convention (the action whose index it is).
- **Priority queues**: ten FIFOs, indexed 1..10 (1 highest). Pool
  maintains a `(level, step)` cycler implementing the
  `1; 1,2; 1,2,3; ...; 1..10; 1,2; ...` pattern. Empty queues at the
  current step are skipped; the cycler still advances.
- **Waiting queue**: one shared list of tasks whose `wait_set` has
  unmet dependencies. Counter tracks size for O(1) "is it
  non-empty" checks on the worker's hot path.
- **Scanner**: spawned as a regular pool task at priority 1 when a
  worker finishes a task and the waiting queue is non-empty. A
  single boolean `scanner_running` (guarded by the waiting-queue
  mutex) prevents redundant scanner spawns. The known race where a
  completion happens between the scanner's last check and the flag
  clear is documented in-source as acceptable: the affected waiter
  stalls only until the next task completion in a busy pool, and a
  fully-quiescent pool with a still-blocked waiter is a sign of a
  missing dependency rather than a scanner bug.
- **Block-and-resume**: an action returning `ACT_BLOCK` causes the
  worker to set `wait_set = [block_on]`, move the task to the
  waiting queue, and trigger the same scanner-spawn check that task
  completion does. When eventually promoted back to ready, the same
  action runs again — typically a "check and advance if ready" idiom.

## Asymptotic notes (for future revisits)

- Scanner iteration is `O(N_waiting × deps_per_task)` per run.
  Acceptable for the project's expected scale (tens of waiting
  tasks). The upgrade path is event-driven dependency promotion
  (each task notifies its dependents on DONE), used by every real
  scheduler at scale.
- Hashmap is open-addressed with linear probing and tombstone-on-
  delete. Long-running pools that churn through millions of tasks
  would need a periodic compaction or chained buckets. Not built;
  noted in the source.
- Single mutex on each queue. Fine until contention measurement
  shows otherwise; per-worker queues with stealing is the upgrade.

## Addendum 2026-04-28: priority demotion on block (iteration 4 design pending)

This is the section issue 107's "Addendum (2026-04-28)" forward-
references. Agreed scope as of session-end 2026-04-28; not yet
written into the "Design evolution" section above as a proper
"Iteration 4" subsection, and not yet implemented in
`libs/900-task-pool.{c,h}`. Resume work from this document next
session.

### What's changing

1. **Remove the waiting queue, the scanner task, and the
   `scanner_running` flag entirely.** ~60-80 lines of code
   disappear from `900-task-pool.c`.
2. **`ACT_BLOCK` no longer routes to a waiting queue.** Instead,
   the worker re-pushes the task onto the ready queue at
   `min(N_PRIORITIES, current_priority + 1)`. Sticky cap at the
   bottom level — once at priority 10 it stays there until the
   action returns `ACT_ADVANCE` (no more BLOCK on this iteration).
3. **`pool_spawn_after` stays as a public API.** Implementation
   becomes option (c) from the design discussion: it prepends a
   synthetic "check deps[] or ACT_BLOCK on first unmet" action to
   the user's actions array. No special-case waiting-queue
   plumbing remains.
4. **New optional flag on `pool_spawn`: `promote_if_late`**
   (default false). When set, the rescheduling action of a
   self-rescheduling periodic compares wall-time gap since the
   previous iteration to the gap "expected" for that priority
   level (derivable from cycler period and N_PRIORITIES). If
   actual > expected, the next spawn goes at
   `max(1, current_priority - 1)`. Sticky promotion (no
   auto-demote on time, only on `ACT_BLOCK`). The task stores
   its own arrival timestamps in `result_slots` so the comparison
   is local; no library bookkeeping needed.

### Why

- Demote-on-block + the cycler removes the need for a separate
  "wait without polling" mechanism. The polling cost at priority
  10 is bounded by the cycler period (one check every ~54 cycler
  steps in a busy pool). The pathological case is "single waiter,
  empty pool" → tight loop on one core; mitigation if it ever
  bites is a brief `nanosleep` on priority-10 BLOCK retries.
- Auto-promote and demote-on-block are symmetric forces. Together
  they give priority a richer meaning: "how often I want to run,"
  with the scheduler self-adjusting under load.
- The scanner's documented race (completion between scanner's
  last check and `scanner_running = false`) disappears because
  the mechanism it implemented disappears.
- One queue (ready) instead of two (ready + waiting). Single
  mutex hot path. Easier to reason about.

### Origin (correction to earlier framing)

The scanner is from iteration 2 (continuation-passing), not
iteration 1 (coroutines). Coroutines used `swapcontext`-based
yielding directly — no scanner needed. The scanner appeared in
iteration 2 specifically to handle `pool_spawn_after`'s declared
dependencies. Iteration 3 (action-array) reused it for mid-task
`ACT_BLOCK` as a free piggyback. Iteration 4 reverses that:
`ACT_BLOCK` gets its own simpler mechanism, and
`pool_spawn_after` rides on top of `ACT_BLOCK` rather than the
scanner.

### Known property to flag in the writeup

If many periodics auto-promote simultaneously (heavy load →
everything is late), they all converge toward priority 1 and
could crowd out tasks that genuinely deserve priority 1. Two
mitigations available; default is "trust the convergence":
- Cap auto-promotion at priority 2 (never elbow projectiles).
- Trust convergence: if many things are late, they all need to
  run sooner; this is the right behavior.

### Resume next session

Pick up from: "Want me to write iteration 4 into issue 114 with
this scope?" Next steps in order:

1. Promote this section into a proper "Iteration 4" subsection
   under "Design evolution" above, mirroring the structure of
   iterations 1-3 (Components / Why / What's gained).
2. Update `libs/900-task-pool.{c,h}` to implement the change:
   - Delete waiting-queue fields, scanner_running, scanner_action,
     maybe_spawn_scanner, scanner-spawn calls in run_task and
     pool_spawn.
   - Update worker's ACT_BLOCK handler to re-push at higher
     priority instead of moving to waiting queue.
   - Add `promote_if_late` field to task_t and to pool_spawn
     signature; add the timestamp logic to the reschedule path.
   - Update pool_spawn_after to inject the synthetic check-deps
     action.
3. Update `tests/003-task-pool-mid-task-block.c` to verify
   priority demotion on retry (currently asserts the block-action
   ran exactly twice — that still holds, but a stronger version
   would also assert the second run happened at a higher priority
   number).
4. Add `tests/007-task-pool-promote-if-late.c` for the new
   auto-promote behavior.
5. Update `tests/000-index.md` blind-spot list (remove "scanner
   race" entry; add "auto-promote + auto-demote convergence
   under heavy load" if appropriate).
6. Append iteration 4 to the "Design evolution" section. Move
   this "Pending" section's content into it. Delete this
   "Pending" section.
7. Verify no other docs reference the waiting queue / scanner by
   name (grep).

## Permanent test layout

Tests live in `tests/` (a permanent directory, not `tmp/`) per
project convention. Each file is a standalone C program named
`{INDEX}-{LIBRARY-OR-MODULE}-{BEHAVIOR}.c` so the directory listing
itself documents what is and isn't covered. The runner is
`tests/run-all.sh`. The current files (post initial implementation
of this issue):

| File                                          | Behavior                                                                |
|-----------------------------------------------|-------------------------------------------------------------------------|
| `tests/000-index.md`                          | Test index + explicit "blind spots" list of behaviors with no coverage. |
| `tests/001-task-pool-sequential-actions.c`    | N-action task runs all actions in order, args routed correctly.         |
| `tests/002-task-pool-spawn-time-deps.c`       | `pool_spawn` with `deps[]` defers task until all deps DONE.             |
| `tests/003-task-pool-mid-task-block.c`        | `ACT_BLOCK` suspends and resumes at the same `current_index`.           |
| `tests/004-task-pool-self-rescheduling.c`     | Self-rescheduling pattern reaches its termination condition.            |
| `tests/005-task-pool-priority-cycler.c`       | High-priority tasks complete sooner on average than low-priority.       |
| `tests/006-task-pool-result-slots.c`          | Write-once result slots readable both by next action and externally.    |

Known blind spots are tracked in `tests/000-index.md`. When a new
behavior gets exercised by a real caller, a new test goes in
`tests/` and the corresponding entry comes off the blind-spots
list.

## Bugs found and fixed during initial implementation

Worth recording so the same trap doesn't get re-laid:

- **Cycler attempt count was too low.** First implementation of
  `ready_pop_locked` only attempted `N_PRIORITIES = 10` cycler
  steps before giving up. But the cycler's full period is
  `sum(k=2..N) = 54` for N=10 — within 10 steps the cycler can fail
  to consult several priority queues, and a task pinned at a
  high-priority-number queue can be stranded indefinitely even
  though `n_ready > 0`. Test 004 (self-rescheduling at priority 5)
  caught this immediately: iteration 7 was spawned but never picked
  up. Fix was a one-line constant change to use the full cycler
  period as the attempt count, with a comment explaining the
  derivation. Source comment is at the relevant
  `#define CYCLER_PERIOD_STEPS` in `libs/900-task-pool.c`.

## Addendum (2026-04-28): priority demotion on block

A behavior change to `worker_main`'s `ACT_BLOCK` handler, motivated
by a design conversation with the user. Captured here so the
rationale lives with the pool's design history.

### Today

When an action returns `ACT_BLOCK` with a `block_on` GUID, the
worker re-queues the task at the **same priority** it was running
at, into the waiting queue, where the scanner promotes it back to
the ready queue once the blocked-on task reaches DONE.

### Proposed

Demote the task by one priority level (toward higher-numbered, less
urgent) on each `ACT_BLOCK`. Restore the original priority when an
action completes without blocking. The task's spawn-time priority
is the floor it returns to; demotion only ever pushes lower.

Rationale, in the user's words: "if you're just going to be
waiting, why bother coming back fast? Better to just get it done
next." A task that keeps blocking is a task that's bottlenecked on
something else; pushing it down clears the way for fresh work that
isn't waiting on anything.

The lazy-chain property: a task that blocks twice ends up at +2
priority. Long dependency chains naturally drift toward the bottom
of the cycler's attention without anyone explicitly modeling
backpressure.

### Bound, so a hot task can't drift forever

Demotion **resets to spawn-time priority** the moment an action
returns `ACT_ADVANCE` (i.e. the task did real work without
blocking). This means a task whose typical pattern is "block once,
do a thing, block once, do a thing" oscillates between its
spawn-time priority and spawn-time + 1, never accumulating.

A task that blocks five times in a row before doing anything
useful drifts to spawn + 5 — exactly the right place for it.

### Implementation sketch

A new field `priority_floor` on the task (= spawn-time priority).
The live `priority` field becomes mutable. ACT_BLOCK does
`priority = min(10, priority + 1)`. ACT_ADVANCE does
`priority = priority_floor`. ACT_JUMP and ACT_DONE leave it alone
(JUMP isn't blocking; DONE is terminating).

A test belongs under `tests/` once this lands —
`007-task-pool-block-demotes-priority.c` or similar.

## Addendum (2026-04-28): timestamp-based motion (adoption pattern)

Not a library change — a **caller pattern** that pairs naturally
with priority-demotion. Recorded here because it's the reason
demotion is safe for movement.

A unit that walks toward a target stores a `last_update_t`
timestamp on the unit struct. The movement task computes
`elapsed = now - u->last_update_t` at the top of its action chain,
advances by `speed * elapsed`, then writes `now` back. If the
task gets demoted to priority 10 and runs every fifth tick instead
of every tick, the unit walks the same total distance — just in
chunkier steps.

Render reads `u->position` either raw (slightly stale: "as of last
update") or extrapolated for sub-task smoothness:
`render_pos = u->position + heading * speed * cos²(err) * (render_now - last_update_t)`.

Both ideas — demotion + timestamp motion — go in together when
107's re-open transitions movement to the pool. See 107's "Shape
B" section for the action chain that consumes them.
