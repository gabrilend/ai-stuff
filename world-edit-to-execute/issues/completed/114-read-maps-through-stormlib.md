# Issue 114: Read Maps Through StormLib

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Implementation
**Priority:** High
**Dependencies:** 112a (StormLib built), 113 (the reader comparison)

---

## Current Behavior

**Completed 2026-09-24.**

- `src/mpq/init.lua` reads through StormLib with the interface below;
  `src/mpq/map_wrapper.lua` reads the map's 512-byte `HM3W` wrapper. Every
  map parser, the loader and the tools run unchanged; the full test suite
  passes (apart from `test_frames`, failing before this) and the phase 1–4
  demos run clean.
- The binding (`src/mpq/stormlib.lua`) raises on an empty or missing extra
  listfile, and on any failed listing other than "no more files".
- `test_stormlib` is now the coverage test: every stored file of every test
  map read (2,786, of which 2,416 have no known name), every listed name
  readable. `test_mpq` covers the interface, including DAoW-5.2's hidden
  duplicate. Found while writing it: some encrypted files can only be read
  by name, not by position (Daow1.23.1B's `(listfile)`), so names are used
  wherever known.
- The demo launchers (`run-demo.sh`, `run_phase1.sh`, `run_phase2.sh`)
  require LuaJIT and say why; phase 1 used to prefer `lua5.4`, and the others
  fell back to it.
- Retired: renamed with `-done` after the extension for one commit
  (637ab69c5) so nothing loaded or ran them, then removed (`src/mpq/`): `header.lua`, `hash.lua`, `hashtable.lua`,
  `blocktable.lua`, `extract.lua`, `pkware.lua`, `huffman.lua` (+ `.info.md`),
  `adpcm.lua` (+ `.info.md`), `system_codecs.lua` (+ `.info.md`); tests
  (`src/tests/`): `test_hash.lua`, `test_header.lua`, `test_blocktable.lua`,
  `test_extract.lua`, `test_codecs.lua`. No future use anticipated: the
  format is described in `docs/formats/mpq-archive.md`, and git history keeps
  the source for a rewrite.

Before this, two MPQ readers existed side by side:

- **The project's own Lua reader** (`src/mpq/init.lua` with `header.lua`,
  `hash.lua`, `hashtable.lua`, `blocktable.lua`, `extract.lua`, `pkware.lua`,
  `huffman.lua`, `adpcm.lua`, `system_codecs.lua`). Every map parser, the map
  loader (`src/data/init.lua`), `mapdump` and `mpq-extract` opened maps through
  `mpq.open`. It read only files whose names it knew (from the map's
  `(listfile)` or the standard names), because an encrypted file's key comes
  from its name.
- **StormLib** (`src/mpq/stormlib.lua`, issue 112a), used for patch programs,
  the Frozen Throne archives and the per-map game data chain, and as the
  reference the own reader was checked against (issue 113: all 369 named files
  of the 16 test maps match).

A coverage check (2026-09-24) asked whether StormLib extracts everything the
maps store. Over the 16 test maps, the block tables hold 2,786 files. StormLib
lists all 2,786 and reads every one in full, including 2,416 that have no name
in any list (it finds their keys without names), and the hidden duplicate of
`war3map.w3d` in DAoW-5.2 (an encrypted second copy the game never reads,
reached by its position as `File00000131.xxx`; it parses as a valid object
file). The own reader can't read unnamed files at all.

## Intended Behavior

The owner (2026-09-24): "If we're using Stormlib, then let's use that. If we
want to replace it, we'll rewrite the functionality that we're using it
for." And: "Does it successfully extract all of the data that is stored in
the map files? If so, then we can transition to just using Stormlib."

`mpq.open` keeps its interface, and StormLib does the reading behind it. The
map parsers, the loader and the tools don't change. The own reader's
modules retire.

| Method | Behaviour |
|--------|-----------|
| `mpq.open(path)` | an Archive, or `nil` and an error |
| `Archive:has(name)` | boolean |
| `Archive:extract(name)` | the bytes, or `nil` and an error when the file is missing or unreadable |
| `Archive:extract_to_file(name, path)` | `true`, or `nil` and an error |
| `Archive:list()` | every stored file's name (list of strings): names from the map's listfile and the standard names, and `FileNNNNNNNN.xxx` for files with no known name, each readable with `extract` |
| `Archive:file_count()` | how many files are stored (integer) |
| `Archive:info()` | `filepath`, `file_size`, `file_count`, and from the map's 512-byte `HM3W` wrapper `map_name`, `max_players`, `map_flags` |
| `Archive:close()` | releases the handle |

The MPQ header's inner numbers (sector size, format version, table sizes)
were only ever read by the own reader's tests; they're StormLib's concern now
and leave `info()`.

## Suggested Implementation Steps

1. **The binding refuses an empty or missing extra listfile.** Found by the
   coverage check: handed an empty listfile, StormLib's search listed nothing
   at all, silently. `Archive:list` raises instead.
2. **`src/mpq/init.lua` on StormLib**: the table above. `list()` passes the
   standard names (`standard_names.write_listfile`) so known map files are
   listed by name. The `HM3W` wrapper (a small fixed header before the
   archive, not part of MPQ) is read by a small module of its own,
   `src/mpq/map_wrapper.lua`.
3. **Retire the own reader**: `header.lua`, `hash.lua`, `hashtable.lua`,
   `blocktable.lua`, `extract.lua`, `pkware.lua`, `huffman.lua`, `adpcm.lua`,
   `system_codecs.lua` and their `.info.md` files, with the tests that reach
   into them (`test_hash`, `test_header`, `test_blocktable`, `test_extract`,
   `test_codecs`), renamed `-done` for one commit, then removed (the house
   rule for retiring files). `test_stormlib`'s comparison against the own
   reader becomes a coverage test: every stored file listed and read.
4. **Tests**: the whole suite passes on StormLib; `test_mpq` checks the
   interface above, including an unnamed file read by its `FileNNNNNNNN`
   name and the DAoW-5.2 duplicate.
5. **Docs**: `docs/formats/mpq-archive.md` stays as the format description
   (what the archive holds and how Blizzard's game reads it), with a note
   that the project reads archives through StormLib. `CLAUDE.md`'s MPQ
   section and the related issues (102, 113) point here.

## Acceptance Criteria

- [x] Handing the binding an empty listfile raises
- [x] `mpq.open` reads through StormLib with the interface above
- [x] Every stored file of every test map is listed and read (2,786 at the time of writing; the test counts them)
- [x] The own reader's modules and their tests retired (`-done` for one commit, then removed)
- [x] The full test suite passes, apart from failures that were there before (`test_frames`)
- [x] `.info.md` files and docs updated

## Notes

- StormLib needs LuaJIT (the binding uses its FFI). The project already runs
  on LuaJIT; the own reader's Lua 5.3 compatibility for MPQ reading goes away
  with it.
- If StormLib is ever replaced, the replacement is written against the
  interface above (the owner: "we'll rewrite the functionality that we're
  using it for"). `docs/formats/mpq-archive.md` and the git history of the
  retired modules are where that rewrite starts.

## Related Documents

- `issues/completed/102-implement-mpq-archive-parser.md` (the own reader)
- `issues/completed/113-remaining-mpq-compressions.md` (the comparison with StormLib)
- `issues/completed/112a-stormlib-build-and-update-script.md`
- `docs/formats/mpq-archive.md`
