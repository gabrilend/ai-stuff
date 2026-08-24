# Issue 8-050b: Colour on Word Pages — Select by Relevance, Present by Colour

## Priority
Medium

## Current Behavior

Each word page selects the poems closest in meaning to one word, then arranges
those poems so the seven semantic colours alternate down the page rather than
arriving in clumps. Each poem's progress bar is drawn in its own colour, **read**
from the precomputed per-poem table rather than re-derived at display time.

Selection and presentation are separate concerns and stay that way: colour never
decides *who* appears, only *where* on the page they appear.

This is a word-page treatment only. The similar/different pages stay in strict
similarity order.

## Intended Behavior

Three rules. The second and third are the ones this issue exists to record.

### 1. Selection is pure relevance

The top N by similarity, nothing displaced. An earlier version selected from a
pool of 7N so that colour balancing could reach past the best matches for
colour-diverse ones — a search for "god" surfaced unrelated poems as a result.
The pool is exactly N now, and the arrangement step returns all N.

### 2. Presentation spreads the colours across the whole page

Not a round-robin. A round-robin deals one poem per colour per cycle, which
drains the small buckets first and leaves the tail of the page a solid run of
whatever colour was most plentiful.

Instead, **stratified spacing**: the j-th of a colour's m poems is given a target
position of `(j - 0.5) × N / m` — the midpoint of its share of the page — and the
whole set is sorted by target. A colour holding 8 of 333 slots therefore appears
about every 42 positions; one holding 131 appears about every 2.5. Neither
clumps, at either end. Within a colour, the more relevant poem still comes first,
and ties are broken by relevance so two builds of the same data agree.

Measured on the word "linux" at N=333: seven distinct colours, longest run of a
single colour is **3**, and slot 1 still holds the best match.

Because the order is no longer strictly descending, the page heading says what it
actually does — "the N poems closest in meaning to this word, arranged to spread
the colours" — rather than claiming a ranking it does not present.

### 3. A poem's colour comes from `poem_colors.json`, never from a fresh cosine

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
contest across the corpus. Measured on the selected model
(`nomic-embed-text-v1.5`) — run `scripts/measure-embedding-spread` to refresh:

| anchor | cosine to average poem | share of corpus won (raw) |
|--------|-----------------------|---------------------------|
| purple | 0.9242 | **48.2%** |
| yellow | 0.9129 | 16.2% |
| green  | 0.9099 | 12.1% |
| blue   | 0.9090 | 10.7% |
| orange | 0.9051 | 5.4% |
| gray   | 0.9026 | 3.1% |
| red    | 0.8992 | 4.3% |

The two columns rank the same way, with one adjacent swap. A spread of 0.025 in
"how generic is this anchor" produces an elevenfold spread in how often it wins,
and the single most generic anchor takes nearly half the corpus. Under raw
nearness the contest is not about what a poem means; it is about which anchor
happens to sit nearest the middle of everything — the same anisotropy the model
imposes on every vector it produces, surfacing in a second place.

The z-scored assignment removes it. The stored distribution is even — 12.1% to
17.2% per colour — where raw nearness gives one colour nearly half.

**A note on where these numbers come from.** The first set written into this
document was measured against `assets/embeddings/embeddinggemma-300m/`, which is
not the selected model; the build resolves `nomic-embed-text-v1.5`. The finding
survived the correction and got stronger, but the lesson is that a hand-typed
embeddings path is a trap. `scripts/measure-embedding-spread` resolves the model
through the project's own selection for exactly that reason, and is the right way
to refresh any figure in this document.

`config.lua` already records the first half of this lesson, in the comment above
`color_associations`: the *bare word* "red" embeds to a generic point that
swallowed ~38% of all poems by raw nearness, which is why each colour's anchor is
the mean of a hand-written association list (fire, blood, passion, rage…) rather
than the colour word alone. The z-scoring is the second half of the same lesson.
Good anchors are necessary and not sufficient; the comparison has to be
standardised too.

## What Changed From the Original Specification

The original specification here was a *cumulative-similarity-balanced
round-robin*: bucket the top N by colour, then deal them back out choosing
whichever colour had the lowest running total of colour-similarity. Two things
about it were wrong, and both are worth recording because the intent was right.

**It sorted on colours that were not the site's colours.** It re-derived each
poem's colour by raw nearest cosine while the progress bar beside it was drawn
from the stored z-scored verdict. The two disagreed on a third of any page. So
the arrangement was spreading the page across a measurement of genericness, and
doing it in colours the reader could not see. Reading the stored verdict fixes
this, and is rule 3 above.

**Its running total reintroduced the same bias.** The "cumulative" budget was
accumulated from raw colour-similarity scores, which are precisely the quantity
shown above to track genericness rather than meaning. Stratified spacing needs no
budget at all — position is a function of bucket size, nothing else.

A third problem was structural rather than numerical: a round-robin exhausts
small buckets early, so the far end of a long page degenerates into a run of the
most common colour. Stratified spacing has no tail behaviour because every
colour's share is laid out across the full length from the start.

## Suggested Implementation Steps

1. Rank every poem against the word by cosine similarity (mean-centred — see
   Issue 8-019's neighbour note and `scripts/measure-embedding-spread`), sort
   descending, take the top N.
2. Read `poem_colors.json` positionally — the array position **is** the
   `poem_index`; entries carry `color` and `similarity` but no index field.
3. Bucket the N by stored colour, preserving relevance order within each bucket.
   A poem with no stored colour buckets as gray, because gray is what its bar
   will render as; bucketing it anywhere else disperses on a colour nobody sees.
4. Give the j-th of a colour's m poems a target position of `(j - 0.5) × N / m`,
   sort by target, break ties by relevance. Return all N.
5. Draw each bar from the site's shared palette, not a private copy — see the
   palette note below.
6. Do not load the colour anchors in the page builder. The only routine that
   needs them is the one assigning colours to **words**, which has no
   precomputed table to read from.

### On the shared palette

The bar colour is looked up by name in a hex table. That table must be the site's
one palette, derived from `config.lua`'s `semantic_colors` and shared with the
other page builders. The word page previously kept its own copy listing a generic
spectrum — red, orange, yellow, green, cyan, blue, indigo, violet, gray — which
are not the seven names the colour calculator assigns. `purple` was absent, so
every purple poem fell through to a hardcoded `#888888` that was not even that
table's gray, and purple is the largest stored bucket at 17.2%. About one poem in
six on every word page rendered in an off-palette grey, and the remainder
rendered in hexes no other page type used.

## Validation

- The first poem on a word page is the highest-scoring poem for that word.
- A poem's bar colour on a word page matches its colour on the chronological and
  similar/different pages, and is one of the seven configured hexes — a bar
  drawn `#888888` means a colour name is missing from the palette.
- Colours alternate: the longest run of a single colour on a full page should be
  small (measured at 3 for "linux" at N=333), and every colour present in the
  selection should appear spread across the page rather than bunched.
- The page heading describes an arrangement, not a strict ranking.

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
