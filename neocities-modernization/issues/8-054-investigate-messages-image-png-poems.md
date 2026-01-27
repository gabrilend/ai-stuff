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

### Decision

**Extract the images — don't tombstone them.** Every image the user sent to themselves was worth saving. The poems should keep their IDs and gain proper image attachments instead of displaying bare filenames. Media-only messages become image poems with `[Image]` placeholder content (matching the pattern established by fediverse image-only posts).

## Suggested Implementation Steps

1. **Add msgtype detection** to `scripts/extract-messages.lua` inside the extraction loop (after line 153). Detect `m.image`, `m.video`, `m.audio`, and `m.file` message types:
   ```lua
   local content = value.content.body or " "
   local msgtype = value.content.msgtype
   ```

2. **Build a filename-to-local-path lookup** from the ZIP extract's `images/` subdirectory. The Matrix export stores decrypted images alongside `export.json`:
   ```lua
   -- Scan images/ directory in the extract for local files
   local function build_image_lookup(extract_dir)
       local lookup = {}
       local images_dir = extract_dir .. "/images"
       local handle = io.popen('ls "' .. images_dir .. '" 2>/dev/null')
       if handle then
           for filename in handle:lines() do
               lookup[filename] = images_dir .. "/" .. filename
           end
           handle:close()
       end
       return lookup
   end
   ```

3. **For media messages, extract attachment metadata** and add it to the poem entry (matching fediverse attachment format):
   ```lua
   if msgtype == "m.image" or msgtype == "m.video"
      or msgtype == "m.audio" or msgtype == "m.file" then
       local filename = value.content.body or ""
       local local_path = image_lookup[filename]
       local attachment = {
           media_type = (value.content.info and value.content.info.mimetype) or "image/png",
           width = value.content.info and value.content.info.w,
           height = value.content.info and value.content.info.h,
           alt_text = nil,  -- Matrix doesn't provide alt-text
           relative_path = local_path
       }
       poem_entry.attachments = { attachment }

       -- Replace bare filename content with descriptive placeholder
       -- so the poem has meaningful display text and a non-trivial embedding
       if filename:match("^%S+%.%w+$") then
           content = "[Image: " .. filename .. "]"
           poem_entry.content = content
           poem_entry.raw_content = content
       end
   end
   ```

4. **Ensure the image sync pipeline** copies message images to the output `media/` directory alongside fediverse images. Update `scripts/sync-images` (or the relevant image sync step in `run.sh`) to include the messages extract `images/` directory as a source.

5. **Add image statistics** to the extraction summary:
   ```lua
   local image_count = 0
   -- ... in the loop, after adding attachment:
   image_count = image_count + 1
   -- ... in summary:
   print("   🖼️  Image messages: " .. image_count)
   ```

6. **Update the extraction summary JSON** to include `image_messages` count and `attachment_statistics` (matching the fediverse extraction summary format).

7. **Test the full pipeline**:
   - Re-run messages extraction and verify:
     - Image messages now have an `attachments` array in poems.json
     - Content shows `[Image: filename.png]` instead of bare `image.png`
     - Image count is reported in extraction summary
   - Re-run image sync and verify message images are copied to `output/media/`
   - Re-run HTML generation and verify message images render inline (like fediverse images)
   - Check that similarity rankings no longer cluster identical "image.png" poems together

8. **Handle mixed messages** (text + image): Some messages may have `msgtype: "m.image"` but contain a meaningful caption in `body` (not just a filename). The filename check (`body:match("^%S+%.%w+$")`) distinguishes these — captions contain spaces and don't match, so they keep their original content while also gaining the attachment.

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

1. **Messages with text AND image**: Some Matrix messages might have `msgtype: "m.image"` but also contain a meaningful caption in `body`. The filename heuristic (`body:match("^%S+%.%w+$")`) handles this — a real caption won't match a bare filename pattern, so the caption is preserved as content while the image attachment is also added.

2. **ID stability**: All messages keep their IDs — no poems are removed, so no tombstoning is needed. Image messages gain attachments and updated content but retain their position in the ID sequence.

3. **Re-running embeddings**: After extraction changes, the poems.json content differs (e.g., `"image.png"` → `"[Image: image.png]"`) so existing embeddings become stale. The embedding pipeline should detect the content change and regenerate affected embeddings.

4. **Other media types**: Matrix supports `m.video`, `m.audio`, `m.file` — these should all have their attachment metadata extracted using the same pattern. A video message gains an attachment entry even if it can't be rendered inline yet.

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
