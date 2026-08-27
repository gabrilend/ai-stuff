# 414 — The numbers were all secretly at 768

## Current behavior

A pixel number in `input/settings.lua` is read as *a length at the reference
resolution* and multiplied through when the real resolution differs. The file a
person edits still says `6.5` and `9`; `field.reference` beside the resolution
says what those numbers were measured against, and one conversion in the field
builder applies it. A stroke covers the same fraction of the frame at any size,
which is asserted rather than eyeballed.

The run takes a resolution on the command line, names the pool entry after it so
two sizes of the same character do not overwrite each other, and warns above
1024 before spending the time.

## Intended behavior

**A pixel number is a fraction of the frame, and should say so by scaling with
it.**

The numbers stay where they are and stay readable — nobody wants to write a
stroke width as `0.00846` — but they are read as *at the reference resolution*
and multiplied through when the real one differs. Written down once, in the
settings file, next to the resolution they are relative to.

**Which numbers scale and which do not is a real distinction**, not a sweep:

- **Scaling**, because they are lengths inside the picture: stroke width, the
  blur radius and its floor, every arrow dimension, the clearance between
  arrows.
- **Not scaling**, because they are not lengths in that picture: the margin and
  the range band, which are already fractions; the thumbnail, which is a size in
  its own right and is the size the illusion is judged at whatever the picture
  was made at; the number of passes; anything counted rather than measured.

**And doubling the resolution is not free**, which the run should say rather
than let somebody discover. The model these recipes are written for was trained
at 512 and is already being pushed at 768. Above that it stops composing one
scene and starts tiling a texture — see the measurement below — so the warning
is not a formality.

## What doubling the resolution actually did

The reason this ticket exists was to make that experiment interpretable rather
than to make it succeed, and it did not succeed. Four characters, the same
seeds, the same brief, 768 against 1536:

| character | 768 | 1536 |
| --- | --- | --- |
| 川 | 0.98 | 0.95 |
| 木 | 0.87 | 0.90 |
| 時 | 0.84 | 0.63 |
| 語 | 0.52 | 0.83 |
| seconds each | 37 | 290 |

**The scores moved in both directions and neither direction was improvement.**
At 768 the strokes are made of things — the sun radical in 時 is a tower with
windows, the mouth radical in 語 is a wooden crate. At 1536 both characters are a
thin traced line over an even crowd texture: the character is *drawn*, not
built.

The cause is architectural rather than tunable. The picture is generated on a
grid of cells that each stand for an eight-pixel square, so 768 is a 96×96 grid
and 1536 is 192×192. The layers that let one part of the picture know what the
rest is doing were trained at roughly 64×64 and their reach does not grow with
the canvas, so past a point every region can only see its neighbours. It tiles
something locally plausible instead of composing something globally coherent.
With no scene left to bend, the only way the structure field can be satisfied is
by darkening pixels directly.

**語 rising from 0.52 to 0.83 is the second confirmed instance of the grader
rewarding the glyph-drawing failure**, and the strongest yet: a traced character
matches the field better than any honest scene can. Recorded against the open
question about what the score is worth.

More room for the strokes is still the right instinct; more pixels is the wrong
way to buy it. The levers that remain are a simpler field (fewer, fatter
strokes), a second low-strength pass at the larger size after composing at the
smaller one, or a checkpoint trained at 1024.

## Suggested implementation steps

1. **A `reference` beside the resolution**, and one function that converts. Not
   a scattering of multiplications at each use, which is the same bug again with
   more places to forget.

2. **Applied where the settings are read, not where they are written**, so the
   file a person edits keeps saying 6.5 and 9.

3. **Test at a resolution other than the reference** — that a stroke covers the
   same *fraction* of the frame at 768 and at 1536 is the whole claim, and it is
   one assertion.

4. **The pool entry carries the resolution in its name**, because the same
   character at two sizes is two artifacts to compare, not one to overwrite.

## Related

`202` — the field these numbers draw. `206` — the arrows. `docs/balance-updates.md`
— where all of them were tuned, at 768. `docs/007-open-questions.md` — the
question about what a high score is worth, which this measurement sharpens.
