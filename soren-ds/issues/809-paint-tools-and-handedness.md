# 809 — Paint: tools, colors, handedness

## Current behavior

The canvas accepts a continuous stroke (808) but the stroke
always uses the same color and the same brush shape. There is no
tool selection, no color picker, and no handedness-aware mapping
of buttons to tools.

## Intended behavior

A small palette of tools the user can switch between:

- **Brush** — solid round stroke of configurable size.
- **Soft brush** — same shape with anti-aliased edges and lower
  opacity at the edges.
- **Eraser** — same shape; draws the background colour.
- **Line** — straight line from `touch-down` position to
  `touch-up` position; ignores `touch-move` (just shows a
  preview).

A small palette of colors the user can pick from. The default
palette has 16 colors covering primary colors, secondary
colors, and a few neutrals. The user can extend the palette
through the drawer (saving a new color from a color picker
sub-flow).

The handedness setting (507) routes the controls per the apps
overview doc:

- **Right-handed:** D-pad cycles tools, L triggers modify (L1
  shrink brush, L2 grow), ABXY picks colors (A/B/X/Y =
  primary/secondary/eraser/most-recent), right stick fine-
  positions an off-screen cursor for precise placement.
- **Left-handed:** ABXY cycles tools, R triggers modify, D-pad
  picks colors, left stick fine-positions.

The control mapping comes from the settings applier (507) so
the paint app doesn't have to re-implement handedness logic; it
just subscribes to the semantic-tag stream.

The brush size, current color, and current tool live in a small
`paint_state` struct on the paint app's map. The state updates
atomically on control changes; the canvas reads it on each
stroke point.

## Suggested implementation steps

1. `struct paint_state` — current tool, color, brush size.
2. Per-tool stroke functions.
3. Wire the semantic-tag input stream to tool, color, and
   modifier updates.
4. A color-picker sub-flow accessible from the drawer.

## Related documents

- `docs/004-input-model.md` — handedness section.
- `docs/008-apps-overview.md`.

## Blocked by

507, 808.

## Blocks

810.
