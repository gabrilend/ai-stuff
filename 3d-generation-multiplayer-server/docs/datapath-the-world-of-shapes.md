# datapath — the world of shapes

*the game's own map data → what the server believes → the triangles we draw*

The rigid half of the contrast. Squares and triangles, flat-shaded, in one of
four schemes.

---

## The decision that makes this easy

> *"Just use the same map file format that 3.3.5a uses and we're good to build
> whatever we want on it later."*

We do not invent a map format. The existing one already has, downstream of it, a
working extraction pipeline and a working navigation-mesh builder — and building
on a format that already has tools is what leaves us free to build whatever we
want later, rather than owing a format its whole toolchain first.

What the server needs before it will let a character stand anywhere:

| Artifact | Answers | Consumed by |
|---|---|---|
| **`.map`** | "what is the ground level at this x, y?" | movement validation, falling |
| **`.vmap`** | "is there something between these two points?" | line of sight, standing |
| **`.mmap`** | "how does something walk from here to there?" | pathfinding |
| a map table row | "does this map exist, and what is it called?" | practically everything |

All three files are produced by tools that ship with the server, from the
client's own archives, and the navigation mesh is built from the first two. We
change none of it.

---

## The part that falls out for free

The collision file is **a triangle soup with a spatial index over it.** Our
renderer wants triangles. So:

```
   3.3.5a map data  (the client's own archives)
          │
          ▼   the stock extraction tools, unpatched
   .map  ·  .vmap  ·  .mmap
          │
          ├──────────────▶  the server:  height, sight, paths
          │
          └──────────────▶  our client:  the geometry it draws
```

**Both halves read the same files.** What you see is what you collide with — not
by careful synchronisation, but because there is only one set of data and no
second copy to drift from. The class of bug where the wall on screen is not the
wall the server believes in cannot occur, because there is no second wall.

The heightfield gives the ground; the collision soup gives everything standing
on it. Flat-shade both, index the colours into a scheme, and a real map comes
out the other side as pure abstract geometry — which is, almost exactly, the
thing the vision describes.

### Which means the first world is free

Point the extractors at a copy of the retail client's data, and phase 4 has
somewhere to stand on its first day: real maps, real collision, real
pathfinding, rendered as untextured flat polygons in four colour schemes. No
authoring, no custom-map pipeline, no generator.

That is a very large early payoff for one decision, and it reorders the work —
seeing a world comes *before* making one, instead of after.

Custom maps, when they come, emit these same formats. Whether by writing the
client-side format and running the stock extractors over it, or by emitting the
extracted files directly, is a later question that this decision does not block.
That is the point of the decision.

---

## The four schemes

| Scheme | Background | Colours | Reads as |
|---|---|---|---|
| white | bright | bright | diagram, blueprint, daylight |
| black | bright | bright | neon, void, night |
| blue | muted | muted | dusk, underwater, distance |
| green | muted | muted | overgrowth, moss, quiet |

A scheme is a background colour plus a small indexed palette. Geometry
references palette **slots**, never literal colours, which is what makes one set
of map files render four ways. Switching schemes switches one table: no reload,
no geometry touched. It should be a keypress and it should be instant, because
the fastest way to find out whether a scheme works is to flip between them while
standing in the world.

The slot a piece of geometry gets is derived from what the map data already
knows about it — ground versus structure, and the area identifier that comes
along with the heightfield. That is a rule to be tuned by looking, and its
current form belongs in `docs/balance-updates.md` rather than frozen here.

Every scheme carries one entry that is not for terrain: the **whisp contrast
colour**, the halo drawn behind a pink star squiggle so it stays legible against
that scheme's background. Dark on the bright schemes, light on the muted ones.
It lives in the scheme table because it is a property of the world being looked
at, not of the creature being looked for.

**Nothing in any scheme is pink.** Pink is reserved for the living. That is a
rule with a reason, and it is checkable by a small tool rather than by memory.

---

## What the client does with it

```
   .map + .vmap for the tiles we are near
        │
        ▼   parse once per tile, no allocation per triangle
   a vertex buffer per tile, uploaded once
        │
        ▼   per frame
   camera → view/projection → draw the visible tiles
        │
        ▼
   whisps on top, billboarded, two passes each
```

Real maps are tiled — a large world is a grid of them, and only the ones nearby
are ever needed. That is inherited structure, and it is exactly the structure
streaming wants, so tile-at-a-time loading is the natural shape rather than an
optimisation bolted on later.

Flat shading takes its value from a face's normal, computed once at load. No
lighting at runtime, no textures, no normals in the file — the normal is derived
from the winding.

The camera is the other half of the feel and is deliberately unsettled.
Overhead, isometric, and behind-the-shoulder produce three different games from
identical geometry, and the vision does not say which. The honest way to answer
it is to implement the cheap version of each and look.

---

## The scratch format, and what it is *not*

`input/world/*.shape` is a small text format — quads, triangles, boxes — that
exists to give the renderer something to draw before the extraction pipeline is
standing, and to make a deliberately awkward test case when one is wanted.

**It is not the world format and it is not authoritative.** Nothing derives
server data from it. If it ever starts to look like the place worlds are
authored, that is a decision to make on purpose and write down, not a drift to
allow.

---

## Registering a map with the server

A row in the server's map table saying the map exists, its numeric id, its
directory name, and its type. Needed only once custom maps arrive; the retail
maps are already registered.

This is a **non-textual patch** and follows the same contract as every other one:
apply is an idempotent insert keyed on the map id, unapply is the matching
delete, and the guard is a row-presence check. Same four properties as a text
patch, different substrate.

The server has its own mechanism for third-party additions to apply data
changes, and a registration through a mechanism upstream *intends* cannot
conflict with upstream at all. Where that seam reaches, it is preferred, for the
same reason a module beats a source edit.

---

## Where this lands in the code

```
src/world/
    mapfile     the heightfield: tiles, grids, area identifiers
    vmapfile    the collision soup and its spatial index
    shape       the scratch text format — fixtures only
tools/
    scheme-check   asserts no scheme contains pink, and that every palette
                   slot clears the contrast threshold against its background
src/draw/
    terrain     a vertex buffer per tile, uploaded once
    palette     the four schemes, shared with the whisp
```

## Related

- `docs/datapath-the-whisp.md` — the soft half of the contrast
- `docs/datapath-the-patch-machine.md` — non-textual patches, and the module seam
- `docs/architecture.md` — the shape all of this serves
- `docs/balance-updates.md` — palette values and camera constants, as they move
