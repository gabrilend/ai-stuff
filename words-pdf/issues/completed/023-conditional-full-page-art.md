# Issue 023: Conditional Full-Page Art

## Current Behavior
`generate_page_art` always runs `draw_tier1_page_art` for every page
whose theme isn't `neutral`. With Issue 022 implemented, the art is
restricted to spaces around the poems — but it still draws on every
page, regardless of how much room there is. On a densely-packed page
where poems fill both columns to the bottom, the Tier 1 art ends up
crammed into thin margins and a narrow column-divider gap, where its
visual character can't really emerge. On a sparse page with a long
single-column poem leaving the other column mostly empty, there's
clearly room for the art to speak.

The current rule treats both cases the same: always render.

## Intended Behavior
`draw_tier1_page_art` only runs when the page has significant blank
space. On dense pages, only the per-poem Tier 2 art and the per-poem
Tier 3 backgrounds render — the Tier 1 layer is skipped entirely.
This produces a visual rhythm across the book: pages with lots of text
read as quiet, focused; pages with shorter content get larger,
expressive theme art filling the breathing room.

Concretely: define a `fill_ratio` for each page (used vertical line
count, summed across both columns, divided by `2 * MAX_LINES_PER_PAGE`).
If `fill_ratio < TIER1_THRESHOLD` (suggested starting value: `0.65`),
render Tier 1 art. Otherwise, skip it. The threshold is a tunable
constant at the top of the file.

## Suggested Implementation Steps
1. In `generate_page_art`, before the `if page_theme ~= "neutral"`
   check, compute the page's fill ratio:
   ```lua
   local used_lines = 0
   for _, poem in ipairs(page_poems.left or {}) do
       used_lines = used_lines + calculate_poem_height(poem)
   end
   for _, poem in ipairs(page_poems.right or {}) do
       used_lines = used_lines + calculate_poem_height(poem)
   end
   local fill_ratio = used_lines / (2 * MAX_LINES_PER_PAGE)
   ```
2. Add a top-level constant `TIER1_ART_THRESHOLD = 0.65` near the
   other layout constants. Document what value 0 means (always draw)
   and what value 1 means (never draw) inline.
3. Combine the threshold check with the existing neutral check:
   render Tier 1 only if `page_theme ~= "neutral"` AND `fill_ratio <
   TIER1_ART_THRESHOLD`.
4. Log the decision so the user can verify on each page: print
   "🎨 Tier 1 skipped: page is N% full" or "🎨 Tier 1 drawn:
   page is N% full" alongside the existing theme print.
5. Per-poem Tier 2 art (`generate_individual_poem_art`) and per-poem
   Tier 3 backgrounds (Issue 020) still run unconditionally — those
   are always appropriate regardless of page density.

## Related Documents
- `compile-pdf-ai.lua` — `generate_page_art`, `draw_tier1_page_art`,
  `calculate_poem_height`, `MAX_LINES_PER_PAGE`
- Issue 022 — restricts *where* Tier 1 art draws; this issue
  controls *whether* it draws at all
- `docs/balance-updates.md` (if it exists, or create it) — record the
  chosen threshold value and reasoning so future tuning has history

## Metadata
- Priority: Medium (visual quality lift; pages still look okay without
  this, just less rhythmically interesting)
- Complexity: Low
- Dependencies: Issue 022 (this controls when 022 fires)
- Estimated Effort: Small

## Implementation Notes
The threshold value `0.65` is a starting guess. It corresponds to
"render Tier 1 art when at least 35% of the page is empty." Worth
running the threshold at 0.5, 0.65, and 0.8 to see how the book's
visual rhythm shifts and pick the value that feels right. Record the
chosen value in `docs/balance-updates.md` (per the project's
balance-tuning convention) so the decision history survives.

A future enhancement: rather than a single global threshold, derive
the threshold from the Tier 1 theme. Themes like `isolation` and
`neutral` might want a *higher* threshold (only render when the page
is very empty — empty space is part of their visual character).
Themes like `chaos` or `energy` might want a *lower* threshold (render
even on moderately-full pages, since their generators thrive in tight
spaces). Out of scope for this issue, but worth noting.
