# Issue 10-025: The Anchor Poem Appears Exactly Once on Similar and Different Pages

## Status: REOPENED (2026-09-22) — built, one test gap

- **Originally completed**: 2026-02-13, for the diversity ("different") pages in
  the threaded renderer only.
- **Reopened**: 2026-09-22, sorted from `next-issue-please-sort`. Scope widened
  from the diversity ranking alone to **both rankings** (similarity and
  diversity) and **both render paths** (the threaded worker and the
  single-threaded formatter).
- **Built 2026-09-22** (steps 1-4). Step 5 is tested for the single-threaded
  path (`src/flat-html-generator.anchor-once.test.lua`, 7 checks). The
  worker's converters live inside the worker function, where no test can
  reach them; their self-filter is a one-line comparison checked by reading.
  Covering the worker needs the converters lifted into a module (8-058).

## What the owner reported

> also on the similar pages the first poem (the anchor poem) is repeated twice,
> once to show it's the anchor, and then again because it's the most similar to
> itself of course.

## Background: two numbering schemes

Every poem carries two numbers, and mixing them causes this defect:

- **Global index** (integer): the poem's position across the whole corpus,
  handed out category by category (fediverse first, then boosts, notes, then
  messages). Unique across the site.
- **Per-category id** (integer): the poem's number within its own category
  (fediverse/696, messages/260). Several poems in different categories share
  the same per-category id.

## Current Behavior

- **Ranked lists hold only neighbours.** The similarity list builder no
  longer opens with the anchor; it skips the anchor's global index if the
  cache lists it, and every entry is keyed by global index (`id =
  poem_index`). The diversity reader already skipped the anchor.
- **Threaded renderer.** The worker's similarity converter now skips the
  anchor's global index, like its diversity converter.
- **Single-threaded formatter.** The three "skip the anchor" checks compare
  global indices, so the anchor prints once and a poem from another category
  that shares the anchor's per-category id is shown.
- Callers that relied on the anchor being first in the list were updated:
  `scripts/test-html-generation` prints entries 1-3 as the top three.
- Before 2026-09-22: the single-threaded list builder inserted the anchor at
  rank 1 under its global index (looked up by array position) while the page
  compared per-category ids, so the anchor printed twice and same-id poems
  from other categories were hidden; the worker's similarity converter had no
  self-filter.

## Intended Behavior

- On every similar and every different page, in both renderers, the anchor poem
  appears exactly once: at the top, as the anchor.
- Every "is this the anchor?" comparison uses the **global index**. A poem from
  another category that shares the anchor's per-category id is shown normally.
- The ranked lists never contain the anchor, whatever the cache holds, so a
  future cache that includes self entries cannot bring the duplicate back.
- The diversity cache format stays unchanged (the algorithm correctly starts
  from the anchor); filtering happens where the cache is read.

## Suggested Implementation Steps

1. In `src/flat-html-generator.lua`, remove the explicit rank-1 insertion of the
   anchor from the similarity ranked-list builder (the single-threaded path).
2. Look the anchor up by global index, not by array position.
3. Add the same self-filter to the worker's similarity-ranking converter that
   the diversity-sequence reader already has (skip the anchor's global index).
4. Change the three skip checks in the single-threaded page formatters (the
   all-poems formatter and its two paginated siblings) to compare global
   indices instead of per-category ids.
5. Test, in the style of `src/flat-html-generator.chronological-links.test.lua`:
   a ranking that contains the anchor's own global index **and** a poem from
   another category sharing the anchor's per-category id. Expected: the anchor
   appears exactly once, and the other-category poem is kept. Run it against
   both render paths.
6. Longer term, 8-058 removes the duplicated single-threaded formatter so there
   is only one place to get this right.

## Design Decision (from 2026-02-13, still holds)

Filter at display time instead of changing the cache:

1. The diversity cache format is algorithmically correct (the sequence starts
   from the anchor).
2. Filtering on read needs no cache regeneration.
3. The step numbering in the sequence stays accurate (step 1 was the anchor).

## Files

- `src/flat-html-generator.lua` — similarity ranked-list builder,
  all-poems / paginated page formatters (single-threaded path), worker
  similarity-ranking converter and diversity-sequence reader (threaded path).
- `libs/vulkan-compute/src/vk_diversity.c` — where the diversity sequence is
  seeded with the anchor.

## Related Issues

- 8-045: timeline-based progress bars (the same global-index vs per-category-id
  mix produces the wrong bar lengths).
- 8-058: eliminate main-thread / worker code duplication (the root of the drift).
- 9-001g: batch parallel diversity sequences (original GPU implementation).
- 9-005: integrate GPU diversity cache into pipeline.
- Uncommitted 9-001 leftovers, handed over 2026-09-22 when worktrees were
  retired: `/mnt/mtwo/programming/ai-worktrees/neo/issue-9-001/neocities-modernization/libs/vulkan-compute/`
  holds `DIVERSITY-CACHE.md`, `compute-diversity-cache.lua`,
  `generate-diversity-cache.sh`, `check-diversity-progress.{lua,sh}`, a 95 MB
  generated `diversity_cache.bin`, and a changed `shaders/max_reduction.comp`
  (January 2026, never committed; main's own GPU diversity path came later).
  Take what is useful into main, then the worktree can be removed.
