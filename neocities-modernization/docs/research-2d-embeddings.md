# Research Report: Two-Dimensional Embeddings for Poetry Similarity

**Date**: 2026-01-09
**Project**: Neocities Modernization - Poetry Similarity System
**Research Question**: What would it mean to use 2D embeddings instead of high-dimensional embeddings?

---

## Current System Analysis

### Existing Configuration

The project currently uses:
- **Model**: `embeddinggemma:latest` (Google's Gemma embedding model)
- **Dimensionality**: 768 dimensions
- **Total Poems**: 7,797 poems embedded
- **File Size**: 62 MB for all embeddings
- **Endpoint**: Ollama local server

### How Current Embeddings Work

Each poem is represented as a **768-dimensional vector** of floating-point numbers:
```
[-0.13334751, 0.017504867, 0.00754194, -0.023819013, ...]
```

**Semantic Meaning**: Each dimension captures a latent feature learned by the neural network. These might correspond to abstract concepts like:
- Emotional tone (sadness, joy, anger)
- Thematic content (nature, technology, relationships)
- Stylistic features (formal, casual, poetic devices)
- Grammatical structures
- Semantic topics

The high dimensionality allows the model to capture **rich, nuanced semantic relationships** between texts.

---

## What Are 2D Embeddings?

### Definition

**Two-dimensional embeddings** would represent each poem as just two numbers: `[x, y]`

Example:
```
Poem 1: [0.42, -0.13]
Poem 2: [0.15, 0.89]
Poem 3: [-0.67, 0.22]
```

These would represent the poem's position on a 2D plane that could be directly visualized as:
```
     y
     │
  ●  │     ●  (Poem 2)
     │
─────┼───────── x
     │  ●
     │   (Poem 3)
(Poem 1)
```

### How They're Created

2D embeddings are typically created through **dimensionality reduction** techniques:

1. **PCA (Principal Component Analysis)**
   - Linear projection that preserves maximum variance
   - Fast, deterministic
   - Loses non-linear relationships

2. **t-SNE (t-Distributed Stochastic Neighbor Embedding)**
   - Non-linear, preserves local neighborhoods
   - Good for visualization
   - Slow, non-deterministic, loses global structure

3. **UMAP (Uniform Manifold Approximation and Projection)**
   - Preserves both local and global structure better than t-SNE
   - Faster than t-SNE
   - Better for both visualization and similarity

4. **Direct Training**
   - Train a model to output 2D vectors directly
   - Requires specific architecture and loss function
   - Rarely done due to severe information loss

---

## Comparison: 768D vs 2D

### Information Capacity

| Aspect | 768D (Current) | 2D (Proposed) |
|--------|---------------|---------------|
| **Expressiveness** | Can encode 768 independent features | Can only encode 2 features |
| **Semantic Nuance** | Captures subtle thematic distinctions | Very coarse groupings only |
| **Similarity Granularity** | Fine-grained: "slightly similar" vs "very similar" | Binary: "close" or "far" |
| **Information Loss** | Minimal (from original text) | Extreme (99.74% fewer dimensions) |

### What Gets Lost in 2D

When compressing 768 dimensions to 2, you lose:
- **Multi-faceted similarity**: A poem can be similar in theme but different in tone
- **Hierarchical relationships**: Poems about "urban nature" vs "wilderness nature"
- **Subtle distinctions**: "melancholy" vs "nostalgic sadness"
- **Cluster overlap**: Poems that belong to multiple semantic categories
- **Distance precision**: Many poems will have similar distances by pure geometric constraint

### Visualization Example

With 768D, similarity relationships might look like (conceptually):
```
Poem A: [0.1 in "sadness", 0.9 in "urban", 0.3 in "short-form", ... 765 more]
Poem B: [0.9 in "sadness", 0.1 in "nature", 0.8 in "long-form", ... 765 more]

Similarity: 0.42 (moderately similar - both sad, different settings/length)
```

With 2D, this collapses to:
```
Poem A: [0.52, 0.31]
Poem B: [0.48, 0.71]

Similarity: 0.28 (based only on 2D distance)
```

---

## What 2D Would Be Good At

### Strengths

1. **Visualization**
   - Can display ALL poems on a single scatter plot
   - Users see spatial relationships immediately
   - Clusters are visually obvious

2. **Speed**
   - Distance calculations are 384× faster (2 vs 768 dimensions)
   - Sorting by similarity is instantaneous
   - Memory usage: 97% reduction (2 floats vs 768 floats per poem)

3. **Interpretability**
   - Axes might be human-understandable (e.g., "formal ← → casual" and "sad ← → joyful")
   - Users can see their position in "poem space"
   - Navigation becomes intuitive spatial movement

4. **Exploration Interface**
   - Could build an interactive map where users click regions
   - Zoom in/out to explore density
   - Draw paths through thematic regions

5. **Clustering**
   - Visual clustering is obvious
   - Could color-code regions
   - Easy to identify "islands" of similar content

### Use Cases Where 2D Excels

- **Browse mode**: "Show me the general landscape of all poems"
- **Quick exploration**: "What's in this thematic region?"
- **Overview visualization**: "Where am I in the collection?"
- **Teaching**: "Here's how poems relate spatially"

---

## What 2D Would Be Bad At

### Weaknesses

1. **Accuracy Loss**
   - Similar poems in 768D might be far apart in 2D (false negatives)
   - Different poems in 768D might be close in 2D (false positives)
   - Loss of subtle semantic relationships

2. **Forced Simplification**
   - Complex relationships become binary: close or not close
   - Multi-dimensional similarity (theme + style + tone) becomes single distance
   - Loses ability to be "similar in one way, different in another"

3. **Projection Artifacts**
   - Dimensionality reduction creates artificial boundaries
   - "Unfolding" of high-D space creates distortions
   - Some distances preserved, others completely wrong

4. **Poor Granularity**
   - With 7,797 poems, 2D space gets very crowded
   - Many poems will have nearly identical 2D positions
   - Hard to distinguish between "5th most similar" and "50th most similar"

5. **Non-Transferable**
   - 2D projection is specific to this dataset
   - New poems can't be easily added (requires re-projection)
   - Can't compare to embeddings from other sources

### Use Cases Where 2D Fails

- **Precise similarity ranking**: "Show me the top 100 most similar poems"
- **Subtle distinction**: "Find poems with similar theme but different tone"
- **Cross-modal tasks**: "Find poems matching this image/music"
- **Dynamic updates**: Adding new poems requires full re-projection

---

## Hybrid Approach: Best of Both Worlds

### Recommended Architecture

**Use both simultaneously**:

1. **768D for computation**
   - Keep for all similarity calculations
   - Use for generating recommendation lists
   - Maintain accuracy and nuance

2. **2D for visualization**
   - Pre-compute using UMAP
   - Store as separate fields: `visual_x`, `visual_y`
   - Use only for display, not computation

### Implementation

```lua
-- Data structure
{
  poem_id = 42,
  embedding_768d = [...768 numbers...],  -- For computation
  visual_2d = {x = 0.42, y = -0.13},    -- For display only
  color = "blue",  -- Based on 768D cluster
  title = "Autumn Memory"
}
```

### Benefits

- **Accurate similarity**: Use 768D for all recommendations
- **Visual exploration**: Show 2D scatter plot for browsing
- **Color coding**: Use 768D to determine semantic clusters, color the 2D viz
- **Dual navigation**: Click on map (2D) → get precise neighbors (768D)

---

## Practical Example: This Project

### Current System (768D Only)

**Similarity Calculation**:
```
Poem A: [768 dimensions]
Poem B: [768 dimensions]

Cosine similarity = dot(A, B) / (||A|| * ||B||)
Result: 0.87 (very similar)
```

**UI**: Text-only navigation
- "Similar poems" link → list of poem IDs
- No spatial awareness
- No overview of collection structure

### With 2D Visualization Added

**Homepage**: Interactive scatter plot
```
    ┌──────────────────────────────┐
    │         ●                   ●│  (Each dot = poem)
    │   ●   ●● ●         ●        │
    │     ●●●    ●   ● ●●         │  Color = theme
    │  ●  ●  ●●     ●●  ●        ●│
    │    ● ●  ●  ●    ●●●  ●      │  Click = navigate
    │  ●     ●●      ●   ●  ●    ●│
    └──────────────────────────────┘
       sad ← → joyful
```

**Features**:
- Click any poem → see 768D-accurate neighbors
- Hover → poem preview
- Zoom → explore dense regions
- Filter by time → animated timeline
- Search → highlight matching poems in space

### Storage Impact

```
Current: 7,797 poems × 768 floats × 4 bytes = 24 MB
With 2D: 7,797 poems × 770 floats × 4 bytes = 24.1 MB

Additional storage: ~100 KB (negligible!)
```

---

## Recommendations for This Project

### Option 1: Keep 768D Only (Current)
**Best for**: Text-based exploration, maximum accuracy
**Trade-off**: No visual overview

### Option 2: Add 2D Visualization (Hybrid)
**Best for**: Visual exploration + accurate similarity
**Trade-off**: Slight complexity, one-time computation cost

### Option 3: 2D Only (Not Recommended)
**Best for**: Small datasets (<100 items), purely visual browsing
**Trade-off**: Massive accuracy loss, poor for this use case

### My Recommendation: **Option 2 (Hybrid)**

**Why**:
1. Best of both worlds: accurate computation + visual exploration
2. Minimal storage overhead (0.4% increase)
3. Enables new interaction paradigms (spatial browsing)
4. Helps users understand collection structure
5. Can be computed once offline (not part of main pipeline)

**Implementation Steps**:
1. Compute 2D projections using UMAP
2. Add `visual_x`, `visual_y` fields to `embeddings.json`
3. Generate interactive HTML scatter plot (using pure HTML canvas)
4. Link 2D positions to 768D similarity lists
5. Add to homepage as exploration interface

---

## Conclusion

**768D embeddings** are essential for accurate semantic similarity - they capture the rich, multi-faceted nature of poetry meaning.

**2D embeddings** sacrifice accuracy for intuition - they make relationships visible and explorable but lose 99.74% of the semantic information.

**The ideal solution**: Use 2D as a **visualization layer** on top of 768D computation. Think of 2D as a "map" that helps you navigate, while 768D is the actual "distance calculator" that tells you how far apart things really are.

The extra storage cost is negligible (~100 KB), but the UX benefit is enormous: users can finally SEE the structure of the collection, not just navigate it blindly through text links.

---

## Technical Notes

### Generating 2D Projections

**Using UMAP** (recommended):
```python
import umap
import numpy as np

# Load 768D embeddings
embeddings_768d = load_embeddings("embeddings.json")  # Shape: (7797, 768)

# Create UMAP projection
reducer = umap.UMAP(
    n_components=2,
    metric='cosine',
    n_neighbors=15,
    min_dist=0.1,
    random_state=42
)

# Compute 2D positions
embeddings_2d = reducer.fit_transform(embeddings_768d)  # Shape: (7797, 2)

# Normalize to [0, 1] range for display
x_norm = (embeddings_2d[:, 0] - embeddings_2d[:, 0].min()) / (embeddings_2d[:, 0].max() - embeddings_2d[:, 0].min())
y_norm = (embeddings_2d[:, 1] - embeddings_2d[:, 1].min()) / (embeddings_2d[:, 1].max() - embeddings_2d[:, 1].min())

# Save to JSON
save_2d_positions(zip(x_norm, y_norm))
```

### Visualization Code

**Pure HTML/Canvas** (no JavaScript frameworks):
```html
<canvas id="poemMap" width="800" height="600"></canvas>
<script>
const canvas = document.getElementById('poemMap');
const ctx = canvas.getContext('2d');

// Load poem positions
const poems = loadPoemData();  // [{x, y, title, color, id}, ...]

// Draw each poem as a circle
poems.forEach(poem => {
    ctx.fillStyle = poem.color;
    ctx.beginPath();
    ctx.arc(poem.x * 800, poem.y * 600, 3, 0, 2 * Math.PI);
    ctx.fill();
});

// Click handler
canvas.onclick = (e) => {
    const x = e.offsetX / 800;
    const y = e.offsetY / 600;
    const clicked = findNearestPoem(x, y);
    window.location = `/similar/${clicked.id}.html`;
};
</script>
```

---

**End of Report**

*This research demonstrates that while 2D embeddings offer powerful visualization capabilities, they should complement rather than replace high-dimensional embeddings for semantic similarity tasks.*
