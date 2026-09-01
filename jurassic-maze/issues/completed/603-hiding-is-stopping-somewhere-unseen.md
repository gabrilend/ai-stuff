# 603 — Hiding Is Stopping Somewhere Unseen

| | |
| --- | --- |
| Phase | 6 — The Habitat |
| Blocked by | 403, 601, 602 |
| Blocks | 604 |
| Reads | [dinosaurs in a habitat](../../docs/019-dinosaurs-in-a-habitat.md) |
| Open questions | none |

## Current behavior

`Sight.find_cover`, breadth-first over surfaces the body could stand on, so the
first hidden place found is the nearest one and there is nothing better further
out.

**The thing that makes it read as hiding is that a successful hider stops.**
Fleeing looks like panic; stopping behind a wall looks like intent, and it is one
line — the arrival sets idle rather than choosing somewhere else.

Failure falls back to fleeing, and both the failure and the flight are counted. A
maze where hiding always fails is a maze with no cover, which is a fact about the
generator's parameters rather than about the creature.

## Intended behavior

A hider searches nearby surfaces for one from which the sight march is blocked,
scored by whether it is blocked and how far the trip is, bounded by the same
`search_budget` the errand pathfinder uses and run on the same
`sight_interval` cadence.

**The thing that makes this read as hiding rather than fleeing is that a
successful hider stops.** It arrives somewhere it cannot be seen and it idles
there, and it moves again only when the thing it is avoiding comes into sight.
Fleeing looks like panic; stopping behind a wall looks like intent. That is the
entire difference and it is one line — the arrival sets `idle` rather than
choosing a new destination.

A hider that finds nowhere hidden within its budget falls back to fleeing, and
the fallback is **counted** in the report. A maze where hiding always fails is a
maze with no cover, which is a fact about the generator's parameters that should
arrive as a number.

## Suggested implementation steps

1. Write the candidate sweep: surfaces within a radius, reachable, scored.
2. Score by sight-blocked first and distance second, so a nearer hidden spot beats
   a far one but any hidden spot beats an unhidden one.
3. Write the arrival: set `idle`, keep the avoided body's id and generation, and
   re-check sight on the cadence.
4. Write the fallback to flee, and count it.
5. Test: on a maze with known cover, a hider from a known seeker reaches a
   surface the seeker cannot see. On a completely open plateau the fallback fires
   and is counted.

## Related documents and tools

- [Dinosaurs in a habitat](../../docs/019-dinosaurs-in-a-habitat.md)
- [Line of sight through stone](../../docs/018-line-of-sight-through-stone.md)
