# Issue 116: Read WC3 Models (.mdx)

**Phase:** 1 - File Format Parsing
**Type:** Implementation
**Priority:** High
**Dependencies:** None open
**Builds on (completed):** the binary readers in `src/compat.lua`, the MPQ reader (114)
**Blocks:** 516 (drawing models in the engine), 603 (the fetcher's model check)
**Related:** 117 (the textures a model names)

---

## Current Behavior

No reader exists for WC3 models. `src/parsers/` reads every data file inside
a map (terrain, doodads, units, regions, cameras, sounds, triggers, object
data), but not the models those files name. The renderer draws every unit as
a placeholder shape (circle, cube, triangle, cylinder). The fetcher (603) can
check a downloaded model only by its first four bytes.

## Intended Behavior

The owner (2026-09-26): "we need a reader for .mdx files, and a little
renderer in-engine. We're gonna need to render the models eventually, so we
might as well build the renderer with them in mind. Why use capsules when you
could use footmen and grunts?"

A parser, `src/parsers/mdx.lua`, that turns a binary WC3 model into a Lua
table the renderer (516) can draw from, and that the fetcher (603) and the
catalogue (1001) can read facts from.

**The format.** A binary `.mdx` file starts with the four bytes `MDLX`, then
a series of chunks. Each chunk is a four-byte tag, a 32-bit little-endian
byte length, and that many bytes. The chunks that matter first:

| Tag | Holds |
|-----|-------|
| `VERS` | format version (800 for classic models) |
| `MODL` | model name, bounding box, blend time |
| `SEQS` | animations: name, start and end frame, move speed, bounds |
| `GLBS` | global sequence lengths (animations that loop independently) |
| `TEXS` | textures: a path, or a *replaceable id* (1 = team colour, 2 = team glow, and others) |
| `MTLS` | materials: layers, each with a texture, a blend mode and flags |
| `GEOS` | geosets (meshes): vertices, normals, texture coordinates, triangles, vertex groups, the material they use |
| `BONE`, `HELP` | the skeleton: bones and helper nodes, with their animated translation, rotation and scale |
| `PIVT` | pivot points, one per node |

Later chunks (attachments, particle emitters, ribbons, lights, event
objects, collision shapes, cameras) are read into the table by tag and
length so nothing is lost, and decoded one at a time as the renderer needs
them. An unknown chunk is kept as raw bytes with its tag and reported, not
skipped silently.

**The result** (a Lua table):
- `version` (integer), `name` (string), `bounds` (min and max corners as
  three numbers each, and a radius)
- `sequences`: list of `{ name (string), first_frame, last_frame
  (integers), move_speed (number), looping (boolean) }`
- `textures`: list of `{ path (string, empty when replaceable),
  replaceable_id (integer, 0 when a path is given) }`
- `materials`: list of `{ layers = list of { texture_index (integer),
  blend_mode (integer), flags (integer), alpha (number) } }`
- `geosets`: list of `{ vertices, normals (flat lists of numbers, three per
  vertex), uvs (flat list, two per vertex), triangles (flat list of vertex
  indices, three per triangle), vertex_groups (one integer per vertex),
  groups (list of lists of bone indices), material_index (integer) }`
- `nodes`: list of `{ name (string), id, parent_id (integers), kind
  ("bone" or "helper"), pivot (three numbers), translation, rotation,
  scale (animation tracks, see below) }`
- `unread`: list of `{ tag (string), bytes (string) }` for chunks not yet
  decoded

An animation track is `{ interpolation (integer: none, linear, hermite,
bezier), global_sequence_id (integer, -1 when none), keys = list of { frame
(integer), value (numbers), in_tan, out_tan (numbers, for hermite and
bezier only) } }`.

**Which versions.** Classic models, version 800, first. Reforged's HD
versions (900 and later) are listed in `docs/versions-we-leave-alone.md` and
are refused with an error that names the version, not guessed at. The text
form of the format (`.mdl`) is not read by this issue.

**Where test models come from.** Models posted by the community, fetched
through 603, are the default test material. The stock models inside the
player's own WC3 install are read only as compatibility checks, to prove the
reader handles Blizzard's own files (see the owner's rule in 516). Neither
kind is committed to the repository.

## Suggested Implementation Steps

1. Chunk walker: magic check, then tag, length and body for each chunk;
   unknown tags into `unread`.
2. `VERS`, `MODL`, `SEQS`, `GLBS`, `TEXS`, `MTLS`.
3. `GEOS`, the largest and the one the renderer needs first.
4. `BONE`, `HELP`, `PIVT` and the animation-track reader they share.
5. A summary function for the fetcher and the catalogue: triangle count,
   vertex count, sequence names, texture paths, replaceable ids used.
6. `src/parsers/mdx.info.md` describing the reader's inputs and outputs.
7. Tests, in `src/tests/test_mdx.lua`: a small model built by the test
   itself (bytes written in the test, so no downloaded file is needed) reads
   back to the expected table; a truncated file fails with an error naming
   the chunk and the offset; a version-900 file is refused; and, when the
   player's install is present, every stock unit model reads without error
   (skipped, and reported as skipped, when it isn't).

## Acceptance Criteria

- [ ] A version-800 model reads into the table above
- [ ] Geosets, materials, textures and sequences are decoded
- [ ] Bones, helpers, pivots and their animation tracks are decoded
- [ ] Unknown chunks are kept and reported, never silently dropped
- [ ] Truncated and HD files fail with errors that name what and where
- [ ] Tests pass without any downloaded or proprietary file present

## Open Questions

1. Should the reader be written in Lua (like every other parser here), in C
   beside the renderer (which will draw from it every frame), or in both
   (the `polyglot-source` pattern: two hand-written versions, one live)?

## Related Documents

- `issues/117-read-wc3-textures.md` (the textures a model names)
- `issues/516-draw-wc3-models-in-engine.md` (the renderer)
- `issues/603-fetch-maps-and-models-from-public-sites.md` (where models come from)
- `docs/versions-we-leave-alone.md` (Reforged formats)
