# Issue 8-050b: Colour on Word Pages — Read the Stored Verdict, Rank by Relevance

## Priority
Medium

## Current Behavior

Each word page lists the poems closest in meaning to one word, in descending order
of that closeness, and draws each poem's progress bar in that poem's semantic
colour. The colour is **read** from the precomputed per-poem table; it is not
re-derived at display time. Ordering and colour are independent: colour decorates
the page, it does not decide who appears on it or in what order.

## Intended Behavior

Two rules, and the second is the one this issue exists to record.

### 1. The page is ordered by relevance and says so truthfully

The heading tells the reader the poems are ranked by semantic similarity, so they
are. Slot 1 holds the best match. Nothing reorders the list after it is sorted.

### 2. A poem's colour comes from `poem_colors.json`, never from a fresh cosine

The colour a poem carries is decided once, by the semantic colour calculator, and
stored. Every consumer reads that stored verdict. A page that recomputes the
colour from the colour anchors at render time will disagree with the rest of the
site, because the calculator does something the naive recomputation does not:
it **z-scores** each poem's similarity against that colour's corpus-wide mean and
standard deviation, and picks the colour the poem sits furthest *above baseline*
for, rather than the colour it is merely nearest to.

## Why Raw Nearest-Cosine Is Not a Colour Contest

This is the substance of the issue, and it is measurable.

Ranking the seven colour anchors by how close each one sits to the **average
poem** reproduces, almost exactly, how often each one wins a raw nearest-cosine
contest across the corpus:

| anchor | cosine to corpus mean | share of corpus won (raw) |
|--------|----------------------|---------------------------|
| purple | 0.9423 | 30.9% |
| blue   | 0.9397 | 17.2% |
| red    | 0.9391 | 20.4% |
| yellow | 0.9378 | 14.6% |
| gray   | 0.9369 | 5.8% |
| green  | 0.9356 | 7.2% |
| orange | 0.9332 | 3.9% |

A spread of 0.9% in "how generic is this anchor" produces an eightfold spread in
how often it wins. Under raw nearness the contest is not about what a poem means;
it is about which anchor happens to sit nearest the middle of everything. That is
the same anisotropy the model imposes on every vector it produces, surfacing in a
second place.

The z-scored assignment removes it. The stored distribution across 8,510 poems is
even — roughly 12% to 19% per colour — where raw nearness gives one colour a
third of the corpus.

`config.lua` already records the first half of this lesson, in the comment above
`color_associations`: the *bare word* "red" embeds to a generic point that
swallowed ~38% of all poems by raw nearness, which is why each colour's anchor is
the mean of a hand-written association list (fire, blood, passion, rage…) rather
than the colour word alone. The z-scoring is the second half of the same lesson.
Good anchors are necessary and not sufficient; the comparison has to be
standardised too.

## Why the Colour Round-Robin Was Removed

An earlier version of this issue specified a cumulative-similarity-balanced
round-robin: bucket the top N poems by colour, then deal them back out choosing
whichever colour had the lowest running total, so the page would show all seven
colours spread evenly down its length. It was implemented, then walked back once
(it had been allowed to *displace* strong matches with weaker colour-diverse
ones — a "god" search surfaced unrelated poems), and has now been removed
entirely. Two reasons:

**It made the page contradict its own heading.** Measured on the word "linux"
with a 333-poem page: the 53rd-best match landed in slot 3, the 251st in slot 8,
and the second-best match waited until slot 10. A reader told the list is ranked
by similarity was reading something else.

**It sorted on colours that were not the site's colours.** The round-robin
re-derived each poem's colour by raw nearest cosine while the progress bar beside
it was drawn from the stored z-scored verdict. The two disagreed on 33% of a
page. So the reorder was spreading the page across a measurement of genericness,
and doing it in colours the reader could not see.

The visual variety the round-robin was meant to produce survives without it: each
bar is still drawn in its own poem's colour, and that colour is now the same one
every other page type uses.

## Suggested Implementation Steps

1. Rank every poem against the word by cosine similarity, sort descending, take
   the top N. Show them in that order.
2. Read `poem_colors.json` positionally — the array position **is** the
   `poem_index`; entries carry `color` and `similarity` but no index field.
3. Pass the stored colour to the bar renderer. Do not load the colour anchors in
   the page builder at all; the only routine that needs them is the one assigning
   colours to **words**, which has no precomputed table to read from.
4. Delete any bucket-and-deal selection step.

## Validation

- The first poem on a word page is the highest-scoring poem for that word.
- A poem's bar colour on a word page matches its colour on the chronological and
  similar/different pages.
- No colour appears on more than roughly a third of any page, because the stored
  distribution is already even — but this is an observation, not a target to
  enforce.

## Related Documents

- Issue 8-050: Enhance Word-Cloud Semantic Similarity Pages (parent)
- Issue 8-050a: Compute Semantic Color for Each Word-Cloud Word
- Issue 8-050c: Apply Word Color to Word-Page Progress Bars
- Issue 8-019: the poem_index rule — the word page also had its embedding lookup
  keyed on the colliding per-category `id`, which is what made its rankings look
  random regardless of colour
- `src/semantic-color-calculator.lua` — the z-scored assignment, and the only
  place a poem's colour is decided
- `config.lua` — `color_associations` (the anchors) and `semantic_colors` (the hex)
- `assets/embeddings/<model>/poem_colors.json` — the stored per-poem verdict

## Metadata

- **Status**: Completed
- **Created**: 2026-01-26
- **Completed**: 2026-01-28
- **Revised**: 2026-08-23 (round-robin removed; stored colours read instead of recomputed)
- **Phase**: 8 (Website Completion)
- **Parent**: 8-050
- **Dependencies**: 8-050a (word colours), poem_colors.json, color_embeddings.json
