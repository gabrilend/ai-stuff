# 1002 — The Lattice Is The Measurement

| | |
| --- | --- |
| Phase | 10 — The Tracing Table |
| Blocked by | 1001 |
| Blocks | 1003 |
| Reads | `src/040-the-projection.info.md`, `src/077-the-scene-file.info.md` |
| Open questions | one, at the bottom |

## Current behavior

A scene says where the world sits in its picture with five numbers, and for a
picture this project drew they are known exactly because the same run wrote both.

For a picture somebody else made they are not known at all. They have to be
measured off it, and measuring an isometric projection off a painting with a ruler
means reading a cell's diamond to the pixel and being wrong by a fraction that
compounds across eighty cells.

## Intended behavior

Do not measure it. **Draw the lattice over the picture and adjust it until it
fits.**

At a given elevation, the world's cell grid projects to a lattice of diamonds. If
the five numbers are right, that lattice lands exactly on the stonework the
painting drew at that elevation. If they are wrong it drifts, and it drifts
*visibly* — a half-pixel error in the cell width is a whole cell of drift by the
far corner, which is obvious on a picture and invisible in a number.

So the numbers are a thing somebody nudges until the picture agrees, rather than a
measurement somebody takes. The lattice is the instrument.

**Raising the elevation slides the lattice up the screen** by exactly one layer's
pixels. That is the second measurement and it comes free: pick a step in the
painting, raise the elevation by one, and see whether the lattice moves from the
tread below to the tread above. When it does, the layer height is right.

## Suggested implementation steps

1. Draw the lattice as lines rather than filled diamonds, so the painting stays
   visible underneath it. The point is the alignment between the two.
2. Nudge by one pixel per key, and by ten with a modifier. A calibration that can
   only move in tens cannot be finished, and one that can only move in ones takes
   an afternoon to cross a picture.
3. Show the five numbers as text. That is not a button and it is the only way to
   write down what was found.
4. Only the lattice near the pointer needs drawing. Eighty by eighty diamonds
   over a whole painting at every frame is six thousand lines nobody is looking
   at.

## Related documents and tools

- [1003](1003-tracing-is-clicking-corners.md) — what uses the calibrated lattice
- `src/077-the-scene-file.info.md` — where the five numbers end up

## Open question

**Is the painting on a consistent lattice at all?** It was drawn rather than
rendered, so its perspective may wander, and a lattice that fits one corner may be
a cell out at the other. If it does wander, snapping to the lattice is the wrong
tool and free placement with a stated elevation is the right one. The tool should
offer both until the picture has answered this, and the picture has not been asked
yet.
