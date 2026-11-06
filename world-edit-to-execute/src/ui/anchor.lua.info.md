# anchor.lua

Interface elements placed by anchors, as WC3's frames are (FDF's
SetPoint), resolved to screen rectangles when the window's size changes
(issue 506b).

- **Units:** offsets and sizes are in the 4:3 area's units, 960 across and
  720 down (WC3's 0.8 by 0.6 times 1200, `anchor.WC3`), with y going
  down. The 4:3 area (`"ui"`) is the window's full height and 4/3 of it
  across, centred; on a window narrower than 4:3 it is the whole window.
  `"screen"` is the whole window. One unit is `min(w / 960, h / 720)`
  pixels.
- **A frame:** `id`, `to` (the frame its points refer to; default `"ui"`),
  `w`, `h`, and `points`, each `{ point, relative_point, x, y, to }`. The
  nine points run from TOPLEFT to BOTTOMRIGHT. On each axis, two points
  at different places set both edges (so the frame stretches); otherwise
  one point and the size set its place.
- **`anchor.resolve(frames, w, h) -> rects, scale, roots`**: every frame's
  `{ x, y, w, h }` in whole pixels. Each edge is rounded on its own, so
  neighbouring frames meet. It returns nil and why for a frame with no
  point, or one point and no size; an unknown point or frame; a circle of
  frames; two frames of one name; or points that cross.
- **`anchor.cache(frames)`**: `:get(w, h)` works the rectangles out only
  when the size changes. `.computed` counts how many times it has.
- **`anchor.roots(w, h)`**: the two root rectangles and the scale.

WC3's own console, given as frames, is `ui/wc3/console_frames.lua`.
