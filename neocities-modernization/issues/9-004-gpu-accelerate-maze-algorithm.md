# Issue 9-004: GPU-Accelerate Maze Algorithm

## Overview

Accelerate the dimension-extreme + similarity-filter maze algorithm (Issue 11-002) using the Vulkan compute infrastructure (Issue 9-001). This issue is blocked by both Phase 9 infrastructure AND Phase 11 algorithm design.

## Current Behavior (CPU Implementation - Issue 11-002)

The maze algorithm has two stages:

**Stage 1: Dimension-Extreme Computation**
```lua
-- For each poem P (7,793):
--   For each dimension D (768):
--     Find poem Q where |Q.embedding[D] - P.embedding[D]| is maximum
--
-- Naive: O(7,793 × 768 × 7,793) = 46 billion comparisons
-- With pre-sorting: O(768 × n log n) + O(n × 768) = ~81 million ops
```

**Stage 2: Similarity Filtering**
```lua
-- For each poem P (7,793):
--   For each of ~500 unique dimension-extreme candidates:
--     Compute full cosine similarity (768 dimensions)
--   Select top 6 by similarity
--
-- Total: O(7,793 × 500 × 768) = ~3 billion ops
```

**CPU Estimated Time**: ~3-5 minutes total

## Intended Behavior (GPU Implementation)

Use Vulkan compute shaders to parallelize both stages:

### GPU Stage 1: Parallel Dimension-Extreme Finding

**Approach A: Naive Parallel (Simple, Memory-Heavy)**
```
For each dimension D (768 dispatches):
    Dispatch shader that computes |embedding[D] - current_val| for all poems
    Parallel reduction to find argmax
    Store result

Memory: 7,793 floats per dispatch = 31KB (trivial)
Dispatches: 768 × 7,793 = 5.9 million (too many!)
```

**Approach B: Per-Poem Parallel (Better)**
```
For each poem P (7,793 dispatches):
    Upload P's embedding values to uniform buffer
    Dispatch shader with 768 workgroups (one per dimension)
    Each workgroup finds the extreme for its dimension
    Write 768 poem IDs to output buffer

Dispatches: 7,793 (manageable)
Per-dispatch work: 768 workgroups × 7,793 comparisons = 6M ops (fast)
```

**Approach C: Fully Batched (Optimal)**
```
Single dispatch with 2D workgroups:
    Dimension (X): 768 workgroups
    Poem batch (Y): 128 poems per dispatch

Pre-upload all embeddings (~20MB) once
For each batch of 128 poems:
    Dispatch 768 × 128 workgroups
    Each finds dimension-extreme for (poem, dimension) pair
    Write to structured output buffer

Dispatches: ceil(7,793 / 128) = 61 dispatches
Total GPU time: ~100ms estimated
```

### GPU Stage 2: Parallel Cosine Similarity

Reuse the cosine distance shader from Issue 9-001c with modifications:

```glsl
// Instead of comparing to a single centroid, compare to N candidates
// Output: similarity scores for top-K selection

layout(set = 0, binding = 0) readonly buffer Embeddings {
    float embeddings[];  // All 7,793 × 768 floats
};

layout(set = 0, binding = 1) readonly buffer CandidateIndices {
    uint candidates[];  // 768 candidate poem IDs per source poem
};

layout(set = 0, binding = 2) writeonly buffer Similarities {
    float similarities[];  // 768 scores per source poem
};

// Dispatch: one workgroup per (source_poem, candidate) pair
// Or: one workgroup per source_poem, loop over candidates
```

After GPU computes similarities, CPU performs simple top-6 selection (negligible time).

## Compute Shader Designs

### Shader 1: dimension_extreme.comp

```glsl
#version 450

layout(local_size_x = 256) in;

layout(set = 0, binding = 0) readonly buffer Embeddings {
    float embeddings[];  // 7,793 × 768 floats
};

layout(set = 0, binding = 1) readonly buffer SourceValues {
    float source_values[768];  // Current poem's embedding
};

layout(set = 0, binding = 2) writeonly buffer Extremes {
    uint extreme_ids[];  // 768 poem IDs (output)
};

layout(push_constant) uniform Constants {
    uint num_poems;
    uint source_poem_id;  // To exclude from search
};

shared float s_max_diff[256];
shared uint s_max_idx[256];

void main() {
    uint dim = gl_WorkGroupID.x;  // Which dimension (0-767)
    uint tid = gl_LocalInvocationID.x;
    uint poems_per_thread = (num_poems + 255) / 256;

    float source_val = source_values[dim];
    float local_max_diff = 0.0;
    uint local_max_idx = 0;

    // Each thread scans a portion of poems
    for (uint i = 0; i < poems_per_thread; i++) {
        uint poem_id = tid * poems_per_thread + i;
        if (poem_id >= num_poems || poem_id == source_poem_id) continue;

        float val = embeddings[poem_id * 768 + dim];
        float diff = abs(val - source_val);

        if (diff > local_max_diff) {
            local_max_diff = diff;
            local_max_idx = poem_id;
        }
    }

    // Store in shared memory
    s_max_diff[tid] = local_max_diff;
    s_max_idx[tid] = local_max_idx;
    barrier();

    // Parallel reduction to find global max
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (tid < stride) {
            if (s_max_diff[tid + stride] > s_max_diff[tid]) {
                s_max_diff[tid] = s_max_diff[tid + stride];
                s_max_idx[tid] = s_max_idx[tid + stride];
            }
        }
        barrier();
    }

    // Thread 0 writes result for this dimension
    if (tid == 0) {
        extreme_ids[dim] = s_max_idx[0];
    }
}
```

### Shader 2: batch_cosine_similarity.comp

Reuse/extend 9-001c for batch candidate comparison:

```glsl
#version 450

layout(local_size_x = 64) in;

layout(set = 0, binding = 0) readonly buffer Embeddings {
    float embeddings[];
};

layout(set = 0, binding = 1) readonly buffer SourceEmbedding {
    float source[768];
};

layout(set = 0, binding = 2) readonly buffer CandidateIDs {
    uint candidate_ids[];  // Up to 768 candidate poem IDs
};

layout(set = 0, binding = 3) writeonly buffer Similarities {
    float similarities[];
};

layout(push_constant) uniform Constants {
    uint num_candidates;
};

void main() {
    uint cand_idx = gl_GlobalInvocationID.x;
    if (cand_idx >= num_candidates) return;

    uint poem_id = candidate_ids[cand_idx];
    uint base = poem_id * 768;

    float dot = 0.0, norm1 = 0.0, norm2 = 0.0;
    for (uint i = 0; i < 768; i++) {
        float a = source[i];
        float b = embeddings[base + i];
        dot += a * b;
        norm1 += a * a;
        norm2 += b * b;
    }

    similarities[cand_idx] = dot / (sqrt(norm1) * sqrt(norm2));
}
```

## Host-Side Algorithm

```c
void compute_maze_exits_gpu(VkComputeContext* ctx,
                            float* embeddings,      // 7,793 × 768 floats
                            uint32_t num_poems,
                            MazeCache* output) {

    // Upload embeddings once (20MB → GPU)
    upload_embeddings(ctx, embeddings, num_poems);

    for (uint32_t poem_id = 0; poem_id < num_poems; poem_id++) {
        // Stage 1: Find 768 dimension extremes
        upload_source_embedding(ctx, &embeddings[poem_id * 768]);
        dispatch_dimension_extreme_shader(ctx, num_poems, poem_id);
        uint32_t extremes[768];
        download_extreme_ids(ctx, extremes);

        // Deduplicate extremes (CPU - fast)
        uint32_t unique[768];
        uint32_t num_unique = deduplicate(extremes, 768, unique);

        // Stage 2: Compute similarities to unique candidates
        upload_candidate_ids(ctx, unique, num_unique);
        dispatch_batch_similarity_shader(ctx, num_unique);
        float similarities[768];
        download_similarities(ctx, similarities, num_unique);

        // Select top 6 (CPU - fast)
        select_top_k(unique, similarities, num_unique, 6, output->exits[poem_id]);
    }
}
```

## Performance Analysis

### CPU Baseline (Issue 11-002)
| Stage | Time |
|-------|------|
| Dimension-extreme (all poems) | ~60 seconds |
| Similarity filtering (all poems) | ~120 seconds |
| **Total** | **~3 minutes** |

### GPU Accelerated
| Stage | Time | Speedup |
|-------|------|---------|
| Upload embeddings | 50ms | N/A |
| Dimension-extreme (per poem) | 1-2ms | 10x |
| Similarity filtering (per poem) | 0.5ms | 20x |
| Download + CPU postprocess | 1ms | N/A |
| **Per-poem total** | **~4ms** | **15x** |
| **All 7,793 poems** | **~31 seconds** | **6x** |

**Note**: The CPU baseline is already fast (~3 min). GPU acceleration provides 6x speedup but may not be worth the complexity unless combined with other GPU workloads in the same session.

### Combined Benefit

If running maze + diversity + similarity matrix in same session:
- Single embeddings upload (~50ms)
- Reuse shaders across all algorithms
- Total session time: ~30 minutes (vs. hours without GPU)

## Suggested Implementation Steps

### Step 1: Implement dimension_extreme.comp Shader
- [ ] Write GLSL compute shader
- [ ] Compile to SPIR-V
- [ ] Validate with test data

### Step 2: Extend Cosine Distance Shader for Batching
- [ ] Modify 9-001c to accept candidate ID list
- [ ] Add batch processing support

### Step 3: Host-Side Integration
- [ ] Add maze-specific functions to Vulkan wrapper
- [ ] Implement upload/download for maze data structures

### Step 4: Lua/C Interface
- [ ] Expose GPU maze computation to Lua
- [ ] Fallback to CPU if GPU unavailable

### Step 5: Integrate with Maze Pipeline
- [ ] Modify 11-002a to use GPU when available
- [ ] Add GPU/CPU mode flag

## Dependencies

**Blocked By:**
- **9-001b**: Vulkan compute wrapper (infrastructure)
- **9-001c**: Cosine distance shader (reused for Stage 2)
- **11-002**: Maze algorithm design (algorithm definition)
- **11-002a**: Dimension-extreme index (CPU reference implementation)
- **11-002b**: Similarity-filtered selection (CPU reference implementation)

**Enables:**
- Faster maze generation in combined GPU sessions
- Pattern for future embedding-space algorithms

## Files to Create

- `libs/vulkan-compute/shaders/dimension_extreme.comp`
- `libs/vulkan-compute/shaders/batch_cosine_similarity.comp`
- `libs/vulkan-compute/maze_compute.c` (host-side functions)
- `src/maze-gpu-accelerator.lua` (Lua interface)

## Quality Assurance Criteria

- [ ] GPU results match CPU reference implementation exactly
- [ ] No validation layer errors
- [ ] Handles full 7,793 poem dataset
- [ ] Graceful fallback when GPU unavailable
- [ ] Memory usage stays within 11GB VRAM

## Related Issues

- **9-001**: Vulkan compute infrastructure (parent)
- **9-001c**: Cosine distance shader (reused)
- **9-001d**: Diversity sequence GPU (similar pattern)
- **11-002**: Maze algorithm design
- **11-002a**: Dimension-extreme index (CPU version)
- **11-002b**: Similarity-filtered selection (CPU version)

---

**Phase**: 9 (GPU Acceleration)

**Priority**: Low (optimization, not required for MVP)

**Created**: 2025-12-25

**Status**: Open

**Blocked By**: 9-001b, 9-001c, 11-002, 11-002a, 11-002b

---

## Appendix: Dependency Graph

```
Phase 9 (GPU Infrastructure)          Phase 11 (Maze Algorithm)
            │                                   │
            ▼                                   ▼
    ┌───────────────┐                  ┌────────────────┐
    │ 9-001a: Setup │                  │ 11-002: Design │
    └───────┬───────┘                  └───────┬────────┘
            │                                   │
            ▼                                   ▼
    ┌───────────────┐                  ┌─────────────────┐
    │ 9-001b: Wrap  │                  │ 11-002a: Dim-Ex │
    └───────┬───────┘                  └────────┬────────┘
            │                                   │
            ▼                                   ▼
    ┌───────────────┐                  ┌─────────────────┐
    │ 9-001c: Cos   │                  │ 11-002b: Filter │
    └───────┬───────┘                  └────────┬────────┘
            │                                   │
            └──────────────┬───────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │ 9-004: GPU Maze │ ← THIS ISSUE
                  └─────────────────┘
```
