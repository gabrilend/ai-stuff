# mdx.lua

Reads Warcraft III's binary model format (`.mdx`, version 800) into a Lua
table. It runs once per model when a map loads; the renderer
(`src/assets/gpu.lua`) copies what it needs into its own memory. Needs
LuaJIT (the reader uses its FFI for floats).

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `parse(bytes)` | the file's bytes (string) | the model table below; raises an error on a bad file (see Errors) |
| `summary(m)` | a parsed model | `{version, name, geosets, vertices, triangles, nodes, sequences, textures, replaceable_ids, unread}` |
| `nodes(m)` | a parsed model | every node of every kind (bones, helpers, attachments, lights, emitters, ribbons, events, collision shapes), by object id |
| `sequence(m, name)` | a parsed model, a name such as `"stand"` | the sequence whose name matches (`"Stand 1"` matches `"stand"`), else the first |
| `sample(track, frame, default, first, last, rotation)` | a track, a frame, a value for no track | the track's value at that frame; `first`/`last` limit it to one sequence's keys; `rotation` interpolates quaternions by slerp |

Constants: `VERSION` (800), `FILTER` (filter mode number → name: `none`,
`transparent`, `blend`, `additive`, `add_alpha`, `modulate`,
`modulate2x`), `SHADING` (shading flag name → bit).

## The model table

| Field | Type | From |
|-------|------|------|
| `version` | integer (800) | `VERS` |
| `name`, `animation_file`, `extent`, `blend_time` | string, string, extent, integer | `MODL` |
| `sequences` | list of `{name, start, finish, move_speed, non_looping, rarity, sync_point, extent}` | `SEQS` |
| `global_sequences` | list of durations (integers) | `GLBS` |
| `textures` | list of `{replaceable, path, flags, wrap_width, wrap_height}`; `path` is `""` when `replaceable` (1 team colour, 2 team glow, 11 cliff, 31-37 trees ...) is set | `TEXS` |
| `materials` | list of `{priority_plane, flags, layers}`; a layer is `{filter_mode, filter, shading, texture, texture_animation, coord, alpha, tracks}` | `MTLS` |
| `geosets` | list of `{vertices, normals, face_types, face_counts, faces, vertex_groups, group_sizes, group_indices, material, selection_group, selection_flags, extent, sequence_extents, uvs}`; vertices and normals are flat lists, three numbers a vertex; `faces` three vertex indices (from 0) a triangle; `uvs` a list of UV sets, two numbers a vertex | `GEOS` |
| `geoset_animations` | list of `{alpha, flags, color, geoset, tracks}` | `GEOA` |
| `bones`, `helpers` | lists of nodes; a node is `{name, id, parent, flags, tracks}`, a bone adds `geoset`, `geoset_animation` | `BONE`, `HELP` |
| `pivots` | list of `{x, y, z}`, by object id (the first is id 0) | `PIVT` |
| `attachments`, `events`, `collision`, `cameras`, `texture_animations` | decoded records | `ATCH`, `EVTS`, `CLID`, `CAMS`, `TXAN` |
| `lights`, `particle_emitters`, `particle_emitters2`, `ribbons` | nodes, with their own fields kept as bytes in `raw` | `LITE`, `PREM`, `PRE2`, `RIBB` |
| `unread` | list of `{tag, offset, bytes}`, in file order | every chunk this reader doesn't decode |
| `other` | tag → bytes (the first chunk of each tag) | the same chunks, by tag |
| `chunks` | list of tags in file order | every chunk |

An extent is `{radius, min = {x, y, z}, max = {x, y, z}}`. A track is
`{interpolation, global, keys}`: interpolation 0 none, 1 linear, 2 hermite,
3 bezier; `global` is a global sequence id or nil; each key is
`{frame, value, inTan, outTan}`, the tangents only for hermite and bezier.
Tracks are kept by their tag (`tracks.KGTR`, `tracks.KMTA` ...).

Issue 116 described the table with other names (`first_frame`,
`replaceable_id`, one `nodes` list); this reader was built first by issue
522 for the renderer, so its names are the interface, and the names in 116
map onto them as: `first_frame`/`last_frame` → `start`/`finish`,
`looping` → `not non_looping`, `replaceable_id` → `replaceable`,
`texture_index` → `texture`, `blend_mode` → `filter_mode`, `triangles` →
`faces`, `groups` → `group_sizes` + `group_indices`, `material_index` →
`material`, `parent_id` → `parent`, `nodes` → `nodes(m)`.

## Errors

Every error starts `MDX:` and says where:

- **Not a model:** `not an MDX model (no MDLX)`.
- **Another version:** `MDX: version 900 is Reforged's HD model format,
  which isn't read (only version 800; see docs/versions-we-leave-alone.md)`;
  a version below 800 is refused the same way.
- **Cut short:** `MDX: the chunk list, at byte 396: chunk "SEQS" claims
  264 bytes, but 196 are left`, or `... N stray bytes, too few for a chunk
  header`.
- **A wrong size or count inside a chunk:** `MDX: chunk GEOS (starting at
  byte 1312), at byte 1596: truncated (needs 4 bytes, 1 left)`, or `... a
  record claims 0 bytes, but 80 are left`.
- **An unknown animation track** inside a decoded chunk: named by its tag.

No read goes past the chunk being decoded, and a record's size is checked
before it is used, so a damaged file fails with one of these errors; it
never reads memory past its buffer and never loops forever.

The callers (`src/assets/init.lua`, `src/assets/tool.lua`, the model
gallery) catch the error and draw a stand-in, as for a missing model.

## Tests

`src/tests/test_mdx.lua` builds its own model byte by byte, and
`src/tests/test_assets.lua` reads every model the test maps carry.
