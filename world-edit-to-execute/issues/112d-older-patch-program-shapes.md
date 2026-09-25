# Issue 112d: Older Patch Program Shapes (1.01 to 1.20e)

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 112
**Priority:** Medium
**Dependencies:** 112b (the stack of layers)

---

## Current Behavior

**In progress.** The layer builder (`src/gamedata/patch_layer.lua`,
`src/cli/build-patch-layer.lua`) reads patch programs from **1.19a** on. The
owner (2026-09-24): "hunt down every patch you can find. The test maps are
not the totality of all maps we intend to support." The older English
programs are fetched (`wc3-installs/patch-sources.tsv`,
`scripts/fetch-patch-programs.sh`) and the stack lists the unreadable ones on
every run as "not built, older patch program shapes (issue 112d)"
(`READABLE_FROM` in the builder).

1. **1.19a to 1.20e: read (2026-09-25).** The same outer layout as 1.21a;
   the diffs' run-length code counts runs from 32 instead of 1 (a copy token
   gives `(b & 0x7F) + 32` bytes, a zero token `b + 32` zeros). Found by
   lining up the same file's diff in 1.20e and 1.21a (both diff the same
   base to the same result, so bsdiff's output is the same and only the
   packing differs): in 1.20e's `iconindex_def.txt`, the token before
   `BSDIFF40` is `0x98` and the literal run is 56 bytes (24 + 32); the zero
   runs fell short by exactly 31 per token. Confirmed on all 218 of 1.20e's
   archive diffs: each rebuilds exactly the file 1.21a's does.
   `src/gamedata/bsd0.lua` takes the step (`RUN_STEP_1_20`, `RUN_STEP_1_21`);
   `patch_layer.lua` chooses it from the build number in the program's
   `patch.cmd` threshold (below 6263, 1.21a's). That threshold turned out to
   be "don't patch this version or later", not always the version made (1.20d
   says 1.0.20.6069 and makes 1.20.3.6070), so the builder checks the version
   made is at or above it. Layers 1.19a, 1.20b, 1.20c, 1.20d, 1.20e build;
   each game program reports its version (1.0.19.6041 … 1.20.4.6074). Their
   editors hold 6052, which stays mapped to 1.21b, its newest version.
   **Cross-check** (`src/tests/test_patch_layers.lua`): the incremental patches
   1.20d→1.20e, 1.20e→1.21a (across the step change) and 1.21a→1.21b, applied
   to the lower layer, write exactly the files of the higher layer; they are
   fetched to `patch-programs/incremental/`, which the stack doesn't build.
2. **Entry kind 0x00: the older diff format (1.01 to 1.14b).** Found
   2026-09-25. 1.14b's `mpqs.lst` names only `Patch_War3x.mpq` (the Low/Med
   archives beside it hold six files and no `patch.lst`); of its 372 entries,
   117 are whole files (kind 0x01) and 253 have kind **0x00**, a diff format
   that is not bsdiff. The same kind carries every diff in Frozen Throne 1.11
   and Reign of Chaos 1.01 to 1.06. What is known:
   - the 24-byte header is the same (old CRC32 and size, new size, time);
   - two uint32 lengths follow, and after them two blocks of exactly those
     lengths (1.14b's `Custom_V0\Units\HumanUnitFunc.txt`: 211 + 7 bytes;
     `CampaignUnitFunc.txt`: 1961 + 164);
   - the first block is a series of records: a few control bytes, a uint16
     length, then that many literal bytes (`HumanUnitFunc.txt` inserts
     `Revive=1` and three `ScoreScreenIcon=…scorescreen-hero-a/m/p` lines;
     control bytes `0c 41 00`, `cb 41 76`, `0d 40 b9 f8 23 54 83 06`,
     `11 40 95 fc 50 43 a3 02`, `0c 40 9a fc eb 4c a3 02`), so it reads like
     copy-from-old-and-insert, with the copy lengths and offsets packed in
     the control bytes (and perhaps the second block) in a way not yet worked
     out. Anchors to test against: in the 1.07 base, `[Hamg]` starts at byte
     270, `[Hmkg]` at 5645, `[Hpal]` at 6498; old 10035 bytes, new 10252.
   - No second copy of 1.14b's files exists to compare with, but text files
     make a decoding checkable: it must give readable text of the new size.
     Reign of Chaos 1.01 to 1.06 may be easier to check, if another source of
     their files turns up. No public description of the format was found.
3. **Finding the patch archive in 1.11 and older.** The outer archive's files
   have no names in its listfile (`File00000000.exe`, `File00000003.mpq` to
   `File00000005.mpq`, …). The patch is the one inner archive holding a
   `patch.lst` with entries (`File00000003.mpq` in Frozen Throne 1.11 and
   Reign of Chaos 1.01 and 1.06); the two small ones beside it hold none. So
   this shape is solved by content once kind 0x00 is read.
4. **Reign of Chaos 1.18a on** (`Patch_War3.mpq`) uses kinds 0x01 and 0x04,
   readable now, plus two entries of kind **0x02**, not yet identified. Its
   stack needs the builder to work on the Reign of Chaos install
   (`war3.mpq` only), with its layers kept apart from Frozen Throne's.

Not yet fetched, because no English program was found: Frozen Throne 1.10,
1.12, 1.13, 1.15–1.18; Reign of Chaos 1.02a, 1.12, 1.13, 1.14b, 1.21a–1.23a
(some exist only as `.bin`/`.zip` or in other languages in the same
collection). Reign of Chaos layers also need the builder to work on the Reign
of Chaos install.

## Intended Behavior

Every fetched program builds a layer, in version order, with the same
guarantees as 1.21a on: every base checked by size and CRC32, every diff
applied or the build stops naming it, a second run changes nothing.

## Suggested Implementation Steps

1. ~~**1.19a–1.20e diff encoding.**~~ Done 2026-09-25 (above). Work out the packing from several small
   entries (the plain control blocks give exact targets: adds + copies = new
   size, data and extra block sizes from the header). Blizzard's patcher of
   that era (`File00000000.exe` / `BNUpdate.exe` in the programs) holds the
   decoder if the format can't be inferred. Test with the 1.20d → 1.20e
   incremental patch: applied to the 1.20d layer it must reproduce the 1.20e
   layer.
2. **Kind 0x00 diffs** (1.01–1.14b): work out the record encoding from the
   text-file entries (known inserts, known base, known new size); then
   1.14b builds, and 1.11 and older once their patch archive is found by
   content (the inner archive with a non-empty `patch.lst`).
3. **Kind 0x02** (two entries in Reign of Chaos 1.18a–1.20e): identify.
4. **Reign of Chaos stack**: layers for `.w3m` maps, built on the Reign of
   Chaos install (`wc3-installs/reign-of-chaos`), named apart from the Frozen
   Throne layers.
5. Lower `READABLE_FROM` as each shape is read; editor builds of those
   versions into `src/gamedata/editor_versions.lua` with evidence.

## Acceptance Criteria

- [x] 1.19a–1.20e layers build, with the incremental-patch cross-check
- [ ] Kind 0x00 diffs read; 1.14b and 1.11 layers build
- [ ] Reign of Chaos layers build
- [ ] The builder reads every fetched program (`READABLE_FROM` gone)

## Related Documents

- `issues/112b-game-version-layers-per-map.md` (the stack; open question 5 lists the sources)
- `src/gamedata/bsd0.lua` (the 1.21-era diff decoder)
- `docs/formats/mpq-archive.md`
