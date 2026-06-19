# Issue 018: Add Bezier, Alpha, and Gradient Drawing Primitives

## Current Behavior
Every generator in `compile-pdf-ai.lua`'s art system uses the same three
libharu calls in combination:

- `hpdf.Page_MoveTo(x, y)` — move pen to a point
- `hpdf.Page_LineTo(x, y)` — straight line from current point to a new point
- `hpdf.Page_Stroke()` — render the path

This gives generators only one drawing vocabulary — opaque straight lines.
Curved shapes have to be approximated as many short line segments
(see `generate_fullpage_dream`'s sine waves, which step `x` by 3 pixels and
LineTo through every point). Transparent overlays don't exist — every mark
is fully opaque, so layering themes always produces hard mark-over-mark
intersections instead of color blending. Filled gradients don't exist either,
so any color transition has to be simulated with many adjacent colored shapes
the eye reads as a gradient.

The visual signature this produces is "early plotter test pattern" — clean,
deliberate, but visibly limited to what a single-color pen can do. Adding any
of three drawing modes — Bezier curves, alpha transparency, color gradients —
substantially widens what generators can express per line of code.

## Inventory of what libharu actually exposes
The Lua bindings in `libs/luahpdf/hpdf.c` expose the following primitives
relevant to this issue:

**Available:**
- `Page_CurveTo(x1, y1, x2, y2, x3, y3)` — cubic Bezier from current point
  with two control points (x1,y1) and (x2,y2) ending at (x3,y3). Combined with
  `Page_MoveTo`, this gives true curves instead of polyline approximations.
- `CreateExtGState()` plus `ExtGState_SetAlphaFill`, `ExtGState_SetAlphaStroke`,
  `ExtGState_SetBlendMode`, and `Page_SetExtGState` — alpha transparency and
  blend modes (normal, multiply, screen, overlay, etc.) applied to subsequent
  drawing operations.
- `Page_Fill`, `Page_FillStroke`, `Page_Eofill`, `Page_EofillStroke`,
  `Page_ClosePathFillStroke` — fill operations beyond pure stroking, including
  even-odd vs nonzero winding fills.
- `Page_Clip`, `Page_Eoclip` — clipping paths so subsequent draws are masked
  to a shape.
- `Page_Concat` (the CTM transform) — rotate, scale, translate coordinate
  systems for composed drawings.

**Not available (gap to close if we want true gradients):**
- `HPDF_Shading_*` family (axial and radial gradients). These are part of
  libharu's C API but not exposed in the existing Lua wrapper. Adding them
  would require editing `libs/luahpdf/hpdf.c` and rebuilding the .so.

## Intended Behavior
A `libs/art-primitives.lua` module sits beside the existing libraries and
provides named higher-level helpers that wrap libharu's raw calls. Generators
in `compile-pdf-ai.lua` call into these helpers instead of touching `hpdf.*`
directly. The helpers cover three capability groups:

1. **Curves.** A `bezier(page, points, options)` helper that draws a cubic
   Bezier from a sequence of points, optionally smoothing automatically
   (catmull-rom-to-cubic conversion so callers can give control points
   without computing tangents). Functions like `flowing_curve(page, start,
   end, sway)` for the common "wavy line" pattern, and `arc(page, center,
   radius, start_angle, end_angle)` built from four-segment Bezier
   approximation since libharu has no arc primitive.

2. **Alpha and blend.** A `with_alpha(page, alpha, fn)` helper that creates
   an ExtGState, applies it, calls `fn` (which does the actual drawing), and
   restores the prior state. Same pattern for `with_blend_mode(page, mode,
   fn)`. These let generators write `with_alpha(page, 0.4, function()
   draw_lots_of_overlapping_circles(page) end)` and have it Just Work.

3. **Simulated gradients.** Since libharu's native shading isn't bound,
   provide `axial_gradient(page, x1, y1, x2, y2, color_a, color_b, steps)`
   that draws `steps` parallel strips with interpolated colors between
   color_a and color_b along the line from (x1,y1) to (x2,y2), and
   `radial_gradient(page, cx, cy, r_inner, r_outer, color_inner,
   color_outer, steps)` that draws `steps` concentric rings. At ~20 steps
   this looks indistinguishable from a true gradient at PDF resolution; at
   ~50 it is indistinguishable; below ~10 it shows banding.

Generators read more like compositions afterwards:
- `arc(page, {x, y}, radius, 0, math.pi)` instead of a `for` loop with
  LineTo through 60 points
- `with_alpha(page, 0.3, function() ... end)` instead of "set color, draw,
  hope the layering works visually"
- `axial_gradient(page, top_left, bottom_right, sky_blue, sunset_orange, 30)`
  instead of nothing or "fake it with hatching"

## Suggested Implementation Steps
1. Create `libs/art-primitives.lua` exposing functions `bezier`,
   `flowing_curve`, `arc`, `with_alpha`, `with_blend_mode`, `axial_gradient`,
   `radial_gradient`. Each should be a small wrapper, not a framework.
2. Implement `arc` using the four-segment cubic Bezier approximation
   (each segment covers up to 90°, control point offset is
   `radius * 4/3 * tan(angle/4)`). This is a well-known formula and worth
   getting right once so generators don't reinvent it.
3. Implement `with_alpha` as create-ExtGState, set-alpha, set-on-page,
   run-callback, set-on-page-with-default-state. Reading the current
   state requires care — libharu uses graphics-state save/restore via
   `Page_GSave` / `Page_GRestore` which the bindings also expose; use
   those rather than manual snapshot/restore.
4. Implement the simulated gradients as a tight loop drawing colored
   strips/rings. Default step count of 30, exposed as an optional
   parameter for callers who want different cost/quality trade-offs.
5. Add unit-test-style render script that produces a one-page PDF
   exercising every helper, so future changes to the primitives can be
   visually verified against a known reference output. Put under
   `tests/art-primitives-visual.lua`.
6. (Stretch goal) Add `HPDF_Shading_*` bindings to `libs/luahpdf/hpdf.c`
   so true PDF-native axial and radial shadings become available, and
   swap the simulated-gradient helpers to use them while keeping the same
   API. This is a separate piece of work and can be deferred.

## Related Documents
- `libs/luahpdf/hpdf.c` — the C bindings; reference for what's exposed
  and where to add new bindings if pursuing the stretch goal
- `compile-pdf-ai.lua` art generation section — the consumers of these
  primitives; expect to convert many `Page_MoveTo`+`Page_LineTo` patterns
  to `bezier` or `arc` calls in Issue 019
- libharu official docs (`libs/libharu-RELEASE_2_3_0/doc/`) — reference
  for the exact semantics of CurveTo, ExtGState, and shading

## Metadata
- Priority: High (Issue 019 generators depend on having these to produce
  visibly distinct theme aesthetics)
- Complexity: Medium (Bezier and alpha are mechanical; gradient simulation
  is a tight inner loop; the stretch-goal C-binding work is more
  involved)
- Dependencies: none
- Estimated Effort: Medium

## Implementation Notes
The Bezier `arc` approximation is well-trodden territory; the standard
trick is to subdivide any arc longer than 90° into multiple Bezier
segments, with control-point offset `radius * (4/3) * tan(angle_per_segment / 4)`.
Doing it right once in this module saves every generator that wants a
circle from re-deriving it.

The `with_alpha` helper is the highest-payoff primitive in this set —
overlapping marks with 0.3 alpha read as designed atmospheric layers
rather than as mistakes, and that single visual quality alone moves the
art from "test pattern" to "intentional composition."

For simulated gradients, the implementation cost is a tight loop with a
linear color interpolation; the runtime cost per gradient is negligible
compared to the Ollama round-trips that the embedding cache (Issue 017)
already addresses.
