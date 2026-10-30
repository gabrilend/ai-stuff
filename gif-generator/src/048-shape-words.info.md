# 048-shape-words — the 3D scene's closed vocabulary

Every word a shape scene may use, where it may use it, and what it means
(issue 701c). Each place (the scene, a shape, a spin, a camera that
orbits, a torus's proportions) is a list of `{ word, kind of value,
meaning }`. The wall (`049-shape-wall.lua`) refuses any word not listed
for where it stands, and the documentation (`docs/shape-format.md`, from
`051-shape-docs.lua`) is printed from these lists, so the two cannot
drift.

## Usable surface

- **CONTEXTS** — place name → list of `{ word, kind, meaning, rules }`;
  rules (optional) are space-separated: `!` needed, `cycles` whole with
  no seam, `whole>=N`, `0..1`, `len=N`, `rising`, ... **ORDER** is the order the
  documentation lists them in.
- **MOTIONS**, **MOTION_COMMON**, **CAMERA_MOTIONS** — the words of each
  kind of motion, and the ones every shape motion takes.
- **MESH_PARAMS** — each cabinet shape's proportions; a scene's `ground`
  takes the terrain's.
- **TIES** — the rules between words, in words, for the documentation
  (the wall keeps them as code).
- **WORLD_SPACE** — world space, stated once.
- **STYLES**, **SHARDS**, **MADE_TAGS** — the short word lists the wall
  owns, and the tags the scene makes without anyone writing them.
- **legal(list) → lookup, sorted**, **motion_words(kind)**,
  **camera_motion_words(kind)** — the lists in the forms the wall reads.

The names the runtime owns (hues, shapes, motion kinds, effects, solids)
are not kept here; the wall takes them from the modules that use them,
and refuses loudly if the motion kinds or shapes listed here and in the
code ever differ.

To add a word: add it here with its meaning, teach the code to read it,
then run `luajit src/051-shape-docs.lua DIR`.
