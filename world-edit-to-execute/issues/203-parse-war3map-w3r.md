# Issue 203: Parse war3map.w3r (Regions)

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 102-implement-mpq-archive-parser

---

## Current Behavior

Cannot read region definitions. Trigger regions, waygate destinations, and
ambient sound zones are inaccessible for scripting and gameplay.

---

## Intended Behavior

A parser that extracts all region definitions from war3map.w3r:
- Region names and IDs
- Bounding boxes (left, right, bottom, top)
- Weather effect assignments
- Ambient sound assignments
- Editor display colors

---

## Suggested Implementation Steps

1. **Create parser module**
   ```
   src/parsers/
   └── w3r.lua          (this issue)
   ```

2. **Implement header parsing**
   ```lua
   -- war3map.w3r header structure:
   -- Offset  Type      Description
   -- 0x00    int32     File version (5 for TFT)
   -- 0x04    int32     Number of regions
   ```

3. **Implement region entry parsing**
   ```lua
   -- Each region entry (variable size):
   -- float:   Left boundary
   -- float:   Bottom boundary
   -- float:   Right boundary
   -- float:   Top boundary
   -- string:  Region name (null-terminated)
   -- int32:   Creation number (unique editor ID)
   -- char[4]: Weather effect ID (0 = none)
   -- string:  Ambient sound name (null-terminated, references w3s)
   -- byte:    Red color component (editor display)
   -- byte:    Green color component
   -- byte:    Blue color component
   -- byte:    Alpha (usually 0xFF)
   ```

4. **Return structured data**
   ```lua
   return {
       version = 5,
       regions = {
           {
               name = "gg_rct_Start_Area",
               creation_number = 0,
               bounds = {
                   left = -512.0,
                   bottom = -512.0,
                   right = 512.0,
                   top = 512.0,
               },
               weather = nil,          -- or "RAhr" for Ashenvale Rain
               ambient_sound = nil,    -- or "gg_snd_RainLoop"
               color = { r = 0, g = 0, b = 255, a = 255 },
           },
           -- ...
       },
   }
   ```

5. **Add region lookup by creation number**
   ```lua
   -- Build index for waygate lookups
   local regions_by_id = {}
   for _, region in ipairs(regions) do
       regions_by_id[region.creation_number] = region
   end
   ```

---

## Technical Notes

### Weather Effect IDs

Common weather effect codes:
```lua
local WEATHER_EFFECTS = {
    ["RAhr"] = "ashenvale_rain_heavy",
    ["RAlr"] = "ashenvale_rain_light",
    ["MEds"] = "dungeon_mist_blue",
    ["FDbh"] = "dungeon_fog_heavy_brown",
    ["FDbl"] = "dungeon_fog_light_brown",
    ["SNbs"] = "northrend_blizzard",
    ["SNhs"] = "northrend_snow_heavy",
    ["SNls"] = "northrend_snow_light",
    -- ... more
}
```

### Region Naming Convention

Editor-generated regions follow pattern: `gg_rct_<name>`
- `gg_rct_` prefix is standard
- Name part comes from World Editor region name

### Usage in Triggers

Regions are referenced by:
- Trigger conditions (unit enters/leaves region)
- Waygate destinations (creation_number matches)
- Weather/sound zones
- Spawn points

### Coordinate System

Region bounds use world coordinates:
- Values in game units (1/128 of terrain tile)
- Origin at map center
- Bounds define axis-aligned rectangle

---

## Related Documents

- docs/formats/w3r-regions.md (to be created)
- issues/102-implement-mpq-archive-parser.md (provides file access)
- issues/202-parse-war3map-units-doo.md (waygates reference regions)
- issues/205-parse-war3map-w3s.md (ambient sounds reference w3s)

---

## Acceptance Criteria

- [ ] Can parse war3map.w3r from all test archives
- [ ] Correctly extracts region names
- [ ] Correctly extracts bounding boxes
- [ ] Correctly extracts weather effects
- [ ] Correctly extracts ambient sound references
- [ ] Correctly extracts editor colors
- [ ] Provides lookup by creation number
- [ ] Returns structured Lua table
- [ ] Unit tests for parser

---

## Notes

Regions are a simpler format compared to doodads/units. They're primarily
used for trigger scripting (detecting unit positions) and ambient effects.

The creation_number field is important for waygate functionality - a
waygate's destination references the creation_number of its target region.

Reference: [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
Reference: [HiveWE Wiki](https://github.com/stijnherfst/HiveWE/wiki/war3map.w3r-Regions)
