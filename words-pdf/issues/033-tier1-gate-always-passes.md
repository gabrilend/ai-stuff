# Issue 033: Tier 1 Area Gate Always Passes Because Of The Right Margin

## Current Behavior

Issue 028 gates Tier 1 page art on outside regions of at least
`TIER1_MIN_REGION_AREA_FRACTION` (8%) of the page. The regions it
considers are the bottom strips, both outer margins and the center gap.

`build_pdf` shifts both columns left by 15% of the page width
(`page_shift = 595 * 0.15 = 89.25pt`). That clamps the left outer margin
to its 5pt minimum but widens the right outer margin to
`595 - right_column_end - 5 = 94.25pt`. At full page height that region
is 94.25 x 842 = 79,359 square points, 15.8% of the page — about twice
the 8% threshold.

So every page whose theme is not "neutral" qualifies, even when both
columns are completely full (`tests/test-layout.lua` checks this:
"a full page still has one qualifying region"). The gate never skips a
page; it only decides which regions besides the right margin are added.
The "skipped" log line can only appear on neutral pages, which are
skipped before the gate.

## Intended Behavior

Undecided — this needs Ritz's call on what Tier 1 art is for:

- **A. The margin is meant to always carry art.** Then this is working as
  designed, and the gate is really "which extra regions get art". Say so
  in 028's design notes and the test, and change nothing else.
- **B. The gate should measure free space inside the text area.** Leave
  the outer margins (and the fixed center gap) out of the area test, so
  a page gets Tier 1 art only when the poems leave real room, and draw
  the margins only on pages that pass.
- **C. Make the margins measure what they look like.** Count a full-height
  margin strip by its width relative to the column width rather than by
  area, so a narrow full-height strip does not outrank a wide, short
  empty area.

## Suggested Implementation Steps

1. Decide between A, B and C.
2. For B: in `select_tier1_regions`, test only `bottom_space` (and any
   future in-column gaps) against `min_area`; when at least one passes,
   add the outer margins and center to the regions drawn.
3. For C: give margins their own threshold constant, recorded in
   `docs/balance-updates.md`.
4. Update the issue-033 check in `tests/test-layout.lua` to the chosen
   behavior and run `tests/run-tests`.

## Relevant Files

- `compile-pdf-ai.lua` (`select_tier1_regions`, `calculate_art_spaces`,
  `build_pdf`'s `page_shift`)
- `tests/test-layout.lua`
- `issues/028-tier1-region-area-gate.md`
