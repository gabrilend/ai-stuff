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

## The pipeline, with no client anywhere in it

There is no retail data to extract from, so nothing is extracted. Our own
geometry is the authority and everything else is derived from it:

```
   input/world/*.shape        authored, in text, hand-editable
          │
          ▼   tools/fabricate
   .map (height)  ·  .vmap (collision)
          │                    │
          │                    ▼   the server's own tool, unmodified
          │              .mmap (navigation)
          │
          ├──────────────▶  the server:  height, sight, paths
          └──────────────▶  our client:  the geometry it draws
```

Two properties fall out, and the first is the good one.

**Both halves read the same files.** The collision file is a triangle soup with
a spatial index; our renderer wants triangles. So what you see is what you
collide with — not by careful synchronisation, but because there is one set of
data and no second copy to drift from. The class of bug where the wall on screen
is not the wall the server believes in cannot occur, because there is no second
wall.

**The navigation mesh is never written.** It is built by a tool that ships with
the server, from height and collision data. Producing those two correctly is the
entire job, and the hardest-sounding artifact costs nothing — which is most of
why keeping the game's own format was worth it.

### The order this arrives in

Collision does not come first. Flat ground does.

```
   flat ground, no collision, no paths     ← the server boots; a character walks
        │
        ▼   once there is geometry worth having
   collision from our shapes                ← line of sight, standing on things
        │
        ▼   built by the server's own tool
   navigation mesh                          ← free
```

The height format has a flag meaning *this tile is flat at one height*, under
which there is no grid at all — a few dozen bytes for a whole tile. And line of
sight, collision height, and pathfinding are each switchable off in the server's
own configuration, which is a supported setting rather than a hack. So the first
world that boots is a floor, and everything else is added when there is a reason
to.

`docs/datapath-the-fabricated-data.md` carries the generation mechanism.

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

The format is tiled — a large world is a grid of tiles, and only the ones nearby
are ever needed. That is inherited structure, and it happens to be exactly the
structure streaming wants, so tile-at-a-time loading is the natural shape rather
than an optimisation bolted on later. Our worlds start as one tile, which makes
the machinery unnecessary and present, which is the right order.

Flat shading takes its value from a face's normal, computed once at load. No
lighting at runtime, no textures, no normals in the file — the normal is derived
from the winding.

## The camera is a witch camera

Three rigs were offered to choose between — overhead, isometric,
over-the-shoulder. The answer was **"if it's my camera, it's a witch camera,
thank you very much,"** and the question fell over, because all three are
*mounts*: a camera bolted to an offset and dragged along behind a player.

A witch camera is not mounted. It flies.

```
        ✳                   the whisp goes where it goes
       ╱
      ╱      ◉  ~~~,        the camera follows, lagging, leaning,
     ╱                      drifting on its own while it does
```

So the camera stops being a value in a config file and becomes **another
floating thing in a world of floating things**. It has the same right to wander
that the arms of a star do:

- it **lags** — the whisp moves first and the camera catches up, so acceleration
  is visible rather than inferred
- it **leans** into turns, and overshoots slightly coming out of them
- it **drifts** when you hold still, on its own slow wander, so a stationary
  frame is never a dead one
- it **rises** when you move fast and settles when you slow, which is the whole
  of "this is urgent" said without any interface

Mechanically that is a position with its own velocity, pulled toward a target
offset by a spring rather than snapped to it, plus the same kind of gated wave
the whisps use. The three rigs survive as the extremes it can be tuned toward,
which is a more useful role for them than being voted on: overhead is the spring
stiff and the height high, over-the-shoulder is the offset short and the lag
long.

Every constant in that list is a dial, and dials live in
`docs/balance-updates.md`.

---

## The authoring format

`input/world/*.shape` is where worlds are written. Text, hand-editable, read out
of `input/` — because a program should learn how to start by reading `input/`,
and because a world you cannot edit in a text editor is a world you will not
experiment with.

The primitives are the ones the vision names, and no others:

```
    # a floor: a quad on the ground plane, one palette slot
    quad   0,0,0   16,0,0   16,16,0   0,16,0   c=2

    # a wall: a quad standing up
    quad   0,0,0   16,0,0   16,0,8    0,0,8   c=3

    # a ramp: a triangle, which is how height happens without curves
    tri    0,0,0   16,0,0   16,0,8            c=2

    # a block: shorthand that expands to six quads
    box    32,32,0  →  48,48,12               c=1
```

Coordinates are the server's own world coordinates, in its own units, so nothing
is transformed between what we draw and what it believes. `c=` is a palette
**slot**, never a literal colour, which is what makes one file render four ways.

**No curves. No textures. No normals.** A face's shade comes from its winding,
computed at load.

> This file's status flipped twice in one sitting — authoritative, then a test
> fixture when it looked like retail data would supply the worlds, then
> authoritative again once it was clear no retail data was coming. The note is
> here so the flip is visible rather than looking like it was obvious all along.

---

## Registering a map with the server

A row in the server's map table saying the map exists, its numeric id, its
directory name, and its type — plus moving the starting position onto it, since
the shipped SQL puts new characters somewhere that no longer exists.

The row itself is fabricated with the rest of the tables. The starting position
is a **non-textual patch**, and it follows the same contract as every other one:
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
    shape       the authoring format: text → polygons, one pass
    mapfile     the heightfield: tiles, grids, area identifiers
    vmapfile    the collision soup and its spatial index
tools/
    fabricate      shapes → the height and collision files the server reads
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
