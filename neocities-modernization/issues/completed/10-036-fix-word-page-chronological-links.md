# 10-036: Chronological Links Must Name the Page That Holds the Poem

## Current Behavior

Every page that lists poems — the word pages, and the per-poem similar and
different pages — puts a `chronological` link under each poem. That link has one
job: land the reader on the poem, inside the chronological view. Because the
chronological view is split into numbered pages, the link has to name the right
page number, and `#poem-N` alone is not enough — an anchor pointing into the
wrong page scrolls nowhere.

All three page families now do this correctly, and a regression test
(`src/flat-html-generator.chronological-links.test.lua`) holds the behavior in
place by asserting that poems mapped to different pages produce links to
different pages.

## The two failures this issue covers

Both had the same shape — the mapping existed, but did not reach the code that
writes the link — in different generators.

### Word pages (`generate-word-pages.lua`) — original report

Per-poem links pointed at `chronological/index.html#poem-...` instead of the
paginated page. `index.html` is a redirect, and a redirect discards the `#poem`
anchor, so every link landed at the top of page 1.

```html
<!-- Header link (CORRECT): -->
<a href="/similar-different/chronological/11.html#poem-fediverse-4298">Chronological</a>

<!-- Per-poem links (WRONG): -->
<a href='/similar-different/chronological/index.html#poem-fediverse-4255'>chronological</a>
```

Causes: `chrono_page_map` used `"index"` for page 1 instead of `"01"`;
`format_poem_for_word_page` hardcoded `index.html`; and the map was not passed
through the call chain.

### Similar / different pages (`flat-html-generator.lua`) — regression

The same class of break, found later on the other page family. The mapping was
computed correctly before the parallel/sequential split, and then dropped:
`generate_all_paginated_pages_for_poem` had no parameter for it, so it forwarded
only seven of the eight arguments `generate_paginated_poem_page_html` expects.
The eighth arrived `nil`, the formatter's `or "01"` default took over, and every
link named page 1.

Measured on the 2026-06-29 build, before the fix:

| Page family | Chronological links | Target |
|---|---|---|
| `output/similar/` | 694,530 | 100% → `chronological/01.html` |
| `output/different/` | all present | 100% → `chronological/01.html` |
| `output/wordcloud/` | many | correct spread across pages 19–83 |

Ninety chronological pages existed at 88 poems each; only the first 88 poems were
reachable by their anchor. The word-cloud column is the tell — the same corpus,
the same mapping function, threaded properly, giving correct answers.

## The chain that must carry the mapping

The mapping is built once per run and then has to survive a long hand-off. Every
function below takes it and passes it on; the link is written only at the end.
A gap anywhere in the chain is invisible at that point of the code — it shows up
as wrong page numbers in the output, thousands of files away. Listed rather than
line-numbered, because the line numbers go stale and the ORDER is the point.

**Where it comes from** — `compute_chronological_mapping` (flat-html-generator),
exported so the word-cloud generators reuse the exact same sort, tiebreaker and
page size. Its companion `default_chrono_per_page` hard-errors on a missing
config key rather than guessing a size.

**Similar / different pages** (flat-html-generator):
`generate_all_paginated_pages_for_poem` → `generate_paginated_poem_page_html` →
`format_all_poems_with_progress_and_color` →
`format_single_poem_with_progress_and_color`, which writes the link. The archive
variants `generate_similarity_html_archive` / `generate_diversity_html_archive`
join the chain at `generate_flat_poem_list_html`.

**Word pages** (generate-word-pages): `chrono_page_map` →`generate_word_page` →
`format_poem_for_word_page`. Note this generator stores pre-formatted `"01"`
strings, where flat-html-generator stores entry tables — the same information in
two shapes, which is itself a latent source of drift.

**Word cloud** (wordcloud-generator): its own `chrono_page_map` built from the
shared mapping function.

**Page size agreement.** Sharing the mapping *function* is not sufficient — the
divisor has to match too, across separate processes. See the follow-up section
below.

## Files Involved

- `src/flat-html-generator.lua` — the mapping function, the similar/different chain
- `src/generate-word-pages.lua` — word-page chain
- `src/wordcloud-generator.lua` — word-cloud chain
- `src/main.lua` — dev-test callers that pass nil deliberately
- `run.sh` — threads `--chrono-per-page` to every generator
- `src/flat-html-generator.chronological-links.test.lua` — the regression test

## Code Path Analysis

There are two renderers for a poem entry, and they must agree. Which one runs is
decided by whether the `effil` threading library loads:

### Sequential path — THE PRODUCTION PATH
`effil` is no longer installed (retired by Issue 9-001f; its pthreads replacement
9-001f1 is still in progress), so `use_parallel` in `flat-html-generator.lua` is
always false and this is the only path that runs a real build. It goes
`generate_all_paginated_pages_for_poem` → `generate_paginated_poem_page_html` →
`format_all_poems_with_progress_and_color` →
`format_single_poem_with_progress_and_color`. Every one of those four functions
must carry both the chronological mapping AND the "is the chronological view
paginated" flag, or the last one has nothing to aim at.

### Parallel worker path — currently unreachable
`format_poem_entry` inside the worker computes the link correctly. It is dead
code until 9-001f1 lands. It is also a second copy of this logic, which is the
duplication Issue 8-058 exists to remove; until then, a change here must be made
in both places.

### Archive path
`generate_similarity_html_archive` / `generate_diversity_html_archive` receive
both values. Disabled by default (`enable_html_archive = false`).

### Test / interactive path
Test functions in `main.lua` and interactive mode pass `nil` deliberately. These
are development tools, not site output.

## Design Decision — the link must follow the writer's branch, and never guess

Two facts decide the target filename, and both must reach the formatter:

| Value | Type | Meaning |
|---|---|---|
| `chrono_mapping` | table, `poem_index` (number) → entry | which page holds each poem |
| `chrono_paginated` | boolean | whether the view was split into pages at all |

Each mapping entry is a table of numbers: `position`, `page_number`,
`total_pages`, `total_poems`, `timeline_progress`.

`chrono_paginated` cannot be read from the pagination config, because
`--chrono-per-page` turns pagination on at runtime without touching that table.
It has to be threaded.

The filename must match the branch in `generate_chronological_index_with_navigation`
that decides where the page was actually written:

- paginated, more than one page → `chronological/NN.html` (zero-padded)
- otherwise → `chronological/index.html`

**There is no page-number guess.** An earlier version of this fix let the
formatter default to `"01"` when the mapping was absent, on the reasoning that
only dev tools would ever hit it. When `effil` disappeared, the untested
sequential path became the only path, its call sites had never been updated to
pass the mapping, and the "dev tools only" default silently became the product:
a full build shipped 694,530 chronological links on the similar/different pages
all pointing at page 1 of 90, while the word-cloud pages (which thread the
mapping properly) stayed correct. A missing mapping now falls back to
`index.html` — the one file written in both modes, costing only the `#poem`
anchor — and logs one warning naming why.

This is the general shape of the failure, worth stating plainly: a fallback that
produces plausible output converts a missing argument into wrong data instead of
a stopped build. Per project rule, fallbacks are warnings and warnings are errors.

## Follow-up: page-size must be shared, not just the mapping function

The fix above shared the mapping *function* so the sort order matched, but each
generator still chose its OWN page-size divisor: the chronological pages honor a
runtime `--chrono-per-page` override, while the wordcloud/word-page generators
(separate luajit processes) read only the compiled-in config default. When the
two differ (e.g. pages built at 88/page but consumers assuming 500/page), every
`#poem` link lands on the wrong page again — `ceil(position / size)` produces a
different page number for the same poem. "One mapping, one answer" only holds
when both the function AND its page-size argument match.

Correct design: the page size has exactly two legitimate sources — the
`--chrono-per-page` flag the build passes, or the pagination config — and
`run.sh` threads the SAME flag to every generator (main, wordcloud, word-pages)
so separate processes cannot disagree. There is no third source and no literal
fallback: if neither the flag nor the config supplies a size, the generators
hard-error rather than guess (a wrong guess silently mis-paginates every link,
which is worse than a loud stop). An earlier attempt recorded the size to a
marker file beside the pages; that was dropped in favor of the simpler
flag-or-config rule with a hard error, which needs no on-disk side channel.

Relevant pieces: `compute_chronological_mapping` and `default_chrono_per_page`
(flat-html-generator; the latter now errors on a missing config key); a small
`resolve_chrono_per_page` helper in each of wordcloud-generator and
generate-word-pages (flag → config → error); and the `--chrono-per-page`
threading in `run.sh`'s word-cloud invocations.

## Related Issues

- Issue 8-050e: Original chronological page mapping implementation
- Issue 8-039: Chronological pagination (created the redirect issue)
- Issue 10-034: Lazy loading orchestrator (parallel worker architecture)
- Issue 10-052: Self-hosted source browser (the per-page marker lives beside its
  chronological pages, outside that browser's tree)
- Issue 9-001f / 9-001f1: retiring effil and replacing it with pthreads. This is
  what turned the sequential path into the production path, and what will decide
  whether the parallel worker's duplicate copy of this logic comes back or goes.
- Issue 8-058: eliminating the main-thread/worker duplication — the structural
  fix for why this logic exists twice and can drift.
- Issue 10-064: adds `--reverse`, which changes chunk-to-page assignment and so
  changes every answer this mapping gives. It must reuse this mapping, not
  reimplement it.

## Open Questions

- **The live output still carries the old links.** The fix is in the generator;
  `output/similar/` and `output/different/` were built on 2026-06-29 and are not
  regenerated by it. Whether to spend a full HTML rebuild now, or fold it into
  the next one, is a scheduling call.
- **Should the parallel worker's copy be deleted rather than maintained?** It is
  unreachable today. Keeping it means every change here must be made twice;
  deleting it means 9-001f1 rebuilds it from this one.
- **Is `chronological_paginated = false` still the intended config default?**
  Real builds pass `--chrono-per-page`, so the committed default is the mode
  nobody runs — which is exactly how the unpaginated branch went untested.

## Status

**COMPLETED** - 2026-03-23 (word pages)
**REOPENED / FIXED** - similar and different pages, same defect class; regression
test added. Open questions above are unanswered, and the live site has not been
regenerated.
