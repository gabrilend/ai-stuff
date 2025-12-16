# Issue 106: Design Internal Data Structures

**Phase:** 1 - Foundation
**Type:** Architecture
**Priority:** High
**Dependencies:** 103, 104, 105 (parser outputs inform structure design)

---

## Current Behavior

Each parser returns ad-hoc Lua tables. No unified structure exists for
representing a complete map. Data is fragmented across parser outputs.

---

## Intended Behavior

A unified `Map` data structure that:
- Aggregates all parsed data into a coherent model
- Provides consistent API for accessing map components
- Serves as the foundation for runtime game state
- Is serializable (can be saved/loaded for caching)
- Clearly separates static map data from runtime state

---

## Suggested Implementation Steps

1. **Create data structure module**
   ```
   src/
   ├── mpq/           (archive access)
   ├── parsers/       (file parsers)
   └── data/          (this issue)
       ├── init.lua   (Map class)
       ├── terrain.lua
       ├── player.lua
       └── strings.lua
   ```

2. **Define Map class**
   ```lua
   -- src/data/init.lua
   local Map = {}
   Map.__index = Map

   function Map.new()
       return setmetatable({
           -- Metadata (from w3i)
           name = "",
           author = "",
           description = "",
           suggested_players = "",

           -- Dimensions
           width = 0,
           height = 0,
           playable_area = { x = 0, y = 0, w = 0, h = 0 },

           -- Tileset
           tileset = "",

           -- Components
           terrain = nil,      -- Terrain object
           strings = nil,      -- StringTable object
           players = {},       -- Player definitions
           forces = {},        -- Force definitions

           -- Source
           source_path = "",   -- Original .w3x path
       }, Map)
   end

   function Map.load(w3x_path)
       local map = Map.new()
       map.source_path = w3x_path

       local archive = mpq.open(w3x_path)

       -- Load string table first (others may reference it)
       local wts_data = archive:extract("war3map.wts")
       if wts_data then
           map.strings = StringTable.new(wts_data)
       end

       -- Load map info
       local w3i_data = archive:extract("war3map.w3i")
       local info = w3i_parser.parse(w3i_data)
       map:apply_info(info)

       -- Load terrain
       local w3e_data = archive:extract("war3map.w3e")
       map.terrain = Terrain.new(w3e_parser.parse(w3e_data))

       archive:close()
       return map
   end

   return Map
   ```

3. **Define Terrain class**
   ```lua
   -- src/data/terrain.lua
   local Terrain = {}
   Terrain.__index = Terrain

   function Terrain.new(parsed_data)
       local self = setmetatable({}, Terrain)
       self.width = parsed_data.width
       self.height = parsed_data.height
       self.tiles = parsed_data.tiles
       self.tilesets = parsed_data.ground_tilesets
       self.cliff_tilesets = parsed_data.cliff_tilesets
       return self
   end

   function Terrain:get_tile(x, y)
       if x < 0 or x > self.width or y < 0 or y > self.height then
           return nil
       end
       return self.tiles[y][x]
   end

   function Terrain:get_height(x, y)
       local tile = self:get_tile(x, y)
       return tile and tile.height or 0
   end

   function Terrain:get_height_interpolated(x, y)
       -- Bilinear interpolation for smooth height queries
       -- Used for unit positioning
   end

   function Terrain:is_pathable(x, y)
       local tile = self:get_tile(x, y)
       if not tile then return false end
       return not tile.is_boundary and not tile.has_water
   end

   return Terrain
   ```

4. **Define Player structure**
   ```lua
   -- src/data/player.lua
   local Player = {}
   Player.__index = Player

   function Player.new(data)
       return setmetatable({
           id = data.id,
           name = data.name,
           type = data.type,        -- "human", "computer", "neutral"
           race = data.race,        -- "human", "orc", "undead", "nightelf"
           start_position = {
               x = data.start_x,
               y = data.start_y,
           },
           color = PLAYER_COLORS[data.id],
           allies = data.allies or {},
       }, Player)
   end

   return Player
   ```

5. **Define StringTable wrapper**
   ```lua
   -- src/data/strings.lua
   local StringTable = {}
   StringTable.__index = StringTable

   function StringTable.new(wts_content)
       local self = setmetatable({}, StringTable)
       self.strings = parse_wts(wts_content)
       return self
   end

   function StringTable:get(id)
       return self.strings[id] or ""
   end

   function StringTable:resolve(text)
       if not text then return "" end
       return text:gsub("TRIGSTR_(%d+)", function(id)
           return self:get(tonumber(id))
       end)
   end

   return StringTable
   ```

6. **Add Map convenience methods**
   ```lua
   function Map:get_player(id)
       return self.players[id]
   end

   function Map:get_force(id)
       return self.forces[id]
   end

   function Map:resolve_string(text)
       if self.strings then
           return self.strings:resolve(text)
       end
       return text
   end

   function Map:get_display_name()
       return self:resolve_string(self.name)
   end
   ```

---

## Technical Notes

### Separation of Concerns

The data structures defined here represent **static map data** - the content
as stored in the .w3x file. Runtime state (unit positions, player resources,
game time) will be separate structures defined in Phase 4.

### Coordinate Systems

Establish consistent coordinate conventions:
- **Tile coordinates**: Integer grid positions (0 to width/height)
- **World coordinates**: Float positions (tile * 128.0)
- **Screen coordinates**: Defined later in rendering

```lua
function Map:tile_to_world(tx, ty)
    return tx * 128.0, ty * 128.0
end

function Map:world_to_tile(wx, wy)
    return math.floor(wx / 128.0), math.floor(wy / 128.0)
end
```

### Immutability

Map data should be treated as immutable after loading. If modifications
are needed (e.g., for a map editor), create explicit mutation APIs
rather than allowing direct table manipulation.

---

## Related Documents

- issues/103-parse-war3map-w3i.md (info structure)
- issues/104-parse-war3map-wts.md (string table)
- issues/105-parse-war3map-w3e.md (terrain structure)

---

## Acceptance Criteria

- [x] Map.load() successfully creates Map from any test .w3x
- [x] Terrain queries (get_height, is_pathable) work correctly
- [x] String resolution works via Map:resolve_string()
- [x] Player and Force data accessible via Map methods
- [x] Coordinate conversion functions work correctly
- [x] Documentation comments on all public APIs
- [x] Unit tests for data structure methods

---

## Notes

This issue bridges the "parsing" work and the "using" work. Get the
API right here, as it will be used extensively in later phases.

Consider using Lua's metatables for lazy loading - don't parse terrain
until terrain is actually accessed, for example.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-16 00:22*

## Analysis: Issue 106 - Design Internal Data Structures

This issue is a good candidate for splitting. It contains **4 distinct data structure modules** plus integration/testing work, each with its own file and responsibilities. Splitting allows parallel development once dependencies (103, 104, 105) are met.

---

## Suggested Sub-Issues

### 106a-implement-stringtable-wrapper

**Description:** Implement the StringTable class that wraps parsed WTS data and provides TRIGSTR resolution.

**Scope:**
- Create `src/data/strings.lua`
- StringTable.new() constructor accepting parsed WTS data
- StringTable:get(id) for direct string lookup
- StringTable:resolve(text) for TRIGSTR_xxx substitution
- Unit tests for string resolution

**Dependencies:** 104 (WTS parser must exist to know input format)

---

### 106b-implement-terrain-class

**Description:** Implement the Terrain class that wraps parsed W3E data and provides spatial queries.

**Scope:**
- Create `src/data/terrain.lua`
- Terrain.new() constructor from parsed W3E data
- Terrain:get_tile(x, y) with bounds checking
- Terrain:get_height(x, y) and Terrain:get_height_interpolated(x, y)
- Terrain:is_pathable(x, y) based on tile flags
- Unit tests for terrain queries

**Dependencies:** 105 (W3E parser must exist to know input format)

---

### 106c-implement-player-force-structures

**Description:** Implement Player and Force data structures from parsed W3I player/force definitions.

**Scope:**
- Create `src/data/player.lua`
- Player.new() constructor with id, name, type, race, start_position, color, allies
- Define PLAYER_COLORS constant table
- Force structure (if complex enough to warrant its own class, otherwise a simple table)
- Unit tests for player/force creation

**Dependencies:** 103 (W3I parser defines player/force data shape)

---

### 106d-implement-map-class-and-loader

**Description:** Implement the central Map class that aggregates all components and provides the unified loading API.

**Scope:**
- Create `src/data/init.lua`
- Map.new() constructor with all metadata fields
- Map.load(w3x_path) orchestrating MPQ extraction and component creation
- Map:apply_info() to populate from W3I data
- Map:get_player(), Map:get_force() accessors
- Map:resolve_string(), Map:get_display_name() convenience methods
- Coordinate conversion: Map:tile_to_world(), Map:world_to_tile()
- Lazy loading via metatables (optional optimization)
- Integration tests with real .w3x files

**Dependencies:** 106a, 106b, 106c (all component classes must exist)

---

## Dependency Graph

```
103 (w3i parser) ──┬──→ 106c (player/force)
                   │
104 (wts parser) ──┼──→ 106a (stringtable)
                   │                         ╲
105 (w3e parser) ──┴──→ 106b (terrain)    ───→ 106d (map + loader)
                                             ╱
                   MPQ module (existing) ────╯
```

---

## Summary

| Sub-Issue | Name | Est. Complexity | Can Parallelize With |
|-----------|------|-----------------|---------------------|
| 106a | implement-stringtable-wrapper | Small | 106b, 106c |
| 106b | implement-terrain-class | Medium | 106a, 106c |
| 106c | implement-player-force-structures | Small | 106a, 106b |
| 106d | implement-map-class-and-loader | Medium | None (depends on a,b,c) |

**Recommendation:** Split this issue. The component classes (106a, 106b, 106c) can be developed in parallel once their parser dependencies are complete, and 106d serves as the integration point. This separation also makes testing cleaner—each component can be unit tested in isolation before integration testing in 106d.

---

## Implementation Notes

*Completed 2025-12-16*

### What Was Built

Created `src/data/init.lua` - unified Map class that aggregates all parsed components:

```lua
local data = require("data")
local map = data.load("path/to/map.w3x")

-- Metadata access:
map:get_display_name()        -- Resolved map name
map:get_display_author()      -- Resolved author
map.width, map.height         -- Map dimensions
map.tileset                   -- Tileset name

-- Component access:
map.terrain                   -- Terrain object (from w3e parser)
map.strings                   -- StringTable object (from wts parser)
map.players                   -- Player definitions (from w3i parser)
map.forces                    -- Force definitions (from w3i parser)

-- Convenience methods:
map:get_player(num)           -- Get player by number
map:get_height(x, y)          -- Terrain height at tile
map:is_walkable(x, y)         -- Pathability check
map:tile_to_world(tx, ty)     -- Coordinate conversion
map:info()                    -- Summary table
map:terrain_stats()           -- Terrain statistics

-- Formatting:
print(data.format(map))
```

### Design Notes

Rather than creating separate wrapper classes for components that already exist
in the parsers (Terrain in w3e, StringTable in wts), the Map class directly
uses the parser outputs. This avoids duplication while providing a unified API.

### Features

- **Lazy-safe loading**: Each file extraction is wrapped in pcall
- **TRIGSTR resolution**: Automatic string resolution for metadata
- **Player colors**: PLAYER_COLORS table with all 16 player colors
- **Round-trip coordinates**: tile_to_world/world_to_tile work correctly

### Test Results

- **16/16 test maps** load successfully
- All accessor methods work correctly
- TRIGSTR resolution verified

### Files Created

- `src/data/init.lua` - Map class and loader
- `src/tests/test_data.lua` - Comprehensive test suite
