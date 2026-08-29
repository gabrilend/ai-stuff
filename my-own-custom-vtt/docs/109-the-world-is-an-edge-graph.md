# The world is an edge graph

*Supersedes the flat-world half of
[the map is geometry not a picture](006-the-map-is-geometry-not-a-picture.md).
Walls as segments and regions as polygons were right about the principle and
wrong about the dimension.*

A vertex holds three fixed-point coordinates and, for each thing it connects to,
the index of that vertex and one material. That pair is an edge. **The set of
edges is the model.**

    vertex
      x, y, z
      connections[]  -- each: { other vertex index, material }

Faces are not stored. A face is an edge loop, and its appearance is composed from
the materials of the edges that bound it.

## Why the edge and not the face

The world has to be editable while people are looking at it, so the cost of an
edit is the cost of the whole feature. A DM does two things to live geometry:
**drags a vertex** and **bisects an edge**.

| | triangle soup | edge graph |
| --- | --- | --- |
| drag a vertex | find every face touching it, rewrite each | change three numbers |
| bisect an edge | insert, then renumber everything after | one vertex, two rewired connections |

This is the structure a modelling program uses, for the same reason.

## A material is an appearance, not a substance

"Stone" is not a material here, because it does not say what you are looking at
it through. *A stone doorway shrouded in shadow* is one.

The enum sits on the edge because an edge is a boundary, and a boundary is where
appearance lives. The near side of a doorway and the far side of the same doorway
are two appearances of one edge.

This is what [the unseen is a surface](110-visibility-is-one-equation.md#the-unseen-is-a-surface)
spends: an unrevealed doorway is filled with a surface composed from that
doorway's own edges, so the picture is never a hole.

## Structures, and the ground

**A structure** is named, nested, built geometry: a tavern, its cellar, the crate
in the corner. It owns vertices and edges. Structures nest exactly as regions do
today and the existing walk is the walk this needs -- deepest wins, an ancestor
of zero is the whole map, and a scope over the tavern still owns the cellar.

**An elevation tilemap** is the ground: a grid with a height per cell. Sculpted
rather than built vertex by vertex, and regular so that footing is arithmetic
rather than search.

**They intersect and neither owns the other.** A tavern sits on a hillside; the
structure's vertices have their own heights and the tilemap continues underneath.
Where they meet is not a merge, and neither is rebuilt when the other changes.

## Where the grid ended up

[Open question 2.1](016-open-questions.md) asked how coarse the fog memory grid
should be. It was dissolved twice -- first when fog became per-vertex, then when
it became authored -- and the elevation tilemap brings a grid back from a third
direction, with the reveal field wanting one too.

Three things now want the same grid, so it is **one decision belonging to the
terrain format**, and it is still open.
