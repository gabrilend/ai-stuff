# Issue 8-005: Integrate Images into HTML Output

## Current Behavior

The image cataloging system (implemented in Issue 6-017) successfully discovers and catalogs all images:
- 539 total images cataloged in `assets/image-catalog.json`
- 532 images from media_attachments (fediverse content)
- 7 images from docs directory
- 526 unique images with full metadata (dimensions, hashes, timestamps)

**However**, the `src/flat-html-generator.lua` does not render any images in the HTML output. The image catalog exists but is never consumed during HTML generation. Generated poem pages contain text only - no `<img>` tags are present.

**Current output**: Text-only HTML pages with no visual media.

## Intended Behavior

Generated HTML pages should include associated images where applicable:

1. **Image Placement**: Images should appear alongside their associated poems
2. **Image Association**: Use poem metadata to link images to their source posts
3. **Responsive Display**: Images should fit within the 80-character-width aesthetic
4. **Lazy Loading**: Consider bandwidth by using lazy loading attributes
5. **Alt Text**: Include descriptive alt text for accessibility

**Expected HTML structure per poem with image**:
```html
<pre>
 ════════════════════════════════════════════════────────────────────────────────

                              poem text goes here

 ════════════════════════════════════════════════────────────────────────────────
</pre>
<img src="images/abc123.jpg" alt="Image attachment" loading="lazy">
<pre>
similar | different
</pre>
```

## Suggested Implementation Steps

### Step 1: Load Image Catalog in HTML Generator
- [ ] Add image catalog loading function to `src/flat-html-generator.lua`
- [ ] Parse `assets/image-catalog.json` at startup
- [ ] Create lookup table mapping image paths to metadata

### Step 2: Create Image-to-Poem Association
- [ ] Parse poem source URLs/IDs to match media_attachments paths
- [ ] Build association map: poem ID -> image(s)
- [ ] Handle poems with multiple images
- [ ] Handle poems with no images (majority case)

### Step 3: Implement Image Rendering Function
- [ ] Create `render_image_html(image_entry)` function
- [ ] Generate `<img>` tag with appropriate attributes
- [ ] Include dimensions for proper layout reservations
- [ ] Add `loading="lazy"` for performance

### Step 4: Integrate into Poem Rendering Pipeline
- [ ] Modify `format_poem_entry()` to check for associated images
- [ ] Insert image HTML after poem content, before navigation links
- [ ] Ensure images appear in chronological.html, similar/, and different/ pages

### Step 5: Handle Image Paths for Deployment
- [ ] Determine image output directory structure
- [ ] Copy/link images to output directory during generation
- [ ] Use relative paths suitable for Neocities deployment

## Dependencies

- **Issue 6-017**: Implement image integration system (COMPLETED - catalog exists)
- Requires `assets/image-catalog.json` to exist
- Requires `assets/poems.json` with source metadata

## Quality Assurance Criteria

- [ ] Poems with associated images display those images in HTML output
- [ ] Images appear in all page types (chronological, similar/, different/)
- [ ] Images use lazy loading for performance
- [ ] Image paths work correctly for static deployment
- [ ] No broken image links in generated output
- [ ] Poems without images render correctly (no empty img tags)

## Related Issues

- **Issue 6-017**: Implement image integration system (provides catalog)
- **Issue 8-001**: Integrate complete HTML generation into pipeline

## Technical Notes

**Image catalog structure** (from `assets/image-catalog.json`):
```json
{
  "file_path": "/path/to/image.jpg",
  "relative_path": "input/extract/media_attachments/...",
  "filename": "image.jpg",
  "extension": "jpg",
  "size_bytes": 123456,
  "width": 800,
  "height": 600,
  "hash": "abc123...",
  "source_directory": "input/extract/media_attachments"
}
```

**Association strategy**: Fediverse posts reference images via `attachment` field in original JSON. The extraction scripts preserve this relationship - need to trace path from poem back to source post to find attachments.

---

**ISSUE STATUS: OPEN**

**Created**: 2025-12-15

**Phase**: 8 (Website Completion)
