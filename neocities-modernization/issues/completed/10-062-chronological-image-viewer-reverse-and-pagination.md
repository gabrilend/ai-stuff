# 10-062: Chronological Image Viewer — Reverse Order + 10-Page Pagination

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Low
- **Type**: Feature
- **Status**: Completed (2026-11-02)

## Current Behavior

`src/generate-gallery-pages.lua` produces `output/gallery/chronological.html`: a
single page listing every catalogued image in chronological (oldest-first) order.
With the full corpus that is one very long page -- the only way to reach the end is
to scroll the whole thing, and there is no way to view newest-first.

## Intended Behavior

The chronological image viewer becomes paginated and bi-directional, with quick
jump navigation -- otherwise identical in look and content to today's page.

- **Forward (oldest-first)** and **reverse (newest-first)** views. The reverse view
  is exactly the same page with the image order flipped.
- **A link at the top of each view to the other** (forward <-> reverse), so the
  reader can flip direction in one click.
- **10 pages per direction.** The chronological image list is split into 10 roughly
  equal pages (forward and reverse each), so each page is a manageable scroll.
- **A page-number jump bar at the top of every page**: the numbers 1 through 10,
  each separated by three spaces, every number a link to that page --

  ```
  1   2   3   4   5   6   7   8   9   10
  ```

  so the reader can jump straight to any page without clicking "next" repeatedly.
  The current page's number should be visually distinct (e.g. not a link / bolded).

## Design Notes / Decisions To Settle

- **Page count vs page size.** "10 pages" is fixed by request, so page size =
  ceil(total_images / 10) and grows with the corpus. (Alternative -- fixed page size,
  variable page count -- is explicitly NOT what is wanted here.)
- **File naming.** Suggest `gallery/chronological-NN.html` (forward) and
  `gallery/chronological-reverse-NN.html` (reverse), with `chronological.html` either
  redirecting to page 01 or being page 01. Keep it consistent with how the poem
  chronological pages are already named/paginated (mirror that convention).
- **Reverse is a view, not new data.** Build the sorted list once, then emit forward
  pages from it and reverse pages from its reversal -- no second catalog pass.
- **Shared chrome.** The jump bar + forward/reverse toggle are the same markup on
  every page; factor them into one helper that takes (current_page, direction).

## Suggested Implementation Steps

1. In `src/generate-gallery-pages.lua`, find the chronological-gallery generation,
   sort the image list once, and split into 10 pages.
2. Add a helper that renders the top jump bar (1..10, three spaces apart, current
   page non-linked) plus the forward/reverse toggle link.
3. Emit forward pages (`chronological-NN.html`) and reverse pages
   (`chronological-reverse-NN.html`) from the list and its reversal.
4. Point `gallery/chronological.html` (and the gallery index's link to it) at page 01.
5. Confirm the per-image links (to similar/different/the poem) still resolve from the
   new page paths -- they are document-relative, so depth must match.

## Related Documents / Tools
- `src/generate-gallery-pages.lua` -- the gallery generator (chronological view).
- The poem chronological pagination (`flat-html-generator.lua`,
  `generate_chronological_index_with_navigation`) -- mirror its paging/naming.
- Stage 9 (`run_generate_html`) runs the gallery generator.

## What Happened (2026-11-02)

The chronological image gallery is now paginated both ways.

- **Pages** -- `gallery/chronological-01.html` .. `-10.html` (oldest first) and
  `gallery/chronological-reverse-01.html` .. `-10.html` (newest first), built by
  `generate-gallery-pages.lua`'s new `M.chronological_pages` /
  `M.write_chronological_pages`. The reverse view is the same sorted list read
  backwards; the catalog is sorted once.
- **Chrome** -- every page has, at the top and again at the bottom, the jump bar
  (`1   2   3 ...`, three spaces apart, the current page bold and unlinked) and
  an "oldest first | newest first" toggle. Each page says which pictures it holds
  ("this page: 22 to 23") and its title says "page N of P".
- **Which page a picture is on** -- `src/gallery-pages.lua` (new, dependency-free
  so effil workers can load it). The gallery's pictures (`STANDALONE_SOURCES`,
  moved here from the generator) are sorted by time, ties broken by hash then
  path; `page_size = ceil(total / pages)`; a picture at 0-based position `i` is on
  page `floor(i / page_size) + 1`.
- **Links from poem pages** -- `image-render.lua` gains `load_gallery_index`
  (catalog path, JSON reader, page count; memoized per process like the
  manifest), called by each HTML worker beside `load_manifest`. A standalone
  picture's title now links to `../gallery/chronological-NN.html#img-...`.
- **Config** -- `pagination.gallery_chronological_pages = 10`; anything but a
  whole number of at least 1 stops the build.

### Decisions

1. **The page is computed, not recorded** (decided by the owner on review):
   from the picture's position in the catalog's time order, with the same
   function in the gallery and in the poem-page renderer. The augment stage and
   the image manifest are unchanged; the manifest's `gallery_anchor` still names
   the picture, and the renderer looks its page up.
2. **Deterministic order.** The old sort compared timestamps only, and Lua's sort
   is not stable, so two pictures with the same time could swap between builds.
   With pages, a swap at a page boundary would move a picture to another page
   and break its links; ties now fall back to the hash, then the path.
3. **Ten pages is a ceiling.** Page size is ceil(total / 10), as the issue says,
   so a small gallery can fill fewer pages (25 pictures in pages of 3 fill 9).
   The jump bar shows only the pages that exist.
4. **File names** follow the issue's suggestion and the poem pages' two-digit
   numbering. They stay in `gallery/`, so every relative path (`../media/`)
   is unchanged.
5. **`chronological.html` stays, as a copy of forward page 01**, so bookmarks
   and links already out in the world still open the gallery (at its start). A
   copy rather than a meta-refresh redirect: no extra hop, and the file is small.
   The gallery index now links `chronological-01.html`.
6. **The direction toggle goes to page 1 of the other view** -- "newest first"
   starts at the newest picture -- rather than to the page holding the same
   pictures, which is harder to predict.
7. **Captions stop at a page break.** A caption names the picture below only
   when it is on the same page; the last picture of a page closes like the last
   picture of the gallery, and the jump bar under it leads on.
8. **A jump bar at the bottom too**, so reaching the end of a page does not mean
   scrolling back up to go on. Otherwise the pages look as before.
9. **A picture the gallery does not show** (a source outside
   `STANDALONE_SOURCES`, which the augment stage can still rank) keeps a plain,
   unlinked title instead of a link to a spot that does not exist. With no
   catalog at all, nothing is linked. Drawing a gallery picture before the index
   is loaded is a wiring mistake and stops the build.
10. **Stale pages are removed.** When a build has fewer pages than the last one,
    the generator deletes the higher-numbered forward and reverse pages it
    wrote before.

### Tests

- `src/gallery-pages.test.lua` (new, 45 checks): the page arithmetic, refused
  page counts, the order (oldest first, ties by hash whatever the catalog order,
  the catalog itself untouched), the index and links; then real pages built from
  a 23-picture catalog into a scratch folder, following **every** picture's link
  to a page that holds its anchor, every picture in the reverse view exactly
  once, the first and last pages' contents, the jump bars, the toggles, the
  caption rule at a page break, a stale page removed, `chronological.html` equal
  to page 01, and an empty gallery.
- `src/image-render.test.lua` (24 checks, was 18): the title links to
  `chronological-05.html#img-abc123` for the 13th of 25 pictures; a picture
  outside the gallery and a missing catalog give no link; the index is read
  once; drawing before loading and a bad page count are refused.
- `luajit src/generate-gallery-pages.lua` on a 20-picture sample catalog wrote
  ten pages each way, `chronological.html` and the index linking page 01.
- Not run here: stage 9 against the real catalog (no corpus on this machine).

