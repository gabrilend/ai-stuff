# 10-066: Word Pages Are Two Thirds of the Site — Find Out Why

## Status
- **Phase**: 10
- **Priority**: Medium
- **Type**: Investigation, then likely a size fix
- **Status**: DEFERRED — resume after the next full corpus regeneration
  (operator's call, 2026-08-08). Blocked on the same thing either way: there is
  no word page to dissect until stage 10 runs again, and the embeddings behind
  it are 146 poems short of the corpus. Regenerating produces the artifact this
  issue needs as a side effect, so waiting costs nothing and avoids a rebuild
  done solely for measurement.
- **Created**: 2026-08-08
- **Split from**: 10-065 (open question 4), which surfaced the measurements while
  removing the CLI's defaults

## Summary

The per-word similarity pages are 11 GB — about two thirds of the entire
generated site — spread over 7,176 files at roughly 1.6 MB each. The size is
near-uniform regardless of the word, and that uniformity is the interesting part:
a page for a word appearing in three poems weighs the same as one for a word
appearing in three thousand.

Nothing yet explains the bulk. The obvious arithmetic does not reach it.

## Current Behavior

### What was measured

Taken on 2026-08-08. Re-measure with `du -sh output/` and
`ls output/wordcloud | wc -l` rather than trusting these later.

| Quantity | Value |
|---|---|
| `output/` total | 16 GB |
| — `output/wordcloud/` | 11 GB across 7,176 files |
| — per word page | ~1.6 MB, near-uniform across words |
| — `output/different/` | 1.6 GB across 15,954 files (~100 KB each) |
| — `output/chronological/` | 22 MB across 1,150 pages |
| Poems in corpus | 8,050 |
| Embeddings, images folded in | 8,701 |

### Why the arithmetic does not reach 1.6 MB

A surviving chronological page, `output/chronological/01.html`, is **12 KB for 7
poems** — about **1.7 KB of HTML per rendered poem**. A word page shows its top-N
most similar poems. At the menu's suggested 50 poems per page that is roughly
**85 KB**, not 1.6 MB. Something accounts for the remaining ~1.5 MB per page, and
multiplied by 7,176 pages that something *is* the site's size.

### What has been ruled out

`src/generate-word-pages.lua` was searched for an obvious per-page payload —
`<script>`, `<datalist>`, an embedded poem index, an inlined font. The only
`<style>` is a one-line font-family declaration (line 766). No large embedded
block was found there.

### Evidence of a large fixed payload — in the MENU, at least

Found by accident: a test run generated a **3-word** cloud, and the archive
preserves clouds at several sizes. Sizes do not scale with word count.

| Archived menu | Words | Size |
|---|---|---|
| `wordcloud-2026-08-08_10-25-57-3words.html` | 3 | 412 KB |
| `wordcloud-2026-06-24_17-12-16-200words.html` | 200 | 423 KB |
| `wordcloud-2026-08-05_21-41-26-7176words.html` | 7,176 | 1,069 KB |

Three words cost 412 KB. Between 3 and 200 words the file grows 11 KB; between
200 and 7,176 it grows 646 KB. So roughly **410 KB is fixed overhead present
regardless of content** — most plausibly the live poem index the menu is
documented to carry (Issue 10-059).

This is measured for the **menu** (`output/wordcloud.html`), not for the per-word
pages (`output/wordcloud/*.html`), which are a different generator and were not
available to measure. But it establishes that a large fixed payload exists in
this family of pages, which is what the "shared payload" hypothesis needed and
did not have. If the per-word pages carry something similar, 7,176 copies of a
~1.5 MB fixed block is the 11 GB.

**Step 2 below should test exactly this**: generate two word pages with very
different poem counts and compare their sizes. If they match, the bulk is fixed
overhead, not content.

### Candidates not yet ruled out

- **Per-character markup.** The golden-poem borders and progress bars build lines
  as coloured spans (see the golden-line assembly around lines 658–667 and
  `poem_bars.golden_corner_box_*`). If every line of every poem is wrapped
  per-character or per-cell, the markup could dwarf the text by an order of
  magnitude. This is the leading candidate because it scales with rendered poems
  and would apply uniformly.
- **A much larger poems-per-page than assumed.** `CONFIG.max_poems_per_page` is
  hardcoded to `100` at line 154, while `poems_per_word_page` comes from the CLI.
  Nothing records what the last build actually used (see 10-065 open question 7),
  so the 50 in the arithmetic above is an assumption, not a fact.
- **Whitespace padding.** Lines are padded to a fixed `CONTENT_WIDTH` (line 665).
  Uniform padding across thousands of lines compresses well in transit but still
  occupies disk and upload quota.

### Why uniformity is a clue, not a symptom

Every word page shows the top-N poems ranked by similarity to that word's
embedding — not the poems *containing* the word. So every page renders exactly N
poems, whatever the word's frequency. Uniform size is therefore expected from the
design; what is not explained is the per-page *magnitude*.

## Intended Behavior

First, an answer: a byte-level account of where 1.6 MB goes on one page, measured
rather than reasoned. Then a decision, informed by that account, about whether
the size is inherent to what the pages show or is an encoding that can be made
cheaper without changing what a reader sees.

The storage budget makes this concrete. `config.storage.limit_gb` is 45, and
`output/` is at 16 GB with the word pages as the dominant term.

## Suggested Implementation Steps

1. Regenerate a handful of word pages (`--wordcloud-words 5`) so there is a
   page to take apart. This needs embeddings for some model first; the RAM-tier
   caches were cleared on 2026-08-08 and cost about 20 minutes to rebuild (per
   `.stage-timings`, not per the estimates that used to be written into run.sh).
2. Before anything subtler: generate two word pages whose words have very
   different poem counts and compare their sizes. The menu measurements above
   show ~410 KB of fixed overhead in that file; if the per-word pages behave the
   same way, two pages of near-identical size settle the question in one step and
   the rest of this list is about finding the block, not proving it exists.
3. Account for the bytes on one page: total, then the share taken by rendered
   poem text, by markup around that text, by the navigation and border
   furniture, and by padding. A crude but sufficient method is stripping tags and
   comparing lengths.
4. Confirm how many poems the page actually rendered, and reconcile it against
   `max_poems_per_page` and the `--wordcloud-poems` value used.
5. Only then decide whether there is a fix worth making, and what it costs a
   reader.

## Relevant Files

- `src/generate-word-pages.lua` — builds these pages; `CONFIG` at ~line 154,
  golden-line assembly ~658–667, page write ~743
- `libs/poem-bars.lua` (via `poem_bars.golden_corner_box_*`) — the border and
  progress-bar markup, the leading suspect for per-character expansion
- `src/wordcloud-generator.lua` — builds the menu these pages hang off
- `config.lua` — `storage.limit_gb` (45), `word_cloud`
- `output/chronological/01.html` — the 12 KB / 7 poem baseline used above

## Open Questions

1. Is 1.6 MB inherent to showing N full poems with this project's visual
   language, or is it an encoding cost that could be reduced without changing
   what a reader sees?
2. Should a word page show fewer poems? That is a question about the work, not
   about bytes — it changes what the page is for, so it is yours to answer, not
   something to optimise into.
3. `output/different/` is 1.6 GB across 15,954 files at ~100 KB each, which is
   also far above the 1.7 KB-per-poem baseline. Is this the same phenomenon at a
   smaller scale, and would one explanation cover both?

## Related Issues

- **10-065** — surfaced these measurements; also the source of the note that
  nothing records the word-cloud parameters a build used
- **8-050** and **8-050a–e** — built the word-cloud similarity pages
- **10-059** — split the word cloud into its own stage
- **10-057** — sizes the rankings cache from the pages a build actually shows,
  which is the same "how much is enough" question one layer down
