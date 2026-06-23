# 11-004: Rewrite the Explore Page and Add a "Deeper Math" Companion

## Status
- **Phase**: 11 (Advanced Exploration)
- **Priority**: Medium
- **Type**: Enhancement
- **Status**: Open

## Current Behavior

Two pages are generated from a shared data/view split in
`src/flat-html-generator.lua`: `corpus_stats(poems_data)` computes the live
numbers, `generate_explore_page` renders explore.html (the map), and
`generate_explore_math_page` renders explore-2.html (the deeper math).
`generate_simple_discovery_instructions(output_dir, poems_data)` remains as a
thin shim that produces both, and `src/main.lua` passes the corpus through.

- explore.html shows live counts (total poems, sources + per-source counts, date
  span, image-only count), links every navigation mode (chronological, similar,
  different, word-cloud, gallery, maze), links explore-2, and carries a
  "Browse the source code (coming soon)" placeholder pointing at the future
  source browser (Issue 10-052).
- explore-2.html explains the engine (embeddings, cosine similarity, the mood
  color map, diversity sequences, the triangular matrix) and draws REAL
  corpus-shape histograms as monospace bars: poems-per-source, length
  distribution, poems-per-year. All figures are computed at build time.

**Deferred** (so this issue stays open): the similarity-SCORE distribution
charts. Those need the precomputed similarity matrix that the explore step
deliberately does not load (it is hundreds of MB), so they are noted on the page
as a planned addition rather than rendered.

Originally the explore page was a single static prose guide (the old
`generate_simple_discovery_instructions`) with no statistics, only two of the
navigation modes, and nothing about how similarity is computed.

## Intended Behavior

Two pages, generated as a data/view pair (the generator produces them; a stats
utility supplies the numbers so nothing is hard-coded — see the note below).

### explore.html (rewrite) -- the welcome / map

The friendly entry point. Keeps a short orientation paragraph, then becomes a
real map of the collection:
- **Live corpus stats**: total poems, number of sources (and their names), the
  chronological date span, count of golden poems, count of boosts, number of
  images in the gallery. All read from the corpus at generation time.
- **Every navigation mode, linked**: similar, different, chronological,
  word-cloud / per-word, gallery, maze. One line each describing what it is for
  (the existing similar/different copy is good; extend it).
- **A "Browse the source" link** to the self-hosted source browser (Issue
  10-052). Until that exists, the link is a clearly-marked placeholder. This is
  the link-only way to share the code without a public GitHub repo (GitHub has
  no "unlisted repo" tier; see 10-052 for the full reasoning).
- **A link to explore-2.html** ("How the similarity actually works").

### explore-2.html (new) -- the deeper math

An honest, readable explanation of the semantic engine, with REAL computed
statistics, not adjectives. Sections:
- **Embeddings**: each poem becomes a fixed-length vector from
  `nomic-embed-text-v1.5` (stored FP16, computed FP32). State the dimensionality
  and storage from the embeddings metadata, not from memory.
- **Cosine similarity**: the angle-between-vectors measure that ranks "similar"
  and "different". Explain that "different" is maximum-contrast, not "unrelated".
- **The mood / centroid color map**: how poems are clustered into semantic moods
  and assigned colors (the centroid generator + the balanced color selection).
- **Diversity sequences**: how the "different" ordering is built so consecutive
  poems stay maximally spread (the diversity precompute).
- **The triangular similarity matrix**: why only the upper triangle is stored and
  how it is addressed (the triangular access library).
- **Distribution charts**: render similarity-score and per-mood histograms as
  monospace ASCII bar charts (fits the site aesthetic, needs no JS). Drive these
  from the same stats utility.

Both pages must use the shared page furniture: `FONT_STYLE`, the black
background, and the centered `<pre>` layout (now corrected so the column sits on
the page centerline).

## Design Notes

- **No hard-coded numbers.** Per project convention, documentation should
  reference a validator/stats utility rather than bake in figures that go stale.
  Add (or reuse) a corpus-statistics gatherer that returns the counts/spans/
  histograms; both pages render from its output. If a suitable utility already
  exists (the centroid/diversity precompute steps already compute much of this),
  prefer extending it over writing a parallel counter.
- **Keep generation and viewing separate.** One function computes the stats
  structure; separate functions render explore.html and explore-2.html from it.
- The ASCII histograms reuse the monospace bar idiom already used elsewhere
  (the progress bars); a small shared bar-rendering helper may be factored out.

## Suggested Implementation Steps

1. Split `generate_simple_discovery_instructions` into `generate_explore_page`
   (the rewritten map) and `generate_explore_math_page` (explore-2), keeping a
   thin compatibility wrapper if any caller still expects the old name.
2. Add a corpus-statistics gatherer (new function/util) returning counts, date
   span, source list, and the histogram buckets. Source the embedding
   dimensionality/precision from the embeddings metadata file.
3. Render explore.html from the stats: orientation + stats block + linked
   navigation modes + "Browse the source" (placeholder until 10-052) + link to
   explore-2.
4. Render explore-2.html: the engine explanation with real numbers and ASCII
   distribution charts.
5. Wire both into `src/main.lua` (extend the explore step) and `run.sh`.
6. Update inbound links that currently point only at explore.html where it makes
   sense to also surface explore-2.
7. Verify both pages center correctly and contain no stale/hard-coded figures.

## Related Documents / Tools

- `src/flat-html-generator.lua` — current `generate_simple_discovery_instructions`,
  `FONT_STYLE`, the centered-`<pre>` page templates.
- `src/main.lua` — the explore generation step.
- `src/centroid-html-generator.lua` — mood/centroid clustering (links to explore).
- The diversity precompute and the triangular similarity access library — the
  math explore-2 describes.
- `/issues/10-052-self-hosted-source-browser.md` — the "Browse the source" target.
