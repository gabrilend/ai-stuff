# 071-the-model

Turns a height field into flat quadrilaterals in three dimensions.

Read this page rather than the source. The source is for when one named function
is misbehaving; this is for everything else.

## What it is for

Nothing in the project had ever built geometry. The renderer drew a diamond and
two parallelograms straight from the height field; the ball sampled an
interpolated height field rather than touching anything solid. Both worked by
knowing the world is a grid, and neither could answer "what is the surface here"
without that assumption.

That was affordable while the world was a grid of columns. It stops being
affordable the moment a ball has to bounce down a staircase, because a staircase
is a sequence of small flat faces and small vertical ones — and the interpolated
height field exists precisely to smooth those away.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `build(field, floor_z)` | a height field in planes | the model |
| `describe(m)` | | face counts, as lines of text |
| `TOP`, `RISER` | | the two kinds of face |

`field` is anything carrying `width`, `depth` and a zero-based `height` array **in
planes** — a cell of height 22 is ground you stand on at 22. That is the map's
convention, not the stone store's, and the two differ by one.

## What a model is

| Field | Type | Meaning |
| --- | --- | --- |
| `count` | integer | how many faces |
| `kind[i]` | `TOP` or `RISER` | horizontal or vertical |
| `x0,y0,z0[i]` / `x1,y1,z1[i]` | numbers | the two corners of the rectangle |
| `nx,ny,nz[i]` | numbers | the outward normal, one of six axis directions |
| `at[cell]` | array of face ids | the faces on or beside that cell |

Flat parallel arrays rather than an array of tables: a large model would
otherwise be one allocation per face, and the physics walks these in its
innermost loop.

**Every face is an axis-aligned rectangle, so two corners with one degenerate
axis describe it completely.** That is exact for this world rather than a
simplification of it. It halves the face count against triangles and it turns a
sphere-against-face test into three clamps and a subtraction instead of a
barycentric solve.

## Three kinds of face, and no others

**Tops.** One horizontal face per flat area, greedily merged: the longest run of
equal height along x, then that run pushed down in y while every cell still
agrees.

**Risers.** One vertical face wherever a cell is taller than a neighbour,
spanning the difference, facing the lower side. Every cliff, every rim and every
tread of every staircase is one of these, and none is a special case. All four
sides are emitted rather than the two facing the camera — a renderer can afford
to know two thirds of the geometry is turned away, and the physics cannot,
because a ball arrives from whichever direction it likes.

**The skirt.** Outside the map the ground is `floor_z`, so the rim closes. Without
it a ball leaving the world falls past an open edge rather than off a solid
object.

## The merge is about seams, not about size

A shelf twelve cells across becoming one face instead of a hundred and forty-four
is the obvious benefit and the smaller one. The real reason is that a ball
rolling across an unmerged shelf crosses a face boundary every single cell, and
every boundary is a chance for a floating-point comparison to place it between
two faces and therefore on neither. **Fewer seams is fewer chances to fall
through the floor.**

On the mountainside the merge turns 2304 cells into 150 tops, a factor of fifteen.

## What the test checks, and what it deliberately does not

`tests/072-the-model.lua` never checks the merge. A greedy merge is exactly the
kind of thing that is correct on the case somebody pictured and wrong one cell to
the left of it, so the test checks the *result* against the field it came from:
every cell under exactly one top at its own elevation, every edge between unequal
cells carrying exactly one riser spanning exactly those two elevations, every
edge between equal cells carrying none.

Together those say the model and the field describe the same solid, which is all
the model is for. The merge may then group faces however it likes.
