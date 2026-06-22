# Issue 027: --natural-themes Flag To Disable Frequency Weighting

## Current Behavior

Every theme selection in the PDF generator runs through
`fuzz.find_most_similar_theme_weighted` (in `libs/fuzzy-computing.lua`),
which multiplies the cosine similarity between the page/poem
embedding and each candidate theme embedding by a
**diversity boost**:

```
diversity_boost = 1 / (1 + picks/10)
```

A theme picked 100 times so far gets ~9% of its real similarity
score and rarely wins again. Three call sites use this:

- Tier 1 (page background art) in `analyze_page_themes`
- Tier 2 (per-poem art around each box) in
  `analyze_individual_poem_for_tier2`
- Tier 3 (per-poem background color) in
  `analyze_individual_poem_theme`

The mechanic is intentional — it spreads theme assignments
evenly across the whole book so a 500-page run doesn't end up
with one theme on 400 pages. But the per-page picks read as
arbitrary: a poem about programming might end up tagged
`anarchist_theory` because `programming_philosophy` has already
been picked too many times.

There is no way to compare the weighted output to the unweighted
output without editing source and risking a stale dead-code
branch.

## Intended Behavior

A `--natural-themes` flag exposed by `./run` and parsed by
`compile-pdf-ai.lua` selects each theme by raw cosine similarity
alone — no frequency penalty, no diversity boost. The unweighted
function `find_most_similar_theme` (already present in
`libs/fuzzy-computing.lua`) is used at every call site that
currently calls the weighted variant.

When the flag is on:

- The startup banner mentions natural-themes mode is active, so
  the operator does not mistake an unbalanced run for a bug.
- The per-page log line for Tier 1 theme selection drops the
  `weighted: %.3f` field (it would just duplicate the raw value).
- `track_theme_selection` still records counts so the end-of-run
  statistics print still works — counts just no longer influence
  the next pick.

When the flag is absent the behavior is identical to today's.

The flag is invariant under position — `./run --natural-themes`,
`./run pdf --natural-themes`, `./run pdf reverse --natural-themes`,
etc. all work. `./run`'s existing positional arg parsing (the
optional `pdf|web|web-chatbot|...` mode and `normal|reverse`
ordering) is unaffected, because the flag is filtered out of
`$@` before the mode dispatch.

## Suggested Implementation Steps

1. In `./run`, near the top before the mode dispatch:

   - Loop over `"$@"`, build a `FILTERED_ARGS` array that excludes
     `--natural-themes`, set `NATURAL_THEMES_FLAG="--natural-themes"`
     if seen.
   - `set -- "${FILTERED_ARGS[@]}"` to overwrite the positional
     args so the rest of the script's `${1:-pdf}` checks see the
     cleaned list.
   - Append `$NATURAL_THEMES_FLAG` (unquoted, so empty disappears)
     to every `lua5.2 ./compile-pdf-ai.lua ...` invocation.

2. In `compile-pdf-ai.lua`:

   - Near the top, scan `arg[]` for `--natural-themes`, assign a
     module-level `NATURAL_THEMES = true` if found.
   - At each call site that uses `fuzz.find_most_similar_theme_weighted`,
     branch on `NATURAL_THEMES`: if true, call the unweighted
     `fuzz.find_most_similar_theme` and synthesize the
     `weighted_score` return value (alias it to `raw_similarity`).
   - When `NATURAL_THEMES` is true, print a startup banner so the
     operator knows which mode they are in.

3. No changes to `libs/fuzzy-computing.lua` — the unweighted
   function it already exports is the one the flag steers to.

## Relevant Files

- `compile-pdf-ai.lua` (arg parsing; three theme-selection call
  sites at `analyze_page_themes`, `analyze_individual_poem_for_tier2`,
  `analyze_individual_poem_theme`)
- `run` (flag-extraction loop, lua invocation tails)
- `libs/fuzzy-computing.lua` (read-only; we just stop calling the
  weighted variant)

## Design Notes

A flag was chosen over an env var because the user invokes
`./run` directly and a flag is more discoverable than a magic
env var. The flag is parsed out of `$@` in `./run` rather than
left in place, because `./run`'s existing positional-arg
checks would mis-classify it as a mode or ordering value.

The unweighted variant is expected to collapse the run toward
whichever themes sit closest to the corpus's embedding-space
centroid — i.e. one or two themes dominating. That is the
intended observation: it tells the operator whether the raw
similarity rankings are meaningful per-page or whether the
balanced output was the only thing making the visual variety
work in the first place.
