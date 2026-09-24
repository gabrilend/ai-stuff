# wc3-installs

Links to the owner's own Warcraft III installs, so tools can find the stock
game archives without hard-coding paths in several places. Nothing from the
installs is copied into the repository. The two links themselves are listed in
`.gitignore`, because their targets exist only on this machine; recreate them
with `ln -s <install folder> wc3-installs/<name>`.

| Link | Points at | Holds |
|------|-----------|-------|
| `reign-of-chaos` | `/mnt/mtwo/games/warcraft-iii/prefix/drive_c/users/ritz/Warcraft-III` | `war3.mpq`: the base game's data, for `.w3m` (Reign of Chaos) maps |
| `frozen-throne` | `/mnt/mtwo/games/warcraft-iii/prefix-tft/drive_c/users/ritz/Warcraft-III` | a separate wine prefix (a copy of the one above, made 2026-09-24) with The Frozen Throne and patch 1.21b installed on top: `war3.mpq`, `war3x.mpq`, `War3xlocal.mpq`, `War3Patch.mpq`, for `.w3x` maps |

Two prefixes keep the Reign of Chaos install exactly as it was, so both data
sets can be read side by side.

Used by the stock-table extraction (issue 112), which reads the stock object
tables that custom maps copy and modify.
