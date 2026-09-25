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
   through: **the map's own archive first**, for every path (optional: `map`
   names the map file); then the map's data set copy (`Custom_V1\Units\...` for Frozen Throne
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

Finding (2026-09-24): some maps carry their own copies of the stock tables.
DAoW-5.2 and 5.3 ship `Units\AbilityData.slk`, `ItemData.slk`,
`AbilityBuffData.slk`, `UpgradeData.slk` and three ability profile files (the
work of a map optimizer that moves object data into tables); Daow6.2 ships
`UpgradeData.slk`. Their custom abilities are defined only there: the 369
"orphan" change sets issue 112c reported were changes to these abilities,
named by the maps' units (275) and scripts (45). The game opens the map's
archive above all others (the same rule that lets a map import models over
stock ones), so the map comes before the data-set copy too: `Custom_V1` also
holds an `ItemData.slk`, and the map's must win.

Finding for issue 112: the stock tables custom maps start from are the
data-set copies (`Custom_V0`, `Custom_V1`), which differ from the melee tables
in `Units\` and from `Melee_V0`. Route A must read through the chain, not the
plain paths.

## Intended Behavior

Loading a map picks its game version and data set automatically and says
which; every patch version that has maps is available as a layer; no install
is modified.

The owner (2026-09-24): "we need to be able to apply and remove patches
idempotently. However, patches are linear, so we will need to apply all of
the patches inbetween as well, removing them if we need to downgrade. Make
sure we do it in the correct order!" and "we're going to need to find all
the patches that we support. And we should try and support as many as we
can."

### The patch stack

Versions form one line: 1.07 (the disc) → 1.10 → 1.11 → … → 1.21b → 1.22 →
… → 1.29.2. Each built version is a layer, stored side by side, never merged
into the install:

- **Apply** version N: build every missing layer from the lowest one up to N,
  each on top of the one below it, in version order. A layer's manifest names
  the layer (or the disc install) it was built on, and the patch program's
  hash; a layer whose manifest already matches is left as it is, so applying
  twice changes nothing.
- **Remove** (downgrade to M): a map that needs M reads layer M. Nothing is
  undone on disk because nothing above M was ever written into M; layers
  above it simply aren't read. Deleting a layer removes only that folder,
  and any layer built on it is marked stale and rebuilt from the layer
  below before it is used again.
- **Order** comes from the version table (below), never from file names or
  file dates.

Two kinds of Blizzard patch program exist (Hive Workshop's list, a
cross-check, not a source):
- **full** (`War3TFT_121b_English.exe`): applies to 1.07 or any later
  version. Our 1.21b layer's diffs, `game.dll` included, all match the 1.07
  disc files, which agrees.
- **incremental** (`War3TFT_124b_124c_English.exe`): applies only to the
  version one step below.

A full patch's diffs may be against the disc files rather than the previous
patch. Then building it on the layer below would fail its base checks; the
builder then tries each lower layer down to the disc, highest first, and
records which base matched. The result is the same stack either way; only
the recorded base differs.

### Which versions

Every version that has a Windows patch program with MPQ data: 1.07 through
1.29.2 (1.30 onwards moved to Blizzard's CASC storage, a different format;
out of scope until asked). Reign of Chaos (1.00–1.06) the same way, on the
Reign of Chaos install, for `.w3m` maps.

### Map → version

The map's `war3map.w3i` editor version names a range of patches, not one:

| Editor | Patches | Test maps |
|--------|---------|-----------|
| 6052 | 1.19a – 1.21b | 12 (DAoW 1.23.1B through 5.4c) |
| 6057 | 1.22 | Daow6.2 |
| 6059 | 1.24a – 1.28.5 | DaoW 6.8, 6.93 |
| 6060 | 1.29.0 – 1.29.2 | DaoW-(HvA)-7.5 |

(Run the map scan in the tests for the current map list.) Rule, sane design
over correctness: a map reads the **newest** patch in its range, the
version its author most likely played; a map can name another in its
settings. The table is built from evidence we produce ourselves: each patch
replaces Blizzard's melee maps (`Maps\...`), and those maps record the
editor build that saved them. The wiki table only cross-checks it.

## Acceptance Criteria

- [x] The 1.21b layer built from the patch program without running it
- [x] Loading a map picks its layers automatically and says which
- [x] No file in either install is modified
- [ ] Layers for every patch that has maps (open question 1)
- [ ] Editor versions mapped to layers from evidence (open question 2)

## Open Questions

1. Where do the patch programs come from? Answered in part (2026-09-24): "find all the patches that we support... support as many as we can". Only 1.21b is on this machine. Public mirrors that are not Blizzard's servers: the Internet Archive's `wc3_patches` item (9.9 GB, Reign of Chaos and Frozen Throne, all languages; its English Frozen Throne patches listed so far are 1.24a–1.26a) and `warcraft-iii-installer-enus` (1.21b–1.27b installers, 1.26a–1.29.2 patches); ModDB (1.21b, 1.26a, 1.27a, 1.27b). Downloading them is waiting for the owner's go-ahead on source and size.
2. ~~Editor version → patch~~ Answered 2026-09-24: from the melee maps each patch ships (our own evidence), cross-checked against the published list; a map reads the newest patch in its editor build's range.
3. The data set: Reign of Chaos maps → `Custom_V0`, Frozen Throne maps → `Custom_V1` is inferred from the folder names and contents. Confirm from the game's behaviour (for example, a test map that shows a stat that differs between the two copies).

## Related Documents

- `issues/112-stock-object-tables-by-two-routes.md`, `issues/completed/112a-stormlib-build-and-update-script.md`
- `/home/ritz/games/azeroth-core/wow-chat-2026/docs/patches/patch-registry.md` (the apply/unapply pattern)
- `wc3-installs/README.md`
- `src/gamedata/bsd0.info.md`, `patch_layer.info.md`, `chain.info.md`
