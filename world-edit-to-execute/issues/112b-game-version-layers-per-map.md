# Issue 112b: Game-Version Layers, Chosen Per Map

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 112
**Priority:** High
**Dependencies:** 112a (completed)

---

## Current Behavior

**In progress (2026-09-24): built and tested; open questions remain.**

The owner (2026-09-24): "we should be able to dynamically apply and unapply
each patch that might have maps for it. When you load a map, it should 'just
work'."

Nothing on disk is ever patched. The Frozen Throne install in
`wc3-installs/frozen-throne` stays the unpatched disc version (1.07); running
Blizzard's 1.21b patcher under wine crashed (a stack overflow) after writing
only its notes. Instead:

1. **Reading the patch program** (`src/gamedata/patch_layer.lua`). The .exe
   holds an MPQ archive (read with StormLib, `src/mpq/stormlib.lua`) whose
   `mpqs.lst` names a nested archive, `Patch_War3x.mpq`, with:
   - `patch.lst`: one entry per line, `target;name-in-archive;0x0` for a file
     that goes into the rebuilt `War3Patch.mpq`, or `target;name-in-archive`
     for a loose install file (maps, `game.dll`, `war3.exe`). A line holding
     only `*` ends the list. One name can live in several folders, so names in
     the archive carry `~00`, `~01` suffixes.
   - `delete.lst`: install files deleted first. It starts with
     `War3Patch.mpq`: the patcher builds that archive afresh from `patch.lst`
     alone, so **a layer is complete by itself** and layers replace each other.
   - `patch.cmd`: the patcher's script, including the version check
     (`FileVersionLessThan War3.exe 1.21.1.6300`).
2. **Applying entries** (`src/gamedata/bsd0.lua`). Each entry has a 24-byte
   header (kind, the old file's CRC32 and size, the new size, a timestamp) and
   is either the whole new file or a Blizzard "BSD0" diff: a run-length-packed
   BSDIFF40 patch with uncompressed blocks (StormLib's format of the same name).
   Archive entries diff against the same path in `War3xlocal.mpq`,
   `War3x.mpq`, `war3.mpq`; loose entries diff against the file on disk. A base
   with the wrong CRC32 or size is refused.
3. **The 1.21b layer** (`src/cli/build-patch-layer.lua`), stored at
   `wc3-installs/patch-layers/1.21b` (a link to
   `/mnt/mtwo/games/warcraft-iii/patch-layers`, ignored by git): 577 archive
   files and 137 install files, 301 of them diffs, every base matching its
   CRC32, built in about 2 seconds, 92 MB. The patched `game.dll` reports
   version 1.21.1.6300, exactly the version the patch names (it was 1.07.5535).
4. **Per-map chains** (`src/gamedata/chain.lua`). A map's stock data is read
   through: the map's data set copy (`Custom_V1\Units\...` for Frozen Throne
   maps, `Custom_V0\...` for Reign of Chaos maps), then the plain path; each
   in the chosen layer first, then the three archives. The layer is picked by
   the map's editor version through `src/gamedata/editor_versions.lua`;
   without an entry, the newest built layer is used and the fallback is
   reported as a warning. `layer = false` gives the unpatched game; a layer
   name forces that one.
5. **Tests** (`src/tests/test_patch_layers.lua`, 17 checks): hand-built
   entries (whole, wrong size, wrong CRC32, unknown kind); the layer's manifest
   and `game.dll` version; a Frozen Throne map reading unit weapons from the
   layer's `Custom_V1` copy, a table it doesn't override from the plain path,
   different values unpatched, the manifest's CRC32; a Reign of Chaos map
   reading `Custom_V0`; a listed editor version picking its layer without a
   warning.

Finding for issue 112: the stock tables custom maps start from are the
data-set copies (`Custom_V0`, `Custom_V1`), which differ from the melee tables
in `Units\` and from `Melee_V0`. Route A must read through the chain, not the
plain paths.

## Intended Behavior

Loading a map picks its game version and data set automatically and says
which; every patch version that has maps is available as a layer; no install
is modified.

## Suggested Implementation Steps

1. ~~Read a patch program; apply its entries; store a layer with a manifest.~~ Done (1.21b).
2. ~~Chain assembly per map, with data sets and a reported fallback.~~ Done.
3. Build layers for the other patches that have maps (needs their patch
   programs; see open question 1). Patches that ship several steps (older
   patch programs sometimes diff against an earlier patch's files) need the
   base archives list extended with the lower layer.
4. Fill `editor_versions.lua` from evidence (open question 2).
5. Confirm how the game picks its data set (open question 3).

## Acceptance Criteria

- [x] The 1.21b layer built from the patch program without running it
- [x] Loading a map picks its layers automatically and says which
- [x] No file in either install is modified
- [ ] Layers for every patch that has maps (open question 1)
- [ ] Editor versions mapped to layers from evidence (open question 2)

## Open Questions

1. Which patches does the owner want layers for? Each needs its patch program; only 1.21b is on this machine.
2. Editor version → patch: the test maps carry editor versions 6052, 6057, 6059 and 6060. Build the table from maps whose patch is known, from the World Editor binaries in each layer, or from published changelogs?
3. The data set: Reign of Chaos maps → `Custom_V0`, Frozen Throne maps → `Custom_V1` is inferred from the folder names and contents. Confirm from the game's behaviour (for example, a test map that shows a stat that differs between the two copies).

## Related Documents

- `issues/112-stock-object-tables-by-two-routes.md`, `issues/completed/112a-stormlib-build-and-update-script.md`
- `/home/ritz/games/azeroth-core/wow-chat-2026/docs/patches/patch-registry.md` (the apply/unapply pattern)
- `wc3-installs/README.md`
- `src/gamedata/bsd0.info.md`, `patch_layer.info.md`, `chain.info.md`
