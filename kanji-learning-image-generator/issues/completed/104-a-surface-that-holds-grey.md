# 104 — A surface that holds grey

## Current behavior

Done. `src/016-the-grey-canvas.lua` holds the surface, the brush, the shape
fill, the blur, the range compression, the inversion and the resampler.

**The plain table is fast enough and stays.** The plan said to measure before
reaching for a faster array, and the measurement is that a full-size blur — the
most expensive thing here by a wide margin — takes about six hundredths of a
second. Nothing about that is worth a dependency.

**One bug, found by a test, and it was in the bounding box rather than in the
brush.** The box around each segment was sized from the brush width at the
segment's two ends, which is wrong for the taper: a perfectly straight stroke
flattens to a single segment spanning the whole stroke, so both of its ends sit
at the tapered tips while its middle is at full width. The box then clipped the
middle of every straight stroke — and clipped it *asymmetrically*, because
rounding down at the top and up at the bottom do not cut the same amount off
each side. Every horizontal and every vertical in the archive was affected;
every curve was fine. The box is now sized from the untapered width, which the
taper can only ever narrow.

A second, related mistake was fixed at the same time: the brush width is asked
for at each pixel's own place along the stroke, not interpolated between the
segment's ends, for exactly the same two-point reason.

## Intended behavior

**A rectangle of floating-point numbers, and the operations that put ink on it.**

Floating point rather than bytes, because the field in `docs/003` is built by
drawing, then ramping, then blurring, then compressing into a range — four passes
over the same surface. Doing that in eight bits quantises four times and the
banding shows up in the blur, which is exactly the part that is supposed to be
smooth.

The operations needed, and nothing else:

**Draw a thick line with soft shoulders.** Coverage per pixel comes from that
pixel's distance to the line segment, so the result is antialiased without
supersampling. The brush has a width that can vary along the stroke, which is what
makes tapering possible.

**Combine by maximum, not by addition.** This is the one decision in this file
that is not obvious and it matters: strokes cross. Ink that accumulates makes
crossings darker than the strokes that formed them, so a character grows bright
knots at its joints and the illusion puts a dark blob wherever two strokes meet.
Taking the maximum means a crossing is exactly as dark as a stroke, which is what
ink on paper does once the paper is saturated.

**Blur.** Three passes of a box blur approximate a gaussian closely enough for
this, and a box blur is separable and constant-time per pixel regardless of
radius — a running sum along each row, then each column. A true gaussian at
radius nine would cost several hundred multiplies per pixel and would not look
different after the range compression.

**Compress into a range.** Map the surface's minimum and maximum onto a chosen
band. `docs/003` says why the band is not zero-to-one.

**Invert.** Polarity (`docs/004`) is one flag and this is what it does.

The surface knows nothing about kanji, strokes, or fields. It is a rectangle of
numbers with a brush.

## Suggested implementation steps

1. **`src/016-the-grey-canvas.lua`**, storing pixels in a flat array indexed
   `y * width + x + 1`. A LuaJIT `ffi` array of `double` would be faster; a plain
   table is used until something measures that it matters, and `034` is where that
   measurement would go.

2. **Restrict every drawing operation to the segment's bounding box**, expanded by
   the brush radius. Naively touching every pixel for every segment is the
   difference between a batch that takes minutes and one that takes hours, and
   there are around eighty thousand strokes in the archive.

3. **Test the invariants that are easy to get wrong**: that a horizontal line has
   the same coverage profile as a vertical one of the same width (asymmetry means
   the distance function is wrong), that two crossing strokes leave the crossing
   no darker than either, that a blur of a uniform surface is that same uniform
   surface (which catches edge handling), and that the range compression puts the
   extremes exactly on the requested band.

## Related

`docs/003` — what gets built on this. `105` — what writes it out.
