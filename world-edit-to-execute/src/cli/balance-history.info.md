# balance-history.lua

Reads the stock tables of every built version of both games and records
every number that ever changed. Run through `scripts/balance-history.sh`.

| Function | Takes | Gives |
|----------|-------|-------|
| `build(games)` | optional set of game keys (`{tft = true}`); all when omitted | `{games = {key = {title, versions, objects}}}`: `versions` is a list of version names, the disc first; `objects[id] = {kind ("unit"/"ability"/"item"/"upgrade"), name (string or nil; borrowed text), fields = {["Table.column"] = list of numbers per version, nil where absent}}` |
| `write(history, folder)` | the result of `build`; a folder | writes `folder/history.js` (`window.HISTORY = {...}`, JSON with control characters as `\u` escapes) |

Command line: `luajit src/cli/balance-history.lua [--dir DIR] <output folder>`.

Reads the **melee** tables (the ones balance patches change) through
`src/gamedata/chain.lua`: the disc with no layer, then each layer. Tables:
`UnitBalance`, `UnitWeapons`, `AbilityData`, `ItemData`, `UpgradeData`.
Names from the newest version's `*Strings.txt`. Only numeric fields whose
value changes between versions they appear in are kept.
