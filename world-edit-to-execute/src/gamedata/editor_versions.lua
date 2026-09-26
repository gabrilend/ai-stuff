--[[
editor_versions.lua - which game patch a map's editor version belongs to

A map's war3map.w3i records the World Editor build that last saved it
(e.g. 6052). This table says which patch layer (src/gamedata/patch_layer.lua)
that build shipped with, so a map loads with the stock values it was made
against.

Only entries backed by evidence belong here, each with where the evidence
came from. A map whose editor version isn't listed is refused with an error
that says what to fetch (src/gamedata/chain.lua, choose_layer); the chain
never guesses a layer. (This comment said "newest layer and a counted
warning" until 2026-09-26; the code had already moved to the error.)

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
layer in its range, the version its authors most likely played. Each entry
records the range (from, to); the chain picks the newest layer the game's
stack has inside it (the Reign of Chaos stack, for one, has no 1.21b), and a
range with no built layer is an error.

1.29.2 has no patch program (1.28 on shipped through Blizzard's launcher);
its layer is an install layer built from a 1.29.2 game copy's own archives.
1.28.5 and 1.29.1 likewise, from game copies (Hive Workshop's file packs).
These World Editors are larger and many small constants match by chance, so
the evidence there is a contrast: 1.28.5's holds 6059 (like 1.24a-1.27b);
1.29.1's and 1.29.2's hold 6060 and not 6059.

1.29.2 is the top of the supported range: the last version on MPQ archives
(1.30 moved to Blizzard's CASC storage, still used by the live game) and
before shared-CD-key LAN play stopped (1.31). Issue 112b. 6059's range runs to 1.28.5, inside the
shared-CD-key cutoff (after 1.30.4); 1.27b is the newest built, since 1.28
has no patch program found.

Format:  [editor_version] = { from = "1.19a", to = "1.21b", evidence = "how we know" }
]]

return {
    [6031] = { from = "1.07", to = "1.07",
        evidence = "the Frozen Throne disc's newest maps were saved by 6031 (52 by 6030, 9 by 6031); the list gives 1.07" },
    [6052] = { from = "1.19a", to = "1.21b",
        evidence = "1.19a-1.21b's WorldEdit.exe hold 6052, none after; the list gives 1.19a-1.21b" },
    [6057] = { from = "1.22a", to = "1.22a",
        evidence = "only 1.22a's WorldEdit.exe holds 6057; the list gives 1.22" },
    [6058] = { from = "1.23a", to = "1.23a",
        evidence = "only 1.23a's WorldEdit.exe holds 6058; the list gives 1.23" },
    [6059] = { from = "1.24a", to = "1.28.5",
        evidence = "1.24a-1.27b's WorldEdit.exe and 1.28.5's World Editor.exe hold 6059, none before and neither 1.29 editor; the list gives 1.24a-1.28.5, and 1.28.5 is its newest" },
    [6060] = { from = "1.29.0", to = "1.29.2",
        evidence = "1.29.1's and 1.29.2's World Editor.exe hold 6060 and not 6059; 1.29.2 (game 1.29.2.9231) is the newest; the list gives 1.29.0-1.29.2" },
}
