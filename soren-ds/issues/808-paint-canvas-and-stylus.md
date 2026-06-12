# 808 — Paint: canvas and stylus

## Current behavior

Both touch screens emit touch events (504) and the compositor
can render surfaces. Nothing yet uses either to paint pixels
onto a canvas the user can save.

## Intended behavior

The paint app's canvas is a single surface spanning both
screens (or one screen, depending on user preference; the
default is both). The canvas's pixels are stored in a bitmap
the size of the combined screen area.

Touch input flow:

1. `touch-down` on either screen translates the touch position
   into canvas coordinates.
2. The brush is "down" — subsequent `touch-move` events draw
   pixels along the touch path with the current tool's stroke
   shape.
3. `touch-up` releases the brush.

The drawing operation is the application of the current tool
(809) at the touch position into the bitmap. Pixels are written
into the canvas's underlying buffer; the surface's damage bit
gets marked, the compositor repaints on the next tick.

Per-frame, while a stroke is in progress, the paint app
interpolates between consecutive touch positions so a fast
stroke doesn't leave gaps in the rendered line. The
interpolation uses Bresenham-style line drawing for solid
strokes; brushes that have texture (a soft brush, for instance)
sample along the line at the brush's spacing.

Undo and clear:

- **Undo.** The app keeps the last N completed strokes (where
  N is configurable, defaulting to a few dozen) as bitmap
  diffs in a ring buffer. Each `touch-up` closes a stroke and
  commits its diff to the ring. Undo pops the most recent
  diff and replays it inverted.
- **Clear.** Fills the canvas with the background colour and
  commits the action as one large diff so undo can revert it.

## Suggested implementation steps

1. The combined-screen bitmap allocation.
2. `paint_stroke_box()` — accumulates touch points into a
   stroke struct.
3. Bresenham line interpolation between consecutive touch
   positions.
4. The undo ring buffer of bitmap diffs.
5. The "clear" operation as one big diff.

## Related documents

- `docs/008-apps-overview.md` — the paint program section.

## Blocked by

504, 601, 603.

## Blocks

809, 810.
