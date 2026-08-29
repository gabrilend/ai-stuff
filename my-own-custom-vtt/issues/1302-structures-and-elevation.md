# 1302 -- Structures, and the ground they sit on

**Phase:** 13, the world becomes solid
**Blocked by:** [1301](1301-the-world-is-an-edge-graph.md)
**Blocks:** [1303](1303-visibility-is-one-equation.md)
**Documents:** [the world is an edge graph](../docs/109-the-world-is-an-edge-graph.md),
[the map is geometry not a picture](../docs/006-the-map-is-geometry-not-a-picture.md)

## Current behaviour

Regions exist and do half of this already. They are named areas with polygon
boundaries, they nest to a depth of eight, `region_deepest_containing` puts a
body in the cellar rather than the tavern above it, and `region_is_within`
answers the permission question by walking a parent chain with no allocation.

What they do not do is **own geometry**. A region names an area; it does not
contain the walls. And there is no ground at all -- the world is a plane at
height zero with segments standing on it.

## Intended behaviour

Two kinds of thing, which intersect.

**A structure** is a named, nested piece of built geometry: a tavern, its cellar,
the crate in the corner of the cellar. It owns vertices and edges from
[1301](1301-the-world-is-an-edge-graph.md). Structures nest, exactly as regions
nest today, and for the same reason -- the deepest one containing you is the one
you are in.

**An elevation tilemap** is the ground: a grid with a height per cell. It is not
built by hand vertex by vertex; it is sculpted, and it is regular so that the
things standing on it can find their footing with arithmetic rather than search.

**They intersect.** A tavern sits on a hillside. The structure's vertices have
their own heights and do not care what the ground is doing; the tilemap continues
underneath. Where they meet is not a merge -- neither owns the other, and neither
is rebuilt when the other changes.

### The structure is the region, grown up

This is not a new tree beside the region tree. It is the region tree with
geometry attached, and the existing walk -- deepest wins, an ancestor of zero is
the whole map, no cycle guard because the validator establishes there are no
cycles -- is the walk this needs. A scope over the tavern still owns the cellar.

### The grid arrives from a third direction

[Open question 2.1](../docs/016-open-questions.md) asked how coarse the fog
memory grid should be. The answer twice was *there is no grid*: first because
fog became per-vertex, then because it became authored. The elevation tilemap
brings a grid back, and [1304](1304-the-reveal-is-a-distance-field.md) wants one
too.

**Three things now want the same grid**, so it is one decision rather than three,
and it belongs to the terrain format rather than to the fog. It is still open,
and it should be measured rather than guessed -- see the question as it now
stands.

## Suggested implementation steps

1. A structure record: a name, a parent, and a span into the vertex block.
2. Keep `region_deepest_containing` and `region_is_within` as they are. If a
   structure needs a different containment test than a region, that is a finding
   worth stopping on, because it would mean the two trees were never one tree.
3. The elevation tilemap: an origin, a cell size, a width and a height, and a run
   of heights. Flat array, no pointers, like everything else.
4. Height lookup at a point: which cell, and interpolate across it in fixed
   point. No floating point crosses the arithmetic line.
5. Intersection: a thing's footing is the higher of the ground under it and the
   structure surface under it. Decide once, in one function, so the answer cannot
   differ between the renderer and the simulation.
6. The validator refuses a structure whose parent chain loops, a tilemap whose
   cell size is zero, and a structure whose vertices are outside the world extent.
