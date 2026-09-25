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
         before it: 6052 is in 1.21b's editor only; 6058 in 1.23a's only;
         6059 in 1.24a's and every later one; the disc's (1.07) holds 6031.
         Blizzard's melee maps shipped in the layers agree where they were
         re-saved (the first 6059 map arrives with 1.24b).
  public Hive Workshop's list of official patches: 6052 for 1.19a-1.21b,
         6057 for 1.22, 6058 for 1.23, 6059 for 1.24a-1.28.5, 6060 for
         1.29.x. A cross-check only (see docs/licensing-and-boundaries.md).

Rule (owner, sane design over correctness): a build maps to the newest
layer in its range, the version its authors most likely played.

Not listed yet: 6057 (1.22) and 6060 (1.29.x) have no patch program found;
see issue 112b open question 5. 6059's newest layer depends on the
shared-CD-key cutoff (open question 4); 1.27b is the newest built.

Format:  [editor_version] = { layer = "1.21b", evidence = "how we know" }
]]

return {
    [6052] = { layer = "1.21b",
        evidence = "only 1.21b's WorldEdit.exe holds 6052; the list gives 1.19a-1.21b" },
    [6058] = { layer = "1.23a",
        evidence = "only 1.23a's WorldEdit.exe holds 6058; the list gives 1.23" },
    [6059] = { layer = "1.27b",
        evidence = "1.24a-1.27b's WorldEdit.exe hold 6059, none before; the list gives 1.24a-1.28.5; 1.27b is the newest built (cutoff open)" },
}
