# 1304 -- The reveal is a distance field, and it goes round corners

**Phase:** 13, the world becomes solid
**Blocked by:** [1303](1303-visibility-is-one-equation.md)
**Blocks:** [1309](1309-the-phase-13-demo.md)
**Documents:** [visibility is one equation](../docs/110-visibility-is-one-equation.md)

## Current behaviour

Sight has a hard edge. A point is visible or it is not, decided by whether a ray
reaches it, and the edge of the visibility polygon is a discontinuity -- one step
sideways and a whole wedge of the world appears at once.

That is correct for a security boundary and wrong for the way somebody walks up
to a corner. Approaching a bend, a person sees a little more of what is round it
with every step. The polygon gives them nothing, nothing, nothing, and then all
of it.

## Intended behaviour

**A cached distance field, flooded outward from the viewer through open space,
and a tile is revealed when its value is under a threshold.**

This is a *Dijkstra map*, which is the name it goes by among roguelike
developers, after the version Brogue popularised. Its general name is a
**distance transform** or **distance field**; the continuous form solves the
eikonal equation and is computed by fast marching; the pathfinding form, where
you find a route by walking downhill, is a **flow field**. All the same object
seen from different trades.

### Why it satisfies the one-equation rule

The flood fill is the **cache**, not the query. Filling is a breadth-first walk,
done when the source moves. The per-tile question is one array lookup and one
comparison, which is exactly the closed form
[1303](1303-visibility-is-one-equation.md) demands.

The expensive part is amortised into a thing computed once and read many times.
That is the same trade as everything else in this phase.

### It goes round corners, and that is the point

**Flood distance is not line of sight.** A ray stops at a wall; a flood goes
around it and arrives at the far side with a larger number. So a tile just round
a bend has a distance slightly above the tiles in front of it, and as somebody
walks forward that distance falls, and the tile fades in.

This means a person can see slightly around a corner. That is a departure from
geometric sight and it is intended -- it is what a gradual reveal *is*. Anybody
reading this later and deciding it is a bug should read this paragraph first.

### The bounded flood

The fill only ever runs out to the reveal radius, so its cost is the number of
tiles in range and not the size of the world. A roguelike recomputes several of
these per turn on a whole map without anybody noticing; bounded, at tile
granularity, this is hundreds of cells rather than thousands of vertices.

### Which grid

The elevation tilemap's, from [1302](1302-structures-and-elevation.md). One grid
serving the ground, the reveal, and whatever else wants tiles, rather than three
grids that can disagree about where a cell begins.

## Suggested implementation steps

1. The field: a flat array of distances over the tilemap's grid, one per viewer,
   sized to the reveal radius rather than to the world.
2. The flood: a breadth-first walk with a queue, refusing to cross a tile a
   structure's geometry blocks. Integer distances only.
3. Recompute when the source moves more than a tile, not every beat.
4. Fold the field into the reveal expression as one more term.
5. A test that the field is symmetric-ish and monotone: no tile has a distance
   lower than a neighbour's minus one, which catches a broken frontier.
6. A test that the field is identical on replay -- it must be, since it is
   derived from geometry and position with no randomness at all.
