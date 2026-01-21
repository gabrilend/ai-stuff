# Issue 8-046: Create Menu Navigation Page

## Priority
Medium

## Current Behavior

The "How to explore this collection" link in the HTML header points to `explore.html`, a page that provides general instructions for navigating the poetry collection.

**Current header:**
```html
<p><a href="explore.html">How to explore this collection</a></p>
```

This is informational but doesn't provide direct navigation to content.

## Intended Behavior

Replace the "How to explore" link with a "Menu" link pointing to the word cloud page (`wordcloud.html`), which will serve as the main navigation hub.

**New header:**
```html
<p><a href="wordcloud.html">Menu</a></p>
```

### Word Cloud as Menu

The word cloud page should evolve into a comprehensive menu with:

1. **Word Cloud Section** (existing): Visual exploration via word frequency/semantics
2. **Poem Index Section** (new): Complete list of all poems organized by category, each linking to their chronological position

### Poem Index Design

Each poem should appear as a link that takes the user to the correct chronological page and scrolls to that poem's anchor:

```
═══════════════════════════════════════════════════════════════════════════════════

                                  📜 Poem Index

══════════════════ fediverse (6,435 poems) ═══════════════════════════════════════

  1 ─ 2020-01-15 ─ "the first line of content..."
  2 ─ 2020-01-16 ─ "another poem begins here..."
  ...

══════════════════ notes (892 poems) ══════════════════════════════════════════════

  what-a-lame-movie ─ "this movie was terrible..."
  philosophical-problems ─ "what if reality..."
  ...

══════════════════ messages (408 poems) ═══════════════════════════════════════════

  1 ─ "hey I was thinking..."
  2 ─ "did you see the news..."
  ...

══════════════════ bluesky (109 poems) ════════════════════════════════════════════

  1 ─ 2024-03-01 ─ "hello bluesky..."
  ...
```

Each entry links to: `chronological/NN.html#poem-{category}-{id}`

### Technical Requirements

1. **Link Format**: Same as similar/different page chronological links
   - Must account for pagination (use `chrono_map` page_number)
   - Format: `chronological/{page}.html#poem-{category}-{id}`

2. **Preview Text**: First ~40 characters of poem content (truncated with `...`)

3. **Date Display**: Show creation date where available (ISO format or relative)

4. **Category Sections**: Group poems by source category

## Suggested Implementation Steps

### Step 1: Rename "How to explore" → "Menu"

Update header generation in `src/flat-html-generator.lua`:
- Lines 2260, 2281: Change link text and href
- Point to `wordcloud.html` instead of `explore.html`

### Step 2: Add Poem Index to Word Cloud Page

Extend `src/wordcloud-generator.lua` to include:
1. Load `chrono_map` for pagination-aware links
2. Group poems by category
3. Generate index section with links

Or create separate function and call from word cloud generator.

### Step 3: Handle Link Generation

Reuse link generation logic from similar/different pages:
```lua
local function generate_chrono_link(poem, chrono_map)
    local anchor_id = get_poem_anchor_id(poem)
    local chrono_info = chrono_map[poem.poem_index]
    if chrono_paginated then
        return string.format("chronological/%02d.html#%s", chrono_info.page_number, anchor_id)
    else
        return string.format("chronological/index.html#%s", anchor_id)
    end
end
```

### Step 4: Preview Text Extraction

```lua
local function get_preview_text(content, max_len)
    local clean = content:gsub("\n", " "):gsub("%s+", " ")
    if #clean > max_len then
        return clean:sub(1, max_len - 3) .. "..."
    end
    return clean
end
```

### Step 5: Delete or Redirect explore.html

Either:
- Remove `explore.html` generation entirely
- Or make `explore.html` redirect to `wordcloud.html`

## Files to Modify

| File | Changes |
|------|---------|
| `src/flat-html-generator.lua` | Change header links (lines 2260, 2281) |
| `src/wordcloud-generator.lua` | Add poem index section |
| `run.sh` (optional) | Remove explore.html generation if applicable |

## Related Documents

- `src/wordcloud-generator.lua` - Word cloud generation
- `src/flat-html-generator.lua` - Header generation, chrono_map
- `issues/8-043-generate-semantic-word-cloud-page.md` - Word cloud feature
- `issues/completed/phase-8/8-030-add-chronological-anchor-links.md` - Anchor link format

## Future Enhancements

- Alphabetical sorting option within categories
- Search/filter functionality (would require JavaScript)
- Collapsible category sections
- Jump-to-letter navigation for large categories

## Metadata

- **Status**: Open
- **Created**: 2026-01-21
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Medium
- **Dependencies**: 8-043 (word cloud), 8-030 (anchor links)
- **Affects**: Navigation, wordcloud.html, header links
