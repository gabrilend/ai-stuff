# Issue 9-013: Pictures Ranked Beside the Poems

## Priority
Medium

## Current Behavior (the system as built, 2026-10-25)

Pictures take part in the similar and different rankings as entries of their
own. Since 2026-10-25 each picture is placed by what it shows: Stage 6 asks
the vision model for every picture's vector (`src/picture-embeddings.lua`,
cached in `picture_embeddings.json`), and Stage 6.7 folds them in by the
rules under "The design" below. The embedding set grows by the gallery
pictures, the GPU ranks everything together, and the pages draw a picture
entry where a ranked picture falls. Built and tested (the step, the
placement, the reuse rule, and the sight test against a running vision
server); the first build with it -- about 1,200 pictures to embed, 3-4 s
each on the 1080 Ti -- and the hubness count after it (step 7 below) are
the owner's to run. The section "The embedding a picture gets" describes
the neighbours-in-time cross-cut, which is now used only for the three
posts whose media has no picture.

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
(`image-render.inject_pseudo_poems`: kind 3 appended; kind 2, the
image-only posts, left as the ordinary posts they are -- see below) and draw a ranked picture with `image-render.format_image_entry`
through the shared poem drawer (`src/poem-entry.lua`): a picture box with
its source-qualified title (`gallery: folder: file`, wrapping at dashes,
slashes and colons, cut at the column when a name has none), each title line
linking to the picture's place on the gallery page; one slot per page, like
a poem. A text + picture post gets a direct "image.png" link under its
ranking line (`image-render.text_image_link`). The chronological pages draw
the poems as the caller loaded them (no folding): a picture-only post shows
as itself, its picture with its own description. Gallery pictures are not on
the chronological pages (Issue 10-042b). The word pages do the same (their
jobs carry their poems, Issue 10-035).

**Picture descriptions in the box (fixed 2026-10-22).** The box described
every picture by its title, so a screen reader read each image-only post's
pictures as "fediverse: image post", though 80 of their 85 pictures have
their own description. Each picture is now described by its own
description, falling back to the title only when it has none, escaped for
the attribute and repeated as the hover title, as the ordinary post does
(`format_image_entry`; three checks in `src/image-render.test.lua`).

**Every post with pictures is drawn as an ordinary post (2026-10-22).**
The 68 image-only posts were drawn as the picture box on similar and
different pages and as ordinary posts on chronological and word pages; the
box left out the post's text (38 of the 68 have some), its content warning
(24 have one) and its links. Owner, after the comparison page
(`scripts/render-image-post-comparison`, both ways side by side with what a
screen reader says, wrapped at 80 columns): "I think every post with
pictures should follow the example in the right column, the one with all
the extra information." So `inject_pseudo_poems` no longer tags them; the
picture box is now only for gallery pictures (kind 3), which have no post.
Checked on poem 133's pages: no picture boxes, its content warning shown,
0 over-wide lines and 0 frame errors.

### Tests

- `src/image-pseudo-embeddings.test.lua` -- the cross-cut, the end cases.
- `src/augment-embeddings-with-images.test.lua` -- the three kinds, the
  manifest, idempotency, numbering after the highest poem, and a read-only
  pass over every model with embeddings on disk.
- `src/image-render.test.lua`, `src/image-render-test.lua` -- the picture
  entry, its title wrapping and links.

## Intended Behavior: pictures embedded from what they show

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

### Tested 2026-10-25: handwritten notebook pages

Why it mattered: the 93 photos in `input/images/poem-pictures/kooky-dookerie/`
are handwritten notebook pages photographed between the same two posts, so
the neighbours-in-time cross-cut gave all 93 one identical vector, and the
diversity walk put that one direction into about two-thirds of all
"different" lists.

Four pages were embedded from their photos (900 and 1800 px on the long
side) and compared with what each page says, read by eye, and with a
re-wording of each page's subject that shares no key word:

| | own page closest | own-page cosine | other pages' cosine |
|---|---|---|---|
| photo vs the page's words, 900 px | 4 of 4 | 0.73–0.80 | 0.63–0.70 |
| photo vs the page's words, 1800 px | 4 of 4 | 0.78–0.82 | 0.60–0.68 |
| photo vs the re-worded subject, either size | 4 of 4 | 0.70–0.76 | 0.58–0.69 |

So the model tells one page of the same notebooks from another by what is
written on it, carries the meaning past the exact words, and reads
handwriting better from the larger photo. Two cautions came with it: photos
sit close to one another whatever they say (0.70–0.80, above any photo's
match with a wrong page), the same kind of shared offset a poem population
has, so photo vectors would need centring on their own average (as words
are, see libs/embedding-space.lua) before ranking beside poems; and the
two posts the cross-cut borrowed from matched the pages no better than any
unrelated text (0.59–0.66). Speed: eight photos and ten texts in 16 s on
the 1080 Ti. Four pages is a small sample.

### The design (owner, 2026-10-25)

Owner: "I think I just want the photo embedding, nothing else." No
transcription, no descriptions folded in, no neighbours mixed into a picture
that has pixels. Answers to the earlier questions:

- **Picture-only posts (kind 2) and gallery pictures (kind 3)** take the
  vision model's embedding of their own picture. A post with several pictures
  takes the normalised average of its pictures' embeddings.
- **Text + picture posts (kind 1)** blend: the normalised average of the
  post's text embedding and its pictures' average, half and half
  (`config.lua` `picture_embeddings.text_share`, 0.5). Owner chose "Blend in
  the picture" over keeping the text alone.
- **Posts whose media has no picture** (two video-only posts and one
  audio-only post in 2026-10) keep the neighbours-in-time cross-cut. Owner:
  "let's just do the before/after poem system that we currently have. For
  those three."
- **No separate centring for pictures.** Owner: "I think this is fine so
  long as they are different from one another. The error was that they were
  all embedded the same." The one shared centring (libs/embedding-space.lua)
  covers pictures and poems together.
- **A model without vision cannot place pictures**, and the build stops
  with an error naming the models that can, rather than quietly falling back
  to the cross-cut.
- **Notebook pages are not treated as poems.** Owner: "yes, but I don't want
  to classify them manually, so, no." Nothing transcribes them.

Size: each picture is shrunk to 1800 px on its long side before it is sent
(`picture_embeddings.long_side`), since handwriting read better at 1800 than
900 px. Transparent pictures are flattened onto white, and an animated GIF
uses its first frame.

## Suggested Implementation Steps (the picture-meaning design)

1. **Server with eyes.** A model entry in `config.lua` may name its
   `vision_projector` (the mmproj GGUF). `scripts/start-llamacpp-server.sh`
   passes `--mmproj` when it is named.
2. **Picture vectors are made in Stage 6**, while the embedding server is
   up: a new step `src/picture-embeddings.lua` (run.sh
   `run_generate_picture_embeddings`, after the text embeddings) finds every
   picture the site ranks (kinds 1-3), fingerprints each file by its
   contents (md5, in parallel), shrinks the new ones in parallel into RAM,
   asks the server for each one's embedding, and keeps them in
   `picture_embeddings.json` beside the model's other caches, keyed by
   fingerprint and size. A picture already there is not sent again; a
   changed file has a new fingerprint and is sent again.
3. **Stage 6.7 only reads those vectors.** `src/augment-embeddings-with-images.lua`
   looks each picture up by its fingerprint; a picture with no vector is an
   error that says to run Stage 6. Kind 2 is replaced by its pictures'
   average, kind 3 is appended with its picture's vector, kind 1 is blended,
   and the three media-only posts take the cross-cut.
4. **A blended vector is never blended twice.** Kind 1 entries keep the
   pure text vector beside the blend (`text_embedding`), the blend is always
   made from that, and Stage 6's reuse of a post's vector takes the
   `text_embedding` when one is there (`src/similarity-engine.lua`).
5. **The manifest says how each picture was placed** (`placed_by`:
   picture, text and picture, or neighbours), and the step prints the counts.
6. **Tests.** The augment test covers each kind with stand-in picture
   vectors, the error for a missing one, and that re-running does not
   compound the blend; the reuse test covers `text_embedding`; a picture
   step test covers the cache (a known picture is not sent again, a changed
   one is) with a stand-in server; and a sight test
   (`scripts/picture-sight.test.sh`) draws pictures of known words and checks
   each lands closest to its own sentence when a vision server is up,
   skipping otherwise.
7. After the owner's next build: count how many of a picture's top similar
   entries are other pictures, the hubness check from 2026-06-23.

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

- **Status**: In progress -- the ranked-picture system is built and in every build;
  the picture-meaning design above is decided (2026-10-25) and being built.
- **Created**: 2026-01-20
- **Phase**: 9 (originally), moved to Phase 8 roadmap
- **Dependencies**: Issue 8-040
- **Blocks**: 10-042d
