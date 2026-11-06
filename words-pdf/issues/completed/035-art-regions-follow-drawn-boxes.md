# Issue 035: Art Regions Follow The Boxes As Drawn

## Current Behavior

`draw_boxed_poem` centers each box with
`actual_x = start_x + (max_width - box_width) / 2`. `max_width` is the
column width in points (272.5 on A4), but `box_width` is the box's width
in characters (the widest line + 4). The two units are mixed, so a box
lands about 94 pt right of the column slot it is given. `build_pdf`'s 15%
page shift (89.25 pt to the left) was tuned against this. Together they
put a full-width (80-character) box at x 15–267 in the left column and
317.5–569.5 in the right.

The art layout does not follow those boxes. `compute_poem_layout` (Tier 2
art) and `calculate_art_spaces` (Tier 1 art) both use the unshifted slot:
x −79.25–193.25 on the left, 223.25–495.75 on the right, and a width of
272.5 pt for every poem. As a result:

- The left column's bottom region for Tier 1 art starts at x −79.25, so
  about a third of it is off the page. The empty space it is meant to
  fill (15–267) is only partly covered.
- The "right outer margin" region (500.75–595) runs 69 pt under every
  full-width right-column box. The art there is hidden by the Tier 3
  fill. Only about 25 pt of real margin shows art.
- The left outer margin region (0–5) overlaps nothing, and the layout
  thinks left boxes have no outer margin at all (box.x < 0), so
  left-column poems never get an OUTER Tier 2 strip. Their real margin
  is 15 pt to over 100 pt.
- Tier 2 strips assume every box is 272.5 pt wide. For a short poem they
  are drawn far from the box. For a wide right-column box, the inner
  strip runs under the box.

Issue 021 asked that per-poem art bounds "match the visible poem box
exactly: same x, same width, same height", and 022 asked that Tier 1 art
go only outside the boxes. Neither holds horizontally.

## Intended Behavior

Every art region is computed from where the boxes are actually drawn.
Poems do not move. The look of the text page stays as it is, and the art
moves to where the empty space really is.

## Suggested Implementation Steps

1. Pull the box position out of `draw_boxed_poem` into one function,
   `box_span(widest_line, start_x, max_width)`, and the box rectangle
   into `poem_box_rect(poem, start_x, start_y, max_width, line_height)`,
   which is the rectangle the Tier 3 fill covers.
2. `draw_boxed_poem` uses both. Drawing is unchanged.
3. `compute_poem_layout` returns `poem_box_rect` for each poem.
4. `calculate_art_spaces` places the columns where a full-width
   (`MAX_CHAR_PER_LINE`) box is drawn, and sizes the bottom regions to
   that width.
5. Add a test that records what `draw_boxed_poem` draws and checks the
   art layout against it.

## What Happened

Built 2026-11-02, on top of issue 033's gate change.

- `box_span` and `poem_box_rect` are new in `compile-pdf-ai.lua`, and
  `draw_boxed_poem` uses them. The text and the fill land where they did
  before (the recorded drawing shows the same x for text and fill).
- `compute_poem_layout` now returns each poem's visible box: its own
  x and width, and the fill's y. The fill sits 4.5 pt above the old
  y-cursor box, because of the half-line lift and
  `TIER3_BOX_VERTICAL_NUDGE`. Boxes in a column are still exactly one
  line apart.
- `calculate_art_spaces` puts the columns at 15–267 and 317.5–569.5 on
  A4. The bottom regions are 252 pt wide instead of 272.5 pt, so a column
  bottom now opens issue 033's gate at about 38 empty lines instead of
  36. The right margin is now 20.5 pt and the left 10 pt. Both are
  slivers under issue 028's rule, so a passing page draws art only in
  its empty column bottoms.
- The Tier 2 strips follow each box. Left-column poems get an OUTER
  strip for the first time.
- `tests/test-render.lua` (8 checks) draws a page with a recording
  stand-in for libharu. It checks that each layout box is exactly the
  rectangle filled, that each line of text lies inside its box, that
  boxes lie on the page one line apart, that no Tier 2 strip covers its
  box or another strip, that left boxes get an outer strip, and that no
  Tier 1 region covers a box. 6 of the 8 checks fail on the old
  geometry. `tests/test-layout.lua`'s A4 checks are updated for the
  honest margins.

### Decisions

- **The unit mix in the centering stays.** Fixing it would move every
  poem on every page. Combined with the 15% shift, it gives the page
  balanced outer margins (15 pt and 25.5 pt for full-width boxes), so it
  reads as the intended look. Short poems sit left of their column's
  middle because of it; changing that is a layout decision for a
  separate issue.
- **The column span used for Tier 1 regions is the full-width box**
  (`MAX_CHAR_PER_LINE` characters), not the widest box on the page.
  That keeps the regions the same on every page. A line longer than
  `MAX_CHAR_PER_LINE` makes a wider box, which a bottom region can still
  touch.
- **Tier 1 art no longer appears in the right margin.** It used to,
  through the oversized region, mostly hidden under boxes. If a margin
  band is wanted on pages that pass, issue 033's rule of drawing margins
  only when they reach 8% is the place to change it.
