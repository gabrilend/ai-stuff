# Issue 019: Fill in 19 Tier 1 Generators

## Current Behavior
`draw_theme_art_in_spaces` in `compile-pdf-ai.lua` is the dispatch point that
turns a classified Tier 1 theme into rendered page art. The function has
explicit unique cases for only three themes: `resistance` (red explosive
radials), `creativity` (multi-color flowing brush strokes), and `technology`
(green circuit traces). Every other Tier 1 theme falls through to the
default `else` branch, which draws "a handful of small gray circles" — the
visual equivalent of a placeholder.

The Tier 1 inventory holds 22 themes (10 core + 12 simple, merged from
art-themes.json). 19 of those 22 currently produce visually identical
placeholder art. A reader of the final book sees the same gray dot pattern
on pages classified as `isolation`, `chaos`, `transcendence`, `connection`,
`love`, `melancholy`, `crystal`, etc. — themes that should look as different
from each other as the words suggest.

Three orphaned generators (`generate_fullpage_nature`, `generate_fullpage_urban`,
`generate_fullpage_dream`) exist but are never invoked by the current
dispatch chain. They were earlier prototypes that were left behind when the
three-tier system was introduced.

## Intended Behavior
Every one of the 22 Tier 1 themes has its own dedicated visual generator,
giving the book a real per-page visual signature that tracks the embedding
classification. The dispatch in `draw_theme_art_in_spaces` becomes a
table-driven lookup (per CLAUDE.md's preference for dispatch tables over
long if/elseif chains): theme name → generator function.

Each generator targets roughly 30 lines and uses the palette (from Issue
016) for colors and the drawing primitives (from Issue 018) for shapes. No
generator hardcodes RGB triples or reaches around the palette/primitives.

The three existing orphaned generators are either folded into the new
dispatch (rewired to handle their themes) or deleted if their new
replacements supersede them.

## Visual briefs for the 19 themes
These are starting points — short evocations meant to anchor the implementation,
not constrain it. The implementer should treat them as design intent and
adapt as the rendering reveals what actually reads on the page.

### Core themes (10)
- **isolation** — Vast negative space with sparse single marks: maybe one or
  two small circles or short strokes per quadrant, with most of the page
  empty. Muted gray-blue accents. The composition itself communicates
  separation; density would betray the theme.
- **identity** — Prismatic refractions and morphing shapes: overlapping
  semi-transparent rectangles or polygons in rainbow accents, with each
  shape slightly transformed (rotated, scaled) so the same form recurs in
  variations. Heavy use of `with_alpha`.
- **systems** — Blueprint blues, network diagrams: nodes (small circles or
  squares) connected by straight or right-angle lines, with line weight
  varying by connection. Cooler blue and gray palette.
- **connection** — Warm oranges and yellows: Bezier curves linking distant
  points across the page, with multiple curves overlapping in low alpha to
  produce a woven feeling. Use `flowing_curve` from the primitives.
- **chaos** — RGB-channel-separated overlapping shapes: draw the same
  geometric form three times in nearly-overlapping positions, once in pure
  red, once in pure green, once in pure blue, all at moderate alpha so the
  glitch-print aesthetic comes through. Random rotations.
- **transcendence** — Mandala geometry from arcs: concentric circles built
  with the `arc` primitive, with radial subdivisions creating sacred-geometry
  patterns. Deep purples and golds. Symmetry is the point — generated content
  should respect a center axis or rotational symmetry.
- **survival** — Earth tones with root-system fractals: a vertical trunk-like
  Bezier curve with branching sub-curves recursing 3-4 levels deep, browns
  and forest greens, suggesting resourcefulness through ramification.

### Simple themes (12)
- **nature** — Organic branching patterns: forest greens, recursive Bezier
  branches starting at random page-bottom points and growing upward with
  natural twist. Could repurpose the existing `generate_fullpage_nature`
  with curves instead of polylines.
- **urban** — Geometric neon grid: rectangle outlines in magenta/cyan/yellow
  at varying scales, with right-angle lines connecting them, suggesting a
  city map or circuit. Could repurpose `generate_fullpage_urban`.
- **energy** — Radiating bursts from a focal point: many short lines emanating
  from one or two centers, color-graded from white at center to orange at
  edge. High line count, strong motion.
- **love** — Soft pink Bezier curves in flowing pairs that approach and
  intertwine: curves shouldn't cross randomly but in pairs that braid.
  Low alpha so multiple braids layer gently.
- **melancholy** — Downward drift: short vertical strokes in muted blue-gray,
  each stroke offset slightly lower than the last, suggesting rain or tears.
  Color washes from upper-blue to lower-gray.
- **dream** — Ethereal sine waves: smooth long curves across the page in
  dreamy purple at low alpha, multiple waves at different frequencies
  overlapping. Could repurpose `generate_fullpage_dream` with `Page_CurveTo`
  instead of polyline.
- **constellation** — Star pattern: small filled circles at random positions
  with thin connecting lines between nearest-neighbor pairs (or
  triangulated). Golden accents on dark blue. Mimics actual star
  cartography.
- **spiral** — Single spiral or several concentric spirals built from arcs:
  whirling motion drawn with `arc` primitives chained at increasing radii.
  Deep purple, smooth gradient if available.
- **circuit** — Right-angle line traces with periodic node circles, like a
  PCB; green-on-black aesthetic; lines should follow Manhattan geometry
  (horizontals and verticals only) for the authentic look.
- **lightning** — Jagged forked paths: a few primary paths from top to
  bottom of the page with bright white-blue strokes, each path branching
  into 2-3 secondary forks at random points. Sharp, asymmetric.
- **crystal** — Faceted geometric polygons: hexagons or triangles in cyan
  with internal subdivision lines suggesting refraction. Sharp clean
  edges; could use clipping paths.
- **neutral** — Replaces the current default gray dots with something
  intentionally minimal: maybe a single subtle horizon line or a faint
  large circle in pale gray. The point is that "neutral" should feel
  chosen, not absent.

## Suggested Implementation Steps
1. Confirm Issue 016 (palette) is implemented — generators will pull all
   colors from `palette.accents` rather than hardcoding RGB.
2. Confirm Issue 018 (drawing primitives) is implemented — generators
   will use `bezier`, `arc`, `with_alpha`, etc., not raw `Page_MoveTo` /
   `Page_LineTo` for anything that has a higher-level primitive.
3. Refactor `draw_theme_art_in_spaces` to use a dispatch table:
   `theme_generators[theme_name](pdf_page, space_list, intensity)`. Keep
   the table at module scope so all generators are discoverable in one
   place.
4. Implement each of the 19 missing generators as a separate function
   (named e.g. `generate_isolation`, `generate_identity`, ...). Target
   ~30 lines each; if a generator wants to be much longer, break it
   into helpers within the same file.
5. Rewire or delete the three orphaned `generate_fullpage_*` functions.
   Most likely: delete and replace with the new dispatch entries.
6. Render a one-page sample for every Tier 1 theme so the implementer
   can visually compare all 22 in one place. Save under
   `tmp/tier1-theme-samples.pdf`. This is the visual-regression baseline.
7. Add any new theme-specific accent colors back to the palette
   (Issue 016) as they're discovered; the palette grows organically as
   generators need named colors.

## Related Documents
- `compile-pdf-ai.lua` — host of `draw_theme_art_in_spaces` and the
  orphaned `generate_fullpage_*` functions
- Issue 016 (palette) and Issue 018 (primitives) — direct dependencies
- Tier 1 theme descriptions inside `initialize_theme_embeddings` —
  source of the semantic intent each generator should embody

## Metadata
- Priority: High (biggest aesthetic impact in the visual-quality cluster)
- Complexity: Medium per generator, but 19 of them — significant volume
- Dependencies: Issues 016 and 018
- Estimated Effort: Large

## Implementation Notes
Resist the temptation to make all generators "interesting." Some themes
(`isolation`, `melancholy`, `neutral`) are stronger when they hold back.
Density and ornament are dramatic choices, not always good ones. An
isolation page that's mostly empty is more truthful to the theme than an
isolation page with 200 marks.

Each generator should be **deterministic given a seed but visually varied
across pages**. This means accepting either an explicit seed parameter or
using `math.randomseed(some_page_hash)` at the top of each generator
invocation. Otherwise two runs over the same corpus produce different
art, which makes debugging and comparison painful.

The dispatch table approach also makes future tier-1 themes (if more
get added) a single-line addition rather than a new branch in a long
if/elseif chain.
