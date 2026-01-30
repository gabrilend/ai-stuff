# Issue 6-033: Enhance Embedding Content Preprocessing

## Priority
High

## Current Behavior

The `extract_pure_poem_content()` function (Issue 6-029) removes reply syntax but still allows several types of metadata and formatting artifacts to leak into embedding content:

### Problem 1: Dashed Content Warnings
Content warnings like `cannabis-mentioned`, `food-recipe-mentioned`, `unreasonable-violence` contain compound words that are rare in embedding model training data:

```
CW: cannabis-mentioned     → Embedding receives "cannabis-mentioned" (rare token)
CW: food-recipe-mentioned  → Embedding receives "food-recipe-mentioned" (rare token)
CW: politics-mentioned-radical-revolution-minus-the-revolt-please → Extremely rare!
```

The embedding model likely handles "cannabis mentioned" (with space) much better than "cannabis-mentioned" (hyphenated compound).

### Problem 2: File Metadata Leaking
File paths and metadata are appearing in poem content:

```
 -> file: fediverse/1678.txt
file: /home/ritz/words/fediverse/2564.txt
 -> file: fediverse/0234.txt
```

### Problem 3: Separator Lines Leaking
Box-drawing and dash separators appear in content:

```
--------------------------------------------------------------------------------
---
```

### Problem 4: Multiple Poems Concatenated
Some content entries contain multiple poems merged together, with their own CW: prefixes:

```
CW: cooking-food-mentioned

Paprika is the best spice, fite me

 -> file: fediverse/1678.txt
--------------------------------------------------------------------------------
CW: re: cooking-food-mentioned

@trdebunked mmmm, paprika for flavor...
```

## Intended Behavior

### For Embeddings Only
Content sent to the embedding model should be:
1. **Dashes in CWs converted to spaces**: `cannabis-mentioned` → `cannabis mentioned`
2. **File metadata stripped**: All `-> file:` and `file:` lines removed
3. **Separator lines stripped**: All `----` lines removed
4. **Single poem isolation**: Only the first poem if multiple are concatenated

### For Display (unchanged)
The original content with dashes is preserved for display purposes.

## Technical Approach

### Enhanced `extract_pure_poem_content()` for Embeddings

```lua
-- {{{ function M.extract_pure_poem_content_for_embedding
function M.extract_pure_poem_content_for_embedding(processed_content)
    local content = M.extract_pure_poem_content(processed_content)

    -- Convert dashes to spaces in entire content for better embedding tokenization
    -- This helps the model understand "cannabis mentioned" vs rare "cannabis-mentioned"
    content = content:gsub("%-", " ")

    -- Remove file path metadata
    content = content:gsub("%s*%->%s*file:[^\n]*\n?", "")
    content = content:gsub("file:%s*/[^\n]*\n?", "")

    -- Remove separator lines (4+ dashes)
    content = content:gsub("\n%-%-%-%-+\n", "\n")
    content = content:gsub("^%-%-%-%-+\n", "")
    content = content:gsub("\n%-%-%-%-+$", "")

    -- Stop at the first separator if multiple poems concatenated
    -- (Everything after a ---- line is likely a different poem)
    local first_separator = content:find("\n%-%-%-%-")
    if first_separator then
        content = content:sub(1, first_separator - 1)
    end

    -- Clean up multiple consecutive spaces from dash removal
    content = content:gsub("%s+", " "):gsub("^%s*", ""):gsub("%s*$", "")

    return content
end
-- }}}
```

### Usage in Embedding Generation

Update `similarity-engine.lua` to use the enhanced function:

```lua
-- Before:
local poem_text = poem_extractor.extract_pure_poem_content(poem.content)

-- After:
local poem_text = poem_extractor.extract_pure_poem_content_for_embedding(poem.content)
```

## Examples

### Before Enhancement
```
Input:  "CW: cannabis-mentioned\n\nfor me my identities are..."
Output: "cannabis-mentioned\nfor me my identities are..."
```

### After Enhancement
```
Input:  "CW: cannabis-mentioned\n\nfor me my identities are..."
Output: "cannabis mentioned for me my identities are..."
```

### Concatenated Poems - Before
```
Input:  "CW: food\n\nPaprika is great\n\n -> file: 1678.txt\n----\nCW: re: food\n\n@user reply"
Output: "food\nPaprika is great\n\n -> file: 1678.txt\n----\nre: food\nreply"
```

### Concatenated Poems - After
```
Input:  "CW: food\n\nPaprika is great\n\n -> file: 1678.txt\n----\nCW: re: food\n\n@user reply"
Output: "food Paprika is great"
```

## Suggested Implementation Steps

1. **Create new function** `extract_pure_poem_content_for_embedding()` in `poem-extractor.lua`
2. **Add dash-to-space conversion** for better tokenization
3. **Add file metadata removal** patterns
4. **Add separator detection** to isolate single poems
5. **Update similarity-engine.lua** to use new function for embeddings
6. **Test with sample poems** that have dashed CWs and metadata
7. **Document** that display uses original content, embeddings use preprocessed content

## Impact Assessment

### Embedding Quality Improvements
- **Better tokenization**: Common words separated by spaces tokenize predictably
- **Cleaner content**: No file paths or separators contaminating semantic analysis
- **Single poems**: Each embedding represents one discrete piece of content
- **Content warning relevance**: CW topics contribute meaningfully to similarity

### Backward Compatibility
- **Display unchanged**: Original content preserved for HTML generation
- **New function**: Doesn't modify existing `extract_pure_poem_content()` behavior
- **Embedding regeneration**: Will need to regenerate embeddings after implementing

## Related Documents

- `/issues/completed/6-029-remove-reply-syntax-from-embedding-content.md` - Prior work on reply removal
- `/src/poem-extractor.lua` - Implementation location
- `/src/similarity-engine.lua` - Consumer of embedding content

## Quality Assurance

### Test Cases
```lua
local test_cases = {
    -- Dashed CW
    {"CW: cannabis-mentioned\n\ntest", "cannabis mentioned test"},
    -- File metadata
    {"content\n -> file: test.txt\nmore", "content more"},
    -- Separator
    {"poem1\n----\npoem2", "poem1"},
    -- Combined
    {"CW: food-recipe\n\ntext\n -> file: x.txt\n----\nCW: other\n\nmore", "food recipe text"}
}
```

## Implementation Progress

### 2026-01-21: Implemented

**Changes made:**

1. **`src/poem-extractor.lua`** (lines 642-682):
   - Added `M.extract_pure_poem_content_for_embedding()` function
   - Converts dashes to spaces for better tokenization
   - Strips file path metadata (`-> file:`, `file: /path`)
   - Strips separator lines (`----`)
   - Isolates first poem if multiple concatenated

2. **`src/similarity-engine.lua`** (line 484-486):
   - Updated to use `extract_pure_poem_content_for_embedding()` instead of `extract_pure_poem_content()`
   - Comment added explaining the change

**Pending:**
- [ ] Regenerate all embeddings to apply the enhanced preprocessing
- [ ] Verify improved similarity quality after regeneration

## Metadata

- **Status**: ✅ Implementation Complete - Pending Embedding Regeneration
- **Created**: 2026-01-21
- **Last Updated**: 2026-01-21
- **Phase**: 6 (Embedding Quality)
- **Blocked By**: None
- **Blocks**: Embedding regeneration for improved similarity
- **Related**: 6-029 (reply syntax removal)
- **Estimated Effort**: Low (straightforward string processing)
