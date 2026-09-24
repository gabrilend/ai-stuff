# Issue 112a: StormLib, Built From Source by the Dependency Script

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 112
**Priority:** High (blocks reading patch archives)
**Dependencies:** None

---

## Current Behavior

**In progress (2026-09-24).** `scripts/build-dependencies.sh` builds StormLib
`v9.40` into `deps/stormlib/lib/libstorm.so`, linked against the system's zlib
1.3.1 and bzip2 1.0.8, with libtomcrypt compiled in from StormLib's own source.
A second run is a no-op; `--list-tags`, `--latest` and `--pin` work.
`src/mpq/stormlib.lua` (LuaJIT FFI: open, list, has, read, extract, close)
opens the 1.21b patch program directly and lists its embedded archive.

Remaining: the `mpq-extract` CLI, the byte-for-byte comparison test against
our own reader, `.info.md` files, and the licence entries. **Licence finding:**
StormLib's bundled copy of libtomcrypt (`src/libtomcrypt/`) carries no licence
file or statement; upstream LibTomCrypt is released into the public domain
(dual Unlicense/WTFPL in current releases). The release review should either
record that or link against a system LibTomCrypt that carries its notice.

Before this: the project's own MPQ reader (`src/mpq/`) reads WC3 map
archives, but not Blizzard's patch or WoW archives: it lacks bzip2 and other
compression methods those use. On 2026-09-24 the 1.21b patch's embedded
archive opened in it, but every file failed to decompress.

(An earlier first cut of this issue put the script at `src/cli/build-stormlib.sh`
with the build in `libs/stormlib/`; the owner asked for it to live in
`scripts/`, as one dependency in a script that walks through all of them, on
the pattern of `/home/ritz/programs/r-mail/scripts/install.sh`.)

## Intended Behavior

**StormLib** (github.com/ladislav-zezula/StormLib, by Ladislav Zezula, MIT
licence, checked 2026-09-24) is the reference open-source MPQ library: it
reads and writes MPQ archives of every version and compression Blizzard used.

`scripts/build-dependencies.sh` compiles every third-party library the project
needs, one by one, into the project-local `deps/` folder; nothing is installed
system-wide:

- A hard-coded `DIR` (the project root), overridable by the first argument.
- Phases, as in r-mail's installer: toolchain check, then each dependency in
  order, then a summary. Re-running skips what's already built at its pin;
  `--force` rebuilds.
- **Pins** in `deps/versions` (one `name tag` per line, tracked in git), so an
  upgrade is one reviewed line. `--pin NAME TAG` sets one; `--latest NAME`
  pins the newest upstream release tag; `--list-tags NAME` shows what upstream
  offers, newest last; `--list` shows each dependency's pin and build state.
- Source clones and build folders live in `.build-tmp/` and are disposable.
- Each dependency's licence, copying and notice files are copied into
  `deps/licenses/<name>/`, keeping their paths, for the release review.
- Adding a dependency = one entry in its list plus one `build_<name>` function.

A LuaJIT FFI binding, `src/mpq/stormlib.lua`, exposes what the project needs:
open an archive (including one embedded in a program file), list its files,
read a file to bytes or extract it to disk, close.

## Suggested Implementation Steps

1. ~~Build script~~ done; ~~FFI binding~~ done.
2. A small CLI, `src/cli/mpq-extract.lua`, over the binding: list or extract an archive's files.
3. Tests: list and extract from a project map archive (already readable by our own reader) and compare bytes with our reader's output.
4. Record the licences of StormLib and its bundled libraries in the licence map, including the libtomcrypt finding above.

## Acceptance Criteria

- [x] One command builds StormLib from a pinned tag; a second run is a no-op
- [x] `--pin`, `--latest` and `--list-tags` work
- [ ] The FFI binding lists and extracts files from a map archive, byte-identical to our own reader
- [ ] Licences of StormLib and bundled libraries listed

## Related Documents

- `issues/112-stock-object-tables-by-two-routes.md`
- `docs/licensing-and-boundaries.md`
- `/home/ritz/programs/r-mail/scripts/install.sh` (the pattern)
- `/home/ritz/games/azeroth-core/wow-chat-2026/docs/patches/patch-registry.md` (source as a disposable artefact at a pinned version)
