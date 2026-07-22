# 103 — Square-Room World Data Model

> **Phase:** 1 (Engine Foundation) · **Depends on:** `101` (language/framework
> choice only; this is mostly pure data) · **Blocks:** `104` (renderer walks it),
> `105`/`106` (collision tests against it), and the Phase 4 & Phase 6 seams ·
> **Difficulty:** medium · **Kind:** foundational data structure · **Status:**
> COMPLETE.

The map. This issue defines *what a world is* — a lattice of square rooms, each
with something special about it, connected by doors — held as **two views of one
thing** so the renderer and collision get their grid while gameplay gets its
room-level handles.

## Current Behavior

Built and tested (`src/001-world.{c,h}`). A **World** holds both lenses over one
map: a tile grid (`cell_t`: solid, wall id, floor/ceiling height, room id) the
renderer and collision walk, and a room table + door graph gameplay reasons
about. The room-behaviour dispatch table (enter/step/exit) is registered with the
trivial `plain`/`spawn` entries — the seam Phase 4/6 fill in. A world builder
hand-lays a two-room test map with a dividing wall, one passable door, and a
step-up between the rooms; a validator checks coherence and reports counts
(`src/001-world-test.c` passes — grid 20×12, 69 walls / 171 floor, 2 rooms, 1
door). The engine renders it **top-down** (a debug view, not the first-person
renderer `104`), with the mover "player" wandering the rooms and bouncing off
walls (the first taste of `105`'s per-axis collision). Capture the view headless
with `FPS_SHOT=<abs.png> FPS_FRAMES=60 ./run`.

## Intended Behavior

A **World** built as two lenses over the same map:

- **Tile-grid view** — a 2-D array of cells the raycaster marches and collision
  tests against. Each cell carries: solid-or-empty, a wall surface id, a **floor
  height**, a **ceiling height**, and the **room id** it belongs to. Floor and
  ceiling heights per cell are what make platforming possible (issue `106`) and
  what let the renderer draw ledges and drops (issue `104`).
- **Room-table view** — keyed by room id, each entry holds the room's footprint
  in the grid, its floor/ceiling heights, its **special-property tag**, and its
  **door list**. This is the handle Phase 4 puzzles attach to and Phase 6's
  Dungeon Master populates. The rooms are the nodes; the doors are the edges of a
  graph laid over the grid.
- **Special property as a dispatch entry.** A room's special-property tag is an
  index into a **room-behaviour dispatch table** (dispatch over if-else, per
  house style), with enter/step/exit callbacks the engine fires. Phase 1 ships
  only trivial entries — `plain` and `spawn` — but the table and its callback
  contract are the real deliverable, because Phase 4 (puzzles/mechanisms/traps)
  and Phase 6 (combat/treasure rooms) register their behaviours against it
  without the engine ever learning what a puzzle or a combat is.
- **Doors / connections** — each door names the two rooms it links, where the
  opening sits on the shared grid edge, and whether it is currently passable
  (so a puzzle can lock/unlock it later).
- **Authored now, emittable later.** Phase 1 builds a small hand-authored test
  world in code (a few square rooms, a couple doors, at least one height change
  to jump onto). The structure is deliberately plain data so the Phase 6 Dungeon
  Master can *emit the same structure* and the engine loads it unchanged.
- **Coordinate & unit conventions** live as comments right on the structure:
  which axis is which, that positions are in tile units, that height is a separate
  vertical axis, and that a solid cell blocks both movement and sight. These
  conventions will be needed again by the renderer and collision, so they are
  written down where they can't drift.

## Suggested Implementation Steps

1. Define the **cell** record (solid flag, wall surface id, floor height, ceiling
   height, room id) and the **tile grid** container, with the coordinate/units
   conventions as comments on the definition.
2. Define the **Room** record (id, footprint, floor/ceiling heights,
   special-property tag, door list) and the **room table**.
3. Define the **Door** record and the room graph it forms.
4. Build the **room-behaviour dispatch table** with the enter/step/exit callback
   contract; register the trivial `plain` and `spawn` behaviours; document the
   contract in the file's `.info.md` so later phases know exactly what to
   implement against.
5. Write a **world builder** that assembles a small hand-authored test world
   (multiple square rooms, doors, a height change), returning both views wired to
   the same underlying cells.
6. Write a tiny **validator** that checks a World for coherence (every cell's room
   id exists, every door links two real rooms, spawn room present, no room
   claiming overlapping cells) and reports counts on demand — so docs can
   reference the validator instead of hardcoding map sizes. Keep it runnable
   standalone; tests are cheap, make several.

## Related Documents / Tools

- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  World / Room / Door structures and the room-special-property seam.
- [notes/vision](../notes/vision) lines ~116–122 — "square rooms that each have
  something special about them."
- Consumers: issue `104` (renders it), `105`/`106` (collide against it), and the
  Phase 4 / Phase 6 seams populate the room table and dispatch entries.
