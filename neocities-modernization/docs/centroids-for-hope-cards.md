# Using Centroids for Hope Card Generation

**Created**: 2026-01-12
**Related Issue**: 6-012 - Implement words-pdf Styled Export System

## Overview

The centroid system (`assets/centroids.json`) provides a powerful way to seed hope card generation with specific moods or themes. Instead of selecting poems from a single anchor poem, you can create custom "hope" anchor points using keywords and source texts.

## How Centroids Work

From Issue 8-008, centroids allow you to:

1. **Define keywords** - Words/phrases added to the embedding
2. **Include source files** - Poems or text files to combine
3. **Generate custom anchor** - Creates embedding from combined content
4. **Rank poems** - All poems ranked by similarity to this centroid

## Using Centroids for Hope Cards

### Scenario: Generate "Hopeful Poems" Collection

Instead of filtering poems by keywords *after* selection, you can:
1. Define a "hopeful" centroid with positive keywords
2. Generate embedding from hopeful source material
3. Get naturally ranked poems by similarity to hope/positivity
4. Top 200 poems will be inherently hopeful!

### Example Centroid Definition

```json
{
  "name": "hope",
  "description": "Uplifting, encouraging, healing poems for hope cards",
  "source_files": [
    "/path/to/your/favorite/hopeful/poem.txt",
    "/path/to/inspirational/quote/collection.txt"
  ],
  "keywords": [
    "hope",
    "healing",
    "light at the end of the tunnel",
    "things will get better",
    "resilience",
    "growth",
    "recovery",
    "new beginnings",
    "gentle encouragement",
    "you are not alone",
    "kindness",
    "compassion",
    "tomorrow is another day",
    "this too shall pass"
  ],
  "output_slug": "hope"
}
```

## Workflow Integration

### Method 1: Use Existing Centroid Pages

If centroid pages are already generated:

```bash
# 1. Generate centroid embeddings
lua src/centroid-generator.lua

# 2. Generate centroid-based HTML pages
# (This creates centroid/hope-similar.html with top N hopeful poems)

# 3. Extract poem list from generated page
# Parse centroid/hope-similar.html to get poem IDs

# 4. Format for PDF
./scripts/export-hope-cards --from-centroid=hope --limit=200
```

### Method 2: Direct Embedding Similarity

Use the centroid embedding directly for ranking:

```lua
-- In export-hope-cards script:

-- 1. Load the "hope" centroid embedding
local hope_centroid = load_centroid("hope")

-- 2. Calculate similarity of all poems to hope centroid
local hope_scores = {}
for poem_id, poem in pairs(poems) do
    local poem_embedding = load_embedding(poem_id)
    local similarity = cosine_similarity(hope_centroid, poem_embedding)
    table.insert(hope_scores, {
        poem_id = poem_id,
        similarity = similarity
    })
end

-- 3. Sort by similarity (most hopeful first)
table.sort(hope_scores, function(a, b)
    return a.similarity > b.similarity
end)

-- 4. Take top N poems
local selected_poems = {}
for i = 1, 200 do
    local poem_id = hope_scores[i].poem_id
    table.insert(selected_poems, poems[poem_id])
end

-- 5. Format for PDF
formatter.write_to_file(selected_poems, "temp/hope-cards.txt")
```

## Advantages Over Keyword Filtering

| Approach | Accuracy | Nuance | Maintenance |
|----------|----------|---------|-------------|
| **Keyword filtering** | Medium | Low | High (update word lists) |
| **Centroid-based** | High | High | Low (define once) |

**Why centroids are better:**
- **Semantic understanding**: Captures meaning, not just word matches
- **Handles synonyms**: "healing" and "recovery" rank similarly
- **Context-aware**: "hope" in different contexts ranked appropriately
- **No false positives**: Won't include dark poems that happen to mention "hope"

## Creating Multiple Hope Card Themes

You can define multiple centroids for different moods:

```json
{
  "centroids": [
    {
      "name": "gentle-hope",
      "keywords": ["soft encouragement", "quiet strength", "you are enough"],
      "output_slug": "gentle-hope"
    },
    {
      "name": "fierce-hope",
      "keywords": ["revolution", "resistance", "we will overcome", "rising up"],
      "output_slug": "fierce-hope"
    },
    {
      "name": "quiet-comfort",
      "keywords": ["rest", "safety", "warm blanket", "tea and quiet", "sanctuary"],
      "output_slug": "comfort"
    }
  ]
}
```

Then generate different PDF collections:
- `hope-cards-gentle.pdf` - Soft, reassuring poems
- `hope-cards-fierce.pdf` - Empowering, activist poems
- `hope-cards-comfort.pdf` - Cozy, soothing poems

## Implementation in export-hope-cards

Update the export script to support centroid mode:

```lua
-- Parse CLI args
local mode = "anchor"  -- or "centroid"
local centroid_name = nil

for i = 1, #arg do
    if arg[i]:match("^--from%-centroid=") then
        mode = "centroid"
        centroid_name = arg[i]:match("^--from%-centroid=(.+)")
    end
end

-- Load poems based on mode
if mode == "centroid" then
    -- Load centroid embedding and rank all poems
    selected_poems = rank_by_centroid(centroid_name, limit)
else
    -- Original anchor-based selection
    selected_poems = rank_by_anchor(anchor_id, limit)
end
```

## Configuration File Location

Centroids are defined in:
```
/mnt/mtwo/programming/ai-stuff/neocities-modernization/assets/centroids.json
```

Generated centroid embeddings are cached at:
```
/assets/embeddings/{model}/centroids.json
```

## Example: Complete Workflow

```bash
# 1. Edit assets/centroids.json to add "hope" centroid
#    (Add keywords and optional source files)

# 2. Generate the centroid embedding
lua src/centroid-generator.lua

# 3. Export hope cards using the centroid
./scripts/export-hope-cards \
    --from-centroid=hope \
    --limit=200 \
    --output=temp/hope-cards-gentle.txt

# 4. Generate PDF
./scripts/generate-hope-card-pdf \
    temp/hope-cards-gentle.txt \
    output/hope-cards-gentle.pdf
```

## Centroid Generator Details

**Script**: `src/centroid-generator.lua`

**What it does:**
1. Reads `assets/centroids.json`
2. For each centroid:
   - Loads source files (if specified)
   - Appends keywords
   - Generates embedding via Ollama
   - Handles long text via recursive chunking
3. Saves embeddings to cache

**Usage:**
```bash
lua src/centroid-generator.lua
```

**Output:**
```
assets/embeddings/embeddinggemma_latest/centroids.json
```

## Tips for Effective Hope Card Centroids

**1. Use evocative phrases, not just single words:**
- ✅ "light at the end of the tunnel"
- ❌ "light"

**2. Include contradictions to capture complexity:**
- "sad but hopeful"
- "tired but resilient"
- "scared but brave"

**3. Reference cultural touchstones:**
- "phoenix rising from ashes"
- "winter turning to spring"
- "stars in the darkest night"

**4. Be specific about the feeling:**
- Not just "happy" but "the relief after crying"
- Not just "love" but "being held when you're scared"

**5. Test and iterate:**
- Generate test PDFs with 20 poems first
- Review if poems match intended mood
- Adjust keywords and regenerate

## Related Documentation

- **Issue 8-008**: Original centroid system implementation
- **Issue 6-012**: Hope card PDF generation
- **docs/words-pdf-integration.md**: PDF generation details

---

*"seed the space with words of grace,*
*and watch the hopeful poems embrace."*
