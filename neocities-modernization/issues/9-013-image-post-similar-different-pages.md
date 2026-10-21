# Issue 9-013: Pictures Ranked Beside the Poems

## Priority
Medium

## Current Behavior (the system as built, 2026-10-21)

Pictures take part in the similar and different rankings as entries of their
own. Every picture without text gets an embedding made from the poems around
it in time, the embedding set grows by those pictures, the GPU ranks
everything together, and the pages draw a picture entry where a ranked
picture falls.

### Three kinds of picture

Decided from the data (a scan of poems.json in June 2026: 411 posts carried
attachments, and only one mentioned an image file name in its text, so text
length alone separates the kinds):

1. **Text + picture post** (343): real text, embedded by its text and ranked
   normally; the picture is drawn as the post's attachment. Nothing changes.
2. **Picture-only post** (68): content is `🖼`, blank, or under 10 characters
   once whitespace and picture emoji are removed (`is_image_only` in
   `src/augment-embeddings-with-images.lua`). Its own embedding is
   meaningless, so it is replaced.
3. **Gallery picture** (660, from the image catalog: my-art, poem-pictures,
   things-I-almost-posted, dnd-pictures-from-the-internet, fediverse-stars):
   no post at all; it is added as a new entry. Fediverse post attachments
   (`fediverse-media`) are not counted here -- they are kinds 1 and 2.

Borderline short posts ("4/20", a bare mention, one word) fall under kind 2;
a "4/20" marker is no more embeddable than `🖼`.

### The embedding a picture gets

`src/image-pseudo-embeddings.lua` places each kind-2 and kind-3 picture at
its date among the TEXT poems only (kinds 1 and ordinary poems; pictures
never average over pictures) and builds its embedding by cross-cutting its
two neighbours: the first half of the dimensions from the poem before, the
rest from the poem after, then normalised to unit length (`SEAM_FRACTION`
0.5). A picture before the first poem or after the last takes its one
neighbour's direction. Several pictures between the same two poems share an
embedding.

Why a cross-cut and not the average (measured 2026-06-23): the average of two
unit vectors sits closer to the corpus centre (+12%, spread falling from sd
0.069 to 0.036), which made pictures "hubs" that flooded every poem's
similar list and never appeared in the different lists. The cross-cut keeps
each dimension's full real-poem size, so pictures sit at the normal
centrality (-0.1%) and rank like poems. The models in use are trained so the
leading dimensions carry the coarse meaning, so it reads as "the subject of
the poem before, the texture of the poem after"; the seam was measured not
to affect hubness, so it is a free aesthetic setting.

No part of this looks at a picture's pixels.

### Where it runs

`run.sh` Stage 6.7 (`run_augment_images`) runs
`src/augment-embeddings-with-images.lua` after the poem embeddings and before
the GPU similarity stage. It replaces the kind-2 embeddings in place, appends
the kind-3 entries, and writes `image-manifest.json` beside the embeddings:
one record per picture (kind, number, source, title, path, size, date,
gallery anchor). It is idempotent: a re-run drops earlier picture entries
before adding them again. The similarity and diversity stages need no change:
they see more rows.

Picture numbers: kind 2 keeps its post's number; kind 3 is numbered after the
highest poem in poems.json (2026-10-20 -- it used to be the highest poem with
an embedding, so when 16 notes arrived after the embeddings were made the
pictures took their numbers and drew in their place on every similar and
different page). The numbering is being redesigned in Issue 8-019, where
every item's number will be recounted each run in date order, pictures
among the poems.

### How the pages draw it

The page workers fold the manifest into their poem list
(`image-render.inject_pseudo_poems`: kind 2 tagged in place, kind 3
appended) and draw a ranked picture with `image-render.format_image_entry`
through the shared poem drawer (`src/poem-entry.lua`): a picture box with
its source-qualified title (`gallery: folder: file`, wrapping at dashes,
slashes and colons, cut at the column when a name has none), each title line
linking to the picture's place on the gallery page; one slot per page, like
a poem. A text + picture post gets a direct "image.png" link under its
ranking line (`image-render.text_image_link`). The chronological pages draw
the poems as the caller loaded them (no folding): a picture-only post shows
as itself, its picture with its own description. Gallery pictures are not on
the chronological pages (Issue 10-042b).

### Tests

- `src/image-pseudo-embeddings.test.lua` -- the cross-cut, the end cases.
- `src/augment-embeddings-with-images.test.lua` -- the three kinds, the
  manifest, idempotency, numbering after the highest poem, and a read-only
  pass over every model with embeddings on disk.
- `src/image-render.test.lua`, `src/image-render-test.lua` -- the picture
  entry, its title wrapping and links.

## Intended Behavior (next): pictures embedded from what they show

### Tested 2026-10-21

EmbeddingGemma 2 is multimodal: with its vision projector
(`assets/models/mmproj-embeddinggemma-2-Q8_0.gguf`, 555 MB, from
`ggml-org/embeddinggemma-2-GGUF`) llama-server embeds a picture into the same
768-dimension space as text (`/v1/embeddings`, a picture as a base64
`image_url` content part; the server started with `--mmproj` and
`--embeddings`). `scripts/compare-picture-embeddings` tested whether it reads
pictures of words. For each picture, the closest of nine sentences:

| Picture | Closest sentence | cosine |
|---|---|---|
| drawn: "the river remembers / every rain that fed it" | that line; second, a paraphrase sharing no key word ("water keeps the memory of the storms that made it") | 0.811; 0.756 |
| drawn: a line of C with a mutex | that line of C | 0.836 |
| drawn: a grocery list | that list | 0.839 |
| real: 39 lines of threaded C | the C line, then "a C program that starts threads and locks a mutex" | 0.747 |
| real: C semaphore pseudocode | the same two | 0.738 |
| real: GNU C documentation page | the C line | 0.653 |
| real: a reddit screenshot of a Princess Bubblegum quote | "a favourite quote from a princess in an animated cartoon" | 0.711 |
| a drawing (my-art: about-face-2) | "a hand-drawn picture of a face" | 0.752 |

Eight of eight closest sentences are the right ones; the unrelated sentence
(an engine manual) is in no picture's top three; pictures of code sit
closest to each other (0.75–0.81). It reads the words and carries their
meaning, not only their letters. A larger picture budget (`-b 2048 -ub 2048`)
changed almost nothing.

### What it would replace or join

A picture can now have up to four sources of meaning:
1. **its pixels** (the vision model: reads words and recognises subjects);
2. **its description** (alt text, fediverse attachments only: often a full
   transcription, e.g. "39 lines of C code included in its original form");
3. **its post's text** (kind 1);
4. **its neighbours in time** (the cross-cut above).

Open questions (for the owner):
- How are they combined into one embedding? One shape: the normalised
  average of the sources a picture has, perhaps weighted; text OCR is
  probably unnecessary now that the model reads words itself.
- Does a text + picture post (kind 1) keep only its text, or gain its
  picture too?
- Is the neighbours-in-time cross-cut kept at all once a picture has its own
  meaning, or only for pictures the model cannot read?
- This needs EmbeddingGemma 2 to be the build's model (the others are
  text-only), a server started with the projector, and the image step
  calling the server -- 1,100+ pictures, measured speed not yet known.

## Suggested Implementation Steps (the picture-meaning design, once answered)

1. Settle the open questions above with the owner.
2. The image step asks the server for each picture's own embedding (and its
   description's, where it has one) and combines the sources by the chosen
   rule; `scripts/compare-picture-embeddings` is the check that a picture
   still lands near what it shows.
3. The build starts its EmbeddingGemma 2 server with the projector
   (`model_path` beside an `mmproj_path` in `config.lua`'s model entry).
4. Re-run the hubness measurement from 2026-06-23 on the new picture
   embeddings: pictures must not flood the similar lists.

## History

- 2026-01-20/21: first design -- each picture-only post attached to the
  nearest text poem in time and drawn beside it, inheriting its embedding.
  Replaced because it left the gallery sources out of the rankings entirely
  and snapped a picture onto one poem's exact meaning.
- 2026-06-22: the design above (pictures as ranked entries); 2026-06-23: the
  cross-cut replaced the average.
- 2026-10-20: numbering after the highest poem; the test's stale
  expectations fixed.

## Related Documents

- Issue 8-040 (pictures on similar/different pages), Issue 8-005 (pictures
  in the HTML)
- Issue 8-019 (numbering every item), Issue 10-042 (standalone pictures in
  the site), 10-042b (gallery pictures on the chronological pages)
- Issue 1-010 (EmbeddingGemma 2)
- `src/augment-embeddings-with-images.lua`, `src/image-pseudo-embeddings.lua`,
  `src/image-render.lua`, `src/poem-entry.lua`,
  `scripts/compare-picture-embeddings`

## Metadata

- **Status**: Open -- the ranked-picture system is built and in every build;
  the picture-meaning design above is open, waiting on its questions.
- **Created**: 2026-01-20
- **Phase**: 9 (originally), moved to Phase 8 roadmap
- **Dependencies**: Issue 8-040
- **Blocks**: 10-042d
