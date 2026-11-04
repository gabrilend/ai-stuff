# 10-066: Word Pages Are Two Thirds of the Site — Find Out Why

## Status
- **Phase**: 10
- **Priority**: Medium
- **Type**: Investigation
- **Status**: Answered; closes after the owner's next build is measured with
  `scripts/measure-page-bytes` (the last step below).
- **Created**: 2026-08-08
- **Split from**: 10-065 (open question 4)

No sizes or counts are written in this issue on purpose. Owner, 2026-10-22:
"this will change dynamically so we should just strike that statistic from
the records." Measure the site instead:

```
scripts/measure-page-bytes                       # the built site
scripts/measure-page-bytes --site FOLDER         # a sample render
```

It counts each kind of page (similar, different, chronological, word pages,
gallery, the rest) and their bytes, and splits the bytes into what a reader
sees, the markup around it, and blank space.

## Current Behavior

When this issue was written the word pages were most of the site, and a word
page weighed far more than its poems seemed to explain. What has been found
since, by measuring with the tool above on a sample render (2026-10-22):

- **A word page costs about what a similar or different page costs for the
  same number of poems.** Every page type draws its poems through the one
  shared drawer now (Issue 8-058), so they share one cost per poem. The old
  weight came from what those pages held then: a word page per word for
  every word in the corpus, each holding several hundred poems. The word
  cloud now has a set number of words (`--words`, `config.lua`
  `word_cloud.max_words`) and each page a set number of poems
  (`--poems-per-page`, `word_cloud.poems_per_page`).
- **About half of every page's bytes are markup**, the same share on every
  page type: each coloured stretch of a progress bar or a frame is wrapped in
  its own `<font color><b>` tags. The rest is the poems' text and the blank
  space of the 80-column layout.

## Intended Behavior

A measured account of where a page's bytes go, from a tool anyone can run,
instead of numbers kept in documents. Then a decision on whether the markup
share is worth reducing (it is an encoding cost: the same pages could be
drawn with fewer tags) -- a separate issue if wanted.

## Suggested Implementation Steps

1. **Done 2026-10-22:** `scripts/measure-page-bytes` (per kind of page:
   pages, bytes, share, bytes per page, and seen / markup / blank).
2. **Done 2026-10-22:** measured a sample render; findings above.
3. After the owner's next build: run `scripts/measure-page-bytes` on the
   built site, confirm the word pages are not an outsized share, and move
   this issue to completed.

## Relevant Files

- `scripts/measure-page-bytes` -- the measurement
- `src/poem-entry.lua`, `src/poem-bars.lua`, `src/boost-bars.lua` -- the one
  drawer; the coloured tags are made in the bar and frame drawers
- `src/generate-word-pages.lua`, `src/word-page.lua` -- the word pages
- `config.lua` -- `word_cloud.max_words`, `word_cloud.poems_per_page`,
  `storage.limit_gb`

## Open Questions

1. Is the markup share worth reducing? It changes no page a reader sees, only
   the bytes uploaded. (Not needed to close this issue.)

## Related Issues

- **10-065** -- surfaced the first measurements
- **8-050** and **8-050a–e** -- built the word-cloud similarity pages
- **8-058** -- one drawer for every page type
- **10-035** -- word pages drawn by the page workers
- **10-057** -- sizes the caches from the pages a build actually shows
