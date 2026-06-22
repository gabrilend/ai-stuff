# Issue 030: Parametric Generator Registry With Cluster→Generator Mapping

## Current Behavior

The art-rendering pipeline has three layers (Tier 1 page background,
Tier 2 per-poem column patterns, Tier 3 per-poem background colors).
Today they are wired by parallel hand-curated tables, all keyed on
hand-coded theme names:

- `compile-pdf-ai.lua` defines 22 Tier 1 generator functions
  (`generate_resistance`, `generate_technology`, … `generate_neutral`)
  in a single ~600-line block, dispatched via a `theme_generators`
  table keyed on theme name.
- `themes/embedding-driven-params.lua` declares 21 themes' worth of
  parameter axes (positive/negative keyword pairs, low/high range),
  one entry per theme. The `initialize_param_axes` pass at startup
  embeds each pair, computes axis = normalize(embed(positive) -
  embed(negative)), and stores results in `PARAM_AXES[theme_name]`.
- `compute_page_percentiles` projects every page onto every axis once
  per run and ranks pages to produce `PAGE_PERCENTILES[page_num]
  [theme_name][param_name]` ∈ [0, 1].
- At render time each generator receives a `params` table holding
  the percentile-driven values for THIS page under THIS theme.

The system works when the theme names in code match the theme names
the pipeline assigns. Issue 029 broke that alignment by introducing
HDBSCAN-derived cluster names (`fediverse_critique`,
`ramen_recipes`, etc.) that don't appear in `theme_generators` or
`PARAM_AXES`. Under the new taxonomy, every cluster falls back to
the `neutral` generator with 0.5-percentile defaults — the renderer
loses almost all of its visual variety.

Tier 2 has its own problem: `draw_tier2_column_patterns` is one
monolithic function with internal name-based branching, not a
registry of separately-parameterized generators. It can't be wired
to the new system without being split.

Tier 3 is fine as-is: poem background color is a static palette
lookup, no parameters to tune.

## Intended Behavior

Generators become **self-describing**. Each generator declares:

- `draw(page, space, params)` — the function the renderer calls.
- `style_description` — one sentence the cluster→generator mapping
  embeds and compares against cluster centroids to decide assignment.
- `parameters = { {name, min, max, low_words, high_words}, ... }`
  — each parameter is an axis defined by two short keyword lists.
  `low_words` describes content that should yield low parameter
  values; `high_words` describes the opposite end.

A new file `themes/generators.lua` is the single source of truth
for both Tier 1 and Tier 2 generator metadata. Tier 3 stays as the
existing palette lookup — no change there.

`themes-v2/name-clusters.lua` gains two passes after the existing
cluster naming step:

1. **Generator mapping.** Embed every generator's `style_description`
   once. For each cluster centroid, walk all generators and pick the
   one with highest cosine similarity. Fallback to `neutral` only if
   the best match is below a low cutoff (~0.3) — should be very rare.
   Result: `cluster.tier1_generator = "circuit"` (and same for tier2
   once tier2 generators exist).
2. **Axis pre-computation.** For each generator each cluster maps
   to, embed the parameters' `low_words` and `high_words`. Compute
   `axis_vector = normalize(embed(high) - embed(low))`. Store in the
   cluster's record under `tier1_parameter_axes` (and equivalent for
   tier2). One axis per parameter, ~768 floats each.

`compile-pdf-ai.lua` is rewired to consume the new schema. At
startup it loads `themes/generators.lua` (for the draw functions
plus metadata) and `themes/derived-taxonomy.lua` (for clusters,
their assigned generators, and pre-computed axes). The
`PARAM_AXES` / `EMBEDDING_DRIVEN_PARAMS` / `compute_page_percentiles`
machinery is deleted — the new system carries equivalent
information per-cluster, not per-theme-name.

Per-poem rendering becomes:

1. Look up the poem's cluster (existing).
2. Find `cluster.tier1_generator` and `cluster.tier1_parameter_axes`.
3. For each parameter axis, project the poem's embedding onto the
   axis to get a raw score. Across all poems, rank-percentile each
   score. Map percentile linearly to `[min, max]` to produce a
   parameter value.
4. Pass the params table to the generator's `draw` function.

`./run` learns to **auto-rebuild** the taxonomy when stale:

- Compare `themes/derived-taxonomy.lua` mtime against
  `input/compiled.txt` AND `themes/generators.lua`. If either is
  newer than the taxonomy, the taxonomy is stale.
- Stale → transparently invoke `themes-v2/run.sh` before generating
  the PDF. Logs prefix the rebuild output so it's clear which phase
  is running.
- New `--no-rebuild` flag to bypass the check (useful for tight
  iteration cycles where the operator knows the taxonomy is still
  valid for their experiment).
- Default on; the cost is paid once per content change.

## Suggested Implementation Steps

Four phases, each landable and testable independently:

### Phase 1 — registry file + Tier 1 migration

1. Create `themes/generators.lua` exporting `M.tier1` and `M.tier2`.
2. `M.tier1` holds all 22 existing Tier 1 generators. Each entry is
   `{draw, style_description, parameters}`. The draw functions are
   moved verbatim from `compile-pdf-ai.lua`. `style_description` is
   written fresh (one short sentence per generator, based on the
   existing per-generator comments and behavior).
   `parameters` is translated from `themes/embedding-driven-params.lua`
   (keyed by what is currently the theme name but is mechanically the
   generator name): `low → min`, `high → max`, `positive →
   high_words`, `negative → low_words`.
3. `M.tier2` is a stub holding the empty schema. A single entry
   `M.tier2.default` points at the existing
   `draw_tier2_column_patterns` so the runtime keeps working until
   Tier 2 generators get fleshed out. No parameters declared yet.
   **The full Tier 2 carve-up — splitting the monolithic dispatch
   into ~19 individual generator entries, adding per-poem percentile
   pre-pass machinery, and switching the runtime to consume the
   registry — is tracked separately in Issue 031.** That work also
   covers the pinwheel geometry change in `compute_tier2_art_spaces`
   (each strip extends into one adjacent corner area), already
   implemented as part of the Issue 031 baseline.
4. `compile-pdf-ai.lua`'s old `theme_generators` table becomes a
   single-line redirect: `for k, v in pairs(generators.tier1) do
   theme_generators[k] = v.draw end`. Old code paths unchanged.

### Phase 2 — cluster→generator mapping in name-clusters.lua

1. Load `themes/generators.lua` at the top of `name-clusters.lua`.
2. After clusters are named, walk each cluster:
   - Pre-embed every Tier 1 generator's `style_description` once
     (cached across clusters).
   - For each cluster, compute cosine similarity to every generator's
     style embedding. Pick the highest. If < 0.3, assign `neutral`
     and log the fallback (should rarely fire).
   - Pre-embed every parameter's `low_words` and `high_words` for
     the matched generator. Compute axis vectors. Store under
     `cluster.tier1_parameter_axes = { {name, min, max, axis},... }`.
3. Extend the output schema in `themes/derived-taxonomy.lua` to
   include `tier1_generator` (string) and `tier1_parameter_axes`
   (list of named axes with bounds) per cluster. Centroid + members
   + name + description fields stay as they are.

### Phase 3 — runtime consumption

1. `compile-pdf-ai.lua` deletes `PARAM_AXES`, `PAGE_PERCENTILES`,
   `initialize_param_axes`, `compute_page_percentiles`, and the
   require of `themes/embedding-driven-params.lua`.
2. New `compute_taxonomy_percentiles(book)` pass at startup: for
   each cluster, project every poem in the corpus onto each of the
   cluster's parameter axes, then rank-percentile by axis. Store as
   `POEM_PARAMS[poem_id][cluster_id][param_name]` ∈ [0, 1] (or a
   thinner per-poem-only lookup if memory tight).
3. `generate_page_art` looks up the assigned cluster's generator
   from the taxonomy, computes its params from the percentiles
   table for the representative poem (or page-average), and calls
   `generators.tier1[name].draw(page, space, params)`.
4. `themes/embedding-driven-params.lua` is deleted.

### Phase 4 — auto-rebuild in ./run

1. Replace `assert_themes_fresh` with `ensure_themes_fresh_or_rebuild`.
   New behavior: if taxonomy is missing OR older than corpus OR older
   than `themes/generators.lua`, run `themes-v2/run.sh "${DIR}"`
   inline before the PDF generation step.
2. Honor `--no-rebuild` flag (parsed alongside `--natural-themes`)
   to skip the auto-rebuild even when stale.
3. Echo a clear marker before the rebuild output so the operator
   can tell from logs which sub-pipeline produced which lines.

## Relevant Files

- `themes/generators.lua` (new, Phase 1)
- `themes/derived-taxonomy.lua` (schema extended in Phase 2)
- `themes/embedding-driven-params.lua` (deleted in Phase 3)
- `themes-v2/name-clusters.lua` (extended in Phase 2)
- `compile-pdf-ai.lua` (Phase 1 redirect, Phase 3 rewire/delete)
- `run` (Phase 4 auto-rebuild)
- `libs/art-primitives.lua` (read-only; the generator draw functions
  use its primitives unchanged)

## Design Notes

**Why generator parameters, not theme parameters?** The previous
system tied parameters to theme names. With cluster discovery
producing unpredictable theme names, the only stable axis of
identity is the generator (a small set of hand-written art
functions). Tying parameters to the generator means any cluster
that picks "circuit" inherits "circuit"'s parameters; no
per-cluster authoring required.

**Why centroids stay anchored on the core?** The cluster's identity
(its centroid) is computed from HDBSCAN's dense-region members
only, NOT recomputed after the noise-reassignment pass (Issue 029).
This keeps the cluster→generator mapping driven by the densest,
most semantically coherent slice of the cluster rather than being
diluted by loose members.

**Why per-poem percentiles instead of per-page?** The old system
ranked per-page because Tier 1 art renders per-page. Tier 2 (when
it lands) renders per-poem. Per-poem percentiles serve both, and
collapsing to page-level for Tier 1 is a single mean operation at
the call site.

**Why `--no-rebuild` matters.** During iterative work on the
renderer (tweaking generators, layout, palette), the taxonomy is
stable but `themes/generators.lua` mtime advances every time you
save. Without an opt-out, every renderer test would trigger a
~3-minute rebuild. The flag is the escape valve for "I know what
I'm doing, just render."

**Why Tier 3 stays static.** Tier 3 is just an RGB color per
poem-background-fill. There's no parameter to tune that improves
it. The static `palette.tier3_backgrounds` keyed on cluster name
(once we backfill entries for the new names) is sufficient. If
later we want per-poem color variation, it's a small additive
issue that doesn't disturb this architecture.

**Why the cluster→generator threshold should be very rare.** If a
cluster regularly fails to find a matching generator, the
generator pool isn't covering the corpus's semantic territory —
that's a signal to add a new generator, not to silently fall back.
Logging the fallback makes the signal visible.
