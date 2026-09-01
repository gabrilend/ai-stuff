# 004 — The Fence Network

The datapath of the cage: what a place actually is on disk, and how a complete
partition of the city is guaranteed rather than achieved.

For what the places *mean*, see
[the places of the city](003-the-places-of-the-city.md); this page is only their
geometry.

## The city is subdivided, never assembled

**The map starts whole and gets cut up.** It does not start empty and get filled
in.

```
   start            one cut           two cuts
   ┌────────┐      ┌────────┐      ┌────────┐
   │        │      │   │    │      │   │    │
   │  one   │  ─▶  │ A │  B │  ─▶  │ A │ B  │
   │        │      │   │    │      │───┼────│
   │        │      │   │    │      │ C │ D  │
   └────────┘      └────────┘      └────────┘
```

**Coverage is always one hundred percent.** There is no untraced ground, no
undefined territory, no identity zero anywhere inside the painting. The work is
not *how much of the city exists yet* but *how finely it is divided and how well
it is named*.

That single change makes several faults unrepresentable rather than merely
checked for:

| Fault the old design could have | Why it cannot happen now |
| --- | --- |
| a loop that does not close | faces are closed by construction; there are no loops to draw |
| an edge belonging to no place | every edge separates exactly two faces |
| an edge named by three places | a planar edge has two sides |
| two blocks that look adjacent but are not | adjacency *is* sharing an edge, and edges are shared by construction |
| ground nobody has defined | the partition is always complete |

This is the same move as choosing a shared network over per-block outlines, taken
one step further: **pick the representation in which the invariant cannot be
violated**, rather than the one you check afterwards.

## What is stored, and what is derived

| | | |
| --- | --- | --- |
| **vertices** | `x`, `y` | position in painting pixels |
| **edges** | `path` | ordered vertex indices — one run of street |
| **places** | `seed`, `name`, `district`, `default_filter` | see below |
| **faces** | — | **derived**, never stored |

The graph of vertices and edges is the truth. The **faces** — the regions the
graph cuts the painting into — are computed from it.

### How faces are found

The standard walk over a planar graph. At each vertex, sort its incident edges by
angle. To trace a face, follow an edge, and at the far end take the next edge
clockwise from the one you arrived on, reversed. Repeat until you return to where
you began. Every such walk closes, and together the walks cover every edge twice
— once from each side, which is exactly the two faces that edge separates.

It requires the graph to be **planar**: no two edges may cross except at a shared
vertex. That is a real constraint on the editor rather than a detail — a crossing
must either be refused or split into a vertex at the intersection. See
[the tracing mode](005-the-tracing-mode.md).

### How a name stays attached to a derived face

Faces are recomputed whenever the graph changes, so their numbering is not
stable, and a name cannot live on a face.

It lives on a **place**, which holds a **seed** — a point inside the region it
names. After any recomputation, each face adopts the place whose seed falls
inside it.

That degrades exactly as it should:

- **Cut a region in two.** The seed lands in one half, which keeps the name. The
  other half is a new, unnamed place. Cutting Tanner's Row in two leaves one half
  still Tanner's Row and one half waiting to be named — which is right.
- **Sever a link.** Two faces merge and two seeds are now inside one face. One
  name has to win, and the person is asked rather than guessed at, because losing
  a hand-written name silently would be unforgivable.

A seed for a new face must be **a point guaranteed to be inside it**. A centroid
is not — a concave face's average position can easily fall outside it, which
would attach a name to the wrong region in a way nobody would notice.

## Two kinds of vertex, and the difference is derived

- A **junction** is a vertex where edges end — several meet there. Drag it and
  every fence into that corner follows, because they all name this same vertex.
- A **shape point** is a vertex only in the interior of exactly one edge. It is
  what makes a curved street curve. Drag it and one stretch bends.

Not stored as a flag. A flag can disagree with the structure and drift silently;
derived, the question *is this a corner?* is answered by looking.

## Intersections are content, not geometry

A junction is where edges happen to meet. An **intersection** is a junction
somebody has named, and it is a thing the game talks about: the tome lists a
block's intersections and everything each one connects to.

Which matters because of what nearness is:

> The connections are what's nearby.

Not distance — which street runs lead where, and what they reach. A corner is
therefore a place you can say something about, and a block's borders are a list
of named corners rather than an anonymous outline.

## Adjacency is a shared edge

**Two places are neighbours when a single edge separates them.** The only notion
of nearness the game has, and now true by construction rather than by careful
tracing.

No distances are computed, no radii drawn, nothing depends on the painting's
threefold scale swing. Influence travels one place at a time along the streets,
and a city wall stops it outright because the places either side of a rampart are
not separated by a street — they are separated by a wall, which is not an edge in
this graph.

Walking the graph gives distance a felt shape rather than a numeric one. One hop
is your daily life; several is an errand you would remember taking.

## The line runs down the middle of the street

A street has width, but the two places facing each other across one share a
**single** edge — so the line follows the road's centre and each place owns its
half.

The precision needed is low. The rule is *somewhere in the road*, not *exactly
the centre*: what matters is that every building sits clearly on one side. And
the cage is only ever looked at when places are 24 to 64 screen pixels across,
where a street is a few pixels wide and a wobble of two is invisible.

Two consequences:

**The cage reads like a road centreline**, which is a natural thing for a hairline
to be doing on a map of a city.

**There is no street object.** A lane is where two places meet, not a place.
Nobody stands *in* a street; they stand in a place, on its half of the road.
Public space is the open buildings and the squares, and a square is a place.

## Drawing the cage

**One pixel wide, in screen space** — converted by hand rather than drawn inside
the zoom transform, so the line is exactly one pixel at every zoom. That is what
makes it read as a cage *laid over* the painting rather than paint *on* it.

**One pixel means one colour.** A single pixel carries no gradient and no weight,
so every line is drawn identically. Which leaves only *whether* an edge is drawn:

> **Draw the boundaries of the level you can currently select. Only those.**

Quadrants at the city view, then districts, then blocks, then buildings. The cage
**swaps** as you descend rather than accumulating. See
[the map surface](002-the-map-surface.md).

This makes an existing promise exact — the cage *is* the set of things you can
click — and needs no cap on density, since a level only becomes selectable when
its places are a workable size on screen.

## Datapath summary

```
   the tracing mode                        the game
        │                                      │
        │ cuts and severs                      │ reads
        ▼                                      ▼
   ┌────────────────────────────────────────────────────┐
   │  vertices ──▶ edges                                │
   │       │          │                                 │
   │       │          ▼                                 │
   │       │      faces (DERIVED — planar face walk)    │
   │       │          │                                 │
   │       │          │ each adopts the place whose      │
   │       │          ▼ seed falls inside it             │
   │       │      places ──▶ district ──▶ quadrant      │
   │       │      (name, seed,  (membership only)        │
   │       │       buildings)                            │
   │       └──▶ intersections (named corners)            │
   └────────────────────────────────────────────────────┘
        │                  │                    │
        ▼ filled by id     ▼ shared edge =      ▼ stroked at the
   identity buffer     adjacency, by         selectable level
        │               construction
        ├──▶ pointer → place, then up the chain
        └──▶ filter shading
```

## Related documents

- [The places of the city](003-the-places-of-the-city.md) — what these regions mean
- [The map surface](002-the-map-surface.md) — the identity buffer and the levels
- [The tracing mode](005-the-tracing-mode.md) — how the cutting is done
- [Open questions](013-open-questions.md)
