# Issue W01: Read the WoW Client's Archives

**Phase:** W - WoW Client Bridge
**Type:** Implementation
**Priority:** Critical (every other W issue reads WoW data through this)
**Dependencies:** None open
**Builds on (completed):** our MPQ reader and PKWARE decompression (phase 1)
**Built in:** the W client, `/mnt/mtwo/games/azeroth-core/custom-client/`, issues 104, 105, 106, 107 (and 401 for models)
**Unlocks:** W02, W03

---

## Current Behavior

This project can open WC3 map archives (`src/mpq/`, MPQ format version 1,
zlib or PKWARE compression). It cannot read the WoW 3.3.5a client's archives:
no 44-byte header support, no bzip2, no chain of archives, no readers for WoW
tables (DBC), textures (BLP2) or models (M2).

As of 2026-09-23 the readers are not built here. The W client (formerly the
custom-client project) builds them once, in C, as a shared library,
`libwreaders.so`, and this issue is this project's side of that arrangement.
Nothing is built on either side yet.

## Intended Behavior

This project's Lua code uses the W client's reading layer through LuaJIT's
FFI, and never keeps a second implementation:

- A Lua module (`src/wow/readers.lua`) loads `libwreaders.so` with the
  declarations in the W client's `wreaders_ffi.h`, and offers Lua-shaped calls:
  - archive chain: `open(client_folder)`, `read(path)`, `has(path)`,
    `which(path)` (which archive supplied the file), `list(pattern)`;
  - tables: `dbc(name)`, returning rows keyed by id, decoded with the
    generated `dbc_layouts.lua` (the W client generates both the C structs and
    this Lua file from one set of layout files, so the two projects cannot
    disagree);
  - textures: `blp_decode(bytes)` → RGBA8 image, and `blp_encode(image, format)`;
  - archive writing: `mpq_write(path, entries)`, used by W02 to build
    `patch-W.MPQ` for the **stock** client (the W client reads converted maps
    as loose folders and does not need it);
  - models (after the W client's issue 401): `m2_load(path)`.
- Errors from the library arrive as Lua errors naming the path and the
  archives searched, never as nil results.
- WC3 maps keep using this project's own Lua MPQ reader, which works; the
  shared library is for WoW's archives.

## Suggested Implementation Steps

1. Wait for (or help build) the W client's issues 104-107.
2. Write `src/wow/readers.lua` over the FFI, plus its `.info.md`.
3. Load `dbc_layouts.lua` from the W client's build output (path in the
   launcher config, W02f).
4. Tests against the owner's client: `Map.dbc` has map id 0 with directory
   `Azeroth`; `which` names a patch archive for a known overridden file; a BLP
   decodes and re-encodes; a small archive written with `mpq_write` reads back.
   Tests that need the proprietary client stop with a loud notice (not a silent
   pass) when the client folder is absent.

## Acceptance Criteria

- [ ] `src/wow/readers.lua` reads the chain, DBC tables and BLP textures through `libwreaders.so`
- [ ] `which`, `list` and `mpq_write` work from Lua
- [ ] No second MPQ/DBC/BLP implementation for WoW files exists in this project
- [ ] `.info.md` beside the new module

## Open Questions

1. **Client folder**: `client/run` points at `/mnt/dile/ritz/games/wotlk`; the
   files found are in `/mnt/mtwo/games/azeroth-core/client/client-files/`.
   Which is live?

## Related Documents

- `docs/wow-client-bridge.md` (Decisions made: the W client)
- `/mnt/mtwo/games/azeroth-core/custom-client/issues/105-mpq-reader.md`, `106-dbc-parser.md`, `107-blp-parser.md`
- `/mnt/mtwo/games/azeroth-core/custom-client/docs/003-asset-formats.md`
