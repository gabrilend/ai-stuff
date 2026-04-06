# 10-042a: Gallery Pages

## Parent Issue

10-042: Integrate Standalone Images Into Site

## Current Behavior

Image-catalog.json contains 664 standalone images across 5 sources, but no gallery pages exist to display them.

## Intended Behavior

Generate HTML gallery pages for each image source:
- `output/gallery/index.html` - Lists all sources with representative thumbnails
- `output/gallery/my-art.html` - 135 images
- `output/gallery/things-i-almost-posted.html` - 120 images
- `output/gallery/poem-pictures.html` - 211 images
- `output/gallery/dnd-pictures.html` - 82 images
- `output/gallery/fediverse-stars.html` - 116 images

Add "Gallery" navigation link to wordcloud.html menu.

## Suggested Implementation Steps

### Step 1: Create src/generate-gallery-pages.lua

New module following existing patterns:
- Vimfolds for function organization
- DIR variable at top for path independence
- Load image-catalog.json via utils.read_json_file()
- Filter to exclude `fediverse-media` source

```lua
-- {{{ local function load_standalone_images
local function load_standalone_images()
    local catalog = utils.read_json_file(DIR .. "/assets/image-catalog.json")
    local standalone = {}
    for _, img in ipairs(catalog.images) do
        if img.source_name ~= "fediverse-media" then
            table.insert(standalone, img)
        end
    end
    return standalone
end
-- }}}
```

### Step 2: Generate gallery page HTML

Grid layout using HTML tables (4 columns):
```html
<table>
  <tr>
    <td><a href="full-image.png"><img src="thumb.png" loading="lazy" width="200"></a></td>
    ...
  </tr>
</table>
```

Match site style:
- `bgcolor="#000000"`
- White text
- Centered layout
- Navigation header with Menu link

### Step 3: Generate gallery index page

Lists all sources with:
- Source name as heading
- Image count
- Representative thumbnail
- Link to source gallery page

### Step 4: Add Gallery link to wordcloud.html

Modify `src/wordcloud-generator.lua` line 374:
```lua
'<p><a href="explore.html">Explore</a> │ <a href="chronological/index.html">Chronological Index</a> │ <a href="gallery/index.html">Gallery</a></p>'
```

### Step 5: Add to main.lua menu

Add gallery generation option to CLI menu.

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/generate-gallery-pages.lua` | CREATE |
| `src/wordcloud-generator.lua` | MODIFY (line 374) |
| `src/main.lua` | MODIFY (add menu option) |

## Acceptance Criteria

- [ ] Gallery index page at `output/gallery/index.html`
- [ ] Individual gallery page for each of 5 sources
- [ ] Images displayed in grid with lazy loading
- [ ] Click on image opens full-size version
- [ ] "Gallery" link in wordcloud.html navigation
- [ ] fediverse-media excluded from galleries

## Dependencies

- Issue 6-017: Image integration system (provides image-catalog.json)

## Status

**COMPLETED** - 2026-04-06

---

## Implementation Progress

### 2026-04-06: Completed

**Created:**
- `src/generate-gallery-pages.lua` - Gallery page generator (~350 lines)
  - Loads image-catalog.json and filters to standalone images only
  - Groups images by source (my-art, poem-pictures, things-i-almost-posted, dnd-pictures, fediverse-stars)
  - Generates grid layout using HTML tables with lazy-loaded thumbnails
  - Creates index page with representative thumbnails and image counts
  - Creates per-source gallery pages with 4-column grid layout
  - Follows existing patterns: vimfolds, config loading, dark theme

**Modified:**
- `src/wordcloud-generator.lua` (line 374) - Added "Gallery" link to navigation menu

**Output files generated:**
- `output/gallery/index.html` - Gallery index (664 images, 5 collections)
- `output/gallery/my-art.html` - 135 images
- `output/gallery/things-i-almost-posted.html` - 120 images
- `output/gallery/poem-pictures.html` - 211 images
- `output/gallery/dnd-pictures.html` - 82 images
- `output/gallery/fediverse-stars.html` - 116 images

**Features:**
- Excludes fediverse-media (520 images inline with poems)
- Lazy loading for performance
- Click thumbnail to view full-size image
- Filename extracted as alt text
- Responsive to html_theme config
