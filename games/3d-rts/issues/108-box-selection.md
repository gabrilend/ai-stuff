# 108 — Box Selection

## Status

TODO

## Current behavior

There is no notion of "selected units." All units share the same
behavior; orders cannot be targeted.

## Intended behavior

Left-mouse-down on the world (no UI under cursor) starts a selection
rectangle. Dragging stretches it across the screen. On release:

- All units whose 3D position projects to a screen point inside the
  rectangle become the new selection.
- Selected units render with a wireframe box outline or a slightly
  brighter color.

A click without drag (down-and-up at the same screen point, within a
small threshold) selects the single unit closest to the click ray, if
any; otherwise it clears the selection.

The selection lives in `src/090-selection.c` and is mirrored into the
snapshot so the renderer can highlight the selection.

## Suggested implementation steps

1. Add a screen-rect drag tracker on the main thread in `040-input.c`.
2. On release (or threshold-exceeded click), emit a `SELECT_RECT` or
   `SELECT_CLICK` event into the queue.
3. In the sim thread, handle these events by:
   - Project each unit's world position to screen using the camera's
     view-projection (the sim thread reads camera state from a
     read-only snapshot copy — the camera does not need to be sim-owned;
     a simple memcpy of the camera struct under a small lock is fine).
   - Mark units inside the rect as `selected = true`, others `false`.
4. Mirror the `selected` flag into the snapshot.
5. Render selection with a wireframe outline. Render the in-progress
   drag rectangle as a 2D overlay during drag.

## Related documents

- `docs/002-mechanics.md` — selection rules.
- `docs/004-architecture.md` — input event types.

## Notes

The camera-state-read on the sim thread is the one place where the
strict "main owns camera" rule bends. The reason is that selection
membership *is* a gameplay decision and must be reproducible from a
tick's inputs alone — that requires the camera at the moment of the
event. Pass a copy of the camera state alongside the `SELECT_RECT`
event in the queue, rather than reading shared state. Document this
trade-off where the event type is defined.
