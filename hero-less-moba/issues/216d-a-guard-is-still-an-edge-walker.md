# 216d — A Guard Is Still an Edge Walker

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 216a, 216b |
| Blocks | — |
| Reads | [guards are leashed](304-guards-are-leashed.md), [the shape of the code](../docs/018-the-shape-of-the-code.md) |
| Open questions | M6, M7 |

## Current behavior

**Everything on a road places a goal and takes a step. A tower guard still walks the
graph, and it is the last thing in the game that moves a different way.**

A body on a lane keeps two numbers — how far along, how far across — and its world
position is derived from them, so a goal in world coordinates converts cleanly in both
directions and one function places any of them.

A guard keeps something else: the node it came from, the node it is going to, and how far
along that edge it has got, plus an offset in world paces to stand it clear of whoever
else is at the same tower. Its position is *an edge and a fraction*, not a point. Walking
is advancing the fraction, and arriving is choosing the next node out of a four-row
dispatch — the next node on a lane, a random neighbour inside the leash, whichever
neighbour is nearer the tower, whichever is nearer the target.

Three of the eleven movement patterns are its: patrolling, walking home, and closing on
something inside the leash. **All three exist as rows in the table and all three delegate**
to the edge walk rather than placing a goal, so the table is complete and the layer beneath
it is not yet universal.

## Intended behavior

**A guard's position becomes a point, like everything else's, and the graph becomes a
thing it consults rather than a thing it lives on.**

Its three patterns then place goals like any other row:

| Pattern | Places its goal at |
| --- | --- |
| `patrol` | the node it has chosen to wander to |
| `leash` | the node of the tower it guards |
| `chase` | its target, at its own reach, if that point is inside the leash |

The graph does not go away. It is what says *which node next* — a guard has no lane and
cannot walk a straight line to a tower through a hillside — so the goal is the next node
rather than the destination, and the guard re-asks when it arrives. That is the same shape
as a lane body aiming a few paces down its own road rather than at the enemy library.

### Why this is worth doing

**The step layer would then be universal**, and every claim made about it would hold for
every body in the game rather than for most of them. Today a guard is not capped in world
paces, is not moved out of the ground it is about to stand on, and reaches the separation
pass as the only thing keeping it out of anybody — which is exactly the arrangement that
had two guards standing inside each other at one tower for a whole match.

**And the offset disappears.** It exists only because a guard's position is derived from an
edge and any correction written into its world position was erased the next tick. A guard
whose position *is* a point has nothing to correct against.

## Suggested implementation steps

1. Give a guard a real position: keep the node it is heading for, drop the fraction along
   the edge, and let the step layer move it.
2. Turn the four-row next-node dispatch from *which node do I step to* into *which node am
   I aiming at*, which is the same table asked one level up.
3. Delete the offset from the guard's record, and the two places that write it.
4. Check the leash still holds. A guard that wanders is bounded by a distance from its
   tower, and that distance is currently measured against a graph position.
5. A scene per guard pattern in [the proving ground](111-the-proving-ground.md) — patrol,
   leash and chase are three mechanics with no test naming them today.

## Open questions

**M6. Does a guard need the graph at all?**
It patrols within a leash radius of its tower, and the ground inside that radius is a
corridor with nothing to walk round. If a guard could aim at any point inside its leash
rather than at a node, the graph stops being part of how a guard moves and the four-row
dispatch loses three of its rows. What that costs is unknown — the graph is also what keeps
a guard from wandering through stone.

**M7. What is the offset for, once positions are points?**
It is described as "how far this body stands from the line its graph position puts it on",
and a guard that has a position of its own does not stand off any line. Whether anything
else has come to depend on it is not checked.

## Related documents and tools

- [216a](216a-a-goal-and-a-step.md), the layers a guard does not yet use
- [216b](216b-every-way-of-moving-is-a-row.md), the table its three rows already sit in
- [304 — guards are leashed](304-guards-are-leashed.md)
