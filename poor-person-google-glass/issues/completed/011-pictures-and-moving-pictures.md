# 011 — Pictures and moving pictures

**Phase:** 0 — Tools
**Blocked by:** 005, 008
**Related documents:** docs/datapath-cad-viewer.md

## Current Behavior
Built: the viewer's `--record` (turn and walk), `src/030-gif-writer.lua`,
`src/031-making-a-gif.lua` (one worker per processor, parts joined in frame
order), `scripts/render-gallery` (stills and GIFs of the crown sketch, the
four described models and the light pipe into output/gallery/, with
index.html; about 40 seconds), tests in `src/032-the-gif-tests.test.lua`
(own decoder and ImageMagick both read back every colour exactly). The
gallery is made, not kept: output/gallery/ is left out of git (the light
pipe's walk alone is 17 MB) and remade by the script. Music waits for
something to play (notes/ideas).

## Intended Behavior
The owner: "can you do some picture renders for the various display things
we're working on here? Some gifs too maybe? And music, when that gets
built?"

- **Moving pictures (GIF).** The viewer records frames on request:
  - `turn`: a full turn of the model on its plinth;
  - `walk`: a walk through a model's stations, the camera gliding from
    each to the next (eye, look point and lens eased between them).
  Frames are written as raw pictures into tmp/shared-memory/frames/NAME/
  with a small description file; a separate program, which never sees the
  viewer, turns them into a GIF. The GIF writer is this project's own (a
  frozen 1989 format: header, one colour table, frames, compressed by
  LZW), its colour table chosen from the frames themselves (median cut),
  checked by a decoder written separately in the tests: the decoded pixels
  must equal the colour-mapped frames exactly.
- **A gallery.** One script renders every model's best stills and moving
  pictures into output/gallery/, with an index page listing them, and
  the stills are filed in development-history/ like any picture.
- **Music** is waiting for something to play; noted in notes/ideas.

## Suggested Implementation Steps
1. src: the GIF writer (colour table, LZW, frames).
2. Viewer: `--record SECONDS turn|walk SECONDS-LONG FRAMES-PER-SECOND`.
3. src: the frames-to-GIF program; scripts/render-gallery.
4. Tests: a GIF round trip through an independent decoder; colour table
   never more than 256; a recording writes the frames it says it did.
