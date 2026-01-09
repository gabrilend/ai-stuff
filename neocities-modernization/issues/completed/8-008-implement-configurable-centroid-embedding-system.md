# Issue 8-008: Implement Configurable Centroid Embedding System

## Status
- **Phase**: 8
- **Priority**: Medium
- **Type**: Feature Enhancement
- **Created**: 2025-12-16

## Current Behavior

The current similarity/diversity exploration system uses single poem embeddings as starting points:
- `similar/XXX.html` pages rank all poems by similarity to poem XXX
- `different/XXX.html` pages rank all poems by maximum diversity from poem XXX
- The starting point is always a single poem's embedding vector

Users cannot define custom "themes" or "contexts" by combining multiple source texts and keywords into a centroid that represents a conceptual cluster.

## Intended Behavior

### 1. JSON Configuration File for Centroid Definitions

Create a configuration file (`assets/centroids.json`) that allows users to define named centroids using **source files** and **keywords**:

```json
{
  "centroids": [
    {
      "name": "philosophical-musings",
      "description": "Poems exploring existential and philosophical themes",
      "source_files": [
        "/absolute/path/to/poem1.txt",
        "/absolute/path/to/poem2.txt",
        "/absolute/path/to/philosophy-notes.md"
      ],
      "keywords": [
        "existentialism",
        "meaning of life",
        "consciousness",
        "free will"
      ],
      "output_slug": "philosophy"
    },
    {
      "name": "technical-thoughts",
      "description": "Programming and technology related content",
      "source_files": [
        "/path/to/code-thoughts.txt",
        "/path/to/tech-musings.txt"
      ],
      "keywords": [
        "programming",
        "systems design",
        "abstraction",
        "algorithms"
      ],
      "output_slug": "tech"
    }
  ]
}
```

### 2. Text-Based Centroid Generation

For each defined centroid, the system:

1. **Load source files** - Read content from all specified absolute file paths
2. **Concatenate content** - Join all file contents with newline separators
3. **Append keywords** - Add keyword/prompt text at the end (newline separated)
4. **Generate embedding** - Send concatenated text to embedding model

### 3. Recursive Chunking for Long Content

If the concatenated text exceeds the embedding model's context window:

```
┌─────────────────────────────────────────────────────────────┐
│  Original concatenated text (too long for embedding model)  │
└─────────────────────────────────────────────────────────────┘
                            ↓
              Split in half, try each chunk
                            ↓
        ┌───────────────┐       ┌───────────────┐
        │   Chunk A     │       │   Chunk B     │
        │ (still long?) │       │ (still long?) │
        └───────────────┘       └───────────────┘
              ↓                       ↓
         Split again              Split again
              ↓                       ↓
      ┌─────┐ ┌─────┐          ┌─────┐ ┌─────┐
      │ A1  │ │ A2  │          │ B1  │ │ B2  │
      └─────┘ └─────┘          └─────┘ └─────┘
              ↓                       ↓
         Embed each              Embed each
              ↓                       ↓
        [vec_A1, vec_A2]       [vec_B1, vec_B2]
                            ↓
              Combine all embeddings via centroid
                            ↓
                    Ultra-Centroid Vector
```

**Key constraint**: Each split must preserve complete poems/sections - never split mid-poem.

### 4. Ultra-Centroid Computation

Once all chunks are embedded:
- Collect all chunk embedding vectors
- Compute arithmetic mean (centroid) of all vectors
- Normalize to unit length
- Use this "ultra-centroid" for similarity/diversity ranking

### 5. Centroid-Based Exploration Pages

Generate HTML pages:
- `centroid/philosophy-similar.html` - All poems ranked by similarity to centroid
- `centroid/philosophy-different.html` - All poems ranked by diversity from centroid

## Suggested Implementation Steps

### Phase A: Core Infrastructure
1. [ ] Create `assets/centroids.json` schema and example file
2. [ ] Implement `scripts/generate-centroid-embeddings`:
   - Parse centroid config JSON
   - Load and validate source files (check paths exist)
   - Concatenate file contents + keywords
   - Implement recursive chunking algorithm
   - Call embedding API for each chunk
   - Compute ultra-centroid from chunk embeddings
   - Cache computed centroids to JSON file
3. [ ] Add validation:
   - Source files exist and are readable
   - Keywords are non-empty strings
   - Output slugs are URL-safe

### Phase B: Chunking Algorithm
4. [ ] Implement smart text splitting:
   - Try to embed full concatenated text
   - If too long, split at paragraph/section boundaries
   - Recursively split until chunks fit model context
   - Track which chunks belong to which poems (for debugging)
5. [ ] Handle edge cases:
   - Single poem that's too long (split at paragraph breaks)
   - Very short content (no chunking needed)
   - Empty files (skip with warning)

### Phase C: Static Generation
6. [ ] Extend `flat-html-generator.lua` to read cached centroids
7. [ ] Generate centroid-based similarity pages
8. [ ] Generate centroid-based diversity pages
9. [ ] Add centroid pages to explore.html navigation

## Technical Notes

### Concatenation Format
```
[Contents of file 1]

[Contents of file 2]

[Contents of file 3]

[Keyword 1]
[Keyword 2]
[Keyword 3]
```

### Recursive Chunking Algorithm
```lua
function generate_embedding_with_chunking(text, max_retries)
    -- Try to embed the full text
    local success, embedding = try_embed(text)
    if success then
        return {embedding}
    end

    -- Text too long - split in half at a safe boundary
    local midpoint = find_safe_split_point(text, #text / 2)
    local chunk_a = text:sub(1, midpoint)
    local chunk_b = text:sub(midpoint + 1)

    -- Recursively process each chunk
    local embeddings_a = generate_embedding_with_chunking(chunk_a, max_retries)
    local embeddings_b = generate_embedding_with_chunking(chunk_b, max_retries)

    -- Combine all embeddings
    local all_embeddings = {}
    for _, e in ipairs(embeddings_a) do table.insert(all_embeddings, e) end
    for _, e in ipairs(embeddings_b) do table.insert(all_embeddings, e) end

    return all_embeddings
end

function find_safe_split_point(text, target_pos)
    -- Find nearest paragraph break (double newline) to target position
    -- Never split in the middle of a poem/section
    local para_break = text:find("\n\n", target_pos - 500)
    if para_break and para_break < target_pos + 500 then
        return para_break + 1
    end
    -- Fallback to single newline
    local line_break = text:find("\n", target_pos)
    return line_break or target_pos
end
```

### Ultra-Centroid Calculation
```lua
function calculate_ultra_centroid(chunk_embeddings)
    local dim = #chunk_embeddings[1]
    local centroid = {}

    -- Initialize with zeros
    for i = 1, dim do centroid[i] = 0 end

    -- Sum all chunk embeddings
    for _, embedding in ipairs(chunk_embeddings) do
        for i = 1, dim do
            centroid[i] = centroid[i] + embedding[i]
        end
    end

    -- Divide by count (mean)
    local count = #chunk_embeddings
    for i = 1, dim do
        centroid[i] = centroid[i] / count
    end

    -- Normalize to unit length
    local magnitude = 0
    for i = 1, dim do
        magnitude = magnitude + centroid[i] * centroid[i]
    end
    magnitude = math.sqrt(magnitude)

    for i = 1, dim do
        centroid[i] = centroid[i] / magnitude
    end

    return centroid
end
```

### Similarity to Centroid
Uses the same cosine similarity metric as poem-to-poem similarity:
```
similarity(poem, centroid) = dot(poem_embedding, centroid) / (||poem|| * ||centroid||)
```

### Scope Clarification
**This feature only creates initial centroid vectors as new exploration starting points.**

It does NOT modify:
- Existing poem embeddings
- Existing similarity matrix
- Existing `similar/XXX.html` or `different/XXX.html` pages
- The similarity/diversity ranking algorithms

The centroid is simply another embedding vector that serves as an anchor point for exploration, computed from user-defined source texts rather than a single poem.

## Related Documents
- `src/flat-html-generator.lua` - Main HTML generation system
- `assets/embeddings/EmbeddingGemma_latest/embeddings.json` - Poem embeddings
- `scripts/generate-embeddings` - Existing embedding generation script

## Acceptance Criteria
- [x] Users can define centroids via JSON config with source files and keywords
- [x] System reads and concatenates specified source files
- [x] Keywords are appended to concatenated content
- [x] Long content is recursively chunked at safe boundaries
- [x] Each chunk is embedded separately
- [x] Chunk embeddings are combined into ultra-centroid
- [x] Static HTML pages generated for each centroid
- [x] Centroid pages show all poems ranked by similarity/diversity

---

## Implementation Notes (2025-12-23)

### Files Created

| File | Purpose |
|------|---------|
| `assets/centroids.json` | Configuration file with 5 example moods |
| `src/centroid-generator.lua` | Generates centroid embeddings from config |
| `src/centroid-html-generator.lua` | Generates HTML pages from centroids |
| `assets/embeddings/EmbeddingGemma_latest/centroids.json` | Generated centroid embeddings |
| `output/centroid/*.html` | Generated exploration pages (11 files) |

### Example Moods Defined

1. **melancholy** - Sad, reflective, introspective moods
2. **wonder** - Awe, curiosity, the vastness of existence
3. **rage** - Anger, frustration, righteous fury
4. **tenderness** - Gentle love, care, softness between beings
5. **absurdity** - The strange, surreal, and darkly comic

### Usage

```bash
# Generate centroid embeddings (requires Ollama running)
lua src/centroid-generator.lua

# Generate HTML pages from centroids
lua src/centroid-html-generator.lua
```

### Output Structure

```
output/centroid/
├── index.html              # Mood selection page
├── melancholy-similar.html # Poems similar to this mood
├── melancholy-different.html
├── wonder-similar.html
├── wonder-different.html
├── rage-similar.html
├── rage-different.html
├── tenderness-similar.html
├── tenderness-different.html
├── absurd-similar.html
└── absurd-different.html
```

### Technical Notes

- Embeddings array format required a lookup table conversion (embeddings stored as array, not object)
- Model storage name uses `EmbeddingGemma_latest` to match existing directory
- Recursive chunking implemented but not triggered for short keyword-only centroids
- Cosine similarity calculated identically to poem-to-poem similarity

### Status

**COMPLETED** - All acceptance criteria met. Ready for integration into main pipeline.
