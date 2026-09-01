# 801 — A Map Is Plates And Stairs

| | |
| --- | --- |
| Phase | 8 — The Mountain |
| Blocked by | — |
| Blocks | 802, 803, 804, 805 |
| Reads | [the isometric projection](../../docs/006-the-isometric-projection.md), `inspiration/NOTICE.md` |
| Open questions | two, at the bottom |

## Current behavior

The world is a grid of 32-bit columns, one bit per layer, produced by a
six-pass generator, and it is the wrong world. Looking at the reference picture
closely enough to count courses of masonry shows what it actually contains:

- **No walls.** Not one. Every vertical surface in that picture is the *side of a
  higher flat plate*. What reads as a wall between two corridors is the edge of a
  block whose top is itself a walkable surface.
- **Flat plates at many elevations**, from single-cell steps up to plazas a dozen
  cells across.
- **Staircases as the only connective tissue**, and there are hundreds of them.
  A flight is six to twelve treads and it runs along a plate edge rather than
  cutting through anything.
- **One high corner and one low corner.** The maze is laid over the face of a
  mountain. Elevation falls from the far corner toward the near one, which is
  why the picture can be read at all: the ground tilts toward the viewer.

The current generator produces a *nested pyramid with two-layer walls on a room
lattice*. Every one of those three choices is wrong. The pyramid hides its own far
side behind its summit; the walls hide the corridor behind every room, which
[109](../109-nothing-hides-behind-anything.md) measured at 71% of the floor; and the
room lattice has no counterpart in the picture at all.

## Intended behavior

A map is **data**, hand-authored and checked in, and it is a list of two kinds of
thing. Nothing generates it and nothing is random.

**A plate** is an axis-aligned rectangle of flat ground at one elevation.

| Field | Type | Meaning |
| --- | --- | --- |
| `x`, `y` | integers | the near-origin corner, in cells |
| `w`, `d` | integers, at least 1 | width along x, depth along y |
| `z` | integer | the elevation of its top surface, in layers |

**A staircase** is a run of treads carrying one elevation to another.

| Field | Type | Meaning |
| --- | --- | --- |
| `x`, `y` | integers | the tread the flight starts at, the high end |
| `dir` | `"+x"`, `"-x"`, `"+y"`, `"-y"` | which way it descends |
| `w` | integer | how wide the flight is, across its direction |
| `from`, `to` | integers | elevation at the top and at the bottom |

The number of treads is `from - to`, one layer per tread, because that is what
makes a staircase a ramp a ball can accelerate down rather than a set of ledges
it bounces off. Tread `n` sits at elevation `from - n`.

Two plates may overlap. Where they do, **the higher one wins** — that is what
makes the format authorable, because a plaza can be laid down as one rectangle
and then have a notch cut into it by a second rectangle laid on top rather than
by splitting the first into four. Order in the list is irrelevant; only elevation
decides.

Everything below the top surface is solid. There are no holes, no overhangs, no
bridges. The world is a height field, and the format's whole job is to be a
*legible* way of writing one down by hand.

## Suggested implementation steps

1. Write the format's reader first, and make it refuse rather than repair. A
   plate off the edge of the world, a staircase whose `from` is below its `to`, a
   flight that lands somewhere no plate reaches — each is a typo in a
   hand-authored file, and a typo that loads silently is a map nobody can debug.
2. Flatten to a height field once, at load. Everything downstream — the model,
   the physics, the renderer — reads one integer per cell and never looks at the
   plate list again. The list is how a person writes it; the field is how the
   program uses it.
3. Report what was loaded the way the maze validator reports: elevation range,
   how many cells each plate actually won, how many were never covered by
   anything. A plate that lost every one of its cells to a later, higher plate is
   almost always an authoring mistake, and it is invisible without the count.
4. Keep the picture's measurements in `inspiration/NOTICE.md` up to date as they
   are read off it, since the authored map is the first thing that has ever had
   to agree with them.

## Related documents and tools

- [802](802-the-mountainside-is-hard-coded.md) — the first map written in this format
- [803](803-the-height-field-becomes-a-model.md) — what consumes it
- `src/067-sightlines.info.md` — how to measure whether a map can be seen

## Open questions

**One. Does a plate carry anything besides elevation?** The picture has paved
plazas, mossy shelves and bare rock, and the renderer already has three tones. A
material field would cost nothing now and cannot be added later without touching
every authored map. Not answered.

**Two. What is the unit of elevation?** The current world says a layer is a
32-bit position and caps at 32 of them. A hand-authored mountain wants more
range and does not need the bitmask at all, since it has no holes. Dropping to a
plain integer height per cell removes the cap and deletes the column array.
Whether anything still needs the bitmask is not answered.
