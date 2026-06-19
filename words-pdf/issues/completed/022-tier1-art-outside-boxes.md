# Issue 022: Restrict Tier 1 Art to Spaces Outside Boxes

## Current Behavior
`draw_tier1_page_art` passes the entire page rectangle to
`draw_theme_art_in_spaces` as a single "space," so the Tier 1 generator
draws across the whole page surface, including underneath every poem box.
Two supporting functions exist but are stubs:

- `calculate_poem_box_positions` returns an empty table — the comment
  says "Placeholder."
- `mask_poem_areas` is a no-op — the comment says "text is drawn on top
  anyway."

The combined effect: Tier 1 art is rendered everywhere, then text is
drawn on top, with no masking layer in between. Text characters have
transparent gaps; the Tier 1 art shows through those gaps and behind
the ASCII border characters. The output is visually noisy and the
contrast between text and art makes reading harder. In `output6.pdf`
this is visible as a large colorful spiral pattern occupying the
middle of the page, with poem text superimposed but the spiral still
showing through.

The infrastructure to fix this already exists at `compile-pdf-ai.lua:1080`
— `calculate_art_spaces` computes a structured set of regions:
`left_outer`, `left_inner`, `center`, `right_inner`, `right_outer`,
`gaps` (between poems), and `bottom_space` (large empty areas at column
bottoms). Tier 1 art should be drawn only in those regions, never under
the poem boxes themselves.

## Intended Behavior
`draw_tier1_page_art` consults `calculate_art_spaces` with accurate
poem box positions (from a properly-implemented
`calculate_poem_box_positions`) and passes the resulting outer / gap /
bottom spaces to `draw_theme_art_in_spaces`. Generators draw their
patterns inside those regions, composing around the poems rather than
behind them.

The text reads cleanly because the poem boxes (filled per Issue 020)
sit on a clean background; the Tier 1 art frames the poems from the
margins and gaps rather than competing with them for the same pixels.

## Suggested Implementation Steps
1. Implement `calculate_poem_box_positions` to return a list of
   `{x, y, width, height}` rectangles, one per poem in
   `page_poems.left` and `page_poems.right`. Use the same
   cumulative-y math as Issue 021 — they're mirrors of each other.
   Consider extracting the layout math into a shared helper that
   both Issue 021 and this issue call, so future layout changes
   stay synchronized.
2. Change `calculate_art_spaces` (if needed) to accept the actual
   poem box positions rather than estimating from heights, so its
   `gaps` and `bottom_space` calculations are accurate.
3. Modify `draw_tier1_page_art` to:
   a. Call `calculate_poem_box_positions` for the current page
   b. Call `calculate_art_spaces` with those positions
   c. Concatenate the outer regions and gap regions into a single
      space list
   d. Call `draw_theme_art_in_spaces` with that list instead of the
      full page
4. The `mask_poem_areas` placeholder can be deleted — with art only
   drawn outside the boxes, no masking is needed.
5. Test with pages of varying density: a fully-packed page should
   show Tier 1 art only in the thin margins and column-divider gap;
   a sparse page should show art filling the larger bottom_space
   regions.

## Related Documents
- `compile-pdf-ai.lua` — `draw_tier1_page_art`, `calculate_art_spaces`,
  `calculate_poem_box_positions`, `mask_poem_areas`,
  `generate_page_art`
- Issue 021 — fixes the same positioning math at a different layer;
  the two should share the layout calculation
- Issue 023 — adds the conditional rule for *when* Tier 1 art runs at
  all; this issue covers *where* it runs

## Metadata
- Priority: High (text legibility is the visible payoff)
- Complexity: Medium (multiple stubs need real implementations)
- Dependencies: Issue 021 (shares positioning math; should be
  implemented as a pair or in the right order)
- Estimated Effort: Medium

## Implementation Notes
Currently `calculate_art_spaces` estimates poem heights via
`calculate_poem_height(poem) * 5` (assuming line_height = 5). It also
hardcodes that estimate inside the function. Once
`calculate_poem_box_positions` is real, `calculate_art_spaces` should
take the actual computed bounds rather than re-estimating from poem
content. This removes a duplicated arithmetic and a place where the
two functions could fall out of sync.

The shared layout helper (factored out across Issues 021 and 022)
should expose a single function that takes (page_poems, layout
constants) and returns the list of poem rectangles. Once that exists,
both issues just consume its output.

When concatenating space regions to pass to `draw_theme_art_in_spaces`,
prefer `bottom_space` and `gaps` as the primary art regions (they're
larger and more visible), with the thin `left_outer` / `right_outer`
margins as secondary. Generators with high mark density (like
`generate_chaos` or `generate_urban`) will look busy in thin margins —
the larger regions give them room to breathe.
