# Issue 112d: Older Patch Program Shapes (1.01 to 1.20e)

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 112
**Priority:** Medium
**Dependencies:** 112b (the stack of layers)

---

## Current Behavior

The layer builder (`src/gamedata/patch_layer.lua`, `src/cli/build-patch-layer.lua`)
reads patch programs from 1.21a on. The owner (2026-09-24): "hunt down every
patch you can find. The test maps are not the totality of all maps we intend
to support." The older English programs are fetched
(`wc3-installs/patch-sources.tsv`, `scripts/fetch-patch-programs.sh`) and the
stack lists them on every run as "not built, older patch program shapes
(issue 112d)" (`READABLE_FROM` in the builder). Three older shapes were found:

1. **1.19a to 1.20e (Frozen Throne)**: the same outer layout as 1.21a
   (`mpqs.lst` naming `Patch_War3x.mpq`; `patch.lst`, `patch.cmd`; entries with
   the 24-byte header and base CRC32s that match the 1.07 disc), but the diff
   payload is encoded differently. Applying them with the 1.21-era decoder:
   17 of 219 diffs apply, 202 fail with sizes that make no sense. In a small
   one (1.20e's `VoidWalkerMissile.mdx`, 158 bytes), after the 4-byte size and
   one run token, the `BSDIFF40` header and the control block appear **stored
   plainly**: read as 32-bit sign-and-magnitude triples they give
   (922, 0, 804), (14, 0, −777), (40, 0, −27), (6755, 0, −6562), whose adds
   total exactly the new size (7731). The data block after them (mostly
   `0x7F` bytes) is packed by some rule not yet identified; the 1.21-era rule
   (top bit: copy `(b & 0x7F) + 1` bytes, else `b + 1` zeros) and its
   off-by-one variants all fall short of the declared size.
2. **1.14b (Frozen Throne)**: the outer archive holds three nested archives
   (`Patch_War3_Low.mpq`, `Patch_War3_Med.mpq`, `Patch_War3x.mpq`), a
   `prepatch.lst`, `patch.txt` and `BNUpdate.exe`; `mpqs.lst` names more than
   one archive, and the builder reads only its first line.
3. **1.11 and older (both games; Reign of Chaos 1.01 to 1.11 seen)**: the
   outer archive's files have no names in its listfile (`File00000000.exe`,
   `File00000003.mpq` to `File00000005.mpq`, `File00000001.xxx`, …), so the
   nested patch archives must be found by content.

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

1. **1.19a–1.20e diff encoding.** Work out the packing from several small
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

- [ ] 1.19a–1.20e layers build, with the incremental-patch cross-check
- [ ] 1.14b and 1.11 layers build
- [ ] Reign of Chaos layers build
- [ ] The builder reads every fetched program (`READABLE_FROM` gone)

## Related Documents

- `issues/112b-game-version-layers-per-map.md` (the stack; open question 5 lists the sources)
- `src/gamedata/bsd0.lua` (the 1.21-era diff decoder)
- `docs/formats/mpq-archive.md`
