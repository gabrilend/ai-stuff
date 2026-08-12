# 301 — In-memory map representation

## Current behavior

Phase 2 left the kernel with a thread pool, a queue, a slot store
primitive, and the gathering function — but no shape for what a
*loaded map* looks like in memory. The torture test from 211 used
the threading core directly with hand-wired box instances.
Anything more structured needs a real data model.

## Intended behavior

A `map_t` holds everything the runtime needs to know about one
running map:

```c
typedef struct {
    const char       *name;
    box_instance_t   *instances;     // every box in this map
    int               n_instances;
    slot_store_t     *slots;         // per-port slots for this map
    gathering_t      *gatherings;    // one per box instance
    box_instance_t  **entry_boxes;   // read boxes the runner kicks
    int               n_entry_boxes;
    transcript_ring_t *transcript;   // from 310, optional pointer
} map_t;
```

A `box_instance_t` carries one box's per-map state — the
descriptor pointer (from 208's table), the slot indices this
instance owns, and per-routing-kind state (the iterator's
counter, the distributor's history, the nonlinearity's value
ring). Two appearances of the same box descriptor in two maps
each have their own box_instance.

A `slot_store_t` is the run of slot structures the map owns. Each
input port on each box_instance maps to one slot inside the
store. The store's storage comes from 108's heap allocator at map
load time.

## Suggested implementation steps

1. `struct map_t` field set.
2. `struct box_instance_t` field set.
3. `struct slot_store_t` field set.
4. `map_alloc(name, descriptor_count)` — allocate from 108.
5. `map_free(map_t *)` — release every allocation back to the
   heap.

## Related documents

- `docs/012-soramech-runtime.md`.

## Blocked by

108, 205 (slot store primitives), 208 (descriptor table).

## Blocks

303, every later phase 3 issue.
