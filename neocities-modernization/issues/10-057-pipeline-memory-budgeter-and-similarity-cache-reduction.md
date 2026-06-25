# 10-057: Pipeline Memory Budgeter + Similarity/Diversity Cache Reduction

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: High
- **Type**: Feature / Performance
- **Status**: Open
- **Builds on**: 10-034 (orchestrator-mode parallel HTML), 10-054 (regenerable
  caches in RAM), 8-058 (eliminate main-thread/worker duplication)

## Background / Why This Exists

The HTML stage (the similarity/diversity page generator) drives the machine to
100% RAM and into swap during a full build. Swap thrashing makes the whole stage
crawl. The cause was diagnosed precisely, and two intuitive suspects were ruled
out:

- **Not the page count.** A misleading log banner printed the 15-page storage
  *ceiling* as if 15 pages were generated per poem; the generator actually honors
  `--pages` and produced 1 page per poem (verified on disk: every `similar/NNNN`
  file ends `-01`). The banner is now fixed to report the real count.
- **Not output buffering.** Pages are streamed to disk one at a time and freed;
  there is no in-memory pile of generated HTML.
- **Not per-thread cache duplication.** Orchestrator mode (10-034) already keeps
  the big caches in ONE process and ships each effil worker a thin per-poem slice,
  so there is no 8x blow-up.

The real cause is two pre-sorted neighbor caches held **resident and co-resident**
in the orchestrator for the whole stage, plus the transient spike of parsing them:

- `tmp/cache/.../similarity_rankings_cache.json` — for every poem, a list of ALL
  other poems sorted by similarity.
- `assets/.../diversity_cache.json` — for every poem, a full max-diversity walk.

Both are N x N structures. At the current corpus that is ~62M numbers per cache;
re-measure sizes with `ls -la` on the two files and total RAM with `free -h`
(do not trust hard-coded figures here — they drift as the corpus grows). Parsing
~147M integers from JSON generates enough short-lived garbage that the working set
balloons above the resident size before the GC catches up, which is what tips the
box into swap.

The deepest waste: a page shows only `K = pages_per_poem x poems_per_page`
neighbors (e.g. 88 for a single 88-per-page page), but each cache stores all
~N neighbors per poem — on the order of 100x more than any page can display.

A second, related gap: the thread count is a fixed value (`--threads`, default 8)
with no awareness of available memory. Dropping threads cannot rescue Stage 9
(its floor is the thread-independent caches), and other threaded/GPU stages can
over-subscribe RAM or VRAM with no guard.

## Current Behavior

- `src/flat-html-generator.lua` (the orchestrator entry, `M.generate_complete_
  flat_html_collection` / `M.generate_website_html`) loads BOTH caches fully into
  the main thread and holds them for the entire stage; nothing frees a cache
  mid-stage. effil workers receive per-poem slices over a channel.
- Caches are monolithic JSON files storing the full neighbor list per poem,
  regardless of how many pages a run will actually generate.
- The cache WRITERS are GPU/C, not Lua: the similarity rankings cache is built by
  `vks_write_rankings_cache_parallel` in `libs/vulkan-compute/src/vk_similarity.c`
  (each worker sorts a poem's neighbors descending and stores ALL of them in
  `PoemRankings.sorted_indices`); the diversity sequences are built by the
  equivalent in `vk_diversity.c`. Both compile into `libs/vulkan-compute/build/
  libvkcompute.so` (Makefile target `shared`), called from Lua via
  `libs/vulkan-compute/lua/vk_similarity.lua` (FFI). The top-K cap therefore lives
  in the C write loop (cap the `sorted_indices` allocation/fill to K), with K
  threaded C <- FFI <- run.sh pagination config, plus a library rebuild.
- `color_embeddings.json` regeneration is now palette-fingerprinted (done in a
  prior change); the cache-staleness lesson there (regenerate when the *input
  shape* changes, not only when the file is missing) is the model this issue
  applies to the similarity/diversity caches.
- Thread count comes from `--threads` (run.sh) or a per-stage default; no stage
  estimates its memory footprint or clamps threads to fit RAM/VRAM.
- **Piece 2 (the cache cap) is built and verified to compile/parse**, both halves:
  - **Similarity**: `vk_similarity.c`'s `vks_write_rankings_cache_parallel` takes a
    `top_k`; each worker keeps only the first K of the already-sorted neighbour list;
    metadata stamps `top_k`. Threaded through `vk_similarity.h`, the `vk_similarity.lua`
    FFI + call, and `run.sh`. `libvkcompute.so` rebuilt clean.
  - **Diversity**: the JSON cache is written by the embedded luajit in
    `scripts/precompute-diversity-sequences-gpu` (GPU computes, CPU writes JSON). Its
    per-poem walk is truncated to the first K there; metadata stamps `top_k`; `run.sh`
    exports `PAGES`/`POEMS_PER_PAGE` so it computes the SAME K. No rebuild (Lua).
  - **K is dynamic**: `K = (--pages else config minimum_pages) x (--poems-per-page
    else config poems_per_page)` -- the ACTUAL pages a build generates, NOT the
    storage ceiling. No hardcoded page counts.
  - **Loader K-check** (`flat-html-generator.lua`): reads each cache's stamped `top_k`
    and errors with the exact regen command if a run needs more than was stored (so
    tight K can never silently under-generate). Stamp 0 / absent = uncapped.
  - NOT yet effective until the caches are REGENERATED with `--force` (the on-disk
    caches are still the old full-size ones).
- **Loader K-check, budgeter wiring, and the CPU strip are done:**
  - Both caches stamp `top_k`; `flat-html-generator.lua` reads it and errors with the
    exact regen command if a run needs more than was stored (no silent under-gen).
  - `memory-budgeter.lua` is wired into the HTML stage (clamps workers to free RAM).
  - The non-GPU route is gone: `run.sh` is GPU-mandatory; the CPU diversity script,
    `run-similarity-calculation`, `similarity-engine-parallel.lua`, and
    `similarity-engine.lua` are deleted; the menu's similarity action calls GPU
    in-process; and the Lua effil rankings-rebuild fallback (which bypassed the cap)
    falls through to the GPU path. The three dead Lua CPU-sort helpers AND the now-unused
    `effil` dependency have been removed from `vk_similarity.lua` (it is GPU-only).
  - Budgeter also wired into the GPU diversity stage as a VRAM batch-size clamp
    (`precompute-diversity-sequences-gpu`): `fit_threads` with `pool="vram"` sizes
    BATCH_SIZE to free VRAM (probed via nvidia-smi), wrapped in pcall so a probe
    failure never breaks the run. Verified the VRAM probe works (10.7 GB free -> keeps
    3584 on this GPU; a guard rail for bigger corpora / smaller cards).
  - Path unification: `vk_diversity.c` shaders + `vk_compute.lua` library path are now
    project-root-relative / DIR-based like similarity, so diversity no longer needs a
    cd-into-vulkan-compute wrapper.
- **Piece 1 is built** (not yet wired): `libs/memory-budgeter.lua` provides the
  pure `compute_fit()` decision, a live `fit_threads()` wrapper, RAM/VRAM probes, and
  the warn-don't-error swap policy, with `memory-budgeter.test.lua` (19 checks) and an
  `.info.md`. No stage calls it yet, so it does not affect any run until wired in
  (Steps 2 and 5).

## Intended Behavior

Three composable pieces. They reinforce each other but can land independently.

### Piece 1 — A reusable memory budgeter (foundational; local lib first)

A small, implementation-agnostic helper that every threaded/GPU stage can call
before spawning workers. It knows nothing about *what* the bytes are — it does
arithmetic and policy over a cost descriptor:

- **Cost descriptor** (each stage supplies one): `{ pool = "ram" | "vram",
  fixed_bytes, per_thread_bytes }`, where `fixed` is loaded once (caches, model
  weights) and `per_thread` scales with worker count (page buffer, batch).
- **Probe**: available bytes in the pool — RAM from `/proc/meminfo` (MemAvailable),
  VRAM from a GPU query. The probe is the ONLY part that differs between pools.
- **Fit policy**: `budget = available x headroom` (headroom leaves room for OS, GC,
  and parse spikes). `safe_threads = floor((budget - fixed) / per_thread)`, clamped
  to `>= 1`. Return `clamp(requested, 1, safe_threads)` and LOG the estimate and
  the decision.
- **The hard case is a WARNING, not an error** (author's call): if `fixed` alone
  exceeds `budget`, no thread count fits. Do NOT abort — warn loudly that the run
  will use swap and is a candidate for an architecture change (shard/cap/stream the
  shared data), then proceed at 1 thread. The user may legitimately choose the
  slowdown over a redesign.

Stages assemble their descriptor from a few measured primitives (e.g. "JSON to Lua
table ~= 2.5x file size", "per-thread page buffer ~= poems_per_page x ~2KB",
"embedding batch ~= batch x seq_len x dims x 2 bytes"). The budgeter is the policy;
the descriptor is the per-stage data.

Lives in this project's `libs/` first; promote to the shared `scripts/libs/` only
once proven here.

### Piece 2 — Cap the caches to the run's actual depth (Fix B; the big RAM win)

When the similarity and diversity caches are GENERATED, store only the top
`K = pages_per_poem x poems_per_page` neighbors per poem instead of all N.

- **K is derived dynamically** from the same config/CLI values that drive
  pagination for the run — never a hard-coded constant. `pages_per_poem` comes
  from `--pages` (or config default), `poems_per_page` from `--poems-per-page`
  (or config).
- **Lossless up to the page ceiling**: the similarity list is sorted by closeness,
  so the top-K ARE the K shown, in order; the diversity walk is built front-to-back
  so its first K are unchanged by dropping the tail. Capping at the storage-ceiling
  K loses nothing even at max pages.
- **Fingerprint the cache** with `{K, poem_count, model}` (mirroring the color
  palette fingerprint). The loader compares the run's required K against the stamp
  and regenerates when the run now needs MORE than was stored, rather than silently
  serving a too-shallow cache.

Effect: cache resident size and parse spike both shrink with K (on the order of
~6x at the 15-page ceiling, ~100x at one page).

### Piece 3 — Split into two passes (Fix A; contained, no regen)

Generate similarity pages with only the similarity cache loaded, free it, then
generate diversity pages with only the diversity cache. Never both resident. Halves
the resident floor and means only one ~400MB file is parsed at a time. No cache
regeneration; contained to the orchestrator setup. Composes with Piece 2 (one
*small* cache resident at a time).

### Where the budgeter is applied (candidate stages)

| Stage | Parallelism | Pool | Cost driver (descriptor) |
|---|---|---|---|
| HTML (Stage 9, this issue) | effil workers | RAM | fixed = neighbor cache(s); per_thread = one page buffer |
| Similarity matrix | GPU + CPU sort threads | VRAM + RAM | fixed = N x N matrix on GPU; per_thread = sort buffers |
| Diversity | GPU + threads (batch 50) | VRAM + RAM | fixed = distance work; per_thread = batch buffers |
| Embeddings | GPU batch (server) | VRAM | fixed = model weights; batch = batch x seq x dims |
| Word similarity pages | effil + batch embeds | RAM + VRAM | fixed = word embeddings; per_thread = per-word similarity |
| Image catalog / render | effil | RAM | per_thread = decoded image buffers |

RAM stages probe `/proc/meminfo`; VRAM stages probe the GPU; the fit policy is
identical. Wiring each stage is a five-line descriptor plus one budgeter call.

## Design Decisions To Settle Before Building

- **Headroom factor** for the budget (e.g. 0.7). Should account for the JSON parse
  spike specifically, since that is the transient that actually causes swap.
- **Modeling the parse spike**: treat it as `fixed_peak = fixed_resident x
  parse_overhead`, so Piece 2 (smaller `fixed`) shrinks the spike the budgeter
  must reserve for.
- **K headroom**: store exactly `K`, or `K x small_factor` so minor page-count
  changes do not force a regen. Recommendation: exactly K, since a fingerprint
  regen is cheap and correctness beats a fudge factor.
- **VRAM probe portability**: which GPU query to standardize on (the similarity
  engine already targets Vulkan; the embedding server is separate).

## Suggested Implementation Steps

1. **Budgeter library** in `libs/` (Piece 1): pure-arithmetic fit function, a RAM
   probe (`/proc/meminfo` MemAvailable) and a VRAM probe, the cost-descriptor
   contract, and structured logging of estimate + decision. Unit-test the
   arithmetic and the warn-don't-error path with synthetic descriptors (no real
   memory needed).
2. **Wire the budgeter into Stage 9** (`flat-html-generator.lua`): build the HTML
   stage's descriptor from the cache file size(s) and the per-thread page-buffer
   estimate; clamp `--threads` before launching effil workers; log the estimate.
3. **Fix B — cap the caches** at generation (similarity-engine + diversity
   generators): compute K from the run's pagination config, store top-K per poem,
   stamp the cache fingerprint, and make the loader regenerate on K/model mismatch.
4. **Fix A — split passes** in the orchestrator: similarity pass (load + free),
   then diversity pass; verify only one cache is resident at a time.
5. **Extend the budgeter to the other stages** in the table, one descriptor each.
6. **Validators** (not hard-coded numbers): a small script that prints the measured
   cache sizes, estimated resident footprint, the budgeter's thread decision for the
   current machine, and confirms peak stays under the budget on a real run.

## Deferred follow-up (separate from the cache cap)

**DONE.** `max_pages_per_poem` is now computed by `compute_storage_max_pages` in
`flat-html-generator.lua` (measured `du`/`find` over the last build's output),
wired into `generate_complete_flat_html_collection`, and removed from `config.lua`.
Measured result on the current corpus: **9 pages/poem** (the old frozen `15` would
have shipped ~69 GB into the 45 GB quota). Original description below.

`max_pages_per_poem` (config.lua, formerly the literal `15`) was an *estimate* of
"how many pages fit the 45 GB Neocities quota" frozen in config. It is now COMPUTED
at runtime and removed from config:
`max_pages = (storage.limit_gb - output/media size - other fixed output) /
(num_poems x 2 x avg_page_size)`, where `avg_page_size` is MEASURED from the last
build's `output/similar/*.html` (pages reference images via `<img src>`, so a page
on disk is text; the picture bytes are a single `output/media/` cost, not per-page).
A self-correcting validator, not a hardcoded number. The cache cap above no longer
uses `15` (it sizes K from the ACTUAL pages generated), so this is independent;
tackle it after the cache work lands.

## Related Documents / Tools

- `src/flat-html-generator.lua` — orchestrator + the cache loaders + the effil
  worker; where Stage 9's budgeter call and the split passes go.
- `tmp/cache/.../similarity_rankings_cache.json`,
  `assets/.../diversity_cache.json` — the two caches to cap (Piece 2).
- `src/similarity-engine-parallel.lua`, `src/mass-diversity-generator.lua` — the
  generators that build those caches (where K-capping is applied).
- `run.sh` — `--threads`, the per-stage runners, and the color-palette fingerprint
  pattern this issue mirrors for cache staleness.
- `docs/effil-usage-patterns.md` — threading model and performance characteristics.
- Issues 10-034 (orchestrator mode), 10-054 (RAM caches), 8-058 (worker dedup).
