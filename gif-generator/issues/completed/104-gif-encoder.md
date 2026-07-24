# 104 — gif encoder

## Current Behavior

Complete. The encoder emits the full block sequence with the flat
LZW dictionary as specified. One lesson learned and recorded in the
source: the code-width bump must happen when the entry *being added*
needs more bits (checked before the add) — bumping after the add
desyncs encoder and decoder by exactly one code; the round-trip test
caught it on first run. Eleven assertions pass, including noise that
forces dictionary resets; ImageMagick independently reads a
ten-frame probe file cleanly, so the timing agrees with the world,
not just with our own decoder.

## Intended Behavior

A handwritten GIF89a encoder, pure LuaJIT, no external libraries.

- Emits, in order: header, logical screen descriptor, global color
  table (the 256-entry palette), the Netscape loop-forever extension,
  then per frame a graphic control extension (delay in hundredths of a
  second) + image descriptor + LZW-compressed data, and the trailer.
- All multi-byte numbers little-endian; frame delay quantization is the
  documented reason the default frame rate is 25 (exactly 4/100 s).
- Every frame fully replaces the previous; no transparency, no dirty
  rectangles — correctness over cleverness at these canvas sizes.
- LZW with the GIF dialect: 9-bit codes growing to the 12-bit ceiling,
  clear-code resets, little-endian bit packing, 255-byte sub-blocks.
  The dictionary is flat and keyed by (previous-code, next-byte) — no
  string building in the hot loop.
- The test suite contains an independent minimal LZW *decoder* (tests
  only, never the pipeline) and round-trips every encoded frame
  byte-for-byte; a block-walker verifies file structure; the final
  proof is a browser looping the file.

## Suggested Implementation Steps

1. The byte writer (little-endian words, sub-block chopping).
2. Block emitters in file order.
3. The LZW compressor.
4. The test-side decoder and round-trip tests; a structure walker.
5. Encode a tiny hand-made two-frame animation and open it in a
   browser as the human check.

## Related Documents

- docs/datapath-gif-encoding.md (this issue's specification)
