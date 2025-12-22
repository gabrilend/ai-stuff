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

- [ ] Doodad class with constructor
- [ ] is_visible() method
- [ ] is_solid() method
- [ ] get_max_life() method
- [ ] __tostring metamethod
- [ ] Unit tests for Doodad class
- [ ] init.lua exports Doodad

---

## Notes

Doodads are the simplest game object type. Starting here establishes patterns
for the more complex Unit and Region classes.
