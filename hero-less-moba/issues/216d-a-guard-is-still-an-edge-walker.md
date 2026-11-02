# 216d — A Guard Is Still an Edge Walker

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 216a, 216b |
| Blocks | — |
| Reads | [guards are leashed](304-guards-are-leashed.md), [the shape of the code](../docs/018-the-shape-of-the-code.md) |
| Open questions | M6, M7 — settled below |

## Current behavior

*Built — see [what is built](#what-is-built) below. This section is the state it was
written against.*

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

## What is built

**All five steps, and the step layer is universal.** A guard's position is its x and y. Its
three rows are in the pattern table, ahead of everything else, and the brain chooses them the
way it chooses any other row. `node_from` is the last node it reached and `node_to` the one
it is aiming at; the offset, the edge fraction, the edge walk and the four-row next-node
dispatch are gone.

| Row | Places its goal at | Pace |
| --- | --- | --- |
| `patrol` | the next node of its wander, re-asked of the graph on reaching each one | relax |
| `leash` | its leash node, straight | hurry |
| `chase` | its target's skin, pulled back to the end of its rope | hurry |

**And it found that no guard had ever moved.** A guard was put out with both ends of its
edge on the tower's node — an edge of length nought, which the walk stepped over rather
than divide by. It never crossed a node, so it never asked where to go next: no guard in
any match ever patrolled, and none ever closed on anything. "No guard ever enters the
leashing state", which [a scenario](../scenarios/a-tower-commits-and-a-guard-comes-home.lua)
recorded as a finding about ordinary play, was this. Guards now walk their ground — a lane
guard to the edge of its hundred and twenty-eight paces, a base guard across the interior.

Three things fell out of guards actually walking:

- **Home was unreachable for a base guard.** A leashing guard was home within eighteen paces
  of its leash node, and a base guard is leashed to a library twenty-one paces in radius:
  the rule about standing in masonry held it twenty-five out. There is now one definition of
  reaching a node — a body's room from the face of any live building on it — used by the
  patrol and the leash alike.
- **A guard walked into its own tower and stood there.** Having reached its tower's node on
  the road and picked the neighbour on the far side, it was dead in line with the tower and
  its goal, and the step layer's correction — out along the line from the building's centre
  — has no sideways in it head-on. One guard stood at a wall for three thousand ticks.
  `patrol` and `chase` now aim at a building's side first when the straight line runs
  through it. Only stone, which never moves; bodies stay the step layer's question.
- **Bodies against stone read as inside it.** The reading that counts bodies in masonry
  measured strictly, while the push out of stone leaves the same hair of slack the
  separation pass does. A body the rule had just put against a wall counted as inside it.
  The reading now allows the same hair, as the overlaps reading already did.

Tested in [the invariants](../tests/051-the-invariants.info.md): a guard walks node to node
inside its leash on the `patrol` row; a push written into its position stays; `chase` aims at
the skin of a target inside its ground and at the end of its rope for one beyond it; a lane
guard and a base guard dragged past their ropes turn, refuse every target and get home; and
a guard dead in line with its tower and the node beyond walks round it.

## Settled

**M6. Does a guard need the graph at all? — For its patrol, yes; for the other two, no.**
`patrol` keeps the graph. Wandering node to node keeps a guard on the roads the map was
built with rather than at random points in a circle, and it keeps the wander stream drawn
once per node reached, which is the same rhythm it was designed with. `leash` and `chase`
aim straight at where they are going, because both destinations are inside the guard's own
ground by definition and the ground in there has nothing to walk round but the tower —
which `round_the_stone` handles. The greedy "whichever neighbour is nearer" rows were a
jagged route to the same place. So the dispatch lost three rows, as the question guessed,
and the one left is a function rather than a table.

**M7. What is the offset for, once positions are points? — Nothing; it is deleted.** Its
two writers were the edge walk's correction and `nudge`, and its one reader was the edge
walk's position. Nothing else read it — not the replay log, which records the graph nodes
and the position, nor the snapshot, nor the renderer. The record no longer has the field.
`wander_node` on the record is also read by nothing and was not, as far as can be found,
ever written; it is left for whoever next touches the record, because removing it is not
this issue.

## Related documents and tools

- [216a](216a-a-goal-and-a-step.md), the layers a guard does not yet use
- [216b](216b-every-way-of-moving-is-a-row.md), the table its three rows already sit in
- [304 — guards are leashed](304-guards-are-leashed.md)
