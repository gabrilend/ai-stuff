# 10-060: Retire Untethered (Dead) Code

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Low
- **Type**: Cleanup
- **Status**: In progress

## Current Behavior
**2026-10-23, the refactoring pass (Issue 10-048 step 2; owner's yes to
retiring after a check by hand).** Renamed `-done` for one commit, then
removed:
- modules: `libs/triangular-similarity-access.lua`,
  `src/triangular-similarity-matrix.lua`, `src/regenerate-clean-site.lua`,
  `src/html-generator/golden-poem-indicators.lua`,
  `src/html-generator/embedding-list-generator.lua` (and its test), and the
  validation suite (`run-validation`, `run-validation-with-reports`,
  `validation-engine`, `report-generator`, `similarity-calculator`) with
  `config.similarity`, which only the calculator read;
- scripts: `compile` (belongs to the words repository and needs folder
  settings nothing here gives it), `generate-diversity-cache.sh` (checked a
  model folder that no longer exists), `run-fediverse` and `run-messages`
  (the update stage does that extraction), `migrate-to-triangular-files.lua`
  (a one-time migration, done), `generate-similarity-rankings-cache` (stage 7
  writes that cache on the GPU), `validate-diversity-cache` (a binary cache
  format the build no longer uses).
- Kept on purpose: `src/hubness-experiment.lua` (the measurement tool for the
  open picture-embedding questions, Issue 9-013), `src/diversity-chaining.lua`
  (named as the reference algorithm by Issues 13-004 and 14-001),
  `src/html-generator/url-manager.lua` (demo 3 uses it until 10-056 rewrites
  the demo), and the hand-run tools (`scrape-boost-content.lua`,
  `quarantine-stale-output`, `check-inline-lua-quotes`, `test-effil-simple`,
  the measuring scripts).
- `scripts/audit-orphan-files` now reports those 3 modules and nothing else.

**Earlier:**

Modules left behind by superseded implementations still sit in `src/`, only kept
"alive" by their own tests. A test that exercises dead code stays green forever and
makes the module look load-bearing -- the reliable tell is "grep for callers and
find only the test."

Verified dead (only referencer is its own test):
- `src/mass-diversity-generator.lua` -- the old CPU-era generator for the per-poem
  "different" pages (it `require`s `diversity-chaining`). The diversity pages are
  now produced by `flat-html-generator.lua` on the GPU path. Nothing in the live
  pipeline calls it; only `src/test-mass-diversity-generator.lua` does. (Its
  `../../index.html` "Poetry Collection" nav links also point at a root index that
  never existed -- moot, since it never runs.)

Verified STILL LIVE (do NOT delete -- checked because they looked adjacent):
- `src/diversity-chaining.lua` -- called by `src/main.lua:895`
  (`generate_diversity_chain`). Its test `src/test-diversity-chaining.lua` stays.

### Added 2026-08-08 (found during Issue 10-065's progress-bar audit)

Every item below is now marked in the source with the tag
`[DEPRECATED / DEAD CODE / PRUNE CANDIDATE]`, chosen so that grepping for any of
"dead", "prune", or "deprecated" finds all of them.

**Dead FILE, no referencers anywhere:**
- `src/triangular-similarity-matrix.lua` -- verified across Lua `require`s, the
  inline `luajit -e` blocks in the .sh scripts, and run.sh's dispatch. The only
  textual hits for the name are a similarly-named FUNCTION inside
  `similarity-engine.lua`, which is a different thing.

**Dead FUNCTIONS inside a LIVE file -- the case this issue's cautionary note is
about, in reverse.** `src/similarity-engine.lua` must not be deleted: it is the
embedding generator behind stage 6. But three of its functions are unreachable
from any live entry point, being the CPU similarity route that Issue 10-057
removed (run.sh now hard-errors on a missing `libvkcompute.so` rather than
falling back to CPU):
- `calculate_similarity_matrix` (~line 930)
- `calculate_full_similarity_matrix` (~line 1079)
- `calculate_triangular_similarity_matrix` (~line 1215)

They are reachable only from this module's own standalone `M.main()` menu and
from `generate_all_model_similarity_matrices`, neither of which the pipeline
invokes. What the live pipeline DOES call into that module, verified by grepping
`generate-embeddings.sh` (the only shell script that requires it):
`generate_all_embeddings`, `flush_embeddings_cache`, `list_available_models`,
`show_all_model_status`.

The lesson to carry forward, which is the mirror of the one above: liveness has
FILE granularity and FUNCTION granularity, and they differ. Last time a live file
was deleted for containing dead-looking code. Pruning these means removing
functions, not the file.

### Dead configuration (retired 2026-10-04)

Liveness has a third granularity beside file and function: the single
setting. A setting nothing reads still looks like a control, so someone edits
it and nothing changes. `scripts/audit-config-keys` now finds these: it loads
`config.lua`, then searches every tracked program for a read of each section
and each setting, following the indirect routes this code uses (a local alias,
a quoted name, a loop over a whole section, a table indexed by a list of names
elsewhere in `config.lua`) and ignoring comment lines. Its first run found six;
each was confirmed by hand and removed, with a short note left in its place
saying what to use instead:

- `randomization.seed` -- `run.sh` stopped reading it under 10-065; the seed is
  `run.sh --seed N`.
- `extraction.enable_fediverse`, `enable_messages`, `enable_notes`,
  `enable_bluesky` -- never read; a source is switched off with `enabled =
  false` on its entry in `sources`.
- `word_cloud.enabled` -- never read; the word cloud is built by selecting
  stage 10.

A seventh, `external_files`, was an empty list read only by a fallback in
`libs/external-sync.lua`: when the sources reader returned no sync entries, the
module read the empty list instead and got the same answer. Worse, the sources
reader was loaded inside a pcall, so if it failed to load the module silently
synced nothing. The list, the fallback, and the module's private config loader
(used only by the fallback) are gone; the sources reader is required outright,
so a broken one is an error. `scripts/notes-tooling-exclusion.test.sh` (which
drives the real sync) passes, and `scripts/sync-external-files --list` still
shows all nine configured syncs.

`docs/config-reference.md` had drifted the same way (written once in April; a
removed section, a renamed one, seven missing). Its section reference is now
generated from `config.lua`'s own comments by `scripts/generate-config-reference`
(`--check` reports drift without writing). The doc's hand-written parts were
corrected and gained a table of removed settings.

### The broader orphan audit (step 3), run 2026-10-04

`scripts/audit-orphan-files` does step 3 as a rerunnable tool. It starts from
every script (`scripts/*`, the root `.sh` files) and every program that is not
a module, follows every place a file is named outside whole-line comments --
which includes the Lua inside shell scripts, the trap this issue warns about --
and reports the modules in `src/` and top-level `libs/` that nothing reaches.
No module is loaded by a name built at run time, so nothing is invisible to it.

It reported 13 modules, each checked by hand. Each needs
the owner's decision:

| Group | Modules | What they are |
|---|---|---|
| already marked dead | `src/triangular-similarity-matrix.lua` | the file this issue verified on 2026-08-08 |
| hand-run tools living in `src/` | `src/hubness-experiment.lua` (Issue 9-013 measurement tool), `src/regenerate-clean-site.lua` (a one-off fix for PDF-corrupted poems) | programs a person would run directly; nothing calls them |
| removed 2026-10-04 | `src/centroid-html-generator.lua` | the mood pages planned in 8-008 Phase C, never wired in; owner: "that function is fulfilled by the word-cloud" |
| removed 2026-10-04 | `libs/pipeline-validator.lua`, and the scripts `scripts/generate-html-parallel` and `scripts/generate-html-pthreads` with the C library `libs/html-threaded/` | the two stand-alone HTML generators (owner's decision) and the pre-start check only the first of them loaded; run.sh's pre-flight gate (10-069) and each stage's own input checks do that job now |
| the validation suite | `src/run-validation.lua`, `src/run-validation-with-reports.lua`, `src/validation-engine.lua`, `src/report-generator.lua`, `src/similarity-calculator.lua` | two command-line runners and the three modules only they use (10-048h); `config.similarity` is read only by the calculator, so it lives or dies with this group |
| what is left of `src/html-generator/` | `golden-poem-indicators.lua` (nothing), `embedding-list-generator.lua` (its test only), `url-manager.lua` (demo 3 only) | 4 of the 16 files 10-048 describes remain; the rest went with the golden-prioritization template system. Demo 3 must be rewritten first (10-056) |
| a reader for triangular similarity files | `libs/triangular-similarity-access.lua` | may be wanted by 8-034 (triangular individual files only), which is open |

**Reachable but off the pipeline (classify before pruning, not dead):**
- `src/model-comparison.lua` -- referenced by `similarity-engine.lua` and
  `scripts/start-llamacpp-server.sh`. A diagnostic tool, not pipeline code.
  Deliberately NOT marked, because "not in the pipeline" is not the same as
  "unreachable" and this issue is about the latter.

## Cautionary context (why this issue is careful, not aggressive)

This cleanup runs right after a near-identical mistake in the opposite direction:
the GPU-only migration (7c48268e) deleted `src/similarity-engine.lua` as "CPU
similarity code", but that module was ALSO the embedding generator, so the next full
regeneration failed at stage 6. It was restored (separate commit). Lesson: "dead
code" must be proven unreferenced by EVERY entry point -- `.lua` requires AND the
inline `luajit -e` blocks inside `.sh` scripts AND run.sh dispatch -- before deletion.

## Intended Behavior

The codebase contains only code reachable from a live entry point (or a test of
live code). Each retired file is removed via `git rm` (recoverable from history if a
hidden caller surfaces).

## Suggested Implementation Steps

1. **Delete the mass-diversity cluster** (done in this issue): `git rm
   src/mass-diversity-generator.lua src/test-mass-diversity-generator.lua`.
2. **Deferred -- trim `src/similarity-engine.lua` to embeddings-only.** It was
   restored verbatim (1909 lines) to unblock stage 6 and still carries the dead
   CPU-similarity matrix functions (`calculate_*_similarity_matrix`,
   `generate_all_model_similarity_matrices`, `compare_model_similarities`, the
   interactive `M.main`, etc., ~lines 910-1779). Keep only the embedding path
   (`generate_all_embeddings`, `list_available_models`, `get_model_status`,
   `show_all_model_status`, `flush_embeddings_cache`) that `generate-embeddings.sh`
   drives. MUST be done when no regeneration is in flight, and verified by re-running
   stage 6, since a mis-trim breaks embeddings again.
3. **Deferred -- broader orphan audit.** Sweep every `src/*.lua` for files whose only
   referencer is a test or nothing at all, checking `.sh` inline-luajit callers too.
   Present findings before deleting; this is where the similarity-engine trap lives.

## Related Documents / Tools
- `src/mass-diversity-generator.lua`, `src/test-mass-diversity-generator.lua` -- deleted.
- `src/diversity-chaining.lua` (+ its test) -- live, kept.
- `src/similarity-engine.lua` -- restored embedding generator; CPU half to be trimmed.
- `src/flat-html-generator.lua` -- the GPU path that superseded mass-diversity-generator.
