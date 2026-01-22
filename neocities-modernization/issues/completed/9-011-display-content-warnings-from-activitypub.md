# Issue 9-011: Display Content Warnings from ActivityPub

## Priority
Medium

## Problem Statement

Content warnings from Mastodon/ActivityPub posts are not displaying in the HTML output. The ActivityPub `summary` field contains content warnings (CW) that were extracted and stored in `poem.content_warning`, but the HTML generation code only detects in-content "CW:" patterns and misses the ActivityPub field.

**Current behavior:**
- In-content patterns like "CW: topic" or "content warning: topic" are detected and displayed
- ActivityPub content warnings stored in `poem.content_warning` are ignored
- 1,781 poems have content warnings but they don't appear in HTML output

**Expected behavior:**
- Both ActivityPub content warnings (`poem.content_warning`) AND in-content patterns should display
- Content warnings should appear in a box at the top of the poem
- Content warnings should NOT be included in embeddings (semantic similarity)

## Root Cause Analysis

The HTML generation code in `flat-html-generator.lua` was checking for content warning patterns in the poem text content but never looking at the separate `poem.content_warning` field that stores the ActivityPub `summary` value.

The data flow is:
1. ActivityPub extraction (`input/fediverse/files/poems.json`) stores `summary` → `content_warning`
2. `poem-extractor.lua` loads this into `poem.content_warning` (separate from `poem.content`)
3. `flat-html-generator.lua` only checked for in-content "CW:" patterns

## Solution

Add content warning display from `poem.content_warning` field at two locations:
1. `format_content_with_warnings()` - for chronological page
2. effil worker thread's `format_poem_entry()` - for similar/different pages

Both locations now:
1. Check if `poem.content_warning` exists and is non-empty
2. Display it in a box before the poem content
3. Continue to also detect in-content "CW:" patterns (for posts that embed CW in content)

## Embedding Exclusion Verification

Content warnings are **NOT** included in embeddings because:
1. `poem.content_warning` is a separate field from `poem.content`
2. Embedding generation uses only `poem.content` via `extract_pure_poem_content_for_embedding(poem.content)`
3. The two fields are never mixed - content warnings stay in their own field

## Files Modified

| File | Change |
|------|--------|
| `src/flat-html-generator.lua` | Added `poem.content_warning` display at lines 1619-1627 (chronological) and lines 2910-2922 (effil worker) |

## Test Cases

1. **Poems with `poem.content_warning` set:**
   - Should display CW box at top of poem
   - CW text should appear as "CW: [content_warning_text]"

2. **Poems with in-content "CW:" pattern:**
   - Should still detect and display these as before
   - Works independently of ActivityPub content warnings

3. **Poems with both:**
   - ActivityPub CW displays first (from `poem.content_warning`)
   - In-content CW displays second (if present)

## Related Documents

- `input/fediverse/files/poems.json` - Contains `content_warning` field
- `src/poem-extractor.lua` - Loads content_warning at lines 272, 323-324, 344
- `src/similarity-engine.lua` - Uses only `poem.content` for embeddings (line 527)

## Metadata

- **Status**: ✅ COMPLETE
- **Created**: 2026-01-21
- **Completed**: 2026-01-21
- **Phase**: 9 (Performance Optimization / Bug Fix)
- **Estimated Complexity**: Low
- **Dependencies**: None
- **Affects**: All page types with content warning display

---

## Implementation Progress

### 2026-01-21: Implementation Complete

**Changes Made:**

1. **`src/flat-html-generator.lua`** - Added ActivityPub content warning display
   - Lines 1619-1627: `format_content_with_warnings()` now checks `poem.content_warning` first
   - Lines 2910-2922: effil worker thread checks `poem.content_warning` before in-content CW patterns
   - Both locations use consistent box formatting with proper spacing

**Behavior After Fix:**

1. ActivityPub content warnings display in a box at top of poem
2. In-content "CW:" patterns continue to work
3. Content warnings remain excluded from embeddings (separate field)
4. Both chronological and similar/different pages show content warnings
