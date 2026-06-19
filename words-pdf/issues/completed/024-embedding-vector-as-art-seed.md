# Issue 024: Embedding Vector as Art Seed

## Current Behavior
The art-generation pipeline uses embeddings only for *classification*:
each page's text is embedded, then cosine-similarity scored against the
22 Tier 1 / 20 Tier 2 / 40 Tier 3 theme vectors, and the winning theme
name is kept. The other 767 dimensions of the embedding vector and every
non-winning similarity score are discarded.

Generators then use `math.random()` for everything except the theme
selection — random angles, random positions, random densities, random
color picks from a fixed palette. So two pages classified as the same
Tier 1 theme produce visually similar but unrelated art: same generator,
same accent colors, but the *specific shape* of each rendering is
arbitrary per-call rather than determined by the poem's content.

This is a double waste: rich per-poem semantic information goes in one
end and gets thrown away, while random entropy goes in the other end
with no connection to the text.

## Intended Behavior
Each generator parameter (curve count, sway magnitude, ring count, etc.)
is driven by the poem's embedding via **concept projection**: a directed
axis between two keyword lists. Specifically:

- Each parameter has a hardcoded config row with `name`, `low`, `high`,
  and two keyword lists (`positive` for the high-extreme keywords,
  `negative` for the low-extreme keywords)
- At startup, every keyword list is embedded once (cached via Issue 017)
- For each parameter, the axis is computed as
  `normalize(positive_vec - negative_vec)`
- For each poem, the projection score is `dot(poem_vec, axis)` — a single
  float saying how far along that axis the poem leans
- Across the corpus, projection scores are sorted and assigned percentile
  ranks (0.0 through 1.0); the percentile, not the raw score, drives the
  parameter value
- The percentile maps linearly to the parameter's `[low, high]` range:
  `value = low + percentile * (high - low)`

Result: same-theme pages still get the same generator, the same color
family (preserving visual coherence), but parameter values that
deterministically track poem content. A reader sees the visual language
*mean something* — a high-percentile-on-"interwoven" poem really does
get more curves than a low-percentile one.

## Suggested Implementation Steps
1. Create `themes/embedding-driven-params.lua` with the config table.
   Each generator that wants parameter variation contributes a row per
   parameter. Format:
   ```lua
   {
       name = "curve_count", low = 4, high = 14,
       positive = "interwoven, connection, bonds, ties, woven, joined, linked, entangled",
       negative = "isolated, alone, separated, solitary, apart, disconnected, severed",
   }
   ```
   Keyword lists, not sentences — shared filler like "this writing
   describes" dilutes the discriminating signal.
2. At PDF generation startup, walk the config and embed every keyword
   list (positive + negative for every parameter). With Issue 017's
   cache, this is a one-time cost. Compute and store each axis as a
   normalized vector.
3. Add a corpus-scoring phase between "load all poems" and "render
   pages": embed every poem (cached via Issue 017), compute projection
   scores for every (poem, parameter) pair, sort by parameter, assign
   each poem its percentile rank per parameter. Store in a table:
   `percentiles[poem_id][theme_name][param_name] = float in [0, 1]`.
4. Cache the percentile table to disk at
   `tmp/parameter-percentiles.lua` (similar format to the embedding
   cache). Invalidate when config keyword lists change — hash the
   config to detect this.
5. Modify generator function signatures to take `poem_id` as an
   additional parameter, and have them consult the global percentiles
   table to look up their parameter values instead of calling
   `math.random()` for the same purposes.
6. Start with one generator end-to-end (suggested:
   `generate_transcendence` since the mandala has many natural knobs)
   to validate the mechanism. If visual quality improves on that one,
   roll out to all 22.

## Worked example
A poem scoring 73rd-percentile on the "interwoven" axis and 22nd
percentile on the "wild dramatic motion" axis:

- `curve_count = floor(4 + 0.73 × 10 + 0.5) = 11` curves
- `sway_magnitude = 10 + 0.22 × 40 = 18.8` units of sway

The connection page renders with 11 curves swaying gently — "many bonds
here, held with restraint."

A different poem at 18th percentile interwoven / 95th percentile drama:

- `curve_count = floor(4 + 0.18 × 10 + 0.5) = 6` curves
- `sway_magnitude = 10 + 0.95 × 40 = 48` units of sway

That page gets 6 dramatically arcing curves — "few links here, but the
ones that exist are turbulent."

## Related Documents
- `tmp/embedding-vector-as-seed-design.md` — the speculative design doc
  this issue formalizes; the doc has additional rationale and worked
  examples that didn't fit the issue-file format
- `libs/fuzzy-computing.lua` — `get_embedding`, `cosine_similarity`,
  `find_most_similar_theme_weighted`; new functions needed for axis
  computation and percentile ranking
- `themes/palette.lua` — generator color palette; this issue doesn't
  change palette structure but adds a parallel parameter system
- Issue 017 — embedding cache, prerequisite (without it this design's
  cold-start cost is prohibitive)
- Issues 019, 022, 023 — visual-quality issues this complements

## Metadata
- Priority: Medium-low (visual quality lift, but project ships fine
  without it; the previous visual-quality issues 019-023 are higher
  impact)
- Complexity: High
- Dependencies: Issue 017 (caching is prerequisite, not optional)
- Estimated Effort: Large

## Implementation Notes
**Determinism is the headline feature.** Don't mix `math.random()` into
embedding-driven generators. Either fully use the percentiles or fully
don't. Mixing produces variation that's neither random-looking nor
content-tracking — the worst of both worlds.

**Keyword lists are the design surface.** Each generator's parameter
behavior is set by 2-7 keywords per direction × 2 directions per
parameter. That's the entire creative interface. Pick keywords that
unambiguously identify the extremes of a meaningful axis — pairs where
the positive and negative are clearly *opposite*, not just *different*.

**Start with one generator.** The full rollout is 22 generators × ~3
parameters each × 2 keyword lists each ≈ 130 keyword lists to write.
That's a meaningful authorship task. Validate the mechanism on
`generate_transcendence` first, see if the variation reads as
meaningful, refine the keyword-writing approach, then scale.

**Percentile rank vs raw score.** Calibrating against the corpus via
percentile rank (rather than mapping raw cosine similarity to a fixed
range) ensures every value in [low, high] is reached by roughly the
same number of poems. Without it, parameter values cluster around the
middle because real cosine scores rarely span [-1, 1] — they cluster
in narrow bands like [0.2, 0.6]. The percentile rank uses the full
output range regardless of how concentrated the input distribution is.

**The dispatch table from Issue 019 doesn't change.** Generators are
still looked up the same way; their signatures just gain `poem_id`.
