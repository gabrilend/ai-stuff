# Issue 9-010: Fix Image Repetition in Associated Posts

## Priority
High

## Problem Statement

Images from image-only posts (e.g., fediverse/5809) appear multiple times on the chronological page:

**Example: fediverse/5809 and 5810**
- Post 5809: Image-only post (content is just "@user-377" reply mention, has 1 image attachment)
- Post 5810: Text post about "alt-text for images" (no attachments)

**Current behavior - Image appears 3 times:**
1. When rendering 5809: `poem.attachments` renders the image
2. When rendering 5810: `poem.associated_images` (from 9-004) renders 5809's image
3. Unknown source of 3rd occurrence (suspected duplicate association)

**Expected behavior:**
Images should appear exactly once - either on their original post OR on the associated post, not both.

## Root Cause Analysis

### Issue 9-004 Design

Issue 9-004 implemented timestamp-based image association to give image-only posts semantic meaning:
- Image-only posts get associated with the nearest text poem by timestamp
- The parent poem's `associated_images` array stores the child's attachments
- When rendering the parent, both its own attachments AND associated images are displayed

### Problem: Images Appear on Both Posts

The current system:
1. Image-only post 5809 still appears in chronological order at its original timestamp
2. 5809's image is rendered as part of 5809's own attachments
3. 5810 also renders 5809's image via `associated_images`

Result: Same image appears twice (or possibly 3 times if there's duplicate association).

### Potential 3rd Occurrence

Need to investigate if:
1. The association function adds the same image twice
2. Both `poem.attachments` and `poem.associated_images` contain the same image for 5810
3. Multiple association runs are happening

## Proposed Solution: Simplified Approach

**User's recommendation:** Abandon the association system. Instead:

1. **Images stay with their original post** - Display on chronological where they were posted
2. **Embedding calculation** for image-only posts:
   - Use embedding of the **next closest text post by timestamp**
   - PLUS embedding of any text that exists in the image-only post itself
   - This gives semantic meaning without duplicating display

### Benefits of Simplified Approach

1. **No image duplication** - Images appear exactly once, on their original post
2. **Simpler data model** - No `associated_images` arrays to maintain
3. **Predictable behavior** - Images appear where they were posted
4. **Semantic meaning preserved** - Embedding inherits from nearest text post
5. **No complex rendering logic** - Just render `poem.attachments`

### Implementation Steps

1. **Remove `associated_images` rendering** from:
   - `format_single_poem_with_progress_and_color()`
   - effil worker thread `format_poem_entry()`
   - chronological page generation

2. **Update embedding generation** for image-only posts:
   - Find nearest text post by timestamp
   - Get that post's embedding
   - If image-only post has any text, add its embedding contribution
   - Store combined embedding for the image-only post

3. **Simplify `poem-extractor.lua`**:
   - Remove `associate_image_only_posts()` function
   - Keep `is_image_only_post()` detection for embedding purposes
   - Store `nearest_text_poem_id` for embedding lookup only (not for display association)

## Evaluation of Approaches

### Current System (9-004)
- **Pros**: Image appears with semantically related text on similar/different pages
- **Cons**: Duplication, complex rendering, unpredictable display

### Proposed Simplified System
- **Pros**: Simple, no duplication, predictable, images appear at original timestamp
- **Cons**: On similar/different pages, image-only posts appear independently (but with proper embedding)

**Recommendation**: The simplified approach is better because:
1. It eliminates the duplication bug entirely
2. Images appearing at their original timestamp is more intuitive
3. The semantic meaning is preserved through embedding inheritance
4. Less code complexity = fewer bugs

## Files to Modify

| File | Change |
|------|--------|
| `src/poem-extractor.lua` | Remove `associated_images` population, keep `is_image_only` detection |
| `src/flat-html-generator.lua` | Remove `associated_images` rendering (3 locations) |
| `src/embedding-generator.lua` | Add embedding inheritance for image-only posts |

## Test Cases

1. **fediverse/5809** (image-only reply):
   - Should appear at original timestamp with its image (once)
   - Embedding should be similar to 5810's embedding

2. **fediverse/5810** (text post):
   - Should NOT show 5809's image
   - Should only show its own content

3. **Similar/different pages**:
   - Image-only posts appear independently
   - Ranked based on inherited embedding from nearest text post

## Related Documents

- Issue 9-004: Image-Only Post Timestamp Association (current implementation)
- Issue 8-040: Add images to similar/different pages
- Issue 8-005: Integrate images into HTML output
- `src/poem-extractor.lua`: Association logic
- `src/flat-html-generator.lua`: Rendering logic

## Metadata

- **Status**: ✅ COMPLETE
- **Created**: 2026-01-21
- **Completed**: 2026-01-21
- **Phase**: 9 (Performance Optimization / Bug Fix)
- **Estimated Complexity**: Medium (refactoring existing feature)
- **Dependencies**: None (this is a fix/simplification)
- **Affects**: All page types with image display

---

## Implementation Progress

### 2026-01-21: Implementation Complete

**Changes Made:**

1. **`src/flat-html-generator.lua`** - Removed `associated_images` rendering (3 locations)
   - Line 1726-1728: Removed loop that rendered `poem.associated_images` attachments
   - Line 2345-2349: Removed associated_images rendering in chronological index
   - Line 3142-3153: Removed associated_images loop in effil worker thread
   - Added Issue 9-010 comments explaining images stay on original post

2. **`src/poem-extractor.lua`** - Simplified association to marking only
   - Replaced `associate_image_only_posts()` with `mark_image_only_posts()` (lines 115-176)
   - New function marks poems with `is_image_only` flag and finds `nearest_text_poem_id`
   - Added `assign_nearest_text_poem_index()` function (lines 396-427)
   - This runs after `poem_index` assignment to set `nearest_text_poem_index` for embedding lookup
   - Bumped extraction_version to "2.3" with `embedding_inheritance` feature flag
   - Removed all `associated_images` array population logic

3. **`src/similarity-engine.lua`** - Added embedding inheritance for image-only posts
   - Added `inherit_embedding()` helper function (lines 196-234)
   - Combines nearest text poem embedding with own text embedding (if any) via averaging
   - Modified embedding generation loop (lines 529-583) to:
     - Detect image-only posts via `is_image_only` and `nearest_text_poem_index`
     - Look up nearest poem's embedding from current or existing embeddings
     - Store inherited embedding with `is_inherited=true` flag
     - Fall back to random embedding if nearest not yet available (marked `needs_inheritance_update`)

**Verification Results:**

Test with fediverse/5809 and 5810:
- Post 5809: `is_image_only=true`, 1 attachment, content "@user-377" (9 chars)
- Post 5809: `nearest_text_poem_id=5810`, `nearest_text_poem_index=5440`
- Post 5810: `poem_index=5440`, text post about alt-text, `is_image_only=false`
- 68 total image-only posts detected across all categories
- All 68 linked to nearest text poems for embedding inheritance

**Behavior After Fix:**

1. Images appear only on their original post (no duplication)
2. Image-only posts inherit semantic meaning via embedding from nearest text post
3. Similar/different rankings for image-only posts based on inherited embedding
4. No `associated_images` arrays created or rendered
