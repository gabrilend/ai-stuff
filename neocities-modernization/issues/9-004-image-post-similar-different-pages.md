# Issue 9-004: Image-Only Post Timestamp Association

## Priority
Medium

## Problem Statement

Image-only posts (fediverse posts containing just `🖼` or minimal text with an image attachment) cannot be meaningfully embedded because there's no semantic content to embed. An embedding of just `🖼` produces a nearly useless vector that won't cluster with related content.

**Current behavior:**
- Image-only posts get embeddings based on minimal text (e.g., `🖼`)
- These embeddings are semantically meaningless
- Similar/different rankings for these posts are essentially random
- Images don't appear on similar/different pages at all (see Issue 8-040)

## Intended Behavior: Timestamp-Based Association

Image-only posts should be **associated with the nearest text poem by timestamp**, inheriting that poem's semantic context.

### Algorithm

1. **Identify image-only posts**: Posts where content is minimal (just emoji, <10 characters, etc.) but `attachments` array is non-empty

2. **Find nearest text poem by timestamp**:
   - For each image-only post at time T
   - Find the closest text poem by `creation_date`
   - If poem A is 5 minutes before and poem B is 10 minutes after, associate with poem A (the closer one)

3. **Associate image with parent poem**:
   - Mark the image-only post as "attached" to its parent poem
   - The image inherits the parent poem's embedding for ranking purposes
   - When the parent poem appears on similar/different pages, the associated image appears with it

4. **Display behavior**:
   - On chronological pages: Image-only posts appear in their original timestamp position
   - On similar/different pages: Image appears with parent poem, consuming one slot in the poems-per-page count
   - The image post is visually distinct (boxed separately) but grouped with its parent

### Example

```
Timeline:
  T-5min:  "the silence between stars" (text poem)
  T:       🖼 [image of night sky]      (image-only post)
  T+10min: "morning arrives too soon"  (text poem)

Association:
  The image post at T is associated with "the silence between stars" (5 min closer than 10 min)

Display on similar/0042-01.html (for "the silence between stars"):
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │ the silence between stars                                                    │
  │ speaks in wavelengths                                                        │
  │ we forgot how to hear                                                        │
  └──────────────────────────────────────────────────────────────────────────────┘
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │ [IMAGE: night sky photograph]                                                │
  │ (associated image post from +5 minutes)                                      │
  └──────────────────────────────────────────────────────────────────────────────┘
```

## Technical Design

### Data Structure Changes

Add fields to poem entries during extraction/processing:

```lua
poem = {
    id = 1234,
    content = "the silence between stars...",
    creation_date = "2024-03-15T10:30:00Z",
    attachments = {...},
    -- New fields:
    associated_images = {  -- Images from nearby image-only posts
        {
            post_id = 1235,
            time_delta_seconds = 300,  -- 5 minutes after
            attachments = {...}
        }
    },
    is_image_only = false  -- Flag for image-only detection
}

image_only_post = {
    id = 1235,
    content = "🖼",
    creation_date = "2024-03-15T10:35:00Z",
    attachments = {...},
    -- New fields:
    is_image_only = true,
    parent_poem_id = 1234,  -- Associated text poem
    time_delta_seconds = 300
}
```

### Detection Criteria

```lua
-- {{{ is_image_only_post
local function is_image_only_post(poem)
    -- Has attachments
    if not poem.attachments or #poem.attachments == 0 then
        return false
    end

    -- Content is minimal (emoji-only or very short)
    local content = poem.content or ""
    local stripped = content:gsub("%s+", ""):gsub("[🖼📷📸🎨🌅🌄🌃🌉🏞️]", "")

    return #stripped < 10
end
-- }}}
```

### Association Algorithm

```lua
-- {{{ associate_image_only_posts
local function associate_image_only_posts(poems)
    -- Separate text poems and image-only posts
    local text_poems = {}
    local image_posts = {}

    for _, poem in ipairs(poems) do
        if is_image_only_post(poem) then
            poem.is_image_only = true
            table.insert(image_posts, poem)
        else
            poem.associated_images = {}
            table.insert(text_poems, poem)
        end
    end

    -- Sort text poems by timestamp for binary search
    table.sort(text_poems, function(a, b)
        return a.creation_date < b.creation_date
    end)

    -- Associate each image post with nearest text poem
    for _, img_post in ipairs(image_posts) do
        local nearest = find_nearest_by_timestamp(text_poems, img_post.creation_date)
        if nearest then
            img_post.parent_poem_id = nearest.id
            img_post.time_delta_seconds = timestamp_diff(nearest.creation_date, img_post.creation_date)
            table.insert(nearest.associated_images, {
                post_id = img_post.id,
                time_delta_seconds = img_post.time_delta_seconds,
                attachments = img_post.attachments
            })
        end
    end

    return text_poems, image_posts
end
-- }}}
```

### Integration Points

1. **Poem extraction** (`src/poem-extractor.lua`):
   - Add `is_image_only` detection
   - Run association algorithm after loading all poems
   - Store associations in poem data

2. **Embedding generation** (`src/embedding-generator.lua`):
   - Skip embedding generation for image-only posts
   - Or: Generate embedding but mark as "inherited from parent"

3. **HTML generation** (`src/flat-html-generator.lua`):
   - When rendering a poem, also render its `associated_images`
   - Each associated image consumes one slot in poems-per-page
   - Add visual distinction for associated images

4. **Similarity ranking**:
   - Image-only posts don't appear independently in rankings
   - They appear as part of their parent poem's display

## Suggested Implementation Steps

1. **Add detection function**:
   - Create `is_image_only_post()` in `libs/utils.lua`
   - Test with sample data to verify detection accuracy

2. **Add association algorithm**:
   - Create `associate_image_only_posts()` function
   - Implement `find_nearest_by_timestamp()` helper
   - Run during poem extraction phase

3. **Update data structures**:
   - Add `is_image_only`, `parent_poem_id`, `associated_images` fields
   - Update JSON serialization if needed

4. **Update embedding generation**:
   - Skip or specially handle image-only posts
   - Ensure they don't break the embedding pipeline

5. **Update HTML generation**:
   - Modify poem rendering to include associated images
   - Add visual styling for associated image boxes
   - Account for associated images in pagination counts

6. **Test with real data**:
   - Find image-only posts in fediverse data
   - Verify associations make semantic sense
   - Check display on all page types

## Configuration

Add to config file:

```lua
image_association = {
    enabled = true,
    max_content_length = 10,  -- Characters (after stripping emoji)
    max_time_delta_hours = 24,  -- Don't associate if >24 hours apart
    image_emojis = {"🖼", "📷", "📸", "🎨", "🌅", "🌄", "🌃", "🌉", "🏞️"}
}
```

## Edge Cases

1. **No nearby text poem**: If an image-only post has no text poem within `max_time_delta_hours`, leave it unassociated (appears only on chronological)

2. **Multiple image posts**: Multiple consecutive image-only posts can all associate with the same text poem

3. **Image post between two equidistant poems**: Use the earlier poem (arbitrary but consistent)

4. **Very long gaps**: Don't associate across day boundaries or unreasonably long gaps

## Related Documents

- Issue 8-040: Add images to similar/different pages (prerequisite - basic image rendering)
- Issue 8-005 (completed): Integrate images into HTML output
- `src/poem-extractor.lua`: Poem loading and processing
- `src/flat-html-generator.lua`: HTML generation

## Implementation Progress

### 2026-01-20: Core Implementation Complete

**Changes made to `src/poem-extractor.lua`:**

1. **Added `is_image_only_post()` function** (lines 56-76):
   - Detects posts with attachments but minimal text content
   - Strips whitespace and common image emojis
   - Returns true if remaining content < 10 characters

2. **Added `parse_iso8601_timestamp()` function** (lines 79-112):
   - Parses ISO 8601 timestamps for comparison
   - Handles formats like "2024-03-15T10:30:00Z"

3. **Added `associate_image_only_posts()` function** (lines 115-187):
   - Separates text poems and image-only posts
   - Finds nearest text poem by timestamp for each image post
   - Associates images within 24-hour window
   - Adds `is_image_only`, `parent_poem_id`, `associated_images` fields

4. **Integrated into `M.load_extracted_json()`** (line 364-366):
   - Calls `associate_image_only_posts()` after loading all poems

**Changes made to `src/flat-html-generator.lua`:**

5. **Updated chronological page generation** (lines 2235-2240):
   - Renders associated images after poem's own attachments

6. **Updated `format_single_poem_with_progress_and_color()`** (lines 1615-1621):
   - Renders associated images from image-only posts

7. **Updated effil worker thread `format_poem_entry()`** (lines 2856-2863):
   - Renders associated images in parallel page generation

**Files modified:**
- `src/poem-extractor.lua` - Image-only detection and timestamp association
- `src/flat-html-generator.lua` - Render associated images in all page types

**Pending:**
- [ ] Full regeneration to test with real data
- [ ] Verify image-only posts are detected correctly
- [ ] Check associated images appear with parent poems

## Metadata

- **Status**: Implementation Complete - Awaiting Validation
- **Created**: 2026-01-20 (rewritten with timestamp association approach)
- **Phase**: 9 (originally), moved to Phase 8 roadmap
- **Estimated Complexity**: Medium (algorithm straightforward, integration touches multiple files)
- **Dependencies**: Issue 8-040 should be completed first (basic image rendering)
- **Affects**: Poem extraction, HTML generation, pagination counts
