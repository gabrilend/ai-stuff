# Issue 112d: Older Patch Program Shapes (1.01 to 1.20e)

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 112
**Priority:** Medium
**Dependencies:** 112b (the stack of layers)

---

## Current Behavior

**In progress.** The layer builder (`src/gamedata/patch_layer.lua`,
`src/cli/build-patch-layer.lua`) reads every fetched patch program, from
Reign of Chaos 1.01b on. The
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
2. **Entry kind 0x00, the oldest diff format: decoded (2026-09-25).** It
   carries every diff in 1.14b, Frozen Throne 1.11 and Reign of Chaos 1.01b to
   1.11. Worked out from known answers: files a 1.14b diff produced that no
   later patch changed are byte-identical in the 1.19a layer (110 such files).
   Built up rule by rule, scoring each guess against all 110:
   - two uint32 lengths, then block A and block B;
   - block A records: a 16-bit word, type in the top two bits, length in the
     low 14. Type 0 inserts literal bytes; type 1 copies from the old file,
     followed by a signed number changing the running offset (old − new);
     type 2 is the same copy adding a constant to every 16-bit word, the
     constant being the last two-byte insert (index lists in models shift:
     `01 00 02 00` → `05 00 06 00` after `04 00`); type 3 writes zeros;
   - block B adds amounts to 16-bit words, in groups by ascending amount: the
     first amount signed, each later increase unsigned, positions as unsigned
     steps from 0, a zero ending each group and the list;
   - numbers: `0xxxxxxx` (7 bits), `10xxxxxx`+1 byte (6 bits + byte × 64),
     `110xxxxx`+2 bytes (5 bits + uint16 × 32), `1110xxxx`+3 bytes (4 bits +
     uint24 × 16); signed ones take the last part as two's complement.
   Result: 104 of 110 exact, and the other six differ only by edits later
   patches made (a fixed "ugpraded" typo, XPFactor 0.10 → 0.15, a hotkey, a
   map size, a value 250 → 300). Every kind 0x00 diff in 1.14b (178 archive
   entries), 1.11 (110) and Reign of Chaos 1.01 (9) and 1.06 (36) decodes to
   its declared size; `src/gamedata/bsd0.lua` (`KIND_DIFF_OLDEST`), with tests.
   **Known gap:** the three program binaries over a megabyte (`War3.exe`,
   `Game.dll`, `WorldEdit.exe`) fail with a copy outside the old file, after
   hundreds of kilobytes that decode sensibly (the number forms check out:
   large offset changes come in exact opposite pairs). Large offsets work some
   way not yet understood, and no later copy of these files exists to check
   against (a rebuilt `War3.exe` should carry a 1.11 version stamp; wrapping
   the copy position around the old file's size doesn't give one). They are
   not game data, so the builder records them as not built, with the reason,
   in the layer's manifest and on screen; any other failure stops the build.
3. **Finding the patch archive in 1.11 and older: done.** The outer
   archive's files have no names in its listfile (`File00000000.exe`,
   `File00000003.mpq` to `File00000005.mpq`, …); the patch is the one inner
   archive holding a non-empty `patch.lst` (`open_patch` in
   `src/gamedata/patch_layer.lua`). Their scripts vary: 1.01b checks
   `FileVersionEqualTo` 1.00 rather than a threshold; incremental patches
   comment their check out; and 1.02's and 1.03's still say "to version
   1.01b" though they make 1.02 (1.0.1.4531) and 1.03 (1.0.3.4653), so names
   are confirmed by the `War3.exe` each writes, not by the script's text. The
   collection's `war3patch101.exe` is the 1.01a → 1.01b incremental, now kept
   with the incrementals.
   **Built:** Reign of Chaos 1.01b, 1.02, 1.03, 1.04, 1.05, 1.06, 1.11 (from the
   1.00 disc), Frozen Throne 1.11 and 1.14b (from 1.07; version from the
   script's threshold, since their `War3.exe` is one of the unbuilt binaries).
   **Editor builds:** 6031 is the 1.07 disc (its newest maps were saved by
   it), and a map saved by it reads the disc with no layer. The builds between
   (6034–6051) and Reign of Chaos's own (4448–4654) have only lower-bound
   evidence (1.11's and 1.14b's melee maps were saved by 6034–6037; the Reign
   of Chaos layers ship no maps), so they aren't listed: such a map stops with
   an error naming its build.
4. **Reign of Chaos 1.18a on: built (2026-09-25).** `Patch_War3.mpq` uses
   kinds 0x01 and 0x04 plus two entries of kind **0x02**: a BSDIFF40 diff
   stored as is after the header, with no size word and no packing
   (`bsd0.KIND_DIFF_UNPACKED`). `build-patch-layer.lua --stack --game roc`
   builds the stack from the Reign of Chaos install (the 1.00 disc,
   `war3.mpq` only) into `wc3-installs/patch-layers-roc`: 1.18a, 1.19a,
   1.20c–e, 1.24a–e, 1.25b, 1.26a, 1.27b, each reporting its game version.
   Their editors hold the same builds as Frozen Throne's of the same era
   (6052 up to 1.20e, 6059 from 1.24a), so `editor_versions.lua` now records
   each build's **range** and the chain picks the newest layer that game's
   stack has in it (Reign of Chaos has no 1.21b: 6052 loads its 1.20e). The
   chain takes `base_archives` for a Reign of Chaos-only install.

**Other languages (checked 2026-09-25).** The German 1.24e program
(`warcraft3collection`, matching its published SHA-512) built on the English
disc gives all 96 of its game-data files (`.slk` tables, `*Func.txt`
profiles) byte-identical to the English 1.24e layer; only text differs (two UI
string files) or can't be built on an English base (42 localized
`*Strings.txt` files, diffed against the German disc's text). So a
foreign-language program could supply a version's balance tables, but not
its English text. It fills no gap yet: the missing Frozen Throne versions
(1.12, 1.13, 1.15–1.18) aren't in these collections in any language; the
Reign of Chaos ones that are (1.12, 1.13 in German, French, Czech) predate
1.18a and use kind 0x00 anyway; Reign of Chaos 1.21a–1.23a exist only as
incrementals, which need a Reign of Chaos 1.21b layer. If a foreign program
is ever used, its layer must say which text it lacks, rather than let the
chain read older English text from below without a word.

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
3. ~~**Kind 0x02**~~ Done: an unpacked BSDIFF40.
4. ~~**Reign of Chaos stack**~~ Done 2026-09-25 from 1.18a (above); 1.01–1.11 wait on kind 0x00.
5. Lower `READABLE_FROM` as each shape is read; editor builds of those
   versions into `src/gamedata/editor_versions.lua` with evidence.

## Acceptance Criteria

- [x] 1.19a–1.20e layers build, with the incremental-patch cross-check
- [x] Kind 0x00 diffs read; 1.14b and 1.11 layers build (three large program binaries per layer left unbuilt, recorded)
- [x] Reign of Chaos layers build, 1.01b to 1.27b
- [x] The builder reads every fetched program
- [ ] The large program binaries in the oldest format (open question 1)
- [ ] First-hand evidence for editor builds 4448–4654 and 6034–6051 (open question 2)

## Open Questions

1. **Large binaries in the oldest format.** How do copy positions work once
   they pass about a megabyte? A decoding is checkable: a rebuilt `War3.exe`
   must carry the version its patch installs. Not game data, so it blocks
   nothing the project reads.
2. **Editor builds 6034–6051 and 4448–4654.** First-hand evidence would come
   from those World Editors (open question 1) or from maps whose patch is
   known.

## Related Documents

- `issues/112b-game-version-layers-per-map.md` (the stack; open question 5 lists the sources)
- `src/gamedata/bsd0.lua` (the 1.21-era diff decoder)
- `docs/formats/mpq-archive.md`
