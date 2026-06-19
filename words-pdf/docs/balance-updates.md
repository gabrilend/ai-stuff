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
