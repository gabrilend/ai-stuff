# Issue 112a: StormLib, Built From Source by a Script

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 112
**Priority:** High (blocks reading patch archives)
**Dependencies:** None

---

## Current Behavior

The project's own MPQ reader (`src/mpq/`) reads WC3 map archives, but not the
archives inside Blizzard's patch programs or WoW's archives: it lacks bzip2 and
other compression methods those use. On 2026-09-24 the 1.21b patch's embedded
archive (cut out of `War3TFT_121b_English.exe` at byte offset 167936) opened,
but every file in it failed to decompress. No MPQ tool or StormLib is
installed on this machine.

## Intended Behavior

**StormLib** (github.com/ladislav-zezula/StormLib, by Ladislav Zezula, MIT
licence, checked 2026-09-24) is the reference open-source MPQ library: it
reads and writes MPQ archives of every version and compression Blizzard used,
and verifies them. It builds with CMake and can use bundled copies of zlib,
bzip2 and libtomcrypt.

A script, `src/cli/build-stormlib.sh`, makes it a project tool:

- A hard-coded `DIR` (the project root), overridable by the first argument;
  all paths relative to it.
- Clones StormLib at a **pinned release tag** (first pin: `v9.40`) into
  `libs/stormlib/source/` (not committed; a build artefact, re-cloned on demand).
- Builds a shared library with CMake into `libs/stormlib/build/` and copies
  `libstorm.so` to `libs/stormlib/lib/`.
- `--update <tag>` moves the pin to a newer tag, rebuilds, and records the new
  pin in `libs/stormlib/PINNED` (committed), so an upgrade is one reviewed line.
- Prints the licence file path of StormLib and of each bundled library it
  compiled in, for the release review in `docs/licensing-and-boundaries.md`.

A LuaJIT FFI binding, `src/mpq/stormlib.lua`, exposes what the project needs:
open an archive (including one embedded at an offset in a program file), list
its files, extract a file to bytes or to disk, close.

## Suggested Implementation Steps

1. Write the build script; run it; confirm `libstorm.so` loads from LuaJIT.
2. Write the FFI binding (open, find-first/find-next listing, read file, close).
3. A small CLI, `src/cli/mpq-extract.lua`, over the binding: list or extract an archive's files.
4. Tests: list and extract from a project map archive (already readable by our own reader) and compare bytes with our reader's output.
5. Record the licences of StormLib and the bundled libraries in the licence map.

## Acceptance Criteria

- [ ] One command builds StormLib from a pinned tag; a second run is a no-op
- [ ] `--update <tag>` changes the pin and rebuilds
- [ ] The FFI binding lists and extracts files from a map archive, byte-identical to our own reader
- [ ] Licences of StormLib and bundled libraries listed

## Related Documents

- `issues/112-stock-object-tables-by-two-routes.md`
- `docs/licensing-and-boundaries.md`
- The upstream-patch pattern used by `/home/ritz/games/azeroth-core/wow-chat-2026/` (source cloned as a disposable build artefact at a pinned commit)
