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
| `patch-programs` | `/mnt/mtwo/games/warcraft-iii/patch-programs` | Blizzard's patch programs, one per version, gathered by `scripts/fetch-patch-programs.sh` from the public mirrors listed in `patch-sources.tsv` (tracked); for 1.29.2, which has no patch program, a `1.29.2/` folder with that version's data archives and programs kept from a game copy; `sources.tsv` inside records each file's checksum, mirror and fetch date |
| `external-notes` | `/mnt/mtwo/games/warcraft-iii/external-notes` | patch notes from Liquipedia's Warcraft III wiki (CC BY-SA 3.0) for the versions the project doesn't read, fetched once by `src/cli/patch-notes-fetch.lua`; `sources.tsv` records each page and when; kept apart from the project's data and never committed |
| `external-values` | `/mnt/mtwo/games/warcraft-iii/external-values` | Liquipedia's unit, building, spell and item pages (CC BY-SA 3.0) for Route B's cross-check, fetched once by `src/cli/route-b-fetch.lua` (today's revisions, and the revisions as they stood under 1.29.2 where they differ); used only to check, never committed |
| `patch-layers-roc` | `/mnt/mtwo/games/warcraft-iii/patch-layers-roc` | the Reign of Chaos stack, built from `reign-of-chaos` (the 1.00 disc) by `build-patch-layer.lua --stack --game roc`; read by the chain with `war3.mpq` as the only base archive |
| `patch-layers` | `/mnt/mtwo/games/warcraft-iii/patch-layers` | one folder per game patch (e.g. `1.21b/`), built by `src/cli/build-patch-layer.lua` from the patch program without running it; maps pick one per load (`src/gamedata/chain.lua`) |

Two prefixes keep the Reign of Chaos install exactly as it was, so both data
sets can be read side by side. Blizzard's 1.21b patcher crashes under wine,
so the Frozen Throne install stays at 1.07 and the patch lives in a layer
instead; any number of patch versions can sit side by side that way.

Used by the stock-table extraction (issue 112), which reads the stock object
tables that custom maps copy and modify.
