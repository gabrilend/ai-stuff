# 110 — Shift-Chained Waypoint Orders

## Status

TODO

## Current behavior

Right-click with shift behaves the same as without — the order is
replaced. There is no notion of a chain of waypoints.

## Intended behavior

Each press-then-hold of the shift key opens a *chain id*. While that
chain id is open, every right-click *appends* a waypoint to the chain
for selected units. Releasing shift closes the chain. Pressing shift
again opens a new chain id.

A right-click without shift held (or after shift was released) replaces
all orders with a single waypoint, as in issue 109.

Behavior summary:

- shift-down → open chain id N.
- right-click while N is open → append waypoint to chain N for all
  selected units.
- shift-up → close N. Subsequent right-click without shift replaces
  orders.
- shift-down again → open chain id N+1.

Chain splitting between selected units (the half-and-half rule) belongs
to issue 118 and is deliberately deferred — this issue keeps the rule
"all selected units share the same chain."

## Suggested implementation steps

1. Track shift state on the main thread. When shift transitions
   `up→down`, allocate the next chain id (monotonic counter). When
   `down→up`, mark that id as closed.
2. On right-click:
   - If shift is open with chain id `cid`: emit
     `MOVE_ORDER_APPEND(cid, world_x, world_y)`.
   - If shift is closed: emit `MOVE_ORDER_REPLACE(world_x, world_y)`.
3. In sim, `MOVE_ORDER_APPEND(cid, …)`:
   - For each selected unit, append a waypoint to its chain.
   - The unit walks the chain head-to-tail.
4. The existing replacement event still clears the chain.
5. Render order chains for selected units as faint lines on the ground
   between waypoints, so the user can see the plan.

## Related documents

- `docs/002-mechanics.md` — chain rules.
- Issue 118 — the split-on-new-chain rule comes later.

## Notes

The chain id is a hand-off token between threads, not a real entity in
the game state. Once the sim has consumed the appends for a chain id,
the id can be forgotten. Keep this pure: do not persist chain ids in
unit state — store only the resulting waypoint list.
