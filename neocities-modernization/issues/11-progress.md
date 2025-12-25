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

### Completed Issues

| Issue | Description | Status | Completed |
|-------|-------------|--------|-----------|
| (none yet) | - | - | - |

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
| k-NN graph construction | 30 min - 5 hours | Embeddings complete |
| Journey pre-computation | ~20 hours | Same as diversity cache |
| Maze structure generation | ~1 hour | k-NN graph complete |
| HTML generation | ~30 min | All caches complete |

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
