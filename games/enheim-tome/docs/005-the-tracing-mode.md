# 005 — The Tracing Mode

How the city gets cut up. **A mode inside the game**, deliberately entered, not a
separate program.

## Why it lives in the game

So that **a map is a thing players can make**. If the editor were a developer
tool, nobody but the author could ever produce a city; inside the game, a map is
a mod, and other people's readings of other places become possible.

That is a good enough reason on its own, and it costs something worth naming:
the game can no longer be *physically incapable* of corrupting a network, because
it now contains code that writes one. Generating and viewing must survive as a
**discipline within one program** — the editing code in its own files, touched by
nothing that draws — rather than as a fact about two programs.

## It is a mode, and that is deliberate

Playing and editing are separate states you switch between on purpose.

They have to be, because the same button means different things in each. In play,
the right button acts on the world; in the tracing mode, it places a node. Keeping
them apart is what stops a mis-click reshaping the city.

The cost is a mode, and a mode is a thing you can be in without noticing. So the
tracing mode should be **unmistakable** — the cage showing every level at once
rather than one, and the map visibly not in its playing state.

## The hands

The same two-hand scheme as everywhere else — **left asks, right acts** — with
the editing gestures hung off it:

| Input | What it does |
| --- | --- |
| **middle drag**, **wheel** | pan and zoom, exactly as in play |
| **left click** | selects |
| **left click, shift held** | drags what is under it |
| **left click, ctrl held** | **severs** the nearest link to the selected node |
| **right click on empty ground** | places a node |
| **right click on a thing** | opens its menu, **without changing the selection** |
| **tab** | opens the menu for whatever is selected |

Two details in there are worth not losing.

**Right-clicking a thing opens its menu without selecting it.** So you can act on
one thing while another stays selected — asking about the lane while the block
stays in the tome. Acting and attending are separated, which is the same idea as
left-asks-right-acts one level up.

**Ctrl-click severs the nearest link to the selected node**, not the nearest link
to the pointer. The selection says *where*, the modifier says *what*, and the
pointer only disambiguates between several links at that corner.

## Cutting and severing are inverses

Placing nodes and linking them **cuts** a region into two. Severing a link
**merges** two regions back into one.

Every state in between is a complete partition — see
[the fence network](004-the-fence-network.md). You are never looking at a
half-finished city, only at a coarsely divided one.

That the two operations are exact inverses is worth noticing twice: it is what
makes the model easy to hold in the head, and it is what makes undo natural,
since the hard part of undo is usually inventing an inverse that does not exist.

## What the mode must refuse

**Crossing edges.** Faces are found by walking a planar graph, so two edges may
not cross except at a shared vertex. A crossing must be refused, or split by
placing a vertex at the intersection — but never quietly allowed, because the
face walk would then produce nonsense and the failure would appear far away from
its cause.

**Imprecise work.** The grab radius is fixed in screen pixels, so at the
whole-city view it covers forty painting pixels and will snap to the wrong thing.
Below some zoom the mode refuses to place or drag at all, naming the zoom you
need.

**Losing a name silently.** Severing merges two named places into one, and one
name must lose. The person is asked. Hand-written names are the expensive part of
this work and none may vanish without somebody saying so.

## What else it authors

Cutting is the loudest part, not the whole:

- **naming** a place, and naming a corner
- **placing a building's rough zone** — a crude shape over a roof, seconds each,
  not a traced footprint
- **assigning membership** — which district a place is in, which quadrant a
  district is in, which buys three levels of hierarchy for a decision apiece
- **listing** buildings and houses, with no geometry attached

All of it can happen long after a region is cut, and most of it will. The mode
should make returning to a place and adding one more thing easy, rather than
demanding a place be finished before you move on.

## A map is a bundle

The picture, the partition cut over it, and the names, **together as one thing**.

Self-contained, so installing a mod is a single act and a map cannot half-exist.
The cost is that every mod ships its own image, which for a 25-megapixel painting
is a large download — accepted, because the failure mode of the alternative is a
map arriving without its picture.

## Related documents

- [The fence network](004-the-fence-network.md) — the structure this writes
- [The map surface](002-the-map-surface.md) — the canvas it shares with play
- [Open questions](013-open-questions.md)
