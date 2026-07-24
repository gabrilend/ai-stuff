# 104 — gif encoder

## Current Behavior

Indexed frames and a palette exist in memory (canvas and palette work);
no file format knows how to hold them.

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
