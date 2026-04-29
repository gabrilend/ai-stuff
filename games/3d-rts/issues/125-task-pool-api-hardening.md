# 125 — Task pool: API hardening pass

## Status

**Future work.** Captured during the iter4 design conversation
(2026-04-28) and originally lived as an addendum at the bottom of
`114-coroutine-pool-library.md`. Split out before 114 moved to
`completed/` so the deferred work remains discoverable.

These changes tighten the public API to favor brutal-and-rigid
contracts over forgiving ones — the goal is to push mistakes into
fail-fast crash-time territory rather than letting them rot
silently. None of them change the library's core mechanics; they
sharpen edges.

ACT_BLOCK with an invalid `block_on` already aborts as of iter4.5.
That eats one suggestion from the original list. The rest follow.

## Suggestions, in implementation order

### 1. `pool_is_done` aborts on unknown id

Today an unknown id returns `-1`. Per the project rule "prefer
error messages and breaking functionality over fallbacks," that's
a fallback. An unknown id means the caller held a `task_id_t`
without a refcount on it — an invariant violation, not a runtime
condition to recover from.

Proposed: `pool_is_done` returns `bool` (or `int` 0/1 only). On
unknown id, log to stderr (id, calling thread, last-known
state if recoverable) and `abort()`.

Same treatment for `pool_ref` and `pool_unref` (today they're
no-ops on unknown id; they should abort).

`pool_result_slot` already returns `SLOT_UNKNOWN_ID` as a value.
The hardened version aborts in that branch instead of returning
the enum value.

Test: `tests/NN-task-pool-aborts-on-unknown-id.c` using fork +
WIFSIGNALED to check for SIGABRT.

### 2. Strict reference ownership — bump on get, drop on scope exit

Current model is permissive: callers manually `pool_ref` /
`pool_unref` and the discipline relies on convention. Easy to
forget.

Proposed contract:

- Every operation that hands a `task_id_t` to user code
  conceptually *gets a reference* and must bump the count.
- References cannot be silently copied. Sharing a `task_id_t`
  between two storage locations requires explicit `pool_ref`.
- A reference is unique to the data structure that owns it;
  freeing the structure unrefs.
- Tasks can be *moved* (transfer of ownership: source field
  cleared to `TASK_ID_NONE`, destination receives the live id
  with no count change) but not *cloned* without explicit
  `pool_ref`.

Approximations to enforce-by-construction in C:

1. Wrap `task_id_t` in a struct `{ task_id_t id; }` so it can't
   be passed to functions expecting raw `uint64_t` and so
   assignments look unusual.
2. Provide only `pool_take(handle*)` (move: zeros source) and
   `pool_clone(handle*)` (explicit ref-bump) operations on the
   wrapper.
3. Build a debug mode that, on every public entry, walks the
   registry and asserts every live id has a non-zero refcount
   from somewhere outside the pool's own bookkeeping.

C can't enforce this at compile time the way Rust can. The
realistic outcome is ~80% safety from the wrapper struct +
move/clone discipline, plus the debug audit pass.

### 3. `registry_lookup` stays private

It already is `static` in the .c, so this is mostly a documentation
constraint. Memorialize: external code only reaches task state
through narrowly-typed query functions (`pool_result_slot`,
`pool_is_done`, etc.); no public function returns a raw `task_t *`
or any pointer derived from `registry_lookup`.

### 4. Wrap park/unpark behind internal functions

Pthreads condvars are the right kernel-interface mechanism, but
the rest of the pool code shouldn't know that. Hide the primitive
behind two internal calls so the worker idle loop reads in the
pool's own vocabulary:

```c
static void pool_park_worker(task_pool_t *pool);
// Block until pool_wake_one_worker is called or shutdown is set.
// Caller must hold the ready-queue lock; this releases it on
// entry and re-acquires on wake.

static void pool_wake_one_worker(task_pool_t *pool);
// Wake exactly one parked worker, if any. No-op if none parked.
```

Worker idle loop becomes:

```c
while (!shutdown) {
    if ((t = ready_pop_locked(pool))) { run_task(pool, t); continue; }
    pool_park_worker(pool);
}
```

Underneath, today's implementation uses `pthread_cond_wait` /
`pthread_cond_signal`. If we ever swap to raw futexes (or a
userspace M:N scheduler), it's a contained change in one file —
the rest of the pool stays oblivious.

## Coupling

Suggestions 1 and 2 interact (the abort-on-unknown-id rule and
the ref-bump-on-get rule reinforce each other). Suggestion 4 is
independent of 1/2 and could land alone. Suggestion 3 is mostly
a documentation policy.

## Tests

- `tests/NN-task-pool-aborts-on-unknown-id.c` — fork + check for
  SIGABRT on `pool_is_done(garbage_id)`.
- `tests/NN-task-pool-handle-move-vs-clone.c` — exercises the
  wrapper struct, asserts move zeroes source and clone bumps
  refcount.

## Related

- `114-coroutine-pool-library.md` (in `issues/completed/`) — the
  iter4/iter4.5 history that produced the current API; this issue
  is the next pass over it.
- `124-task-pool-stable-indices.md` — independent refactor; could
  land before or after 125.
