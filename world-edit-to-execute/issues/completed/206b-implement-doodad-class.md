# Issue 206b: Implement Doodad Class

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 206a-create-gameobjects-module-structure, 201-parse-war3map-doo
**Parent Issue:** 206-design-game-object-types

---

## Current Behavior

Doodad parser (src/parsers/doo.lua) returns plain tables. No Doodad class exists
to provide methods or consistent API.

---

## Intended Behavior

A Doodad class that wraps parsed doodad data with:
- Consistent property access
- Type-specific methods (visibility, solidity, life)
- Clear separation of static vs runtime data

```lua
local gameobjects = require("gameobjects")
local doodad = gameobjects.Doodad.new(parsed_doodad)

print(doodad.type_id)        -- "LTlt" (tree type)
print(doodad:is_visible())   -- true
print(doodad:is_solid())     -- true
print(doodad:get_max_life()) -- 100
```

---

## Suggested Implementation Steps

1. **Create Doodad class**
   ```lua
   -- src/gameobjects/doodad.lua
   local Doodad = {}
   Doodad.__index = Doodad

   function Doodad.new(parsed)
       return setmetatable({
           type_id = parsed.id,
           variation = parsed.variation,
           position = {
               x = parsed.position.x,
               y = parsed.position.y,
               z = parsed.position.z,
           },
           angle = parsed.angle,
           scale = {
               x = parsed.scale.x,
               y = parsed.scale.y,
               z = parsed.scale.z,
           },
           flags = parsed.flags,
           life = parsed.life,
           creation_id = parsed.creation_number,
           -- Runtime state (nil until game starts)
           current_life = nil,
           destroyed = false,
       }, Doodad)
   end
   ```

2. **Implement methods**
   ```lua
   function Doodad:is_visible()
       return self.flags >= 1
   end

   function Doodad:is_solid()
       return self.flags >= 2
   end

   function Doodad:get_max_life()
       return self.life
   end
   ```

3. **Add __tostring metamethod**
   ```lua
   function Doodad:__tostring()
       return string.format("Doodad<%s at (%.0f,%.0f)>",
           self.type_id, self.position.x, self.position.y)
   end
   ```

4. **Update init.lua**
   - Uncomment Doodad require
   - Add to exports table

5. **Create tests**
   - Test constructor with mock parsed data
   - Test all methods
   - Test metatable behavior

---

## Technical Notes

### Doodad Flags

From war3map.doo format:
- 0 = invisible, non-solid
- 1 = visible, non-solid
- 2 = visible, solid

### Life Values

- Life is stored as percentage (0-100)
- -1 may indicate default (full life)
- Destructibles have meaningful life; decorations typically 100

### Parser Output Fields

From src/parsers/doo.lua DoodadEntry:
```lua
{
    id = "LTlt",          -- 4-char type ID
    variation = 0,
    position = { x, y, z },
    angle = 0.0,
    scale = { x, y, z },
    flags = 2,
    life = 100,
    creation_number = 1,
    item_table = {...},   -- v8 only
}
```

---

## Related Documents

- issues/201-parse-war3map-doo.md (parser implementation)
- src/parsers/doo.lua (input format)
- issues/206-design-game-object-types.md (parent)

---

## Acceptance Criteria

- [x] Doodad class with constructor
- [x] is_visible() method
- [x] is_solid() method
- [x] get_max_life() method
- [x] __tostring metamethod
- [x] Unit tests for Doodad class
- [x] init.lua exports Doodad

---

## Notes

Doodads are the simplest game object type. Starting here establishes patterns
for the more complex Unit and Region classes.

---

## Implementation Notes

*Completed 2025-12-22*

### Constructor

The Doodad.new() constructor copies all fields from parser output:
- Core: id, name, variation, creation_number
- Position: position {x,y,z}, angle
- Scale: scale {x,y,z}
- Flags: flags (0=invisible_non_solid, 1=visible_non_solid, 2=normal)
- Life: life percentage (0-100)
- V8 fields: item_table_pointer, item_sets_count

Position and scale tables are copied (not referenced) to prevent external mutation.
Missing fields use sensible defaults (position=0,0,0, scale=1,1,1, flags=2, life=100).

### Methods Implemented

| Method | Description |
|--------|-------------|
| `is_visible()` | Returns true if flags >= 1 |
| `is_solid()` | Returns true if flags >= 2 |
| `get_max_life()` | Returns life percentage |
| `get_current_life()` | Returns runtime life (nil before game start) |
| `is_destroyed()` | Returns runtime destroyed state |
| `has_item_drops()` | Checks item_table_pointer >= 0 (v8 only) |
| `get_angle_degrees()` | Converts angle from radians to degrees |

### Runtime State

Two fields are initialized for runtime game state:
- `current_life` - starts nil, set during gameplay
- `destroyed` - starts false, set when doodad destroyed

### __tostring

Shows visibility state in string representation:
- `Doodad<LTlt @ 100,200>` - normal (visible+solid)
- `Doodad<LTlt @ 100,200 [invisible]>` - flags=0
- `Doodad<LTlt @ 100,200 [non-solid]>` - flags=1

### Tests Added

11 new tests added to test_gameobjects.lua (total now 83):
- Constructor copies all fields
- Default values when fields missing
- is_visible() with different flags
- is_solid() with different flags
- get_max_life()
- has_item_drops()
- get_angle_degrees() conversion
- Runtime state fields initialized
- Position table copied (no external mutation)
- __tostring shows visibility state
