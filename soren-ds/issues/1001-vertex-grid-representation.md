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

## Related documents

- `docs/010-modeller.md`.

## Blocked by

108, 305, 902.

## Blocks

1002, every later phase 10 issue.
