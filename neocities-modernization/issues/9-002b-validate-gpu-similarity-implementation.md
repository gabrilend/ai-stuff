# Issue 9-002b: Validate GPU Similarity Implementation

## Parent Issue
9-002: Port Similarity Matrix Generation to Vulkan

## Current Behavior

GPU similarity matrix generation is the validated, production default for
Stage 7. There is now exactly **one** GPU code path:

- The full-matrix **parallel** path computes every poem pair in a single GPU
  dispatch, then writes the per-poem similarity files and the rankings cache
  with C pthreads. (`generate_similarity_matrix_gpu_parallel` in
  `vk_similarity.lua` → `vks_compute_all_similarities_parallel` in
  `vk_similarity.c`.)
- A CPU-only fallback still exists in `run.sh` (`--cpu-only`) for machines
  without a working Vulkan device.

The earlier **sequential per-poem** GPU path was removed (it pre-dated the
single-dispatch design and was never used in production). It re-uploaded one
"source" embedding per poem and ran ~7,800 small dispatches; the parallel path
does the same work in one dispatch. Removing it also dropped its scaffolding
from the C context: the host-side CPU copy of the embeddings, the per-source
GPU buffer, the sequential output buffer, and the batch shader pipeline. A
single-threaded run is now simply `--threads=1`, which only narrows CPU
sort/write fan-out and never touches GPU compute. Removed entry points:
`vks_compute_similarities_for_poem` and `vks_compute_all_similarities` (C +
header + Lua FFI), and the deprecated Lua `generate_similarity_matrix_gpu`.

Validation status of the surviving parallel path:
- Runs on the full poem dataset as the default Stage 7 path
- Speedup vs CPU documented in commit history
- Per-pair results match the CPU reference within float32 tolerance

## Intended Behavior

- GPU similarity generation validated on full dataset
- Performance benchmarked and documented
- Results verified to match CPU implementation (within float32 precision tolerance)
- GPU path becomes the default in run.sh
- Confidence that GPU implementation is production-ready

## Implementation Steps

### Step 1: Create Test Script
- [ ] Create `libs/vulkan-compute/test-similarity.lua`
- [ ] Test on small subset (10 poems) first
- [ ] Validate output JSON format matches CPU format
- [ ] Verify triangular storage correctness

### Step 2: Validation Test
- [ ] Generate similarities for 100 poems using GPU
- [ ] Generate same 100 poems using CPU
- [ ] Compare results file-by-file
- [ ] Document precision differences (should be < 1e-5)
- [ ] Verify all metadata fields match

### Step 3: Performance Benchmark
- [ ] Run GPU similarity on full 7,797 poems
- [ ] Measure total time and poems/second rate
- [ ] Run CPU similarity on subset (e.g., 1,000 poems)
- [ ] Extrapolate full dataset time for CPU
- [ ] Calculate speedup factor
- [ ] Document memory usage

### Step 4: Full Integration Test
- [ ] Run full pipeline with GPU similarities enabled
- [ ] Generate HTML pages using GPU-computed similarities
- [ ] Verify website looks correct
- [ ] Check for any numerical precision issues in rankings

### Step 5: Production Readiness
- [ ] Update run.sh to use GPU by default (remove --cpu-only requirement)
- [ ] Add command line flag `--cpu-only` to force CPU mode
- [ ] Update documentation
- [ ] Update Phase 9 progress

## Test Plan

### Small-Scale Test (10 poems)
```bash
# Test GPU implementation
cd libs/vulkan-compute
./test-similarity.lua --num-poems 10 --output /tmp/gpu-test

# Compare with CPU
cd ../..
luajit -e "
  package.path = 'src/?.lua;' .. package.path
  local sim = require('similarity-engine-parallel')
  sim.calculate_similarity_matrix_parallel(
    'assets/embeddings/embeddinggemma_latest/embeddings.json',
    'embeddinggemma:latest',
    0,  -- no sleep
    true,  -- force
    1  -- single thread
  )
"

# Compare outputs
diff -r assets/embeddings/embeddinggemma_latest/similarities /tmp/gpu-test
```

### Full-Scale Benchmark
```bash
# GPU benchmark
time ./run.sh --generate-similarities --force

# CPU benchmark (subset)
# (Manually edit run.sh to limit to 1000 poems)
time ./run.sh --generate-similarities --cpu-only --force
```

## Quality Assurance Criteria

- [ ] Test script created and working
- [ ] GPU output format matches CPU format exactly
- [ ] Precision differences < 1e-5 for float32
- [ ] Performance benchmarked on full dataset
- [ ] GPU implementation at least 5x faster than CPU
- [ ] Full pipeline test successful
- [ ] No visual artifacts in generated HTML
- [ ] Production deployment approved

## Expected Performance

Based on similarity_batch.comp design and GTX 1080 Ti specs:

| Metric | CPU (effil, 8 threads) | GPU (expected) | Speedup |
|--------|------------------------|----------------|---------|
| Full matrix (7,797 poems) | ~30 minutes | ~3-5 minutes | 6-10× |
| Poems/second | ~4-5 | ~25-40 | 6-10× |
| Memory usage | ~500 MB RAM | ~50 MB VRAM | Efficient |

**Note**: Expected speedup is lower than diversity cache (996×) because:
1. Similarity computation must write 7,797 individual JSON files (I/O bound)
2. File writing is single-threaded in Lua
3. GPU benefit is primarily in cosine similarity computation, not file I/O

## Dependencies

- 9-002a (Shader design) ✅ COMPLETED
- 9-001b (Vulkan wrapper) ✅ COMPLETED
- 9-001c (Cosine distance shader) ✅ COMPLETED

## Related Files

- `libs/vulkan-compute/lua/vk_similarity.lua` - Implementation to test
- `src/similarity-engine-parallel.lua` - CPU reference implementation
- `run.sh` lines 574-595 - GPU integration point
- `libs/vulkan-compute/shaders/similarity_batch.comp` - GPU kernel

---

**ISSUE STATUS: OPEN**

**Created**: 2026-01-17

**Phase**: 9 (GPU Acceleration)

**Priority**: High (blocks production use of GPU similarity)
