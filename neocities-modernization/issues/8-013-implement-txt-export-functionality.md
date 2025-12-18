# 8-013: Implement TXT Export Functionality

## Status
- **Phase**: 8
- **Priority**: High
- **Type**: Feature Implementation
- **Blocks**: 8-012 (Paginated Similarity Chapters)

## Blocking Relationship

Issue 8-012 (Paginated Similarity Chapters) **cannot be completed** until this issue is resolved.

The pagination system requires working .txt exports before it can be finalized.

---

## Current Behavior

Issue 5-013 documented .txt export functionality as "completed", but the current state needs verification:

1. Does `flat-html-generator.lua` actually generate .txt files?
2. Are images properly converted to alt-text in .txt output?
3. Is the 80-character width formatting correct?
4. Are .txt files generated alongside .html files?

## Intended Behavior

Generate `.txt` exports for each poem's similarity/diversity/chronological ordering:

```
similar/0068.txt      ← All ~7000 poems sorted by similarity to poem 68
different/0068.txt    ← All ~7000 poems sorted by diversity from poem 68
chronological.txt     ← All ~7000 poems in chronological order
```

### TXT Format Requirements

1. **80-character width** - All lines wrap at 80 characters
2. **Images → Alt-text** - Replace `<img>` tags with `[Image: alt-text]`
3. **No HTML tags** - Pure plain text
4. **Poem separators** - Clear visual separation between poems
5. **Header** - File header indicating sort order and source poem

### Example TXT Output

```
================================================================================
                    POEMS SORTED BY SIMILARITY TO POEM 68
================================================================================
Total poems: 6,860
Generated: 2025-12-17

================================================================================

 -> file: fediverse/0068
--------
the original poem text goes here, wrapped at 80 characters so that it displays
properly in any text editor or terminal window without horizontal scrolling.

[Image: A sunset over the ocean with purple clouds]

more poem text continues here after the image placeholder...

================================================================================

 -> file: fediverse/1234
--------
the next most similar poem appears here...

================================================================================
```

---

## Implementation Steps

### Phase A: Verify Current State
1. [ ] Check if `generate_similarity_txt_file()` exists in flat-html-generator.lua
2. [ ] Test current .txt generation (if any)
3. [ ] Document gaps between current and intended behavior

### Phase B: Core TXT Generation
4. [ ] Create `generate_txt_export(poems_sorted, output_path)` function
5. [ ] Implement `strip_html_tags(content)` utility
6. [ ] Implement `image_to_alt_text(img_tag)` converter
7. [ ] Implement `wrap_text_80_chars(text)` formatter

### Phase C: Image Handling
8. [ ] Parse `<img>` tags from poem content
9. [ ] Extract alt-text: `<img alt="description">` → `[Image: description]`
10. [ ] Handle missing alt-text gracefully: `[Image: no description]`
11. [ ] Preserve image position in text flow

### Phase D: Integration
12. [ ] Generate .txt alongside .html in main generation pipeline
13. [ ] Add .txt generation to `scripts/generate-html-parallel`
14. [ ] Verify file sizes are reasonable (~5-10MB per full corpus export)

### Phase E: Testing
15. [ ] Verify 80-character width on sample outputs
16. [ ] Verify all images converted to alt-text
17. [ ] Verify no HTML tags remain in output
18. [ ] Test with poems containing special characters

---

## Technical Requirements

### Image to Alt-Text Conversion

```lua
-- {{{ image_to_alt_text
local function image_to_alt_text(content)
    -- Convert <img> tags to [Image: alt-text] format
    -- Pattern: <img ... alt="description" ... >

    local result = content:gsub('<img[^>]*alt="([^"]*)"[^>]*>', '[Image: %1]')

    -- Handle images without alt text
    result = result:gsub('<img[^>]*>', '[Image: no description]')

    return result
end
-- }}}
```

### HTML Tag Stripping

```lua
-- {{{ strip_html_tags
local function strip_html_tags(content)
    -- Remove all HTML tags except those already converted
    local result = content

    -- First convert images to alt-text
    result = image_to_alt_text(result)

    -- Then strip remaining HTML tags
    result = result:gsub('<[^>]+>', '')

    -- Decode HTML entities
    result = result:gsub('&amp;', '&')
    result = result:gsub('&lt;', '<')
    result = result:gsub('&gt;', '>')
    result = result:gsub('&quot;', '"')
    result = result:gsub('&#39;', "'")
    result = result:gsub('&nbsp;', ' ')

    return result
end
-- }}}
```

---

## File Size Estimates

```
Per-poem .txt export (full corpus):
- ~7000 poems × ~200 chars average = ~1.4MB raw text
- With formatting and separators: ~2-3MB per file

Total .txt files:
- Similarity: 6860 files × ~2.5MB = ~17GB
- Diversity: 6860 files × ~2.5MB = ~17GB
- Chronological: 1 file × ~2.5MB = ~2.5MB

Grand total: ~34GB of .txt exports
```

**Note**: This is significant storage. Consider:
- Generating .txt on-demand vs. pre-generating
- Compression (.txt.gz)
- Storing only page-1 poem's full export

---

## Related Documents

- `/src/flat-html-generator.lua` - Main generation logic
- `/issues/completed/5-013-implement-flat-html-compiled-txt-recreation.md` - Original .txt spec
- `/issues/8-012-implement-paginated-similarity-chapters.md` - Blocked by this issue

---

## Acceptance Criteria

- [ ] .txt files generate for all similarity orderings
- [ ] .txt files generate for all diversity orderings
- [ ] .txt files generate for chronological ordering
- [ ] Images converted to `[Image: alt-text]` format
- [ ] No HTML tags in .txt output
- [ ] 80-character line width enforced
- [ ] Download links work from HTML pages

---
