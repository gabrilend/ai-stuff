--[[
editor_versions.lua - which game patch a map's editor version belongs to

A map's war3map.w3i records the World Editor build that last saved it
(e.g. 6052). This table says which patch layer (src/gamedata/patch_layer.lua)
that build shipped with, so a map loads with the stock values it was made
against.

Only entries backed by evidence belong here, each with where the evidence
came from. A map whose editor version isn't listed loads with the newest
layer available and a counted warning (src/gamedata/chain.lua).

Evidence, two routes (issue 112b, 2026-09-24):
  ours   Each layer's WorldEdit.exe holds its own build number as a 4-byte
         constant (it writes it into every map it saves), and not the build
         before it: 6052 is in 1.21b's editor only; 6057 in 1.22a's only;
         6058 in 1.23a's only;
         6059 in 1.24a's and every later one; the disc's (1.07) holds 6031.
         Blizzard's melee maps shipped in the layers agree where they were
         re-saved (the first 6059 map arrives with 1.24b).
  public Hive Workshop's list of official patches: 6052 for 1.19a-1.21b,
         6057 for 1.22, 6058 for 1.23, 6059 for 1.24a-1.28.5, 6060 for
         1.29.x. A cross-check only (see docs/licensing-and-boundaries.md).

Rule (owner, sane design over correctness): a build maps to the newest
layer in its range, the version its authors most likely played.

1.29.2 has no patch program (1.28 on shipped through Blizzard's launcher);
its layer is an install layer built from a 1.29.2 game copy's own archives.
Its World Editor is six times larger and many small constants match by
chance, so the evidence there is a contrast: it holds 6060 and not 6059,
which every editor from 1.24a to 1.27b holds; its game program is
1.29.2.9231.

1.29.2 is the top of the supported range: the last version on MPQ archives
(1.30 moved to Blizzard's CASC storage, still used by the live game) and
before shared-CD-key LAN play stopped (1.31). Issue 112b. 6059's range runs to 1.28.5, inside the
shared-CD-key cutoff (after 1.30.4); 1.27b is the newest built, since 1.28
has no patch program found.

Format:  [editor_version] = { layer = "1.21b", evidence = "how we know" }
]]

return {
    [6052] = { layer = "1.21b",
        evidence = "only 1.21b's WorldEdit.exe holds 6052; the list gives 1.19a-1.21b" },
    [6057] = { layer = "1.22a",
        evidence = "only 1.22a's WorldEdit.exe holds 6057; the list gives 1.22" },
    [6058] = { layer = "1.23a",
        evidence = "only 1.23a's WorldEdit.exe holds 6058; the list gives 1.23" },
    [6059] = { layer = "1.27b",
        evidence = "1.24a-1.27b's WorldEdit.exe hold 6059, none before; the list gives 1.24a-1.28.5; 1.27b is the newest built (1.28.x has no program yet)" },
    [6060] = { layer = "1.29.2",
        evidence = "1.29.2's World Editor.exe holds 6060 and not 6059; its game is 1.29.2.9231; the list gives 1.29.0-1.29.2" },
}
