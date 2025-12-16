# Issue 9-001: Implement Vulkan Compute Infrastructure

## Overview

Create a reusable Vulkan compute infrastructure to replace CPU-bound vector operations across the project. This infrastructure will accelerate diversity sequence generation, similarity matrix calculation, and future embedding operations.

**Target Hardware**: NVIDIA GTX 1080 Ti (3,584 CUDA cores, 11GB VRAM, 484 GB/s bandwidth)

## Current Behavior

- Diversity sequence pre-computation uses effil threading library with catastrophic performance
- Similarity matrix generation is single-threaded Lua
- All vector operations are CPU-bound
- Processing times measured in hours for large datasets

## Intended Behavior

- Vulkan compute shaders handle all vector-heavy operations
- GPU parallelism provides 10-100x speedup for suitable workloads
- Clean C/Lua interface via LuaJIT FFI or standalone binary
- Reusable infrastructure for future features

## Sub-Issues

| Sub-Issue | Description | Priority |
|-----------|-------------|----------|
| 9-001a | Set up Vulkan development environment | High |
| 9-001b | Implement core Vulkan compute wrapper | High |
| 9-001c | Create cosine distance compute shader | High |
| 9-001d | Implement diversity sequence GPU algorithm | High |
| 9-001e | Create Lua/C integration layer | Medium |
| 9-001f | Remove effil dependency | Low |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Lua Scripts (main.lua, generate-html-parallel, etc.)           │
│   - High-level orchestration                                    │
│   - File I/O, JSON handling                                     │
└─────────────────────────────────────────────────────────────────┘
                              │ FFI or subprocess
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ C Vulkan Wrapper (libs/vulkan-compute/)                         │
│   - Device initialization                                       │
│   - Buffer management                                           │
│   - Shader dispatch                                             │
│   - Result retrieval                                            │
└─────────────────────────────────────────────────────────────────┘
                              │ Vulkan API
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ SPIR-V Compute Shaders                                          │
│   - cosine_distance.comp                                        │
│   - centroid_calculation.comp                                   │
│   - max_reduction.comp                                          │
│   - similarity_matrix.comp                                      │
└─────────────────────────────────────────────────────────────────┘
```

## Technical Requirements

### Vulkan Setup
- Vulkan SDK installed
- SPIR-V compiler (glslc or shaderc)
- Validation layers for development

### Compute Shaders Needed
1. **Cosine Distance**: Calculate distance between embedding and centroid
2. **Centroid Calculation**: Average of selected embeddings
3. **Max Reduction**: Parallel reduction to find maximum distance
4. **Similarity Matrix**: Batch cosine similarity for all pairs

### Data Layout
- Embeddings: 6,641 × 768 floats = ~20MB
- Fits entirely in GPU memory
- Single upload, multiple dispatches

## Quality Assurance Criteria

- [ ] Vulkan device initialization succeeds on GTX 1080 Ti
- [ ] Compute shader produces identical results to CPU implementation
- [ ] Performance improvement of at least 5x over CPU
- [ ] Memory usage stays within VRAM limits
- [ ] Clean error handling and resource cleanup
- [ ] Works with validation layers enabled (no errors/warnings)

## Dependencies

- Vulkan SDK
- SPIR-V compiler
- C compiler (gcc/clang)
- LuaJIT (for FFI integration)

## Related Documents

- `docs/effil-vs-compute-shader-feasibility.md` - Feasibility analysis
- Issue 8-002 - Multi-threaded HTML generation (blocked by this)
- Issue 9-002 - Similarity matrix Vulkan port

---

**ISSUE STATUS: OPEN**

**Created**: 2025-12-14

**Phase**: 9 (GPU Acceleration)

**Priority**: High
