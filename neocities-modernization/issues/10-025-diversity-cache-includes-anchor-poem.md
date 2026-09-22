# Issue 10-025: The Anchor Poem Appears Exactly Once on Similar and Different Pages

## Status: REOPENED (2026-09-22)

- **Originally completed**: 2026-02-13, for the diversity ("different") pages in
  the threaded renderer only.
- **Reopened**: 2026-09-22, sorted from `next-issue-please-sort`. Scope widened
  from the diversity ranking alone to **both rankings** (similarity and
  diversity) and **both render paths** (the threaded worker and the
  single-threaded formatter).

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

- **Diversity pages, threaded renderer (fixed 2026-02-13, still true).** The GPU
  diversity sequence starts with the anchor poem itself, because the algorithm
  seeds its running centroid from the anchor. The worker's diversity-sequence
  reader skips any entry equal to the anchor's global index, so the anchor
  shows once.
- **Similarity pages, threaded renderer.** The worker's similarity-ranking
  converter has **no** self-filter. It shows the anchor once today only because
  the current similarity cache happens to contain no self entries. A cache that
  did include the anchor would print it twice.
- **Similar and different pages, single-threaded formatter.** This is the path
  that produced the owner's sample (the ` -> file:` header line above the top
  bar is written only by this formatter).
  - The ranked-list builder always inserts the anchor at rank 1, tagged with
    its **global index**.
  - The page formatter prints the anchor, then walks the list and skips entries
    whose number equals the anchor's **per-category id**.
  - The rank-1 copy carries the global index, so it does not match and is
    printed a second time. That is the reported defect.
  - The same comparison **wrongly hides** any poem from another category whose
    per-category id equals the anchor's (on the messages/260 page, fediverse/260
    and notes/260 are dropped from the list).
  - The anchor is looked up by array position rather than by global index. That
    lines up today only by accident.
- The single-threaded formatter runs when the thread count is 1 or the threading
  library fails to load. That drift between the two paths is tracked by
  8-058 (eliminate main-thread / worker code duplication).

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
