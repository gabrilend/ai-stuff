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
