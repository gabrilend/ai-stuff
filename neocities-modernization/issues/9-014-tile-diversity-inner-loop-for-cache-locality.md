# Issue 9-014: Tile Diversity Shader Inner Loop For L2 Cache Locality

## Current Behavior

The GPU diversity-sequence shader processes every iteration by having each
workgroup scan all candidate poem embeddings in a single strided pass over
the full embedding table:

- Embedding table is ~25 MB (8,359 poems × 768 dimensions × 4 bytes)
- L2 cache on a GTX 1080 Ti is 5.5 MB
- The table is ~4.5× bigger than the cache, so consecutive reads thrash

Each iteration, all 3,584 workgroups want to read the same embedding
table. In principle the L2 should help — many workgroups read the same
poem at the same time — but the GPU does not run all workgroups in
lockstep. The scheduler issues them as waves limited by SM residency
(roughly 80-100 concurrent on this hardware), so at any given moment
some workgroups are early in their scan and others are late. The L2
ends up juggling multiple "regions" of the table at once, evicting and
re-fetching, and we see roughly 22% of theoretical memory bandwidth.

Empirically, the first ~25% of a batch run is dominated by memory
bandwidth; iteration rate then climbs sharply as the mask sparsifies
and the working set naturally shrinks below cache size. The slow part
of the run is the part where the table doesn't fit in cache.

Relevant files:

- The GLSL shader for the inner scan and reduction
- The C wrapper that creates the pipeline and pushes constants
- The Lua driver that loops over chunks and sizes them adaptively
- The wrapper script that loads embeddings and kicks off the run

## Intended Behavior

Replace the single inner-scan loop with a tiled scan: each iteration
walks the candidate space in tiles small enough to fit in L2, with
all workgroups scanning the same tile before any workgroup advances
to the next. Within each tile, every workgroup hits the L2 cache for
its embedding reads; between tiles, exactly one tile's worth of data
is brought in from VRAM.

Tile sizing derivation: target tile working-set ≤ L2 size with margin.
With 768-dim embeddings at 4 bytes each, 1,500 candidates × 768 × 4 ≈
4.6 MB, comfortably under the 5.5 MB cache. The exact tile size is a
single line of Lua and should be computed from `embedding_dim` rather
than hardcoded, so a future move to a different embedding model
(384-dim, 1024-dim) re-derives the right tile size automatically.

Output must remain bit-identical to the current implementation. The
correctness argument is associativity of max: scanning [a..z] in one
pass and taking the max is equal to taking the max of (max[a..m],
max[n..z]). The tiled scan just splits the inner loop differently;
the per-iteration winner is the same.

Two implementation shapes exist, with different trade-offs:

- **In-shader tile loop**: one dispatch per iteration, with an outer
  tile loop wrapping the candidate scan. Workgroups march at roughly
  the same pace because they do roughly the same work per tile, but
  the GPU does not enforce lockstep. Captures *part* of the cache
  benefit because workgroups drift apart in tile progress as the run
  goes on. Simplest to implement; preserves the existing dispatch
  structure.
- **Dispatch per tile**: one shader invocation per tile, with a fence
  wait between tiles. Hard grid sync — guarantees all workgroups
  finish tile K before any start tile K+1, capturing the full
  theoretical cache benefit. Each tile-dispatch is *shorter* than
  the current per-iteration dispatch (one tile of L2-cached work
  instead of the cache-thrashing full scan), so the watchdog is
  easier to satisfy than today, not harder. Multiplies dispatch
  count by ~5× per iteration, but each dispatch is much cheaper, so
  this is a positive trade rather than a negative one as long as
  CPU-side dispatch overhead is hidden by pipelining (see below).

Either shape is worth implementing. The in-shader version is the
simpler baseline if just getting tiling working at all is the
priority. The dispatch-per-tile version is the higher-payoff target
if pursuing maximum speedup; it pairs naturally with multiple frames
in flight (two command buffers cycling so the CPU records the next
tile dispatch while the GPU runs the current one), which compounds
because tiling raises the dispatch count and pipelining hides the
per-dispatch CPU overhead.

### FP16 storage (compounding optimization)

A separate but complementary lever on the same bandwidth bottleneck:
store the embedding table as half-precision (FP16) floats instead
of single-precision (FP32). That immediately halves the in-VRAM
size of the table, halves the bandwidth required to stream it
through the L2 cache, and effectively doubles the cache's usable
capacity for embedding data.

Why this is safe for this algorithm: the diversity ranker only
needs to know which candidate is *most different* from the
centroid, not the exact numeric distance. The relative ordering of
cosine distances is preserved under FP16 conversion to ~10 bits of
mantissa, which is far more precision than is needed to rank
~8,000 candidates that are typically separated by distances well
over 1e-3. The loss is invisible in the output sequence.

Why this stacks with tiling: tiling fixes "the working set does
not fit in cache because of how we access it"; FP16 fixes "the
working set is unnecessarily large." Doing both means each tile
holds twice as many candidates in the same L2 bytes (so we can
use larger tiles and fewer dispatches), AND each tile load from
VRAM moves half as many bytes. The two wins multiply rather than
overlap because they target different terms of the same equation.

**Hardware caveat for Pascal-era GPUs (GTX 1080 Ti):**
- FP16 *storage* is supported and delivers the full memory-bandwidth
  win — every read of the embedding buffer transfers half as many
  bytes as today's FP32 layout.
- FP16 *compute* is NOT supported at full throughput on Pascal.
  Packed-FP16 math runs at 1/64 the speed of FP32. The right
  pattern here is to read FP16 from storage, immediately cast to
  FP32 in registers, and do all arithmetic at FP32. The bandwidth
  win is preserved; the compute path is unchanged.
- On Volta+ (RTX 20-series and later), FP16 math is at least as
  fast as FP32, so the same code automatically picks up additional
  compute speedup on newer hardware. On data-center parts
  (A100/H100) FP16 math is several times faster than FP32.
- The implementation must explicitly follow the "load FP16,
  compute FP32" pattern. A shader that uses native FP16
  arithmetic everywhere would actually run *slower* on 1080 Ti
  than today's all-FP32 code.

Output remains correctness-equivalent: the FP32 cosine distances
computed from FP16-loaded values may differ in the last few bits
of mantissa from the all-FP32 path, but the resulting *ordering*
of candidates is preserved, so the diversity_cache.json output
is the same sequence of poem indices.

## Suggested Implementation Steps

These steps describe the in-shader tile-loop variant. The dispatch-per-
tile variant differs in that the tile loop lives in the Lua driver
instead of the shader, and each tile dispatches the existing shader
with adjusted candidate-range push constants; the shader itself
needs no tile loop. Pipelining (two-command-buffer rotation) is a
separate concern that stacks on top of either variant.

1. Add a `tile_size` push constant to the shader (uint, fifth position).
   Wrap the existing strided candidate-scan loop in an outer loop over
   tiles `[0, num_tiles)`. Each tile reads candidates in the index
   range `[tile * tile_size, min((tile+1) * tile_size, num_poems))`.
   The running max across tiles is just the existing per-thread
   `local_max_distance` / `local_max_index`, which is already kept
   across iterations of the inner loop and works without modification.
2. Update the pipeline allocation in the C wrapper from 4 uints to 5
   uints (the existing comment about why this size has to match the
   push struct explains the failure mode if forgotten).
3. Update the C dispatch function to take and forward `tile_size`.
   Update the Lua FFI cdef to match.
4. In the Lua driver, compute `tile_size = math.floor(L2_BYTES * 0.85
   / (embedding_dim * 4))` (the 0.85 leaves headroom for other things
   the L2 holds: centroids, masks, shader code). Document the
   derivation in a comment.
5. Correctness test: run the modified pipeline on a small subset (32
   sequences, first 100 iterations is enough), compare each sequence's
   output to the existing `diversity_cache.json`. They must be
   identical. If they are not, the running-max comparison across tiles
   has a bug — most likely the initial values of `local_max_distance`
   and `local_max_index` are being reset between tiles when they
   shouldn't be.
6. Benchmark: time the first 500 iterations before and after on the
   same input. Expect 1.5-2.5× speedup on those iterations. The later
   iterations (where the mask is sparse) won't change much because
   they already fit naturally in cache.

### FP16 storage path (compounds with tiling; can be done independently)

Steps 7-12 add the FP16 storage optimization. They can be applied
on top of tiling, or before tiling, or independently — the two
pieces only interact at step 11, where the tile-size calculation
should account for the halved per-candidate footprint.

7. Add a small Lua helper that converts the existing FP32
   embeddings.json into a binary FP16 file at
   `assets/embeddings/<model>/embeddings_fp16.bin`. Format:
   `num_poems × embedding_dim × 2 bytes`, little-endian
   half-floats in row-major order. The conversion is a one-time
   cost per model; subsequent runs read the binary directly. Use
   LuaJIT FFI plus the standard "shift exponent, round mantissa"
   FP32→FP16 routine, or call out to a small C helper if the
   pure-Lua version is too slow on 8 M floats.
8. In the shader, add the `GL_EXT_shader_16bit_storage` and
   `GL_EXT_shader_explicit_arithmetic_types_float16` extensions
   at the top. Change the Embeddings binding from
   `readonly buffer { float embeddings[]; }` to
   `readonly buffer { float16_t embeddings[]; }`. Inside the
   inner cosine-distance loop, load FP16 and immediately cast
   to FP32 (`float e_val = float(embeddings[base + d]);`). Keep
   the centroid, the dot-product accumulators, and the norm
   accumulators all as FP32. This preserves the bandwidth win
   without paying the Pascal FP16-compute penalty.
9. On the C side, change the embeddings upload to use the FP16
   buffer (size `num_poems × embedding_dim × sizeof(uint16_t)`).
   No change to the dispatch logic — push constants and pipeline
   layout are unaffected.
10. In `vk_compute.lua`, update the upload path to read the FP16
    binary file (one big `ffi.copy` into a `uint16_t[?]` buffer)
    instead of the current "flatten Lua table to FP32 ffi array"
    loop. The Lua side is much faster on FP16 binary because it
    is a straight `read` + `ffi.copy`, no per-value conversion.
11. If tiling is also active: update step-4's tile-size formula
    from `L2_BYTES * 0.85 / (embedding_dim * 4)` to
    `L2_BYTES * 0.85 / (embedding_dim * 2)`. With 2 bytes per
    value instead of 4, a tile of ~3,000 candidates fits the same
    L2 budget that previously held 1,500. Document the change
    next to the original formula so future readers can recover
    both versions from one place.
12. Correctness test: re-run the same 32-sequence / 100-iteration
    subset from step 5 and compare to the FP32-tiled output.
    Sequences must be IDENTICAL. If any sequence diverges, the
    "load FP16, compute FP32" rule was violated somewhere in
    the shader — most commonly by leaving an intermediate
    accumulator as float16_t.

## Related Documents

- This optimization came up as part of the stage-8 GPU performance
  investigation, which produced the wall-clock timing fix
  (`socket.gettime` instead of `os.clock`), the shader-internal
  iteration loop, the chunked dispatch architecture, and the
  push-constant size bug. The chunked architecture is what makes
  this tiling change small: the per-chunk dispatch already does
  setup/teardown, so adding an inner tile loop adds work to the
  shader but not to the C or Lua layers.
- The 1080 Ti L2 cache figure (5.5 MB) is a published spec, not a
  measured number; if this code is ever ported to a different GPU,
  the L2 size should come from a runtime query rather than a constant.

## Risks

- Cache benefit depends on workgroup-pacing assumptions that hold in
  practice but are not enforced by the API. If a future driver
  release changes the scheduler aggressiveness, the benefit could
  shrink or disappear. Worth re-benchmarking after major driver
  updates.
- Tile-boundary off-by-one bugs are easy to introduce, especially on
  the last partial tile when `num_poems` is not a multiple of
  `tile_size`. The correctness test against the existing cache will
  catch these.
- The probe-based chunk sizing in the Lua driver may need re-tuning
  because per-iter cost will change. If the probe over-estimates iter
  cost after the change, `chunk_size` will land at 1 unnecessarily.
  The right test is whether the post-warmup chunk timings look
  sensible (sub-second is the watchdog-safe target).
- FP16 storage on Pascal hardware preserves only the bandwidth win,
  not a compute win. The implementation must follow the explicit
  "load FP16, immediately cast to FP32, compute at FP32" pattern.
  A shader that uses `float16_t` for accumulators or intermediate
  variables will run *slower* on a 1080 Ti than the current
  all-FP32 code. The correctness test catches output divergence,
  but not the perf regression — benchmarking is the only way to
  catch this class of bug.
- The FP16 on-disk format (`embeddings_fp16.bin`) is a new file
  that downstream consumers do not understand. As long as
  embeddings.json continues to exist alongside it, the rest of the
  pipeline (semantic-color-calculator, similarity-engine, the HTML
  consumers) keeps working unchanged. If the FP32 JSON is ever
  removed, every downstream tool that reads it must first be
  migrated to load the FP16 binary. Don't delete the JSON without
  doing the migration.

## Expected Outcome

Magnitude of the win depends on which implementation shape is chosen.
The reasoning is grounded in an empirical observation from the
current run: between the cold-cache start (~1.3 iter/sec) and the
warm-cache middle (~7 iter/sec), iteration rate climbs by roughly
5×. Decomposing that, about 2× comes from the mask sparsifying (half
the candidates remain at iter 4220) and about 2.5× comes from L2
cache hit rate improving as the working set shrinks toward L2 size.
The 2.5× cache factor is what tiling extracts — applied to the early
game, where it currently does not happen at all.

- **In-shader tile loop** (no grid sync, workgroups drift):
  - 1.5-2.5× speedup on the bandwidth-bound first quarter of each batch
  - Roughly 1.3-1.5× faster total run time
- **Dispatch per tile** (hard grid sync via fence waits):
  - 3-5× speedup on the bandwidth-bound first quarter of each batch
  - Roughly 2-3× faster total run time
  - A further ~1.5-2× on top of that with pipelining (two command
    buffers in flight, CPU records the next tile dispatch while
    the GPU runs the current one). The wins compound because tiling
    raises the dispatch count and pipelining hides per-dispatch
    CPU overhead — alone, either is a moderate win; together they
    multiply because each fixes a different bottleneck.
- **FP16 storage** (stacks on either tiling shape, or stands alone):
  - ~1.8-2× from memory bandwidth being halved
  - Stacks roughly multiplicatively with tiling because the two
    optimizations attack different terms of the same equation
    (access pattern vs. data size)
- **All three together** (dispatch-per-tile + pipelining + FP16):
  - Realistic total ~5-10× speedup, possibly 8-15× on the
    bandwidth-bound early game where all three constraints bite
    simultaneously. The current run's multi-hour first batch
    becomes a sub-hour batch; the total run becomes interactive
    rather than overnight.

Invariants regardless of shape:

- Little change on later iterations (already cache-friendly, since
  the mask is sparse enough that the working set fits L2 naturally)
- Output bit-for-bit identical to the current implementation
- No change to the public API of the diversity cache or its consumers

Practical framing for prioritization: a 3-5× total speedup turns a
multi-hour cache regeneration into a tractable interactive job. If
embeddings are regenerated often (new poems, model retraining, model
upgrade to a different embedding dimension), the engineering
investment pays back quickly. If regeneration is rare, the value is
lower — but the optimization also matters more on larger datasets,
because the cache-fit problem scales superlinearly with the
embedding table size.

