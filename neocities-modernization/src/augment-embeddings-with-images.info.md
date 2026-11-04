# augment-embeddings-with-images.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/augment-embeddings-with-images.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
augment-embeddings-with-images.lua

Issue 9-013 pipeline hook. Runs AFTER poem embeddings exist (Stage 6) and
BEFORE the GPU similarity stage (Stage 7). It places every picture among the
poems by what the picture shows: Stage 6's picture step
(src/picture-embeddings.lua) asked the vision model for each picture's
vector, and this step folds those vectors into the embedding set, so
pictures rank on similar/different pages like poems.

Three image classes (decided from the data, see issue 9-013):
  1. text + image post  -> its text vector blended with its pictures'
     (half and half, config.lua picture_embeddings.text_share); the pure
     text vector is kept beside the blend (text_embedding) so a re-run, or
     Stage 6 reusing the post's vector, never blends a blend
  2. image-only post     -> REPLACE its useless 🖼 embedding with its
     pictures' vector (the average, for several); a post whose media has
     no picture (a video, a sound) keeps the neighbours-in-time cross-cut
     (src/image-pseudo-embeddings.lua), the owner's choice for those few
  3. standalone catalog image (my-art, ...) -> APPEND a new entry with its
     picture's vector
A picture with no vector in the cache is an error: it says to run Stage 6.

Outputs (idempotent — safe to re-run):
  embeddings.json        : augmented in place (class-2 replaced, class-3
                           appended with is_image=true). The similarity stage
                           reads this unchanged.
  image-manifest.json     : poem_index -> render data for every image entry,
                           so the HTML renderer can draw an image box instead
                           of looking the index up in poems.json (where the
                           class-3 pseudo-poems do not exist).

Run from any directory: luajit src/augment-embeddings-with-images.lua [--dir PATH]

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.parse_iso8601(ts)`

```
Minimal ISO-8601 -> Unix epoch, matching poem-extractor's parser. Used to put
text poems and image-only posts on the same numeric timeline as catalog
images (which already carry a unix modification_time).
```

### `M.is_image_only(content)`

```
Class 2 detector. Strips whitespace and the image-placeholder emojis the
collection uses, then treats <10 remaining characters as "no usable text".
Mirrors poem-extractor's is_image_only_post so classification is consistent.
```

### `M.rel_below_source(img)`

```
The image path below its source directory, for the "source: sub: name.png"
title. Catalog `relative_path` is actually absolute, so strip the
`source_directory` prefix.
```

### `M.augment(embeddings_data, poems_data, catalog_data, pictures_in)`

```
Pure-ish core: operates on already-loaded tables, returns the augmented
embeddings list and the image manifest. No file I/O (so it is testable).
  embeddings_data : { embeddings = [ {embedding, poem_index, id, ...}, ... ] }
  poems_data      : { poems = [ {poem_index, id, category, content,
                                 creation_date, attachments}, ... ] }
  catalog_data    : { images = [ {source_name, modification_time, ...}, ... ] }
  pictures_in     : { vector_of = function(absolute path) -> vector (an
                      error when the picture has none), dir = project folder
                      (post attachments live under it), text_share = the
                      text's part of a text + picture post (number, 0-1) }
```

### `M.pictures_from_cache(dir, model, edir, poems_data, catalog_data)`

```
The pictures_in for M.augment, from Stage 6's picture cache: each picture
is fingerprinted again (a picture edited since Stage 6 has a new
fingerprint, and is reported as having no vector rather than given its old
one).
```

## Inside (local to the file)

### `read_json(path)`
(No comment above it in the source.)

### `write_json(path, data)`
(No comment above it in the source.)

### `normalised(vec)`

```
A vector scaled to length 1 (a new array). A zero vector is an error: no
real picture or poem gives one, so it means something upstream broke.
```

### `blend(parts)`

```
The normalised weighted sum of normalised vectors: parts is an array of
{ vector, weight }.
```

### `pictures_vector(poem, pictures_in)`

```
One vector for a post's pictures: the average of each picture's vector.
Returns nil for a post with no picture among its attachments.
```

### `main()`
(No comment above it in the source.)
