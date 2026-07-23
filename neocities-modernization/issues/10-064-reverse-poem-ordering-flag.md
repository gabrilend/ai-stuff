# 10-064: `--reverse` Flag — Reverse Poem Page Order + Chronologically-Sorted Similar/Different

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Medium
- **Type**: Feature
- **Status**: Open
- **Sibling**: 10-062 (the same reversal, but for the image gallery's chronological
  view). This issue is the POEM analog and is scoped to poems only; the gallery is
  out of scope here (see Decisions to Settle).

## Current Behavior

`run.sh` exposes the pipeline through named flags and an interactive TUI
(`-I` / `--interactive`). There is no flag or menu item that reverses reading order.

The generated site has one fixed ordering per view:

- **Chronological index pages** are built oldest-first. The canonical sort
  (`sort_poems_chronologically_by_dates` in `src/flat-html-generator.lua`) orders
  poems ascending by post date (earliest → latest), and
  `generate_chronological_index_with_navigation` paginates that ascending list into
  `chronological/01.html`, `chronological/02.html`, … at `--chrono-per-page` poems
  each. Consequence: page `01.html` holds the OLDEST chunk with the oldest poem at
  its top; the single newest poem lives at the very bottom of the very last page —
  the least reachable spot on the site.
- **Similar pages** are ordered most-similar-first. The order is read straight from
  the precomputed similarity-rankings cache (descending similarity score) by
  `generate_similarity_ranked_list`.
- **Different pages** are ordered most-different-first. The order is the precomputed
  maximum-diversity walk from the diversity cache (consecutive poems kept maximally
  spread), read by `generate_maximum_diversity_sequence`.

The explore page (`explore.html`, prose in `page-templates/explore.txt`) describes
these orders as fixed facts: "chronological — read the collection in time order,
start to finish", similar = "Most alike first", different = "Most unlike first".

The chronological page size must agree across three processes — `src/main.lua`,
`src/wordcloud-generator.lua`, `src/generate-word-pages.lua` — because each emits
`#poem` anchor links that target a specific chronological page number; that is why
`--chrono-per-page` is forwarded to all three (issue 10-036). Any new ordering flag
inherits this same cross-process agreement requirement.

## Intended Behavior

Add one mode flag, `--reverse` (and a matching interactive-menu checkbox), that
reverses reading order across the whole build. When it is active, generation
produces a site whose poem ordering is flipped in the following precise ways. When
it is absent, output is exactly as today.

### The flag and the menu item

- **CLI**: `--reverse` — a boolean switch (no value), listed in `show_help` under a
  fitting group (e.g. near the Pagination options, since it changes page order).
- **TUI**: a checkbox in the "Configuration" section of `interactive_mode_tui`,
  mapped to the `--reverse` flag so it appears live in the command preview, wired
  through `menu_get_value` like the other config toggles (Dry Run, Verbose).

### Chronological index pages (with `--reverse`)

The corpus is chunked into pages of `--chrono-per-page` poems, exactly as today.
`--reverse` reverses **which chunk lands on which page number**, while keeping the
**within-page order ascending (earliest poem at the top)** unchanged.

- Page 1 holds the LATEST chunk (the most-recent `chrono-per-page` poems). Within
  page 1 the poems still read earliest → latest top-to-bottom, so the earliest of
  that newest chunk is at the top and the single final poem of the whole corpus is
  at the bottom of page 1.
- Page 2 holds the next-latest chunk, again ascending within the page.
- … and so on, so the last page holds the earliest chunk.

Worked example with a page size of 100 and N poems numbered 1..N in true
chronological order (1 = earliest, N = latest):

| Page | Chunk shown (by chronological rank) | Top of page | Bottom of page |
|------|-------------------------------------|-------------|----------------|
| 1    | last 100: poems N-99 … N            | N-99        | N (final poem) |
| 2    | 2nd-to-last 100: poems N-199 … N-100| N-199       | N-100          |
| …    | …                                   | …           | …              |

In one sentence: **`--reverse` reverses the page order (newest chunk becomes page 1)
and preserves the within-page ascending, earliest-at-top order.** The net effect is
that the newest poem moves from "bottom of the last page" to "bottom of page 1".

### Similar / different pages (with `--reverse`)

The SET of poems shown is unchanged — still the most-related poems chosen by the
similarity-rankings cache (similar) and the diversity cache (different). Only the
**row order changes: from score-order to chronological order.**

- **Similar** pages: the selected related poems are re-sorted by date, **latest
  first** (newest at top, descending date).
- **Different** pages: the selected related poems are re-sorted by date, **earliest
  first** (oldest at top, ascending date).

They are "still the most related" — the membership is score-determined — but they
are laid out in time order rather than by similarity/difference score. Example: a
page that today shows the 100 most-similar poems ranked by score instead shows those
same 100 poems sorted newest-to-oldest.

Note the deliberate asymmetry: similar is descending date, different is ascending
date. Different therefore matches the chronological pages' ascending direction;
similar is intentionally the opposite. (Preserve this exactly as specified.)

### Explore page (documented side-effect)

The chronological re-sort of the similar/different pages is a **documented
side-effect**, surfaced on the explore page. Because the site is built in one mode
at a time, the explore prose should state the ordering the current build actually
used — add a short ordering note to `page-templates/explore.txt` (which
`scripts/sync-page-templates` copies into `input/pages/explore.txt` before
generation), filled by the generator based on whether `--reverse` was active. The
existing template/marker machinery (`src/page-template.lua`, with its `OMIT`
sentinel and error-on-unknown-marker behavior — issue 11-005) is the right tool: a
`{ORDERING_NOTE}` marker that expands to the reversed-mode explanation when
`--reverse` is set and to the default text (or `OMIT`) otherwise.

## Design Notes / Decisions to Settle

- **Mode flag vs. parallel pages.** This issue specifies `--reverse` as a *mode*:
  one build has one ordering, chosen at generation time (matches "an option that
  reverses the ordering" and a TUI checkbox). The alternative — emitting a second,
  parallel set of reverse pages so both orderings coexist in one build, the way
  10-062 emits `chronological-reverse-NN.html` — is explicitly NOT what is described
  here. Trade-off to accept: to publish both orderings you build twice into two
  output directories. (Recommended: keep it a mode flag; revisit only if both
  orderings need to ship from a single build.)
- **Similar/different: re-sort scope.** When a related list spans more than one page
  (`--poems-per-page`), re-sort the FULL selected list chronologically and THEN
  paginate (recommended), rather than re-sorting within each page independently.
  This keeps the whole related set in one continuous time order across its pages.
  Confirm this matches intent.
- **Cross-process consistency (critical).** `--reverse` changes chronological page
  numbering, and `#poem` anchor links baked into similar/different pages, word-cloud
  pages, and per-word pages all point at specific chronological page numbers. The
  flag MUST be forwarded identically to `src/main.lua`, `src/wordcloud-generator.lua`,
  and `src/generate-word-pages.lua` (exactly as `--chrono-per-page` already is —
  issue 10-036), or those links land on the wrong page. Treat a mismatch as a bug to
  test against, not a fallback to tolerate.
- **"Reverse" semantics are two different operations under one flag.** For
  chronological pages it reverses the chunk-to-page assignment (page order); for
  similar/different it switches score-order to date-order. The issue name is one
  flag; the implementation touches two distinct code paths. Keep them clearly
  commented so a future reader is not surprised that one flag does two things.
- **Caches are not recomputed.** The similar/different re-sort operates on the set
  already selected from the similarity/diversity caches — it is a display re-sort by
  date, never a recompute of relatedness.
- **Gallery is out of scope.** Reversing the image gallery's chronological view is
  issue 10-062; this issue does not touch `src/generate-gallery-pages.lua`.

## Suggested Implementation Steps

1. **`run.sh` — flag + forwarding.** Add a `--reverse` case to the argument parser
   (set `REVERSE=true`), document it in `show_help`, and build a `REVERSE_ARG` that
   is appended to the `luajit src/main.lua … --html-only` invocation in
   `run_generate_html` and to the `wordcloud-generator.lua` /
   `generate-word-pages.lua` invocations in `run_generate_wordcloud` — mirror how
   `--chrono-per-page` / `$chrono_per_page_arg` is already threaded through both.
2. **`run.sh` — TUI.** Add a `--reverse` checkbox to the Configuration section of
   `interactive_mode_tui`, read it with `menu_get_value`, and set `REVERSE`
   accordingly in the menu-result block.
3. **`src/flat-html-generator.lua` — chronological.** Thread a `reverse` option into
   `generate_chronological_index_with_navigation`; after chunking the ascending
   list, reverse the chunk-to-page assignment (newest chunk → page 1) while leaving
   each page's within-chunk ascending order intact. Preserve existing page naming
   and the `index.html → 01.html` redirect.
4. **`src/flat-html-generator.lua` — similar/different.** In the page-generation
   path (`generate_page` / the callers `generate_similarity_ranked_list` and
   `generate_maximum_diversity_sequence`), when `reverse` is set, re-sort the
   selected related list by post date before pagination — similar descending
   (latest first), different ascending (earliest first) — using the same date
   extraction the canonical chronological sort uses.
5. **Consistency plumbing.** Pass `reverse` into `src/wordcloud-generator.lua` and
   `src/generate-word-pages.lua` so their `#poem` chronological links and their
   similar/different-style poem lists match the main build.
6. **Explore page side-effect.** Add the `{ORDERING_NOTE}` marker (or block) to
   `page-templates/explore.txt`, and fill it in the explore generator
   (`generate_explore_page` / `corpus_stats`) based on the reverse flag, using
   `src/page-template.lua`. Keep the default-mode wording unchanged.
7. **Tests.** Add a test that validates (a) chronological chunk-reversal places the
   newest chunk on page 1 with within-page ascending order, and (b) the
   similar/different date re-sort (similar latest-first, different earliest-first)
   on a small fixture corpus. Per project convention, a new feature ships with a
   test that proves it.
8. **Verify both modes.** Generate the site once without `--reverse` and once with
   it; confirm the default output is byte-identical to today and the reversed build
   paginates and links correctly (both modes must be confirmed working before this
   is considered complete).

## Related Documents / Tools

- `run.sh` — argument parser, `show_help`, `interactive_mode_tui`,
  `run_generate_html`, `run_generate_wordcloud` (the flag, menu item, and
  forwarding).
- `src/flat-html-generator.lua` — `sort_poems_chronologically_by_dates`,
  `extract_post_date_from_poem`, `generate_chronological_index_with_navigation`,
  `generate_similarity_ranked_list`, `generate_maximum_diversity_sequence`,
  `generate_page`, `corpus_stats`, `generate_explore_page`.
- `src/wordcloud-generator.lua`, `src/generate-word-pages.lua` — must receive the
  flag for `#poem` link and ordering agreement.
- `page-templates/explore.txt` + `scripts/sync-page-templates` + `src/page-template.lua`
  — where the documented side-effect lives and how prose reaches the generator.
- `config.lua` — pagination defaults (`poems_per_page`, `chronological_poems_per_page`).
- `/issues/10-062-chronological-image-viewer-reverse-and-pagination.md` — the gallery
  sibling; mirror its naming/paging conventions where they overlap.
- `/issues/completed/10-036-fix-word-page-chronological-links.md` — the precedent for
  keeping chronological pagination consistent across processes.
- `/issues/11-004-rewrite-explore-page-and-add-deeper-math-page.md`,
  `/issues/completed/11-005-externalize-explore-page-copy-into-editable-templates.md`
  — the explore page and its editable-template system.
