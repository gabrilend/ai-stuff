# wc3-installs

Links to the owner's own Warcraft III installs and the patch layers built
from them, so tools can find the stock game data without hard-coding paths in
several places. Nothing from the installs is copied into the repository. The
links themselves are listed in `.gitignore`, because their targets exist only
on this machine; recreate them with `ln -s <folder> wc3-installs/<name>`.

| Link | Points at | Holds |
|------|-----------|-------|
| `reign-of-chaos` | `/mnt/mtwo/games/warcraft-iii/prefix/drive_c/users/ritz/Warcraft-III` | `war3.mpq`: the base game's data |
| `frozen-throne` | `/mnt/mtwo/games/warcraft-iii/prefix-tft/drive_c/users/ritz/Warcraft-III` | a separate wine prefix (a copy of the one above, made 2026-09-24) with The Frozen Throne installed from its disc, unpatched (1.07): `war3.mpq`, `War3x.mpq`, `War3xlocal.mpq` |
| `patch-layers` | `/mnt/mtwo/games/warcraft-iii/patch-layers` | one folder per game patch (e.g. `1.21b/`), built by `src/cli/build-patch-layer.lua` from the patch program without running it; maps pick one per load (`src/gamedata/chain.lua`) |

Two prefixes keep the Reign of Chaos install exactly as it was, so both data
sets can be read side by side. Blizzard's 1.21b patcher crashes under wine,
so the Frozen Throne install stays at 1.07 and the patch lives in a layer
instead; any number of patch versions can sit side by side that way.

Used by the stock-table extraction (issue 112), which reads the stock object
tables that custom maps copy and modify.
