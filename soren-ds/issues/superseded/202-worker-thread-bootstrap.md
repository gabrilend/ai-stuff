# 202 — Worker thread bootstrap

## Current behavior

Every CPU core is awake (201), running its per-core setup, and
arriving at the same C entry function. None of those cores yet
knows what to *do* — they have stacks and they have a pointer to
kernel memory, but no loop they execute and no role they fill.

## Intended behavior

Each core becomes a *worker thread* with a numbered identity and
a defined main loop. The bootstrap:

- Allocates a per-worker context struct on the heap from 108.
  The context carries the worker's id (zero through N-1), a
  pointer to the worker's stack region, room for the
  currently-executing task pointer once 209's scheduling loop
  lands, and the worker's local random-number-generator state.
- Stores a pointer to that context in a per-core register the
  chip provides (the thread-pointer register on ARM, or
  equivalent).
- Calls the worker entry function with the context as its sole
  argument.
- The worker entry function, for phase 2's first cut, sits in a
  no-op loop reading and writing nothing. 209 replaces that loop
  with the real scheduling body.

The boot-time confirmation through 110 expands to report each
worker's context address alongside its core id.

## Suggested implementation steps

1. `struct worker_context` — id, stack base, task pointer slot,
   rng state.
2. `worker_bootstrap()` — alloc, populate, register, dispatch.
3. `worker_entry_stub()` — for-now no-op loop.
4. Call from 201's per-core path.

## Related documents

- `docs/003-threading-model.md`.

## Blocked by

108 (heap allocator), 201 (cores have to be awake first).

## Blocks

203, 209, 210, 211.
