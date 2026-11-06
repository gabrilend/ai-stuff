# Issue 015: Testing Framework for Large Scale Generation

## Current Behavior
No comprehensive testing system exists for validating the correctness of large-scale processing tasks before full execution.

## Intended Behavior
Develop robust testing framework that:
- Validates HTML generation correctness before processing ~4000 pages
- Tests embedding calculations on sample data
- Verifies navigation system functionality
- Provides incremental testing capabilities
- Ensures output quality before resource-intensive operations

## Suggested Implementation Steps
1. Design test data sets with known expected outcomes
2. Create unit tests for embedding similarity calculations
3. Build integration tests for HTML generation pipeline
4. Implement sampling strategies for large data set validation
5. Add regression testing for PDF generation changes
6. Create performance benchmarks and validation
7. Design test automation and continuous validation
8. Add test reporting and error analysis tools

## Related Documents
- Source: next-4 file (lines 20-23)
- Related to: All major system components

## Metadata
- Priority: High
- Complexity: Medium
- Dependencies: All other system components
- Estimated Effort: Medium

## Implementation Notes
Essential for validating system correctness before expensive processing operations. Should be developed alongside major features to enable iterative testing.

## What Happened (slice A: offline unit tests, 2026-11-02)

The first slice builds the part of this issue that needs no embedding
server, no libharu and no real corpus: unit tests for the functions that
load, lay out and theme the book. Steps 1, 2 and 5 are partly done; the
HTML-generation and navigation tests (steps 3, 4, 6) wait until the HTML
output exists, so this issue stays open.

- `tests/run-tests [DIR]` runs every `tests/test-*.lua` under each Lua
  interpreter the machine has (lua5.2, luajit, lua5.4; a missing one is
  skipped and named) and exits non-zero on a failed check, a test that
  crashed before counting, or no interpreter at all. Same idiom as
  `my-libs/zip/tests/run-tests`.
- `tests/kit.lua` is the shared checking kit (check / same / near /
  lines / truthy / finish, ending with a `counts <passed> <failed>` line
  the runner reads). `kit.load_compiler` loads `compile-pdf-ai.lua` with
  a stand-in for the `hpdf` binding and `WORDS_PDF_NO_MAIN` set, so its
  functions can be called without generating a book.
- `tests/test-corpus.lua` (20 checks): `detect_poem_type`,
  `normalize_poem_spacing`, `load_file` on `tests/fixtures/corpus.txt`
  (a small synthetic corpus, no real posts), and a check that the
  embedding loader's copy of the normalizer
  (`themes-v2/load-poem-embeddings.lua`) gives the same result as the
  compiler's, since both must agree for the embedding cache to hit.
- `tests/test-layout.lua` (15 checks): `calculate_poem_height`,
  `build_book` invariants on books from a fixed-seed generator (every
  line placed exactly once and in order, no column over
  `MAX_LINES_PER_PAGE`, no empty column, long poems start a fresh
  column), issue 028's gate, and `calculate_art_spaces` on the real A4
  geometry.
- `tests/test-similarity.lua` (14 checks): `cosine_similarity`,
  `find_most_similar_theme` and the frequency-weighted chooser.

Changes to `compile-pdf-ai.lua` that the tests needed or found:

- `main()` runs only when `WORDS_PDF_NO_MAIN` is unset, so the script can
  be loaded for its functions. `./run` is unaffected.
- Issue 028's region filter moved out of `generate_page_art` into
  `select_tier1_regions(spaces, page_width, page_height)`, unchanged in
  behavior, so it can be tested without a PDF page.
- `load_file` stops with a clear error when the input file cannot be
  opened (it used to print a message and then crash on a nil file).
- `load_file` leaves out blocks that are empty after normalizing.

### Decisions

- **Empty blocks are skipped.** They drew nothing but still took five
  lines of column height each in `build_book`. Theme scores are keyed by
  each poem's position in `book.poems` and embeddings by text, so
  nothing else shifts.
- **Lua 5.4 is tested alongside 5.2 and LuaJIT.** The machine the tests
  were written on has no lua5.2; the runner skips it there and runs it
  wherever it is installed.
- **Fixture, not real corpus.** The real corpus is large and private;
  the fixture covers each block type `detect_poem_type` knows.
- **Two findings filed rather than changed here:** issue 033 (the Tier 1
  gate always passes on a themed page) and issue 034 (the weighted theme
  chooser favors overused themes when every score is negative). A check
  in `test-layout.lua` records 033's current behavior and names the issue.

## What Happened (rendering geometry, 2026-11-02)

- `tests/test-render.lua` (8 checks, issue 035) runs `draw_boxed_poem`
  against a recording stand-in for libharu, and checks the art layout
  against what was drawn. This is a first regression test for PDF
  generation (step 5) that needs no libharu.
