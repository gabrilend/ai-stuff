# Research Report: Tuple-Based Embeddings (768 × 2D Structure)

**Date**: 2026-01-09
**Project**: Neocities Modernization - Poetry Similarity System
**Research Question**: What would it mean to use 768-dimensional embeddings where each dimension is a 2D tuple instead of a scalar?

---

## Clarification: What We're Actually Asking

This report addresses a **novel embedding structure** where:
- Instead of 768 scalar values: `[0.42, -0.13, 0.89, ...]`
- We have 768 two-dimensional tuples: `[(0.42, -0.13), (0.89, 0.34), (-0.21, 0.67), ...]`

This is **NOT** about dimensionality reduction (768D → 2D). This is about changing the fundamental data type of each dimension from a scalar to a coordinate pair.

---

## Current System vs Tuple-Based System

### Current Scalar Embeddings

```json
{
  "id": "poem-0042",
  "embedding": [
    -0.13334751,    // Dimension 0: scalar intensity
    0.017504867,    // Dimension 1: scalar intensity
    0.00754194,     // Dimension 2: scalar intensity
    ...             // 765 more scalar values
  ]
}
```

**Properties**:
- 768 numbers per poem
- Each dimension = single intensity value
- Total storage: 768 × 4 bytes = 3 KB per poem

### Proposed Tuple Embeddings

```json
{
  "id": "poem-0042",
  "embedding": [
    [-0.13334751, 0.017504867],  // Dimension 0: (x, y) coordinate
    [0.00754194, -0.023819013],  // Dimension 1: (x, y) coordinate
    [0.11234567, 0.98765432],    // Dimension 2: (x, y) coordinate
    ...                          // 765 more (x, y) pairs
  ]
}
```

**Properties**:
- 768 coordinate pairs per poem
- Each dimension = 2D point in its own feature space
- Total storage: 768 × 2 × 4 bytes = 6 KB per poem (2× current)

---

## What Does Each Tuple Dimension Represent?

### Conceptual Interpretations

Each (x, y) tuple in a dimension could represent:

#### 1. **Magnitude + Direction** (Polar-Like Representation)
```
Dimension 0: "Sadness Feature"
  x = intensity of sadness (how sad?)
  y = directionality of sadness (melancholy vs grief vs nostalgia?)

Dimension 1: "Urban Theme"
  x = urban vs rural scale
  y = modern vs historical scale
```

**Example**:
```
Poem A: [(0.9, 0.1), ...]  → Very sad, leaning melancholy
Poem B: [(0.9, 0.9), ...]  → Very sad, leaning grief
Poem C: [(0.1, 0.5), ...]  → Barely sad, neutral direction
```

#### 2. **Positive + Negative Axes** (Bipolar Features)
```
Dimension 0: "Formality Spectrum"
  x = formality (casual ← → formal)
  y = technicality (simple ← → complex)

Dimension 1: "Emotional Valence"
  x = positive emotions
  y = negative emotions
```

**Example**:
```
Poem A: [(0.8, 0.2), ...]  → Formal language, simple concepts
Poem B: [(-0.5, 0.9), ...]  → Casual language, complex ideas
```

#### 3. **Independent Sub-Features**
```
Dimension 0: "Nature Theme"
  x = flora presence (plants, trees, flowers)
  y = fauna presence (animals, insects, birds)

Dimension 1: "Time References"
  x = past-oriented language
  y = future-oriented language
```

#### 4. **Spatial Encoding in Feature Space**
Each dimension represents a position in a learned 2D "concept space" where semantic relationships are encoded spatially. Similar concepts cluster together in the 2D subspace.

---

## Mathematical Properties

### Distance Metrics

With tuple-based embeddings, we need to define how to measure distance:

#### Option 1: Element-Wise 2D Distance, Then Sum
```lua
function tuple_cosine_similarity(embedding_a, embedding_b)
    local dot_product = 0
    local norm_a = 0
    local norm_b = 0

    for i = 1, 768 do
        -- Treat each tuple as a 2D vector in dimension i
        local ax, ay = embedding_a[i][1], embedding_a[i][2]
        local bx, by = embedding_b[i][1], embedding_b[i][2]

        -- 2D dot product for this dimension
        local dim_dot = ax * bx + ay * by
        dot_product = dot_product + dim_dot

        -- 2D magnitude for this dimension
        norm_a = norm_a + (ax * ax + ay * ay)
        norm_b = norm_b + (bx * bx + by * by)
    end

    return dot_product / (math.sqrt(norm_a) * math.sqrt(norm_b))
end
```

This treats the embedding as 1536 flat dimensions (768 × 2).

#### Option 2: Per-Dimension 2D Similarity, Then Average
```lua
function tuple_dimension_aware_similarity(embedding_a, embedding_b)
    local total_similarity = 0

    for i = 1, 768 do
        local ax, ay = embedding_a[i][1], embedding_a[i][2]
        local bx, by = embedding_b[i][1], embedding_b[i][2]

        -- Cosine similarity within this 2D dimension
        local dot = ax * bx + ay * by
        local norm_a = math.sqrt(ax * ax + ay * ay)
        local norm_b = math.sqrt(bx * bx + by * by)

        local dim_similarity = dot / (norm_a * norm_b + 1e-8)
        total_similarity = total_similarity + dim_similarity
    end

    return total_similarity / 768
end
```

This treats each dimension as its own 2D similarity calculation.

#### Option 3: Euclidean Distance Per Dimension
```lua
function tuple_euclidean_distance(embedding_a, embedding_b)
    local total_distance = 0

    for i = 1, 768 do
        local ax, ay = embedding_a[i][1], embedding_a[i][2]
        local bx, by = embedding_b[i][1], embedding_b[i][2]

        -- 2D Euclidean distance in this dimension
        local dx = ax - bx
        local dy = ay - by
        local dim_distance = math.sqrt(dx * dx + dy * dy)

        total_distance = total_distance + dim_distance
    end

    return total_distance / 768  -- Average distance per dimension
end
```

---

## Advantages of Tuple-Based Embeddings

### 1. **Richer Feature Representation**
- Each semantic feature can encode TWO aspects instead of one
- Example: "sadness" can have both intensity AND type
- More nuanced similarity: poems can be "similarly sad but differently sad"

### 2. **Natural Multi-Aspect Encoding**
- Separates complementary properties within each feature
- Could capture contradictions: high joy + high sadness simultaneously
- Allows for "orthogonal" semantic properties in same dimension

### 3. **Polar/Angular Relationships**
```
If dimensions encode magnitude + direction:
  - Can find poems with "same energy, different direction"
  - Can find poems with "same theme, different approach"
  - Angular distance captures stylistic variation
```

### 4. **Dimension-Specific Visualization**
- Each of 768 dimensions can be plotted as scatter plot
- See how poems cluster in "Sadness Space" (dimension 42)
- Identify outliers in specific semantic dimensions

### 5. **Flexible Similarity Metrics**
- Can weight magnitude vs direction differently
- Can emphasize certain dimensions over others
- Can compute "structural similarity" (angles) separate from "intensity similarity" (magnitudes)

---

## Disadvantages and Challenges

### 1. **Double Storage Requirements**
```
Current: 7,797 poems × 768 floats × 4 bytes = 24 MB
Tuple:   7,797 poems × 1,536 floats × 4 bytes = 48 MB

Increase: 24 MB (100% growth)
```

For this project, storage is not an issue (48 MB is trivial). But at scale this matters.

### 2. **Ambiguous Semantic Interpretation**
- What does the x-axis vs y-axis of dimension 347 mean?
- Neural networks would learn these automatically, but interpretation is harder
- May not align with human intuitions

### 3. **No Existing Pre-Trained Models**
- Current embedding models (Gemma, BERT, etc.) output scalar dimensions
- Would need to train custom model from scratch
- Or: artificially split existing dimensions into pairs (loses meaning)

### 4. **Similarity Metric Uncertainty**
- Which distance formula is "correct"?
- Different metrics give different results
- Need empirical testing to validate

### 5. **Computational Cost**
- 2× floating-point operations for distance calculations
- More complex similarity logic
- Potentially slower indexing/search

### 6. **Harder to Integrate with Existing Tools**
- Most vector databases expect flat scalar vectors
- Visualization tools assume 1D per dimension
- Would need custom infrastructure

---

## How Would You Create Tuple Embeddings?

### Option 1: Train Custom Model

**Architecture**: Modify transformer output layer to produce 2D vectors per dimension

```python
class TupleEmbeddingModel(nn.Module):
    def __init__(self):
        self.transformer = TransformerEncoder()
        # Output: 768 dimensions × 2 values each
        self.output_layer = nn.Linear(hidden_size, 768 * 2)

    def forward(self, text):
        hidden = self.transformer(text)
        flat_output = self.output_layer(hidden)  # Shape: (1536,)
        # Reshape to (768, 2)
        return flat_output.reshape(768, 2)
```

**Training**: Contrastive learning with tuple-aware loss function

**Pros**: Learns meaningful 2D structure
**Cons**: Requires large dataset and compute

### Option 2: Split Existing Embeddings

**Naive Approach**: Take 768D embedding, reshape to (384, 2)

```python
embedding_768d = model.encode(poem)  # [768] scalars
embedding_384tuples = embedding_768d.reshape(384, 2)  # [(x,y)] × 384
```

**Pros**: Uses existing models
**Cons**:
- Reduces from 768 to 384 dimensions
- No semantic meaning to the pairing
- Arbitrary split (dimension 0 + 1 may not be related)

### Option 3: Learned Projection from Scalar to Tuple

**Approach**: Train adapter layer that converts scalar to tuple

```python
# Start with existing 768D scalar embeddings
scalar_embedding = gemma_model.encode(poem)  # [768] scalars

# Train small network to project each scalar to (x, y)
tuple_embedding = []
for i, scalar in enumerate(scalar_embedding):
    x, y = projection_network(scalar, dimension_id=i)
    tuple_embedding.append([x, y])
```

**Training**: Use similarity-preserving loss (maintain relative distances)

**Pros**: Preserves all 768 dimensions, builds on existing models
**Cons**: Still requires training; unclear if useful

### Option 4: Engineered Semantic Tuples

**Manual Design**: Create 768 hand-crafted 2D feature spaces

```python
# Dimension 0: Emotional Valence
x = positive_emotion_score(poem)  # 0-1
y = negative_emotion_score(poem)  # 0-1

# Dimension 1: Formality
x = formal_language_ratio(poem)   # 0-1
y = vocabulary_complexity(poem)   # 0-1

# ... 766 more hand-crafted features
```

**Pros**: Fully interpretable
**Cons**: Requires enormous manual effort, likely worse than learned features

---

## Use Cases Where Tuple Embeddings Excel

### 1. **Multi-Aspect Similarity Search**
```
Query: "Find poems that are similarly sad but expressed differently"
- Compare magnitude (intensity of sadness): must be similar
- Compare angles (expression of sadness): must be different
```

### 2. **Feature Space Exploration**
```
Visualize all poems in "Love Dimension Space":
  x-axis: romantic love
  y-axis: familial love

See which poems occupy which quadrants
```

### 3. **Contradiction Detection**
```
Dimension 42: (joy, sadness)
  Poems with high values in BOTH coordinates are emotionally complex
  Find poems with (0.9, 0.9) → "bittersweet" or "nostalgic"
```

### 4. **Directional Similarity**
```
Find poems "moving in the same semantic direction":
  Calculate angular similarity between vectors
  Group poems by trajectory in feature space
```

---

## Use Cases Where Scalar Embeddings Are Better

### 1. **Standard Similarity Ranking**
- Scalar embeddings are simpler and well-understood
- Proven to work for semantic similarity
- No ambiguity in distance calculation

### 2. **Integration with Existing Tools**
- Vector databases (FAISS, Annoy, etc.) expect flat vectors
- Pre-trained models output scalars
- Established best practices

### 3. **Interpretability of Results**
- "These poems have cosine similarity 0.87" is clear
- With tuples: "Is that 0.87 in magnitude? Angle? Combined?"

### 4. **Computational Efficiency**
- Half the storage, half the computation
- Faster indexing and retrieval

---

## Hybrid Approach: Structured Tuple Interpretation

**Idea**: Keep scalar embeddings computationally, but interpret them as tuples conceptually

```lua
-- Store as flat 1536-dimensional vector for computation
embedding = [x1, y1, x2, y2, x3, y3, ..., x768, y768]

-- Organize into 768 tuples for visualization/analysis
function get_dimension_tuple(embedding, dim_index)
    local i = (dim_index - 1) * 2
    return embedding[i + 1], embedding[i + 2]
end

-- Compute similarity on flat vector (standard cosine)
similarity = cosine_similarity_flat(embedding_a, embedding_b)

-- Visualize specific dimensions as 2D spaces
plot_dimension(poems, dimension=42)  -- Shows all poems in this 2D feature
```

**Benefits**:
- Compatible with existing infrastructure
- Can train as 1536D model
- Interpret as 768 tuples for analysis
- Best of both worlds

---

## Practical Implications for This Project

### Current System
- **Model**: `embeddinggemma:latest` (768D scalar)
- **Size**: 7,797 poems × 3 KB = 24 MB
- **Similarity**: Standard cosine similarity

### If Switching to Tuple Embeddings

#### Storage Impact
```
Current: 24 MB embeddings
Tuple:   48 MB embeddings
Increase: +24 MB (still trivial for this project)
```

#### Generation Time Impact
```
Must re-embed all 7,797 poems with new model
Current embedding: ~1-2 seconds per poem
Total: ~2-4 hours for full re-generation
```

#### Similarity Calculation Changes
```lua
-- Current (flat-html-generator.lua:1156)
function calculate_similarity(poem_a, poem_b)
    return cosine_similarity(poem_a.embedding, poem_b.embedding)
end

-- With tuples (new version)
function calculate_similarity_tuple(poem_a, poem_b)
    -- Need to decide on metric (see distance options above)
    return tuple_aware_similarity(poem_a.embedding, poem_b.embedding)
end
```

#### Website Generation Impact
```
No change to HTML generation
Changes only affect:
  1. Embedding generation (src/ollama-embedder.lua)
  2. Similarity calculation (src/flat-html-generator.lua)
  3. Possibly similarity matrix format
```

---

## Experimental Path Forward

If you want to explore tuple embeddings:

### Phase 1: Synthetic Test (1-2 hours)
1. Take 100 poems from existing dataset
2. Artificially create tuple embeddings (reshape 768 → 384×2)
3. Implement multiple distance metrics
4. Compare similarity rankings against scalar baseline
5. See if any interpretation emerges

### Phase 2: Learned Projection (1-2 days)
1. Train small network to project scalar → tuple
2. Use similarity-preserving loss
3. Re-compute similarities
4. Measure quality (precision/recall on human similarity judgments)

### Phase 3: Custom Model (1-2 weeks)
1. Fine-tune transformer to output tuples directly
2. Train on poetry similarity task
3. Evaluate against scalar baseline
4. Test interpretability of learned 2D spaces

### Phase 4: Integration (2-3 days)
1. Update embedding generator
2. Update similarity calculator
3. Regenerate all embeddings
4. Rebuild website

---

## Recommendations

### For This Project (Neocities Poetry)

**Recommendation**: **Keep scalar embeddings for now**, but consider tuple structure for future experiments

**Why**:
1. **Proven Quality**: Scalar embeddings work well for semantic similarity
2. **No Existing Models**: Would need to train custom tuple model from scratch
3. **Unclear Benefit**: No evidence tuple structure improves poetry similarity
4. **Integration Cost**: Would require significant refactoring
5. **Interpretability**: Scalar dimensions are already hard to interpret; tuples are harder

**When Tuple Embeddings Make Sense**:
- After gathering user feedback on similarity quality
- If you identify specific multi-aspect features (e.g., "sad but hopeful")
- If you want to build interactive dimension-specific exploration tools
- If you're willing to train a custom model

### For Research/Exploration

**Recommendation**: **Try synthetic tuple experiment** (Phase 1 above)

**Why**:
1. Low cost (1-2 hours)
2. No model training required
3. Can validate if tuple structure offers anything
4. If promising → proceed to Phase 2
5. If not → abandon with minimal cost

### For Future Work

**Potential Application**: **Dimension-specific visualization**

Even with scalar embeddings, you could:
1. Take pairs of dimensions (e.g., dim 42 & 43)
2. Plot poems in 2D space defined by those dimensions
3. Create 384 such plots (768 dimensions = 384 pairs)
4. Find which dimension-pairs show interesting clusters
5. Interpret what those dimensions represent

This gives you tuple-like visualization WITHOUT changing the embedding structure.

---

## Conclusion

**Tuple-based embeddings** (768 dimensions × 2D coordinates) represent a novel and largely unexplored embedding architecture. They offer:

**Potential Advantages**:
- Richer feature representation (2 aspects per dimension)
- Natural encoding of multi-faceted properties
- Dimension-specific 2D exploration
- Flexible similarity metrics

**Significant Challenges**:
- No existing pre-trained models
- Ambiguous semantic interpretation
- Unclear similarity metrics
- 2× storage requirements
- Limited proven benefits

**For this project**: The **scalar 768D embeddings are sufficient** for accurate poetry similarity. Tuple embeddings are an interesting research direction but not necessary for the current goals.

**Recommendation**: Keep current scalar embeddings. Consider exploring tuple structure if:
1. You want to experiment with novel embedding architectures
2. You identify specific multi-aspect features that would benefit from 2D representation
3. You're willing to train custom models and validate results

The cost/benefit ratio currently favors scalar embeddings, but tuple embeddings remain an intriguing avenue for future research.

---

**End of Report**

*This research demonstrates that while tuple-based embeddings offer theoretical advantages for multi-aspect semantic representation, their practical benefits remain uncertain without empirical validation. The current scalar embedding system is well-suited for this project's needs.*
