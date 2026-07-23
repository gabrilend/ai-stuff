# 11-007: Word-Cloud Word Strip Atop Each Similar / Different Page

## Status
- **Phase**: 11 (Advanced Exploration)
- **Priority**: Medium
- **Type**: Enhancement
- **Status**: Open
- **Builds on**: 8-043/8-050 (word cloud + word embeddings & colors), the
  similar/different page generator, 11-005 (page polish)

## Current Behavior

Each poem has paginated "similar" and "different" pages, rendered by
`M.generate_paginated_poem_page_html(starting_poem, sorted_poems, page_type, ...)`
in `src/flat-html-generator.lua` (`page_type` is `"similar"` or `"different"`).
Each page shows a slice of `sorted_poems` (the ranked neighbours), sized by
`config.pagination.poems_per_page`. The pages show poems only — they make no use
of the word cloud.

The word cloud already computes, per model, two caches in the embeddings dir:
- `word_embeddings.json` — `{ word -> embedding }` for the word-cloud word set
  (produced by `src/generate-word-pages.lua`: `load_word_embeddings_cache`,
  `M.generate_word_embeddings`).
- `word_colors.json` — `{ word -> color }`, the SAME colors the cloud renders each
  word in (`compute_word_colors(word_embeddings)` in the same file).

Poem embeddings live in `embeddings.json` (same dir). Nothing currently relates
the word set to the poems shown on a given similar/different page.

## Intended Behavior

A strip of **K word-cloud words across the top of each page** (K from config,
default 20, NO CLI flag). The strip **represents the poems actually shown on that
page** — and the SAME selection system is used on similar AND different pages.

- One system, both pages. The similar/different distinction already lives in
  *which poems the page shows* (a tight cluster on a similar page; a diverse
  spread on a different/diversity page). The strip just describes whatever poems
  are present, so a similar page gets words for its cluster and a different page
  gets words spanning its spread. (Rejected: "farthest words from the poems" for
  the different page — those would describe things NOT on the page, which is
  useless and confusing; "the different of different" is not "similar".)
- Each word is rendered in the SAME color it has in the word cloud (from
  `word_colors.json`) and links to that word's word-cloud page, so the strip is
  both recognizable across pages and navigational.

"The poems present on that page" = the specific paginated slice of `sorted_poems`
shown there, so page 1 and page 2 of the same list get different strips.

### Selection method: vote the per-poem winners, do NOT sum the scores

The goal is to surface the ENDS of the page's spectrum (if the page leans "trains"
at one end and "bananas" at the other, show both), with the middle represented in
proportion to how many middle poems there are.

Summing each word's cosine across the page's poems does NOT do this — it is
algebraically a centroid comparison: `Σ_i cos(w, p_i) = |C|·cos(w, C)` where `C`
is the centroid of the unit poem vectors and `|C|` is constant across words. So
"sum of scores" ranks identically to "cosine to the average," which rewards the
word moderately close to everything (e.g. "grocery store") over the extremes
("trains", "bananas"). That is the opposite of the goal.

Instead, **count wins, not scores**: each poem on the page casts exactly ONE vote
— for its single nearest word-cloud word. A train poem votes "trains", a banana
poem votes "bananas", a middle poem votes for a middle word — so the ends appear,
and the middle scales with the number of middle poems (the page is itself a
spectrum). Those votes RANK the candidates; the final K are then chosen by a
diversity pass (below), because this word cloud is very synonym-heavy and raw
vote order alone would fill the strip with near-duplicates of the busiest region.

Worked example (5-poem page; cosine of each poem to three illustrative words):

    poem            trains  grocery  bananas      one-vote winner
    A (very train)   0.88     0.45     0.10        trains
    B (train-ish)    0.80     0.48     0.18        trains
    C (middle)       0.50     0.62     0.50        grocery
    D (banana-ish)   0.18     0.48     0.80        bananas
    E (very banana)  0.10     0.45     0.88        bananas

Summing scores would crown the bland middle (grocery 2.48 > trains 2.46 = bananas
2.46) — and so would rank/Borda voting (grocery 11 > trains 10 > bananas 9), for
the same centroid reason. One-vote tally gives trains 2, bananas 2, grocery 1:
the ends win, the middle appears in proportion. A single very-strong match earns
exactly one vote, so no lone poem can hijack the strip; a whole region of the page
reliably surfaces its word.

### Diversity pass: MMR over the vote tally (the word cloud IS synonym-heavy)

The word cloud has many near-synonyms (train / locomotive / railway), so picking
the top-K by raw vote order would clog the strip with duplicates of the busiest
region. After tallying, choose the K words greedily with a Maximal Marginal
Relevance penalty:

    selected = {}
    repeat K times:
        pick the candidate w maximizing:  votes(w) - lambda * max_{s in selected} sim(w, s)
        add w to selected

`sim` is word<->word cosine over the word-cloud words. Slot 1 is always the
top-voted word (nothing selected yet, no penalty); each later slot avoids words
too similar to ones already chosen — so "train" wins a slot but "locomotive" /
"railway" get suppressed while a distinct word ("bananas", sim ~ 0, no penalty)
rises. `lambda` (config, mild default) tunes it: 0 = pure popularity (raw top-K),
too high = it starts preferring low-vote oddballs just for being different. This
is the two-stage split that keeps it controllable: VOTES answer "how much of the
page cares about this word", the PENALTY answers "have I already covered this
region" — kept separate rather than tangled into a transfer-election (STV/IRV),
whose transfers in embedding space would instead reinforce the dominant region.

## Suggested Implementation Steps

1. **Candidate words, colors, and word<->word similarity.** Load
   `word_embeddings.json` and `word_colors.json` once per run (per-model, via
   `utils.embeddings_dir()`). The candidate set is exactly the word-cloud words.
   Also build (and cache) the word<->word cosine matrix over that set — it is
   small (W x W, W = word-cloud size) and is what the MMR diversity pass penalizes
   against. Reuse `model-evaluator.cosine` / `fuzzy-computing.cosine_similarity`.
2. **Precompute poem -> its single nearest word ONCE, and cache it.** A poem's
   nearest word-cloud word does not depend on which page it appears on, so it is
   computed a single time over all poems (one poem x word pass — the same shape as
   the similarity stage; reuse `fuzzy-computing.cosine_similarity` /
   `model-evaluator.cosine`, or the GPU batch path if needed) and written to a
   cache in the embeddings dir (e.g. `poem_top_word.json`: `{ poem_index -> word }`).
   Regenerate when embeddings change (freshness check like the other caches). This
   is the only heavy work; it replaces re-scoring poems on every page.
3. **Per-page selection (cheap).** Inside `generate_paginated_poem_page_html`,
   gather the cached nearest word of each poem on this page and tally the votes,
   then run the MMR diversity pass (votes minus `lambda` x max similarity to
   already-picked words) to choose the final K. Identical for `similar` and
   `different` (the page's poem set already carries the distinction). No per-page
   embedding math — just counting plus K small penalty lookups in the cached
   word<->word matrix.
4. **Render the strip** at the top of the page body, each word in a span styled
   with its `word_colors.json` color and linked to that word's word-cloud page.
5. **Config.** Add to `config.lua` `word_cloud`: `page_word_strip_count` (K,
   default 20) and `page_word_strip_diversity` (`lambda` for the MMR penalty, a
   mild default). Read where the page is rendered. No CLI flags (per request).
   (Each poem casts one vote, so there is no per-poem vote-depth knob.)
6. **Performance note.** Per-page cost drops to lookups + counting over
   ~`poems_per_page` cached lists — trivial across the tens of thousands of pages.
   The cost moves to step 2's one-time precompute; size it like the similarity
   stage and cache it. Measure before reaching for the GPU path.

## Related Documents / Tools

- `src/flat-html-generator.lua` — `generate_paginated_poem_page_html` (where the
  strip is injected; knows the page's poem slice and `page_type`).
- `src/generate-word-pages.lua` — `word_embeddings.json` and `word_colors.json`
  producers (`load_word_embeddings_cache`, `compute_word_colors`).
- `embeddings.json` (poem embeddings), `utils.embeddings_dir()` (per-model paths).
- `libs/fuzzy-computing.lua` `cosine_similarity` / `libs/model-evaluator.lua`
  `cosine` — reuse for ranking.
- `config.lua` `word_cloud` section — home for the count.

## Resolved (decided 2026-06-30)

- **Same system for both pages.** The strip represents the poems shown; the
  similar/different difference is carried by the poem set, not by the word
  selection. (Dropped the earlier "farthest words" idea for the different page.)
- **Selection = one vote per poem for its single nearest word; tally; keep top K.**
  Summing cosine across poems is algebraically a centroid comparison and surfaces
  the bland middle ("grocery store") instead of the spectrum ends ("trains",
  "bananas"); rank/Borda voting has the same centroid bias. One vote per poem gives
  the ends and scales the middle with the poem distribution, and no single
  very-strong poem can dominate (it is worth exactly one vote). See "Selection
  method" above.
- **Diversity pass (MMR) over the tally, ON by default.** The word cloud is very
  synonym-heavy, so after the vote tally the final K are chosen greedily with a
  similarity penalty (`votes - lambda * max-sim-to-already-picked`), suppressing
  near-duplicates (train/locomotive/railway) so distinct regions (bananas) get a
  slot. Two stages kept separate: count, then diversify. See "Diversity pass".
- **Strip words link to their word-cloud pages**, and inherit `word_colors.json`
  colors.

## Open Questions (minor)

- **Tie-breaking** when several words tie on vote count right at the K cutoff: fall
  back to summed cosine among the tied set, or to word-cloud prominence? (Edge case;
  pick one when building.)
