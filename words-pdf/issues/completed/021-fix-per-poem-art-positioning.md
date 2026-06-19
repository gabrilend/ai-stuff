# Issue 021: Fix Per-Poem Art Positioning

## Current Behavior
`generate_individual_poem_art` walks each column of poems and draws Tier 2
art around each one. The bounds it computes for each poem are wrong in
two ways:

```lua
local poem_height = #poem * line_height
local poem_bounds = {
    x = margins.left - page_shift,
    y = page_height - margins.top - (poem_num - 1) * (poem_height + line_height),
    width = column_width,
    height = poem_height,
}
```

1. **The y formula uses the current poem's height for all prior poems.**
   The expression `(poem_num - 1) * (poem_height + line_height)` assumes
   every previous poem in the column has the same height as the current
   one. So if poem 1 has 10 lines and poem 2 has 30 lines, the art for
   poem 2 is positioned as if there were one 30-line poem above it, not
   one 10-line poem above it. By poem 5 or 6 the drift is severe.
2. **The poem_height excludes the box's borders and padding.** It uses
   `#poem * line_height`, which counts only the body lines. The actual
   box also has a top border, top padding, bottom padding, bottom border,
   and a line of separation from the next poem — five extra lines that
   `calculate_poem_height` already accounts for. So even on poem 1, the
   art rectangle is shorter than the visible box.

Visible symptom in `output6.pdf`: art appears for the top few poems in
each column, then either drifts out of alignment or vanishes off the
bottom of the page. Long poems get no art at all because their calculated
y position lands below the page bottom.

## Intended Behavior
Per-poem art bounds match the visible poem box exactly: same x, same
width, same height (including borders/padding), and y position
determined by cumulative vertical position of all prior poems in the
column. Every poem on every page — including long single-column poems —
gets its art drawn around the correct rectangle.

## Suggested Implementation Steps
1. Refactor `generate_individual_poem_art` to maintain a `y_cursor`
   variable per column, starting at `page_height - margins.top` and
   decremented after each poem.
2. Use `calculate_poem_height(poem) * line_height` for the actual box
   height (this function already returns the correct line count
   including borders and padding).
3. The poem's box top is at the current `y_cursor`; the box bottom is
   at `y_cursor - box_height`. Set `poem_bounds.y = y_cursor -
   box_height` so the rectangle starts at the bottom-left corner of
   the box (consistent with libharu's coordinate convention).
4. After processing a poem, decrement `y_cursor` by `box_height +
   line_height` (the extra `line_height` is the gap between poems
   that the renderer leaves).
5. Do the same for the right column with its own `y_cursor`. Both
   start at the same top y.
6. Verify against `build_book`'s layout logic — both functions need to
   agree on poem heights and gaps. If `build_book` ever changes its
   layout math, this code needs to update too. Add a comment
   pointing to `build_book` so future readers know they're paired.

## Related Documents
- `compile-pdf-ai.lua` — `generate_individual_poem_art`,
  `calculate_poem_height`, `build_book` (the layout function whose
  positioning this code must mirror)
- Issue 020 — uses the same poem-bounds math for background fills
- Issue 022 — needs the same accurate bounds for its
  `calculate_poem_box_positions` implementation

## Metadata
- Priority: High (without this, per-poem art is broken for ~80% of
  poems on a typical page)
- Complexity: Low
- Dependencies: none
- Estimated Effort: Small

## Implementation Notes
The fundamental rule of this fix is **mirror `build_book`'s layout
arithmetic**. That function tracks where each poem actually sits on
the page; this code needs to track the same positions. If they
diverge, the art positions drift away from the boxes again. Worth
extracting the layout math into a shared helper at some point — but
for this issue, just mirroring it is enough.

Long poems that span multiple columns are split into segments by
`append_long_poem` before they reach `build_book`'s page layout. By
the time `generate_individual_poem_art` sees them, each entry in
`page.left` or `page.right` is at most one column's worth, so the
cumulative-y approach works without any special long-poem handling
at this layer.
