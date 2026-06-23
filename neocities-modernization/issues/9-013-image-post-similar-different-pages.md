# Issue 9-013: Image-Only Post Timestamp Association

## Priority
Medium

## Problem Statement

Image-only posts (fediverse posts containing just `🖼` or minimal text with an image attachment) cannot be meaningfully embedded because there's no semantic content to embed. An embedding of just `🖼` produces a nearly useless vector that won't cluster with related content.

**Current behavior:**
- Image-only posts get embeddings based on minimal text (e.g., `🖼`)
- These embeddings are semantically meaningless
- Similar/different rankings for these posts are essentially random
- Images don't appear on similar/different pages at all (see Issue 8-040)

## REDESIGN (2026-06-22): Neighbor-Averaged Pseudo-Embedding

> This supersedes the "Timestamp-Based Association (Nearest Neighbor)" design
> further below, which was implemented (see Implementation Progress) and is kept
> for history per the append-only ticket convention.

### Why the redesign

The original design associated each image-only post with the SINGLE nearest text
poem by timestamp and rendered it inline with that one parent. Two limits drove
the rethink:

1. It only covers image-only fediverse POSTS. The standalone catalog sources
   (my-art, poem-pictures, things-I-almost-posted, dnd-pictures-from-the-internet,
   fediverse-stars) never earn a place in the similar/different rankings at all.
2. Inheriting one neighbor's embedding snaps the image onto that poem's exact
   semantic position. It cannot express the image's "between two moments"
   character — which is the whole point of placing it chronologically.

### Three classes of images (decided from the data, not guessed)

A scan of poems.json (411 posts carry attachments) shows three distinct cases.
Critically, the feared `[image-1234.png]` placeholder text does NOT exist — only
1 of 411 posts references an image filename in its content — so text+image posts
carry real text, and a simple bare-content-length threshold separates the classes
(no placeholder detection needed):

1. **Text + image post** (~343): real post text, e.g. "religion is a set of shared
   cultural parables...". The post is already embedded by its text and ranks
   normally; the image renders as its attachment and thereby INHERITS the post's
   text embedding. No pseudo-embedding — this is already correct. The user's rule
   "if an image is part of a text post, use the post's text as the image's
   embedding" is satisfied by leaving these alone.

2. **Image-only post** (~52): content is just `🖼` or blank. Its real embedding is
   semantically useless, so REPLACE it with the neighbor-averaged pseudo-embedding
   and let the post rank as a first-class image entry.

3. **Standalone catalog image** (my-art, poem-pictures, etc.): no post at all →
   neighbor-averaged pseudo-embedding, first-class image entry.

Classification: strip whitespace + image emoji from content; if what remains is
shorter than the threshold (the existing `is_image_only` uses < 10 chars), it is
class 2, else class 1. The ~16 borderline "short" posts (series markers like
"4/20"/"part 2/20", bare mentions like "@user-880", single words like "mitski")
fall under class 2 by this threshold; that is an acceptable default — a "4/20"
marker is no more embeddable than `🖼`. Revisit only if a regenerated page shows a
short-but-meaningful post landing oddly.

Only classes 2 and 3 are fed to `compute_image_pseudo_embeddings`. The
chronological spine passed to it is TEXT poems only (classes 1 + ordinary poems);
class-2/3 images are never part of the spine they average over.

### The pseudo-embedding

Every text-LESS image (class 2 or 3) is placed at its timestamp within the global
chronological order of text poems. Its embedding is
synthesized as the AVERAGE of the embeddings of the poem immediately BEFORE and
the poem immediately AFTER it in that order:

    pseudo_embedding = normalize( (embedding_before + embedding_after) / 2 )

This lands the image at the semantic midpoint of its temporal neighbors — its true
"between" position. The image then becomes a first-class ranked entity: its
similarity to any poem P is `cosine(pseudo_embedding, P.embedding)`, so it sorts
into similar/different rankings exactly like a poem.

### Edge cases

- Image before the first poem chronologically: use only the following poem's
  embedding (no average).
- Image after the last poem chronologically: use only the preceding poem's
  embedding.
- Identical timestamps / equidistant neighbors: the average is order-independent,
  so ties need no special handling.
- Multiple images between the same two poems: all share the same midpoint
  pseudo-embedding and rank together. Acceptable.

### Pipeline placement (why this is clean)

Pseudo-embeddings are derived purely from existing poem embeddings, so they are
computed AFTER poem embedding generation (the stage that writes embeddings.json)
and BEFORE the GPU similarity stage. Images are appended to the embedding set as
"pseudo-poems," so the existing similarity + diversity GPU stages rank them
uniformly with zero special-casing — they just see more rows. Only HTML rendering
needs to tell an image entry from a poem entry.

### Algorithm

1. Sort all TEXT poems by `creation_date` to form the chronological spine; keep
   each poem's embedding alongside it.
2. For each image (image-only post, and each catalog image carrying a timestamp):
   a. Locate its position in the spine by timestamp (binary search).
   b. `before` = nearest poem with date <= image date; `after` = nearest with
      date >= image date.
   c. `pseudo_embedding` = average(before.embedding, after.embedding), or the
      single available end embedding, then L2-normalize.
3. Append each image as a pseudo-poem `{is_image=true, source, display_path,
   attachments, embedding=pseudo_embedding, creation_date}` to the embedding set
   the similarity stage consumes.
4. Similarity + diversity stages run unchanged over the combined set.
5. similar/different/chronological renderers detect image pseudo-poems and draw
   an image box with a source-qualified title; each consumes one slot per page,
   like a poem.

### Suggested Implementation Steps (redesign)

1. **Pure function** `compute_image_pseudo_embeddings(poems_with_embeddings,
   image_catalog)` → list of image pseudo-poems. No GPU, no I/O — unit-testable
   on small fixtures (verify the average + normalization + end-case handling).
2. **Pipeline hook**: after embeddings.json is written, build and append the
   image pseudo-poems, emitting the combined embedding set the similarity stage
   reads. Keep generation and consumption separate (data-gen vs data-view).
3. **Renderer**: extend flat-html-generator to render image pseudo-poems in
   similar/different/chronological lists (image + title box, one slot each).
4. **Shared title helper**: the `source: subdir: name.png` formatting is shared
   with Issue 10-042d (gallery chronological list) — factor it into one function.
5. Decide the fate of the old `associate_image_only_posts()` path — remove or
   repurpose once the pseudo-embedding path covers image-only posts too.

---

## Superseded Original Design: Timestamp-Based Association (Nearest Neighbor)

> Implemented 2026-01-20/21 (see Implementation Progress). Superseded by the
> redesign above; preserved for history.

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
- [x] Verify image-only posts are detected correctly
- [ ] Check associated images appear with parent poems

### 2026-01-21: Core Implementation Complete

**Added `associate_image_only_posts()` function** in `src/poem-extractor.lua` (lines 407-509):
- Identifies image-only posts: content ≤ 10 chars AND has attachments
- Finds nearest text poem by timestamp using ISO date parsing
- Adds `associated_images` array to parent poems with:
  - `source_poem_index`, `source_category`, `source_id`
  - `time_delta_seconds`, `creation_date`, `attachments`
- Marks image-only posts with `is_image_only_associated = true`

**Integration in `extract_poems_auto()`** (line 544-547):
- Called after poem_index assignment
- Bumped extraction_version to 2.2
- Added `features.image_only_association = true` to metadata

**Test Results:**
- Found 71 image-only posts in collection
- Associated all 71 with parent poems
- 69 parent poems received associated_images (some get multiple)

### 2026-06-22: Redesign — pseudo-embedding core + augmentation hook built

- `src/image-pseudo-embeddings.lua`: pure neighbor-averaging core (+ 16 tests).
- `src/augment-embeddings-with-images.lua`: pipeline hook. Classifies posts
  (class 1 text+image kept; class 2 image-only embedding replaced; class 3
  catalog images appended), builds the text-poem chronological spine, computes
  pseudo-embeddings, and writes augmented `embeddings.json` + a sidecar
  `image-manifest.json` for the renderer. Idempotent. (+ 20 tests incl. a
  read-only real-data pass: class1=343, class2=68, class3=692, 8362 → 9054.)

**Pending (critical path before regeneration):**
- [ ] Wire the augmentation step into run.sh between Stage 6 and Stage 7.
- [ ] Renderer: flat-html-generator must draw image entries (poem_index beyond
      the poem range, looked up in `image-manifest.json`) on
      similar/different/chronological pages instead of failing the poems.json
      lookup. THIS gates a correct regeneration.
- [ ] Decide fate of the old nearest-neighbor `associate_image_only_posts()`.

## Metadata

- **Status**: 🔄 Reopened (2026-06-22) — redesign to neighbor-averaged pseudo-embedding. The original nearest-neighbor association was implemented & shipped; the redesign generalizes images to first-class ranked entities (covers standalone catalog sources, not just image-only posts).
- **Created**: 2026-01-20 (rewritten with timestamp association approach)
- **Phase**: 9 (originally), moved to Phase 8 roadmap
- **Estimated Complexity**: Medium (algorithm straightforward, integration touches multiple files)
- **Dependencies**: Issue 8-040 should be completed first (basic image rendering)
- **Affects**: Poem extraction, HTML generation, pagination counts
