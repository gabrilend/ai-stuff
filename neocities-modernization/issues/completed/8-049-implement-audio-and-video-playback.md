# Issue 8-049: Implement Audio and Video Playback in HTML Pages

## Priority
Medium

## Current Behavior

The HTML generator only renders `<img>` tags for image attachments. Audio and video files are:
1. Extracted from ActivityPub archives ✓
2. Copied to `output/media/` directory ✓
3. **Not rendered in HTML pages** ✗

**Media types in dataset:**
| Type | Count | Currently Rendered |
|------|-------|-------------------|
| PNG | 485 | ✓ `<img>` |
| JPEG | 29 | ✓ `<img>` |
| JPG | 10 | ✓ `<img>` |
| WEBP | 9 | ✓ `<img>` |
| MP4 | 9 | ✗ Ignored |
| MP3 | 4 | ✗ Ignored |

**Code that filters to images only** (`flat-html-generator.lua`):
```lua
if media_type:match("^image/") then
    -- Only images are rendered
end
```

## Intended Behavior

All media types should be rendered with appropriate HTML5 elements:

### Audio Files (MP3, OGG, WAV)
```html
<audio controls preload="metadata" style="display:block; max-width:100%">
  <source src="/similar-different/media/3482997f23aeb1cb.mp3" type="audio/mpeg">
  Your browser does not support the audio element.
</audio>
```

### Video Files (MP4, WEBM)
```html
<video controls preload="metadata" style="display:block; max-width:min(100%,800px); height:auto">
  <source src="/similar-different/media/0abcae28f5be3163.mp4" type="video/mp4">
  Your browser does not support the video element.
</video>
```

**Key attributes:**
- `controls`: Shows play/pause, volume, seek bar
- `preload="metadata"`: Only loads metadata initially (not full file) for performance
- `style`: Consistent with image styling for responsive layout

## Technical Analysis

### Media Type Mapping

| MIME Type | Extension | HTML Element |
|-----------|-----------|--------------|
| `image/*` | png, jpg, jpeg, webp, gif | `<img>` |
| `audio/mpeg` | mp3 | `<audio>` |
| `audio/ogg` | ogg | `<audio>` |
| `audio/wav` | wav | `<audio>` |
| `video/mp4` | mp4 | `<video>` |
| `video/webm` | webm | `<video>` |

### Files to Modify

The same 3 locations that handle image rendering need to be extended:

1. **`render_attachment_images()` function** (~line 1252-1300)
   - Rename to `render_attachments()` for clarity
   - Add `elseif media_type:match("^audio/")` branch
   - Add `elseif media_type:match("^video/")` branch

2. **Worker thread `render_attachments()` helper** (~line 3243-3267)
   - Add audio/video handling

3. **Worker thread direct rendering** (~line 3287-3305)
   - Add audio/video handling

### Attachment Structure Reference

From ActivityPub extraction:
```lua
{
    media_type = "video/mp4",           -- or "audio/mpeg"
    url = "https://server.com/...",
    relative_path = "files/112/.../abc.mp4",
    description = "Alt text",            -- may be nil
    width = 1920,                        -- video only, may be nil
    height = 1080                        -- video only, may be nil
}
```

## Suggested Implementation Steps

1. **Update `render_attachment_images()` in main scope**:
   ```lua
   local function render_attachments(attachments)
       -- ... existing setup ...

       for _, attachment in ipairs(attachments) do
           local media_type = attachment.media_type or ""
           local basename = (attachment.relative_path or ""):match("([^/]+)$") or ""
           local src = base_path .. "/output/media/" .. basename

           if media_type:match("^image/") then
               -- Existing image handling
               table.insert(html, render_image_tag(src, attachment))
           elseif media_type:match("^audio/") then
               table.insert(html, render_audio_tag(src, media_type))
           elseif media_type:match("^video/") then
               table.insert(html, render_video_tag(src, media_type, attachment))
           end
       end
   end
   ```

2. **Add audio tag helper**:
   ```lua
   local function render_audio_tag(src, media_type)
       return string.format([[
     <audio controls preload="metadata" style="display:block; max-width:100%%">
       <source src="%s" type="%s">
       Your browser does not support audio.
     </audio>]], src, media_type)
   end
   ```

3. **Add video tag helper**:
   ```lua
   local function render_video_tag(src, media_type, attachment)
       local width_attr = ""
       local height_attr = ""
       if attachment.width and attachment.height then
           width_attr = string.format(' width="%d"', attachment.width)
           height_attr = string.format(' height="%d"', attachment.height)
       end
       return string.format([[
     <video controls preload="metadata" style="display:block; max-width:min(100%%,800px); height:auto"%s%s>
       <source src="%s" type="%s">
       Your browser does not support video.
     </video>]], width_attr, height_attr, src, media_type)
   end
   ```

4. **Replicate in worker thread** (inline, since workers can't access main scope functions)

5. **Update convert-urls if needed**:
   - Should already work since media paths use same pattern
   - Verify audio/video sources are converted correctly

6. **Test with sample posts**:
   - Find poems with audio/video attachments
   - Verify playback works in browser
   - Check mobile responsiveness

## Sample Test Data

Audio files in dataset:
- `3482997f23aeb1cb.mp3`
- `34fd5f8e19ec7e61.mp3`
- `66d6a6bdf50b343b.mp3`

Video files in dataset:
- `0abcae28f5be3163.mp4`
- `253e966f52f665b3.mp4`
- `3292df3dfdbbcccf.mp4`

## Accessibility Considerations

- Audio/video elements have native browser controls (keyboard accessible)
- Consider adding `<track>` elements for captions if available in ActivityPub data
- Alt-text from `attachment.description` could be shown as fallback text

## Related Issues

- Issue 8-040: Add Images to Similar/Different Pages (established attachment rendering pattern)
- Issue 8-048: Flatten Media Directory (media files already in correct location)

## Implementation Progress

### 2026-01-28: Complete Implementation

**Changes to `src/flat-html-generator.lua`:**

1. **Updated `render_attachment_images()` (lines 1234-1345)**:
   - Now handles `audio/*` and `video/*` MIME types in addition to `image/*`
   - Audio: `<audio controls preload="metadata">` with `<source>` element
   - Video: `<video controls preload="metadata">` with optional width/height
   - All media rendered outside `<pre>` tags for proper max-width behavior

2. **Updated `render_attachment_images_txt()` (lines 1348-1400)**:
   - Returns `[Audio: filename.mp3]` placeholders for audio
   - Returns `[Video: filename.mp4]` placeholders for video
   - Matches existing `[Image: alt-text]` pattern for TXT exports

3. **Updated worker thread media rendering (lines 3282-3359)**:
   - Collects all renderable media types (image, audio, video)
   - Renders appropriate HTML5 element for each type
   - Maintains consistency with main scope implementation

**HTML5 elements generated:**

```html
<!-- Audio -->
<audio controls preload="metadata" style="display:block; max-width:100%">
  <source src="/.../media/3482997f23aeb1cb.mp3" type="audio/mpeg">
  Your browser does not support the audio element.
</audio>

<!-- Video -->
<video controls preload="metadata" width="720" height="1280"
       style="display:block; max-width:min(100%,800px); height:auto">
  <source src="/.../media/0abcae28f5be3163.mp4" type="video/mp4">
  Your browser does not support the video element.
</video>
```

**Test files available:**
- 4 MP3 files (audio/mpeg)
- 6+ MP4 files (video/mp4)

## Metadata

- **Status**: Completed
- **Created**: 2026-01-23
- **Completed**: 2026-01-28
- **Phase**: 8 (Website Completion / HTML Generation)
- **Estimated Complexity**: Low-Medium
- **Dependencies**: Issue 8-048 (complete)
- **Affects**: 13 posts (9 video + 4 audio)
