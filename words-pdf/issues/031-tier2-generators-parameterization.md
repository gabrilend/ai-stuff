# Issue 031: Tier 2 Generator Carve-Up And Per-Poem Parameterization

## Current Behavior

Tier 2 art is the **per-poem decorative motif layer** — small patterns
drawn in the four strips immediately surrounding each poem's box (top
strip, bottom strip, inner-gutter side, outer-page-margin side).
Conceptually equivalent to Tier 1 (page background art) but at poem
granularity instead of page granularity.

All three slices of this issue are implemented in code (see "Intended
Behavior" and "Suggested Implementation Steps" for the blueprint):

1. **Monolith carved up (slice A).** The old ~600-line
   `draw_tier2_column_patterns` if/elseif chain is gone. Its 20 named
   motifs plus the default fallback now live as 21 entries in
   `themes/generators.lua`'s `M.tier2`, each with the same
   `{style_description, parameters, draw}` shape Tier 1 uses. The old
   hard-coded `math.floor(N * intensity)` counts became
   percentile-driven `parameters` axes (one density/count axis per
   motif, two for none — kept deliberately simple). Note the source
   actually carried a 20th branch, `social_media_fatigue`, beyond the
   19 the blueprint enumerated; it was migrated too.

2. **Per-poem percentile pre-pass added (slice B).** `POEM_PERCENTILES`
   (keyed by poem ordinal index) parallels `PAGE_PERCENTILES`.
   `compute_poem_axis_percentiles(book)` projects every poem onto each
   cluster's `tier2_parameter_axes` and rank-percentiles them; it runs
   from `main()` right after `compute_axis_percentiles`. `build_book`
   stamps `poem._index`, inherited by split segments in
   `append_long_poem`, so the renderer can find each poem's params.

3. **Runtime switched to the registry (slice C).**
   `generate_individual_poem_art` now classifies each poem's cluster,
   looks up its `tier2_generator`, fetches the `draw` from
   `generators.tier2` (falling back to `generators.tier2.default`), and
   calls it per pinwheel strip with the poem's `POEM_PERCENTILES`
   params. The legacy function is deleted.

**Activation is gated on a taxonomy rebuild.** The checked-in
`themes/derived-taxonomy.lua` predates *all* generator-mapping fields
(it has no `tier1_generator`/`tier2_generator`/parameter-axes at all),
so at runtime every cluster falls back to `neutral`/`default` and the
generator system — Tier 1 included — stays dormant. Editing
`themes/generators.lua` bumped its mtime, so the next `./run`
auto-rebuilds the taxonomy via the Issue 030 Phase 4 stale-check, which
regenerates it with the cluster→generator mappings and per-cluster axes
(Tier 2 included, since `name-clusters.lua` already walks
`generators.tier2` generically). That rebuild needs the llama.cpp
embedding + chat servers running; it was not run in this environment
because no server was up. Until then the per-poem art renders as the
default lavender dashes for every poem.

The four-strip geometry (`compute_tier2_art_spaces`) was upgraded to
a **pinwheel layout** under this issue's first step (already
implemented and merged) — see "Already done" below.

## Intended Behavior

Tier 2 reaches parity with Tier 1's registry-driven model. The
monolithic dispatch is gone. Each visual motif is its own entry in
`themes/generators.lua` under `M.tier2`, with the same shape Tier 1
generators use: `{draw, style_description, parameters}`. The Issue 030
machinery (cluster→generator mapping, axis pre-computation,
percentile-driven params) extends naturally to cover Tier 2 — the
only structural addition needed is a **per-poem percentile pass**
parallel to the existing per-page pass (Tier 1 keys params by page;
Tier 2 keys by individual poem).

At render time, `generate_individual_poem_art` walks each poem on
the page, looks up the poem's assigned cluster, fetches the
cluster's `tier2_generator` from the loaded taxonomy, finds that
generator's `draw` function in the registry, and calls it with
percentile-driven params from `POEM_PERCENTILES`. The legacy
`draw_tier2_column_patterns` function is deleted.

End state: each poem on each page can have its own per-poem motif
with quantitative knobs (density, intensity, etc.) driven by the
poem's projection onto axes the generator declared. Adding a new
Tier 2 motif is the same one-line registry addition that Tier 1
already supports.

## Already Done (pinwheel geometry)

`compute_tier2_art_spaces` was rewritten before this issue lands to
implement the pinwheel layout — each strip extends into one adjacent
corner area so the four strips together claim every corner of the
bounding region without overlap:

- TOP    extends into the INNER corner   (width = box.width + column_gap)
- INNER  extends into the BOTTOM corner  (height = box.height + line_height, downward)
- BOTTOM extends into the OUTER corner   (width = box.width + outer_w when outer exists)
- OUTER  extends into the TOP corner     (height = box.height + line_height, upward)

Rotation is CW around a left-column box (inner=right) and CCW around
a right-column box (inner=left), creating mirrored flow when the two
columns are viewed as a spread. Left-column poems in the current
15%-shift layout have outer_w=0, so OUTER and BOTTOM's outer-extension
are both omitted — left poems get 3 strips and the bottom-outer /
top-outer corners stay uncovered for them.

See the docstring on `compute_tier2_art_spaces` in `compile-pdf-ai.lua`
for the full geometry contract.

## Suggested Implementation Steps

Split the work into three sub-slices, all of which must land before
Tier 2 produces visually meaningful output:

### Slice A — carve the monolith into generator entries

1. For each of the 19 named branches in `draw_tier2_column_patterns`
   (compile-pdf-ai.lua), move its body verbatim into a new entry in
   `themes/generators.lua`'s `M.tier2` table. Each entry takes the
   same shape as Tier 1 generators:
   ```
   M.tier2.digital_resistance = {
       style_description = "Small green lock symbols suggesting encryption, privacy, technical activism, surveillance resistance.",
       parameters = {
           {name = "lock_count", min = 2, max = 24,
            low_words = "single, isolated, intimate, private",
            high_words = "many, ubiquitous, surveillance, swarmed"},
       },
       draw = function(page, space, params)
           -- relocated body from compile-pdf-ai.lua:1397-ish
       end,
   }
   ```
2. The 19 branch names to migrate (drawn directly from the current
   dispatch chain, in source order):
   `digital_resistance`, `neurodivergence`, `gender_fluidity`,
   `digital_loneliness`, `mutual_aid`, `economic_anxiety`,
   `technomysticism`, `fragmented_consciousness`, `gaming_culture`,
   `environmental_awareness`, `programming_philosophy`,
   `anarchist_theory`, `ai_consciousness`, `local_organizing`,
   `intimate_relationships`, `mental_overflow`, `plural_systems`,
   `economic_systems`, `online_communities`. Plus the default
   fallback becomes its own entry `M.tier2.default` (overwriting
   the current empty stub).
3. Each generator should declare 1–3 parameters with `low_words`/
   `high_words` axes. The current branches use a single `intensity`
   variable hard-coded at 0.8 in the caller — most branches multiply
   it by a fixed count (e.g. `math.floor(12 * i)` for lock count).
   Migrating those `12 * i` patterns to a percentile-driven
   parameter is the substantive part of this slice. The axis-words
   should describe content that would push the count toward its
   high vs low end.
4. The pinwheel strip ordering (`top, bottom, inner, outer`) is now
   guaranteed by `compute_tier2_art_spaces`. Generators that want to
   treat the four strips differently can switch on the strip index;
   most current branches treat all strips the same and just draw
   into whatever `cb` rectangle they receive.

### Slice B — per-poem percentile pre-pass

5. In `compile-pdf-ai.lua`, add `POEM_PERCENTILES = {}` global with
   the structure `POEM_PERCENTILES[poem_index][theme_name][param_name]
   = float ∈ [0, 1]`. Parallel to the existing PAGE_PERCENTILES, but
   keyed by poem instead of page.
6. New `compute_poem_axis_percentiles(book)` function, called from
   `main()` right after `compute_axis_percentiles(book)`. For each
   cluster in THEMES with `tier2_parameter_axes`:
   - For each poem in `book.poems`, project its whole-poem embedding
     (`poem._full_text` already attached in build_book) onto each
     axis. Skip empty / short poems with the 0.5-percentile default.
   - Rank-percentile across all poems per (theme, param) pair.
   - Store at `POEM_PERCENTILES[i][theme][param]`.
   - Cost ~ 50 clusters × 2 axes × 7800 poems × 768 dim ≈ 600M ops,
     ~5s with FFI. Run once at startup.
7. To enable runtime lookup, `build_book` needs to attach the poem's
   ordinal index to each placed poem-table (similar to how
   `_full_text` was attached in Issue 029). Add
   `poem._index = original_book.poems_index` in the same loop that
   sets `_full_text`. For segments split by `append_long_poem`, the
   index inherits from the parent poem.

### Slice C — runtime switch

8. Rewrite `generate_individual_poem_art` to use the registry,
   mirroring what `draw_theme_art_in_spaces` does for Tier 1. The
   loop becomes:
   ```
   for poem_num, box in ipairs(layout.left) do
       local poem_theme = analyze_individual_poem_for_tier2(box.poem)
       local theme_info = THEMES[poem_theme] or THEMES.neutral
       local gen_name   = theme_info.tier2_generator or "default"
       local gen_entry  = generators.tier2[gen_name] or generators.tier2.default
       local art_spaces = compute_tier2_art_spaces(box, true, ...)
       local params     = (box.poem._index
                           and POEM_PERCENTILES[box.poem._index]
                           and POEM_PERCENTILES[box.poem._index][poem_theme])
                          or {}
       for _, space in ipairs(art_spaces) do
           gen_entry.draw(pdf_page, space, params)
       end
   end
   ```
   Same for the right-column loop.
9. Delete the entire `draw_tier2_column_patterns` function from
   `compile-pdf-ai.lua` (currently ~600 lines, lines ~1362-1957).
   Its content has been distributed across `M.tier2` entries in
   `themes/generators.lua`.
10. Re-run `./run themes-rebuild` (auto-rebuild via the Issue 030
    Phase 4 stale check will catch the change to
    `themes/generators.lua` automatically). The taxonomy regenerates
    with cluster→tier2_generator mappings keyed to the new
    generator pool — clusters whose centroids align with
    `programming_philosophy.style_description` start picking that
    generator, etc.

## Relevant Files

- `compile-pdf-ai.lua` (`draw_tier2_column_patterns` to delete;
  `generate_individual_poem_art` to rewrite; `compute_poem_axis_percentiles`
  and `POEM_PERCENTILES` to add; `build_book` to attach `_index`)
- `themes/generators.lua` (`M.tier2` to populate with 20 entries)
- `themes-v2/name-clusters.lua` (Phase-2 mapping already handles
  tier2; the new generators automatically pick up the next themes-
  rebuild without code changes here)
- `themes/derived-taxonomy.lua` (regenerated by themes-rebuild)

## Design Notes

**Why per-poem percentiles and not per-page.** Tier 1 renders one
big motif per page, so per-page percentiles match the granularity of
the visual. Tier 2 renders per poem, and poems on the same page can
sit in very different parts of embedding space (a programming poem
next to a poem about grief). A per-page percentile would average
their projections, washing out the distinction. Per-poem keeps each
poem's motif tuned to its own content.

**Why the pinwheel rotation matters more for Tier 2.** Tier 1 sits
in big rectangular regions (bottom strip, outer margins) that have
clear visual boundaries. Tier 2 sits in thin strips that wrap a
box — without the pinwheel, the corners are unclaimed dead space
that breaks the visual continuity of any motif drawn across the
strips. With the pinwheel, motifs flow around the box like art on
a Möbius strip.

**Why the legacy `draw_tier2_column_patterns` gets deleted, not
left as a fallback.** Per the project's "fallbacks are warnings,
warnings are errors" rule: leaving the legacy function present
would let bugs in the new registry silently fall back to it,
masking the failure. After this issue, every Tier 2 path goes
through the registry. If a cluster has no `tier2_generator`
assigned (taxonomy is stale, etc.), the auto-rebuild catches it.
If the assigned generator doesn't exist in the registry, the
runtime falls back to `M.tier2.default` (which is the migrated
old fallback) — and that's the only fallback.

**Why `intensity` parameter goes away.** The current code's
`intensity` is just a constant 0.8 baked at the caller; every
generator multiplies its count by `intensity`. Under the new
system, "intensity" is just one of several axes a generator may
declare (e.g. as `density` or `count`), driven by per-poem
percentile rather than a fixed value. Some generators may want a
single intensity-style axis; others may want independent count,
length, and density axes. The registry pattern is permissive.

**Why the order of slices matters.** Slice A (carve-up) can land
without B/C and just sits unused — the runtime still goes through
the legacy path until Slice C flips the switch. Slice B (per-poem
percentiles) is also additive; it computes POEM_PERCENTILES but
nothing reads it until Slice C. Slice C (the runtime switch) is the
breaking change — it removes the legacy path and starts consuming
both new pieces. Landing A and B first then C as a small final
flip keeps the diff legible and the rollback path simple.

**The 0.5-percentile default for missing data.** Same convention as
the existing PAGE_PERCENTILES code: a poem whose embedding is
unavailable (cache miss, too short, etc.) gets `0.5` for every
param, putting it at the middle of every axis. This produces
"average" art rather than degenerate art, and is consistent with
the existing behavior of `compute_axis_percentiles`.
