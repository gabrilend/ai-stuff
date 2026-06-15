# 117 — Single Rally Point with X/Y Drag

## Status

TODO

## Current behavior

A factory produces units that simply stand at the factory. There is no
rally point.

## Intended behavior

Clicking the factory selects it. While the factory is selected, a rally
indicator (a small flag or marker) renders at its current single rally
point. Mouse-down on the indicator and drag (without shift) moves the
indicator across the terrain in real time:

- Drag axis is X/Y only (the cursor's terrain pick supplies X/Y).
- Z is read from `terrain_height_at(x, y)` so the indicator sits on
  the surface as it moves over hills.

On mouse-up, the new rally point is committed for the factory. Newly
produced units walk to this rally point.

## Suggested implementation steps

1. Add `rally_chain` to `Factory` — start with a 1-element chain.
   (Issue 118 will extend this to multiple chains.)
2. Click on the factory (terrain pick that hits the factory's
   bounding volume) sets it as the "rally-edit target" on the main
   thread.
3. While rally-edit is active, render a rally marker.
4. On mouse-down over the marker, enter drag mode. Each frame during
   drag, emit `RALLY_DRAG_MOVE(x, y)` with the current terrain pick.
5. The sim updates the rally point's X/Y but does not commit until
   mouse-up emits `RALLY_DRAG_COMMIT`.
6. Newly produced units have their first chain waypoint set to the
   committed rally point.
7. Render the path from the factory to the rally point as a faint
   line, like unit order chains.

## Related documents

- `docs/002-mechanics.md` — factory and rally rules.
- Issue 118 — extends to multiple chains.

## Notes

The "drag updates live, commit on release" pattern parallels how the
order-chain replace works for units (issue 109). Keeping the patterns
isomorphic across units and factories is the design goal — one mental
model for both.

## Task pool integration

This issue, like 116, splits cleanly across two priority levels:

**Live drag visual update — priority 6.** Each `RALLY_DRAG_MOVE`
event spawns a short task that updates the displayed rally
position. The user is actively dragging and watching, so the
update should feel fluid — but a single dropped frame's worth of
lag is acceptable, and we don't want this to preempt sim-tick
work. Priority 6 gives the cycler a reasonable chance to schedule
it without crowding higher-priority work.

```
rally_drag_move_task_actions = [
    [0] read_terrain_pick_from_event
    [1] write_indicator_position_to_snapshot   // not committed yet
]
```

**Commit on release — priority 3.** The `RALLY_DRAG_COMMIT` event
spawns a one-shot task at input-handler priority. This is the
moment when newly-produced units start using the new rally point,
so it should land in the same tick the user releases the mouse.

```
rally_drag_commit_task_actions = [
    [0] write_committed_rally_to_factory_state
    [1] mirror_committed_state_to_snapshot
]
```

The drag move at priority 6 means the indicator can briefly lag
the cursor under heavy sim load — that's the right trade. The
commit at priority 3 means the gameplay effect always lands
promptly.
