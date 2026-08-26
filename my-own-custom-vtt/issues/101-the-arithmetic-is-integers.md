# 101 -- The arithmetic is integers

**Phase:** 1, the world holds still
**Blocked by:** nothing. This is the first file in the project.
**Blocks:** everything that has a position, a distance, or an angle.
**Documents:** [a thing in the world](../docs/005-a-thing-in-the-world.md)
**Open questions:** [1.1](../docs/016-open-questions.md) -- is one world unit one
foot? The answer sets the constant this whole file is built around.

## Current behaviour

Nothing exists.

## Intended behaviour

One module providing every arithmetic operation the world needs, in fixed point,
with no floating point anywhere in it.

A **world coordinate** is a signed 32-bit integer counting in units of 1/1024 of
a world unit. An **angle** is an unsigned 16-bit integer where a full turn is
65536, so that turning past a full circle wraps by overflowing, which costs
nothing and is always correct.

The module offers:

| Operation | Why it cannot be left to the caller |
| --- | --- |
| Multiply two coordinates | The intermediate needs 64 bits before it is shifted back down. A caller who forgets overflows at about two world units. |
| Divide two coordinates | Integer division truncates toward zero, so a body drifting left and one drifting right round differently. One rounding rule, applied here, commented here. |
| Distance, and distance squared | Squared is what almost every caller actually wants; offering it prominently stops people reaching for the square root out of habit. |
| Square root | Integer, for the cases that genuinely need a length. |
| Sine and cosine of an angle | A lookup table over the 16-bit angle space, generated at build time. No `libm`, because `libm` returns doubles. |
| Angle from a vector | The inverse, for pointing a body at a thing. |
| Normalise a vector to a given length | Needed by every movement step. |

Every one of these is deterministic, and identical on every machine, because
integer arithmetic gives the compiler no freedom to reassociate or fuse.

## Suggested implementation steps

1. Fix the scale constant and write the reasoning beside it as a comment, not in
   a document -- this is the number somebody will want to change in two years and
   they need to find out what depends on it at the point of change.
2. Write the multiply and divide first, with the rounding rule and the reason for
   it in a comment. These are the two that get quietly "simplified" later.
3. Generate the sine table at build time from a script that lives beside the
   source. Do not commit a table of numbers with no visible origin -- make the
   tool, not the thing.
4. Write the companion `.info.md` listing every operation, its inputs, its
   outputs, and its rounding behaviour.
5. Write tests that pin the rounding: multiply and divide across zero, angles
   that wrap, distances at the extremes of the range. These tests are the
   specification, because the specification is entirely about edge behaviour.
6. Add a test asserting that no floating-point instruction appears in the
   compiled object. This sounds excessive and it is the cheapest possible guard
   against the one mistake that is invisible until an hour into a replay.

## Deprecated temporary files

The sine table generator is permanent, not temporary. It is regenerated whenever
the angle resolution changes.
