# 043-the-camera

Pan, zoom, and following a body.

Read this page rather than the source.

## What it is for

Four numbers and nothing else. Pure arithmetic — it does not import the engine,
so the headless runner can construct one to compute a culling range without a
window being anywhere near it.

## The camera

| Field | Meaning |
| --- | --- |
| `pan_x`, `pan_y` | added to every projected point |
| `scale` | multiplies all three projection constants together |
| `subject`, `subject_generation` | the body being followed, or zero |

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `new()` | | a camera |
| `pan_by(camera, dx, dy)` | | |
| `zoom_at(Projection, camera, factor, sx, sy)` | | zooms, keeping the world point under the pointer where it was |
| `clamp(Projection, camera, store, w, h)` | | keeps the maze from being scrolled entirely off screen |
| `ease_toward(Projection, camera, x, y, height, w, h, ease)` | | slides the pan toward a world point |
| `fit(Projection, camera, store, w, h)` | | scale and pan so the whole maze is visible |
| `MIN_SCALE`, `MAX_SCALE` | | |

## Three decisions worth keeping

**Zoom multiplies all three projection constants by one number.** Scaling the
cell size and the layer height independently would change the apparent angle of
the world as you zoom, which reads as the maze leaning.

**Zoom is anchored at the pointer.** Zooming toward the middle of the window when
the thing you care about is at the edge — which is most of the time, because you
are zooming in order to look at it — means chasing it back after every notch of
the wheel.

**The clamp is in world coordinates, not pixels.** A clamp in pixels behaves
differently at every zoom level, which reads as the maze becoming sticky as you
zoom in. It exists not to keep the maze centred but because a person who has
scrolled into empty space has no cue about which way to come back.

`ease_toward` slides rather than snaps: a camera welded to a body stepping
between cells makes the whole maze jitter by a cell every step, which is
unwatchable.
