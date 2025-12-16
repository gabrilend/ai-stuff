# Issue 9-002: Port Similarity Matrix Generation to Vulkan

## Overview

Port the similarity matrix generation from CPU-based Lua to Vulkan compute shaders. This operation is O(n²) and highly parallelizable.

## Current Behavior

Similarity matrix is calculated in `src/similarity-engine.lua`:
- Single-threaded Lua implementation
- Calculates cosine similarity for all poem pairs
- 6,641 × 6,641 = ~44 million comparisons
- Each comparison: 768-dimensional dot product + norms
- Estimated CPU time: Several hours for full matrix

## Intended Behavior

- GPU-accelerated similarity matrix computation
- All pairs computed in parallel
- Target time: Minutes instead of hours
- Results stored in same format for compatibility

## Sub-Issues

| Sub-Issue | Description | Priority |
|-----------|-------------|----------|
| 9-002a | Design similarity matrix compute shader | High |
| 9-002b | Implement batch processing for large matrices | High |
| 9-002c | Integrate with existing similarity-engine.lua | Medium |

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

- [ ] GPU matrix matches CPU matrix within floating-point tolerance
- [ ] Performance improvement of at least 10x over CPU
- [ ] Memory usage stays within VRAM limits
- [ ] Output format compatible with existing JSON storage

## Performance Targets

| Metric | CPU (current) | GPU (target) |
|--------|---------------|--------------|
| Time | Hours | Minutes |
| Pairs/sec | ~10K | ~1M+ |

## Dependencies

- 9-001b (Vulkan wrapper)
- 9-001c (Cosine distance shader - shares components)

## Related Files

- `src/similarity-engine.lua` - Current CPU implementation
- `assets/embeddings/*/similarity_matrix.json` - Output format

---

**ISSUE STATUS: OPEN**

**Created**: 2025-12-14

**Phase**: 9 (GPU Acceleration)

**Priority**: Medium (after diversity sequences)
