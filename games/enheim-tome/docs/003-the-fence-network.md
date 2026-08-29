# 003 — The Fence Network

The datapath of the cage: what a block actually is on disk, why it is not a
polygon, and how the one thing the game means by *nearness* falls out of it.

This is the structure the whole heroic effort of hand-tracing writes into. Get it
wrong and the tracing has to be done twice.

## Why it is not a list of polygons

The obvious structure — each block holding its own closed list of points — fails
the moment you drag anything. A vertex on the fence between two blocks belongs to
both. Move it in one and the other stays where it was, and you get a hairline
gap where two blocks used to meet.

The gap is the visible half of the failure. The invisible half is worse: the two
blocks are no longer recorded as touching, so nothing propagates between them,
and the city quietly stops being connected in a way that looks fine on screen.

So the cage is a **network**, and blocks are faces of it.

## The three tables

| Table | Field | Type | Meaning |
| --- | --- | --- | --- |
| **vertices** | `x` | number | horizontal position in painting pixels |
| | `y` | number | vertical position in painting pixels |
| **edges** | `path` | ordered list of integers | indices into the vertex table, walked from one end to the other |
| **blocks** | `name` | string | what this place is called; the only way to reach it by name |
| | `loop` | ordered list of pairs | each pair is an edge index and a direction flag, walked in order to close the fence |
| | `default_filter` | string, or nothing | the filter that switches on when this block is selected |
| | `buildings` | list of records | see below |

A building is a record with no position at all:

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | the tanner's, the third house on the lane |
| `purpose` | string | what is done there, or who lives there |

Buildings are never clickable on the map and never drawn. The painting's houses
were not drawn to be individually meaningful, and in the packed quarters
south-west of the bridge one roof genuinely does not visibly end where the next
begins. Pretending otherwise would mean inventing hundreds of footprints that
correspond to nothing. See
[what this game is](001-what-this-game-is.md) on blocks being the unit of play.

## Two kinds of vertex, and neither is stored as such

The distinction that makes dragging behave correctly is **derived, not recorded**:

- A **junction** is a vertex appearing at the start or end of any edge. Several
  edges meet there. Drag it and every fence running into that corner follows, so
  an intersection stays an intersection.
- A **shape point** is a vertex appearing only in the interior of exactly one
  edge. It is what makes a curved street curve. Drag it and you bend that one
  stretch of fence and nothing else.

Grab the corner of a block and the neighbourhood re-corners with it. Grab the
middle of a lane and you nudge the lane. That is what a person expects from the
tool, and it costs no extra field — it is a consequence of the same vertex
appearing in more than one edge's path.

## Adjacency is the whole point

**Two blocks are neighbours when their loops name the same edge.**

That is the only notion of nearness the game has, and it is exact. No distances
are computed, no radii are drawn, nothing depends on the painting's wildly
non-uniform scale. Influence travels one block at a time along the streets, and a
city wall stops it outright because the blocks on either side of a rampart do not
share an edge.

Because adjacency is structural rather than measured, it is also **checkable**: a
tool can walk the network and report edges named by three blocks (impossible), by
one block (the city's outer boundary, or a mistake), or by none (a stranded
edge). That check belongs beside the tracing tool and should run every time the
network is saved.

## Drawing the cage

**One pixel wide, in screen space.** The fence is not drawn inside the map's zoom
transform. Each vertex is converted from painting pixels to screen pixels by
hand, and the line is stroked at a literal width of one. Inside the transform the
line would scale with the zoom — invisible at the whole-city view and a fat worm
at native pixels. Outside it, the cage stays exactly one pixel at every zoom,
which is what makes it read as a cage laid over the painting rather than as paint
on it.

### Each block fades on its own size

A single global zoom threshold cannot work here, because at native zoom a harbour
block is around 300 screen pixels across while a block up by the north wall is
around 40. So each block's fence gets its own opacity from its own on-screen
width:

| On-screen width | Fence |
| --- | --- |
| under about 24 pixels | not drawn at all — too small to aim at anyway |
| about 24 to 64 | opacity ramps from nothing to solid |
| over about 64 | a solid one-pixel line |

with one override: **the block under the pointer and the selected block always
draw at full strength**, whatever their size. So the painting is clean at the
city view, the cage thickens up naturally as you descend into it, and whatever
you are actually pointing at is always outlined.

The two thresholds are tunables, not constants. Which measure of "width" — the
bounding box, or the square root of the on-screen area — is not settled; the
bounding box is the working ruling because it is cheaper and the difference only
shows on very elongated blocks.

## Unfenced ground

Most of the painting will be untraced for a long time, and some of it forever —
the mountains, the fields, the sea, the foreground ridge. In the identity buffer
described in [the map surface](002-the-map-surface.md), untraced ground reads as
identity zero.

What happens when you click there is undecided. See
[open questions](010-open-questions.md).

A tool should report **coverage** — how much of the painting is fenced, how many
blocks exist, how many are still unnamed — because the tracing is the largest
single piece of hand-work in the project and its progress needs a number that
nobody has to count by hand.

## Datapath summary

```
   the tracing tool                      the game
        │                                    │
        │ writes                             │ reads
        ▼                                    ▼
   ┌──────────────────────────────────────────────┐
   │  vertices  ──referenced by──▶  edges         │
   │                                 │            │
   │                                 │ named by   │
   │                                 ▼            │
   │                              blocks          │
   │                            (loop, name,      │
   │                             default filter,  │
   │                             buildings)       │
   └──────────────────────────────────────────────┘
        │                    │                  │
        │ filled by id       │ same edge =      │ stroked
        ▼                    ▼ adjacency        ▼
   identity buffer      the neighbour       the cage
        │                  graph
        ├──▶ pointer → block
        └──▶ filter shading
```

## Related documents

- [The map surface](002-the-map-surface.md) — the identity buffer and how it is used
- [The tracing tool](004-the-tracing-tool.md) — the program that writes all of this
- [Filters and the weave](005-filters-and-the-weave.md) — what reads blocks
- [Open questions](010-open-questions.md)
