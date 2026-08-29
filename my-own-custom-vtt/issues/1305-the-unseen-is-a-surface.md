# 1305 -- The unseen is a surface, not a hole

**Phase:** 13, the world becomes solid
**Blocked by:** [1301](1301-the-world-is-an-edge-graph.md),
[1303](1303-visibility-is-one-equation.md)
**Blocks:** [1307](1307-the-third-view.md)
**Documents:** [the world is an edge graph](../docs/109-the-world-is-an-edge-graph.md),
[the dynamic picture](../docs/012-the-dynamic-picture.md)

## Current behaviour

Beyond what a viewer may see there is nothing. The renderer draws the visibility
polygon and the fog, and what is outside them is black -- an absence, drawn as an
absence. A doorway into an unrevealed room is a hole in the picture.

## Intended behaviour

**Fill the boundary plane with a surface composed from that boundary's own edge
materials.** The unseen reads as the back face of something rather than as a gap
in the world.

A doorway into a dark room is not a black rectangle. It is *a stone doorway
shrouded in shadow*, which is a material -- the enum on the edges bounding that
aperture, in proportion to the edges that bound it.

### The material names the appearance of not-seeing

This is why [1301](1301-the-world-is-an-edge-graph.md) puts the enum on the edge
and why a material is an appearance rather than a substance. "Stone" does not say
what you are looking at it through. "A stone doorway shrouded in shadow" does,
and it is the thing that has to be drawn.

### It leaks nothing, and that is deliberate

The fill is composed from the **boundary's own edges**, and the boundary is
already visible. Nothing behind it is sampled.

The tempting improvement is to sample the far side so the fill matches what is
actually there. **Do not.** A player reading the fill would learn about a room
they have not entered, and the whole point of the surface is that it is honest
about being a surface.

### A player can tell it apart from a wall

Also deliberate. A doorway shrouded in shadow reads as a doorway -- you can see
that there is a way through and that you cannot see through it. It is not a
trick; masonry and an unlit opening are different materials and they look
different. Otherwise four people walk repeatedly into what they believe is a
wall, and the mystery costs more than it buys.

## Suggested implementation steps

1. Find the aperture: the edge loop bounding the boundary between a revealed
   structure and an unrevealed one. This falls out of the edge graph -- it is the
   loop whose two sides differ in reveal.
2. Compose the fill from the loop's materials, weighted by edge length.
3. Draw it as a surface on the aperture plane, at the aperture's depth, so it
   occludes correctly and does not float.
4. A test that no term in the composition reads a vertex on the unrevealed side.
   That is the leak test surviving into a design that no longer treats leaks as
   fatal, because this one would be visible to a player and would be a lie.
5. A material vocabulary big enough to say *shrouded*, *lit*, *submerged*,
   *smoke-filled* -- as bitmask combinations rather than as a table of every pair.
