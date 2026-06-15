# 119 — Selected-Unit Chain Splitting

## Status

TODO

## Current behavior

When the user opens a new shift chain (issue 110), every selected unit
takes that same chain. There is no division of the selection.

## Intended behavior

When a *new* shift chain begins (i.e. a new shift-press-then-hold
opens a fresh chain id) for a multi-unit selection, the selection is
split:

- The first half of the (currently selected) units keep walking the
  *previous* chain.
- The second half take the *new* chain — the one being built by
  appends with this fresh chain id.

Each subsequent new chain id splits *the most recent half* in half
again. The split is by stable index in the selection (e.g. unit ids
sorted ascending), not by position or random.

Concretely, with selection `[A, B, C, D, E, F, G, H]`:

- Open chain 1: `A..H` go to chain 1.
- Open chain 2 (still all 8 selected): `A..D` keep chain 1, `E..H`
  take chain 2.
- Open chain 3: `E..F` keep chain 2, `G..H` take chain 3.

The selected set itself does not change — only the assignment of which
units take which chain changes.

## Suggested implementation steps

1. Track the "active chain id" and an "assignable unit set" on the
   main thread. When a fresh chain id opens, halve the assignable set
   (keep the first half assigned to the previous chain id; the second
   half becomes the new assignable set).
2. Emit `MOVE_ORDER_APPEND(cid, x, y)` events that include the
   *assignable* unit ids for that chain, not the full selection.
3. In sim, append waypoints to only those units' order chains.
4. The previous chain id's units are unaffected after the split — they
   keep whatever chain they had.
5. Render the chains in distinct colors so the user can see which
   units received which chain.

## Related documents

- `docs/002-mechanics.md` — split rule.
- Issue 110 — the chain-id mechanism.

## Notes

A subtle case: if the selection has an odd count, halve as
`first = ceil(n/2)`, `second = floor(n/2)`. The vision does not
specify; this convention keeps the *previous* chain group at least as
large as the new one, which feels right for incremental fan-out. Call
this out in a comment so a future reader does not silently change it.

## Task pool integration

**Recommended priority: 3** — input-handler class. The actual
splitting logic happens on the main thread (it's pure
bookkeeping over the selection set + chain ids; no game state
involved). What lands in the task pool is the per-event
`MOVE_ORDER_APPEND(cid, x, y, [unit_ids])` work, which is just
issue 110's task with an explicit unit-id list instead of "all
selected."

```
move_order_append_subset_task_actions = [
    [0] iterate_provided_unit_id_list_only
    [1] append_waypoint_to_each
]
```

The split is invisible to the task pool — by the time an append
event reaches the sim, it already carries the correct subset of
unit ids. The pool just runs the append against the listed
units, regardless of how the main thread arrived at that subset.

Rendering chains in distinct colors per group is again a pure
snapshot-data concern; no task-pool involvement.
