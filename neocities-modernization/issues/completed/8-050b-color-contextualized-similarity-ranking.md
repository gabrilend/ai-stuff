# Issue 8-050b: Balanced Color Selection for Word-Page Poem Ranking

## Priority
Medium

## Current Behavior

In `src/generate-word-pages.lua`, the `generate_word_html()` function (line 626) ranks poems for each word page using **pure cosine similarity** between the word embedding and each poem embedding:

```lua
-- Current: rank by word-to-poem similarity only
local similarity = cosine_similarity(word_embedding, poem_embedding)
```

This produces a list of the 50 most semantically similar poems to the word. However, this approach has a color monoculture problem: if "silence" is semantically closest to "blue", then most of the top-ranked poems will also be blue-cluster poems (since semantic similarity and color affinity are correlated). The resulting page would be visually monotone.

## Intended Behavior

Select poems using a **cumulative-similarity-balanced round-robin** across all 7 semantic colors. The algorithm ensures:

1. **Equal color representation**: Roughly N/7 poems per color (e.g., ~7 each for 50 total)
2. **Best-within-category**: Within each color, the highest word-similarity poems are chosen
3. **Cumulative equalization**: When two colors compete for the next slot, the color with the lowest running total of color-similarity scores gets priority — ensuring no color dominates

### Algorithm: Balanced Color Round-Robin

```
Input:
  - word_embedding: the word-cloud word's embedding
  - color_embeddings: embeddings for each of the 7 color names
  - poem_embeddings: all poem embeddings
  - N: number of poems to select (configurable, default 50)

Phase 1: Build candidate pool
  - Rank ALL poems by cosine_similarity(word_embedding, poem_embedding)
  - Take top K candidates (K = N × 7, e.g., 350 for N=50)
  - This pre-filter ensures all candidates are semantically relevant

Phase 2: Compute color affinities
  - For each candidate poem, compute similarity to each of the 7 color embeddings
  - Assign each poem a "best color" = the color with highest similarity
  - Record the similarity score for that best color

Phase 3: Build color buckets
  - Group candidates by their best color
  - Within each bucket, sort by word-similarity (descending)
  - Result: 7 ranked lists, one per color

Phase 4: Balanced selection
  - Initialize cumulative_color_sim[color] = 0 for all 7 colors
  - Initialize selected = {} (empty list)
  - Repeat until #selected == N or all buckets exhausted:
      1. Find the color with the LOWEST cumulative_color_sim
         (ties broken by: which color has more remaining candidates)
      2. From that color's bucket, pop the top poem (highest word-similarity)
      3. Add poem to selected list
      4. Add the poem's color-similarity score to cumulative_color_sim[color]
  - Return selected (ordered by selection sequence)
```

### Why This Works

- **No monoculture**: Even if "silence" is strongly blue, the blue bucket fills its cumulative total quickly (high color-similarity scores), causing other colors to get more turns
- **Self-balancing**: Colors with weaker affinity to the word naturally have lower scores, so they get extra picks to catch up — but they're still picking from semantically relevant poems (from the Phase 1 pre-filter)
- **Best of each color**: Within each color bucket, we always pick the most word-relevant poem first, so quality stays high
- **Graceful degradation**: If a color has zero candidates in the pool, it's simply skipped and other colors absorb its slots

### Example

For "silence" (word color: blue), after Phase 1 pre-filtering:
- Blue bucket: 80 candidates (strong affinity)
- Purple bucket: 45 candidates
- Gray bucket: 40 candidates
- Green bucket: 30 candidates
- Red bucket: 15 candidates
- Orange bucket: 10 candidates
- Yellow bucket: 8 candidates

Round-robin with N=50:
- Round 1: All colors start at 0. Yellow goes first (fewest candidates = tiebreak). Picks best yellow poem (color_sim=0.61). cumulative: {yellow: 0.61}
- Round 2: All others at 0. Orange goes (fewest remaining). Picks best orange (0.63). cumulative: {yellow: 0.61, orange: 0.63}
- ...continues, each color accumulating...
- After 7 rounds: each color has 1 poem
- Round 8: Blue has cumulative 0.87 (high affinity). Yellow has 0.61 (low). Yellow gets next pick.
- ...continues until 50 selected...

Result: ~7 poems per color, with slight imbalances based on availability and cumulative scores.

## Suggested Implementation Steps

### 1. Load color embeddings in `generate_word_html()`

```lua
-- Load color embeddings (same file used by semantic-color-calculator.lua)
local color_embeddings_file = utils.embeddings_dir("embeddinggemma_latest") .. "/color_embeddings.json"
local color_embeddings_data = utils.read_json_file(color_embeddings_file)
local color_embeddings = {}
if color_embeddings_data and color_embeddings_data.embeddings then
    color_embeddings = color_embeddings_data.embeddings
end
```

### 2. Create the balanced selection function

```lua
-- {{{ local function balanced_color_select
-- Selects N poems using cumulative-similarity-balanced round-robin
-- Ensures roughly equal color representation while maintaining word relevance
local function balanced_color_select(candidates, color_embeddings, color_names, N)
    -- Phase 2: Compute color affinities for each candidate
    for _, candidate in ipairs(candidates) do
        local best_color = "gray"
        local best_color_sim = -1
        candidate.color_sims = {}
        for _, color_name in ipairs(color_names) do
            local color_emb = color_embeddings[color_name]
            if color_emb then
                local sim = cosine_similarity(color_emb, candidate.embedding)
                candidate.color_sims[color_name] = sim
                if sim > best_color_sim then
                    best_color_sim = sim
                    best_color = color_name
                end
            end
        end
        candidate.best_color = best_color
        candidate.best_color_sim = best_color_sim
    end

    -- Phase 3: Build color buckets (sorted by word_similarity descending)
    local buckets = {}
    for _, color_name in ipairs(color_names) do
        buckets[color_name] = {}
    end
    for _, candidate in ipairs(candidates) do
        table.insert(buckets[candidate.best_color], candidate)
    end
    for _, color_name in ipairs(color_names) do
        table.sort(buckets[color_name], function(a, b)
            return a.word_similarity > b.word_similarity
        end)
    end

    -- Phase 4: Balanced round-robin selection
    local cumulative = {}
    local bucket_idx = {}  -- next pick index per color
    for _, color_name in ipairs(color_names) do
        cumulative[color_name] = 0
        bucket_idx[color_name] = 1
    end

    local selected = {}
    while #selected < N do
        -- Find color with lowest cumulative score that still has candidates
        local pick_color = nil
        local lowest_cum = math.huge
        local most_remaining = -1
        for _, color_name in ipairs(color_names) do
            local remaining = #buckets[color_name] - bucket_idx[color_name] + 1
            if remaining > 0 then
                local cum = cumulative[color_name]
                if cum < lowest_cum or (cum == lowest_cum and remaining > most_remaining) then
                    lowest_cum = cum
                    pick_color = color_name
                    most_remaining = remaining
                end
            end
        end

        if not pick_color then break end  -- all buckets exhausted

        -- Pop top candidate from this color's bucket
        local idx = bucket_idx[pick_color]
        local poem = buckets[pick_color][idx]
        bucket_idx[pick_color] = idx + 1

        -- Track cumulative color similarity
        cumulative[pick_color] = cumulative[pick_color] + poem.best_color_sim

        table.insert(selected, poem)
    end

    return selected
end
-- }}}
```

### 3. Update the main ranking loop in `generate_word_html()`

Replace the current sort-and-slice approach (lines 736-752) with:

```lua
-- Build candidate pool: top K by word similarity
local candidates = {}
for poem_id_str, poem_embedding in pairs(poem_lookup) do
    local poem_id = tonumber(poem_id_str)
    local poem = poems_by_index[poem_id]
    if poem and poem_embedding then
        local word_sim = cosine_similarity(word_embedding, poem_embedding)
        table.insert(candidates, {
            poem = poem,
            embedding = poem_embedding,
            word_similarity = word_sim
        })
    end
end
table.sort(candidates, function(a, b)
    return a.word_similarity > b.word_similarity
end)

-- Pre-filter to top K (K = poems_per_page × 7)
local pool_size = math.min(#candidates, CONFIG.poems_per_word_page * 7)
local pool = {}
for i = 1, pool_size do pool[i] = candidates[i] end

-- Balanced color selection
local selected = balanced_color_select(
    pool, color_embeddings, color_names, CONFIG.poems_per_word_page)
```

### 4. Add `color_names` to config access

The ordered color list is already in `config.lua:138`:
```lua
color_names = {"red", "blue", "green", "purple", "orange", "yellow", "gray"},
```

Load it in `generate_word_html()`:
```lua
local color_names = unified_config.color_names
    or {"red", "blue", "green", "purple", "orange", "yellow", "gray"}
```

### 5. Store poem embeddings for selection function

The selection function needs access to poem embeddings (for color similarity computation). The current code discards embeddings after computing word similarity. Update to preserve them in the candidate entries (as shown in step 3 above).

## Validation

- Each word page should contain poems from most or all 7 colors
- No single color should dominate the page (max ~N/4 poems of one color for N=50)
- Within each color group, the poems should be semantically relevant to the word
- The cumulative color-similarity totals should be roughly balanced across colors
- A diagnostic log line per word page could report the color distribution:
  ```
  Word "silence": red=7 blue=8 green=7 purple=7 orange=7 yellow=7 gray=7
  ```

## Edge Cases

- **Color with zero candidates in pool**: Skipped in round-robin; other colors absorb slots
- **Pool size smaller than N**: Return all available (may have unbalanced colors)
- **All poems have same best color**: Each round picks from the same bucket; cumulative grows fast but there's no alternative — all N will be that color. This is degenerate but correct.
- **Color embeddings not available**: Fall back to pure word-similarity ranking (current behavior)

## Performance Notes

The additional cost is computing 7 color similarities per candidate poem in the pool. For pool_size=350 and 7 colors:
- 350 × 7 = 2,450 cosine similarity computations
- Each is O(768) → ~1.9M FLOPs total
- Negligible (<1ms on modern CPU)

## Design Note: Interaction with 8-050c

With this balanced selection algorithm, each word page intentionally shows poems from ALL 7 colors. This raises a question for 8-050c: should progress bars show the word's unified color, or should they show each poem's own color (revealing the intentional color diversity)?

Options:
1. **Word color for all bars** (original 8-050c design): Unified visual identity, but hides the color diversity
2. **Per-poem color for bars** (current behavior, but actually working): Shows the rainbow of colors chosen by the balanced selection
3. **Hybrid**: Word color for the page header/title, per-poem color for progress bars

This interaction should be considered when implementing 8-050c. The balanced selection makes per-poem colors more meaningful — each color was intentionally included. Showing those colors reveals the algorithm's work.

## Related Documents

- Issue 8-050: Enhance Word-Cloud Semantic Similarity Pages (parent)
- Issue 8-050a: Compute Semantic Color for Each Word-Cloud Word (provides word-to-color mapping)
- Issue 8-050c: Apply Word Color to Word-Page Progress Bars (affected by this algorithm)
- `src/generate-word-pages.lua:726-752` — Current ranking loop
- `src/diversity-chaining.lua` — Precedent for balanced selection algorithms
- `config.lua:128-138` — Semantic color definitions
- `config.lua:138` — Ordered color names list
- `assets/embeddings/embeddinggemma_latest/color_embeddings.json` — Color embeddings

## Metadata

- **Status**: Completed
- **Created**: 2026-01-26
- **Completed**: 2026-01-28
- **Phase**: 8 (Website Completion)
- **Parent**: 8-050
- **Estimated Complexity**: Medium-High (new selection algorithm + config plumbing)
- **Dependencies**: 8-050a (word colors), color_embeddings.json
- **Blocks**: 8-050e (centroid computation uses final poem list)

## Completion Notes

### Changes Made

1. **Added `balanced_color_select()` function** (lines 307-388):
   - Phase 2: Computes color affinities for each candidate poem
   - Phase 3: Builds color buckets sorted by word similarity
   - Phase 4: Balanced round-robin selection using cumulative totals
   - High-affinity colors "spend" their budget faster, allowing other colors more picks

2. **Updated `generate_word_html()`**:
   - Loads color embeddings for balanced selection (line 878-885)
   - Gets ordered color_names from config (line 887-889)
   - Builds candidate pool with embeddings preserved (lines 951-966)
   - Pre-filters to top K candidates (K = N × 7) for semantic relevance
   - Uses balanced_color_select() when color embeddings available
   - Falls back to pure similarity ranking if color embeddings missing

### Algorithm Summary

```
For each word page:
1. Compute word→poem similarity for ALL poems
2. Take top K candidates (K = 350 for N=50)
3. Assign each candidate its "best color" via color embedding similarity
4. Group into 7 color buckets, sorted by word-similarity within each
5. Round-robin selection: pick from color with lowest cumulative color-similarity
6. Result: ~7 poems per color, best word-relevance within each color
```

### Performance

The additional cost is negligible:
- 350 candidates × 7 colors = 2,450 cosine similarity computations
- Each O(768) → ~1.9M FLOPs total per word page
- <1ms on modern CPU
