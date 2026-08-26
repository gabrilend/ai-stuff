# 105 — A picture on the disk

## Current behavior

Done. `src/017-write-a-picture.lua` writes grayscale and colour-with-transparency
PNGs, with real compression rather than uncompressed blocks.

A full-size field comes out at well under a fifth of its raw size, which is the
whole reason the compressor was written rather than skipped. Run the phase demo
for the figure against the archive on disk.

**Both checks the plan asked for are in place and both are real.** The round trip
goes through a decoder written in the test from the format description, not
through anything in `017` — a round trip through code written from the same
misunderstanding proves nothing. And the outside opinion is taken when the
machine has one, with the tool named in the output; when there is none, the test
says the outside check was skipped rather than counting it as a pass.

Two ordering mistakes surfaced immediately, both the same shape: a table lookup
placed before the bounds check that protects it, in the code that picks which
length bracket and which distance bracket a repeat falls into.

## Intended behavior

**A PNG writer, which means a deflate compressor, written here rather than
borrowed.**

Two kinds of image are needed and no others: 8-bit grayscale for the structure
field (`docs/003`), and 8-bit RGBA for the stroke-order arrows (`206`), which
must be transparent where there is no arrow.

### Why deflate is being written rather than shelled out to

PNG's compressed stream is a zlib stream, and zlib streams are deflate. There is
no way to write a PNG without one.

The cheap escape is a *stored* deflate block — the format permits uncompressed
blocks, and a PNG built from them is valid and every viewer opens it. It is also
about six times larger than it should be, and this project writes two images per
character for potentially six thousand characters. A gallery of that is a
gigabyte of nothing.

So: fixed-Huffman deflate with real match finding. Fixed Huffman means the code
tables are the ones in the specification rather than ones computed from the data,
which costs a few percent against dynamic Huffman and removes the entire tree
construction and encoding problem. Match finding is a hash chain over three-byte
sequences. For blurred grayscale — long smooth gradients and large flat margins —
this compresses very well, and the several hundred lines it costs are paid once.

### The other thing PNG needs

**Filtering.** Every scanline is prefixed with a filter byte saying how its bytes
were transformed, and the transformations are differences against the pixel to
the left, the one above, both, or a predictor of the three. This exists because
deflate finds repeats and an image's repeats are usually *gradients* rather than
identical bytes — a smooth ramp is incompressible raw and is a run of identical
bytes once you difference it. Skipping filtering (writing filter 0 everywhere)
on a blurred grayscale image roughly doubles the output.

The filter is chosen per scanline by the heuristic in the specification: try each,
sum the absolute values of the signed results, keep the smallest.

**And two checksums that are different from each other**, which is the classic
place to lose an afternoon: every PNG chunk carries a CRC-32 over its type and
data, and the zlib stream inside the `IDAT` chunks carries an Adler-32 over the
*uncompressed* bytes. They are not the same algorithm, they are not computed over
the same bytes, and getting either wrong produces a file that some viewers open
and others refuse.

## Suggested implementation steps

1. **`src/017-write-a-picture.lua`** — CRC-32 and Adler-32 with a built table,
   the scanline filters, fixed-Huffman deflate with a hash chain, and the chunk
   writer. Grayscale from a canvas; RGBA from four canvases or from a pixel
   callback.

2. **Test by reading it back.** A picture written and re-read must be the same
   picture — a small decoder for the fixed-Huffman subset lives in the test, not
   in the library, since nothing in this project needs to read a PNG. Round-tripping
   is the only test that catches a wrong Huffman code, because a wrong code
   produces a file whose length looks right.

3. **Check against a real decoder too, if one is present.** If the machine has
   `pngcheck` or ImageMagick, the test uses it and says which it used. If not, the
   test says the external check was skipped rather than passing silently — an
   unavailable check reported as a pass is worse than no check.

## Related

`docs/003` — the field this writes. `104` — the surface it reads from.
