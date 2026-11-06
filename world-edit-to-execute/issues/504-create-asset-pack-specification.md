# Issue 504: Create Asset Pack Specification

**Phase:** 5 - Rendering
**Type:** Design/Architecture
**Priority:** Medium
**Dependencies:** 516 (the model chooser)
**Re-cut:** 2026-09-26, from "Create Asset Pack Specification"

---

## Current Behavior

No format exists for a player's replacement art. The January plan was an
asset pack: a manifest mapping WC3 content ids to community files, stacked
as fallbacks. Since then (2026-09-26): a unit draws the model its map asks
for, a player may override any model path with a model of their own, seen
only on their machine, and overrides are made through the game's UI, not
yet planned; until then the chooser reads them from a data file (516).

## Intended Behavior

The format of that override data file, written down: which model path is
replaced, by which file (stored by hash, 604), with what scale, tint and
team-colour handling, and whether for every map or one. The UI (506) writes
it; the chooser (516) reads it; a player can pass a set of overrides to
another over rmail (609). "Asset pack" becomes this: a shareable set of
overrides.

## Suggested Implementation Steps

1. The file's fields and types, in this issue and in a `.info.md` beside
   its reader.
2. A reader used by 516's chooser, with tests.

## Acceptance Criteria

- [x] The override file's format is written down with every field's type (2026-11-06: below, and `src/assets/overrides.info.md`)
- [ ] 516's chooser reads it, and a test override replaces a model path
- [x] A set of overrides can be passed as one file (2026-11-06: one plain text file; `overrides.merge` takes a received set in)

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

No asset loading system exists. All visuals would need to be hardcoded or use primitive placeholders. There's no way for the community to supply visual content.

---

### Intended Behavior

Asset pack specification that:
- Defines manifest format for community asset packs
- Specifies how assets map to WC3 content IDs
- Supports multiple resolution variants
- Enables asset pack stacking (fallback chains)
- Documents requirements for asset creators

**Core Concept:** Like emulator "ROM packs" or game mod systems - community creates visual packs that the engine loads, separate from game logic.

**Manifest Example:**
```lua
-- asset_pack/manifest.lua
return {
    name = "Community Classic",
    version = "1.0.0",
    author = "Community Contributors",
    description = "WC3-inspired placeholder art",

    -- Asset mappings
    units = {
        ["hfoo"] = {  -- Human Footman
            sprite = "units/human/footman.png",
            icon = "icons/human/footman.png",
            size = {64, 64},
            animations = {
                idle = {frames = 4, fps = 8},
                walk = {frames = 8, fps = 12},
                attack = {frames = 6, fps = 15},
            },
        },
        -- More units...
    },

    terrain = {
        ["Ldrt"] = "terrain/dirt.png",
        ["Lgrs"] = "terrain/grass.png",
        -- More tiles...
    },

    ui = {
        command_panel = "ui/command_panel.png",
        minimap_frame = "ui/minimap_frame.png",
        -- More UI elements...
    },
}
```

---

### Suggested Implementation Steps

1. **Design manifest schema**
   - Required fields vs optional
   - Version compatibility rules
   - Validation requirements

2. **Define asset categories**
   - Units (sprites, animations, icons)
   - Buildings (sprites, construction stages)
   - Terrain (tiles, transitions)
   - Effects (particles, projectiles)
   - UI (frames, buttons, fonts)
   - Audio (sounds, music) - future

3. **Create asset loader module**
   ```lua
   -- src/render/assets.lua
   local assets = {}

   function assets.load_pack(path) end
   function assets.get_unit_sprite(unit_id) end
   function assets.get_terrain_tile(tile_id) end
   function assets.set_pack_priority(pack_name, priority) end
   ```

4. **Implement fallback system**
   - Pack priority ordering
   - Missing asset → next pack → placeholder
   - Logging for missing assets

5. **Document asset creation guide**
   - Required formats (PNG, etc.)
   - Size/resolution requirements
   - Animation frame layout
   - Naming conventions

---

### Design Questions for User

1. **Manifest format?**
   - Lua table (easy for modders)
   - JSON (standard, tooling support)
   - YAML (human readable)
   - Custom format

2. **Asset resolution?**
   - Single resolution (simpler)
   - Multiple variants (@1x, @2x)
   - Dynamic scaling

3. **Pack structure?**
   - Flat (all files in directories)
   - Archive (zip/custom format)
   - Hybrid (development vs release)

4. **Copyright handling?**
   - How to clearly document legal status
   - Metadata for attribution
   - License field in manifest

---

### Acceptance Criteria

- Manifest schema documented
- Asset loader can read manifests
- Fallback chain works correctly
- Missing assets log warnings
- At least one example pack created
- Asset creation guide written

---

### Notes

This is critical for the project's legal strategy - community supplies visuals, we supply the engine. The specification must be clear enough for contributors to create compatible packs.

**May need successor issues for:**
- Asset validation tool
- Pack creation wizard/tool
- Hot-reload during development
- Compressed pack format

---

### Sub-Issue Analysis

**Analysis Date:** 2025-12-29

#### Recommendation: Keep as Single Issue

This issue does not benefit from splitting. While it has multiple steps, they are tightly coupled:

1. **Documentation-driven**: The manifest schema design (step 1) drives everything else
2. **Linear dependency**: Asset loader (step 3) requires schema (step 1) and categories (step 2)
3. **Small code scope**: The actual code (loader + fallback) is relatively straightforward
4. **Coherent deliverable**: A spec without example packs or docs is incomplete

**Alternative structure if scope grows:**

If implementation reveals complexity, consider:
- 504a: Design manifest schema and document categories
- 504b: Implement asset loader and fallback system
- 504c: Create example pack and asset creation guide

For now, keep as single issue and split only if implementation exceeds expected scope.

---

### Related Documents

- notes/vision (legal philosophy)
- issues/503-*.md (placeholder system this replaces)
- Phase 6 issues (asset system expansion)

---

## Decisions (2026-11-06)

Made without the owner; each one theirs to overturn.

1. **The file is plain text, read line by line, never run.** The project's
   other settings files are Lua that returns a table (`config/player-data.lua`,
   the layer manifests), but a set of overrides is meant to pass between
   players (609), and loading someone else's Lua runs their code. So the
   form is a header line (`wete-overrides 1`), an optional `name` line, and
   one tab-separated `override` line each: the model path, the file's hash,
   then `key=value` options. Comments start with `#`.
2. **The replacing file is named by its hash** (`sha256:` and 64 lower-case
   hex digits) in the player's store (604, `assets/dedup.lua`), as the
   issue says, not by a path on one machine: the same set means the same
   models on every machine that has those blobs.
3. **The options:** `scale=N` (above 0, multiplied with the unit's own
   scale), `tint=R,G,B` (0-255, multiplied with the unit's own tint),
   `team_colour=on|off` (whether the replacement's team-colour textures
   take the owner's colour; on by default), `map=HASH` (only on the map
   whose file has that hash; every map by default). Each at most once;
   defaults are left out when written.
4. **Every map or one: the file holds both.** 516 left that choice to the
   override screen; the format allows either, so the screen can offer
   both. On one map, that map's override wins over one for every map.
5. **Paths match as the game's do:** whatever their case, slash direction,
   leading slash or extension (`.mdx`, `.mdl` or none).
6. **A file is all right or refused whole**, every problem listed with its
   line number. The same path twice for the same scope is refused naming
   both lines. A missing file is no overrides; a broken one is an error, as
   `player_data` treats a broken config file: the player meant something.
7. **The player's own set lives at `<player data>/overrides.txt`**
   (`assets/player_data.lua`, from #79's branch). It is saved whole and
   renamed into place.
8. **Received sets are merged in priority order, the first winning**, with
   every conflict (two sets naming different files for one path and scope)
   listed, as asset packs are ordered in 601's loader.
9. **516's stand-in chooser is built with it**, in `assets/chooser.lua`:
   the override (read from the store), then the model the map requests,
   then a placeholder; each path chosen once; uses counted by source, and
   every placeholder and failed override kept with its reason. It takes the
   map's model through a function (such as `A:model`), so W03's resolver
   can replace it whole.
10. **Stacked on #79** (the 601 loader, on #66 and #30): it uses
    `player_data.lua` and `dedup.lua`, which only that chain has.

## What happened (2026-11-06)

- `src/assets/overrides.lua` (with its `.info.md`): `parse`, `write`,
  `load`, `save`, `file_for`, `merge`, `key`; a set's `add`, `remove`,
  `lookup`, `count`.
- `src/assets/chooser.lua` (with its `.info.md`): `new`, `choose`,
  `counts`, `placeholders`, `failed_overrides`, `report`, `clear`.
- `src/tests/test_overrides.lua` (110 checks, with its `.info.md`): the
  file read, refused line by line and written back the same; scopes;
  adding, removing, merging; the player's file on disk; the chooser over a
  real store in a scratch folder.
- Mutation check: `overrides.lua` 212 mutants, 197 caught; `chooser.lua`
  55, 54 caught. The 16 left are equivalent: `return nil` for
  `return false` where callers only test for truth (11), an emptied entry
  set to `false` instead of `nil` (1), and number formatting that gives
  the same text either way (4).

## Left (needs raylib, or the screen)

- 516's chooser is not yet what the window calls: `A:model_for`
  (`src/assets/init.lua`) would hand its path to `chooser:choose`, with
  `A:model` as `requested`, and the window would use the look (scale,
  tint, team colour). That changes the map viewer and waits on raylib.
- The override screen (506) that writes the file.

