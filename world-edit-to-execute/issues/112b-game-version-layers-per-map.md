# Issue 112b: Game-Version Layers, Chosen Per Map

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 112
**Priority:** High
**Dependencies:** 112a (reading patch archives)

---

## Current Behavior

The Frozen Throne install in `wc3-installs/frozen-throne` is the unpatched
disc version. Running patch 1.21b under wine failed twice (2026-09-24): the
patcher copied its updater and notes, then crashed with a stack overflow
before changing any game file. Patches change stock balance values, and a map
built for a given patch expects that patch's values.

**What a patch program contains** (read with StormLib, 2026-09-24):
`War3TFT_121b_English.exe` holds an archive with `prepatch.lst` ("extract
BNUpdate.exe / extract Patch.txt / execute BNUpdate"), `mpqs.lst`, the updater,
and a nested archive `Patch_War3x.mpq` (51.5 MB, 722 files). In that nested
archive the changed files are **binary diffs** (each carries a `BSDIFF40`
section) against the previous version, under flat names (`UnitWeapons.slk`,
`UndeadUpgradeFunc~00.txt` where one name appears in several folders), with
`patch.lst` (46 KB, where each file goes), `patch.cmd`, `delete.lst` (which
starts with `War3Patch.mpq`: the patcher deletes and rebuilds that archive)
and `revert.lst`. So a layer can be built without running the patcher:
read `patch.lst`, apply each BSDIFF40 diff to the file from the layer below,
and store the result.

## Intended Behavior

The owner (2026-09-24): "we should be able to dynamically apply and unapply
each patch that might have maps for it. When you load a map, it should 'just
work'."

Nothing on disk is ever patched in place. Each game version is a **layer**,
and loading a map stacks the layers for the version it was made for:

```
 map says: Frozen Throne, made with patch 1.21
      │
      ▼
 chain = war3.mpq  →  war3x.mpq  →  War3xlocal.mpq  →  [patch layer 1.21b]
        (base)        (expansion)                       (only that patch's files)
```

- **A patch layer** is the set of files one Blizzard patch changes, extracted
  once from the patch program's embedded archive (112a) and stored per
  version under the owner's data folder (never in the repository):
  `patch-layers/1.21b/…`. Where a patch ships binary diffs rather than whole
  files, the layer stores the result of applying the diff to the layer below,
  made once by a tool and verified by hash.
- **Applying** a patch = adding its layer to the chain for this map load.
  **Unapplying** = not adding it. The installs and the layers stay pristine,
  the same idea as the wow-chat-2026 patch system, where the upstream tree is
  a disposable artefact and changes are stamped on and peeled off, except that
  here nothing is stamped on at all: the chain is assembled in memory.
- **Choosing the version.** The map's info file (`war3map.w3i`) records its
  format (Reign of Chaos or Frozen Throne) and the editor version that saved
  it; newer maps also record the game version. A table maps editor versions
  to patch versions. A map whose version can't be told gets the newest layer
  and a warning.
- The stock-table readers (112 Route A) read through whichever chain the map
  selected, so a 1.21 map sees 1.21 balance.

## Suggested Implementation Steps

1. Extract the 1.21b patch's archive with 112a's tool; list what it contains (whole files, diffs, scripts).
2. Layer store format and a layer builder per patch program.
3. Map version detection from `war3map.w3i`; the editor-version → patch table as a data file.
4. Chain assembly per map load; report which layers were used.
5. Tests: a Reign of Chaos map and a Frozen Throne map each get the right chain; a stock value known to change between two patches reads differently under each layer.

## Acceptance Criteria

- [ ] The 1.21b layer built from the patch program without running it
- [ ] Loading a map picks its layers automatically and says which
- [ ] No file in either install is modified

## Open Questions

1. Which patches does the owner want layers for? Each needs its patch program (only 1.21b is on this machine).
2. Editor version → patch version: build the table from maps whose patch is known, or from published changelogs?

## Related Documents

- `issues/112-stock-object-tables-by-two-routes.md`, `issues/completed/112a-stormlib-build-and-update-script.md`
- `/home/ritz/games/azeroth-core/wow-chat-2026/docs/patches/patch-registry.md` (the apply/unapply pattern)
- `wc3-installs/README.md`
