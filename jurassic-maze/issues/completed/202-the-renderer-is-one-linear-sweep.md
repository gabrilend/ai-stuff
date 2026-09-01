# 202 — The Renderer Is One Linear Sweep

| | |
| --- | --- |
| Phase | 2 — The Eye |
| Blocked by | 101, 102, 201 |
| Blocks | 203, 204, 308 |
| Reads | [drawing a pile of stones](../docs/007-drawing-a-pile-of-stones.md) |
| Open questions | 6 (is the jungle ever in scope) — does not block |

## Current behavior

Two static meshes, built once at load, drawn with the camera as a transform.
Rebuilding per frame would be a hundred thousand polygons of work to produce a
picture identical to the last one.

There are now **two** sweep orders and both are correct. Row by row is the array's
own memory order and is what the pure sweep and the face count use. Band by band
groups cells sharing one value of `x + y`, and the mesh is built in that order
with each band's index range recorded — because **bodies have to be drawn between
the bands**. A mesh drawn in one call is drawn all at once, and a ball drawn
afterwards sits on top of every wall in the maze including the ones in front of
it. That was not foreseen when this issue was written; the interleaving is what
made it necessary.

Face counts: about 26,000 faces for 209,000 blocks of stone, which is twelve
percent. Two thirds of every block faces away from a fixed camera and the rest is
mostly buried.

## Intended behavior

The renderer never draws a block. It draws **faces**, and a face is a
disagreement between one column and its neighbour.

For each column, break its bits into **runs** of consecutive stone. For each
run, up to three faces:

| Face | When |
| --- | --- |
| top, a diamond | always, at the run's topmost layer |
| right, a parallelogram | over the layers where the neighbour at `x+1` has no stone |
| left, a parallelogram | over the layers where the neighbour at `y+1` has no stone |

The exposed layers of a side face are `run & bit.bnot(neighbour)` — one
operation. Two identical columns side by side produce zero and draw nothing,
which is why a large solid terrace costs its outline rather than its area.

The other two sides and the underside face away from the viewer and are never
considered. That is two-thirds of the geometry gone, for free, because the camera
angle is fixed.

**Back to front is the array's own order.** `for y ascending, for x ascending`
is the correct painter's order, and the column index is `x + y * width`, so the
sweep is linear from the first element to the last. This is why the index is that
way round — see issue 101.

**Nothing is allocated per frame.** Face vertices are written into one reused
array. A renderer that allocates is a renderer that stutters whenever the
collector notices, correlated with nothing.

## Suggested implementation steps

1. Write the run decomposition over a column: yield `{bottom, top}` pairs. Fold
   it. It is a loop over set bits, not a loop over layers.
2. Write the three face emitters, each writing four vertices into the shared
   array.
3. Write the sweep over the visible range from issue 201, in index order.
4. Write the outline as part of each face rather than as a second pass — a second
   pass doubles the sweep, and the sweep happening once is the entire design.
5. Measure: frames per second at the default maze size, and the count of faces
   emitted. Both go in the report. A face count that jumps when nothing visible
   changed means the culling broke.
6. Test: a hand-built store of two identical adjacent columns emits no face
   between them. A column with a tunnel emits two top faces. A fully enclosed
   column emits none.

## Related documents and tools

- [Drawing a pile of stones](../docs/007-drawing-a-pile-of-stones.md)
- [The isometric projection](../docs/006-the-isometric-projection.md)
