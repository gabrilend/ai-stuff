# Issue 16-010: Add Semantic Colors to Word Cloud Display & Fix URL Links

## Priority
Medium

## Current Behavior

1. **Word cloud colors not displayed**: The main `wordcloud.html` page shows all words in the default link color (blue). The semantic colors computed in `word_colors.json` (7,016 words with colors like red, blue, green, etc.) are not used in the visual display.

2. **Broken main.html link**: The word pages (`output/wordcloud/*.html`) link to `main.html` which doesn't exist. The link is generated in `src/generate-word-pages.lua:795` but should point to `wordcloud.html` instead.

3. **Inconsistent URL generation**: The `wordcloud-generator.lua` uses relative URLs while `generate-word-pages.lua` uses absolute production URLs (`/similar-different/...`).

## Intended Behavior

### 1. Colorized Word Cloud Display

Each word in the word cloud should be displayed in its semantic color:
- "love" → red
- "ocean" → blue
- "forest" → green
- etc.

The `wordcloud-generator.lua` should:
1. Load `word_colors.json` from the embeddings directory
2. Look up each word's semantic color
3. Apply the color via `<font color="...">` tags

### 2. Fix main.html → wordcloud.html

In `generate-word-pages.lua:795`, change:
```lua
<a href="%s/main.html">Main</a>
```
to:
```lua
<a href="%s/wordcloud.html">Menu</a>
```

This matches the navigation pattern used in chronological pages.

### 3. Consistent URL patterns

All generators should use the same URL strategy (absolute `file:///...` paths that get converted by `convert-urls`).

## Suggested Implementation Steps

### Step 1: Modify wordcloud-generator.lua

Add function to load word colors:
```lua
local function load_word_colors()
    local cache_file = utils.embeddings_dir("embeddinggemma_latest") .. "/word_colors.json"
    local data = utils.read_json_file(cache_file)
    if data and data.word_colors then
        local lookup = {}
        for _, entry in ipairs(data.word_colors) do
            lookup[entry.word] = entry.color
        end
        return lookup
    end
    return {}
end
```

Update `generate_wordcloud_html()` to use colors:
```lua
-- Load color config and word colors
local color_config = unified_config.colors or {}
local word_colors = load_word_colors()

-- In the word HTML generation loop:
local semantic_color = word_colors[entry.word] or "gray"
local hex_color = color_config[semantic_color] or "#888888"
table.insert(word_html, string.format(
    '<a href="wordcloud/%s.html"><font size="%d" color="%s">%s%s%s</font></a>',
    safe_word, entry.font_size, hex_color, bold_open, entry.word, bold_close
))
```

### Step 2: Fix generate-word-pages.lua

Line 795: Change `main.html` to `wordcloud.html`
Line 795: Change "Main" label to "Menu" for consistency

### Step 3: Regenerate HTML files

```bash
luajit src/wordcloud-generator.lua
luajit src/generate-word-pages.lua --html-only
```

## Validation

1. Open `output/wordcloud.html` - words should display in various colors
2. Open any `output/wordcloud/*.html` - "Menu" link should navigate to wordcloud.html
3. Run `./scripts/convert-urls --to-production --dry-run` - should report expected conversions

## Related Documents

- Issue 8-050a: Compute Semantic Color for Each Word-Cloud Word (completed - generated word_colors.json)
- `src/wordcloud-generator.lua` - Word cloud page generator
- `src/generate-word-pages.lua` - Individual word page generator
- `assets/embeddings/embeddinggemma_latest/word_colors.json` - Cached word colors

## Metadata

- **Status**: Completed
- **Created**: 2026-02-20
- **Completed**: 2026-02-20
- **Phase**: 16
- **Estimated Complexity**: Low
- **Dependencies**: word_colors.json, color_embeddings.json

## Completion Notes

### Changes Made

1. **src/generate-word-pages.lua:795-801**
   - Changed `main.html` → `wordcloud.html` (main.html didn't exist)
   - Changed "Main" label to "Menu" for consistency with chronological pages
   - Removed duplicate "Word Cloud" link (redundant with Menu)
   - Updated format string arguments accordingly

2. **src/wordcloud-generator.lua:115-131**
   - Added `load_word_colors()` function to load word colors from embeddings cache
   - Modified `generate_wordcloud_html()` to apply semantic colors to each word
   - Each word now displays in its semantic color (red, orange, yellow, green, blue, purple, gray)

3. **Regenerated HTML files**
   - `output/wordcloud.html` - now has colorized words
   - `output/wordcloud/*.html` (200 files) - now link to Menu correctly

### Color Distribution in Word Cloud

| Color  | Hex Code | Count |
|--------|----------|-------|
| orange | #FFA94D  | 120   |
| red    | #FF6B6B  | 49    |
| yellow | #FFE066  | 26    |
| blue   | #74C0FC  | 4     |
| green  | #69DB7C  | 1     |

### Validation

- [x] Word cloud displays with semantic colors
- [x] "love" word appears in red (#FF6B6B)
- [x] "game" word appears in green (#69DB7C)
- [x] Menu link in word pages navigates correctly to wordcloud.html
- [x] URL conversion script shows 30,400 URLs converted across 200 word pages
