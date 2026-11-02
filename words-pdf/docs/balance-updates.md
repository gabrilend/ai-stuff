# Balance Updates

Append-only log of tuning values and small tweaks. Each entry records what
was changed, what it was changed to, and why. Newest entries at the bottom.

---

## 2026-06-18 — TIER1_ART_THRESHOLD = 0.65 (initial value)

**File:** `compile-pdf-ai.lua`
**Variable:** `TIER1_ART_THRESHOLD`
**Value:** `0.65`

Threshold for rendering Tier 1 page-level generative art. The page's fill
ratio is `sum(calculate_poem_height(poem)) / (2 * MAX_LINES_PER_PAGE)`.
Tier 1 art only renders when fill ratio is *less than* this threshold,
so dense pages stay quiet and sparse pages get the full art treatment.

**Starting at 0.65** as a guess — "render when at least 35% of the page
is empty." Worth running the script at 0.50, 0.65, and 0.80 and picking
the value where the book's visual rhythm feels right.

Added by Issue 023.

---

## 2026-06-20 — TIER1_ART_THRESHOLD retired; TIER1_MIN_REGION_AREA_FRACTION = 0.08 (initial value)

**File:** `compile-pdf-ai.lua`
**Variable retired:** `TIER1_ART_THRESHOLD` (was `0.65`)
**Variable added:** `TIER1_MIN_REGION_AREA_FRACTION`
**Value:** `0.08`

The page-fullness gate was replaced by a per-region area filter. The old
rule rejected Tier 1 art on any page above 65% global fill — but a page
can be 70% full and still have one large contiguous empty zone (e.g.
tall poem in one column, short poem in the other leaves the bottom of
the short side empty). The new rule computes the outside regions first
and draws Tier 1 art in any region whose area is at least
`TIER1_MIN_REGION_AREA_FRACTION` of the page area. Slivers below the
threshold are dropped from the render even on sparse pages.

**Starting at 0.08** (8% of the page) — roughly a third of a column at
full height. Worth running at 0.05, 0.08, and 0.12 to see which gives
the most consistently readable art placement.

Added by Issue 028.

---

## 2026-06-20 — TIER3_BOX_VERTICAL_NUDGE = 2 (initial value)

**File:** `compile-pdf-ai.lua`
**Variable:** `TIER3_BOX_VERTICAL_NUDGE`
**Value:** `2` (PDF points; PDF Y increases upward, so larger = box up)

The Tier 3 background rectangle drawn by `draw_boxed_poem` was visually
bottom-heavy: its top edge sat flush with the top dashed border (the
`+ line_height * 0.5` half-line offset already in the position formula),
but its bottom edge extended ~2.5 pt below the bottom dashed border
because the box height equals `(#poem + 4) * line_height` while the
dashed borders only span `(#poem + 3) * line_height` at the baseline.
The 2-pt upward nudge shifts the whole rectangle up so the gaps above
and below the dashed-border characters look roughly equal.

Worth trying 1, 2, and 3 pt on the same page to see which reads most
balanced. Bump if the bottom still feels heavier; reduce if the top
starts to peek above the dashed border.

---

## 2026-11-02 — Tier 1 gate measures only the column bottoms (value unchanged)

**File:** `compile-pdf-ai.lua`
**Variable:** `TIER1_MIN_REGION_AREA_FRACTION`
**Value:** `0.08` (unchanged)

The 15% page shift makes the right outer margin about 16% of the page on
every page, so under issue 028's rule every themed page passed the gate.
The gate now measures only the empty column bottoms against the
threshold; the outer margins and center strip are drawn on a passing
page when they are themselves at least the threshold, and never open the
gate. Tier 1 art is now much rarer on books of short poems (on a
synthetic book of 1–20-line poems, 1 page in 96). If that reads too
sparse, try 0.05.

Changed by Issue 033.

---

## 2026-11-02 — Art regions measured where the boxes are drawn (values unchanged)

**File:** `compile-pdf-ai.lua`
**Variable:** `TIER1_MIN_REGION_AREA_FRACTION` = `0.08` (unchanged)

The Tier 1 column-bottom regions are now 252 pt wide (the width of a
full-width box), not 272.5 pt (the column slot). So the same 8% needs
about 38 empty lines instead of 36. The right margin region shrank from
94.25 pt (69 pt of it under the boxes) to 20.5 pt, below the threshold,
so a passing page no longer draws Tier 1 art in the margin.

Changed by Issue 035.
