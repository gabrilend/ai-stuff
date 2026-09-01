# Dinosaurs In A Habitat

"Dinosaurs rumbling through a habitat hiding and playing games." Three things in
that sentence and each one is a piece of machinery: **rumbling** is a body wider
than a cell, **hiding** is
[line of sight](018-line-of-sight-through-stone.md), and **playing games** is
[the next document](020-games-that-creatures-play.md).

## A body that is bigger than one cell

A dinosaur's `radius` is more than half a cell, so its footprint is a square of
cells rather than one. It uses the `striding` row of
[the locomotion table](012-locomotion-is-a-dispatch-table.md), which is the
ordinary walk with the enterability check applied to every cell of the footprint
instead of one.

Three consequences, all of them the kind that surprise somebody later:

**A dinosaur cannot go everywhere a little guy can.** A one-cell corridor does
not admit a three-cell animal. That is correct and it is the most interesting
thing about having them share a maze — the little guys have a whole network of
boltholes, and the network is not a feature anybody added.

**A dinosaur's stance is its centre**, and its centre may be over a cell it could
not itself stand on if it were small. The footprint check is what matters; the
stance is only for indexing.

**A dinosaur occupies several buckets.** The `index` pass puts a body in the
bucket for its stance, and a three-cell animal in one bucket is invisible to
anything standing beside its tail. So a wide body is placed in every bucket its
footprint covers, and the `meet` pass's greater-id rule stops the duplicate pairs
that would otherwise cause.

## Hiding

A dinosaur that does not want to be seen heads for a surface from which the
thing it is avoiding cannot see it — a cell where the sight march is blocked.

Finding one is a search over nearby surfaces, scored by whether sight is blocked
and how far away it is, bounded by the same `search_budget` the errand pathfinder
uses. It runs on the `sight_interval` cadence rather than every tick, for the
same reason and with the same per-body phase offset.

The thing that makes this read as hiding rather than as fleeing is that a
successful hider **stops**. It arrives somewhere it cannot be seen and it idles
there, and it only moves again when the thing it is avoiding comes into sight.
Fleeing looks like panic; stopping behind a wall looks like intent.

## Rumbling

Dinosaurs are heavy, and heaviness is entirely a rendering matter here: a wide
body, a slow step, and a small vertical bob per step so that the body settles on
each footfall. There is no mass anywhere in the simulation and nothing has
momentum but the balls.

Two dinosaurs that meet do not push each other. They step around each other by
the same rule any two walkers do — lower id gets the surface — and a dinosaur that
cannot fit past another simply waits. Waiting looks like deference and costs
nothing.

## The habitat, which is the same maze

Nothing about the stone changes for this phase. The dinosaurs live in the maze
the balls rolled down and the fencers fought in. That is the whole arrangement of
this project working as intended: one piece of geometry, understood once, and a
succession of things put into it.

What changes is which parts of it matter. For a ball the interesting features are
slopes and ledges. For a fencer they are corridors narrow enough to be blocked.
For a dinosaur they are the wide terraces it can cross and the sightlines across
them — and those were in the maze all along without anybody putting them there.

## Related documents and tools

- [Line of sight through stone](018-line-of-sight-through-stone.md)
- [Games that creatures play](020-games-that-creatures-play.md)
- [Locomotion is a dispatch table](012-locomotion-is-a-dispatch-table.md) — the `striding` row
