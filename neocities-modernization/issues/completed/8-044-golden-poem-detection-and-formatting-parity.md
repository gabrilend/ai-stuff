# Issue 8-044: Golden Poem Detection and Formatting Parity

## Priority
High

## Current Behavior

### Problem 1: Inconsistent Golden Poem Detection

The HTML generator uses the **wrong method** to detect golden poems:

**Extraction (correct)** - `scripts/extract-fediverse.lua:372-386`:
```lua
-- Golden poem calculation: HTML-cleaned content (before anonymization) + content warning text
local golden_content = golden_poem_content or content
local golden_poem_length = string.len(golden_content)
if cw and cw ~= "" then
    golden_poem_length = golden_poem_length + string.len(cw)
end
is_golden_poem = (golden_poem_length == 1024)
```

**HTML Generator (incorrect)** - `src/flat-html-generator.lua:1326-1331`:
```lua
local function is_golden_poem(poem)
    if poem.content then
        local content_length = #poem.content
        return content_length == 1024  -- WRONG: uses post-anonymization content without CW
    end
    return false
end
```

**Result**:
- Extraction identifies **431** golden poems (using pre-anonymization + CW)
- HTML generator identifies **244** golden poems (using post-anonymization, no CW)
- Only **241** poems are identified by both methods
- **190 poems** have `metadata.is_golden_poem = true` but content ≠ 1024 chars

**Root cause**: The anonymization process changes character counts (replacing `@username` with `user-XXX`), and content warnings are stored separately from `poem.content`.

### Problem 2: Similar/Different Pages Missing Golden Formatting

The effil worker thread (`format_poem_entry()` at line 2833) does **not** apply golden poem formatting. It formats all poems identically using the regular corner box style (`┌─│`), even for golden poems.

**Chronological pages** (main scope): ✅ Checks `is_golden_poem()`, applies `╔═║` formatting
**Similar/different pages** (effil worker): ❌ No golden detection, no golden formatting

### Problem 3: Formatting Differences Between Page Types

The chronological and similar/different pages should have nearly identical poem formatting, but they differ:

| Feature | Chronological | Similar/Different |
|---------|--------------|-------------------|
| Golden poem detection | `is_golden_poem()` called | Not checked |
| Golden box formatting | `apply_golden_poem_formatting()` | Not applied |
| Progress bar generator | `generate_progress_dashes()` with `is_golden` param | Inline implementation, no golden param |
| Content formatting | `format_content_with_warnings()` | Inline word-wrapping |
| CW box rendering | Via `format_content_with_warnings()` | Inline implementation |

## Intended Behavior

1. **Use metadata for golden detection**: Replace `#poem.content == 1024` with `poem.metadata and poem.metadata.is_golden_poem`

2. **Apply golden formatting everywhere**: Similar/different pages should show golden poems with the same `╔═║` box-drawing format as chronological pages

3. **Consistent formatting**: Both page types should produce visually identical output for the same poem at the same progress position

## Validation Data

```
Golden poem counts:
  #content == 1024:              244
  metadata.is_golden_poem:       431
  Both agree:                    241
  Metadata says golden, content differs: 190
  Content is 1024, metadata disagrees:   3
```

Examples where metadata=golden but content ≠ 1024:
- poem_index=162: content=999 + CW=25 = 1024 ✓
- poem_index=276: content=994 + CW=30 = 1024 ✓

The CW text is counted in `golden_poem_character_count` but stored separately from `poem.content`.

## Suggested Implementation Steps

### Step 1: Fix golden poem detection in main scope
```lua
-- Replace this:
local function is_golden_poem(poem)
    if poem.content then
        return #poem.content == 1024
    end
    return false
end

-- With this:
local function is_golden_poem(poem)
    -- Use pre-calculated golden status from extraction metadata
    -- This correctly accounts for pre-anonymization content + CW text
    if poem.metadata and poem.metadata.is_golden_poem then
        return true
    end
    return false
end
```

### Step 2: Add golden detection to effil worker thread
Add `is_golden_poem()` helper inside the effil worker thread's function scope.

### Step 3: Add golden formatting to effil worker
Add a simplified version of `apply_golden_poem_formatting()` inside the effil worker, or refactor to share code.

### Step 4: Verify progress bar handles golden poems
Ensure the effil worker's progress bar implementation passes `is_golden` parameter correctly for proper corner character selection (`╔`/`╚` vs `┌`/`└`).

### Step 5: Test and validate
- Regenerate HTML for a known golden poem (e.g., poem_index=162)
- Verify `╔` appears in both chronological and similar pages
- Verify all 431 golden poems get golden formatting

## Technical Notes

### Why extraction uses pre-anonymization content

Mastodon's 500-character limit (or 1024 for compatible instances) counts:
- The actual text content (what you typed in the post)
- @mentions as they appear (e.g., `@alice@example.com`)
- Content warning text (just the text, NOT the "CW: " prefix)

**NOT counted** (these are display/UI elements added by our pipeline):
- "CW: " prefix
- "fediverse/1234" identifiers
- Navigation links
- Box-drawing characters
- Any other formatting added during HTML generation

The extraction process preserves this count in `golden_poem_character_count` so we can identify poems that were "golden" (exactly at the character limit) when posted, regardless of later privacy processing or display formatting.

### Why 3 poems have content=1024 but metadata≠golden

These are likely edge cases where:
- Non-fediverse poems (notes, messages) happen to be exactly 1024 chars
- Or fediverse poems where anonymization coincidentally preserved the exact count

These should probably NOT be treated as golden (they weren't golden when posted).

## Related Documents

- `scripts/extract-fediverse.lua` - Golden poem calculation (lines 372-386)
- `src/flat-html-generator.lua` - `is_golden_poem()` function (lines 1326-1331)
- `src/flat-html-generator.lua` - `apply_golden_poem_formatting()` (lines 1545-1600)
- `src/flat-html-generator.lua` - effil worker `format_poem_entry()` (lines 2833+)
- `issues/8-006-fix-golden-poem-box-drawing-format.md` - Original golden formatting implementation

## Implementation Progress

### 2026-01-21: Implemented

**Changes to `src/flat-html-generator.lua`:**

1. **Fixed main scope `is_golden_poem()` (line 1326)**:
   - Now uses `poem.metadata.is_golden_poem` instead of `#poem.content == 1024`
   - Single source of truth from extraction metadata

2. **Added `is_golden_poem()` to effil worker thread (line 2787)**:
   - Same logic as main scope, checks metadata

3. **Added golden detection to `format_poem_entry()` (line 2854)**:
   - Checks `is_golden` at function start

4. **Modified top progress bar (lines 2869-2877)**:
   - Golden poems get `╔` corner prefix
   - Regular poems have no corner prefix

5. **Added golden side borders to content (lines 2961-2985)**:
   - Golden poems get `║` (colored) left wall, `│` right wall
   - 80-char content area with padding

6. **Modified navigation box (lines 3000-3053)**:
   - Golden: `╟─────────┐` separator, `║ similar │` nav line, `┤` right end
   - Regular: `┌─────────┐` separator, `│ similar │` nav line, `│` right end

7. **Modified bottom progress bar (lines 3089-3098)**:
   - Golden poems use `╚` corner
   - Regular poems use `╘` corner

**Result**: All 431 golden poems (per metadata) will now render with proper golden formatting on both chronological AND similar/different pages.

### 2026-01-21: Re-opened - Multiple alignment issues

**Issues found:**
1. Bottom progress bar right junction off by one (position 69 should be 70)
2. Similar/different pages: nav box gap too small (58 chars, should be 60)
3. Similar/different pages: nav line uses `┤` instead of `│` for right end
4. Content warning lines not padded correctly (UTF-8 byte counting bug)

**Fixes applied to `src/flat-html-generator.lua`:**

1. **LAYOUT constant (line 125)**: Changed `GOLDEN_RIGHT_JUNCTION_POS = 69` → `70`

2. **Main scope junction (line 746)**: Changed `RIGHT_JUNCTION_POS = 69` → `70`

3. **Effil worker junction (line 3085)**: Changed `RIGHT_JUNCTION = is_golden and 69` → `70`

4. **Effil worker nav top (lines 3023-3042)**:
   - Gap changed from 58 → 60 chars
   - Right box positions changed from 69-81 → 71-83

5. **Effil worker nav line (lines 3044-3052)**:
   - Right end changed from `┤` → `│` (separator uses ┤, nav uses │)
   - Gap calculation changed from 22+22 → 23+23
   - Right wall position changed from 69 → 71

6. **UTF-8 character counting (lines 1559-1564, 2984-2989)**:
   - Added `utf8_char_count()` helper function in both scopes
   - Box-drawing chars are 3 bytes but 1 character; `#str` counted bytes
   - Fix: Remove UTF-8 continuation bytes (0x80-0xBF) before counting

**Root causes:**
- Junction position 69 was incorrect for 60-char gap (should align with ┌ at position 71)
- Effil worker used inconsistent gap (58 vs main scope's 60)
- `#string` counts bytes in Lua, not UTF-8 characters

## Metadata

- **Status**: ✅ Complete
- **Created**: 2026-01-21
- **Completed**: 2026-01-21
- **Re-opened**: 2026-01-21 (alignment issues)
- **Re-completed**: 2026-01-21 (junction, gap, and UTF-8 fixes)
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Medium
- **Dependencies**: None
- **Affects**: All HTML output pages, visual consistency
