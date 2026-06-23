# 10-042d: Gallery Chronological Image List

## Parent Issue

10-042: Integrate Standalone Images Into Site

## Related Issues

- 10-042a: Gallery Pages (the per-source gallery grids; this adds a new view)
- 10-042b: Chronological Interleaving (images mixed INTO the poem timeline — a
  different page; this one is images-only)
- 9-013: Image pseudo-embeddings (shares the source-qualified title helper)

## Current Behavior

The gallery (`gallery/index.html`) has a "chronological" link in its top nav, but
it does not lead to an images-only chronological view. Images are browsable only
per-source as grids (10-042a). There is no single page that walks every image
from every gallery source in time order.

## Intended Behavior

A new page lists EVERY image from ALL gallery sources in chronological order (by
image timestamp — `modification_time` from `image-catalog.json`, the same field
10-042b uses). Reached from the gallery's "chronological" link.

The page is a vertical scroll of images separated by caption blocks. Each caption
block sits BETWEEN two images and names both: the image above it and the image
below it. Consequently every image's title appears twice — once as the "below"
title of the block above it, and once as the "above" title of the block beneath
it. This gives a reader scrolling in either direction a label for what they just
passed and what is coming next.

### Exact layout

For images A, B, C … in chronological order, the page reads top to bottom:

```
            [ image A ]
──────────────────────────────────────────
(blank line)
my-art: air-defence-drones-5.png            <- title of image ABOVE (A)
(blank line)
my-art: game-design: camera-idea.png        <- title of image BELOW (B)
(blank line)
──────────────────────────────────────────
            [ image B ]
──────────────────────────────────────────
(blank line)
my-art: game-design: camera-idea.png        <- title of image ABOVE (B)
(blank line)
poem-pictures: sunset-over-water.png        <- title of image BELOW (C)
(blank line)
──────────────────────────────────────────
            [ image C ]
            ...
```

So each between-images block is exactly:

```
<separator>
<blank>
<title of the image above>
<blank>
<title of the image below>
<blank>
<separator>
```

The first block (above the first image) has no "above" title; the last block
(below the last image) has no "below" title.

### Title format ("full path", colon-joined)

A title is the image's source name followed by any nested subdirectories and the
filename, joined with `": "` instead of slashes:

- top-level image: `my-art: air-defence-drones-5.png`
- nested image:    `my-art: game-design: camera-idea.png`

Derived from the catalog entry's `source_name` plus the portion of its
`relative_path` below the source directory, with `/` replaced by `: `. This same
helper is used by Issue 9-013 for image entries on similar/different pages — write
it once and share it.

### Constraints

- Pure static HTML, CSS-free, consistent with the rest of the site (no JavaScript).
- Images use the corrected `input/images/...` paths (see the gallery path fix), so
  they actually render.
- All standalone sources included (my-art, poem-pictures, things-I-almost-posted,
  dnd-pictures-from-the-internet, fediverse-stars). Whether to include
  `fediverse-media` (poem attachments) is a generation toggle — default off, since
  those already appear with their poems.

## Suggested Implementation Steps

1. **Shared title helper**: `qualified_image_title(catalog_entry)` →
   `"source: sub: name.ext"`. Place where both the gallery generator and the
   pseudo-embedding renderer (9-013) can call it. Reuse `extract_display_name`
   logic where sensible.
2. **Chronological ordering**: collect catalog images (excluding fediverse-media
   by default), sort by `modification_time`. Reuse the ordering rationale from
   10-042b (randomized sources already have scattered timestamps).
3. **Page generator**: emit image + between-block sequence per the layout above.
   Generate to `gallery/chronological.html` (or wherever the gallery nav points).
4. **Wire the nav link**: the gallery's existing "chronological" link targets this
   page.
5. **Verify** after a regeneration: titles appear twice, paths are colon-joined,
   nested dirs show their subdir segment, images render.

## Data Sources / Tools

- `assets/image-catalog.json` — `source_name`, `relative_path`, `modification_time`
- `src/generate-gallery-pages.lua` — gallery generation, `extract_display_name`,
  `SOURCE_TITLES`/`SOURCE_SLUGS`
- `src/image-manager.lua` — catalog construction

## Metadata

- **Status**: 📋 Specced, not started
- **Created**: 2026-06-22
- **Phase**: 10 (Integrate Standalone Images)
- **Estimated Complexity**: Low–Medium (new static page + one shared helper)
- **Dependencies**: gallery path fix (so images render); shares title helper with 9-013
