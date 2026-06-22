# Issue 028: Gate Tier 1 Page Art On Per-Region Area Instead Of Page Fullness

## Current Behavior

`generate_page_art` in `compile-pdf-ai.lua` decides whether to render
Tier 1 (page-level background) art on each page by computing a
single **global fill ratio**:

```
fill_ratio = sum_of_poem_heights / (2 * MAX_LINES_PER_PAGE)
```

If `fill_ratio < TIER1_ART_THRESHOLD` (currently `0.65`) and the
page's theme is not `"neutral"`, Tier 1 art is drawn in the regions
outside the poem boxes (bottom strip, outer margins, center gap),
as computed by `calculate_art_spaces`. Otherwise the page gets no
background art at all.

The downside is the gate fires **before** the outside regions are
even computed. A page that is 70% full *globally* can still have
one large contiguous empty area — for example, a tall poem on the
left and a short poem on the right leaves the bottom of the right
column empty for many lines. Under the current rule that page is
"too full" for Tier 1 art, even though there is plenty of canvas
in the right place. Conversely, a 30%-full page where the empty
space is scattered into many small slivers passes the global
threshold and the renderer ends up painting tiny scraps of art
that read as noise.

## Intended Behavior

The per-page Tier 1 decision becomes geometry-driven:

1. Compute the outside regions first (as today, via
   `calculate_art_spaces`).
2. Filter the regions to those whose individual area is at least
   `TIER1_MIN_REGION_AREA_FRACTION` of the total page area.
3. If at least one region qualifies, draw Tier 1 art **in the
   qualifying regions only** — the slivers are dropped from the
   render even on otherwise-sparse pages.
4. If none qualify, skip Tier 1 art for the page.

The starting value of `TIER1_MIN_REGION_AREA_FRACTION` is `0.08`
(8% of the page) — about the size of a third of one column at
full height, big enough to read as a deliberate canvas rather
than as decoration tucked into a corner.

The `page_theme == "neutral"` short-circuit stays: neutral-themed
pages still get no Tier 1 art regardless of geometry.

The per-page log line names the qualifying-region count and the
threshold so the operator can tell at a glance why a page got
art (or did not).

## Suggested Implementation Steps

1. Delete `TIER1_ART_THRESHOLD` from the constants block near the
   top of `compile-pdf-ai.lua`. It has no remaining call sites
   after this change.
2. Add `TIER1_MIN_REGION_AREA_FRACTION = 0.08` in the same block
   with a comment explaining the geometry-based gate.
3. In `generate_page_art`:
   - Drop the `used_lines` / `fill_ratio` / `fill_pct` computation.
   - Move the `calculate_art_spaces` call and the outside-regions
     flatten BEFORE the gate.
   - Compute `min_area = page_width * page_height * TIER1_MIN_REGION_AREA_FRACTION`.
   - Filter `outside_regions` into a `qualifying_regions` list by
     `region.width * region.height >= min_area`.
   - Render Tier 1 art when `page_theme ~= "neutral"` AND
     `#qualifying_regions > 0`. Pass `qualifying_regions` (not
     the unfiltered `outside_regions`) to `draw_tier1_page_art`.
4. Update the progress_ui.log messages to describe the new gate
   (qualifying count, threshold percentage, largest region size
   for the "skipped" case).
5. Append a balance-updates.md entry recording the retirement of
   `TIER1_ART_THRESHOLD` and the introduction of
   `TIER1_MIN_REGION_AREA_FRACTION = 0.08`.

## Relevant Files

- `compile-pdf-ai.lua` (`generate_page_art`, constants block)
- `docs/balance-updates.md` (tuning log)

## Design Notes

Per-region filtering instead of a global page-fullness check was
chosen over alternatives ("largest single region must be ≥ N%",
"sum of region areas above some threshold") because it answers
the operator's actual question — "is there a chunk big enough to
put art in?" — on a per-region basis rather than rolling the
decision up to a single page-wide number. A page with two
medium-sized qualifying regions gets art in both; a page with
one big region and four useless slivers gets art only in the
big one. The all-or-nothing per-page decision is gone.

The minimum-area threshold lives at the page level, not the
column level, so the same fraction means roughly the same visual
size regardless of which region (bottom strip vs. column outer
vs. center gap) is being measured. A column-relative threshold
would have made bottom strips qualify too easily and side
margins qualify too rarely.

The previous threshold (`TIER1_ART_THRESHOLD = 0.65`) is deleted
outright rather than left in the constants block as a no-op —
dead constants invite confusion when someone later tries to
tune them. `docs/balance-updates.md` records the retirement.
