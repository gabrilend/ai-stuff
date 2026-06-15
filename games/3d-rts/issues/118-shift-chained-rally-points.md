# 118 — Shift-Chained Rally Points

## Status

TODO

## Current behavior

A factory has exactly one rally point (from issue 117). All produced
units take the same single waypoint.

## Intended behavior

Holding shift while right-clicking on the terrain — with a factory
selected for rally-edit — *appends* a new rally chain to the factory.
Each shift-press-then-hold opens a new rally chain id; subsequent
right-clicks while held append waypoints to that chain. Releasing
shift closes the chain.

A right-click on the terrain *without* shift held while in rally-edit
behaves exactly like the unit single-order replace: it erases all
existing rally chains and sets a single chain with one waypoint.

When the factory produces a unit, it picks the *next* chain in
round-robin order. Counter increments per produced unit; wraps around
when it hits the chain count. **Strict rotation, not shuffle.**

## Suggested implementation steps

1. Extend `Factory.rally_chain` (single) to `rally_chains` (array of
   chains, fixed-capacity from config), plus a `next_chain_index` int.
2. Reuse the chain-id mechanism from issue 110 — emit
   `RALLY_CHAIN_APPEND(cid, x, y)` with shift held, and
   `RALLY_CHAIN_REPLACE(x, y)` without.
3. On `RALLY_CHAIN_REPLACE`, clear all chains and set
   `rally_chains[0]` to a single-waypoint chain.
4. On `RALLY_CHAIN_APPEND` for a new cid not yet seen by this factory,
   append a new empty chain and add the waypoint. For an open cid
   already seen, append the waypoint to that chain.
5. On factory production, pick chain `next_chain_index`, increment and
   wrap. Set the new unit's order chain to a copy of the rally chain.
6. Render all chains for a selected factory, each with a slightly
   different color so the user can see the rotation pattern.

## Related documents

- `docs/002-mechanics.md` — round-robin rule.
- Issue 110 — the chain-id pattern this reuses.

## Notes

The vision is explicit: "every other unit will go down a different
chain until the last one has been picked - then it will restart from
the top. They won't be shuffled." Shuffling is *forbidden*, not just
not-required. Keep the rotation deterministic and observable.

## Task pool integration

**Recommended priority: 3** — same input-handler priority as
issues 109, 110, 117. Each `RALLY_CHAIN_APPEND(cid, x, y)` and
`RALLY_CHAIN_REPLACE(x, y)` event spawns a one-shot task.

```
rally_chain_append_task_actions = [
    [0] find_or_open_chain_for_cid
    [1] append_waypoint_to_that_chain
]

rally_chain_replace_task_actions = [
    [0] clear_all_factory_chains
    [1] set_rally_chains_zero_to_single_waypoint
    [2] reset_next_chain_index
]
```

The round-robin rotation lookup happens inside the factory's
production task (issue 116, priority 5) when it spawns a new
unit; not a new task type, just a field read.

The per-chain rendering of multiple chains in distinct colors is
purely a snapshot-data concern: the chains' waypoint lists are
already in the snapshot from the actions above, so the renderer
walks them on the main thread with no task-pool involvement.
