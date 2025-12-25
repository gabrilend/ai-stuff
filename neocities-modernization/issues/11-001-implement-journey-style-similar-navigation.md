# Issue 11-001: Implement Journey-Style Similar Navigation

## Current Behavior

The "similar" pages (`similar/XXX.html`) display poems sorted by their cosine similarity to the **starting poem**. This creates a "spiral outward" pattern where:

1. User starts at poem A
2. Poem B is shown (most similar to A)
3. Poem C is shown (second most similar to A)
4. Poem D is shown (third most similar to A)
5. ...and so on, always comparing back to the origin

```
Current Algorithm:

    A (origin) ──┬── B (closest to A)
                 ├── C (2nd closest to A)
                 ├── D (3rd closest to A)
                 └── E (4th closest to A)

Path shape: Expanding sphere from origin
```

This means poems at the end of the list may be semantically very different from each other, even though they're all roughly equidistant from the origin.

## Intended Behavior

Change the "similar" algorithm to find the **next closest poem to the previous poem** in the sequence, creating a wandering chain through semantic space:

```
New Algorithm (Journey-Style):

    A ──→ B ──→ C ──→ D ──→ E
    │     │     │     │     │
    └─────┴─────┴─────┴─────┘
    Each step: find closest to PREVIOUS, not to origin

Path shape: Wandering chain through embedding space
```

### Key Differences

| Aspect | Current (Spiral) | New (Journey) |
|--------|------------------|---------------|
| Comparison target | Always poem A | Previous poem in chain |
| Path coherence | Decreasing (drift from origin) | Constant (each step similar) |
| User experience | "Things like A" | "A journey from A" |
| Duplicates | Never | Never (track visited set) |

### Algorithm Pseudocode

```lua
-- Journey-style similar sequence
local function generate_journey_sequence(start_poem_id, all_embeddings)
    local sequence = {start_poem_id}
    local visited = {[start_poem_id] = true}
    local current_embedding = all_embeddings[start_poem_id]

    while #sequence < #all_embeddings do
        local best_id = nil
        local best_similarity = -1

        -- Find closest UNVISITED poem to CURRENT poem
        for poem_id, embedding in pairs(all_embeddings) do
            if not visited[poem_id] then
                local sim = cosine_similarity(current_embedding, embedding)
                if sim > best_similarity then
                    best_similarity = sim
                    best_id = poem_id
                end
            end
        end

        if best_id then
            table.insert(sequence, best_id)
            visited[best_id] = true
            current_embedding = all_embeddings[best_id]  -- Update current!
        else
            break
        end
    end

    return sequence
end
```

### Computational Complexity

- **Per poem**: O(n²) comparisons (same as current, but different pattern)
- **Optimization**: Can reuse the pre-computation infrastructure from diversity cache
- **Cache file**: `assets/embeddings/EmbeddingGemma_latest/journey_cache.json`

### Expected User Experience

The journey-style path will feel more like "reading a book" where each page naturally leads to the next, rather than "browsing a catalog" where items are sorted by relevance to a query.

## Suggested Implementation Steps

### Step 1: Create Journey Sequence Generator
- [ ] Add `generate_journey_sequence()` function to similarity engine
- [ ] Reuse incremental centroid optimization (track current, not origin)
- [ ] Add visited set to prevent duplicates

### Step 2: Create Pre-computation Script
- [ ] Create `scripts/precompute-journey-sequences`
- [ ] Mirror structure of `scripts/precompute-diversity-sequences`
- [ ] Output to `journey_cache.json`

### Step 3: Integrate into HTML Generation
- [ ] Add "journey" mode alongside "similar" and "different"
- [ ] Option A: Replace current similar behavior
- [ ] Option B: Add as third navigation mode (`journey/XXX.html`)

### Step 4: Update Navigation Links
- [ ] Add journey link to poem header if implemented as third mode
- [ ] Or update existing similar links to use journey algorithm

### Step 5: Update Documentation
- [ ] Update `docs/data-flow-architecture.md`
- [ ] Update explore.html with journey explanation

## Design Decision Required

**Question**: Should journey-style replace the current similar algorithm, or be added as a third navigation mode?

**Option A - Replace**: Simpler, fewer pages, but loses "spiral" option
**Option B - Add Third Mode**: More choice for users, but 50% more HTML pages

Recommendation: Start with Option A (replace) since the journey provides strictly better exploration. The spiral pattern is less useful for discovery.

## Related Issues

- **Issue 9-003**: Centroid optimization (reusable techniques)
- **Issue 8-002**: Multi-threaded HTML generation (parallel pre-computation)
- **Issue 11-002**: Maze-based exploration (complementary feature)

## Files to Modify

- `src/similarity-engine.lua` (add journey algorithm)
- `scripts/precompute-diversity-sequences` (template for journey version)
- `src/flat-html-generator.lua` (if replacing similar mode)

---

**Phase**: 11 (Advanced Exploration)

**Priority**: Medium (enhancement, not blocker)

**Created**: 2025-12-25

**Status**: Open
