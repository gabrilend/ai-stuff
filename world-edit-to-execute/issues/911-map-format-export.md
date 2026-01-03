# Issue 911: Map Format and Export

**Phase:** 9
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 901 (Editor core), Phase 1 (Parsers)

---

## Current Behavior

Maps can be parsed (loaded) but not saved. No unified format exists that supports both WC3 and WoW gameplay modes.

## Intended Behavior

A unified map format that:
1. Stores all data for both WC3 and WoW gameplay modes
2. Exports to standard WC3 format (.w3x/.w3m) for compatibility
3. Exports to our enhanced format for full features
4. Handles mode-specific data gracefully

### Dual-Mode Philosophy

```
UNIFIED MAP FORMAT (.wex)
┌────────────────────────────────────────────────────────────────────┐
│                         SHARED DATA                                │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Terrain, Objects, Regions, Cameras, Sounds, Triggers        │  │
│  │ (Data used by both WC3 and WoW modes)                        │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│           ┌──────────────────┼──────────────────┐                  │
│           │                  │                  │                  │
│           ▼                  │                  ▼                  │
│  ┌─────────────────┐         │         ┌─────────────────┐        │
│  │   WC3 LAYER    │         │         │   WOW LAYER    │        │
│  │                 │         │         │                 │        │
│  │ - Hero system   │   SEAMLESS        │ - Classes       │        │
│  │ - RTS commands  │   SWITCH          │ - Professions   │        │
│  │ - Build queues  │    (F5)           │ - Quest log     │        │
│  │ - Unit control  │         │         │ - Gear stats    │        │
│  └─────────────────┘         │         └─────────────────┘        │
│                              │                                      │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
                    ▼                     ▼
           ┌─────────────────┐   ┌─────────────────┐
           │  EXPORT: .w3x   │   │  EXPORT: .wex   │
           │  (WC3 compat)   │   │  (Full format)  │
           └─────────────────┘   └─────────────────┘
```

### Unified Format Structure

```
map.wex (ZIP-based archive)
├── manifest.lua           # Map metadata, version, features
├── terrain/
│   ├── heightmap.bin      # Terrain heights
│   ├── textures.bin       # Tile textures
│   ├── cliffs.bin         # Cliff data
│   └── water.bin          # Water levels
├── objects/
│   ├── units.lua          # Unit placements
│   ├── doodads.lua        # Doodad placements
│   ├── items.lua          # Item placements
│   └── regions.lua        # Region definitions
├── definitions/
│   ├── units.lua          # Custom unit stats (w3u equivalent)
│   ├── abilities.lua      # Custom abilities (w3a equivalent)
│   ├── items.lua          # Custom items (w3t equivalent)
│   └── ...
├── scripts/
│   ├── triggers/          # Trigger scripts
│   │   ├── init.lua
│   │   ├── combat.lua
│   │   └── ...
│   └── ai/               # AI scripts
├── assets/
│   ├── models/
│   ├── textures/
│   └── sounds/
├── wc3/                   # WC3-specific data
│   ├── forces.lua         # Player forces
│   ├── techtree.lua       # Tech requirements
│   └── upgrades.lua       # Research data
└── wow/                   # WoW-specific data
    ├── quests.lua         # Quest definitions
    ├── npcs.lua           # NPC dialogue/vendors
    └── instances.lua      # Dungeon/raid data
```

### Export Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| **Unified** | .wex | Full format, both modes |
| **WC3** | .w3x/.w3m | Standard WC3 compatible |
| **WoW Server** | .wowmap | Server asset package |
| **Lightweight** | .wexl | No embedded assets |

### WC3 Export Mapping

```
UNIFIED (.wex)              WC3 (.w3x MPQ)
─────────────────────────────────────────────────
manifest.lua          →    war3map.w3i
terrain/heightmap     →    war3map.w3e
terrain/textures      →    war3map.w3e
objects/units.lua     →    war3mapUnits.doo
objects/doodads.lua   →    war3map.doo
objects/regions.lua   →    war3map.w3r
definitions/units     →    war3map.w3u
definitions/abilities →    war3map.w3a
scripts/triggers/     →    war3map.wtg + war3map.wct + war3map.j
wc3/forces.lua        →    war3map.w3i (forces section)
assets/*              →    war3mapImported/*
```

### API Design

```lua
local mapfile = require("editor.mapfile")

-- LOAD --

-- Load unified format
local map = mapfile.load("my_map.wex")

-- Load WC3 format (auto-convert to unified)
local map = mapfile.load("old_map.w3x")

-- SAVE --

-- Save as unified format
mapfile.save(map, "my_map.wex")

-- Export to WC3 format
mapfile.export_wc3(map, "my_map.w3x", {
    version = "1.31",  -- Target WC3 version
    strip_wow_data = true,  -- Remove WoW-only data
})

-- Export lightweight (no assets, for version control)
mapfile.export_lightweight(map, "my_map.wexl")

-- QUERIES --

-- Get map info
local info = map:info()
-- { name, author, description, size, modes = {"wc3", "wow"} }

-- Check what modes the map supports
local has_wc3 = map:supports_mode("wc3")
local has_wow = map:supports_mode("wow")

-- Get mode-specific data
local wc3_data = map:get_mode_data("wc3")
local wow_data = map:get_mode_data("wow")

-- VALIDATION --

-- Validate for export
local errors = mapfile.validate_for_export(map, "wc3")
-- Returns list of incompatibilities

-- Fix common issues
mapfile.fix_export_issues(map, "wc3")
```

### Mode-Specific Data Handling

```lua
-- When exporting to WC3, WoW-only data is:
-- 1. Stripped (not included in export)
-- 2. Stored in map metadata (for re-import)

-- When exporting to WoW server, WC3-only data is:
-- 1. Converted where possible (RTS commands → abilities)
-- 2. Stripped where incompatible

-- DATA OVERLAP
-- Some data exists in both modes with different meaning:
--
-- SHARED (identical):
--   - Terrain
--   - Doodads
--   - Regions
--   - Basic units
--
-- PARALLEL (different representation):
--   - Unit stats: WC3 (simple) ↔ WoW (detailed)
--   - Abilities: WC3 (JASS) ↔ WoW (spell database)
--   - Items: WC3 (ability-based) ↔ WoW (stat-based)
--
-- MODE-EXCLUSIVE:
--   - WC3: Build queues, tech tree, forces, upkeep
--   - WoW: Quests, professions, instances, raids
```

### Validation Warnings

```
EXPORT VALIDATION: WC3
┌────────────────────────────────────────────────────────────┐
│ ⚠ WARNING: Map uses WoW-only features                     │
│                                                            │
│ The following will be stripped from WC3 export:           │
│   - 3 quests                                              │
│   - 2 profession trainers                                 │
│   - 1 dungeon entrance                                    │
│                                                            │
│ The following will be converted:                          │
│   - 15 WoW-style abilities → WC3 abilities                │
│   - 8 item stats → simplified WC3 items                   │
│                                                            │
│ ✓ No errors - map is exportable                          │
│                                                            │
│ [Export Anyway] [Review Changes] [Cancel]                 │
└────────────────────────────────────────────────────────────┘
```

## Suggested Implementation Steps

1. Create `src/editor/mapfile/` module structure
2. Define unified format specification
3. Implement manifest parser/writer
4. Implement terrain serialization
5. Implement object serialization
6. Implement definition serialization
7. Implement script serialization
8. Implement asset packaging
9. Implement WC3 export (unified → w3x)
10. Implement WC3 import (w3x → unified)
11. Implement lightweight export
12. Implement validation system
13. Implement mode-specific data handling
14. Create comprehensive tests

## Acceptance Criteria

- [ ] Unified format saves all map data
- [ ] Unified format loads correctly
- [ ] WC3 export produces valid .w3x files
- [ ] WC3 import converts to unified format
- [ ] Round-trip (load → save → load) preserves data
- [ ] Mode-specific data handled correctly
- [ ] Validation reports export issues
- [ ] Lightweight export excludes assets
- [ ] Format is version-controlled friendly
- [ ] Large maps save in reasonable time

## Related Documents

- Phase 1 - All file parsers
- `docs/formats/` - Format specifications
- Issue 110 - Object data parsers

## Notes

- Consider compression for terrain data (LZ4, zstd)
- Lua-based data files are human-readable and diff-friendly
- Binary formats for terrain (performance)
- May want "map template" for new map creation
- Consider checksums for asset integrity
- Format version important for future compatibility
- May want "map optimization" (strip unused assets)
