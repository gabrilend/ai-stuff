# Issue 9-002a: Design Similarity Matrix Compute Shader

## Parent Issue
9-002: Port Similarity Matrix Generation to Vulkan

## Current Behavior
No GPU shader for similarity matrix computation.

## Intended Behavior
Efficient compute shader that calculates all pairwise cosine similarities.

## Implementation Steps

### Step 1: Basic Shader Implementation
- [ ] Create `similarity_matrix.comp` based on design in 9-002
- [ ] Handle symmetric matrix optimization (only compute upper triangle)
- [ ] Compile to SPIR-V

### Step 2: Optimize Memory Access
- [ ] Use shared memory for frequently accessed data
- [ ] Optimize workgroup size for GTX 1080 Ti
- [ ] Profile different access patterns

### Step 3: Handle Edge Cases
- [ ] Poems with zero-norm embeddings (random embeddings should be unit vectors, but verify)
- [ ] Diagonal entries (self-similarity = 1.0)

### Step 4: Validate Precision
- [ ] Compare GPU float32 results to CPU results
- [ ] Determine acceptable tolerance (1e-6 typical for float32)
- [ ] Document any precision trade-offs

## Shader Variants to Consider

1. **Naive**: Each thread computes one similarity
2. **Tiled**: Use shared memory tiles for better cache utilization
3. **Vectorized**: Use vec4 operations for 4x throughput on dot products

## Quality Assurance Criteria

- [ ] Shader compiles without errors
- [ ] Results within 1e-5 of CPU reference
- [ ] Performance at least 10x faster than CPU

## Dependencies

- 9-001a (Vulkan environment)

---

**ISSUE STATUS: OPEN**

**Created**: 2025-12-14

**Phase**: 9 (GPU Acceleration)

**Priority**: High
