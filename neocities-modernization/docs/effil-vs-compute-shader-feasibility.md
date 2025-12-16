# Parallelization Strategy: CPU vs Vulkan GPU Compute

**Document Purpose**: Evaluate parallelization approaches for diversity sequence pre-computation and other embedding-heavy operations.

**Created**: 2025-12-14
**Updated**: 2025-12-14

**Related Issue**: 8-002 (Implement Multi-threaded HTML Generation)

**Target Hardware**:
- CPU: 16 threads available
- GPU: NVIDIA GTX 1080 Ti (3,584 CUDA cores @ 1.58 GHz, 11GB VRAM, 484 GB/s bandwidth)

---

## Problem Statement

The diversity sequence pre-computation requires:
- For each of ~6,641 poems, generate a complete ordering of all other poems by maximum diversity
- Each sequence requires O(n²) operations: ~22 million vector comparisons (768-dimensional)
- Total operations for all sequences: ~146 billion vector comparisons

The effil threading library proved unsuitable due to ~17 billion cross-thread synchronization operations per sequence.

---

## Option 1: Process-Based CPU Parallelism

### Description
Spawn 16 separate Lua processes, each handling a subset of poems. No shared memory, no synchronization overhead.

### Implementation
```bash
for i in $(seq 0 15); do
    luajit precompute-diversity-chunk.lua $i 16 &
done
wait
luajit merge-diversity-chunks.lua
```

### Performance
- Per-process workload: ~415 sequences × 25s = ~2.9 hours
- Total time: **3-5 hours** (with thermal management)

### Characteristics
| Aspect | Value |
|--------|-------|
| Implementation Effort | Medium (4-6 hours) |
| Memory Usage | ~4GB total |
| Complexity | Low |
| Future Reuse | Limited to CPU workloads |

---

## Option 2: Vulkan Compute Shaders

### Description
Offload vector mathematics to the GPU. The GTX 1080 Ti's 3,584 cores and 484 GB/s memory bandwidth are ideal for this workload.

### Architecture
```
┌─────────────────────────────────────────────────────────────┐
│ Lua/C Host                                                  │
│   - Load embeddings, upload to GPU buffer                   │
│   - Dispatch compute shader per sequence                    │
│   - Read results back                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Vulkan Compute Shader                                       │
│   - All 6,641 embeddings in GPU memory (~20MB)              │
│   - Parallel distance computation across workgroups         │
│   - Parallel reduction for max distance selection           │
│   - Atomic centroid accumulation                            │
└─────────────────────────────────────────────────────────────┘
```

### Performance
- GPU parallel distance calculation: ~0.5-1ms per iteration (vs 4ms CPU)
- Per-sequence time: ~4-8 seconds
- Total time: **2-4 hours** (with optimal batching: potentially under 2 hours)

### Characteristics
| Aspect | Value |
|--------|-------|
| Implementation Effort | High (20-40 hours initial) |
| Memory Usage | ~20MB VRAM |
| Complexity | High initial, low ongoing |
| Future Reuse | High - similarity matrix, embeddings, etc. |

### Vulkan-Specific Considerations
- Explicit memory management (no driver overhead)
- SPIR-V shader compilation
- Integration via LuaJIT FFI or standalone C binary
- Validation layers available for debugging

---

## Comparison

| Criterion | Process-Based (16 proc) | Vulkan Compute (1080 Ti) |
|-----------|-------------------------|--------------------------|
| Runtime | 3-5h | 2-4h |
| Initial Effort | 4-6 hours | 20-40 hours |
| Ongoing Effort | Per-feature | Reusable infrastructure |
| Memory | ~4GB RAM | ~20MB VRAM |
| Thermal Impact | High (16 cores at 100%) | Lower (GPU handles heat better) |
| Extensibility | Limited | High |

---

## Recommended Approach

### Phase 1: Process-Based (Immediate)
Implement process-based parallelism for the diversity pre-computation to unblock HTML generation. This provides a working solution in 4-6 hours of development.

### Phase 2: Vulkan Infrastructure (Strategic)
Build Vulkan compute infrastructure to replace CPU-bound operations across the project:

1. **Diversity sequence generation** - Current blocker
2. **Similarity matrix calculation** - Currently single-threaded, O(n²)
3. **Embedding generation** - If moving to local models
4. **Real-time similarity queries** - For interactive features

The upfront investment pays off when multiple features benefit from GPU acceleration.

---

## Implementation Roadmap

1. ~~Fix index mapping bug~~ (completed via issue 8-004)
2. Implement process-based diversity pre-computation (interim solution)
3. Create Vulkan compute infrastructure
4. Port diversity computation to Vulkan
5. Port similarity matrix generation to Vulkan
6. Remove effil dependency entirely

---

## References

- [Vulkan Compute Tutorial](https://vulkan-tutorial.com/Compute_Shader)
- [Vulkan Specification](https://www.khronos.org/registry/vulkan/specs/1.3/html/)
- [LuaJIT FFI](https://luajit.org/ext_ffi.html)
- [NVIDIA Vulkan Best Practices](https://developer.nvidia.com/blog/vulkan-dos-donts/)
