# Issue 8-043: Generate Semantic Word Cloud Page

## Priority
Medium

## Current Behavior

No word cloud visualization exists. The website shows poems in chronological, similarity, and diversity orderings, but lacks a high-level view of the collection's semantic content.

## Intended Behavior

A new pipeline stage generates a word cloud page (`output/wordcloud.html`) where:

1. **Word extraction**: Parse all poems from chronological.html and count word occurrences
2. **Embedding-based weighting**: Instead of using raw frequency for font size, use each word's cosine similarity to the collection's centroid embedding
3. **Visual output**: Display words with font sizes proportional to their centroid similarity (closest = largest)

### Semantic Weighting Rationale

Traditional word clouds use frequency, which surfaces common words. Our approach surfaces **thematically central** words - those whose meaning is closest to the "average meaning" of the entire poetry collection.

**Hypothesis**: Words closest to the centroid represent the collection's semantic essence - recurring themes, emotional core, and distinctive vocabulary.

### Stop Word Filtering (Critical)

**Problem**: Without filtering, function words ("the", "and", "is", "was", "however") will dominate. These words:
- Appear in virtually all training contexts
- Have semantically "neutral" embeddings (not strongly associated with any meaning)
- This neutrality places them close to any centroid by default

**Solution**: Filter stop words before analysis. After filtering, the centroid-proximate words will be genuinely thematic.

**Recommended stop word sources:**
- NLTK English stop words (179 words)
- Custom additions for this corpus if needed
- Or: Part-of-speech filtering (keep nouns, verbs, adjectives only)

## Technical Design

### Pipeline Stage

**New Stage**: Add as Stage 6.75 or Stage 10.5 (after embeddings exist, before/after HTML generation)

```bash
# In run.sh
# Stage X: Generate word cloud
if [[ "$GENERATE_WORDCLOUD" == "true" ]]; then
    echo "☁️  Stage X: Generating semantic word cloud..."
    lua src/wordcloud-generator.lua \
        --input "$OUTPUT_DIR/chronological.html" \
        --embeddings "$ASSETS_DIR/embeddings" \
        --output "$OUTPUT_DIR/wordcloud.html"
fi
```

### Algorithm

```lua
-- Pseudocode for wordcloud-generator.lua

-- 1. Extract words from all poems
local word_counts = {}
for poem in chronological_poems do
    for word in poem.content:gmatch("%w+") do
        local normalized = word:lower()
        if not stop_words[normalized] then
            word_counts[normalized] = (word_counts[normalized] or 0) + 1
        end
    end
end

-- 2. Filter by minimum frequency (reduce noise)
local MIN_OCCURRENCES = 5
local candidate_words = {}
for word, count in pairs(word_counts) do
    if count >= MIN_OCCURRENCES then
        table.insert(candidate_words, {word = word, count = count})
    end
end

-- 3. Generate embeddings for each word
--    Option A: Use Ollama to embed each word individually
--    Option B: Use pre-computed word vectors if available
local word_embeddings = {}
for _, entry in ipairs(candidate_words) do
    word_embeddings[entry.word] = generate_embedding(entry.word)
end

-- 4. Compute collection centroid
--    Option A: Average of all poem embeddings (already exists)
--    Option B: Average of all word embeddings
local centroid = load_collection_centroid()  -- From existing pipeline

-- 5. Compute similarity scores
for _, entry in ipairs(candidate_words) do
    entry.similarity = cosine_similarity(word_embeddings[entry.word], centroid)
end

-- 6. Normalize to font sizes (e.g., 12px to 72px)
local min_sim, max_sim = find_min_max(candidate_words, "similarity")
for _, entry in ipairs(candidate_words) do
    local normalized = (entry.similarity - min_sim) / (max_sim - min_sim)
    entry.font_size = 12 + (normalized * 60)  -- 12px to 72px range
end

-- 7. Generate HTML
generate_wordcloud_html(candidate_words)
```

### HTML Output Format

Since CSS is avoided, use inline `<font size="X">` tags or pixel-based sizing.

**Each word links to a similarity page** showing poems ranked by their similarity to that word:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Word Cloud - Poetry Collection</title>
    <meta charset="utf-8">
</head>
<body bgcolor="#1a1a2e" text="#ffffff">

<center>
<a href="wordcloud/silence.html"><font size="7"><b>silence</b></font></a>
<a href="wordcloud/memory.html"><font size="5">memory</font></a>
<a href="wordcloud/night.html"><font size="6"><b>night</b></font></a>
<a href="wordcloud/water.html"><font size="4">water</font></a>
<a href="wordcloud/window.html"><font size="3">window</font></a>
<!-- ... more words ... -->
</center>

</body>
</html>
```

### Word Similarity Pages

For each word in the word cloud, generate a page at `output/wordcloud/{word}.html` that:

1. **Shows the word as header**: "Poems similar to: *silence*"
2. **Ranks all poems** by cosine similarity to that word's embedding
3. **Uses existing poem display format**: Same box-drawing style as similar/different pages
4. **Pagination**: Apply same pagination strategy as similar/different pages (max 15 pages per word, 100 poems per page)

**Example**: `output/wordcloud/silence.html`
```
╔══════════════════════════════════════════════════════════════════════════════╗
║                        Poems similar to: silence                             ║
╚══════════════════════════════════════════════════════════════════════════════╝

                              --- #1 (0.847) ---
┌──────────────────────────────────────────────────────────────────────────────┐
│ the silence between us                                                       │
│ speaks louder than                                                           │
│ anything we could say                                                        │
└──────────────────────────────────────────────────────────────────────────────┘
                    │ similar │  chronological  │ different │

                              --- #2 (0.823) ---
...
```

### Directory Structure

```
output/
├── wordcloud.html              # Main word cloud page
└── wordcloud/                  # Word similarity pages
    ├── silence.html
    ├── silence-02.html         # Page 2 if paginated
    ├── memory.html
    ├── night.html
    ├── water.html
    └── ...                     # One set of pages per word
```

### Storage Consideration

With 200 words and potential pagination:
- **Minimum**: 200 files (1 page per word)
- **Maximum**: 200 × 15 = 3,000 files (if all words get max pagination)
- **Estimated size**: ~50-150 MB depending on pagination depth

This fits within the 45GB Neocities budget but should be configurable.

**Alternative**: ASCII art word cloud using character repetition or box-drawing for emphasis.

### Centroid Source Options

1. **Use existing poem centroid**: Average of all 7,797 poem embeddings (if pre-computed)
2. **Compute fresh**: Average all poem embeddings at generation time
3. **Word-only centroid**: Average of just the extracted word embeddings (different semantic space)

**Recommendation**: Use poem centroid (option 1 or 2) - this represents the true "center" of the poetic content, not just vocabulary.

## Configuration

Add to `config/input-sources.json` or unified config:

```lua
wordcloud = {
    enabled = true,
    output_file = "wordcloud.html",
    min_occurrences = 5,        -- Minimum times a word must appear
    max_words = 200,            -- Maximum words to display
    font_size_min = 12,         -- Smallest font (px)
    font_size_max = 72,         -- Largest font (px)
    stop_words_file = "config/stop-words.txt",  -- Optional custom list
    use_default_stop_words = true
}
```

## Stop Words File

Create `config/stop-words.txt` with common English function words:

```
a
an
the
and
or
but
is
are
was
were
be
been
being
have
has
had
do
does
did
will
would
could
should
may
might
must
shall
can
...
```

Or use programmatic list from a standard source.

## Suggested Implementation Steps

1. **Create stop words list**:
   - Download or create `config/stop-words.txt`
   - Include ~200 common English function words

2. **Create `src/wordcloud-generator.lua`**:
   - Word extraction from poem content
   - Stop word filtering
   - Frequency counting and thresholding

3. **Add embedding generation for words**:
   - Batch embed candidate words via Ollama
   - Cache word embeddings to `assets/word-embeddings.json`
   - Skip re-embedding for cached words

4. **Compute centroid similarity**:
   - Load collection centroid (or compute from poem embeddings)
   - Calculate cosine similarity for each word

5. **Generate main word cloud HTML**:
   - Map similarity to font size
   - Each word is a link to `wordcloud/{word}.html`
   - Render word cloud (centered layout)

6. **Generate word similarity pages**:
   - For each word in the cloud:
     - Compute similarity between word embedding and all poem embeddings
     - Sort poems by descending similarity
     - Generate paginated HTML pages in `output/wordcloud/`
   - Reuse existing poem formatting functions from `flat-html-generator.lua`
   - Apply pagination config (max pages, poems per page)

7. **Add navigation to word pages**:
   - Link back to main word cloud
   - Prev/next pagination links
   - Links to poem's similar/different/chronological pages

8. **Integrate into run.sh**:
   - Add `--generate-wordcloud` flag
   - Create `output/wordcloud/` directory
   - Add to `--full` stage list (expensive due to page generation)

9. **Test and validate**:
   - Verify stop words are filtered
   - Check that thematic words (not function words) are largest
   - Click through word links to verify similarity pages
   - Verify pagination works correctly

## Expected Results

**Words likely to be LARGE** (close to centroid, after filtering):
- Recurring themes: "night", "silence", "memory", "water", "light"
- Emotional core: "love", "loss", "time", "dream"
- Distinctive vocabulary unique to this collection

**Words likely to be SMALL** (distant from centroid):
- Rare or unusual words
- Words that appear in only specific contexts
- Technical or specialized vocabulary

## Research Value

This word cloud serves as a **semantic fingerprint** of the poetry collection. It answers: "What is this collection fundamentally about?" not by counting, but by measuring meaning.

Comparing word clouds across different poetry collections could reveal distinctive thematic differences - a potential future feature.

## Related Documents

- `src/centroid-generator.lua` - Existing centroid computation
- `assets/embeddings/` - Pre-computed poem embeddings
- `config/input-sources.json` - Configuration location
- `run.sh` - Pipeline orchestration

## Implementation Progress

### 2026-01-21: MVP Implemented (Frequency-Based)

Implemented the first phase of the word cloud feature using frequency-based sizing rather than embedding-based weighting. This provides immediate value while leaving semantic weighting as a future enhancement.

**Files Created:**

1. **`config/stop-words.txt`** - 271 stop words organized by category:
   - Anonymization artifacts (`user`, `users`)
   - Contraction fragments (`don`, `doesn`, `didn`, etc.)
   - URL/technical artifacts (`https`, `http`, `www`, `com`, etc.)
   - Articles, pronouns, prepositions, conjunctions
   - Auxiliary verbs, common verbs, common adverbs
   - Question words, other common function words

2. **`src/wordcloud-generator.lua`** - Word cloud generator:
   - Loads stop words from configurable file
   - Extracts words from all poems (alphanumeric sequences)
   - Filters by minimum length (default: 3 chars)
   - Filters by minimum occurrences (default: 5)
   - Calculates font sizes (1-7) based on frequency normalization
   - Fisher-Yates shuffles words for visual variety
   - Generates CSS-free HTML using `<font size="X">` tags
   - Reads configuration from `config/input-sources.json`

**Configuration Added to `config/input-sources.json`:**

```json
"word_cloud": {
    "enabled": true,
    "stop_words_file": "config/stop-words.txt",
    "output_file": "wordcloud.html",
    "min_occurrences": 5,
    "max_words": 200,
    "min_word_length": 3,
    "font_size_min": 1,
    "font_size_max": 7
}
```

**Configuration Added to Issue 10-003 (Config Consolidation):**

Added `word_cloud` section with vimfolds to the proposed Lua config structure.

**Output Statistics:**
- 222,784 total words extracted from 7,844 poems
- 23,455 unique words after stop word filtering
- 200 words displayed (configurable `max_words`)
- Output: `output/wordcloud.html`

**Deferred to Future Enhancement:**
- Embedding-based weighting (word similarity to centroid)
- Individual word similarity pages (`wordcloud/{word}.html`)
- Navigation links on word cloud words
- Pagination for word pages

The frequency-based word cloud provides immediate insight into the collection's vocabulary. Embedding-based semantic weighting can be added as a follow-up issue when more sophisticated thematic analysis is desired.

## Metadata

- **Status**: ✅ Complete (MVP)
- **Created**: 2026-01-20
- **Completed**: 2026-01-21
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Medium (word extraction easy, embedding integration moderate)
- **Dependencies**: Requires embedding infrastructure (Stage 3) - for future semantic version
- **Affects**: New output file, new pipeline stage
