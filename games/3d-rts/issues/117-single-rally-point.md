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
