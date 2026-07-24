# 014-paths — clock-face parametric paths

A path answers two questions at any progress from 0 to 1: where, and
which way is travel facing (the tangent — how "oriented inward"
works). The clock-face convention is implemented exactly once, here:
y grows downward, clockwise means increasing angle, 12 is straight
up, hours are 30 degrees, fractional and spoken hours legal.

## Usable surface

- **clock_angle(hour) → radians** — accepts 7, 7.2, or "7 o'clock".
- **arc{center, radius, from, to, turn} → path** — turn must be
  stated ("clockwise"/"counterclockwise"); an arc without one is
  refused, because from-12-to-7 could sweep either way and guessing
  draws the wrong picture silently.
- **line{from, to} → path** — constant unit heading; a zero-length
  line is refused (use a point if standing still is the intent).
- **point{at} → path** — ignores progress; heading is zero so an
  emitter's aim honestly means nothing extra.

Each path is { kind, at(t) → x, y, heading(t) → hx, hy }.
