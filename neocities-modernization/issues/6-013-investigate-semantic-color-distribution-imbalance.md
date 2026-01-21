# 6-013: Investigate Semantic Color Distribution Imbalance

## Status
- **Phase**: 6 (Embedding Generation)
- **Priority**: Low
- **Created**: 2026-01-18
- **Related Files**:
  - `src/semantic-color-calculator.lua`
  - `config/semantic-colors.json`
  - `assets/embeddings/*/poem_colors.json`

## Current Behavior

The semantic color assignment algorithm produces heavily skewed distribution:

```
[SEMANTIC COLORS] Color distribution (7844 poems):
[SEMANTIC COLORS]   red: 5043 (64.29%)
[SEMANTIC COLORS]   orange: 1031 (13.14%)
[SEMANTIC COLORS]   green: 1030 (13.13%)
[SEMANTIC COLORS]   purple: 389 (4.96%)
[SEMANTIC COLORS]   blue: 351 (4.47%)
```

Red dominates with 64% of poems, while blue/purple together only account for ~9%.

## Intended Behavior

More balanced color distribution across the semantic spectrum. The ideal distribution
depends on the artistic goals:

1. **Equal distribution**: Each color ~20% (1570 poems each)
2. **Perceptually balanced**: Adjusted for human color perception differences
3. **Semantically proportional**: Colors match the actual semantic content distribution

## Root Cause Analysis

The current algorithm likely:
1. Uses cosine similarity to color concept embeddings
2. Assigns each poem to the highest-similarity color
3. Some color concepts may be more broadly applicable (red = passion/love is common in poetry)

Possible causes:
- Color concept embeddings may be too similar to each other
- The embedding model may have learned biased associations
- Poetry corpus naturally contains more emotionally "red" themes

## Investigation Steps

### Phase 1: Analyze Current Algorithm
1. [ ] Read and document the current color assignment logic in `semantic-color-calculator.lua`
2. [ ] Extract the color concept embeddings from `config/semantic-colors.json`
3. [ ] Calculate pairwise similarity between color concept embeddings
4. [ ] Determine if some colors have very similar embeddings (causing one to dominate)

### Phase 2: Analyze Similarity Distribution
1. [ ] For each poem, log similarities to ALL colors (not just the winning one)
2. [ ] Calculate the "margin of victory" - how much higher is the winning color?
3. [ ] Identify poems with close second-place colors
4. [ ] Visualize the similarity distribution per color

### Phase 3: Explore Solutions

**Option A: Adjusted Thresholds**
- Apply per-color scaling factors to normalize distribution
- Pros: Simple, predictable
- Cons: May not reflect true semantic meaning

**Option B: Color Embedding Refinement**
- Modify color concept definitions to be more distinct
- Pros: Fixes root cause
- Cons: Requires recomputation of color embeddings

**Option C: Softmax Temperature**
- Add temperature parameter to sharpen/soften color assignments
- Pros: Tunable, mathematically sound
- Cons: Still may not balance if similarities are inherently skewed

**Option D: Quantile Normalization**
- Force equal distribution by using percentile-based assignment
- Pros: Guarantees balance
- Cons: May assign semantically wrong colors

**Option E: Cluster-based Assignment**
- K-means cluster poems into N groups, then assign colors to clusters
- Pros: Data-driven, respects poem similarities
- Cons: More complex, may require rebalancing

### Phase 4: Implement and Validate
1. [ ] Choose approach based on investigation findings
2. [ ] Implement solution with A/B comparison capability
3. [ ] Generate before/after color distribution stats
4. [ ] Manually review sample poems from each color for semantic accuracy

## Related Considerations

- The color is used for visual styling in HTML pages
- Colors appear in the "Similar Poems" navigation
- Drastic changes may affect user experience for existing readers
- Consider adding a "color confidence" metric

## Notes

This issue was created after observing the distribution during GPU similarity generation.
The imbalance may be acceptable if it reflects the true semantic content of the poetry
corpus (i.e., if most poems genuinely discuss themes associated with "red").

---

*Created: 2026-01-18*
*Last Updated: 2026-01-18*
