# image-pseudo-embeddings.info.md

Pure helper for Issue 9-013 (redesign): synthesize a "pseudo-embedding" for an
image from the poems that bracket it in time, so the image can be ranked on
similar/different pages like a poem. No I/O, no GPU, no date parsing — the
pipeline caller supplies numeric timestamps and joined embeddings.

## Concept

An image has no semantic vector of its own. We place it at its timestamp in the
chronological order of text poems and synthesize its embedding by CROSS-CUTTING
its two temporal neighbours: the leading dimensions come from the poem before it,
the trailing dimensions from the poem after it (a "crooked" cut, not an average).
We do this because averaging two unit vectors smooths them toward the corpus
centre (measured +12% closer to the centroid), turning images into hubs that
flood every poem's similar list; the cross-cut keeps each dimension's full
real-poem magnitude and stays at the normal baseline centrality. Because
nomic-embed-text-v1.5 is a Matryoshka model (leading dims carry coarse meaning),
the seam reads as "the image takes its subject from the poem before and its
texture from the poem after." At the timeline ends only one neighbour exists, so
the single side is used.

## External functions

### `M.qualified_image_title(source_name, rel_below_source) -> string`
- Builds the colon-joined "full path" title shared with Issue 10-042d.
- `source_name`: gallery source (e.g. `"my-art"`).
- `rel_below_source`: the image path below the source dir (subdirs + filename,
  `/`-separated). Leading slashes tolerated.
- Returns e.g. `"my-art: air-defence-drones-5.png"` or, nested,
  `"my-art: game-design: camera-idea.png"`. If `rel_below_source` is empty,
  returns just `source_name`.

### `M.find_chrono_neighbors(sorted_poems, t) -> before, after`
- `sorted_poems`: array sorted ASCENDING by `.timestamp`, each `{ timestamp,
  embedding, ... }`.
- `t`: target numeric timestamp.
- Returns the nearest poem at-or-before and at-or-after `t` (either may be `nil`
  at the ends). If a poem sits exactly at `t`, that poem is returned as BOTH sides
  (the image snaps to that exact moment instead of averaging across it).
- O(log n) binary search.

### `M.compute_image_pseudo_embeddings(poems, images) -> pseudo, skipped`
- `poems`: array of `{ poem_index, timestamp (number), embedding (array) }`.
  Order does not matter (sorted internally; caller's array untouched).
- `images`: array of `{ id, source_name, rel_below_source, timestamp (number), ... }`.
- `pseudo`: array of image pseudo-poems, each `{ is_image=true, id, source_name,
  rel_below_source, display_title, timestamp, embedding (unit-normalized), image }`
  where `image` is the original record (for rendering).
- `skipped`: images that could not be placed (empty poem timeline). A missing
  pseudo-embedding is treated as an error condition for the caller to surface —
  no silent fallback.

## Tested by

`src/image-pseudo-embeddings.test.lua` (16 assertions: crooked cross-cut, both
timeline ends, exact-timestamp snap, unit-length normalization, title formatting
incl. nested + leading-slash, empty-timeline skip). Run with
`luajit src/image-pseudo-embeddings.test.lua`.

## Not yet wired (remaining 9-013 work)

This module is the pure core. Still to do (the batched-regeneration pass):
1. Pipeline hook: load embeddings.json + poems.json (join by poem_index for the
   embedding + ISO-date→timestamp), load image-catalog.json, call this module,
   append the pseudo-poems to the embedding set the GPU similarity stage reads.
2. Renderer: flat-html-generator draws image pseudo-poems on
   similar/different/chronological pages (image + title box, one slot each).
3. Share `qualified_image_title` with the gallery chronological page (10-042d).
