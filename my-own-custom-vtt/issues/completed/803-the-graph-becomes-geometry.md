# 803 -- The graph becomes geometry

**Phase:** 8, content generation
**Blocked by:** [802](802-the-layout-is-a-graph.md)
**Blocks:** [804](804-furnishing-asks-the-ruleset.md)
**Documents:** [the map is geometry](../docs/006-the-map-is-geometry-not-a-picture.md)

## Current behaviour

A checked graph exists. It has no coordinates.

## Intended behaviour

Turn topology into wall segments and region polygons. **Mechanical, and testable
against the graph it came from.**

### What it must produce

Everything the validator insists on, from the start rather than as a repair pass:

- No zero-length wall.
- Region polygons closed, non-self-intersecting, wound counter-clockwise.
- Nested regions genuinely inside their parents.
- Every thing's `region` the deepest one containing it.

A generator that produces worlds the validator refuses is a generator nobody can
use, and **repairing afterwards is how a generator stops matching its own
output.**

### Placing rooms

Rooms get positions such that they do not overlap and connected ones are near
each other. A simple approach — place, push apart, repeat — is fine and must be
**deterministic**: the same number of iterations every time, not "until it
settles", because "until it settles" is a different number of steps on a
different machine and the whole point of a seed is gone.

### Corridors

An edge becomes a gap in each room's wall and a passage between them. The gap is
the interesting part: a wall is a run of segments with a hole, not one segment
that is somehow permeable.

That falls out of walls being segments. A picture-based map would have had to
paint a door; this deletes a piece of wall and adds two.

## Suggested implementation steps

1. Place nodes, deterministically, with a fixed iteration count.
2. Emit each room's outline as segments, leaving gaps where edges leave.
3. Emit corridors as two parallel runs.
4. Emit region polygons, counter-clockwise, with nesting where the graph says.
5. Run the validator immediately and **fail rather than repair**.
6. Write the companion `.info.md`.
7. Test: every generated world validates; rooms do not overlap; every graph edge
   has a walkable passage; the same seed gives byte-identical geometry.
