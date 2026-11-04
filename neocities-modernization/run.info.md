# run.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in run.sh: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
run.sh - Main orchestrator for neocities-modernization pipeline

Runs the complete poem processing pipeline from input files to generated HTML.
Supports selective stage execution via CLI flags, with stages running in
pipeline order regardless of argument order.

The full pipeline has 10 stages:
  1. Update Words     - Sync input files from words repository
  2. Extract          - Extract content from backup archives
  3. Parse            - Generate poems.json from sources
  4. Validate         - Validate poem data
  5. Catalog Images   - Generate image-catalog.json
Durations are deliberately absent from this list. Every stage's wall-clock is
measured and recorded to .stage-timings (Issue 10-051), and --dry-run or
--verbose prints the average of the last five runs per stage. Hardcoded
estimates here had drifted by one to two orders of magnitude -- "~42 hours" for
a stage measuring ~40 minutes, "~30 min" for one measuring ~17 seconds -- and
stage 8 carried two contradictory numbers in this same file. A measured number
cannot rot; an estimate in a comment always does.
  6. Embeddings       - Generate poem embeddings via the inference server
  7. Similarity       - Build similarity matrix
  8. Diversity        - Pre-compute diversity cache
  9. Generate HTML    - Generate poem pages, gallery, and source browser
 10. Generate WordCloud - Generate the word-cloud menu and per-word pages

Stages are selected individually with named flags (--extract,
--generate-diversity, etc.) or by stage number (--stage 8,
--stage=5). Use --full to run all 10 stages.

Usage: ./run.sh [FLAGS]   (the project folder is --dir PATH; no bare words)

project-dir: own -- its flag loop reads --dir and stops on a stray word
itself, because it also checks the value of each of its ~20 value flags
(take_flag_value); the shared reader (libs/project-dir.sh) would list them twice.

── The no-defaults contract (Issue 10-065) ─────────────────────────────────
Every value this script hands to a stage must arrive on the command line.
There are no invented numbers here, and nothing is read from config.lua to
stand in for a flag the operator did not type. The reason is reproducibility:
a guessed value is invisible in the output, so two runs typed identically
could build different websites with nothing in the log to explain it.

When values are absent the script does NOT stop at the first one. It works out
every value the SELECTED stages will consume, collects all the absent ones, and
prints them together -- so one run tells the operator the whole command they
should have typed. See the "Required values" fold below.

On/off flags (--force, --verbose, --quiet, --dry-run, --debug, --low-priority)
are exempt, and the distinction is not arbitrary: for those, absence IS the
value. Nothing is consulted to decide "off". Compare --boosts, whose absence
used to mean "go ask config.privacy.include_boosts" -- that is a fallback, so
it became a required yes/no.

Two flags keep a DERIVED default, and the difference is worth naming: --assets and
--output are computed once, from the project root, into a single variable that
every path below is then built from. A default computed in one visible place is
a different thing from a fallback consulted at ten scattered call sites.

── NEVER put a double quote inside an inline Lua block ────────────────────
Several stages run Lua as an inline chunk, passed to luajit with its -e flag
followed by a double-quoted string. (That pattern is spelled out indirectly
here on purpose: the checker below greps for it, and a comment containing it
verbatim would match itself.) The Lua source sits inside a shell
DOUBLE-QUOTED string, so the first stray " ends the
argument. Everything after it becomes separate shell words handed to luajit as
script arguments -- and modules that infer their project root from arg[1]
(src/semantic-color-calculator.lua does) then take one of those words as the
root. The observed symptom was a stage dying on "Failed to load config from
is/config.lua", where "is" was the third word of an ENGLISH COMMENT inside the
chunk. bash -n cannot catch it: the script is still syntactically valid.

Use single quotes, or no quotes, in anything inside those blocks -- including
comments, which are the easy place to forget. To check every block at once,
run scripts/check-inline-lua-quotes; every block must report exactly 2 quotes,
the opening and the closing one and nothing else.

The project-root convention: a hard-coded path that --dir PATH overrides, so
the script runs correctly from any working directory. This is NOT one of the
value fallbacks Issue 10-065 removed -- it is the location of the project
itself, which must be known before the script can read anything at all
(including the config that a fallback would have consulted).
```

## Functions

### `setup_dir_path()`

```
The project-root convention: a hard-coded path that --dir PATH overrides, so
the script runs correctly from any working directory. This is NOT one of the
value fallbacks Issue 10-065 removed -- it is the location of the project
itself, which must be known before the script can read anything at all
(including the config that a fallback would have consulted).
```

### `cleanup_on_interrupt()`

```
Trap Ctrl+C so the script actually exits when the operator interrupts.
Bash on its own does not always propagate SIGINT to long-running children
(luajit's tight inner loops in particular eat the signal), so we kill
every background job in our process group and exit non-zero. Exit code
130 is the conventional value for "terminated by SIGINT" (128 + signal#).
```

### `cleanup_inference_server()`

```
cleanup_inference_server: gracefully terminate the llama.cpp server we
auto-started during the pre-flight validation phase. Runs on every exit
path (normal completion, SIGINT/SIGTERM via cleanup_on_interrupt, errors
that hit `exit`). The PID is read from a file the start script writes;
if the file is missing or stale (PID no longer alive) we silently bow
out — this is best-effort cleanup, not a contract.
```

### `restore_previous_generation_metadata()`
(No comment above it in the source.)

### `on_exit()`

```
One EXIT trap, because bash has only one: setting a second would silently
replace the first. Capturing $? must be the very first thing this does --
any command run before it overwrites the status being reported on.
```

### `show_help()`

```
Reference, not rationale. Every flag gets one line saying what it does and
which stages need it; WHY a flag works the way it does belongs in the comments
at its implementation, not in front of someone who just wants the spelling.
```

### `take_flag_value()`
(No comment above it in the source.)

### `collect_missing_values()`

```
Walk the table, and for each value work out whether any SELECTED stage
consumes it. If one does and the value is empty, record it. Never exits --
recording and continuing is the whole point.
```

### `report_missing_values()`

```
Print every absent value at once and stop. The flag spelling starts each line
so the whole block can be read straight into a command line; the explanation
rides behind a "#" so a copied line is still valid shell.
```

### `validate_supplied_values()`

```
Shape checks for values that DID arrive. Separate from the gate above on
purpose: "absent" is a list the operator can act on all at once, but "present
and malformed" is a typo in a specific place, and pointing at it immediately
is more useful than burying it in a list of unrelated absences.
```

### `log_info()`
(No comment above it in the source.)

### `log_verbose()`
(No comment above it in the source.)

### `log_stage()`
(No comment above it in the source.)

### `log_dry_run()`
(No comment above it in the source.)

### `symbol_success()`

```
Colored symbol helpers
```

### `symbol_info()`
(No comment above it in the source.)

### `symbol_error()`
(No comment above it in the source.)

### `symbol_warning()`
(No comment above it in the source.)

### `write_generation_metadata()`

```
The record of what produced this build. A small JSON at the output root;
written early (so an interrupted build still leaves it) and at the root (so
per-stage clears, which only touch output/ subdirs, never wipe it).

Issue 10-065: it used to record the seed, pages and poems-per-page only. That
gap had a cost that was paid in full: after the word-cloud pages were lost,
nothing in the build's own artifacts said what --wordcloud-words,
--wordcloud-poems or --chrono-per-page had produced them, so 11 GB -- two
thirds of the site -- could not be reproduced from its own record.

It now writes every value the requirement gate asked for on this run, driven by
the SAME table. That is the property worth keeping: the record cannot fall
behind the flags, because adding a flag to REQUIRED_VALUES adds it here too.

Only values this run actually needed are written. A run of stages 9 and 10 has
no --server, and recording an empty one would claim something untrue about how
the build was made.
```

### `run_update_words()`
(No comment above it in the source.)

### `run_extract()`
(No comment above it in the source.)

### `run_strip_excluded()`

```
Issue 10-053: After sync/extraction, remove excluded images + note source files
from input/ so they are never cataloged, embedded, rendered, or uploaded. Runs
before image cataloging. strip-excluded validates every exclusion BEFORE it
deletes anything; a non-zero exit means a broken exclusion path (it points at no
real file), which is FATAL -- continuing would ship content that was explicitly
marked do-not-ship. The validation happens before any stripping and before the
expensive catalog/embed stages, so a bad path costs only the cheap re-run.
```

### `run_parse()`
(No comment above it in the source.)

### `run_validate()`
(No comment above it in the source.)

### `run_catalog_images()`

```
Issue 10-015a: Pass --verbose flag to show detailed image catalog statistics
```

### `emb_cache_dir()`

```
Issue 10-054: resolve a model's cache directory through the shared resolver
(scripts/cache-dir), so run.sh's freshness/pre-flight checks look in EXACTLY the
place the Lua code and generate-embeddings.sh write -- disk or RAM, per the
CACHE_IN_RAM switch. Pass --disk for the reboot-surviving diversity cache. A
blank result is a hard error rather than a silently-wrong (empty) path.
```

### `require_embeddings_for_model()`

```
Issue 10-065 (open question 1): the check stages 7 and 8 already perform, given
to stages 9 and 10, which lacked it.

Why the disk is the right authority here. For stages 7-10 the model name is
purely a CACHE DIRECTORY name -- they never contact the inference server. So
the argument inference-server-config makes for refusing to validate --model
(the server is the only authority on what is loaded, and a second authority
drifts) simply does not reach them: there is no server in the loop to reject
anything. What these stages actually need is embeddings on disk, and that is a
thing this script can verify without keeping a second list in sync.

What it prevents: a one-character slip. "--model qwen3-embedding:4B" resolves
to a real, empty directory sitting beside the real ":4b" one, indistinguishable
from a model whose embeddings have simply not been generated yet -- and stages
9 and 10 would then build a site against nothing.

Called BEFORE each stage's dry-run check, matching stages 7 and 8: a dry run
should say that the real run cannot work. The check only reads, so it is safe
there.
```

### `run_generate_embeddings()`
(No comment above it in the source.)

### `run_generate_word_embeddings()`

```
Word-cloud word embeddings + their semantic colors. Split out of
run_generate_embeddings (Issue 8-043b) and ordered AFTER the semantic-color
stage so color_embeddings.json already exists when the word-color step runs.
```

### `run_generate_picture_embeddings()`

```
Issue 9-013: the vision model embeds every picture the site ranks (post
pictures and gallery pictures) while the Stage 6 server is up. Only pictures
not already in the model's picture cache are sent; Stage 6.7 reads the cache.
```

### `run_generate_semantic_colors()`
(No comment above it in the source.)

### `run_augment_images()`

```
Issue 9-013: place every picture among the poems by its own vector (from
Stage 6's picture step): picture-only posts and gallery pictures take their
pictures' vectors, text + picture posts blend text and pictures, and the
three posts whose media has no picture keep the before/after-poem placement.
Folds them into embeddings.json so the GPU similarity stage ranks pictures
alongside poems, and writes image-manifest.json, which the HTML renderer
reads to draw picture entries. Cheap and idempotent: it runs each time
before the matrix build.
```

### `run_generate_similarity()`
(No comment above it in the source.)

### `run_generate_diversity()`
(No comment above it in the source.)

### `run_generate_html()`
(No comment above it in the source.)

### `run_build_download_zip()`

```
The "download everything" archive: the whole rendered site plus the published
source (scripts/build-download-zip). It used to be built only at deploy time,
to avoid a multi-GB archive on every local build -- but every source-browser
page links to it, so every check of a build without it failed, and a run is
only made when the site has changed anyway (owner, 2026-10-07: "we gotta build
the 3.2gb zip every time if it changed"). Assembled in RAM
(tmp/shared-memory/), then published as 90 MB pieces with a page listing
them in output/download/ -- Neocities takes no file over 100 MB (Issue 10-077).
```

### `run_validate_output()`

```
Issue 9-006: after pages are built, count the width of every line inside every
poem column and check every link, across the whole of output/, all processors
at once. Anything over-wide or pointing at nothing fails the run -- after the
pages are written, so the build is complete and the report says what to fix.
The report lands in tmp/shared-memory/validate-output-report.txt.
```

### `run_generate_wordcloud()`

```
Issue 10-059: the word-cloud stage. Builds the site's entry menu (which carries the
live poem index) and the per-word similarity pages. Runs after stage 9, so the
chronological pages its #poem links target already exist. Replaces the retired
numeric-similarity-index stage, whose output (numeric-index.html) was linked from
nowhere and was superseded by the menu's embedded poem index.
```

### `interactive_mode_tui()`

```
TUI-based interactive mode with command preview
Uses Lua menu library for stable rendering and real-time command preview
```
