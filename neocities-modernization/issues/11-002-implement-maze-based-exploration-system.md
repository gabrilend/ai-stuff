# Issue 11-002: Implement Maze-Based Exploration System

## Current Behavior

All three navigation modes (similar, different, journey) present poems in a **fixed linear order**. The user has no agency—they scroll through a predetermined sequence without making choices.

```
Current Navigation Model:

    User clicks poem A
           │
           ▼
    ┌─────────────────────────────┐
    │  Similar Page for A         │
    │  ─────────────────────────  │
    │  1. Poem B (most similar)   │  ← No choice
    │  2. Poem C                  │  ← No choice
    │  3. Poem D                  │  ← No choice
    │  ... 7,790 more poems ...   │  ← No choice
    └─────────────────────────────┘
```

## Intended Behavior

Create a **maze-based exploration system** where poems are nodes in a graph, and users navigate by choosing between 3-6 semantically similar options at each "intersection."

### Conceptual Model

```
Maze Navigation Model:

    User at Poem A
           │
    ┌──────┴──────┐
    │ INTERSECTION │
    │─────────────│
    │ Go to B? ──→│  (0.92 similar)
    │ Go to C? ──→│  (0.89 similar)
    │ Go to D? ──→│  (0.87 similar)
    │ Go to E? ──→│  (0.85 similar)
    └─────────────┘
           │
    User chooses C
           │
           ▼
    ┌──────┴──────┐
    │ INTERSECTION │
    │─────────────│
    │ Go to F? ──→│  (new options based on C)
    │ Go to G? ──→│
    │ Go to H? ──→│
    │ ← Back to A │  (backtracking allowed)
    └─────────────┘
```

### Mathematical Foundation

**Step 1: Build k-Nearest-Neighbors Graph**

Treat the 768-dimensional embedding space as a graph:
- Each poem is a **node**
- Each node connects to its **k nearest neighbors** (e.g., k=6)
- Edges are weighted by cosine similarity

```
k-NN Graph (k=5):

    poem_42 ────── poem_847 (0.94)
       │ ╲
       │  ╲─── poem_123 (0.91)
       │   ╲
       │    ╲─ poem_2891 (0.88)
       │
       ├───── poem_1547 (0.86)
       │
       └───── poem_3102 (0.84)
```

**Step 2: Generate Spanning Tree Maze**

Use a maze generation algorithm (Prim's, Kruskal's, or recursive backtracker) to extract a spanning tree from the k-NN graph:

- **Spanning tree** = connected graph touching all nodes with no cycles
- **Guarantees**: Every poem reachable, no forced backtracking
- **Edges kept**: 7,792 (one less than node count)
- **Branching factor**: Variable (some nodes have 1 exit, some have 4+)

```
Spanning Tree Maze:

              poem_42 (START)
             /   |   \
        poem_847  poem_123  poem_2891
           |         |
       poem_501   poem_999
          / \        |
     poem_X poem_Y  poem_Z
        ...        ...
```

**Step 3: Add Extra Edges for Choice**

Keep additional k-NN edges beyond the spanning tree to give users multiple options at each intersection:

```
Maze with Extra Edges:

    At poem_42, user sees:
    - poem_847 (main path + similar)
    - poem_123 (main path + similar)
    - poem_2891 (main path + similar)
    - poem_1547 (extra edge - shortcut!)

    User chooses any, maze adapts
```

### Key Properties

| Property | Value | Notes |
|----------|-------|-------|
| Nodes | 7,793 | All poems reachable |
| Spanning tree edges | 7,792 | Minimum connectivity |
| Extra choice edges | ~31,000 | From k-NN graph |
| Choices per intersection | 2-6 | Based on local k-NN density |
| Backtracking | Optional | User can return to previous poem |
| Cycles | Prevented | Unless user explicitly backtracks |

### Maze Generation Algorithms

**Option A: Randomized Prim's Algorithm**
- Start at random node, grow tree by adding random adjacent edges
- Creates organic, winding paths
- Good for "discovery" feeling

**Option B: Randomized Kruskal's Algorithm**
- Sort all edges, add if they don't create cycle
- Creates more uniform branching
- Good for "fair" distribution of poems

**Option C: Recursive Backtracker (DFS)**
- Depth-first exploration with backtracking
- Creates long corridors with occasional branches
- Good for "journey" feeling

**Recommendation**: Randomized Prim's with seed based on starting poem ID (reproducible but varied per poem).

### User Interface Design

```html
<!-- maze/42.html -->
<html>
<head><title>Poetry Maze - Room 42</title></head>
<body>
<pre>
╔════════════════════════════════════════════════════════════════════╗
║                          POETRY MAZE                                ║
║                         Room 42 of 7793                             ║
╠════════════════════════════════════════════════════════════════════╣
║                                                                     ║
║  [Current Poem Content Here]                                        ║
║                                                                     ║
║  the quick brown fox jumped over the lazy dog                       ║
║  and then sat down to contemplate existence                         ║
║                                                                     ║
╠════════════════════════════════════════════════════════════════════╣
║  WHERE WOULD YOU LIKE TO GO?                                        ║
║                                                                     ║
║  ┌─────────────────────────────────────────────────────────────┐   ║
║  │ → [A] Poem 847: "the slow grey wolf..."        (0.94 match) │   ║
║  │ → [B] Poem 123: "contemplating the void..."    (0.91 match) │   ║
║  │ → [C] Poem 2891: "existence is a funny..."     (0.88 match) │   ║
║  │ → [D] Poem 1547: "brown leaves falling..."     (0.86 match) │   ║
║  └─────────────────────────────────────────────────────────────┘   ║
║                                                                     ║
║  ← [BACK] Return to previous room                                   ║
║                                                                     ║
╚════════════════════════════════════════════════════════════════════╝
</pre>
<p>
  <a href="maze/847.html">[A] Poem 847</a> |
  <a href="maze/123.html">[B] Poem 123</a> |
  <a href="maze/2891.html">[C] Poem 2891</a> |
  <a href="maze/1547.html">[D] Poem 1547</a>
</p>
</body>
</html>
```

### Information Hiding Potential

The user mentioned hiding information within the maze:

> "we could easily hide information within that the user would have to navigate through and toward"

Ideas for hidden content:
- **Golden poems** appear as "rare rooms" with special border treatment
- **Secret areas** reachable only through specific poem chains
- **Centroid rooms** (melancholy, wonder, rage, etc.) as "boss rooms"
- **Easter eggs** at poems with specific ID patterns (e.g., poem 777)

## Suggested Implementation Steps

### Step 1: Build k-NN Graph
- [ ] Add `build_knn_graph(embeddings, k)` function
- [ ] For each poem, compute and store k nearest neighbors with similarities
- [ ] Output: `assets/knn_graph.json` (~50MB estimated)

### Step 2: Implement Maze Generator
- [ ] Add `generate_maze_tree(knn_graph, start_poem_id, seed)` function
- [ ] Implement randomized Prim's algorithm
- [ ] Seed with poem ID for reproducible but varied mazes
- [ ] Output: maze structure (spanning tree + extra edges)

### Step 3: Pre-compute All Mazes
- [ ] Create `scripts/precompute-maze-structures`
- [ ] Generate maze adjacency lists for each starting poem
- [ ] Cache to `assets/maze_cache.json`

### Step 4: Create Maze HTML Generator
- [ ] Add `generate_maze_page(poem_id, maze_cache)` function
- [ ] Render current poem with intersection choices
- [ ] Include back-link to previous room

### Step 5: Integrate into Pipeline
- [ ] Add `maze/` output directory
- [ ] Update `run.sh` to include maze generation step
- [ ] Add maze link to poem headers

### Step 6: Add Special Features
- [ ] Mark golden poems as "treasure rooms"
- [ ] Add centroid poems as "landmark rooms"
- [ ] Consider "fog of war" - hide unvisited poem previews?

## Computational Analysis

### k-NN Graph Construction
- **Comparisons**: O(n²) = 60.7 million
- **Time**: ~30 minutes (single-threaded), ~5 minutes (8 threads)
- **Storage**: 7,793 × 6 × (poem_id + similarity) ≈ 1.5 MB

### Maze Generation
- **Per poem**: O(n log n) for Prim's with priority queue
- **Total**: O(n² log n) for all starting poems
- **Time**: Negligible compared to k-NN construction

### HTML Generation
- **Pages**: 7,793 maze pages
- **Per page**: ~10KB (poem content + 4-6 choices)
- **Total**: ~78 MB (modest compared to similar/different)

## Related Issues

- **Issue 11-001**: Journey-style similar navigation (complementary)
- **Issue 9-003**: Incremental centroid optimization (reusable for k-NN)
- **Issue 8-002**: Multi-threaded generation (parallel maze pages)

## Files to Create

- `src/knn-graph-builder.lua` (k-NN graph construction)
- `src/maze-generator.lua` (Prim's algorithm implementation)
- `scripts/precompute-maze-structures` (pre-computation script)
- `src/maze-html-generator.lua` (HTML page generation)

## Open Questions

1. **Should maze replace an existing mode or be additive?**
   - Recommendation: Additive (fourth navigation mode)

2. **Should back-links preserve history or just go to previous page?**
   - Recommendation: Preserve history (like browser back button)

3. **Should unvisited poems show previews or be hidden?**
   - Recommendation: Show first line as teaser

4. **Should mazes be deterministic per starting poem or truly random?**
   - Recommendation: Deterministic (seeded by poem ID) for cache-ability

---

**Phase**: 11 (Advanced Exploration)

**Priority**: Medium (innovative feature, not blocking deployment)

**Created**: 2025-12-25

**Status**: Open

---

## Appendix: Maze Algorithm Pseudocode

### Randomized Prim's Algorithm

```lua
function generate_maze(knn_graph, start_id)
    local in_maze = {[start_id] = true}
    local maze_edges = {}
    local frontier = {}  -- Edges from maze to non-maze

    -- Initialize frontier with start node's edges
    for _, neighbor in ipairs(knn_graph[start_id]) do
        table.insert(frontier, {from = start_id, to = neighbor.id, sim = neighbor.similarity})
    end

    while #frontier > 0 do
        -- Pick random edge from frontier
        local idx = math.random(#frontier)
        local edge = frontier[idx]
        table.remove(frontier, idx)

        -- Skip if target already in maze (would create cycle)
        if in_maze[edge.to] then
            goto continue
        end

        -- Add edge to maze
        table.insert(maze_edges, edge)
        in_maze[edge.to] = true

        -- Add new node's edges to frontier
        for _, neighbor in ipairs(knn_graph[edge.to]) do
            if not in_maze[neighbor.id] then
                table.insert(frontier, {from = edge.to, to = neighbor.id, sim = neighbor.similarity})
            end
        end

        ::continue::
    end

    return maze_edges
end
```

This creates a spanning tree where every poem is reachable with no cycles, but the path taken is randomized (seeded for reproducibility).
