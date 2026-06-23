# Issue 10-048: Codebase Consolidation Sweep — Remove Duplicates, Decompose Monoliths, Archive Dormant Subsystems

## Priority
Medium

## Summary

A survey of the project's source tree (≈28,000 lines of Lua plus ≈5,500 lines of shell across 14+ development phases) identified concrete refactoring opportunities clustered into three categories:

1. **Duplication that has accumulated by isolation** — three independent HTML-escape implementations, three independent config loaders, three near-identical test files for one feature.
2. **A single 4,612-line generator** carrying four logically independent concerns inside one file.
3. **A dormant parallel architecture** in `src/html-generator/` (16 files) that the live pipeline never touches, plus four orphaned generator modules and five test files misplaced inside `src/`.

The work is broken into sub-tasks (10-048a through 10-048f below) which can be spun off into their own issue tickets when they are picked up for implementation. Items are ordered most-valuable-first.

## Current Behavior

### The HTML generator is a 4,612-line monolith

`src/flat-html-generator.lua` is the single largest source file in the project at 4,612 lines and 77 top-level functions. It is the primary HTML page generator called from the main pipeline (`main.lua` lines 584 and 601). Inside, four largely independent concerns are interleaved:

- pagination math (page sizing, slicing, prev/next nav links)
- poem formatting (golden frames, boost frames, regular entries, markdown, content warnings, color gradients)
- ranking & cache loading (similarity ranking and diversity chain construction from precomputed caches)
- per-page-type output (chronological index, paginated lists, similarity pages, diversity pages, text archives)

The four sections share a small number of locally-scoped helpers — notably a private `escape_html` and a color-gradient function — which currently prevent clean extraction without first lifting those into a shared primitives library.

### HTML escaping is defined three times, with different semantics

A function that escapes HTML entities is defined three separate times across the project:

- `src/flat-html-generator.lua:1486` — a local function with only 3 substitutions, missing apostrophe and quote escapes (a known gap referenced by an open issue)
- `src/html-generator/template-engine.lua:19` — module-level, 5 substitutions
- `src/html-generator/golden-poem-indicators.lua:13` — module-level, identical 5 substitutions to the template-engine

The flat-html-generator implementation is genuinely weaker than the other two. Identical poem text can render differently depending on which page rendered it, and apostrophe-bearing content can break HTML attributes on the main pipeline's pages.

### Three separate config loaders re-implement the same load pattern

Three modules each call `pcall(dofile, "/config.lua")` against the project root with their own root-detection logic:

- the unified config loader (the one meant to be canonical)
- the Ollama config wrapper
- the data-sources loader

Each carries its own version of project-root detection, including a hardcoded `/mnt/mtwo/...` fallback path that will silently mis-resolve on any clone to a different location. None of the three delegates to either of the others.

### A whole subsystem (`src/html-generator/`) is reached only by demos

The directory `src/html-generator/` contains 16 files (template engine, golden-collection generator, render-time similarity helper, URL manager, and 9 test files). Cross-reference analysis shows the live execution graph from `run.sh` and `main.lua` never imports anything from this directory. The only inbound references come from:

- `demos/generate-site.lua`, `demos/5-demo.lua`, `demos/3-demo.sh`
- two themselves-dead source modules (`src/centroid-html-generator.lua` and `src/regenerate-clean-site.lua`)

This is a parallel HTML-generation experiment that was superseded by the flat-html-generator path. It still works (the demos use it), but it adds confusion to the source tree because its name suggests it is the production generator.

### Four orphaned generator modules sit inside `src/`

Four files in `src/` have zero incoming imports from any driver script:

- a regeneration-from-scratch utility (one-off cleanup script, never wired in)
- a centroid embedding generator (standalone CLI, not in pipeline)
- a centroid-based HTML page generator (companion to the above)
- a gallery-page generator (1,186 lines but no callers found in any pipeline)

The centroid pair appears to be intentional power-user tooling. The regeneration utility and the gallery generator look genuinely abandoned.

### Five test files are misplaced inside `src/`

Five `test-*.lua` files sit alongside production code in `src/` rather than in a dedicated tests directory:

- a diversity-chaining test
- a mass-diversity-generator test
- a similarity-calculator test
- a report-generator test
- a validation-engine test

The last two are imported only by the orphaned validation runners (see below). The first three are orphaned outright. None of them are referenced by `run.sh`.

### The 1,573-line `run.sh` driver mixes four unrelated concerns

The main bash driver carries CLI argument parsing (~100 lines), ten pipeline stage executors (~600 lines), an interactive TUI menu (~250 lines), and logging/color helpers (~70 lines) all in one file with 22 functions sharing a single namespace.

### Smaller follow-ups

- Three near-identical test files for the golden-poem-bonus feature (the most recent supersedes the other two)
- Two CLI wrappers for the validation engine that overlap heavily and neither is wired into `run.sh`
- The shared logger (`utils.log_info` / `log_warn` / `log_error`) is bypassed in dozens of files in favor of bare `print` and `io.write`
- The main entry point carries three menu systems (TUI, simple fallback, legacy wrapper) where the legacy wrapper is no longer reachable

## Intended Behavior

A consolidated source tree where:

- **One canonical HTML-escape implementation** lives in `libs/html-escape.lua` (or as a function exported from `libs/utils.lua`), imported by every site that emits HTML.
- **The 4,612-line HTML generator is decomposed** into four siblings of roughly 800–1,400 lines each, organized along the natural concern boundaries (pagination, formatting, ranking lookup, page-type dispatch).
- **A single config-loading layer** owns project-root detection and `dofile` parsing. The Ollama config and the data-sources loader depend on it rather than re-implementing it. The hardcoded fallback path is removed in favor of a single detector that fails loudly when invoked outside a clone.
- **The dormant subsystem is archived** to `demos/html-generator-experiment/` (or absorbed into a libs module if a piece of it deserves promotion to production), clearing the parallel architecture from the active source tree.
- **Orphan modules are evaluated** and either deleted, moved to `scripts/` (if standalone), or wired into the pipeline (if they should be live).
- **Test files live in a `tests/` directory** at project root, separate from `src/`.
- **`run.sh` becomes a thin entry point** that sources four lib files: a CLI parser, the pipeline stages, the interactive TUI, and shared logging. The logging helpers are shared with `generate-embeddings.sh`.

## What Should NOT Change

The three modules named `*similarity-engine*` look like duplicates by name but are actually three distinct layers and **should remain separate**:

- the batch embedding generator (`src/similarity-engine.lua`)
- its parallel-dispatch variant (`src/similarity-engine-parallel.lua`)
- the render-time lookup helper (`src/html-generator/similarity-engine.lua`)

Merging them would conflate compute, dispatch, and read layers that benefit architecturally from being separate. Renaming them to disambiguate (e.g., `embedding-batch-generator`, `embedding-parallel-runner`, `similarity-lookup`) is an acceptable smaller change if the name collision causes confusion during reading.

## Sub-Tasks

Each of these can be promoted to its own issue file (10-048a, 10-048b, …) when picked up. They are ordered by recommended execution sequence — earlier items unblock or de-risk later ones.

### 10-048a: Unify the HTML-escape implementation
Extract a single canonical `escape_html` into a shared library (most natural place is `libs/` since `utils.lua` already exists there). The canonical version should escape `&`, `<`, `>`, `"`, and `'`. Replace the three existing implementations with imports. Verify rendered output is unchanged for non-quote-bearing content and that quote-bearing content now renders correctly through the main pipeline.

Relevant files: `src/flat-html-generator.lua`, `src/html-generator/template-engine.lua`, `src/html-generator/golden-poem-indicators.lua`.

### 10-048b: Move tests out of `src/` and delete orphan tests
Create a `tests/` directory at project root. Move the five `src/test-*.lua` files there. Delete the nine `src/html-generator/test-*.lua` files (none of them are imported by anything reachable from the live pipeline; this can be re-confirmed with a cross-reference search before deletion). Among the three duplicate golden-poem-bonus tests, retain only the most recently modified one and discard the other two.

### 10-048c: Archive the dormant `src/html-generator/` directory
Move the directory to `demos/html-generator-experiment/` so the demos that depend on it continue to work, but its presence no longer suggests it is production code. As part of the move, evaluate whether the template-engine's escape function and any other reusable primitives should be lifted into `libs/` before archival.

### 10-048d: Remove or relocate orphan generator modules
Evaluate each of the four orphaned modules (regenerate-clean-site, centroid-generator, centroid-html-generator, generate-gallery-pages). For each: delete outright, move to `scripts/` (if standalone power-user tool), or wire into a phase demo (if it represents a feature that should be demonstrated). Document the disposition in this issue.

### 10-048e: Consolidate config-loading behind one canonical loader
Modify the Ollama config module and the data-sources loader to depend on the canonical config-loader rather than calling `pcall(dofile, ...)` themselves. Lift project-root detection into a single `utils.detect_project_root()` function that fails loudly when called from outside a clone (no hardcoded `/mnt/mtwo/...` fallback).

### 10-048f: Decompose `flat-html-generator.lua` into four siblings
Split along the four natural concern boundaries identified above:

- a pagination helper
- a poem formatter
- a ranking front-end (cache loader + per-poem ranking accessors)
- a page-type dispatcher

Prerequisite work: lift any locally-scoped helpers used across multiple sections into a shared primitives module first (this is partly accomplished by 10-048a for the escape function). The split itself is mechanical once helpers are hoisted.

### 10-048g: Decompose `run.sh` into a thin entry point plus four sourced lib files
- `lib/cli-parser.sh` for argument parsing
- `lib/pipeline-stages.sh` for the ten stage executors
- `lib/interactive-mode.sh` for the TUI menu
- `lib/logging.sh` for color and log helpers (shared with `generate-embeddings.sh`)

Each lib file should contain declarations only — no side effects at source time — so order doesn't matter.

### 10-048h: Tidy follow-ups
- Consolidate the two validation CLI wrappers (`run-validation.lua` and `run-validation-with-reports.lua`) into one runner with a `--reports` flag, or wire the comprehensive one into `run.sh` if it represents desired pipeline behavior.
- Remove the unreachable legacy menu wrapper from the main entry point.
- Audit new code in subsequent phases to route through the shared logger rather than bare `print`.

## Suggested Implementation Steps

Recommended execution order (each step keeps risk low for the next):

1. **Sub-task 10-048a** — unify HTML escape. Smallest scope, highest confidence, eliminates a bug class immediately.
2. **Sub-task 10-048b** — move and clean up tests. Pure reorganization, no behavior change.
3. **Sub-task 10-048c** — archive the dormant subsystem. Removes the largest single block of confusing parallel architecture from the active tree.
4. **Sub-task 10-048d** — handle orphan generators. Decide disposition per module; small risk of deleting something a forgotten workflow depends on, so confirm with `git log` before each deletion.
5. **Sub-task 10-048e** — consolidate config loading. Removes the hardcoded-path footgun and the duplicate `dofile` calls.
6. **Sub-task 10-048f** — decompose the HTML generator. The biggest structural change, made safer by the helper-extraction work that step 1 began.
7. **Sub-task 10-048g** — decompose `run.sh`. Independent of all earlier steps; can run in parallel with 10-048f.
8. **Sub-task 10-048h** — tidy follow-ups. Low-priority polish.

The deletion-focused steps (10-048b, 10-048c, 10-048d) collectively remove an estimated 2,500–3,000 lines of code with high confidence. Most of the remaining value is in structural simplification rather than further code reduction.

## Related Issues

- **8-058: Eliminate Main Thread / Worker Code Duplication** — Related territory (HTML generation code duplicated between main thread and effil worker scopes). The decomposition in 10-048f should be coordinated with that work so the worker-thread copies and the main-thread copies converge on the same set of new sibling modules.
- **8-034: Refactor to Triangular Individual Files Only** — Earlier refactoring effort in the storage layer, useful as a precedent for how the project handles structural changes.
- **10-010: Integrate Test Suites into Development Pipeline** — Once 10-048b moves tests into `tests/`, this becomes more tractable.

## Metadata

- **Status**: Open
- **Created**: 2026-06-15
- **Phase**: 10 (Developer Tooling / Website Completion)
- **Estimated Complexity**: Large (umbrella; individual sub-tasks range from Small to Medium)
- **Dependencies**: None for the cleanup sub-tasks. The decomposition tasks (10-048f, 10-048g) are easier after the helper extraction in 10-048a.
- **Affects**: HTML generation pipeline, config loading layer, source tree organization, test placement, main bash driver. No effect on rendered output if executed faithfully.
