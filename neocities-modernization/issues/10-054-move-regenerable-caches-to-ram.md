# 10-054: Move Regenerable Caches to RAM (tmp/) to Spare the Disk

## Status
- **Phase**: 10 (Developer Tooling)
- **Priority**: Medium
- **Type**: Feature / Refactor
- **Status**: Open

## Problem

The pipeline rewrites large intermediate caches to disk on every regeneration --
most punishingly the per-poem `similarities/` directory (3.8 GB across ~9,054
separate files) and the big JSON caches (similarity ~413 MB, embeddings ~118 MB,
word embeddings ~98 MB). On an SSD this burns write endurance for data that is
fully regenerable. `tmp/` is a tmpfs symlink (16 GB of RAM), so writing caches
there does zero disk I/O; they persist for the whole boot (reused across runs)
and only regenerate after a reboot -- an acceptable trade (recompute vs wear).

## Blocker Discovered: cache paths are not centralized

The same cache file is located three inconsistent ways across ~30 sites:
- `utils.embeddings_dir() .. "/X.json"`   (centralized)
- `utils.asset_path("embeddings/" .. model .. "/X.json")`
- `DIR .. "/assets/embeddings/" .. model .. "/X.json"` -- and some scripts
  HARDCODE a stale `embeddinggemma_latest` model name (dead code paths)

They all resolve to the same disk path today, so flipping one of them to `tmp/`
would desync readers from writers of the SAME cache -- a silent "cache missing"
that triggers a surprise regeneration. So the location cannot be moved until the
paths are centralized.

## Intended Behavior

Two cache roots, one source of truth each:
- `utils.embeddings_dir(model)` -> RAM (`tmp/cache/embeddings/<model>`): the
  MOVABLE caches (embeddings.json, embeddings_fp16.bin, the `similarities/` dir,
  similarity_rankings_cache.json, word_embeddings.json, poem_colors.json,
  word_colors.json, color_embeddings.json, image-manifest.json, centroids.json).
- `utils.embeddings_dir_disk(model)` -> disk (`assets/embeddings/<model>`): only
  `diversity_cache.json`, which costs ~40-50 min to recompute and so stays on
  disk to survive reboots.
- Asset-root movable caches (`image-catalog.json`, `validation-report.json`) ->
  a RAM `cache_root()`; `poems.json` and the model `.gguf` stay on disk.

Every scattered reference is rewritten to go through the matching function, so
there is exactly one place that decides each cache's location.

## Design Notes

- **Centralize, then flip.** Do the path-centralization as a behavior-preserving
  step first (everything still resolves to disk, verifiable that nothing breaks),
  then change the one function body to point at `tmp/`.
- **Diversity is the exception, by cost not size.** It is a single 343 MB write
  (low wear) but the most expensive recompute (~45 min), so it is the one cache
  that stays on disk. Everything else recomputes in seconds-to-minutes.
- **Regenerate-if-absent.** After a reboot `tmp/` is empty; the run scripts must
  recreate the tmp cache dirs early (the existing `ensure-tmp-symlink` + the
  writers' `ensure_directory` calls), and the stages' existing "cache present?"
  checks guide a regeneration if a movable cache is missing.
- **No new shell file-ops for routing.** Routing is done in code (paths via
  `io.open`, dirs via the sanctioned `ensure_directory`); no symlink trickery.

## Suggested Implementation Steps

1. Add `tmp_cache_root()`, repoint `embeddings_dir()` at it, add
   `embeddings_dir_disk()` (assets), in `libs/utils.lua`.
2. Rewrite every scattered movable-cache path (asset_path / hardcoded) to call
   `embeddings_dir()`; rewrite every `diversity_cache.json` path to call
   `embeddings_dir_disk()`. Audit with a grep that no `assets/embeddings/` or
   `asset_path("embeddings` reference survives except diversity.
3. Route `image-catalog.json` + `validation-report.json` through the RAM root.
4. Ensure the run script sets up the tmp cache dirs before any stage uses them.
5. Delete the orphaned on-disk movable caches once (they regenerate to RAM); keep
   `diversity_cache.json` and the model.
6. Validate with a full pipeline run (the only true proof): confirm caches land
   in `tmp/`, diversity stays on disk and is reused, and a simulated reboot
   (clear tmp) regenerates the movable caches without touching diversity.

## Progress (2026-06-23)

- **Done & committed (switch still OFF, behaviour identical to disk):**
  - The foundation: `CACHE_IN_RAM` switch + `embeddings_dir()` (movable) /
    `embeddings_dir_disk()` (diversity) in `libs/utils.lua`.
  - Every GENERATION-path read/write centralized: `main.lua`,
    `flat-html-generator.lua` (similarity reader + diversity reader),
    `augment-embeddings-with-images.lua`, `generate-similarity-rankings-cache`
    (similarities + ranking writer), `precompute-diversity-sequences-gpu`
    (reads embeddings movable, writes diversity to disk),
    `triangular-similarity-access.lua` (4 per-poem similarity reads).
  - The experiment tools (`hubness-experiment.lua`, the augment test) read via
    `embeddings_dir()` so they follow the caches.
  - A grep audit confirms NO movable-cache path in the live pipeline still
    hardcodes `assets/embeddings/` or `asset_path("embeddings/`.
- **The flip — TRIED, then REVERTED (2026-06-23).** Set `CACHE_IN_RAM = true`
  and ran a full regeneration. It FAILED, proving the centralization claim above
  was wrong: the **readers** were routed to RAM but several **writers still write
  to disk**, so readers found nothing.
  - `augment-embeddings-with-images.lua` crashed: "missing embeddings.json" — it
    reads `embeddings_dir()` (RAM), but the embedding generator wrote
    `embeddings.json` to disk (`assets/embeddings/<model>/`, fresh-dated, so it
    was written this run, just to the wrong root).
  - The word-color step skipped: "no color embeddings found" — same desync on
    `color_embeddings.json` (on disk, reader looks in RAM).
  - **Why the audit missed it:** the audit grepped for the literal
    `asset_path("embeddings/` / `/assets/embeddings/`. Writers that build the
    directory into a VARIABLE first (e.g. `similarity-engine.lua`'s
    `target_model_dir .. "/embeddings.json"`) slipped through.
  - **Before re-flipping:** find EVERY writer of a movable cache (not just the
    readers) and route it through `embeddings_dir()`. A reliable audit must follow
    the variables (or grep the cache *filenames* like `embeddings.json` and check
    each site), not just the literal `asset_path` calls. Then a clean full run.
- **Orphan cleanup — N/A while reverted.** With `CACHE_IN_RAM = false` the
  on-disk caches are the live ones again; do not delete them. (When the flip
  eventually sticks: delete ONLY the movable on-disk caches, never
  `diversity_cache.json`.)
- **Deferred (safe to leave; not on the live pipeline path):**
  - The validators (`pipeline-validator.lua`, `scripts/validate-pipeline-data`)
    are diagnostic-only (not run by `run.sh`/`main.lua`); after a flip they would
    report movable caches as "missing" until updated to use `embeddings_dir()`.
  - The asset-root caches (`image-catalog.json` 1MB, `validation-report.json`
    6MB) stay on DISK for now -- tiny wear, and moving them needs their own
    scattered reader/writer reconciliation. Revisit if wanted.
  - Setting up `tmp/cache/...` early + deleting the orphaned on-disk movable
    caches happens as part of the flip.

## Related
- `libs/utils.lua` (`embeddings_dir`, `embeddings_dir_disk`, `similarities_dir`).
- `scripts/ensure-tmp-symlink`, the `tmp/` tmpfs symlink.
- Dead scripts hardcoding `embeddinggemma_latest` (candidates for separate removal).
