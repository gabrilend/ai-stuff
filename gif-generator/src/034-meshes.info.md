# 034-meshes — the shape cabinet

The solid shapes a shape-film scene can place: each word builds a mesh of
triangles, wound outward and checked as it is built. Knows triangles only.

## Usable surface

- **build(name, params) → mesh** — `{ verts, faces, superball }`.
- **radius_toward(mesh, v) → r** — how far the surface reaches along `v`.
- **terrain_height(params, x, z) → y** — the ground's height at a point.
- **reshape(vertex, p) → x, y, z** — a vertex bent by a shape's reshaping.

The words, their parameters and the checks are written out in full in
`039-shape-films.info.md`, under "The parts".
