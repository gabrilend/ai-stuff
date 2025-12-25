# Phase 11 Progress Report

## Phase 11 Goals

**"Advanced Exploration"**

Phase 11 focuses on innovative navigation systems that give users agency in how they explore the poetry corpus, moving beyond linear sequences to graph-based and maze-like discovery experiences.

### **From Phase 8-10**
- Complete HTML generation pipeline functional
- Three navigation modes: similar, different, chronological
- Similarity/diversity algorithms optimized
- TUI menu system integrated

### **Phase 11 Objectives**
- Implement journey-style similar navigation (chain-based, not origin-based)
- Create maze-based exploration system with user choice at intersections
- Build k-nearest-neighbors graph infrastructure
- Add interactive elements within static HTML constraints

## Phase 11 Issues

### Active Issues

| Issue | Description | Status | Priority |
|-------|-------------|--------|----------|
| 11-001 | Implement journey-style similar navigation | Open | Medium |
| 11-002 | Implement maze-based exploration system | Open | Medium |
| 11-002a | Build dimension-extreme index | Open | High |
| 11-002b | Implement similarity-filtered choice selection | Open | High |
| 11-002c | Generate maze HTML pages | Open | Medium |
| 11-002d | Add special room features | Open | Low |
| 11-003 | Maze pipeline integration | Open | Low |

### Completed Issues

| Issue | Description | Status | Completed |
|-------|-------------|--------|-----------|
| (none yet) | - | - | - |

### Issue Dependencies

```
11-002 (Overview)
    │
    ├── 11-002a (Dimension Extremes)
    │       │
    │       └── 11-002b (Similarity Filtering)
    │               │
    │               └── 11-002c (HTML Generation)
    │                       │
    │                       └── 11-002d (Special Rooms)
    │
    └── 11-003 (Pipeline Integration) ← depends on all above
```

## Conceptual Overview

### The Four Navigation Modes

After Phase 11, the website will offer four distinct exploration modes:

| Mode | Algorithm | User Agency | Path Shape |
|------|-----------|-------------|------------|
| **Similar** (current) | Closest to origin | None | Spiral outward |
| **Journey** (11-001) | Closest to previous | None | Wandering chain |
| **Different** | Farthest from centroid | None | Bouncing across space |
| **Maze** (11-002) | Constrained by k-NN graph | **Choose at intersections** | User-directed |

### Mathematical Foundation

All four modes operate in the same 768-dimensional embedding space created by the Ollama model. The difference is how they traverse this space:

1. **Similar**: Euclidean "distance from origin" ordering
2. **Journey**: Greedy nearest-neighbor walk
3. **Different**: Centroid-repulsion with running average
4. **Maze**: k-NN graph with spanning tree constraints

### Why k-NN Graph?

The k-nearest-neighbors graph is the foundation for the maze system:

```
k-NN Graph Properties (k=6):
- Nodes: 7,793 poems
- Edges: ~46,758 (each poem → 6 nearest neighbors)
- Symmetry: Not guaranteed (A's neighbor B may not have A as neighbor)
- Storage: ~1.5 MB JSON

Spanning Tree from k-NN:
- Edges: 7,792 (minimum connectivity)
- Cycles: None (tree property)
- Reachability: 100% (spanning property)
```

## Technical Dependencies

- Phase 8: HTML generation infrastructure
- Phase 9: GPU acceleration (optional, speeds up k-NN construction)
- Issue 9-003: Incremental centroid optimization (reusable techniques)

## Estimated Timeline

| Milestone | Estimated Time | Dependencies |
|-----------|----------------|--------------|
| Dimension-extreme index (11-002a) | ~1 minute | Embeddings complete |
| Similarity filtering (11-002b) | ~3 minutes | 11-002a complete |
| Maze HTML generation (11-002c) | ~10 minutes | 11-002b complete |
| Special room features (11-002d) | ~5 minutes | 11-002c complete |
| Journey pre-computation (11-001) | ~20 hours | Embeddings complete |
| Pipeline integration (11-003) | ~2 hours | All above complete |

### Algorithm Summary (Dimension-Extreme + Similarity Filter)

The maze algorithm uses a two-stage selection:

1. **Stage 1**: For each poem, find 768 "dimension-extreme" poems (one per embedding dimension, maximally different at that index)
2. **Stage 2**: From those 768, select the 6 most similar overall to the original poem

This creates "variations on a theme" - poems that are almost identical except for ONE semantic aspect.

## Completion Criteria

- [ ] Journey-style navigation implemented and cached
- [ ] k-NN graph constructed and validated
- [ ] Maze structures generated for all starting poems
- [ ] Maze HTML pages generated with intersection choices
- [ ] All four navigation modes linked from poem headers
- [ ] Documentation updated with exploration mode explanations

---

**Phase Status: OPEN**

**Created**: 2025-12-25

## Related Documents

- `docs/roadmap.md` - Overall project phases
- `issues/8-002-implement-multithreaded-html-generation.md` - Threading infrastructure
- `issues/9-003-optimize-centroid-calculation-and-parallelization.md` - Optimization patterns
