# 10-062: Chronological Image Viewer — Reverse Order + 10-Page Pagination

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Low
- **Type**: Feature
- **Status**: Open (planned; deferred -- come back to it later)

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
