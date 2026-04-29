# 900-task-pool — external API

Action-array task pool: workers run tasks composed of small atomic
action functions, with priorities, parking-on-block, promote-on-
blocked-requester, and a write-once per-action result-slot table
(plus a parallel filled-bit array that distinguishes "not yet
written" from "written, value happens to be NULL"). Header in
`900-task-pool.h`, implementation in `900-task-pool.c`. Full design
rationale and the iteration history that produced this design
lives in `issues/completed/114-coroutine-pool-library.md`.

## Types

- `task_pool_t` — opaque pool handle.
- `task_id_t` — `uint64_t`, monotonically issued. `TASK_ID_NONE` (0)
  is the no-task sentinel.
- `task_ctx_t` — context passed to every action. Has `self_id`,
  `current_index`, `args`, `result_slots`, `n_slots`, `pool`,
  `jump_to`, `block_on`.
- `action_fn_t` — `typedef action_result_t (*)(task_ctx_t *)`.
- `action_result_t` — enum: `ACT_ADVANCE`, `ACT_JUMP`, `ACT_BLOCK`,
  `ACT_DONE`.
- `slot_status_t` — enum: `SLOT_FILLED`, `SLOT_PENDING`,
  `SLOT_OUT_OF_RANGE`, `SLOT_UNKNOWN_ID`.

## Functions

### `task_pool_t *pool_create(int n_workers)`
- **Inputs:** number of pthreads to spawn (≥ 1).
- **Returns:** owning pool, or NULL on bad arg / allocation failure.
- **Notes:** workers start immediately and block on the empty
  ready queues until something is spawned.

### `void pool_destroy(task_pool_t *pool)`
- **Inputs:** pool from `pool_create`.
- **Caller obligation:** drain the pool of tasks you care about
  before calling. Tasks remaining in any queue are leaked
  (intentional).

### `task_id_t pool_spawn(task_pool_t *pool, const action_fn_t *actions, void *const *action_args, int n_actions, int priority)`
- **Inputs:**
  - `actions[n_actions]` — array of action functions, copied.
  - `action_args[n_actions]` — parallel args array, copied. NULL is
    accepted (means no per-action args).
  - `priority` — clamped to `[1, 10]`. 1 = highest, 10 = lowest.
- **Returns:** task GUID, or `TASK_ID_NONE` on error.
- **Notes:** the pool holds one reference. To keep the task alive
  past natural completion (e.g., to read result slots), call
  `pool_ref` before completion.
- **Iter4 change:** there is no `deps` parameter. Cross-task waits
  are user-driven via `pool_result_slot` reads inside actions, paired
  with `ACT_BLOCK` returns.

### `void pool_ref(task_pool_t *pool, task_id_t id)`
- Bump the refcount. No-op if `id` is unknown.

### `void pool_unref(task_pool_t *pool, task_id_t id)`
- Drop a refcount. Last drop frees the task and removes it from
  the registry. No-op if `id` is unknown.

### `slot_status_t pool_result_slot(task_pool_t *pool, task_id_t id, int slot, void **out)`
- Read action `slot`'s output. On success (`SLOT_FILLED`) writes
  the value (which may itself be NULL) to `*out`.
- Returns `SLOT_PENDING` if action `slot` has not yet completed,
  `SLOT_OUT_OF_RANGE` if slot is outside `[0, n_actions)`, or
  `SLOT_UNKNOWN_ID` if `id` is not in the registry.
- Does NOT change refcount; caller must guarantee the task is
  still alive (via `pool_ref` or knowledge that the pool's own
  reference is still held).

### `int pool_is_done(task_pool_t *pool, task_id_t id)`
- Returns 1 if the task has reached DONE, 0 if still in some
  queue, -1 if `id` is unknown to the registry.

## Writing an action

An action is a function with this signature:

```c
action_result_t my_action(task_ctx_t *ctx);
```

It reads `ctx->args` for its inputs (= `action_args[current_index]`
from the spawn call), reads earlier actions' outputs from
`ctx->result_slots[k]` for `k < ctx->current_index`, optionally
writes its own output to `ctx->result_slots[ctx->current_index]`,
and returns one of:

- `ACT_ADVANCE` — most actions return this; runs the next action.
  The library marks `result_filled[current_index] = true`.
- `ACT_JUMP` — set `ctx->jump_to` to the index to run next. Library
  also marks the slot filled.
- `ACT_BLOCK` — "I can't progress now." Set `ctx->block_on` to
  the GUID of the task you're waiting on. The library parks your
  task on that task's waiters list (zero CPU until woken), and
  promotes the blocker by one priority level if it's in the
  ready queue. When the blocker reaches DONE, your task gets
  pushed back to the ready queue and this same action runs
  again. The slot is **not** marked filled. `block_on` is
  REQUIRED — the library aborts on `TASK_ID_NONE`, self-id, or
  an id missing from the registry.
- `ACT_DONE` — task is finished; remaining actions are skipped.
  Library marks the slot of the action that returned DONE as
  filled; later slots stay unfilled.

For cross-task value waits, the canonical pattern is:

```c
action_result_t my_action(task_ctx_t *ctx) {
    void *value = NULL;
    slot_status_t s = pool_result_slot(ctx->pool, OTHER_TASK_ID, k, &value);
    if (s == SLOT_PENDING) {
        ctx->block_on = OTHER_TASK_ID;
        return ACT_BLOCK;
    }
    // ... use value ...
    return ACT_ADVANCE;
}
```

## Linking

- Requires `-lpthread`.
- C11 (uses `<stdatomic.h>`).

## Known limitations / upgrade paths

- **Registry is open-addressed with linear probing and tombstones,
  fixed at 4096 slots.** Long-running pools that churn through
  millions of tasks would warrant chained buckets or periodic
  rebuild; this is asserted on, not handled. Issue 124 (iter5)
  replaces the registry with a stable-index dense pointer array.
- **Single mutex per queue group.** Per-worker queues with
  stealing would scale to higher core counts; not implemented.
- **No cancellation primitive.** A spawned task runs to completion
  (or until BLOCKed forever); there's no `pool_cancel(id)`.
- **No library-managed periodicity.** Self-rescheduling tasks
  re-spawn themselves manually. Issue 123 captures the planned
  frame-based periodics interface.
- **FIFO ordering within a single priority is not preserved.**
  Iter4's array-per-priority + swap-with-last design trades it
  away. Priority is the throttle; order within a priority is
  "whatever the swap shuffling produces."
- **`pool_spawn` does not abort on registry-full.** It calls
  `abort()` from `registry_insert` to avoid silent corruption;
  callers should ensure this never fires under normal load.
- **Wait cycles are not detected.** If A parks on B and B parks
  on A, both park forever. Callers must avoid cycles.
- **Hardening pass deferred (issue 125).** ACT_BLOCK with an
  invalid `block_on` already aborts; broader API hardening (enum
  return for unknown ids elsewhere, registry_lookup ownership,
  park-wrapper abstraction) is captured in 125 for a future
  pass.
