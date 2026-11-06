# 1001 — Vertex grid representation

## Current behavior

The modeller needs a data structure for placed 3D vertices.
Nothing in the launch system holds 3D points; the compositor's
surfaces are 2D pixel grids. The vertex grid is the modeller's
own primitive.

## Intended behavior

A `vertex_grid_t` holds a set of placed vertices indexed by
their integer grid coordinates. The grid is the conceptual space
the user moves the cursor through — a finite cube of cells where
each cell can either contain a vertex or be empty.

The grid:

- Has fixed bounds in X, Y, Z (the launch size is 32 × 32 × 32
  cells, which is small enough to fit in RAM and large enough
  to model anything a user would author on a handheld).
- Maps each occupied cell to a `vertex_t` carrying the cell's
  identity and a list of faces this vertex belongs to.
- Supports placement, removal, query, and iteration.

The grid is allocated from the per-app region (902) so a buggy
modeller can't corrupt anything outside itself. Each vertex is
small (its identity plus a short face-list pointer); the
storage is a sparse hash map keyed by packed (x, y, z) coords.

The vertex grid is itself a soramech sub-map — `kind: "map"` —
because the modeller's outer map merges with other models by
encapsulation. This is the first application in the project to
use encaps in user-authored content.

## Suggested implementation steps

1. `struct vertex_t` — cell coords, face list head.
2. `struct vertex_grid_t` — sparse hash map plus iteration
   helpers.
3. `vertex_grid_alloc()` — from 108's per-app allocator.
4. `vertex_grid_place(grid, x, y, z)`.
5. `vertex_grid_remove(grid, x, y, z)`.
6. `vertex_grid_at(grid, x, y, z) → vertex *`.

## What happened

Built on the twin, with the **STAND-IN for 902**: 902 (a region of
memory per app) is not built, so the grid takes its memory through
`src/engine/127-app-memory.h`, two calls that name the app the memory
is for. Today they hand out the engine's shared blocks (029) and keep a
budget per app (4 MB unless set), refusing whatever would pass it. They
do not protect one app's memory from another. When 902 lands, those two
calls become `page_alloc_for_app` and its partner, and nothing that
calls them changes.

The grid:

- `src/system/128-vertex-grid.c` and `.h`. A dense array of vertices
  and a hash table over it, keyed by the cell packed into 15 bits.
  Open addressing, at most half full; removal shifts the run back
  rather than leaving tombstones, and the last vertex fills the gap.
  Both start at 16 vertices and double up to the whole cube (512 KB in
  all). A grid that cannot grow refuses the placement and is unchanged.
- A vertex is its cell, `first_face` (-1) and `face_count` (0): the
  places 1003 will fill.
- Every call is safe from any core: a lock per grid, and answers are
  copies, never pointers, because another core may grow or reorder the
  grid as soon as the lock is let go. (The issue asked for
  `vertex_grid_at → vertex *`; a copy is the safe form of it.)
- Grids are named by number, 16 at most, each naming its app.

The sub-map:

- `src/boxes/129-vertex-grid.c`: `place_vertex`, `remove_vertex` and
  `vertex_in`, each taking a `struct cell` (grid, x, y, z) and answering
  a `struct cell_answer` (the cell, the answer, the face count).
- `src/maps/vertex-grid.map`: the three as one program with three doors
  in and three out, which a modeller's map places as one station.

Placing it as one station found a bug in the loader (068): a door
marked on a placed program's own station line was recorded against a
station that was never set, so the outer program's argument went to the
wrong place and its result never came. The loader now follows such a
door down to the inner port or exit, as it already did for wires.

`twin/tests/130-test-vertex-grid.c` (48 checks):

- The stand-in's budget: kept, refused past it, given back.
- One vertex placed, found, placed again, removed; every cell outside
  the cube refused on every axis.
- The whole cube in, found, walked, and half of it out.
- 400 000 random placements and removals against a plain array of
  flags.
- A grid out of memory refuses and is unchanged, then goes on once its
  budget is raised; a freed grid gives every byte back; 16 at most.
- Four threads filling one grid at once.
- The boxes' sizes; the map through its doors, alone and placed inside
  another map.

## Related documents

- `docs/010-modeller.md`.

## Blocked by

108, 305, 902.

## Blocks

1002, every later phase 10 issue.
