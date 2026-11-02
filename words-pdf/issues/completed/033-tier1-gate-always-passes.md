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

Three answers were weighed:

- **A. The margin is meant to always carry art.** Then this is working as
  designed, and the gate is really "which extra regions get art".
- **B. The gate should measure free space inside the text area.** Leave
  the outer margins (and the fixed center gap) out of the area test, so
  a page gets Tier 1 art only when the poems leave real room, and draw
  the margins only on pages that pass.
- **C. Make the margins measure what they look like.** Count a full-height
  margin strip by its width relative to the column width rather than by
  area.

**Decided: B.** The gate measures only the regions inside the text block
— the empty bottoms of the two columns. The outer margins and the center
gap are the same size on every page, so they cannot tell a roomy page
from a full one. A page passes when a column bottom is at least
`TIER1_MIN_REGION_AREA_FRACTION` (8%) of the page; a passing page gets
art in those column bottoms and in any margin or center strip that is
itself at least 8% (in practice the right margin). A page with full
columns gets no Tier 1 art.

Why B and not A: issue 028 asks "is there a chunk big enough to put art
in?" and says a page that fails gets no art. Its sizing note ("8% is
about a third of a column at full height") and its design note that a
page-level threshold keeps "side margins [from qualifying] too rarely"
were written without the 15% shift in view; with it, A turns 028's gate
into a constant. `THREE-TIER-SYSTEM.md` calls Tier 1 a full-page
background, which 022 and 028 deliberately narrowed to "outside the
boxes, when there is room", so it does not argue for A either. C would
keep a gate that compares unlike shapes, and still needs a second
threshold to tune.

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

## What Happened

Built as B (2026-11-02).

- `select_tier1_regions` in `compile-pdf-ai.lua` measures only
  `spaces.bottom_space` against the threshold. When one passes, it adds
  each outer margin and center strip that is itself at least the
  threshold, so 028's "no slivers" rule is unchanged for drawing. Its
  second return value is now the measured column bottoms rather than all
  outside regions.
- `generate_page_art`'s log lines name the column bottoms: "an empty
  column bottom ≥ 8% of page area; drawing N region(s)" and "no empty
  column bottom ≥ 8% of page area (largest: N%, column bottoms: N)".
- `TIER1_MIN_REGION_AREA_FRACTION` keeps its value and still measures
  against the whole page's area, so 8% means the same size it did. On A4
  a column bottom reaches it at about 36 empty lines (a strip 147 pt
  tall across the 272.5 pt column).
- `tests/test-layout.lua`: the issue-033 check now says a full page gets
  no Tier 1 art although its right margin is 16%; new checks cover a
  margin alone not opening the gate, a half-empty column opening it with
  the right margin joining, and, filling one column a line at a time,
  the page passing exactly when that column's bottom reaches 8%.

**Effect on a book.** Tier 1 art becomes much rarer. On synthetic books
of 2,000 poems through `build_book`, the share of pages that pass (all
of them did before, apart from neutral pages) is:

| poem lengths | pages | pass now |
|--------------|-------|----------|
| 1–20 lines   | 96    | 1        |
| 1–40 lines   | 157   | 22       |
| 1–80 lines   | 299   | 203      |
| 1–300 lines  | 1282  | 939      |

Short poems pack columns tightly, so a corpus of mostly short poems gets
art mainly on the last page and on pages where a long poem starts a
fresh column. If that is too sparse, lowering the threshold (028 already
suggests trying 0.05) is the tuning knob, recorded in
`docs/balance-updates.md`.
