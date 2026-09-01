# 805a — The World Is Drawn From The Model

| | |
| --- | --- |
| Phase | 8 — The Mountain |
| Blocked by | 803 |
| Blocks | — |
| Part of | [805](805-a-ball-is-a-sprite-in-a-solid-world.md) |
| Reads | `src/042-the-renderer.info.md`, `src/071-the-model.info.md` |
| Open questions | one, at the bottom |

## Current behavior

The world is drawn by a sweep over columns that turns disagreements between
neighbouring bitmasks into polygons. It is fast, it is correct, and it does an
outline trick with two meshes that costs two draw calls for the whole maze.

It is also **a second description of the world**, and the physics now uses the
first. The model has 438 faces for the mountainside and the sweep emits 3616 for
the same stone; both are right, and a bug in either would be a picture that does
not match what balls are bouncing off — the hardest kind of bug there is, because
both halves look correct on their own.

**They are now checked against each other**, which was the risk rather than the
feature. `tests/072-the-model.lua` sweeps the renderer over the mountainside,
gathers what it says about every column top and every face between two columns,
and compares it against what the model says about the same edges. They agree
everywhere. That is most of the value this issue was going to buy, at none of the
cost of a second renderer, and it is why what follows is no longer urgent.

## Intended behavior

A second renderer that draws the same world from the model's faces, so the two
can be put side by side.

**A face is already a rectangle with a normal**, so the four screen points are
the projection of its four corners, and there is no sweep and no bitmask
arithmetic at all.

**The tone comes from the normal**, not from a face constant. Straight up is the
lit tone; the two horizontal directions that face the camera take the other two.
That is the same three-tone shading the sweep does, arrived at from geometry — so
a surface added later that is neither a top nor a riser shades correctly without
anybody deciding what it is.

**Faces are banded by `x + y` and drawn back to front**, because bodies have to
be drawn between the bands. A ball drawn after all the stone sits on top of every
wall in the maze including the ones in front of it.

**The rim is not drawn.** It is the one kind of face in the model that does not
correspond to any stone — a wall around the edge of the world that exists so
nothing leaves it. Drawing it would put a fence around the mountain.

## Suggested implementation steps

1. Draw it with flat colours and no outline first, and compare it against the
   sweep on the same map at the same camera. They are the same world by two
   routes; any difference is a bug in the new one.
2. Take the tone from the normal even though there are only two kinds of face
   today. The whole reason to carry normals is that the shading stops being a
   table of special cases.
3. Count the faces both ways and put both numbers in the report. A model that
   draws in a tenth of the polygons is worth knowing about; a model that draws in
   a tenth of the polygons and looks different is a bug with a number attached.

## Related documents and tools

- [805](805-a-ball-is-a-sprite-in-a-solid-world.md) — the whole of which this is half
- [805b](completed/805b-a-ball-is-a-baked-sprite.md) — the other half
- `src/071-the-model.info.md` — what a face is

## Open question

**Does this replace the sweep or sit beside it?** The sweep insets its faces by a
hair over a mesh of full-size ones in the outline colour, which draws every line
in the maze in two draw calls and has no equivalent here. Two renderers is two
things to keep in step; one renderer means losing something that works and is
already tuned. Keeping both is defensible only while one is checking the other,
which is not a permanent arrangement. Not answered.
