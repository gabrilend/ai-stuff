# 202 — Walking an Edge of the Graph

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 101, 201 |
| Blocks | 203, 206, 209, 508 |
| Reads | [the map and its milestones](../docs/002-the-map-and-its-milestones.md), [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

A body's position on a lane is two numbers — how far along, and how far across —
with its world position derived from the lane's own curve. That is what makes a rank
survive a corner, and it means the move pass never computes a square root: step
lengths and cumulative distances are precomputed at map build time.

Guards walk the graph directly instead, by neighbour, because they have no lane.

## Intended behavior

A soldier's position is always "on the edge between node A and node B, some
fraction of the way along." Advancing is arithmetic, not search:

1. Add `speed` to `progress`.
2. If `progress` passes 1, set `node_from = node_to`, look up the next node along
   the lane's path in the direction `facing` points, and carry the remainder into
   the new edge.
3. Derive `x` and `y` from the two nodes and the fraction.

There is no pathfinding, no A*, no flow field, and no per-tick search of any
kind. With a thousand soldiers on the map that difference is the whole frame
budget. The graph was authored to make this true; this issue is where the payoff
is collected.

Passing a node that carries a milestone updates the soldier's `milestone` field
and, if it is deeper than what the team has reached in that lane, the team's push
depth.

At a **junction**, the next node is not simply the next along the path — the
soldier asks the sign-post standing there. Wave units, guards, and monsters
ignore sign-posts and continue along their own lane. Only heroes read them. That
is not an oversight: if waves could be rerouted, a team could feed all three
lanes into one and the three-lane structure of the map would be decorative.
Sign-posts arrive in issue 508; until then the junction branch returns the
straight-on answer and the comment above it says so.

`x` and `y` are derived for the renderer and for weapon range. Nothing about
progress, lanes, or how far a push has gone ever reads them.

## Suggested implementation steps

1. Write the move pass over the soldier store, sliced for the thread pool: it
   reads the graph, which is read-only, and writes only into per-soldier fields.
2. Write the edge-crossing carry so that a soldier fast enough to cross two edges
   in one tick does so correctly. Do not clamp; a clamp is a silent fallback and
   fallbacks are errors.
3. Write the milestone update, and the push-depth update as a single compare-and-
   maybe-write per soldier.
4. Stub the junction branch with a comment naming what will replace it.
5. Write a test that walks one soldier from one library to the other and asserts
   it passes all nine milestones in order and arrives.
6. Write a second test at a speed high enough to cross several edges per tick,
   asserting the same.

## Related documents and tools

- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
