# 124 — Task pool: stable-index task storage (iter5)

## Status

**Exploratory — not committed work.** Captured during the iter4
design conversation (2026-04-28) as one possible refactor of task
storage. As of 2026-04-29 the user has explicitly pushed back on
pre-planning this: whether to actually do it should be decided
based on a concrete need, not as part of a multi-iteration roadmap.

Possible drivers if it ever becomes real work:
- Cheap iteration over live tasks (registry walk + tombstone skip
  is replaced by a dense `for i in 0..n_live` loop).
- Removing the tombstone accumulation in the open-addressed hash.

For now: not blocked, not committed, not next.

## Why this exists separately

The iter4 conversation went through several variants of "use indices
instead of pointers" — full slab allocator, chunked layout,
swap-with-last, and finally the variant captured here: stable
indices via a free list, with priority queues storing those indices
rather than task pointers. Iter4 does not depend on it; iter4 just
swaps the queue data structure to arrays-of-pointers and keeps the
pointer-based registry. This issue is the consistency follow-up.

## Current behavior (post-iter4)

- Tasks are individually `calloc`'d on `pool_spawn`.
- The registry is an open-addressed hash table:
  `task_t *table[REGISTRY_CAPACITY]` keyed on `id & MASK`.
- On free, the slot is marked with a `TOMBSTONE` sentinel so that
  later lookups for unrelated ids that collided into the same probe
  chain still find their target.
- Live tasks are not enumerable cheaply — iterating live tasks
  requires walking all 4096 registry slots and skipping NULL and
  TOMBSTONE entries.
- Priority queues hold `task_t *` pointers. Each task carries a
  `queue_position` int for O(1) splice via swap-with-last in its
  current priority's array.

## Intended behavior

- Tasks are still individually heap-allocated. The pool gains a
  dense pointer array `task_t **task_ptrs` with `n_tasks`
  (live count) and `cap_tasks` (allocated capacity).
- A free-list `int free_slots[]` tracks unused indices in
  `task_ptrs`. Allocate: pop a slot off the free list (or grow
  the array if empty), store the new task pointer there. Free:
  push the slot onto the free list, leave the array entry
  unused.
- **Slot indices are stable** for a task's entire lifetime. Other
  tasks being freed does not change my index.
- The registry maps `id → int slot_index` instead of `id → task_t *`.
  Lookup is `task_ptrs[registry[id]]` — two reads instead of one,
  but the indirection is cheap (the pointer array stays hot).
- Priority queues store `int slot_index` instead of `task_t *`.
  Promotion/demotion moves an integer between arrays.
- Live-task enumeration is `for (int i = 0; i < cap_tasks; i++) if (task_ptrs[i]) ...` — an order-of-magnitude faster than walking the registry hash.

## Why stable, not swap-with-last

Earlier in the design conversation, swap-with-last (compact the dense
list on every removal) was proposed. Stable-indices won out because:

1. Priority queues hold slot indices. Swap-with-last in the dense
   list would invalidate every queue entry pointing at the moved
   slot, requiring fix-up walks.
2. The cost of holes in the dense list is small — capacity grows
   slowly and never shrinks; iteration with NULL skips is still
   far faster than the hash walk it replaces.
3. Stability removes a class of bugs ("I held a slot index across
   a critical section and something else got freed").

## Suggested implementation steps

1. Add to `task_pool_t`:
   - `task_t **task_ptrs;`
   - `int n_tasks_alloc;` (capacity of the array)
   - `int *free_slots; int n_free; int cap_free;`
2. Replace the registry's value type from `task_t *` to `int`.
   Update `registry_insert`, `registry_lookup`, `registry_remove`.
   The TOMBSTONE sentinel needs reworking — likely an int value
   like `-2` to distinguish from "empty" (`-1`) and live indices.
3. Replace `pool_spawn`'s `calloc` + registry insert with: malloc
   the task, allocate a slot from the free list (growing
   `task_ptrs` if needed), store the pointer, insert
   `(id → slot)` into the registry.
4. Replace `task_free` callsites with: free the heap struct, push
   the slot onto the free list, clear `task_ptrs[slot] = NULL`.
5. Convert priority queue arrays from `task_t **` to `int *`. The
   per-task `queue_position` field stays an int. Worker
   resolves: `int slot = queues[p][i]; task_t *t = task_ptrs[slot];`.
6. Add a helper `task_t *task_get(task_pool_t *pool, task_id_t id)`
   that wraps the two-step lookup. Most internal callers use this.
7. Migrate every internal `task_t *` local that came from a
   registry lookup to use `task_get`. The sites are
   self-contained (one file).
8. Verify iter4's tests still pass; the public API is unchanged.

## What stays the same

- The public API (`pool_spawn`, `pool_result_slot`, `pool_is_done`,
  `pool_ref`, `pool_unref`) — all still take `task_id_t`.
- Action signatures (`task_ctx_t` unchanged).
- The behavioral changes from iter4 (single priority field,
  demote-on-block, promote-blocker, result_filled).

## Tests

- `tests/NN-task-pool-stable-indices.c` — spawn task A at slot S,
  spawn many other tasks, free a bunch of them, assert A's slot
  is still S.
- Existing iter4 tests should pass without modification.

## Out of scope

- Shrinking the dense array. Pool grows to high-water mark;
  shrinking adds copying or fragmentation handling that isn't
  worth it for a game process bounded by gameplay.
- Migrating the public API to expose slot indices. Slots stay
  internal; users still see GUIDs.

## Related

- `114-coroutine-pool-library.md` — iter4's locked scope; this is
  the iter5 follow-up.
