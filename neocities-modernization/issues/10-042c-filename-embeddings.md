# 10-042c: Filename Embeddings

## Parent Issue

10-042: Integrate Standalone Images Into Site

## Current Behavior

Embeddings are generated only for poem text content. Standalone images have no semantic representation and cannot appear in similar/different rankings.

## Intended Behavior

Generate text embeddings from image filenames:
- Extract display name: `sunset-over-mountains.png` → `"sunset over mountains"`
- Generate embeddings via Ollama (same pipeline as poems)
- Store with ID format: `img-{source}-{hash8}`
- Images appear in similar/different rankings based on embedding similarity

## Suggested Implementation Steps

### Step 1: Add filename_to_display_name() to image-manager.lua

```lua
-- {{{ function M.filename_to_display_name
function M.filename_to_display_name(filename)
    -- "sunset-over-mountains.png" -> "sunset over mountains"
    local name = filename:gsub("%.[^.]+$", "")  -- Remove extension
    name = name:gsub("[-_]", " ")               -- Dashes/underscores to spaces
    name = name:gsub("%s+", " ")                -- Collapse multiple spaces
    name = name:match("^%s*(.-)%s*$")           -- Trim whitespace
    return name
end
-- }}}
```

### Step 2: Add get_standalone_images_for_embedding()

```lua
-- {{{ function M.get_standalone_images_for_embedding
function M.get_standalone_images_for_embedding()
    local catalog = load_catalog()
    local images = {}
    for _, img in ipairs(catalog.images) do
        if img.source_name ~= "fediverse-media" then
            table.insert(images, {
                id = string.format("img-%s-%s",
                    img.source_name:gsub("[^%w]", ""),
                    img.hash:sub(1, 8)),
                content = M.filename_to_display_name(img.filename),
                source_name = img.source_name,
                filename = img.filename,
            })
        end
    end
    return images
end
-- }}}
```

### Step 3: Modify similarity-engine.lua to include images

After generating poem embeddings:
1. Load standalone images via `get_standalone_images_for_embedding()`
2. Generate embeddings for each image's display_name
3. Store in embeddings.json with `img-` prefixed IDs
4. Include in similarity matrix calculation

### Step 4: Update similarity/different page generation

When generating rankings:
- Include image embeddings in similarity calculation
- Images can appear in poem's similar/different rankings
- Display format for images in rankings:
  ```
  --- #5 [IMAGE: my-art/sunset.png] ---
  [thumbnail]
  ║ gallery: my-art ║
  ```

### Step 5: (Future) Add similar/different pages for images

Once embeddings exist, images can be anchors:
- `similar/img-myart-a144e809-01.html`
- `different/img-myart-a144e809-01.html`

This is deferred - implement only if needed.

## Files to Modify

| File | Changes |
|------|---------|
| `src/image-manager.lua` | Add `filename_to_display_name()`, `get_standalone_images_for_embedding()` |
| `src/similarity-engine.lua` | Include images in embedding generation |
| `src/flat-html-generator.lua` | Render images in similar/different rankings |

## Future Enhancements

### Vision Model Embedding
Instead of filename-only embedding, use multimodal model:
1. Generate image description via LLaVA, Claude Vision, etc.
2. Embed the generated description
3. Much richer semantic understanding than filename

### OCR-Based Embedding
For images containing text (screenshots, memes):
1. Run OCR (tesseract or similar)
2. Embed extracted text
3. Useful for text-heavy images

## Acceptance Criteria

- [ ] `filename_to_display_name()` correctly extracts readable names
- [ ] Embeddings generated for all 664 standalone images
- [ ] Image embeddings stored in embeddings.json with `img-` prefix
- [ ] Images appear in poem similarity/different rankings
- [ ] Image display in rankings shows thumbnail + gallery link

## Dependencies

- Issue 10-042b: Chronological interleaving (images must have pseudo-poem structure)

## Status

**OPEN** - Created 2026-03-23
