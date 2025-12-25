# Issue 11-002: Implement Maze-Based Exploration System

## Current Behavior

All navigation modes (similar, different, chronological) present poems in a **fixed linear order**. The user scrolls through a predetermined sequence without making choices about which direction to explore.

## Intended Behavior

Create a **maze-based exploration system** where users navigate through the poetry corpus by choosing between 3-6 thematically related but subtly different poems at each step.

### Core Algorithm: Dimension-Extreme with Similarity Filter

The algorithm uses a two-stage selection process:

```
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 1: Generate 768 Dimension-Extreme Candidates              │
│ ─────────────────────────────────────────────────────────────── │
│                                                                 │
│ For each dimension i in [0, 767]:                               │
│     Find the poem whose embedding[i] value is most different    │
│     from current_poem.embedding[i]                              │
│                                                                 │
│ Result: 768 poems, each "opposite" along one semantic axis      │
│                                                                 │
│ Example:                                                        │
│   current_poem.embedding = [0.82, -0.31, 0.67, ...]            │
│   dim_0_extreme = poem with embedding[0] ≈ -0.95               │
│   dim_1_extreme = poem with embedding[1] ≈ +0.88               │
│   ...                                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 2: Filter to Most Similar Overall                        │
│ ─────────────────────────────────────────────────────────────── │
│                                                                 │
│ From the 768 candidates:                                        │
│     Compute full cosine similarity to original poem             │
│     Select top 3-6 poems with highest similarity                │
│                                                                 │
│ Result: Poems that are "almost the same, except for ONE thing"  │
│                                                                 │
│ These become the user's exit choices from this "room"           │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Works

The algorithm creates a "variations on a theme" exploration pattern:

| Property | Effect |
|----------|--------|
| **Dimension-extreme selection** | Ensures each candidate differs in ONE specific learned feature |
| **Similarity filtering** | Keeps choices feeling coherent and related |
| **Combined effect** | "Near-clones with a twist" - familiar but subtly different |

The user experiences a journey where each step feels related to the last, but has some ineffable quality that's shifted. Like walking through alternate universe versions of the same poem.

### Mathematical Interpretation

In 768-dimensional embedding space:
- The 768 dimension-extreme candidates form a "shell" around the current poem
- Each candidate lies in a different "octant" (extreme along one axis)
- The similarity filter selects candidates that are still CLOSE despite being extreme
- These are points that are geometrically nearby but lie across dimensional boundaries

### User Experience

1. **No state preservation**: Forward-only navigation. Users can use browser back button if desired.
2. **Pure mystery**: No hints about dimensions or selection criteria. Just poems.
3. **3-6 choices per step**: Enough variety without overwhelming
4. **Deep thematic exploration**: Stay in a "mood neighborhood" while exploring its edges

### Example Navigation Session

```
Room 1: "the autumn leaves fall silently to earth"
        ┌─────────────────────────────────────────┐
        │ Where would you like to go?             │
        │                                         │
        │ → "the autumn leaves drift to ground"   │
        │ → "the maple leaves fall to soil"       │
        │ → "the october leaves fall to earth"    │
        │ → "autumn petals descend silently"      │
        └─────────────────────────────────────────┘

User picks: "autumn petals descend silently"

Room 2: "autumn petals descend silently"
        ┌─────────────────────────────────────────┐
        │ Where would you like to go?             │
        │                                         │
        │ → "spring petals descend gently"        │
        │ → "autumn blossoms fall quietly"        │
        │ → "fading petals drift silently"        │
        │ → "crimson petals sink slowly"          │
        └─────────────────────────────────────────┘

Each choice feels related but offers a subtle shift in one semantic aspect.
```

## Suggested Implementation Steps

See sub-issues for detailed implementation:

- **11-002a**: Build dimension-extreme index (pre-computation)
- **11-002b**: Implement similarity-filtered choice selection
- **11-002c**: Generate maze HTML pages
- **11-002d**: Add special room features (golden poems, landmarks)

## Computational Analysis

### Stage 1: Dimension-Extreme Computation

```
For each poem (7,793):
    For each dimension (768):
        Scan all poems to find extreme → O(7,793)

Total: O(7,793 × 768 × 7,793) = O(46 billion) comparisons

OPTIMIZATION: Pre-sort poems by each dimension value
    Sort once: O(768 × 7,793 × log(7,793)) = O(75 million)
    Lookup: O(768) per poem
    Total with optimization: O(75 million + 7,793 × 768) = O(81 million)
```

### Stage 2: Similarity Filtering

```
For each poem (7,793):
    Compute cosine similarity for 768 candidates: O(768 × 768)
    Sort and take top 6: O(768 log 768)

Total: O(7,793 × 768 × 768) = O(4.6 billion) operations
Time: ~1-2 minutes
```

### Cache Structure

```
Precomputed cache (dimension_maze_cache.json):
{
    "metadata": {
        "algorithm": "dimension-extreme-similarity-filtered",
        "dimensions": 768,
        "choices_per_poem": 6,
        "generated_at": "2025-12-25 ..."
    },
    "exits": {
        "1": [423, 1847, 3291, 892, 5521, 2103],   // poem 1's 6 exit choices
        "2": [1502, 847, 4421, 3892, 721, 6103],   // poem 2's 6 exit choices
        ...
    }
}

Size: 7,793 × 6 × ~4 bytes = ~187 KB
```

## Design Decisions

### Decision 1: Navigation State
**Choice**: No state preservation. Forward-only with browser back.
**Rationale**: Keeps implementation simple. HTML is truly static. Users can map it themselves if curious.

### Decision 2: User Hints
**Choice**: Pure mystery. Just show poems, no dimension/similarity info.
**Rationale**: Let users discover their own patterns. "good luck lmao"

### Decision 3: Cache Strategy
**Choice**: Full precomputation of all 768 dimension-extremes, then filter to 6.
**Rationale**: Different starting poems have different extremes. One-time compute cost (~10 min) for instant HTML generation.

### Decision 4: Number of Choices
**Choice**: 6 exits per room (configurable).
**Rationale**: Enough variety for meaningful choice, few enough to not overwhelm.

## HTML Page Structure

```html
<!-- maze/42.html -->
<html>
<head>
    <meta charset="UTF-8">
    <title>Poetry Maze - Room 42</title>
</head>
<body>
<pre>
╔════════════════════════════════════════════════════════════════════════════════╗
║                               POETRY MAZE                                       ║
╠════════════════════════════════════════════════════════════════════════════════╣
║                                                                                 ║
║  the autumn leaves fall silently to earth                                       ║
║  covering the ground in golden memories                                         ║
║  while birds prepare their journey south                                        ║
║                                                                                 ║
╠════════════════════════════════════════════════════════════════════════════════╣
║  WHERE WOULD YOU LIKE TO GO?                                                    ║
║                                                                                 ║
║  ┌─────────────────────────────────────────────────────────────────────────┐   ║
║  │ → [1] "the autumn leaves drift quietly to ground..."                    │   ║
║  │ → [2] "the maple leaves fall silently to soil..."                       │   ║
║  │ → [3] "october leaves descend gently to earth..."                       │   ║
║  │ → [4] "autumn petals sink slowly to grass..."                           │   ║
║  │ → [5] "the falling leaves whisper to ground..."                         │   ║
║  │ → [6] "crimson leaves drift silently earthward..."                      │   ║
║  └─────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                 ║
╚════════════════════════════════════════════════════════════════════════════════╝
</pre>
<p>
<a href="423.html">[1]</a> |
<a href="1847.html">[2]</a> |
<a href="3291.html">[3]</a> |
<a href="892.html">[4]</a> |
<a href="5521.html">[5]</a> |
<a href="2103.html">[6]</a>
</p>
</body>
</html>
```

## Related Issues

- **Issue 11-001**: Journey-style similar navigation (complementary exploration mode)
- **Issue 9-003**: Centroid optimization patterns (reusable for similarity computation)
- **Issue 8-002**: Multi-threaded HTML generation (parallel maze page generation)

## Sub-Issues

- **11-002a**: Build dimension-extreme index infrastructure
- **11-002b**: Implement similarity-filtered choice selection
- **11-002c**: Generate maze HTML pages
- **11-002d**: Add special room features (golden poems, landmarks, easter eggs)

## Files to Create

- `src/dimension-extreme-builder.lua` (Stage 1 computation)
- `src/maze-choice-selector.lua` (Stage 2 filtering)
- `scripts/precompute-maze-exits` (pre-computation script)
- `src/maze-html-generator.lua` (HTML page generation)

---

**Phase**: 11 (Advanced Exploration)

**Priority**: Medium (innovative feature, not blocking deployment)

**Created**: 2025-12-25

**Updated**: 2025-12-25 (refined algorithm: dimension-extreme + similarity filter)

**Status**: Open
