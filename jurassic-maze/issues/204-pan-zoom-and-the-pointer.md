# 204 — Pan, Zoom, And The Pointer

| | |
| --- | --- |
| Phase | 2 — The Eye |
| Blocked by | 201, 202 |
| Blocks | 407 |
| Reads | [the camera and what it watches](../docs/008-the-camera-and-what-it-watches.md) |
| Open questions | none |

## Current behavior

The maze is drawn from a fixed viewpoint and cannot be moved.

## Intended behavior

Four numbers: `pan_x`, `pan_y`, `scale`, and a `subject` body id that is zero
until phase four gives it something to follow.

**Zoom multiplies all three projection constants by one number.** Scaling the
cell size and the layer height independently would change the apparent angle as
you zoom, which reads as the maze leaning.

**Zoom is centred on the pointer.** Invert the projection at the pointer before
the scale change and after it, and add the difference to the pan. Zooming toward
the middle of the window when the thing you care about is at the edge means
chasing it back after every notch of the wheel.

Panning by drag and by the arrow keys. Both write the same two numbers; neither
is a mode.

The camera is clamped so the maze cannot be scrolled entirely off the screen —
not to keep it centred, but because a person who has scrolled into empty space
has no cue about which way to come back.

## Suggested implementation steps

1. Write the camera record and its `to_screen` binding, so callers pass a camera
   rather than five loose numbers.
2. Write drag: pointer delta added to pan while a button is held.
3. Write wheel zoom with the pointer-anchored correction, and clamp `scale`
   between a minimum where the whole maze fits and a maximum where a cell is a
   comfortable size.
4. Write the clamp on pan, in world coordinates, not screen ones — a clamp in
   screen coordinates behaves differently at every zoom level.
5. Test: zooming at a pointer position leaves the world point under that pointer
   unchanged, to within a pixel, across a range of scales. This is the one that
   catches an inverted sign, which otherwise looks almost right.

## Related documents and tools

- [The camera and what it watches](../docs/008-the-camera-and-what-it-watches.md)
- [The isometric projection](../docs/006-the-isometric-projection.md)
