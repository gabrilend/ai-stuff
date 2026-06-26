# 10-060: Retire Untethered (Dead) Code

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Low
- **Type**: Cleanup
- **Status**: In progress

## Current Behavior

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

## Cautionary context (why this issue is careful, not aggressive)

This cleanup runs right after a near-identical mistake in the opposite direction:
the GPU-only migration (745ce6a9) deleted `src/similarity-engine.lua` as "CPU
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
