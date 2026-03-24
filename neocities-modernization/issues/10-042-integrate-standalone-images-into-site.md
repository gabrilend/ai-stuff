# 10-042: Integrate Standalone Images Into Site

## Current Behavior

The image-manager (`src/image-manager.lua`) catalogs standalone images from configured directories into `assets/image-catalog.json`, but this catalog is never consumed for display. Images exist in:

| Source | Count | Path | Has `randomize_order` |
|--------|-------|------|----------------------|
| poem-pictures | 211 | input/media_attachments/poem-pictures | No |
| my-art | 135 | input/media_attachments/my-art | No |
| things-I-almost-posted | 120 | input/media_attachments/things-i-almost-posted | No |
| fediverse-stars | 116 | input/media_attachments/fediverse-stars | Yes |
| dnd-pictures-from-the-internet | 82 | input/media_attachments/dnd-pictures | Yes |
| **Total standalone** | **664** | | |

**Excluded from this issue:**
- `fediverse-media` (520 images) - already attached to poems inline via ActivityPub extraction
- Message attachments - inline with messages, not in image catalog

## Intended Behavior

### 1. Gallery Pages (one per source)

Each image source gets a dedicated gallery page:
- `output/gallery/my-art.html`
- `output/gallery/things-i-almost-posted.html`
- `output/gallery/poem-pictures.html`
- `output/gallery/dnd-pictures.html`
- `output/gallery/fediverse-stars.html`
- `output/gallery/index.html` (lists all sources)

Gallery page features:
- Grid layout using HTML tables (matches site style)
- Lazy-loading thumbnails (max 200px)
- Click to view full-size
- Filename as alt-text
- Navigation back to main site

### 2. Menu Link from Chronological Pages

Add "Gallery" link to wordcloud.html navigation:
```
┌────────────────────────────────────────────────────────┐
│  explore  │  chronological  │  gallery  │             │
└────────────────────────────────────────────────────────┘
```

### 3. Chronological Interleaving by Timestamp

Images interleaved into chronological.html:
- Create pseudo-poems from image catalog entries
- Sort by `modification_time` from catalog
- `randomize_order = true` sources already have scattered timestamps (Issue 10-030)
- `randomize_order = false` sources use actual file timestamps
- Navigation shows "gallery" link only (no similar/different until Phase C)

### 4. Similar/Different Integration via Filename Embedding

Generate text embeddings from image filenames:
- Extract display name: `sunset-over-mountains.png` → `"sunset over mountains"`
- Generate embeddings via Ollama (same pipeline as poems)
- Use ID format: `img-{source}-{hash8}` (avoids breaking poem_index sequence)
- Images appear in similar/different rankings for poems
- Future: Vision model or OCR-based embeddings for richer semantics

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| ID format | `img-{source}-{hash8}` | Avoids breaking existing poem_index/cache structure |
| Exclude fediverse-media | Yes | Already attached to poems inline |
| Exclude messages attachments | N/A | Not in image catalog (inline with messages) |
| Gallery layout | Grid thumbnails (HTML tables) | Matches site style, no CSS dependencies |
| Chronological nav for images | Gallery link only | No semantic data until Phase C |
| Anchor support | Deferred to Phase C | Rankings first, then full anchor pages |

## Sub-Issues

| Issue | Description | Depends On |
|-------|-------------|------------|
| 10-042a | Gallery Pages | None |
| 10-042b | Chronological Interleaving | 10-042a |
| 10-042c | Filename Embeddings | 10-042b |

## Files to Modify

| File | Phase | Changes |
|------|-------|---------|
| `src/generate-gallery-pages.lua` | A | NEW - gallery generation |
| `src/wordcloud-generator.lua` | A | Add Gallery nav link (line 374) |
| `src/image-manager.lua` | C | Add `filename_to_display_name()` |
| `src/flat-html-generator.lua` | B | Chronological interleaving |
| `src/similarity-engine.lua` | C | Image embedding generation |
| `config.lua` | A | Gallery config section (optional) |

## Dependencies

- Issue 6-017: Image integration system (COMPLETED - provides image-catalog.json)
- Issue 10-030: Image source position randomization (COMPLETED - provides randomize_order)
- Issue 10-015a: Image-manager sources-loader migration (COMPLETED)

## Related Issues

- Issue 8-005: Integrate images into HTML output (poem attachments, not standalone)
- Issue 9-013: Image-only post timestamp association (fediverse posts, not standalone)

## Acceptance Criteria

- [ ] Gallery page exists for each image source (5 pages)
- [ ] Gallery index page lists all sources
- [ ] "Gallery" link appears in wordcloud.html navigation
- [ ] Standalone images appear in chronological.html by timestamp
- [ ] Images in chronological have "gallery" navigation link
- [ ] Filename embeddings generated for all 664 standalone images
- [ ] Images appear in similar/different rankings based on embedding similarity
- [ ] `randomize_order` flag respected for timeline placement

## Status

**OPEN** - Created 2026-03-23, Planning completed 2026-03-23
