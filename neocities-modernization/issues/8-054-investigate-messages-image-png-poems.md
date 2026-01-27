# Issue 8-054: Investigate and Fix Messages "image.png" Poems

## Priority
Medium

## Current Behavior

Poems from the `messages` category that correspond to image messages display only the literal text `"image.png"` as their content. No actual image is rendered. These poems are semantically empty — they pollute similarity rankings, waste page space, and confuse readers.

### Example output (similarity-ranked page)

```
───────────────────────────────────────────────────────────────────────────────────
 image.png
┌─────────┐                                                           ┌───────────┐
│ similar │                       chronological                       │ different │
╘─────────┴───────────────────────────────────────────────────────────┴───────────┘
```

### Affected poems

At least 16 messages poems contain only "image.png" as content, including IDs: 0014, 0015, 0183, 0241, 0556, 0569, 0682, 0706, 0707, 0708, 0709, 0710, 0756, and others. These appear clustered in similarity rankings because their identical embedding ("image.png") produces near-perfect cosine similarity with each other.

### Root Cause

The messages extraction script (`scripts/extract-messages.lua:153`) extracts only the `body` field from Matrix messages:

```lua
local content = value.content.body or " "
```

For image messages in the Matrix export format, the `body` field contains just the filename (e.g., `"image.png"`, `"20240706_212649.jpg"`). The actual image data, dimensions, and file references live in separate fields that are completely ignored:

```json
{
  "type": "m.room.message",
  "content": {
    "body": "image.png",           // ← Only this is extracted
    "msgtype": "m.image",          // ← Ignored (type detection)
    "file": {                      // ← Ignored (image URL and encryption)
      "url": "mxc://matrix.org/...",
      "mimetype": "image/png",
      "size": 808254
    },
    "info": {                      // ← Ignored (dimensions and thumbnails)
      "h": 1415,
      "w": 1125,
      "mimetype": "image/png",
      "size": 808254
    }
  },
  "origin_server_ts": 1622934419199
}
```

### Contrast with fediverse extraction

The fediverse extractor (`scripts/extract-fediverse.lua:440-478`) properly handles attachments:
- Detects `Document` type attachments in the ActivityPub `attachment` array
- Extracts `media_type`, `url`, `relative_path`, `alt_text`, `width`, `height`, `blurhash`
- Stores an `attachments` array on each poem entry
- The HTML generator renders these as `<img>` tags

The messages extractor has **no attachment handling at all** — the poem entry (lines 156-165) never includes an `attachments` field.

### Data available in the Matrix export

The `similar-different.zip` backup contains:
- **`export.json`**: Full Matrix room export with structured message data
- **`images/` directory**: 166 actual decrypted image files (PNG, JPG)
- **Message types**: `m.text`, `m.image`, `m.video`, `m.audio`, `m.file`

The image files are already decrypted and available as local files — no decryption needed. The filenames in the `images/` directory can be correlated with the export.json entries.

## Intended Behavior

Two changes are needed:

### 1. Filter out image-only messages (immediate fix)

Messages where `content.msgtype == "m.image"` and the body is just a filename (no meaningful text) should be treated the same way the fediverse extractor handles image-only posts — filtered out during extraction. A poem whose entire content is `"image.png"` contributes nothing to semantic analysis and pollutes the embedding space.

The existing image-only detection logic in `src/poem-extractor.lua` already handles this for fediverse posts — the messages extractor should apply the same principle.

**Detection heuristic**: If `content.msgtype` is `"m.image"`, `"m.video"`, `"m.audio"`, or `"m.file"`, AND the `body` field matches a filename pattern (e.g., ends in `.png`, `.jpg`, `.gif`, `.mp4`, `.webm`, `.pdf`, etc.), the message is media-only and should be either:
- Excluded from extraction entirely (simpler — these poems are meaningless without the image)
- Or kept but marked with an `attachments` field and given a placeholder content like `"[Image]"` (more complex — requires image integration)

### 2. Extract image attachments from Matrix messages (future enhancement)

For messages that combine text AND an image, or for a future version that supports rendering message images:

```lua
-- Detect message type and extract attachment metadata
if value.content.msgtype == "m.image" then
    local attachment = {
        media_type = (value.content.info and value.content.info.mimetype) or "image/png",
        width = value.content.info and value.content.info.w,
        height = value.content.info and value.content.info.h,
        alt_text = nil,  -- Matrix doesn't have alt-text for images
        -- Map to local file in the ZIP extract
        relative_path = find_local_image(value.content.body, images_dir)
    }
    poem_entry.attachments = { attachment }
end
```

This would allow the HTML generator to render message images the same way it renders fediverse images.

### Decision point

The simplest fix is **option 1: filter out media-only messages**. This eliminates the "image.png" poems immediately and cleans up the semantic space. Image rendering for messages can be a separate follow-up issue if desired.

## Suggested Implementation Steps

### Phase A: Filter out media-only messages (recommended first step)

1. **Add msgtype detection** to `scripts/extract-messages.lua` inside the extraction loop (after line 153):
   ```lua
   local content = value.content.body or " "
   local msgtype = value.content.msgtype

   -- Skip media-only messages — their body is just a filename, not meaningful text
   -- These pollute the embedding space with identical "image.png" vectors
   if msgtype == "m.image" or msgtype == "m.video"
      or msgtype == "m.audio" or msgtype == "m.file" then
       -- Check if body is just a filename (no real text content)
       if content:match("^%S+%.%w+$") then
           skipped_media_count = skipped_media_count + 1
           i = i + 1  -- Preserve ID stability (tombstoning)
           goto continue
       end
   end
   ```

2. **Add skip counter** and report it in the extraction summary:
   ```lua
   local skipped_media_count = 0
   -- ... (in summary) ...
   print("   🖼️  Skipped media-only: " .. skipped_media_count)
   ```

3. **Update extraction summary JSON** to include `media_only_skipped` count.

4. **Test**: Re-run messages extraction and verify:
   - "image.png" poems no longer appear in `poems.json`
   - Total poem count decreases by ~16
   - ID gaps are present where media messages were (tombstoning)
   - Remaining poems all have meaningful text content

### Phase B: Extract message images (future enhancement)

5. **Map Matrix image filenames to local files**: The ZIP extract has images in an `images/` subdirectory. Build a lookup from filename → local path.

6. **Add attachment metadata** to poems that combine text + image (if any exist in the export).

7. **Ensure the image sync pipeline** (`scripts/sync-images`) copies message images alongside fediverse images.

8. **Verify rendering**: Regenerate HTML and confirm message images appear alongside their text content.

## Data Statistics

| Metric | Value |
|--------|-------|
| Total messages in export | 1,081 |
| Messages with `msgtype: "m.image"` | ~167 |
| Poems currently showing "image.png" | 16 |
| Poems showing other filenames | ~151 (some may have text + image) |
| Image files in ZIP archive | 166 |
| Affected percentage of messages corpus | ~15.4% |

**Why only 16 "image.png" poems when there are 167 image messages?** Many image messages may have filenames other than "image.png" (e.g., `"20240706_212649.jpg"`, `"screenshot-2024.png"`) — these are also media-only but show a different filename string. The 16 poems in the user's similarity ranking are just the ones that share the exact same "image.png" string and therefore cluster together in similarity.

## Edge Cases

1. **Messages with text AND image**: Some Matrix messages might have `msgtype: "m.image"` but also contain a meaningful caption in `body`. The filename heuristic (`body:match("^%S+%.%w+$")`) handles this — a real caption won't match a bare filename pattern.

2. **ID stability**: Skipped media messages must still increment the ID counter (`i = i + 1`) to preserve tombstoning — existing poem IDs must not shift.

3. **Re-running embeddings**: After filtering, the poems.json changes and any existing embeddings for the removed poems become stale. The embedding pipeline should detect the poem count change and offer to regenerate.

4. **Other media types**: Matrix supports `m.video`, `m.audio`, `m.file` — these should all be filtered using the same logic. A video message with body "recording.mp4" is equally meaningless as text.

## Related Documents

- `scripts/extract-messages.lua` — Messages extraction script (200 lines, the file being modified)
- `scripts/extract-fediverse.lua:440-478` — Fediverse attachment extraction (reference implementation)
- `src/poem-extractor.lua` — Poem loading with image-only filtering
- `input/messages/` — Raw message backup directory
- `issues/completed/6-031-configurable-poem-exclusion-filter.md` — Exclusion filter (could be used as interim workaround)

## Metadata

- **Status**: Open
- **Created**: 2026-01-26
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Low (Phase A), Medium (Phase B)
- **Dependencies**: None
- **Affects**: Messages poem count, similarity rankings, embedding space quality
