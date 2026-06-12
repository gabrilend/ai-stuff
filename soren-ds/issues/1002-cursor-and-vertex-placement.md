# 1002 — Cursor and vertex placement

## Current behavior

The vertex grid (1001) has a place function but nothing yet
moves a cursor through 3D space to pick where to place a vertex.

## Intended behavior

A `cursor_t` carries the user's current position in the grid.
The cursor moves under analog-stick control:

- Left stick X/Y maps to grid X/Z (horizontal plane).
- Right stick Y maps to grid Y (elevation). Right stick X
  rotates the perspective view (1009) for orientation.
- Each frame, the stick deltas accumulate into a sub-cell
  position. When the position crosses a cell boundary, the
  cursor jumps to the next cell.

A face button — `A` in right-handed mode, the symmetric one in
left-handed mode — confirms placement: a vertex is placed at
the cursor's current cell. If the cell already has a vertex,
the press removes it (a toggle).

The cursor is rendered as a small bright cross at its cell
position in the perspective view. Cells with existing vertices
render as larger dots; the cursor sitting on an occupied cell
shows both.

A second face button — `B` — cancels mid-action (a vertex about
to be placed at a specific cell is unplaced if the user changes
their mind before moving away).

## Suggested implementation steps

1. `struct cursor_t` — position, sub-cell accumulator, rotation
   angle.
2. `cursor_advance_box()` — per-frame stick-delta accumulation.
3. `cursor_place_or_toggle_box()` — face-button-A handling.
4. `cursor_cancel_box()` — face-button-B handling.
5. The cursor and existing-vertex rendering hooks for 1009.

## Related documents

- `docs/010-modeller.md`.
- `docs/004-input-model.md` — handedness section.

## Blocked by

503 (sticks), 502 (face buttons), 507 (handedness), 1001.

## Blocks

1003, 1009.
