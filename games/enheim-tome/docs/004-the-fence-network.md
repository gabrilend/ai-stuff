# 004 — The Fence Network

The datapath of the cage: what a place actually is on disk, why a block is not a
polygon, and how the one thing the game means by *nearness* falls out of it.

This is the structure the whole heroic effort of hand-tracing writes into. Get it
wrong and the tracing has to be done twice. For what the places *mean*, see
[the places of the city](003-the-places-of-the-city.md); this page is only their
geometry.

## Why a block is not a list of points

The obvious structure — each block holding its own closed list of points — fails
the moment you drag anything. A vertex on the fence between two blocks belongs to
both. Move it in one and the other stays where it was, and you get a hairline
gap where two blocks used to meet.

The gap is the visible half of the failure. The invisible half is worse: the two
blocks are no longer recorded as touching, so nothing propagates between them,
and the city quietly stops being connected in a way that looks fine on screen.

So the cage is a **network**, and blocks are faces of it.

## The tables

| Table | Field | Type | Meaning |
| --- | --- | --- | --- |
| **vertices** | `x`, `y` | numbers | position in painting pixels |
| **edges** | `path` | ordered list of integers | vertex indices, walked from one end to the other. One run of street. |
| **intersections** | `vertex` | integer | which vertex this corner is at |
| | `name` | string | what the corner is called |
| **blocks** | `name` | string | what the place is called |
| | `loop` | ordered list of pairs | an edge index and a direction flag each, walked in order to close the fence |
| | `district` | integer | which district it belongs to — the only thing districts and quadrants need |
| | `default_filter` | string, or nothing | the filter that switches on when this block is selected |
| **buildings** | `name` | string | what it is called |
| | `block` | integer | which block it stands in |
| | `zone` | a few points | a rough shape over the roof, enough to click. **Not a traced footprint.** |
| | `access` | one of a few values | almost always open; see [the places of the city](003-the-places-of-the-city.md) |

Houses live inside buildings and have **no geometry whatsoever** — no footprint,
no zone, no point. They are a list, reached through the tome. What they are is
described in [the places of the city](003-the-places-of-the-city.md).

Districts and quadrants have no geometry either. Their outlines are the outer
edges of their members, computed on demand. **Everything above the block is
free.**

## Two kinds of vertex, and the difference is derived

The distinction that makes dragging behave correctly is not recorded anywhere:

- A **junction** is a vertex appearing at the start or end of any edge. Several
  edges meet there. Drag it and every fence running into that corner follows, so
  a corner stays a corner.
- A **shape point** is a vertex appearing only in the interior of exactly one
  edge. It is what makes a curved street curve. Drag it and you bend that one
  stretch of fence and nothing else.

Grab the corner of a block and the neighbourhood re-corners with it. Grab the
middle of a lane and you nudge the lane. That is what a person expects from the
tool, and it costs no extra field — it is a consequence of the same vertex
appearing in more than one edge's path.

## Intersections are content, not geometry

A junction is where edges happen to meet. An **intersection** is a junction
somebody has named, and it is a thing the game talks about: the tome lists a
block's intersections and everything each one connects to. See
[the tome](007-the-tome.md).

This matters because of what the author said nearness is:

> The connections are what's nearby.

Not distance, not radius — which street runs lead where, and what they reach.
A corner is therefore a place you can say something about, and a block's borders
are a list of named corners rather than an anonymous outline.

## Adjacency is the whole point

**Two blocks are neighbours when their loops name the same edge.**

That is the only notion of nearness the game has, and it is exact. No distances
are computed, no radii drawn, nothing depends on the painting's wildly
non-uniform scale. Influence travels one block at a time along the streets, and a
city wall stops it outright because the blocks on either side of a rampart do not
share an edge.

Because adjacency is structural rather than measured, it is also **checkable**: a
tool can walk the network and report edges named by three blocks (impossible), by
one block (the city's outer boundary, or a mistake), or by none (stranded). That
check belongs beside the tracing tool and should run on every save.

Walking the graph also gives distance a felt shape rather than a numeric one. One
hop is your daily life. Several hops is an errand you would remember taking.

## Drawing the cage

**One pixel wide, in screen space.** The fence is not drawn inside the map's zoom
transform. Each vertex is converted from painting pixels to screen pixels by
hand, and the line is stroked at a literal width of one. Inside the transform the
line would scale with the zoom — invisible at the whole-city view and a fat worm
at native pixels. Outside it, the cage stays exactly one pixel at every zoom,
which is what makes it read as a cage laid over the painting rather than as paint
on it.

**One pixel means one colour.** A single pixel carries no gradient and no weight,
so every line in the cage is drawn identically — there is no opacity to vary and
no thickness by which to tell a quadrant boundary from an alley's.

### One level at a time

Which leaves only *whether* an edge is drawn, and the rule is:

> **Draw the boundaries of the level you can currently select. Only those.**

Quadrants at the city view, then districts, then blocks, then buildings — the
cage **swaps** as you descend rather than accumulating. See
[the map surface](002-the-map-surface.md).

This makes an existing promise exact: the cage *is* the set of things you can
click. And it needs no cap on density, because a level only becomes selectable
when its places are a workable size on screen.

### Why not a fade

An earlier design faded each boundary in on its own on-screen width. Since the
fence runs down the middle of a street, **nearly every edge is shared by exactly
two blocks** — only the city's outer boundary is single-sided — and each block
would have wanted its own opacity for one line stroked once.

A harbour block 300 screen pixels across beside an alley of 28: taking the larger
left small places with lopsided part-drawn outlines; taking the smaller put faint
patches into large ones that read as the drawing failing; stroking twice made
shared edges brighter than unshared ones. One colour removes the number they were
disagreeing about.

## Undefined ground

Most of the painting will be untraced for a long time, and some of it forever —
the mountains, the fields, the sea, the foreground ridge. In the identity buffer
it reads as zero.

What happens when you click there is undecided. See
[open questions](012-open-questions.md).

A tool should report **coverage** — how much of the painting is fenced, how many
blocks and buildings exist, how many are still unnamed — because the tracing is
the largest single piece of hand-work in the project and its progress needs a
number nobody has to count by hand.

## Datapath summary

```
   the tracing tool                        the game
        │                                      │
        │ writes                               │ reads
        ▼                                      ▼
   ┌────────────────────────────────────────────────────┐
   │  vertices ──▶ edges ──▶ blocks ──▶ buildings       │
   │      │          │          │                       │
   │      └──▶ intersections    └──▶ district ──▶ quadrant
   │           (named corners)       (membership only)  │
   └────────────────────────────────────────────────────┘
        │                  │                    │
        │ filled by id     │ same edge =        │ stroked, by level,
        ▼                  ▼ adjacency          ▼ faded on own size
   identity buffer    the neighbour          the cage
        │                graph
        ├──▶ pointer → place, then up the chain
        └──▶ filter shading
```

## Related documents

- [The places of the city](003-the-places-of-the-city.md) — what these shapes mean
- [The map surface](002-the-map-surface.md) — the identity buffer and the levels
- [The tracing tool](005-the-tracing-tool.md) — the program that writes all of this
- [Open questions](012-open-questions.md)
