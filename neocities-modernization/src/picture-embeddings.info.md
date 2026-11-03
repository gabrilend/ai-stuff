# picture-embeddings.info.md

Stage 6's picture step (Issue 9-013). The embedding model, loaded with its
vision projector, turns each picture into the same kind of vector it makes
for a poem, and this step does that for every picture the site ranks: the
picture attachments of posts, and the gallery pictures. The vectors are kept
in a cache beside the model's other caches, so a picture is sent to the
server once. Stage 6.7 (`src/augment-embeddings-with-images.lua`) reads the
cache; it does not talk to the server.

Run by `run.sh` (`run_generate_picture_embeddings`, inside Stage 6 while the
server is up), or by hand:

    luajit src/picture-embeddings.lua [DIR] --model NAME --server NAME

## The cache: `<model's embeddings folder>/picture_embeddings.json`

| field | type | meaning |
|---|---|---|
| `metadata.format` | string | `"picture-embeddings-v1"`; any other is refused |
| `metadata.model` | string | the model that made the vectors |
| `metadata.long_side` | integer | the size the pictures were shrunk to |
| `metadata.generated_at` | string | local time of the run |
| `pictures[key]` | table | one picture at one size; `key` is `"<md5>@<long_side>"` |
| `pictures[key].embedding` | array of numbers | the model's vector (768 numbers for EmbeddingGemma 2) |
| `pictures[key].example` | string | a path the picture was found at, for a person reading the file |

A picture is known by the md5 of its contents, so a moved or renamed file
keeps its vector, an edited one is sent again, and the same picture in two
places is one entry. Pictures no longer on the site are dropped from the
cache each run.

## Settings (`config.lua` `picture_embeddings`)

- `long_side` (integer, pixels): pictures are shrunk to this on their long
  side before sending; smaller pictures keep their size.
- `request_seconds` (integer): how long one picture may take.
- `text_share` (number, 0-1): read by Stage 6.7, the text's part of a text
  + picture post.

The model's `vision_projector` (in its `available_models` entry) is what
lets the server see; a model without one stops the step with an error.

## External functions

### `M.pictures_to_place(dir, poems_data, catalog_data) -> array of paths`
Every picture file the site ranks, each once, sorted: the picture
attachments of every post (`media_type` image/...) and every catalog picture
except `fediverse-media` (those are the same post attachments).

### `M.post_picture_path(dir, attachment) -> path`
Where a post attachment's file lives: `input/media_attachments/<relative_path>`.

### `M.is_picture(attachment) -> boolean`
Whether a post attachment is a picture (not a video or a sound).

### `M.fingerprints(paths, scratch) -> { [path] = md5 }`
The md5 of every file, on every processor at once (`xargs -P`, `md5sum -z`).
Each batch of 64 writes its answers to its own file under
`<scratch>/fingerprint-answers/`, read once all batches finish; sharing one
pipe let batches cut into each other's answers and lose a few per run. A file
that cannot be read is an error giving how many failed and naming the first;
a batch that failed with every answer present is an error too.

### `M.cache_key(md5, long_side) -> string`
`"<md5>@<long_side>"`.

### `M.shrink_all(jobs, long_side, scratch)`
`jobs`: array of `{ source = path, target = path }`. Writes each target as a
JPEG (quality 95): long side down to `long_side`, transparency flattened onto
white, an animation's first frame. On every processor at once. A target that
did not appear is an error naming its source.

### `M.server_embedder(endpoint, scratch, timeout_seconds) -> function(jpeg) -> vector`
Asks the server's `/v1/embeddings` for a picture's vector (the picture as a
base64 `image_url` content part). No vector in the reply is an error that
names the picture and asks whether the server was started with `--mmproj`.

### `M.update(cache, paths, hashes, long_side, shrink, embed, scratch, say) -> cache, report`
The step's core, with the file work and the server passed in (so the test
needs neither). Keeps the cached vectors of pictures still on the site,
shrinks and sends the rest one at a time (the server has one slot), and
removes each shrunk copy once sent. `report`: `{ reused, made, total }`.

## Tests

- `src/picture-embeddings.test.lua`: real files, fingerprints and shrinking;
  a stand-in server; the cache rules.
- `src/picture-sight.test.lua`: with a vision server up, pictures of known
  words land closest to their own words (SKIP without one).
