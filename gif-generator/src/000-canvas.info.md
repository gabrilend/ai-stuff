# 000-canvas — the light buffer and tone-mapper

The canvas particles glow onto. Accumulates light as floats so glows
can pile up without clipping; compresses to displayable color once
per frame. Layout: three floats per pixel, row-major, y downward.
Zero energy is the black background — nothing ever paints black.

## Usable surface

- **new(width, height) → canvas** — allocates the energy plane and
  the mapped plane once (both reused every frame). Refuses sizes
  under 1x1.
- **clear(canvas)** — zeroes the energy plane; start of every frame.
- **add(canvas, x, y, er, eg, eb)** — deposit light at a pixel,
  additively. The only write operation; order never matters. Errors
  on out-of-bounds (callers clip first).
- **tonemap(canvas) → mapped floats** — energy to [0,1] color:
  white-shift (blazing hues bleach toward white), soft knee (never
  clips), gamma last. Writes and returns the canvas's mapped plane.
- **mapped_byte(canvas, x, y, channel) → 0..255** — viewing
  convenience for tests and debug dumps; the pipeline itself goes
  straight from mapped floats to palette indices.

Knobs (WHITE_KNEE, GAMMA) live at the top of the file; tuning them
belongs in docs/balance-updates.md with reasons.
