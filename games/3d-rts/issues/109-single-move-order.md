# 109 — Right-Click Single Move Order

## Status

TODO

## Current behavior

Units only move via the temporary scatter key from issue 107. There is
no targeted movement.

## Intended behavior

With at least one unit selected and **shift not held**, right-clicking
on the terrain issues a movement order to every selected unit:

- Their existing order chain (if any) is *erased*.
- A new chain consisting of one waypoint at the picked terrain point
  is set.
- The unit immediately starts walking toward that waypoint.

The temporary scatter key from issue 107 is removed in this issue — the
real input is now in place.

## Suggested implementation steps

1. Detect right-click on the main thread, only when no UI is hovered
   and no factory placement is active.
2. Translate the click to a world point with `terrain_pick`.
3. If shift is **not** held, emit a `MOVE_ORDER_REPLACE(world_x,
   world_y)` event. Shift-held variant is deferred to issue 110.
4. In sim, on receiving `MOVE_ORDER_REPLACE`, clear each selected
   unit's order chain and append the single waypoint.
5. The existing movement system (issue 107) consumes the chain head as
   `target_xy` until the chain is empty.
6. Remove the scatter key and its `// TODO(issue-109): remove` comment.

## Related documents

- `docs/002-mechanics.md` — order rules.

## Notes

This issue is the moment when "movement" becomes "an order." A unit's
target is now a function of its order chain head, not a free-floating
field. Refactor `Unit` accordingly: replace `target_xy`/`has_target`
with a small order-chain ring buffer per unit. Keep the buffer
fixed-capacity from config (no dynamic allocation), and make the
overflow behavior an explicit error (logged + dropped order), not
silent truncation.

## Task pool integration

**Recommended priority: 3** — input-driven, runs once per right-
click. User is waiting for the order to register (the new waypoint
indicator should appear within one tick), so faster than background
maintenance, but not preempting projectile-tick work.

A `MOVE_ORDER_REPLACE` event spawns a single task:

```
order_replace_task_actions = [
    [0] iterate_selected_units
    [1] clear_each_units_order_chain
    [2] append_single_waypoint_to_each
]
```

If issue 107 adopts the per-unit self-rescheduling movement task
(Shape B), this task additionally needs to spawn a movement task
for any unit that doesn't already have one — actions [3] would be
"for each unit that gained a waypoint and has no live movement
task, spawn movement task at priority 2."
