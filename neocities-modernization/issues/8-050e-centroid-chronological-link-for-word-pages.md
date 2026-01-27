# Issue 8-050e: Add Centroid-Based Chronological Link to Word Pages

## Priority
Medium

## Current Behavior

Each word-cloud similarity page (`output/wordcloud/{word}.html`) has a header with two navigation links:

```html
<p>
    <a href="...output/wordcloud.html">Back to Word Cloud</a> |
    <a href="...output/chronological/index.html">Chronological</a>
</p>
```

Two problems:

1. The "Chronological" link always points to `chronological/index.html` (the first page). It does not consider which section of the timeline is most relevant to the word being explored.

2. There is no link to `main.html` (the site's main navigation page), so users must navigate back to the word cloud first and then find their way to main.

## Intended Behavior

### 1. Centroid-based chronological link

Replace the generic "Chronological" link with one that targets the **correct chronological page and anchor**. The target is determined by:

1. For a word like "silence", the page shows (e.g.) 50 poems from the balanced color selection
2. Compute the centroid (average embedding) of those 50 poems
3. Find which poem in the entire chronological ordering is closest to that centroid
4. Link to that poem's anchor in the correct paginated chronological page: `chronological/XX.html#poem-{category}-{id}`

### Why this is useful

The centroid of the selected poems represents the "semantic center" of the word's poem cluster. The chronological poem closest to this centroid is the best single entry point into the timeline for someone exploring this word's theme. It answers: "Where in the timeline does this word's essence live?"

### 2. Main page link

Add a link to `main.html` in the header navigation, giving users a direct path back to the site's primary navigation hub without requiring intermediate steps through the word cloud.

### Visual Design

The header should include all three navigation targets:

```html
<p>
    <a href="...output/main.html">Main</a> |
    <a href="...output/wordcloud.html">Word Cloud</a> |
    <a href="...chronological/05.html#poem-notes-quiet-evening">Chronological</a>
</p>
```

The "Chronological" link text stays simple — the user doesn't need to know it's centroid-based. It just takes them to the right place in the timeline.

## Suggested Implementation Steps

### 1. Compute centroid of selected poems

After ranking and selecting the top N poems in `generate_word_html()`, compute their centroid:

```lua
-- After selecting top poems for the word page
local centroid = {}
local dim = #poem_lookup[next(poem_lookup)]  -- embedding dimension

-- Initialize centroid to zeros
for d = 1, dim do centroid[d] = 0 end

-- Sum embeddings of selected poems
local count = 0
for _, entry in ipairs(top_poems) do
    local poem_id = tostring(entry.poem.poem_index)
    local emb = poem_lookup[poem_id]
    if emb then
        for d = 1, dim do centroid[d] = centroid[d] + emb[d] end
        count = count + 1
    end
end

-- Average
if count > 0 then
    for d = 1, dim do centroid[d] = centroid[d] / count end
end
```

### 2. Find the chronological poem closest to the centroid

```lua
-- Search all poems for the one closest to the centroid
local best_poem = nil
local best_similarity = -1

for poem_id_str, poem_embedding in pairs(poem_lookup) do
    local sim = cosine_similarity(centroid, poem_embedding)
    if sim > best_similarity then
        best_similarity = sim
        best_poem = poems_by_index[tonumber(poem_id_str)]
    end
end
```

### 3. Generate the chronological anchor link

Using the same anchor ID format as the chronological pages:

```lua
-- Build anchor ID (same format as flat-html-generator.lua)
local anchor_id = string.format("poem-%s-%s",
    best_poem.category or "unknown",
    best_poem.id or 0)

-- Determine which chronological page this poem is on
-- Need: chrono_page_map[poem_index] → page number
local chrono_page = chrono_page_map[best_poem.poem_index] or "index"
local chrono_center_link = string.format(
    "%s/chronological/%s.html#%s",
    base_path, chrono_page, anchor_id)
```

### 4. Build the chronological page map

The chronological view is paginated (500 poems per page, configurable via `--chrono-per-page`). To build the mapping from poem to page:

```lua
-- Sort poems chronologically (same order as chronological generator)
local sorted_poems = {}
for _, poem in ipairs(poems_data.poems) do
    table.insert(sorted_poems, poem)
end
table.sort(sorted_poems, function(a, b)
    return (a.creation_date or "") < (b.creation_date or "")
end)

-- Map each poem_index to its chronological page
local chrono_per_page = options.chrono_per_page or 500
local chrono_page_map = {}
for i, poem in ipairs(sorted_poems) do
    local page_num = math.ceil(i / chrono_per_page)
    -- Page format: "index" for page 1, "02" for page 2, etc.
    local page_str = page_num == 1 and "index" or string.format("%02d", page_num)
    chrono_page_map[poem.poem_index] = page_str
end
```

### 5. Pass to `generate_word_page()` and render in HTML header

Add `chrono_center_link` to the page generation. The header should include
three links: Main, Word Cloud, and the centroid-targeted Chronological link.

```lua
-- In the HTML header:
table.insert(html_parts, string.format(
    '<p><a href="%s/main.html">Main</a>' ..
    ' | <a href="%s/wordcloud.html">Word Cloud</a>' ..
    ' | <a href="%s">Chronological</a></p>',
    base_path, base_path, chrono_center_link
))
```

This replaces the current two-link header (`generate-word-pages.lua:536-537`)
which only has "Back to Word Cloud" and a generic "Chronological" link.

### 6. Handle the `chrono_per_page` configuration

The chronological page size needs to be accessible in `generate-word-pages.lua`. Options:
- Read from `config.lua` (already has pagination settings)
- Accept as CLI parameter (forward from run.sh)
- Default to 500 if not available

## Validation

- Each word page header should have three links: Main, Word Cloud, and Chronological
- The "Main" link should resolve to `main.html`
- The "Chronological" link should point to a valid chronological page and anchor (e.g., `chronological/05.html#poem-notes-quiet-evening`)
- The linked poem should be semantically representative of the word's theme
- Clicking the chronological link should scroll to the correct poem in the chronological page
- For different words, the chronological links should point to different locations in the timeline
- Edge case: if all top poems are on the same chronological page, the link should point to that page

## Edge Cases

- **No poem embeddings found**: Fall back to linking to `chronological/index.html`
- **Empty top poems list**: Fall back to generic chronological link
- **Centroid poem not in chronological map**: Use closest available page
- **Single-page chronological view**: All links point to `chronological/index.html`

## Performance Notes

Computing centroids for 200 words is fast (just averaging vectors). The closest-poem search requires comparing the centroid to all ~7,800 poem embeddings per word, but since embeddings are already in memory and cosine similarity is O(d) where d=768, this adds ~200 × 7800 × 768 = ~1.2 billion FLOPs total — a few seconds on a modern CPU. No GPU needed.

## Related Documents

- Issue 8-050: Enhance Word-Cloud Semantic Similarity Pages (parent)
- Issue 8-050b: Color-Contextualized Similarity Ranking (provides the final poem list)
- Issue 8-008: Configurable Centroid Embedding System (precedent for centroid-based navigation)
- Issue 8-039: Move Chronological Files to Subdirectory (chronological URL structure)
- Issue 8-030: Add Chronological Anchor Links (anchor ID format)
- `src/generate-word-pages.lua:526-541` — Current HTML header template
- `src/flat-html-generator.lua` — Chronological page generation (pagination reference)

## Metadata

- **Status**: Open
- **Created**: 2026-01-26
- **Phase**: 8 (Website Completion)
- **Parent**: 8-050
- **Estimated Complexity**: Medium (centroid computation + chronological page mapping)
- **Dependencies**: 8-050b (final ranked poem list determines centroid)
