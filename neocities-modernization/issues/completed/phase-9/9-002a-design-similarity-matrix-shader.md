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

## Implementation Summary

**Shader Created:** `libs/vulkan-compute/shaders/similarity_batch.comp` (59 lines)

**Design Chosen:** Batch similarity computation (triangular format)
- Each invocation computes similarities for one source poem to all higher-indexed poems
- Uses push constants for source_index, num_poems, embedding_dim, num_targets
- Workgroup size: 256 threads (1D layout for simplicity)
- Memory efficient: Only stores source embedding + target similarities

**Key Features:**
- Triangular storage: Only computes upper triangle (i > j)
- Cosine similarity: dot product / (norm_source * norm_target)
- Push constants for dynamic parameters
- Compatible with triangular individual files format (Issue 8-034)

**Files Created:**
- `shaders/similarity_batch.comp` - GLSL compute shader (59 lines)
- `src/vk_similarity.c` - C implementation (290 lines)
- `include/vk_similarity.h` - C API header
- `lua/vk_similarity.lua` - Lua FFI bindings (223 lines)

**Integration:**
- Integrated with run.sh Stage 7 (GPU path exists at lines 574-595)
- Outputs standard triangular JSON format
- Compatible with existing similarity-engine.lua format

## Quality Assurance Criteria

- [x] Shader compiles without errors
- [x] Shader compiled to SPIR-V (build/similarity_batch.spv)
- [x] C wrapper implementation complete (vk_similarity.c)
- [x] Lua bindings complete (vk_similarity.lua)
- [ ] Results validated against CPU reference (pending full test)
- [ ] Performance benchmarked against CPU (pending)

## Dependencies

- 9-001a (Vulkan environment) ✅ COMPLETE
- 9-001b (Vulkan wrapper) ✅ COMPLETE

---

**ISSUE STATUS: COMPLETED (Implementation)**

**Created**: 2025-12-14

**Completed**: 2026-01-10

**Phase**: 9 (GPU Acceleration)

**Priority**: High

**Note**: Shader design and implementation complete. Integration testing and performance benchmarking remain as follow-up tasks in parent issue 9-002.
