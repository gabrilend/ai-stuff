# 10-042b: Chronological Interleaving

## Parent Issue

10-042: Integrate Standalone Images Into Site

## Current Behavior

Chronological.html displays only poems. Standalone images from image-catalog.json are not shown.

## Intended Behavior

Standalone images appear interleaved with poems in chronological.html:
- Images sorted by `modification_time` from catalog
- `randomize_order = true` sources (dnd-pictures, fediverse-stars) already have scattered timestamps
- `randomize_order = false` sources (my-art, poem-pictures, things-i-almost-posted) use actual file timestamps
- Images display with simplified navigation (gallery link only, no similar/different)

## Suggested Implementation Steps

### Step 1: Create pseudo-poem structure for images

Add function to `src/flat-html-generator.lua`:

```lua
-- {{{ local function create_image_pseudo_poems
local function create_image_pseudo_poems(image_catalog)
    local pseudo_poems = {}
    for _, img in ipairs(image_catalog.images) do
        if img.source_name ~= "fediverse-media" then
            table.insert(pseudo_poems, {
                type = "standalone_image",
                pseudo_id = string.format("img-%s-%s",
                    img.source_name:gsub("[^%w]", ""),
                    img.hash:sub(1, 8)),
                creation_date = os.date("!%Y-%m-%dT%H:%M:%SZ", img.modification_time),
                modification_time = img.modification_time,
                source_name = img.source_name,
                filename = img.filename,
                display_name = filename_to_display_name(img.filename),
                attachments = {{
                    url = img.relative_path,
                    media_type = "image/" .. img.extension,
                    width = img.width,
                    height = img.height,
                }},
                is_standalone_image = true,
            })
        end
    end
    return pseudo_poems
end
-- }}}
```

### Step 2: Merge with poems and sort

Modify chronological generation to:
1. Load poems from poems.json
2. Load image catalog
3. Create pseudo-poems for standalone images
4. Merge both lists
5. Sort by creation_date/modification_time

### Step 3: Render standalone images in chronological loop

Detect `is_standalone_image` flag and render differently:
- Header: ` -> image: source/filename.png`
- Display image using existing `render_media_attachment()` pattern
- Navigation: Link to source gallery only (no similar/different)

```
 -> image: my-art/sunset-over-mountains.png
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  [IMAGE]                                                                     │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                              gallery: my-art                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Step 4: Generate anchor IDs for images

Use pseudo_id format for HTML anchors:
```html
<span id="img-myart-a144e809"></span>
```

## Files to Modify

| File | Changes |
|------|---------|
| `src/flat-html-generator.lua` | Add pseudo-poem creation, modify chronological loop |
| `src/image-manager.lua` | Add `filename_to_display_name()` helper |

## Acceptance Criteria

- [ ] Standalone images appear in chronological.html
- [ ] Images sorted correctly by timestamp among poems
- [ ] `randomize_order` sources scattered throughout timeline
- [ ] Non-randomized sources appear at their actual file dates
- [ ] Each image has gallery navigation link
- [ ] Images have unique anchor IDs

## Dependencies

- Issue 10-042a: Gallery pages (must exist for navigation links)
- Issue 10-030: Randomization (provides scattered timestamps)

## Status

**OPEN** - Created 2026-03-23
