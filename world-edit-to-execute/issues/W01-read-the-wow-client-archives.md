# Issue W01: Read the WoW Client's Archives

**Phase:** W - WoW Client Bridge
**Type:** Implementation
**Priority:** Critical (every other W issue reads WoW data through this)
**Dependencies:** None open
**Builds on (completed):** our MPQ reader and PKWARE decompression (phase 1)
**Unlocks:** W02, W03

---

## Current Behavior

The project can open WC3 map archives (`src/mpq/`), which are MPQ format
version 1 (32-byte header) with zlib or PKWARE compression. It cannot read the
WoW 3.3.5a client's archives:

- WoW's archives use the second MPQ header layout (`format_version` field = 1,
  44 bytes), which adds a "high block table" so offsets can pass 4 GB.
  `src/mpq/header.lua` reads the field but nothing uses the extra table.
- Many WoW files are bzip2-compressed. `src/mpq/extract.lua` returns the error
  "bzip2 decompression not implemented".
- The client is a **chain** of archives where later ones override earlier ones
  (`common.MPQ` … `patch-3.MPQ`, then the locale archives in `Data/enUS/`).
  Our reader opens one archive at a time and has no notion of a chain.
- There are no readers for WoW's table files (DBC), textures (BLP2) or models
  (M2 + `.skin`).

The sibling project `/mnt/mtwo/games/azeroth-core/custom-client/` plans the
same readers (its issues 105 MPQ reader via StormLib, 106 DBC, 107 BLP), in C.
None of its code exists yet.

## Intended Behavior

One reading layer, used by W02 (to append map rows and look up texture names),
W03 (to load models) and W04 (to know what a display id looks like):

- **Archive chain**: given the client folder, open every archive in the
  client's own load order, look a path up in all of them and return the bytes
  from the last archive that has it. Paths are case-insensitive and use
  backslashes. A lookup that finds nothing is an error naming the path and the
  archives searched, not an empty result.
- **DBC tables**: header `WDBC`, four uint32 counts (records, fields, record
  size, string block size), fixed-size records, then a string block. A layout
  description per table (field name → offset → type) turns rows into Lua tables
  keyed by id. First tables: `Map`, `AreaTable`, `LoadingScreens`,
  `CreatureDisplayInfo`, `CreatureModelData`, `AnimationData`,
  `ItemDisplayInfo`, `ItemSet`, `GameObjectDisplayInfo`.
- **BLP2 textures**: palettized (256 colours + 0/1/4/8-bit alpha) and DXT1/3/5,
  with all mipmaps, decoded to RGBA8 or handed to the GPU still compressed.
- **M2 models** (magic `MD20`, version 264): header, vertices, bones with
  keyframe tracks, sequences, attachments, cameras, texture slots; plus the
  `00.skin` file (which vertices and triangles form the mesh at full detail)
  and external `.anim` files where a sequence's keyframes live outside the M2.
- A **writer** for MPQ archives, needed by W02 to build `patch-W.MPQ`.

## Suggested Implementation Steps

1. Decide open question 1 below (one shared reader or two) before writing code.
2. **Archive chain** (`src/wow/archives`): the load order list lives in a data
   file, not in code; the chain answers `has(path)`, `read(path)`,
   `list(pattern)` and `which(path)` (which archive won).
3. **Decompression**: add bzip2 (via a C library bound through LuaJIT's FFI,
   or through the shared C reader) and the second header layout.
4. **DBC**: one generic reader plus a layout file per table. Verify each layout
   by checking `record size` equals the sum of field sizes; a mismatch is an
   error, because it means the layout is for a different client build.
5. **BLP2**: palettized first (easiest to check by eye), then DXT.
6. **M2**: static mesh first (stand pose, one texture), then bones and one
   sequence, then all sequences, attachments and cameras.
7. **MPQ writer**: StormLib (the reference MPQ library) is the practical
   choice; writing our own is possible later.
8. Tests: against the owner's client, read `Map.dbc` and check its row count
   is plausible and that map id 0 has directory `Azeroth`; decode a known BLP
   to PNG in `tmp/shared-memory/`; load one creature M2 and print bone and
   sequence counts. Tests that need the proprietary client skip with a loud
   notice (not a silent pass) when the client folder is absent.

## Acceptance Criteria

- [ ] Any path in the client resolves through the chain, and `which` names the winning archive
- [ ] bzip2 and the 44-byte header are supported
- [ ] The nine DBC tables above load with verified layouts
- [ ] BLP2 palettized and DXT decode to images that look right
- [ ] One creature M2 loads with mesh, bones, sequences, attachments
- [ ] An MPQ archive can be written and then read back by the chain
- [ ] `.info.md` file beside each new source file

## Open Questions

1. **One reader or two?** (a, recommended) Build the readers once, in C, in the
   custom-client project, as a small library that this project calls through
   LuaJIT's FFI: one implementation, two users, and our renderer is already C.
   (b) Extend our Lua reader: no dependency on a project with no code yet.
   (c) Both, each checking the other.
2. **Client folder**: `client/run` points at `/mnt/dile/ritz/games/wotlk`;
   the files found are in `/mnt/mtwo/games/azeroth-core/client/client-files/`.
   Which is live?

## Related Documents

- `docs/wow-client-bridge.md`, `docs/datapath-wow-models-in-engine.md`
- `docs/formats/mpq-archive.md` (our MPQ notes; will gain a WoW section)
- `/mnt/mtwo/games/azeroth-core/custom-client/docs/003-asset-formats.md`
