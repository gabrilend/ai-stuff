# 078-generate

A description and a seed become a place. Four stages, and the split between the
first two carries the phase.

| Stage | Produces |
| --- | --- |
| validate | `076-describe`. Refuse before anything expensive. |
| lay out | Rooms and corridors as an **abstract graph**. No coordinates. |
| realise | Topology into wall segments and region polygons. |
| furnish | Things standing in it. |

## Why the graph exists before the geometry

Nearly every question worth asking is a question about the graph:

| Question | Against the graph | Against geometry |
| --- | --- | --- |
| Is it connected? | A walk | A flood fill over what, exactly? |
| Is there a loop? | Edges minus nodes plus one | Effectively unanswerable |
| Is the treasure behind the guard? | A path check | Unanswerable |

## The layout is a chain, deliberately

Connected by construction either way, but a chain has a property an arbitrary
tree does not: **every edge joins rooms that end up next to each other**, so every
one becomes a straight corridor rather than a passage routed around whatever is
in the way.

The layout stage is choosing a shape it knows the realise stage can build. That
constraint is shared between two files and invisible from either alone, so it is
written down in both.

Loops join non-neighbours and are routed **up and over** the row, which keeps them
from having to be threaded past intervening rooms.

## Loops are retried, not attempted once

An early version drew two rooms per loop and gave up on a collision — so a
description asking for one loop routinely got none. And `generate_check` only
*capped* the count rather than requiring it, so nothing noticed.

Both were wrong. Loops are now placed with a bounded retry, an impossible request
is refused by name, and the check requires the **exact** count. A check that can
only catch too many is half a check, and the missing half is the one that catches
a generator ignoring its description.

## Doorways are holes, not painted doors

`emit_side` renders a room's wall as a run of segments **skipping the gaps**. A
wall is a run with a hole in it, not one segment that is somehow permeable — which
falls out of walls being segments, where a picture-based map would have had to
paint a door.

Gaps are sorted before emitting, because two doorways on one side in the wrong
order would produce a segment running backwards — a wall of negative length,
which the validator refuses for good reason.

## `generate_check` asks a different question from `world_validate`

`world_validate` asks *is this a coherent world*. It would happily pass a tidy
dungeon with three rooms when somebody asked for eight.

`generate_check` asks *is this the world that was described*: the room count, the
required features, the loop count, the size bounds, no overlaps — **and whether
you can actually walk between the rooms.**

That last one was missing. An early generator produced a perfectly connected
graph and emitted four solid walls per room; the graph check passed, the
validator passed, and the result was a row of sealed boxes that only the demo's
picture revealed. The reachability check now floods the geometry on a
one-metre grid and a test seals a real dungeon on purpose to prove the check is
not vacuous.

The flood uses **four directions, not eight** — a diagonal step can slip between
two walls meeting at a corner, which would report a sealed room as reachable.

## Determinism

Everything draws from **named streams**, so adding a draw in the layout does not
silently change what gets furnished. Room placement is a deterministic row rather
than a physical relaxation: "push apart until it settles" is a different number
of steps on a different machine, and the whole point of a seed is gone.
