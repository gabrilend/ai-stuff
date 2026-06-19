# Issue 020: Draw Tier 3 Poem Background Colors

## Current Behavior
The script computes a per-poem Tier 3 theme classification and resolves it
to a pale background color via `generate_poem_color_from_theme`, but
**nothing in the pipeline actually draws that color**. The function is
defined and the color table is populated, but no caller ever consults it.

The visible effect on output: every poem box is just text + ASCII border
characters on the page's default background. Whatever Tier 1 art was drawn
behind the boxes shows through every gap between characters, making the
text harder to read and the per-poem theme classification invisible to a
reader. An earlier version of the project (visible in `output6.pdf`) did
draw these backgrounds — the wiring was removed in a refactor and never
restored.

## Intended Behavior
Each poem's box is filled with a solid pale color before the text and
border characters are rendered on top. The fill color comes from
`palette.tier3_backgrounds[theme]`, where `theme` is the result of
`analyze_individual_poem_theme(poem)`. Forty distinct colors map to forty
Tier 3 themes; poems classified the same get the same background, so a
reader flipping through the book learns the color vocabulary
implicitly (pink-ish = direct_action, mint = programming_philosophy,
light-blue = ai_consciousness, etc.).

The fill goes behind the box borders, not behind the page background, so
Tier 1 page art (when present — see Issue 022) is masked under the poem
box but not elsewhere on the page. The masking is structural: it solves
the readability problem and also makes the per-poem theme color
genuinely legible.

## Suggested Implementation Steps
1. In `draw_boxed_poem`, after computing the box's `actual_x`,
   `current_y`, `box_width`, and total box height (lines of poem +
   borders + padding × line_height), compute the rectangle that the
   box occupies on the page.
2. Get the poem's Tier 3 theme via `analyze_individual_poem_theme(poem)`.
   With Issue 017's embedding cache in place, this call is near-free on
   warm runs because the poem's embedding will already be cached from
   the Tier 2 classification done in `generate_individual_poem_art`.
3. Look up the color via `palette.tier3_backgrounds[theme]` (with the
   `neutral` fallback the function already handles).
4. Set fill color via `hpdf.Page_SetRGBFill(page, table.unpack(color))`
   and draw a filled rectangle at the box bounds via
   `hpdf.Page_Rectangle` + `hpdf.Page_Fill`. This must happen *before*
   the text and ASCII border drawing — the existing code already does
   text last, so insertion is at the top of the function.
5. After the fill, reset fill color to text_color so the existing text
   drawing doesn't pick up the wrong color (the existing code sets text
   color explicitly, but defense-in-depth is cheap).

## Related Documents
- `compile-pdf-ai.lua` — `draw_boxed_poem`, `analyze_individual_poem_theme`,
  `generate_poem_color_from_theme`
- `themes/palette.lua` — `palette.tier3_backgrounds` (the 40-color table)
- Issue 017 — the embedding cache that makes the per-poem Tier 3 call
  free on rerun

## Metadata
- Priority: High (foundation for readable output; without this Tier 1 art
  destroys text contrast)
- Complexity: Low
- Dependencies: Issue 017 (for performance, not correctness)
- Estimated Effort: Small

## Implementation Notes
The box height calculation needs to include the ASCII top border, top
padding line, all content lines, and bottom border. The existing
`calculate_poem_height(poem)` function returns `#poem + 5` (poem lines +
top border + top padding + bottom padding + bottom border + space
between poems) — that's exactly the right value, just need to multiply
by `line_height` to get pixel height.

The width comes from the existing `box_width` calculation in
`draw_boxed_poem`. The rectangle's bottom-left corner is at
`(actual_x, current_y - total_box_height)` because libharu's Y axis
runs upward and the existing code positions text via top-anchored Y.

Do not draw the background for empty poems (`#poem == 0`) — the
existing early-return at the top of `draw_boxed_poem` handles this.
Place the new fill logic *after* that early return so empty entries
don't produce stray colored rectangles.
