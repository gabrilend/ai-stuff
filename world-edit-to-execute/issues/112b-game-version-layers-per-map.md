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
   names the map file); then the data-set copy the map chose (below), then
   the plain path; each
   in the chosen layer first, then the three archives. The layer is picked by
   the map's editor version through `src/gamedata/editor_versions.lua`;
   without an entry, the newest built layer is used and the fallback is
   reported as a warning. `layer = false` gives the unpatched game; a layer
   name forces that one.
   **The data set** comes from the map's "game data set" setting (open
   question 3): Custom (1) reads `Custom_V1\` for Frozen Throne maps,
   `Custom_V0\` for Reign of Chaos maps; Melee (2) reads the plain melee
   tables for Frozen Throne maps (the patched ones), `Melee_V0\` for Reign of
   Chaos maps; Default (0) is Melee when the map's melee flag is set, Custom
   otherwise. A value outside 0–2 is an error.
5. **Tests** (`src/tests/test_patch_layers.lua`, 17 checks): hand-built
   entries (whole, wrong size, wrong CRC32, unknown kind); the layer's manifest
   and `game.dll` version; a Frozen Throne map reading unit weapons from the
   layer's `Custom_V1` copy, a table it doesn't override from the plain path,
   different values unpatched, the manifest's CRC32; a Reign of Chaos map
   reading `Custom_V0`; a listed editor version picking its layer without a
   warning.

6. **The stack** (2026-09-24). `scripts/fetch-patch-programs.sh` gathered
   the English Frozen Throne programs for 1.21b, 1.22a, 1.23a, 1.24a–e,
   1.25b, 1.26a and 1.27b (and Reign of Chaos 1.24a–1.27b, not built yet) into
   `wc3-installs/patch-programs`, with a checksum record.
   `build-patch-layer.lua --stack` builds them in version order, each on the
   layers below (`patch_layer.build`'s `lower_layers`); a diff's base is the
   first copy, highest layer first then the disc, whose size and CRC32 match.
   A second run rebuilds nothing; a layer whose program or layers beneath
   changed is rebuilt, and so is everything above it.
   - **Order** is the version stamped in the `War3.exe` each program writes
     (`patch_layer.target_version`). The programs' own scripts can't be
     trusted for it: from 1.25b on they check "older than 1.99.99.9999", a
     placeholder, and ordering by it built 1.27b before 1.25b.
   - **Every program found is a full patch**: all 301 diffs in each, from
     1.21b to 1.26a, sit on the 1.07 disc files; 1.27b ships only whole
     files. No lower layer has been needed as a base yet.
   - **Editor builds** (`src/gamedata/editor_versions.lua`): each layer's
     `WorldEdit.exe` holds its own build number and not its predecessor's
     (6052 only in 1.21b, 6057 only in 1.22a, 6058 only in 1.23a, 6059 from
     1.24a on), agreeing with the published list. 6052 → 1.21b, 6057 →
     1.22a, 6058 → 1.23a, 6059 → 1.27b.
   - Tests (`test_patch_layers.lua`): versions read through a placeholder,
     each layer's `Game.dll` version, a second stack build changing nothing,
     every editor build naming a built layer. `test_stock_rows.lua` merges
     each test map on its own version and names the one with no layer yet
     (DaoW 7.5, editor 6060) as a warning.

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

Every version with a Windows patch program and MPQ data, **up to the last
version before Blizzard stopped clients sharing one CD key from playing
together**. The owner (2026-09-24): "we also, on principle, should only
support the patches that were before Blizzard removed the capability to
have multiple clients that shared a CD key play together. That change killed
the game." By the dates (open question 4) that change came with 1.31.0
(May 28, 2019) or 1.31.1 (June 10, 2019), so the last supported version is
1.30.4. Every MPQ-era version (up to 1.29.2) is before the cutoff, 1.26a and
1.27b included. 1.30.x is inside the cutoff too, but moved to Blizzard's
CASC storage, a different format: a separate reader, when wanted. Reign of Chaos the
same way, on the Reign of Chaos install, for `.w3m` maps.

One patch program per version is needed, even though a full patch installs
over any earlier version: it goes forward to its own version only, and holds
that version's files (whole, or as diffs against the disc). The 1.27b patch
cannot produce 1.22's tables; nothing in it describes them.

Patch programs are gathered by `scripts/fetch-patch-programs.sh` from the
mirrors in `wc3-installs/patch-sources.tsv` (tracked) into
`wc3-installs/patch-programs` (a link beside the installs, never in git),
with a record of each file's checksum, mirror and date.

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
- [ ] Layers for every patch that has maps (open question 5: 1.29.x has no patch program)
- [x] Editor versions mapped to layers from evidence (6052, 6058, 6059)
- [x] The stack builds in version order, twice without change

## Open Questions

1. Where do the patch programs come from? Answered in part (2026-09-24): "find all the patches that we support... support as many as we can". Only 1.21b is on this machine. Public mirrors that are not Blizzard's servers: the Internet Archive's `wc3_patches` item (9.9 GB, Reign of Chaos and Frozen Throne, all languages; its English Frozen Throne patches listed so far are 1.24a–1.26a) and `warcraft-iii-installer-enus` (1.21b–1.27b installers, 1.26a–1.29.2 patches); ModDB (1.21b, 1.26a, 1.27a, 1.27b). Downloading them is waiting for the owner's go-ahead on source and size.
2. ~~Editor version → patch~~ Answered 2026-09-24: from the melee maps each patch ships (our own evidence), cross-checked against the published list; a map reads the newest patch in its editor build's range.
4. ~~The shared-CD-key cutoff~~ Answered 2026-09-24 from dates (the owner: "check the dates on the threads, then the release dates of the patches"). A Hive Workshop thread, Feb 24 – Mar 20, 2019, says one key works for several players on LAN (1.30.4, Jan 14, 2019, was current). A Blizzard forum post of July 5, 2019 says "after recent patches I have been unable to join my own LAN games like I could before"; the patches between were 1.31.0 (May 28, 2019) and 1.31.1 (June 10, 2019). Cutoff: after 1.30.4. Inferred from two community posts, not a changelog; a changelog line or a two-client test on 1.30.4 and 1.31.0 would confirm it.
5. **Versions with no public English patch program found yet**: 1.10–1.21a, 1.27a, 1.28.x, 1.29.x. 1.22a was found (2026-09-24) on the Internet Archive (`war3tft-en-patch122a`, a full patch) and built. 1.29.x matters now: DaoW 7.5 was saved by its editor (6060). 1.28 onwards shipped through Blizzard's launcher; the only 1.29.2 copies found are whole game installs (`warcraft-iii-1-29-2-9231`, 1.35 GB), not patch programs. Using one means taking its data archives as a layer instead of building one from a patch; to decide with the owner.
3. ~~The data set~~ Answered 2026-09-24. A map chooses it: `war3map.w3i`'s "game data set" (format 17 on) is 0 = Default (based on the map's melee flag), 1 = Custom, 2 = Melee (latest patch). Evidence: the editor's own option names in each layer's `UI\WorldEditStrings.txt` ("Default (based on map melee status)", "Custom (TFT 1.07, RoC 1.01)", "Melee (Latest Patch)"), the values 0 and 2 in the test maps, and the community specification (WC3MapSpecification, `Info/0-33.md`) as a cross-check. It matters: the patches rebalance only the melee tables (`Units\`); the custom copies stay at 1.07 (1.22a's Knight: 28 damage and 1.40 cooldown in `Units\UnitWeapons.slk`, still 25 and 1.50 in `Custom_V1\` up to 1.27b). Seven test maps (DAoW 5.3 to 5.4c) choose Melee and so read the patched tables; the chain had given every Frozen Throne map `Custom_V1`.

## Related Documents

- `issues/112-stock-object-tables-by-two-routes.md`, `issues/completed/112a-stormlib-build-and-update-script.md`
- `/home/ritz/games/azeroth-core/wow-chat-2026/docs/patches/patch-registry.md` (the apply/unapply pattern)
- `wc3-installs/README.md`
- `src/gamedata/bsd0.info.md`, `patch_layer.info.md`, `chain.info.md`
