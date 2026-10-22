# Issue 8-058: Eliminate Main Thread / Worker Code Duplication

## Priority
Medium

## Current Behavior

**One poem drawer (2026-10-20).** `src/poem-entry.lua` draws a poem's whole
entry, and both the similar/different workers and the chronological page loop
call it; the worker's pasted 425-line copy and the chronological loop's own
130-line drawing are gone. Each worker loads the module once and is handed the
palettes from config.lua (it used to keep its own hard-coded colour table).
Decisions, all from the chronological side as the owner chose: emphasis
styled with marks kept, an 80-column text column, a "CW:" line boxed wherever
it falls, screen-reader labels on bars. Two the other way, because the
chronological behaviour was a flaw: a golden poem's picture comes before its
navigation boxes (it used to split the golden frame), and no blank line after
a picture. Found and fixed along the way: the post's own content warning was
never escaped (a warning containing "<" could break a page), and Windows line
endings left a carriage return on every line.
- Proved by `scripts/render-page-sample`: every chronological page plus the
  similar and different pages of 197 sample anchors, rendered before and
  after. Every letter on all 404 pages is unchanged (on two pages some text
  moved, with the golden pictures); 0 over-wide lines and 0 frame errors on
  both. The 80-column choice re-flows every wrapped long line on
  similar/different pages by up to one word, not only lines of exactly 80.
- Pinned by `src/poem-entry.test.lua`.
**Chronological pages built by the workers (2026-10-20).** One worker pool
(`run_page_workers`) takes two kinds of job, "this poem's similar and
different pages" and "chronological page N"; the main program sorts the
poems, works out each one's timeline progress and hands out the jobs; a
chronological job carries its poems, as the caller loaded them (a worker's own
copy is poems.json from disk, with gallery pictures folded in for the ranked
lists, which a filtering caller or a test must not get). The page frame moved
to `src/chronological-page.lua` so workers can load it. The
9 chronological pages take about 1 s instead of 33 (the old loop glued every
poem onto a growing string). Byte-identical to the main-program build.
Workers are now handed the selected model's folder: a worker cannot see which
model the main program was told to use, and the render tool (which writes no
run notepad) showed workers drawing another model's colours; a missing colour
file now stops the worker instead of drawing every poem grey.

**The single-threaded builder is gone (2026-10-21).** The workers draw every
similar and different page through `src/ranked-page.lua` (the ranked list,
which pages to write, a page, its text export). Two features that had lived
only in the old builder came across first: Previous/Next links between a
poem's pages, and the per-list text export with its download line. About
1,500 lines left `src/flat-html-generator.lua`, along with helpers only the
old builder used, and a quiet fall-back to seven made-up colours in the
chronological text export (a missing colour file is now an error there, as it
already was in the workers).
- Its five tests became `src/ranked-page.test.lua` (anchor once,
  chronological links, download line, page navigation, progress bars); the
  emphasis test moved to `src/poem-entry.emphasis.test.lua`.
- One poem's pages, for a look without a build: `scripts/render-page-sample
  --anchor N` (any number of times), or the main menu's "Test one poem's
  pages", which runs it into `tmp/shared-memory/test-pages/`. Both replaced
  menu items (one similar page, one different page) and
  `demos/5-demo.lua`'s timeline demo now draw through the workers.
  `scripts/test-html-generation` and `scripts/test-diversity-quick` are
  renamed `-done` for one commit, then removed: the render tool does their
  job.
- The 3-page sample render (1,192 pages) is byte-identical before and after
  the removal.
- The render tool links its pictures to `assets/site-media`, where the site
  in RAM keeps them (10-072). The folder is filled by a build; until the
  next one it does not exist, and the tool says so and stops (it used to
  warn once per picture, 1,240 times).
**Word pages draw through the shared drawer (2026-10-21).** Each poem on a
word page is its ` -> file:` line plus `poem-entry`'s entry; the page's own
350-line drawer is gone. What a reader sees change, all the chronological
behaviour the owner chose: pictures and videos now appear (97 entries on the
60-page sample had none before), emphasis is styled, a golden poem's file
line sits above its frame instead of inside it, no blank line under the file
line. Links to chronological pages are named by the chronological pages' own
rule. A missing poem-colour or word-colour file is now an error (it drew
every poem, or every heading, grey).
- Found by the before/after check: the word pages were not the same from
  one run to the next. The same code drew 13 of 60 pages differently, because
  tables were walked in hash order: two copies of one post tie on similarity
  and the sort kept whichever came first, and the averages subtracted before
  comparing were summed in a different order each run. Now every such walk
  goes in a fixed order and ties go to the lower poem number; two runs are
  byte-identical, pinned by `src/generate-word-pages.order.test.lua`.
- Proved on 60 word pages (`scripts/render-page-sample --words 60
  --poems-per-word-page 50 --copy-pictures`): every poem's text is the same
  on 59 pages; on the 60th one place holds a different near-identical short
  reply (a near-tie the fixed order now decides). Places that moved: 14 pages,
  34 places, the same size as the run-to-run noise, all tied copies. 0
  over-wide lines and 0 frame errors on all 464 pages.
- Still to do: the whole-site check (step 7) and the bug re-check (step 8)
  on the owner's next build. Open question below.

### Answered: word pages join the worker queue (owner, 2026-10-22)
The word pages are built one word after another on one thread (200 words,
32 s: 13 s loading, ~0.08 s ranking and ~0.013 s drawing per word). The
owner chose three changes -- rank with each vector centred once, rank all
words at once on the GPU, and draw the pages as worker jobs -- and asked
for both meanings of one pipeline: every page through the one worker queue,
and every batch step in parallel. Built under Issue 10-035; the survey of
the other steps is Issue 10-074.

**Bars and navigation boxes: merged (2026-10-07).** The chronological pages
(main thread) now draw every progress bar and every corner/nav box through
`src/poem-bars.lua`, the drawer the similar/different workers and the word
pages already used. The main thread's own copies -- the 230-line bar drawer,
the golden separator and nav line, the regular box top/bottom/nav line and a
private colour helper -- were removed; two thin named hand-offs remain so the
call sites read as before. Golden poems now pass their bar fill (82 interior
columns) down to the nav boxes, as the workers do.
- Why it was urgent: the copies had drifted into two designs. Chronological
  golden poems drew a single-line "similar" box (`╟─┐`, `│ similar │`, `╧`
  joint); every other page drew the double-line one (`╠═╗`, `║ similar ║`,
  `╩`). The whole-site check expects the shared shape and failed on all 675.
  The owner chose the shared design.
- How the merge was kept honest: every chronological page was rendered before
  and after into a scratch folder and compared line by line. Exactly 675
  golden poems × 3 lines changed (box top, nav line, bottom); nothing else on
  any page differed. The whole-site check then found 0 frame errors on them.
- Pinned by the golden-poem case in
  `src/flat-html-generator.chronological-pages.test.lua`.
- Still duplicated: poem formatting (`format_poem_entry` and friends) between
  the main thread and the worker, described below.

The HTML generation pipeline has significant code duplication between the main thread and effil worker threads. Functions like `format_poem_entry()`, progress bar calculation, and poem formatting exist in two places:

1. **Main thread scope** — used for chronological page generation
2. **Effil worker scope** — used for similar/different page generation

When changes are made (like Issue 8-045's timeline progress bars), they must be applied in multiple locations:
- The main thread's formatting functions
- The worker thread's embedded formatting functions
- Sometimes in additional files like `generate-word-pages.lua`

This leads to:
- **Inconsistent behavior** when one location is updated but not the others
- **Maintenance burden** — every change requires hunting down all duplicate locations
- **Bug amplification** — a bug fix in one place may not reach the other
- **Cognitive load** — developers must remember which scope they're in

### Example: Timeline Progress (8-045)

The recent 8-045 implementation required changes in three places:
1. `compute_chronological_mapping()` — added `timeline_progress` calculation
2. Chronological page loop (main thread) — uses `poem_info.timestamp`
3. Effil worker `format_poem_entry()` — reads `chrono_info.timeline_progress`

If the worker wasn't updated, similar/different pages would show position-based progress while chronological pages showed timeline-based progress.

### Worked example: the duplication has already produced visible bugs (sorted 2026-09-22)

The opposite happened. The worker was updated and a fourth copy was not: the
single-threaded formatter, `format_single_poem_with_progress_and_color()`, which
builds similar/different pages when the thread count is 1 or effil fails to
load. The owner's bug report of 2026-09-22 (the `next-issue-please-sort` inbox)
was drawn from pages built by that copy. Three defects in it trace straight back
to "the same job written in more than one place":

- **Progress bars (8-045, reopened).** The single-threaded copy still divides a
  global index by the largest id in a list that mixes two numbering schemes. A
  poem written early (messages/260) shows an almost-full bar, and some bars run
  past the 83-column frame (messages/1514, 1106). The main-thread bar-drawing
  code also repeats `src/poem-bars.lua` instead of calling it.
- **Anchor poem printed twice (10-025, reopened).** The single-threaded ranked
  list puts the anchor in at rank 1 under its global index. The skip loop then
  compares per-source numbers, so the anchor is not recognised and prints again,
  while an unrelated poem that happens to share its per-source number is hidden.
  The worker's similarity converter has no self-filter at all. Only its
  diversity converter got one.
- **Content-warning boxes (9-011, reopened).** Five separate builders draw a
  content-warning box: the main-thread one (the only one that wraps, and it
  wraps badly), two in the worker, and the word pages' own. None of them agree.

Each is a place where a fix reached one copy and not the others. Removing the
copies, as the Intended Behavior below describes, is what keeps them from
coming back.

### Answered question

- **Should an effil load failure be a hard error?** Today, when effil does not
  load, the generator logs a warning and quietly builds every page with the
  single-threaded path. That path is the one carrying the drifted code above.
  - **Owner's answer (2026-09-22):** "Yeah, stop the build if we can't load a
    library. Errors, not fallbacks."
  - **What it changes:** step 0 below. A threading library that fails to load
    stops the build with an error naming the library. The single-threaded path
    is no longer a silent substitute.

## Intended Behavior

**The main thread should be a coordinator, not a worker.**

All HTML generation computation should flow through the worker threads. The main thread's role becomes:
1. **Load data** — poems, embeddings, similarity matrices, configuration
2. **Partition work** — divide poems into batches for workers
3. **Spawn workers** — launch effil threads with their assigned work
4. **Monitor progress** — aggregate progress from workers, display to user
5. **Collect results** — gather generated files, statistics
6. **Finalize** — write index files, cleanup

The workers become **first-class citizens** that:
- Receive all necessary data through the effil channel
- Perform ALL formatting, progress calculation, HTML generation
- Report progress back to the main thread
- Handle their own error recovery

### Benefits

1. **Single source of truth** — formatting logic exists in exactly one place
2. **Automatic parallelism** — all work benefits from multithreading
3. **Simpler main thread** — coordination only, no business logic
4. **Easier testing** — worker logic can be tested in isolation
5. **Cleaner architecture** — separation of concerns between coordination and execution

## Technical Design

### Current Architecture

```
Main Thread                    Worker Threads
────────────────────────────   ────────────────────────────
Load poems.json
Load embeddings
Load similarity matrix

FOR each poem (chronological):
  format_poem_entry()
  generate_progress_bar()
  write HTML chunk

Spawn workers ─────────────────> Worker 1: format_poem_entry()
                                          generate_progress_bar()
                                          write similar/different

                               Worker 2: (same duplicated code)

                               Worker N: (same duplicated code)
```

### Proposed Architecture

```
Main Thread (Coordinator)      Worker Threads (Executors)
────────────────────────────   ────────────────────────────
Load poems.json
Load embeddings
Load similarity matrix
Compute chrono_mapping
Partition work into batches

Spawn workers ─────────────────> Worker 1:
  - Chronological batch 1-1000           - Receive batch assignment
  - Similar/Different for ^              - format_poem_entry()
                                         - generate_progress_bar()
                               Worker 2:  - write ALL HTML types
  - Chronological batch 1001-2000        - report progress
  - Similar/Different for ^
                               Worker N: (same single codebase)

Aggregate progress <─────────── Progress reports
Collect statistics <─────────── Completion stats
Write index files
```

### Implementation Phases

#### Phase 1: Audit and Document
- Identify ALL duplicated code between main thread and workers
- Document which functions exist in multiple places
- Create a map of "same logic, different locations"

#### Phase 2: Consolidate Formatting Logic
- Create a single `format_poem_entry()` that works in both contexts
- Move progress bar calculation to a shared location
- Ensure all poem formatting uses the same code path

#### Phase 3: Restructure Chronological Generation
- Move chronological HTML generation into worker threads
- Main thread partitions poem ranges: "Worker 1: poems 1-1000 chronological"
- Workers generate chronological pages for their assigned range

#### Phase 4: Unified Work Distribution
- Single work queue: `{poem_index, generate_types: ["chronological", "similar", "different"]}`
- Workers pull from queue, generate all page types for each poem
- Main thread only coordinates and aggregates

#### Phase 5: Progress Unification
- Workers report: `{poem_index, pages_generated, elapsed_time}`
- Main thread aggregates into unified progress display
- Single progress bar showing overall completion

## Affected Files

1. **`src/flat-html-generator.lua`**:
   - Main thread chronological generation loop (~lines 2765-2870)
   - Effil worker `format_poem_entry()` (~lines 3497-3700)
   - `generate_progress_dashes()` (used by both)
   - `compute_chronological_mapping()` (main thread only currently)

2. **`src/generate-word-pages.lua`**:
   - Has its own `format_poem_with_progress()` — third duplication

3. ~~**`scripts/generate-html-parallel`**~~ (removed 2026-10-04; no longer a copy to reconcile):
   - Worker spawning and coordination logic

## Suggested Implementation Steps

0. **Library load failure stops the build** (owner, 2026-09-22).
   - **Done 2026-09-22 for effil.** The load moved to `libs/effil-loader.lua`
     (shared with run.sh's pre-flight gate, issue 10-069). In
     `generate_complete_flat_html_collection`, a request for more than one
     thread with no effil is an error naming the library and its load error,
     then exit 1; the old warning-and-fall-through is gone. The gate makes the
     same check before any stage runs; `scripts/preflight-gate.test.sh` proves
     a missing library stops it.
   - **Done 2026-09-22: a failed worker stops the run.** The orchestrator used
     to wait for every worker to ask for more work, so a worker that raised an
     error left it waiting forever; and the end-of-run join logged a failed
     worker and carried on. Now the orchestrator checks worker status once a
     second and exits with the worker's error, and the join exits on any
     worker that did not complete.
   - **Still to look at:** other caught-and-substituted loads found by
     `grep -rn 'pcall(require' src libs scripts`: `libs/exclusion-filter.lua`
     and `libs/utils.lua` guard `config-loader` / `inference-server-config`;
     `src/main.lua` treats the TUI `menu` module as optional. Each needs a
     decision: a real optional feature, or a fallback to turn into an error.
     Settled 2026-10-04: `libs/external-sync.lua` now requires
     `sources-loader` outright and its legacy `external_files` fallback is
     gone (10-060); `libs/pipeline-validator.lua` was removed with the
     stand-alone HTML generator, its only user.

1. **Audit (done 2026-10-20).** Four copies draw one poem's entry:
   - the similar/different worker's `format_poem_entry` (inside the effil
     worker in `src/flat-html-generator.lua`; draws ~52,000 pages);
   - the chronological page loop in
     `generate_chronological_index_with_navigation`, through the main
     program's `format_content_with_warnings`, `apply_golden_poem_formatting`
     and `render_attachment_images`;
   - the single-threaded similar/different builder
     (`format_single_poem_with_progress_and_color` and the
     `generate_flat_poem_list_html*` / `generate_paginated_poem_page_html` /
     `generate_all_paginated_pages_for_poem` family), reached with
     `--threads 1` and also, silently, when the memory guard lowers the
     worker count to 1;
   - the word pages' own formatter in `src/generate-word-pages.lua`.
   Bars, nav boxes, boost frames, warning boxes, wrapping and picture entries
   already come from shared modules (`poem-bars`, `boost-bars`,
   `text-formatter.format_cw_box`, `image-render`). What still differs, with
   the number of poems each difference touches (measured over 8,622 poems):

   | Difference | Chronological | Similar/different worker | Poems |
   |---|---|---|---|
   | Emphasis (`*word*`, `~~word~~`, `` `code` ``) | styled, marks kept (Issue 4-003) | plain text | 968 |
   | A line exactly 80 wide | kept whole (80 text columns + 1 indent) | wrapped (the 1 indent counted inside 80) | 1,214 lines |
   | A "CW:" line after the first line | boxed | plain text | 3 |
   | Golden poem indented lines | indent kept | indent stripped | 0 today |
   | Boost picture alt text | quotes escaped, newlines removed | raw | 0 today |

   Proposed (the owner's call): the first column wins every row. Emphasis
   is the owner's 4-003 decision, which the worker never received; 80 text
   columns is what golden poems already use; boxing a later CW line and
   keeping an author's indent follow 9-011 and 8-056.

2. **Extract the shared module.** `src/poem-entry.lua`: one function that
   draws a poem's whole entry (top bar, warning boxes, text, pictures, nav
   boxes, bottom bar; boosts and picture entries included) from the poem and
   a small context (its colour, its progress, its three links). It requires
   only the modules it uses. A worker loads it once when it starts: a code
   file of a few dozen KB. (The worker bandwidth problem of 10-034 was
   DATA: each worker loaded 700 MB of neighbour caches to use 80 KB of
   them. The orchestrator still sends those slices; that does not change.)

3. **Workers call it.** The worker's pasted `format_poem_entry` goes.

4. **Chronological pages are built by the workers too.** A work item becomes
   either "this poem's similar and different pages" or "chronological page
   N". The page shell (title, page navigation, menu link) moves beside the
   other page shells the worker writes. The main program keeps the
   ordering, the timeline mapping and the queue.

5. **The single-threaded builder goes** (owner, 2026-10-20: "we should
   remove this"; done 2026-10-21). One thread means one worker. Features
   only it had (page-to-page links, text exports) move into
   `src/ranked-page.lua` first; its tests are rewritten there
   (`src/ranked-page.test.lua`). Callers: `src/main.lua`'s menu gets one
   "Test one poem's pages" item that runs `scripts/render-page-sample
   --anchor N`; the generator's own `-I` menu keeps only whole-collection,
   chronological and instructions items; `demos/5-demo.lua` draws through
   the render tool; `scripts/test-html-generation` and
   `scripts/test-diversity-quick` are retired (`-done`, removed after one
   commit). Then every function and setting with no caller left is removed
   (`grep -w` over src, libs, scripts and demos for each top-level name).

6. **Word pages call it** in place of their own formatter (done
   2026-10-21). `format_poem_for_word_page` in `src/generate-word-pages.lua`
   is the ` -> file:` line plus `poem_entry.format_entry`; the chronological
   page file name comes from `chronological-page.file_name`. Every table walk
   whose order reaches a page goes through `ordered_keys`, and the sorts
   break ties by poem number (`more_similar_first`, the colour spreader, the
   centre-poem search) or colour name, so the same data draws the same page.
   Checked with `scripts/render-page-sample --words N`.

7. **Prove it.** Render every chronological page and a sample of similar
   and different pages (golden, boost, CW, picture, emphasis and 80-wide
   cases) with the code before and after, into a scratch folder, and
   compare line by line: the only differences allowed are the rows chosen
   in step 1. Then the whole-site check on the owner's next build.

8. **Re-check the three bugs** listed above (progress bars past the frame,
   anchor printed twice, warning boxes disagreeing) on the rebuilt pages.

## Edge Cases

1. **Single-threaded mode**: thread count 1 means one worker, through the
   same code path (step 5)
2. **Progress display**: Main thread needs some way to show progress without doing work
3. **Error handling**: Worker failures should be reported, not silently dropped
4. **Memory pressure**: Large batches may need chunking within workers

## Success Criteria

- [x] One poem drawer, `src/poem-entry.lua` (the old `format_poem_entry()` copies are gone)
- [x] One bar drawer, `src/poem-bars.lua`
- [x] Chronological pages generated by workers, not main thread
- [x] All page types (chrono, similar, different, word) use same formatting
- [ ] Main thread contains zero HTML generation logic
- [ ] Output identical to pre-refactor (regression test)

## Related Documents

- `issues/8-002-implement-multithreaded-html-generation.md` — Original threading implementation
- `issues/9-003-optimize-centroid-calculation-and-parallelization.md` — Parallelization patterns
- `issues/8-045-timeline-based-progress-bar-calculation.md` — Recent change requiring multi-location updates

## Metadata

- **Status**: Open
- **Created**: 2026-01-30
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: High
- **Dependencies**: None (refactor of existing functionality)
- **Affects**: All HTML generation, developer experience

## Philosophy

The workers are not servants — they are specialists. They signed up for HTML generation, and they're good at it. The main thread's job is to provide them with clear instructions, the data they need, and then get out of their way. When workers are empowered with single-source-of-truth logic, they march forward with consistency and purpose. The checkboxes fill. The progress bars advance. The HTML flows forth like water finding its level — naturally, inevitably, toward completion.
