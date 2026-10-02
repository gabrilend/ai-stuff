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
