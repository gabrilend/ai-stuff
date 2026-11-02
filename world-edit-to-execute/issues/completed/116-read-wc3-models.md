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

**Written in Lua, run once per model** (owner, 2026-09-26): "the model
reader should only need to be run once, to pull the model's data into memory
for C. That part can be lua. It just has to return data to the renderer,
which stores it for the duration of the map." The reader runs when a map
loads, once for each model the map uses; the renderer copies the result into
its own memory and keeps it until the map ends. Nothing reads model files
while frames are being drawn, so the reader's speed matters only to load
time.

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

**What it reads.** Whatever model a map asks for: a model imported into the
map, or a stock model from the player's own WC3 install (516, the owner's
rule of 2026-09-26), and the community models the player installs as
overrides. The stock models are therefore real input, not only test
material. None of them is committed to the repository; tests build their
own small models.

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

- [x] A version-800 model reads into the table above (under issue 522's field names; see Implementation Notes)
- [x] Geosets, materials, textures and sequences are decoded
- [x] Bones, helpers, pivots and their animation tracks are decoded
- [x] Unknown chunks are kept and reported, never silently dropped
- [x] Truncated and HD files fail with errors that name what and where
- [x] Tests pass without any downloaded or proprietary file present

## Open Questions

1. ~~Lua, C, or both?~~ Answered 2026-09-26: Lua, run once per model at
   map load, handing its data to the renderer (see Intended Behavior).

## Related Documents

- `issues/117-read-wc3-textures.md` (the textures a model names)
- `issues/516-draw-wc3-models-in-engine.md` (the renderer)
- `issues/603-fetch-maps-and-models-from-public-sites.md` (where models come from)
- `docs/versions-we-leave-alone.md` (Reforged formats)

## Implementation Notes

**Date:** 2026-11-02

### What was already there

Issue 522 (2026-09-29) built the reader this issue asked for, as
`src/parsers/mdx.lua`, without updating this file: every chunk listed
above, tracks and their sampler, and the renderer and the model gallery
on top of it. Every one of the 265 distinct models in the 16 test maps
parses (`src/tests/test_assets.lua`). What it lacked, against this issue's
criteria: errors that say where, refusing the versions the project leaves
alone, the summary for the fetcher and catalogue, the `.info.md`, and a
test that needs no downloaded file. This pass adds those.

### Changes (`src/parsers/mdx.lua`)

- **Every read is bounded by the chunk being decoded.** The buffer is raw
  FFI memory: before, the 16-bit and 8-bit reads (triangle indices, vertex
  groups) didn't check the length at all, so a damaged model read
  whatever memory lay past its buffer instead of failing. Now each read
  checks, and an error names the chunk, where it starts and the byte the
  reader stopped at, e.g. `MDX: chunk GEOS (starting at byte 1312), at
  byte 1596: truncated (needs 4 bytes, 1 left)`.
- **Record sizes are checked before use.** Materials, layers, geosets,
  geoset animations, nodes, cameras and texture animations carry their
  own size; a size of zero (or less than the size field) used to set the
  position back to the record's start and loop forever. Now
  `R:record()` refuses it, naming the size and what was left.
- **A chunk header cut short is reported** (`N stray bytes, too few for a
  chunk header`), where before up to seven trailing bytes were dropped
  without a word.
- **Only version 800 is read.** Version 900 and later (Reforged's HD
  models) is refused with an error naming the version and pointing at
  `docs/versions-we-leave-alone.md`; so is a version below 800. The few
  branches 522 had added for Reforged's extra material and geoset fields
  (`version > 800`) are taken out, since they can no longer run.
- **Unknown chunks are reported,** in `m.unread` as `{tag, offset, bytes}`
  in file order. `m.other` (by tag) stays for anything that used it; a
  second chunk of the same unknown tag no longer overwrites the first.
- **`mdx.summary(m)`**: version, name, geoset, vertex, triangle and node
  counts, sequence names, texture paths, replaceable ids, unread tags.
- **`src/parsers/mdx.info.md`** describes inputs, outputs and errors.

### Tests (`src/tests/test_mdx.lua`, 35 tests, 0.2 s)

The test writes a small model itself with `parsers/binwrite.lua` (VERS,
MODL, SEQS, GLBS, TEXS, MTLS with an animated layer, GEOS with one
triangle, BONE with a hermite track, HELP, PIVT and an unknown chunk) and
checks it reads back field by field. Then:
- cut at every byte: either a shorter valid model (cut on a chunk
  boundary) or an error naming the byte;
- every 4-byte window overwritten with all ones and all zeros (about 3,000
  damaged files): only the reader's own `MDX:` errors, never a Lua error;
- a vertex count too large, a material size of zero, an unknown track tag
  and stray trailing bytes each give the expected error;
- versions 900, 1100 and 700 are refused by number;
- with the owner's install present, every stock unit model in
  `UnitUI.slk` is read; without it (as in the cloud container) that test
  prints `SKIPPED` and says why.

The old reader fails the new test (it has no `unread`), and the new
reader reads all 265 models in the 16 test maps to exactly the same
tables as the old one did (checked by comparing the two readers' output
field by field).

### Decisions made while building

1. **522's field names are the interface, not this issue's.** The
   renderer, the editor and the asset tools already use them; renaming
   would break them for no gain. `mdx.info.md` maps each name this issue
   used onto the one the reader has.
2. **Reforged versions are refused, not half read.** 522 read two of
   Reforged's extra fields; this issue, written before it, said to refuse
   900 and later, and the project's policy
   (`docs/versions-we-leave-alone.md`) is to leave Reforged's formats
   alone. All 265 test-map models are version 800, so nothing that
   worked stops working; a refused model gets a stand-in like any
   unreadable one.
3. **Strict sizes over lenient ones.** A record that runs past its chunk
   is an error, not something to read around: the reader is run once per
   model at load time, and a clear error there beats wrong geometry later.
