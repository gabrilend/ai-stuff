# Datapath — from indexed frames to a .gif file

This document follows the palette and the stack of index-rectangles
into the finished file in `output/`. The target is GIF89a — a format
frozen since 1989, which is precisely its charm.

## The file, block by block

A GIF is a sequence of blocks, and we emit them in this order:

1. **Header**: the six bytes `GIF89a`.
2. **Logical screen descriptor**: canvas width and height (16-bit,
   little-endian — as is every multi-byte number in the format), and a
   flag saying a global color table follows.
3. **Global color table**: our purpose-built palette, 256 entries of
   three bytes each, written once and shared by every frame.
4. **Looping instruction**: the Netscape application extension — the
   historical, universally honored way to say "loop forever."
5. **Per frame**: a graphic control extension (frame delay, in
   hundredths of a second — the reason the default frame rate is 25),
   then an image descriptor (frame position and size — always the full
   canvas), then the LZW-compressed pixel data.
6. **Trailer**: the single byte that means "no more blocks."

Every frame fully replaces the last (disposal method "draw over";
no transparency). At our canvas sizes, chasing dirty-rectangle
optimizations buys little and costs correctness risk; if file size
ever matters, that is a measured decision for later, not a default.

## LZW, in one paragraph

The pixel bytes are compressed with the GIF flavor of LZW: a
dictionary starts holding every single-byte string plus two special
codes (clear, end); the encoder greedily matches the longest known
string, emits its code, and adds that string-plus-next-byte as a new
entry. Codes are written with just enough bits to address the
dictionary (starting at 9 bits for 256-color data), growing a bit at a
time as the dictionary fills, and the dictionary is reset with a clear
code when it reaches the 12-bit ceiling. The bit-stream is packed
little-endian into bytes, and the bytes are chopped into sub-blocks of
at most 255, each prefixed by its length.

The dictionary is a flat FFI table keyed by (previous-code, next-byte)
— no string concatenation in the hot loop, which is the difference
between milliseconds and seconds per frame in a dynamic language.

## Trust, but verify

The encoder's tests decode what was encoded: an independent, dumb LZW
*decoder* lives in the test suite (never in the pipeline) and must
round-trip every frame byte-for-byte. File-level checks confirm block
structure by walking the emitted file with an offset ruler. The proof
of the pudding remains a real browser looping the gif.

## Relevant pieces

- the byte writer (little-endian words, sub-block chopping)
- the block emitters (header, screen descriptor, palette, loop, frame)
- the LZW compressor (flat dictionary, growing code width, clear/reset)
- the test-side LZW decoder (round-trip honesty, tests only)
