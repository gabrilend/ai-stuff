# Issue 9-002: Port Similarity Matrix Generation to Vulkan

## Overview

Port the similarity matrix generation from CPU-based Lua to Vulkan compute shaders. This operation is O(n²) and highly parallelizable.

## Current Behavior

The similarity matrix is computed on the GPU and is the production default
for the pipeline's similarity stage: one dispatch computes every poem pair,
then C threads write the per-poem similarity files and the rankings cache
(see 9-002b, which records the surviving path and the removal of the
earlier per-poem path). The CPU similarity engine was deleted (9-001f).
All three sub-issues are done: 9-002a (the shader), 9-002b (validation,
2026-10-25: `src/similarity-gpu-matches-cpu.test.lua` checks the built table
against a direct calculation, worst difference 7.9e-07 on its first run) and
9-002c (threaded file writing).

Before this issue (kept for the record): the matrix was computed in
single-threaded Lua, every pair a 768-dimension dot product, taking hours.

## Intended Behavior

- GPU-accelerated similarity matrix computation
- All pairs computed in parallel
- Target time: Minutes instead of hours
- Results stored in same format for compatibility

## Sub-Issues

| Sub-Issue | Description | Status | Priority |
|-----------|-------------|--------|----------|
| 9-002a | Design similarity matrix compute shader | ✅ Completed | High |
| 9-002b | Validate GPU similarity implementation | ✅ Completed (2026-10-25) | High |
| 9-002c | Parallelize similarity file writing with thread pool | ✅ Completed | Medium |

## Technical Approach

### Shader Design
```glsl
#version 450
layout(local_size_x = 16, local_size_y = 16) in;

layout(set = 0, binding = 0) readonly buffer Embeddings {
    float embeddings[];  // num_poems * 768
};

layout(set = 0, binding = 1) writeonly buffer SimilarityMatrix {
    float similarities[];  // num_poems * num_poems
};

layout(push_constant) uniform Constants {
    uint num_poems;
    uint embedding_dim;
};

void main() {
    uint i = gl_GlobalInvocationID.x;
    uint j = gl_GlobalInvocationID.y;

    if (i >= num_poems || j >= num_poems) return;
    if (i > j) return;  // Only compute upper triangle

    uint base_i = i * embedding_dim;
    uint base_j = j * embedding_dim;

    float dot_product = 0.0;
    float norm_i = 0.0;
    float norm_j = 0.0;

    for (uint k = 0; k < embedding_dim; k++) {
        float a = embeddings[base_i + k];
        float b = embeddings[base_j + k];
        dot_product += a * b;
        norm_i += a * a;
        norm_j += b * b;
    }

    float similarity = dot_product / (sqrt(norm_i) * sqrt(norm_j));

    // Store in both positions (symmetric matrix)
    similarities[i * num_poems + j] = similarity;
    similarities[j * num_poems + i] = similarity;
}
```

### Memory Considerations
- Full 6,641 × 6,641 float matrix = ~176MB
- Fits easily in 11GB VRAM
- Can compute entire matrix in one dispatch

### Dispatch Strategy
- Workgroup size: 16 × 16 = 256 threads
- Total workgroups: ceil(6641/16) × ceil(6641/16) = 416 × 416 = ~173K
- Each workgroup handles 256 pairs

## Quality Assurance Criteria

- [x] GPU implementation created
- [x] Generates triangular individual files format
- [x] Memory usage stays within VRAM limits
- [x] Shader compiled and integrated with pipeline
- [x] Lua FFI bindings complete
- [x] Full integration testing with actual dataset (Issue 9-002b: it is the only Stage 7 path)
- [x] Performance benchmarking (Issue 9-002b: each build's time is in `.stage-timings`)
- [x] Validation against CPU reference (Issue 9-002b: against a direct calculation, the CPU engine having been removed)

## Performance Targets

| Metric | CPU (current) | GPU (expected) |
|--------|---------------|----------------|
| Time | Hours | Minutes |
| Pairs/sec | ~10K | ~100K+ |

## Suggested Implementation Steps

The sub-issues are the steps, in order:

1. 9-002a, the similarity shader (done).
2. 9-002b, validate on the full dataset: per-pair results match a CPU
   reference within float32 tolerance, and the speedup is measured.
3. 9-002c, write the per-poem files from a thread pool (done 2026-10-20:
   the single-dispatch path writes them from C threads).

## Dependencies

- 9-001b (Vulkan wrapper) ✅
- 9-001c (Cosine distance shader - shares components) ✅

## Blocks

- 9-002a

## Implementation Summary

Created GPU-accelerated similarity matrix computation adapted for triangular individual files format.

**Files Created:**
- `libs/vulkan-compute/shaders/similarity_batch.comp` - Batch similarity shader
- `libs/vulkan-compute/include/vk_similarity.h` - C API header
- `libs/vulkan-compute/src/vk_similarity.c` - Implementation (286 lines)

**Key Features:**
- Computes similarities for one poem to all higher-indexed poems
- Generates data for triangular individual files format
- Batch processing with progress callbacks
- CPU copy of embeddings retained for efficient source extraction
- Memory efficient: ~50 MB (embeddings + buffers)

**Architecture Decision:**
- Adapted to generate triangular format (Issue 8-034) instead of full matrix
- Avoids LuaJIT table overflow issues
- Directly compatible with existing storage format

**Next Steps:**
- **Issue 9-002b**: Validation testing on full dataset, performance benchmarking
- **Issue 9-002c**: Parallelize file writing with thread pool (3× speedup expected)
- Production deployment approval

## Related Files

- `src/similarity-engine-parallel.lua` - Current CPU implementation
- `libs/triangular-similarity-access.lua` - Triangular format access utility

---

**ISSUE STATUS: COMPLETED (Implementation)**

**Created**: 2025-12-14

**Completed**: 2026-01-10

**Phase**: 9 (GPU Acceleration)

**Priority**: Medium (after diversity sequences)

**Note**: Implementation, integration and validation complete (2026-10-25).
