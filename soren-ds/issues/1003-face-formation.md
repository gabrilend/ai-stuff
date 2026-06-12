# 1003 — Face formation

## Current behavior

Vertices can be placed (1002) but they don't yet connect into
faces. Without faces a model is just a point cloud — useful for
nothing.

## Intended behavior

A `face_t` is three or four connected vertices. The launch
modeller supports triangles and quads (with quads stored as
their own type rather than as two triangles, because the user
authors them as quads).

Formation flow:

1. The user moves the cursor to a placed vertex and presses
   `X` — the "begin face" face button. The vertex enters
   pending-face state. A small highlight appears.
2. The user moves the cursor to a second placed vertex and
   presses `X` again. The second vertex joins the pending face.
3. The user does the same for the third vertex (a triangle is
   now ready) and optionally a fourth (a quad is ready).
4. Pressing `Y` — the "commit face" face button — closes the
   face. The face joins the model's face list; each of its
   vertices remembers the face on its face-list.
5. Pressing `B` cancels the pending face.

The face's normal is computed from the vertex order using the
right-hand rule. The user can flip the normal later (via the
inspector in 1009) if the default came out reversed.

Edges of the face — implicit line segments between consecutive
vertices in the face's vertex list, plus a closing segment from
the last back to the first — render as lines in the perspective
view (1009). Faces themselves render as colored polygons once
1004 ships.

## Suggested implementation steps

1. `struct face_t` — vertex list (3 or 4), normal, color slot,
   roughness slot.
2. `face_begin(vertex)`.
3. `face_add_vertex(vertex)`.
4. `face_commit()` / `face_cancel()`.
5. The pending-face state in the modeller's `cursor_t`.

## Related documents

- `docs/010-modeller.md`.

## Blocked by

1002.

## Blocks

1004, 1005, 1007, 1009.
