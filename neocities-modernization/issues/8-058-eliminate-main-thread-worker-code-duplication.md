# Issue 8-058: Eliminate Main Thread / Worker Code Duplication

## Priority
Medium

## Current Behavior

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

3. **`scripts/generate-html-parallel`**:
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
   - **Still to look at:** other caught-and-substituted loads found by
     `grep -rn 'pcall(require' src libs scripts`: `libs/external-sync.lua`
     falls back to the legacy `external_files` config when `sources-loader`
     will not load; `libs/exclusion-filter.lua`, `libs/utils.lua` and
     `libs/pipeline-validator.lua` guard `config-loader` /
     `inference-server-config`; `src/main.lua` treats the TUI `menu` module as
     optional. Each needs a decision: a real optional feature, or a fallback
     to turn into an error.

1. **Audit**: Run grep for duplicated function names across all HTML generators
   ```bash
   grep -n "format_poem_entry\|generate_progress_dashes\|is_golden_poem" src/*.lua
   ```

2. **Extract shared module**: Create `src/poem-formatter.lua` with all formatting logic

3. **Refactor workers**: Workers `require` the shared module instead of embedding code

4. **Migrate chronological**: Move chronological generation into worker scope

5. **Test parity**: Ensure output is byte-for-byte identical before/after refactor

6. **Remove main thread formatting**: Delete duplicated code from main thread

## Edge Cases

1. **Single-threaded mode**: Should still work when thread count = 1
2. **Progress display**: Main thread needs some way to show progress without doing work
3. **Error handling**: Worker failures should be reported, not silently dropped
4. **Memory pressure**: Large batches may need chunking within workers

## Success Criteria

- [ ] `format_poem_entry()` exists in exactly ONE location
- [ ] `generate_progress_dashes()` exists in exactly ONE location
- [ ] Chronological pages generated by workers, not main thread
- [ ] All page types (chrono, similar, different, word) use same formatting
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
