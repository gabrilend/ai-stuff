# 701b — one reader, one writer

Part of 701. Depends on: 701a. Blocks: 701d, 701e.

## Current Behavior

The encoder (`src/004-gif.lua`) and palette (`src/002-palette.lua`) exist
once and are already shared, though by a climbing path. Readers are not:
this project's encoder test carries its own LZW decoder
(`src/005-gif-test.lua`); the gallery's tests carry a block walker
(`tests/gif-facts.lua`); the viewer carries the only complete decoder
(`gif-decode.lua`: local palettes, sub-rectangles, transparency, disposal,
interlacing), and its test also calls ImageMagick. The gallery writes PNG
stills with its own `png.lua`.

## Intended Behavior

- One encoder, one palette, one decoder, one PNG writer, each one numbered
  file in this project.
- Every test that needs to read a GIF uses the one decoder, which is itself
  tested against the encoder by round trip and against ImageMagick as an
  outside witness.
- The walker's useful checks (block structure, frame counts, loop
  extension) become functions of the one decoder rather than a second
  parser.
- Other projects that want the encoder take a checked copy, the way
  `my-libs/zip` is installed (`install-into` plus `check-copy`), rather than
  a path into this folder.

## Suggested Implementation Steps

1. Promote the viewer's decoder to a numbered file; point the viewer at it.
2. Replace the encoder test's private decoder and the gallery's walker with
   calls into it; keep every check they made.
3. Fold `png.lua` in as the one PNG writer.
4. Prove: all tests pass, the six fingerprints are unchanged, and the round
   trip encode → decode → encode is byte-identical for every film in the
   library.
5. Add an install-and-check pair for other projects; note in
   `burner-of-down-things` issue 806, which plans to use "gif-generator's"
   encoder, how to take it.

## What Happened (2026-10-30)

Built on the branch `claude/701b-one-reader-one-writer`, on top of 701a.

1. **The decoder is one numbered file** (`src/040-gif-decode.lua`, done in
   701a). It now also reports what a file is made of: signature, the
   loop-forever block, whether the trailer ends the file, the global table
   and its raw bytes, and with `structure = true` one record per stored
   frame, its raw indices included and whether its stream was whole.
   `facts()` gives that without keeping pictures, and
   `luajit src/040-gif-decode.lua --facts file.gif` prints the walker's old
   line, so the shell tests read it unchanged.
2. **The private readers are gone.** `005-gif-test.lua`'s own LZW decoder
   and walker are replaced by calls into 040, every check kept (the
   strictness included: an offset frame, a local table, an odd code size
   or a short stream is refused). `tests/shape-films/gif-facts.lua` is
   removed; `test-shape-films` asks 040 instead, and `041` now checks frame
   counts and sizes against ImageMagick, its outside witness. A quick
   mutation run (a byte changed every seventh position of an encoded film)
   was caught 207 times of 208 by the new walker.
3. **`038-png.lua` is the one PNG writer** (done in 701a).
4. **The proof.** `005`: 11 of 11. `test-shape-films`: 193 of 193 (the 186
   before, the six fingerprints unchanged, and the new round trip). The
   round trip, `src/044-round-trip-test.lua`, takes a film apart with 040
   and puts it back with 004: all six approved films, and all 34 scenes
   filmed at full length into RAM, come back byte-identical. The owner's
   library was not on the machine that ran it; `luajit
   src/044-round-trip-test.lua DIR /home/ritz/pictures/shape-gifs` checks it.
5. **Other projects take a checked copy**: `install-into <libs>` and
   `check-copy <libs>` at the project root, as `my-libs/zip` does, copying
   the encoder, palette, reader and PNG writer as `gif-encoder.lua`,
   `gif-palette.lua`, `gif-decoder.lua` and `png-writer.lua`, with a
   `gif-studio.version` file. `burner-of-down-things` issue 806 says how to
   take them.

Open until it has run on her machine with her library, as 701a.
