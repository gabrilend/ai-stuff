# 1301 -- The world is an edge graph, and the edges carry the material

**Phase:** 13, the world becomes solid
**Blocked by:** nothing. This is the foundation the rest of the phase stands on.
**Blocks:** [1302](1302-structures-and-elevation.md),
[1305](1305-the-unseen-is-a-surface.md)
**Documents:** [the world is an edge graph](../docs/109-the-world-is-an-edge-graph.md),
[the map is geometry not a picture](../docs/006-the-map-is-geometry-not-a-picture.md)

## Current behaviour

The world is flat and two-dimensional. Walls are segments -- a pair of endpoints
and some flags. Regions are polygons. There is no height anywhere, no surface, no
material, and nothing that says what a wall *looks like*; appearance belongs
entirely to the sprite a thing wears, and the map itself is drawn as lines.

A wall knows where it is and knows nothing about what it is made of, what is on
either side of it, or which other walls it meets. Two walls meeting at a corner
are two independent records that happen to share coordinates, and the fact that
they meet is rediscovered by arithmetic every time anybody needs it.

## Intended behaviour

**A vertex holds, for each thing it connects to, the index of that vertex and one
material enum.** That pair is an edge. The set of edges is the model.

    vertex
      x, y, z
      connections[]  -- each: { other vertex index, material }

Faces are implied by edge loops rather than stored. Nothing is stored twice.

### Why the edge, and not the face

The two operations a DM performs on live geometry are **drag a vertex** and
**bisect an edge**. In a triangle soup both are global: every face touching the
moved point has to be found and rewritten, and a bisection renumbers everything
after it. In an edge graph both are local and constant-time -- dragging changes
three numbers, bisecting inserts one vertex and rewires two connections.

The world has to be editable *while people are looking at it*, so the cost of an
edit is the cost of the whole feature.

This is the structure a modelling program uses, and it is used here for the same
reason: it makes the editing operations cheap and it makes them obviously
correct.

### The material lives on the edge, not on the face

An edge is a boundary between two things, and a boundary is where appearance
actually lives. The far side of a doorway and the near side of the same doorway
are different appearances of one edge, which is why the enum sits there.

**A material names an appearance, not a substance.** "A stone doorway shrouded in
shadow" is a material. "Stone" is not, because it does not say what you are
looking at it through. This is the vocabulary decision the rest of the phase
depends on, and [1305](1305-the-unseen-is-a-surface.md) is what spends it.

### The edge graph is the whole model

Once edges carry material, there is nothing left for a separate face list to
hold. A face is an edge loop; its appearance is composed from the materials of
the edges bounding it. So the format does not have a mesh with annotations -- it
has one structure, and the geometry and the appearance are the same data read two
ways.

## Suggested implementation steps

1. The vertex record: three fixed-point coordinates, and a run of connections in
   the flat-array style everything else in the world uses -- an index and a count
   into a shared connections block, never a pointer.
2. The connection record: the other vertex's index, and the material enum. Both
   fixed-width; the whole thing must fit the wire format's existing discipline.
3. The material enum as a bitmask, so an appearance can be a combination without
   the table growing multiplicatively.
4. Drag a vertex: change three numbers, touch nothing else. A test that asserts
   no other record changed.
5. Bisect an edge: one new vertex, two rewired connections, the material
   inherited by both halves. A test that asserts the loop is still closed.
6. Validation: every connection is reciprocal, every loop closes, no vertex
   points at itself, and the depth of nesting is bounded. The validator refuses
   rather than repairs, as everywhere else.
7. The world file format grows a vertex block and a connections block. The
   header already carries a version and a checksum that survives a format change
   -- see open question 15.4, which was answered for exactly this day.
