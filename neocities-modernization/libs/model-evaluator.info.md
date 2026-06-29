# model-evaluator.lua

Pure comparison + statistics for the embedding-model evaluation framework
(Issue 10-031). No IO, no model/server knowledge — it takes plain Lua tables
(vectors and text) and returns plain Lua tables, so the math is testable in
isolation and the generation/orchestration layer owns the messy parts.

Used by `src/model-comparison.lua` (the `report` step). See also
`scripts/evaluate-embedding-models` (the orchestrator) and Issue 10-031.

## Functions

### `M.cosine(a, b) -> number`
Cosine similarity of two equal-length vectors. Only ever compared *within* a
single model's space (dimensions differ across models), so absolute values are
per-model and only rankings are compared between models.

### `M.rank_anchor(anchor_vec, pool, exclude_index, top_k) -> list`
Rank every vector in `pool` (map of `poem_index -> vector`) by cosine to
`anchor_vec`, nearest first, dropping `exclude_index` (the anchor itself).
Returns an array of `{ poem_index, score }`, length `min(top_k, #pool-1)`.
Deterministic tiebreak (poem_index ascending).

### `M.topk_agreement(rank_a, rank_b, k) -> number`
How many poems appear in BOTH rankings' top-k (set overlap, order ignored). The
headline "do the models even pick the same poems" number.

### `M.kendall_tau(rank_a, rank_b) -> (number|nil, n)`
Kendall's tau-b over the poems the two rankings share: +1 identical order, 0
unrelated, -1 reversed. Returns `nil, n` when fewer than two items are shared
(correlation undefined). O(n²) in the shared set — fine for top-N slices.

### `M.lexical_jaccard(text_a, text_b) -> number`
Jaccard overlap of the two poems' lowercased word sets, in [0,1]. High = they
literally share words (surface/structural kinship); low = a model called them
similar despite little shared vocabulary (so it rewards meaning/theme/tone, not
words). The crude "surface similarity" contrast to the neural models.

### `M.personality(anchor_text, anchor_len, ranked, texts, lengths, k) -> table`
Turn a model's top-k matches for one anchor into interpretable signals:
- `mean_jaccard` — avg word-overlap of anchor with its top matches (surface lean)
- `mean_len_ratio` — avg `min/max` of word counts (near 1 = length bias)
- `mean_score` — avg cosine of the top matches (per-model neighbourhood tightness)
- `n` — how many matches contributed
Descriptive, not a verdict — the report shows them for a human to interpret.

### `M.mean(list) -> number|nil`
Arithmetic mean of a numeric array, or `nil` if empty (so callers render "n/a"
rather than divide by zero).
