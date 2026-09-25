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
2. **1.14b (Frozen Throne)**: the outer archive holds three nested archives
   (`Patch_War3_Low.mpq`, `Patch_War3_Med.mpq`, `Patch_War3x.mpq`), a
   `prepatch.lst`, `patch.txt` and `BNUpdate.exe`; `mpqs.lst` names more than
   one archive, and the builder reads only its first line. Not read yet.
3. **1.11 and older (both games; Reign of Chaos 1.01 to 1.11 seen)**: the
   outer archive's files have no names in its listfile (`File00000000.exe`,
   `File00000003.mpq` to `File00000005.mpq`, `File00000001.xxx`, …), so the
   nested patch archives must be found by content. Not read yet.

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
2. **1.14b's several nested archives**: read every archive `mpqs.lst` names;
   find which targets each serves (`prepatch.lst`, `patch.txt`).
3. **Unnamed inner files (1.11 and older)**: identify the nested archives by
   opening each `File…mpq` and looking for `patch.lst`.
4. **Reign of Chaos stack**: layers for `.w3m` maps, built on the Reign of
   Chaos install (`wc3-installs/reign-of-chaos`), named apart from the Frozen
   Throne layers.
5. Lower `READABLE_FROM` as each shape is read; editor builds of those
   versions into `src/gamedata/editor_versions.lua` with evidence.

## Acceptance Criteria

- [x] 1.19a–1.20e layers build, with the incremental-patch cross-check
- [ ] 1.14b and 1.11 layers build
- [ ] Reign of Chaos layers build
- [ ] The builder reads every fetched program (`READABLE_FROM` gone)

## Related Documents

- `issues/112b-game-version-layers-per-map.md` (the stack; open question 5 lists the sources)
- `src/gamedata/bsd0.lua` (the 1.21-era diff decoder)
- `docs/formats/mpq-archive.md`
