# pool.h / pool.c — public surface

The **engine's only threads**: N workers pulling tasks off one FIFO queue. Every
SoraMech box runs here as a task; a box re-arming (the frame-clock, an iterator)
is a task spawning itself. FFI-irrelevant — this is pure C the rest of the C
engine links against directly.

Modelled on SoraMech's `libs/task-pool/pool.c`, kept lean: no per-worker
language-spec init/teardown (our boxes are plain C), no priority queue (plain
FIFO), tuned for a game that never quiesces.

## Types

- `pool_t` — opaque pool handle.
- `pool_task_t` — `void (*)(void *arg)`. One function, one argument, no return.

## Lifecycle

- `pool_t *pool_create(int n_workers)` — spawn workers, live immediately (no init
  barrier). `n_workers <= 0` → online CPU count, capped at `POOL_MAX_WORKERS`
  (16). NULL on allocation / pthread failure.
- `void pool_destroy(pool_t *p)` — stop accepting work, wake and join every
  worker, free queued-but-unrun tasks, free the pool. Safe on NULL.
- `int pool_n_workers(const pool_t *p)` — worker count (0 for NULL).

## Submission and wait

- `void pool_spawn(pool_t *p, pool_task_t fn, void *arg)` — queue a task. Safe
  from any thread, **including from inside a running task** — that is how a box
  re-arms itself and how an iterator re-spawns.
- `void pool_wait_quiescent(pool_t *p)` — block until the in-flight count hits
  zero. For setup/teardown and tests. **A running game never calls this** — the
  live frame-clock keeps the count above zero; the game runs until a quit signal
  triggers `pool_destroy`.

## Concurrency model

- Two non-nesting locks: `q_mtx` guards the queue + shutdown flag; `act_mtx`
  guards the in-flight tally + the quiescence wait. No lock-ordering to reason
  about.
- The in-flight tally is incremented at `pool_spawn` (before the task can run) so
  a quiescence waiter never sees a false zero between enqueue and execution.

## Test

- `pool-test.c` — the regression prover: fan-out exactness (every task runs
  once), self-spawn (a task re-arms itself exactly N times — the heartbeat /
  iterator shape), and nested spawn (children spawned from inside a task). Build
  with `-std=c11 -pthread`; exit 0 = pass.

## Related

- `libs/engine-core/slot.{c,h}` — the slots tasks read and write through.
- `docs/soramech-notes.md` — pattern 6 (frame-clock heartbeat), pattern 7 (the
  render thread, the one thread NOT in this pool).
- Issue `101` — the architecture this pool serves.
