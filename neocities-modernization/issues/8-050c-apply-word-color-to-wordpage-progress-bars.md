# Issue 8-050c: Apply Word Color to All Progress Bars on Word Pages

## Priority
Medium

## Current Behavior

In `src/generate-word-pages.lua`, the `format_poem_for_word_page()` function (line 274) colors each poem's progress bar using that **poem's individual semantic color**:

```lua
-- Current: each poem gets its own color
local poem_color_data = poem_colors and poem_colors[poem_idx]
local semantic_color = poem_color_data and poem_color_data.color or "gray"
local hex_color = color_config and color_config[semantic_color] or "#888888"
```

This means a word page for "silence" might show progress bars in red, blue, green, purple, orange — whatever each individual poem's semantic color happens to be. The result is visually chaotic and does not communicate the word's thematic identity.

## Intended Behavior

All progress bars on a word page should use the **word's semantic color** (computed in 8-050a), not each poem's individual color. This creates a unified visual identity for the word page:

- "silence" page → all progress bars in blue
- "fire" page → all progress bars in red
- "forest" page → all progress bars in green

### Scope of Color Change

The word's color should replace the poem's color in these visual elements:
1. **Top progress bar** (`═` colored section)
2. **Bottom progress bar** (`═` colored section, junction characters `╧`)
3. **Golden poem corners** (`╔`, `╚`, `║`, `╟`)
4. **Navigation box characters** (when inside the colored progress region)

All of these are currently driven by `hex_color` in `format_poem_for_word_page()`. Changing the color source at the top of that function propagates to all elements.

## Suggested Implementation Steps

### 1. Add `word_color` parameter to `format_poem_for_word_page()`

```lua
-- Updated function signature:
local function format_poem_for_word_page(poem, rank, similarity, poem_colors, color_config, chrono_map, word_color)
```

### 2. Use word color instead of poem color

Replace the per-poem color lookup (lines 277-280):

```lua
-- Before (per-poem):
local poem_color_data = poem_colors and poem_colors[poem_idx]
local semantic_color = poem_color_data and poem_color_data.color or "gray"
local hex_color = color_config and color_config[semantic_color] or "#888888"

-- After (per-word):
local semantic_color = word_color or "gray"
local hex_color = color_config and color_config[semantic_color] or "#888888"
```

### 3. Pass word color through `generate_word_page()`

Update `generate_word_page()` signature (line 511) to accept and forward `word_color`:

```lua
local function generate_word_page(word, ranked_poems, output_dir, poems_per_page, poem_colors, color_config, chrono_map, word_color)
    -- ...
    for i, entry in ipairs(top_poems) do
        local formatted = format_poem_for_word_page(
            entry.poem, i, entry.similarity,
            poem_colors, color_config, chrono_map,
            word_color  -- NEW: pass word color
        )
    end
end
```

### 4. Load word colors in `generate_word_html()` and pass through

```lua
-- In generate_word_html(), after loading word_colors.json (from 8-050a):
local word_color_map = {}  -- word -> color name
for _, entry in ipairs(word_colors_data.word_colors) do
    word_color_map[entry.word] = entry.color
end

-- In the per-word loop:
local word_color = word_color_map[word] or "gray"
generate_word_page(word, ranked_poems, output_dir, poems_per_page,
    poem_colors, color_config, chrono_map, word_color)
```

### 5. Consider updating the page header to show the word's color

Optionally, use the word's hex color in the `<h1>` tag:

```html
<h1>Poems similar to: <i><font color="#3c78dc">silence</font></i></h1>
```

This reinforces the color identity at the page level.

## Design Decision: Unified vs. Per-Poem Color

Issue 8-050b introduces a balanced round-robin selection algorithm that intentionally
places poems from ALL 7 semantic colors on each word page. This raises a design question:

### Option 1: Word color for all bars (original design)
- All progress bars use the word's semantic color (e.g., all blue for "silence")
- Unified visual identity, feels like a "themed gallery"
- Hides the intentional color diversity from the balanced selection

### Option 2: Per-poem color for bars (fix the current bug)
- Each poem's progress bar uses that poem's own semantic color
- Reveals the rainbow created by the balanced selection algorithm
- The page header / word title still uses the word's color for identity
- Requires fixing the current bug where `poem_colors` may not load correctly

### Option 3: Hybrid approach
- Word's color for: page header `<h1>`, page border elements, section dividers
- Poem's color for: progress bars, navigation box characters, golden corners
- Best of both worlds: page has a color identity, but individual poems keep their character

**Recommendation**: Option 2 or 3, since 8-050b's balanced selection was specifically
designed to ensure color diversity. Hiding that diversity behind a uniform color would
defeat the purpose of the algorithm. The word's color can still appear in the header.

**Implementation note**: If Option 2 is chosen, the primary task becomes ensuring
`poem_colors` loads correctly (it may currently be failing, explaining the gray bars).
If Option 3 is chosen, the `word_color` parameter is used for header elements while
`poem_colors[poem_idx]` continues to drive progress bars.

## Validation

- Progress bars should display visible, non-gray colors
- If Option 2: each poem's bar should match its semantic color from `poem_colors.json`
- If Option 3: page header uses word color, bars use per-poem colors
- Golden poems should still render correctly (corners, side borders)
- Navigation box colorization should still work (positions relative to progress)
- Compare before/after: bars should be colorful regardless of which option is chosen

## Edge Cases

- **poem_colors fails to load**: Error and halt (prefer breakage over silent gray fallback, per project conventions)
- **Word with no color assignment**: Fall back to "gray" for header elements
- **Poem with no color assignment**: Fall back to "gray" for that poem's bars only

## Related Documents

- Issue 8-050: Enhance Word-Cloud Semantic Similarity Pages (parent)
- Issue 8-050a: Compute Semantic Color for Each Word-Cloud Word (dependency)
- `src/generate-word-pages.lua:270-504` — `format_poem_for_word_page()` function
- `src/flat-html-generator.lua:806-1033` — Reference: `generate_progress_dashes()` for similar/different pages
- Issue 8-035: Colorize Nav Boxes According to Progress Bar (precedent)

## Metadata

- **Status**: Open
- **Created**: 2026-01-26
- **Phase**: 8 (Website Completion)
- **Parent**: 8-050
- **Estimated Complexity**: Low (change color source at one point, propagates everywhere)
- **Dependencies**: 8-050a (word colors must exist)
