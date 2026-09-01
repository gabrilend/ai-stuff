# Phase 10 — The Tracing Table

**Built and not yet used.** The tool exists, the formats exist, and the painting
has not been traced. That is the next thing, and it is a person's job rather than
a program's.

| Issue | |
| --- | --- |
| [1001](completed/1001-a-plan-is-polygons-at-elevations.md) | a plan is polygons at elevations |
| [1002](1002-the-lattice-is-the-measurement.md) | **in progress** — the lattice is the measurement |
| [1003](1003-tracing-is-clicking-corners.md) | **in progress** — tracing is clicking corners |

`./trace-scene` opens the reference painting.

## The journey, and what it taught

### The lattice is the instrument, not the ruler

A scene needs five numbers saying where a world sits in its picture, and for a
picture somebody else made they are not known. Measuring them with a ruler means
reading a cell's diamond to the pixel and being wrong by a fraction that compounds
across eighty cells.

So they are not measured. The world's own cell grid is drawn over the painting and
nudged until the two agree, and a half-pixel error in the cell width is a whole
cell of drift by the far corner — invisible in a number, obvious on a picture.
Raising the elevation slides the lattice up by exactly one layer's pixels, which
is the second measurement and comes free: pick a step, raise by one, and see
whether the lattice moves from the tread below to the tread above.

### A pixel is a line, so the elevation is chosen before the click

A pixel of an isometric picture corresponds to a whole line of world points, one
for every height. Nothing about the pixel picks one out — only somebody saying
which height they meant. **So there is no way in the tool to place a vertex whose
height is unknown**, and elevation is shown as colour rather than as position,
because position is exactly what cannot show it.

### The world is as big as what was traced

The first version declared a footprint — ninety-six by ninety-six — and drew the
lattice over that finite square. That is backwards: it means choosing how much of
a picture is going to be the world before knowing what is in it, and then fitting
the trace into the box.

The lattice is now bounded by the view and by nothing else, and the extent falls
out of the shapes when they are rasterised. A traced world does not begin at cell
zero, so the scene shifts it there and shifts the picture's origin the opposite
way by exactly as much, which leaves every pixel where it was.

**What it taught:** the untraced-cell shading became useful in the same move. Over
a declared square it was a red wash across the whole painting on the very first
frame, hiding the thing being traced; over the traced region it is a real gap
between two shapes and is the only progress there is on a job like this.

### The same editing mistake, three times

Three files in a row lost a function's signature to a patch, because the vimfold
comment above each function repeats its declaration and a search for that line
finds the comment first. Every one produced a syntax error a long way from the
edit, and one of them cost a run that hung for three minutes rather than failing.

## What is deferred, and what it is waiting on

**The trace itself.** Nothing has been drawn on the painting. The two open issues
are open because the tool has not met the picture yet, and the questions they hold
are the ones only that meeting can answer.

**Whether the painting is on a consistent lattice at all.** It was drawn rather
than rendered, so its perspective may wander, and a lattice that fits one corner
may be a cell out at the other. If it wanders, snapping is the wrong tool and free
placement with a stated elevation is the right one. Both are in the tool, and the
picture has not been asked.

**What the tags are for.** A structure carries a word, and the tool cycles it
through four guesses. Which words the painting actually needs is not known.
