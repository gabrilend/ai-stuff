# Issue W10a: The WoW Layer of a Map

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W10 (its step 1, and the keeping half of step 8)
**Priority:** High (every later W10 step edits what this opens and keeps)
**Dependencies:** W10's answered question 1 (one map holds both games), 911c (map projects), the W client's reader library (`libwreaders.so`: its 020-adt), W02a/W02b (the WoW maps the tests are made from)
**Blocks:** W10's steps 2-9 (the editors on a WoW map)

---

## Current Behavior

*As written (2026-11-05, before this issue's work):* the editor opens
WC3 maps and map projects (911c). A project's `wow/` folder is
"reserved for the WoW layer (issue 911's design): nothing yet": a WC3
build warns about each file in it, and nothing reads, keeps or writes a
WoW map. WoW maps exist in this project only as W02's output, a build
folder at the client's own paths (`World/Maps/<dir>/`).

*Now:* see Implementation Notes.

## Intended Behavior

One map holds both games (the owner, 2026-11-04: "we are unifying
them"; W10's question 1). A map project keeps WoW maps beside its WC3
part, under `wow/`, at the client's own paths:

    MyMap.wex/wow/World/Maps/<dir>/<dir>.wdt, <dir>.wdl, <dir>_<tx>_<ty>.adt
    MyMap.wex/wow/layer.lua      what was added: each file's size and CRC-32

- A WoW map is added from any loose folder holding it (a W02 build, the
  W client's overlay, a map made by hand), byte for byte.
- It is validated for a WoW build (its WDT, its tiles' names, what
  changed since it was added; with the W client's reader, every tile
  read), and built out again as a loose folder, byte for byte, so a WoW
  map saved without changes is the map that was opened (W10's acceptance
  line 3).
- A WC3 build leaves it out and says so once a map, not once a file.
- The editor lists a project's WoW maps and reads their tiles for its
  tools: each chunk's position, 145 heights, holes, texture layers with
  their 64 x 64 blend maps, shadow and tints; each placed model and
  building with its name, unique id, position, turn and scale (and a
  building's box and doodad set); each water layer.

## Suggested Implementation Steps

1. `src/editor/wowmap.lua`: a map's files by kind, the W client's reader
   loaded by FFI, a tile read into Lua data, and the editor's side
   (`E:wow_maps`, `E:wow_map`).
2. `src/editor/mapfile.lua`: `add_wow`, `validate(dir, "wow")`,
   `build_wow`, the layer's record, the WC3 build's one line a map, and
   the command line.
3. Tests on a WoW map W02's converter makes from a made WC3 terrain (no
   WC3 or WoW install), with the reader's part skipped without the
   library.

## Acceptance Criteria

- [x] A WoW map from a loose folder is added to a map project's `wow/`
      layer byte for byte, and built out again byte for byte.
- [x] The layer is validated for a WoW build; a WC3 build leaves it out
      and still builds.
- [x] The editor, on a map opened from a project, lists its WoW maps and
      reads every tile through the W client's reader: chunks, heights,
      layers, blend maps, placements, water.
- [ ] Drawn by the editor's Lua renderer (W10's acceptance line 1: needs
      the window; the data it draws from is here).

## Open Questions (each answered 2026-11-05, as decisions below; the owner's to overturn)

1. Where is a WoW map read from: a loose folder, or the client's own
   archives?
2. Which tiles a map has: the WDT's list of tiles, or the ground files
   present?
3. What the project keeps of a WoW map: its files as they are, or a
   readable form (as 911c keeps WC3 files as text where it can)?
4. Where in a project the WoW layer lives, and how it is recorded so a
   WC3 export doesn't lose it.
5. Can a project be WoW-only, with no WC3 part?
6. Which reader, and what happens without it?
7. Which coordinates the tools see.

## Decisions (2026-11-05; each the owner's to overturn)

1. **From a loose folder.** W02's builds and the W client's overlay
   (its 105a) are loose folders at the client's own paths, so a map is
   added from `<root>/World/Maps/<dir>/`. Reading the stock client's
   archives needs a WoW install and the reader's archive chain; that is
   a later step, and W10's question 3 (Blizzard's maps are templates to
   learn from; the project ships its own) applies when it comes: a map
   taken from the client's archives isn't copied into a project that is
   shared.
2. **The ground files present.** A map's tiles are its
   `<dir>_<tx>_<ty>.adt` files (tx west to east, 0-63), as the W client
   finds them: the W client has no reader for the WDT's tile list
   (`MAIN`), only for its blend-map form (`adt_wdt_big_alpha`), and this
   project writes no second reader (one reader per format, 2026-10-07).
   Asking the W client for a WDT tile-list reader is noted for
   custom-client; until then a file named outside 0-63, or not named as
   a tile, is warned about.
3. **The files as they are.** No readable form of an ADT gives the file
   back byte for byte yet (W02's writer writes its own tiles, not any
   tile), and 911c's rule is to use a readable form only when it does.
   So the layer keeps the files whole and the editor reads a view of
   them. An edited tile will be written by W10's step 8 (W02's writers).
4. **`wow/World/Maps/<dir>/`, recorded in `wow/layer.lua`.** At the
   client's own paths, the layer is itself a loose overlay the W client
   can read. The record lives under `wow/` because a WC3 export writes
   the rest of the project afresh and keeps `wow/` as it is (911c). It
   holds each added file's size and CRC-32, so validation can say what
   changed since: an edit is information, not an error.
5. **Not yet.** The editor opens a project by building its WC3 part
   (911c), so a project needs one; a WoW-only map waits for W10's
   new-map step. `wowmap.open` itself works on any folder.
6. **The W client's reader, by FFI** (`libwreaders.so`, from
   `$W_CLIENT_BUILD`, else the W client's own default build folder).
   Without it the layer is still added, validated by name and built
   out; reading a tile says why it can't.
7. **The reader's own:** world yards, x north, y west, z up; heights
   above each chunk's base, in the file's order. No conversion, so a
   tool and the W client agree on every number.

## Implementation Notes

*(2026-11-05)*

- `src/editor/wowmap.lua` (new): `maps`, `files`, `valid_name`,
  `reader`, `open`; a map's `tile`, `read_all`; `attach` gives the
  editor `E:wow_root`, `E:wow_maps`, `E:wow_map`.
- `src/editor/mapfile.lua`: `add_wow`, `validate_wow` (and
  `validate(dir, "wow")`), `build_wow`, `WOW_LAYER`; a WC3 build's WoW
  maps are one `info` line each; another mode is refused by name; the
  command line has `add-wow`, `build-wow` and `validate DIR wow`; the
  README written into `wow/` says what it holds.
- `src/editor/init.lua`: attaches the WoW layer to every opened map.
- **Tests:** `src/tests/test_wow_layer.lua` (new): 50 with the W
  client's reader library, 34 and 2 skipped without. A WoW map made by
  W02's converter (two tiles, a lake, a tree, a hut):
  - its files by kind;
  - a folder without its WDT, an out-of-range or misnamed tile,
    a missing map and a bad name;
  - read through the reader: 256 chunks at W02's layout's positions,
    145 heights, texture names, blend maps, shadow and tints, the lake's
    water, the tree's model and unique id, the hut's building and box,
    a tile kept once read, and a damaged tile's why;
  - added to a project exported from Daow 4.4: byte for byte, recorded,
    validated, left out of the WC3 build in one line while the WC3 map
    still builds;
  - built out byte for byte with nothing else, and kept through a
    second WC3 export;
  - validation's notes: a changed tile, a file off the client's paths,
    a folder with no WDT (the WoW build refused), a misnamed tile, an
    added map's lost WDT, an unknown mode, every tile read;
  - the editor listing and opening the WoW map of a project, and saying
    a `.w3x` has none.

  `test_mapfile` 36, `test_editor` 83 and `test_editor_integration` 44
  are unchanged.

**Still open:** drawing a WoW map in the editor's window (W10's
acceptance line 1), reading the stock client's archives (decision 1), a
WoW-only project (decision 5), and the WDT tile-list reader in the W
client (decision 2).
