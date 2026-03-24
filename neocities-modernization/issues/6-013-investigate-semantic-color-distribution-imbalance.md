# 6-013: Investigate Semantic Color Distribution Imbalance

## Status
- **Phase**: 6 (Embedding Generation)
- **Priority**: Medium (upgraded from Low - visual variety is important)
- **Created**: 2026-01-18
- **Related Files**:
  - `src/semantic-color-calculator.lua`
  - `config/semantic-colors.json`
  - `assets/embeddings/*/poem_colors.json`
  - `assets/embeddings/*/word_colors.json`

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

### Word Color Distribution (also imbalanced)

The wordcloud word colors show the same problem, just shifted:

```
Word color distribution (7155 words):
  orange: 3892 (54.4%)
  red:    2123 (29.7%)
  yellow:  878 (12.3%)
  blue:    116 (1.6%)
  purple:  107 (1.5%)
  green:    26 (0.4%)
  gray:     13 (0.2%)
```

This confirms the problem is with how color concept embeddings occupy the semantic space,
not with poems or words specifically. Orange/red dominate because their concept embeddings
are close to a huge swath of the embedding space.

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

**Option F: Minimum-Cost Rebalancing**
- Store ALL color similarities for each word/poem, not just the winner
- Identify "close call" assignments where 2nd place color is nearly as strong
- Move ambiguous items from over-represented colors to under-represented colors
- Prioritize moves with smallest "margin of victory" (lowest semantic cost)
- Pros: Preserves strong associations, only moves genuinely ambiguous items
- Pros: Tunable stopping point (balance threshold)
- Pros: Interpretable (can explain why each item was reassigned)
- Cons: Requires storing full similarity vectors (minor storage increase)

This is essentially a minimum-cost flow problem: move "units" (words/poems) from surplus
nodes (orange/red) to deficit nodes (blue/green/purple), where the cost of each move
is the semantic distance (difference between 1st and 2nd place scores).

**Option G: Word-Mediated Color Assignment (RECOMMENDED)**
- For each poem, find the most similar wordcloud word
- Inherit that word's color (words already have colors computed)
- Adds a layer of semantic indirection: poem → word → color
- Pros: Words are more atomic/concrete, may have cleaner color associations
- Pros: Interpretable ("this poem is colored blue because it's most similar to 'ocean'")
- Pros: Leverages existing word color infrastructure
- Cons: Computationally expensive (~8000 poems × ~7000 words = ~56M comparisons)
- Cons: Word colors themselves are imbalanced (may need Option F rebalancing afterward)

This approach can be combined with Option F: first assign colors via word mediation,
then apply minimum-cost rebalancing if distribution is still skewed.

### Phase 4: Implement Option G (Word-Mediated Color Assignment)

#### Step 1: Load required data
```lua
-- Load poem embeddings
local poems = load_json("cache/poems.json")
local poem_embeddings = load_json("assets/embeddings/MODEL/embeddings.json")

-- Load word embeddings and colors
local word_embeddings = load_json("assets/embeddings/MODEL/word_embeddings.json")
local word_colors = load_json("assets/embeddings/MODEL/word_colors.json")

-- Build word lookup: word_name -> { embedding, color }
local word_lookup = {}
for _, wc in ipairs(word_colors.word_colors) do
    word_lookup[wc.word] = { color = wc.color, similarity = wc.similarity }
end
```

#### Step 2: Compute poem-to-word similarities
```lua
function assign_poem_color_via_word(poem_embedding, word_embeddings, word_lookup)
    local best_word = nil
    local best_similarity = -1

    for word, word_emb in pairs(word_embeddings) do
        local sim = cosine_similarity(poem_embedding, word_emb)
        if sim > best_similarity then
            best_similarity = sim
            best_word = word
        end
    end

    return {
        color = word_lookup[best_word].color,
        via_word = best_word,
        word_similarity = best_similarity
    }
end
```

#### Step 3: Pipeline Integration

Current pipeline structure (relevant stages):
```
Stage 6:  Generate embeddings (poems) via Ollama
  └─ 6a: Generate word embeddings (for wordcloud)
  └─ 6b: Compute semantic colors (current: poem → color concepts)
Stage 7:  Build similarity matrix (poem-to-poem)
Stage 9:  Generate HTML (uses poem colors)
```

**New pipeline stage needed**: Poem-to-word similarity computation

Option A: Replace stage 6b with word-mediated assignment
```
Stage 6b: Compute poem colors via word mediation
  1. Load poem embeddings (from 6)
  2. Load word embeddings (from 6a)
  3. For each poem, find most similar word
  4. Inherit word's color
  5. Apply rebalancing if needed (Option F)
  6. Output: poem_colors.json (same format, enhanced metadata)
```

Option B: Add new sub-stage 6c (keep 6b for comparison)
```
Stage 6b: Compute direct semantic colors (existing)
Stage 6c: Compute word-mediated colors (new)
  - Config flag to choose which method HTML generation uses
```

**Files to modify:**
- `run.sh`: Add stage 6c or modify stage 6b
- `src/semantic-color-calculator.lua`: Add word-mediated assignment function
- `config.lua`: Add `color_assignment_method = "word_mediated"` option

#### Step 4: Optimize for performance
- ~56M similarity calculations is expensive but manageable
- Options for speedup:
  1. **Batch processing**: Process poems in batches, show progress
  2. **GPU acceleration**: Use existing Vulkan infrastructure (if word embeddings fit in VRAM)
  3. **Approximate nearest neighbor**: Use LSH or FAISS for faster lookup (overkill for 7K words)
  4. **Parallel processing**: Use effil workers or pthreads (existing infrastructure)

#### Step 5: Store results with provenance
```lua
-- Enhanced poem_colors.json format:
{
    poem_index = 1234,
    color = "blue",
    assignment_method = "word_mediated",  -- vs "direct" for old method
    via_word = "ocean",                   -- which word determined the color
    word_similarity = 0.89,               -- how similar poem is to that word
    word_color_confidence = 0.94          -- how confident the word's color assignment was
}
```

#### Step 6: Apply Option F rebalancing (if needed)
After word-mediated assignment, check distribution. If still skewed, apply minimum-cost
rebalancing using the word similarities as the basis for reassignment costs.

### Phase 5: Implement Option F (Minimum-Cost Rebalancing) - if needed after Phase 4

#### Step 1: Modify semantic-color-calculator.lua to store full similarity vectors
```lua
-- Instead of just storing the winning color:
-- { word = "ocean", color = "orange", similarity = 0.94 }

-- Store all similarities:
-- { word = "ocean",
--   color = "orange",          -- winner (for backward compatibility)
--   similarity = 0.94,         -- winner score (for backward compatibility)
--   all_similarities = {
--     orange = 0.94, blue = 0.91, red = 0.87, green = 0.72, purple = 0.65, yellow = 0.58
--   }
-- }
```

#### Step 2: Implement rebalancing algorithm
```lua
function rebalance_colors(items, target_distribution)
    -- 1. Calculate current counts and targets
    local current_counts = count_by_color(items)
    local total = #items
    local target_per_color = total / num_colors  -- or custom targets

    -- 2. Identify surplus and deficit colors
    local surplus = {}   -- colors with too many items
    local deficit = {}   -- colors with too few items

    -- 3. For items in surplus colors, calculate "reassignment cost"
    --    cost = similarity[current_color] - similarity[candidate_color]

    -- 4. Sort by cost (ascending) - lowest cost = most ambiguous

    -- 5. Reassign lowest-cost items to deficit colors until balanced
    --    Prefer moving to 2nd-place color; use 3rd-place if 2nd is also surplus

    -- 6. Stop when:
    --    a) All colors within threshold of target, OR
    --    b) No more "cheap" moves (all remaining items have high reassignment cost)
end
```

#### Step 3: Add configurable balance threshold
```lua
-- config.lua
color_rebalancing = {
    enabled = true,
    target_distribution = "equal",  -- "equal" or custom {red=0.2, blue=0.2, ...}
    max_reassignment_cost = 0.15,   -- Don't move if margin > 15%
    min_color_percentage = 0.10,    -- Every color should have at least 10%
}
```

#### Step 4: Validate and compare
1. [ ] Generate before/after color distribution stats
2. [ ] Sample 10 items per color that were reassigned - verify semantic fit
3. [ ] Ensure items with high "margin of victory" were NOT reassigned
4. [ ] Output reassignment log: "ocean: orange→blue (cost: 0.03)"

## Related Considerations

- The color is used for visual styling in HTML pages
- Colors appear in the "Similar Poems" navigation
- Drastic changes may affect user experience for existing readers
- Consider adding a "color confidence" metric

## Notes

This issue was created after observing the distribution during GPU similarity generation.

### 2026-03-23 Update
Analysis of wordcloud word colors revealed the same imbalance (orange 54%, red 30%),
confirming the problem is with color concept embedding placement in semantic space,
not with poems specifically.

**Recommended approach: Option G + Option F combined**

1. **Option G (Word-Mediated Assignment)**: Assign poem colors by finding the most
   similar wordcloud word and inheriting its color. This adds a layer of semantic
   indirection that may produce cleaner associations (words are more atomic than poems).

   Bonus: This is interpretable! "This poem is blue because it's most similar to 'ocean'."

2. **Option F (Minimum-Cost Rebalancing)**: If word-mediated assignment is still skewed,
   apply rebalancing by moving "close call" poems to under-represented colors.

The key insight: words are semantic anchors. A poem about the ocean might get "red" via
direct color-concept comparison (because it's emotional), but via word mediation it gets
"blue" (because "ocean" → blue is a strong association).

**Compute cost**: ~56M similarity calculations (8K poems × 7K words), but manageable
with existing parallel processing infrastructure.

---

*Created: 2026-01-18*
*Last Updated: 2026-03-23*
