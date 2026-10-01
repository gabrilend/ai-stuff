# Issue 911b: New Maps from Scratch

**Phase:** 9 (editor)
**Type:** Implementation
**Priority:** Critical
**Parent:** 911 (map format and export)
**Dependencies:** 911a (writing maps back), 901 (editor core)

---

## Current Behavior

- **Editing only:** the editor edits maps that exist. Phase 9's goal is to *create* WC3 maps, but nothing makes a new one.
- **Map info:** `war3map.w3i` can only be read.
- **Melee start:** Blizzard.j's `MeleeStartingUnits` is a no-op here, so a melee map starts without units.
- **The lobby:** every one of the twelve player slots plays, whatever the map lists.

## Intended Behavior

### Making a map (`editor/new_map.lua`)

`new_map.create(path, opts)` makes a map from nothing, as the World Editor's New Map does:

- **`war3map.w3i`**, written by the new `w3i.write`:
  - name, author, description;
  - the WE's margins (6, 6, 4, 8) around the playable size, and camera bounds inside it;
  - the melee flag; the tileset;
  - the players (race, human or computer, start locations around a ring) and one force.
- **`war3map.w3e`**: flat ground of the tileset's first texture at cliff level 2, dry, with the edge flagged. The tilesets' ground and cliff textures are those of Lordaeron Summer or Winter, Barrens, Ashenvale or Northrend.
- **`war3map.wpm`**: land inside, closed at the edge.
- **`war3map.shd`**: no shadows.
- **`war3map.doo`**: no doodads.
- **`war3map.j`**, the script:
  - config: name, players, teams, start locations, each slot's race and controller;
  - main: camera bounds, day and night, ambient sounds, music, `InitBlizzard`, and for a melee map Blizzard.j's melee setup;
  - a gold mine by each start (`CreateUnit` and `SetResourceAmount`). As a script unit, the editor shows and moves it.
- **The archive:** a new MPQ, with the 512-byte HM3W header (name, player count) in front.

**Command line:**

```
luajit src/editor/new_map.lua OUT.w3x --name N --size 96 --players human,orc:computer [--tileset L] [--custom]
```

### Changes elsewhere

- **`parsers/w3i.lua`:**
  - `w3i.write` writes back every test map's `war3map.w3i` byte for byte. To do that, the parser now keeps each player's type and race numbers, the raw fixed-start value (a flags number, 3 in DAoW 2.1), which optional sections the file had, and any bytes after them.
- **`jass/natives/bj.lua`:** `MeleeStartingUnits` gives each playing player with a start location its race's town hall and workers, between the hall and the nearest gold mine:
  - human: Town Hall and 5 peasants;
  - orc: Great Hall and 5 peons;
  - undead: Necropolis, 3 acolytes and a ghoul;
  - night elf: Tree of Life and 5 wisps.
- **`jass/vm.lua` (the lobby):** only the slots the map lists play, unless `opts.playing` says otherwise. A two-player map is two players, and the melee AI starts only for its computers. The 16 test maps all list twelve, so they're unchanged.
- **`editor/objects.lua`:** script units owned by `Player(n)` (not only by a variable) are found.

## Acceptance Criteria

- [x] Every test map's `war3map.w3i` written back byte for byte
- [x] A new three-player melee map:
  - [x] header, info, ground, pathing, shadows, doodads and script as asked
  - [x] the game runs its script without errors
  - [x] each race's hall and workers are at their starts, with a gold mine by each
  - [x] the melee AI runs only for the two computer players, and the orc AI has built within forty seconds
- [x] Opened in the editor (the mines as script units), edited (a mine moved, ground raised, a welcome trigger), saved and played as edited
- [x] A custom (not melee) map starts with nothing owned; Northrend's ground
- [x] Made from the command line
- [x] Seen in the window: the new map's town hall, peasants and gold mine under fog of war

## Notes

- **Tests:** `src/tests/test_new_map.lua` (23 tests).
- **No `war3mapUnits.doo`:** this project's `unitsdoo` parser reads a record layout that differs from the TFT one as remembered (gold amount, acquisition range, custom colour). The test maps' only records are start locations whose bodies are all zero, so they can't settle which is right. Rather than write records WC3 might misread, a new map puts its start locations in the w3i and the script, and its mines in the script. Checking the record layout against a map with placed units is left to 911.
- **Food shows 0/0 here:** food values come from the game's own unit tables (`ufoo` / `ufma`), which are read from the owner's install. Without the install (this sandbox), food is 0.
