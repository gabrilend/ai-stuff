# Issue 9-001d: Implement Diversity Sequence GPU Algorithm

## Parent Issue
9-001: Implement Vulkan Compute Infrastructure

## Current Behavior
Diversity sequence computed in Lua with O(n²) complexity per sequence:
1. Start with poem's embedding
2. Calculate centroid of selected embeddings
3. Find poem with maximum distance from centroid
4. Add to sequence, repeat until all poems ordered

CPU time: ~25 seconds per sequence, ~46 hours total for 6,641 sequences.

## Intended Behavior
GPU-accelerated diversity sequence generation:
- Parallel distance calculation across all remaining poems
- Parallel reduction to find maximum
- Centroid update on GPU
- Target: ~4-8 seconds per sequence, ~8-15 hours total

## Implementation Steps

### Step 1: Additional Compute Shaders

**centroid_update.comp** - Update centroid with new embedding:
```glsl
#version 450
layout(local_size_x = 256) in;

layout(set = 0, binding = 0) buffer Centroid {
    float centroid[768];
};

layout(set = 0, binding = 1) readonly buffer NewEmbedding {
    float new_embedding[768];
};

layout(push_constant) uniform Constants {
    uint count;  // Number of embeddings in centroid so far
};

void main() {
    uint i = gl_GlobalInvocationID.x;
    if (i >= 768) return;

    // Incremental centroid update
    float old_sum = centroid[i] * float(count);
    float new_sum = old_sum + new_embedding[i];
    centroid[i] = new_sum / float(count + 1);
}
```

**max_reduction.comp** - Find index of maximum distance:
```glsl
#version 450
layout(local_size_x = 256) in;

layout(set = 0, binding = 0) readonly buffer Distances {
    float distances[];
};

layout(set = 0, binding = 1) readonly buffer Mask {
    uint mask[];  // 1 = available, 0 = already selected
};

layout(set = 0, binding = 2) buffer Result {
    uint max_index;
    float max_distance;
};

shared float s_distances[256];
shared uint s_indices[256];

void main() {
    // Parallel reduction implementation
    // ...
}
```

### Step 2: Host-Side Algorithm
```c
void compute_diversity_sequence(VkComputeContext* ctx,
                                 float* embeddings,
                                 uint32_t num_poems,
                                 uint32_t start_poem,
                                 uint32_t* output_sequence) {
    // 1. Upload embeddings to GPU (once)
    // 2. Initialize centroid with start_poem embedding
    // 3. Initialize mask (all available except start_poem)
    // 4. Loop num_poems - 1 times:
    //    a. Dispatch cosine_distance shader
    //    b. Dispatch max_reduction shader
    //    c. Read max_index
    //    d. Dispatch centroid_update shader
    //    e. Update mask
    //    f. Store index in sequence
}
```

### Step 3: Optimize Dispatch Pattern
- [ ] Minimize GPU ↔ CPU synchronization
- [ ] Batch multiple sequences if memory allows
- [ ] Use async compute where beneficial

### Step 4: Validate Results
- [ ] Compare GPU sequences to CPU reference
- [ ] Verify ordering is identical (or acceptably similar given float precision)

## Quality Assurance Criteria

- [ ] GPU sequences match CPU sequences
- [ ] Performance improvement of at least 5x over CPU
- [ ] Memory usage stays within 11GB VRAM
- [ ] Handles full 6,641 poem dataset

## Performance Targets

| Metric | CPU (current) | GPU (target) |
|--------|---------------|--------------|
| Per-sequence | 25s | 4-8s |
| Total (6,641) | 46h | 8-15h |

## Dependencies

- 9-001c (Cosine distance shader)

---

**ISSUE STATUS: OPEN**

**Created**: 2025-12-14

**Phase**: 9 (GPU Acceleration)

**Priority**: High
