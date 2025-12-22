# Issue 206g: Finalize Module and Documentation

**Phase:** 2 - Data Model
**Type:** Documentation
**Priority:** Medium
**Dependencies:** 206b, 206c, 206d, 206e, 206f (all class implementations)
**Parent Issue:** 206-design-game-object-types

---

## Current Behavior

After 206a-f, individual classes exist but:
- init.lua may have incomplete exports
- Documentation comments may be missing
- No cross-class consistency verification
- No integration tests

---

## Intended Behavior

A polished, complete gameobjects module with:
- All classes properly exported
- Consistent metatable usage
- Documentation comments on all public APIs
- __tostring on all classes
- Integration tests verifying the module works as a whole

---

## Suggested Implementation Steps

1. **Update init.lua with all exports**
   ```lua
   -- src/gameobjects/init.lua
   -- Game object type system for WC3 map data
   --
   -- Each class wraps parser output with a consistent API:
   --   local obj = Class.new(parsed_data)
   --   obj:method()
   --
   -- Available classes:
   --   Doodad  - Trees, destructibles, decorative objects
   --   Unit    - Units, buildings, heroes, items
   --   Region  - Trigger areas, waygate destinations
   --   Camera  - Cinematic and gameplay cameras
   --   Sound   - Sound definitions and ambient loops

   local Doodad = require("gameobjects.doodad")
   local Unit = require("gameobjects.unit")
   local Region = require("gameobjects.region")
   local Camera = require("gameobjects.camera")
   local Sound = require("gameobjects.sound")

   return {
       Doodad = Doodad,
       Unit = Unit,
       Region = Region,
       Camera = Camera,
       Sound = Sound,
   }
   ```

2. **Verify metatable consistency**
   - All classes use `Class.__index = Class`
   - All classes have `Class.new(parsed)` constructor
   - All classes have `__tostring` metamethod
   - Constructor validation is consistent

3. **Add documentation comments**
   Each public method should have:
   ```lua
   --- Returns the center point of this region.
   -- @return table {x, y} coordinates
   function Region:get_center()
   ```

4. **Create integration test**
   ```lua
   -- src/tests/test_gameobjects.lua
   -- Verify:
   --   - Module loads without error
   --   - All classes are exported
   --   - All classes can be instantiated
   --   - Metatables work correctly
   --   - __tostring works on all classes
   ```

5. **Test with real parser output**
   - Load a test map
   - Parse all data files
   - Create game objects from parsed data
   - Verify no nil errors or type mismatches

6. **Update docs/table-of-contents.md**
   - Add gameobjects module documentation entry

---

## Technical Notes

### Metatable Pattern

All classes should follow this pattern:
```lua
local Class = {}
Class.__index = Class

function Class.new(parsed)
    -- Validate parsed has required fields
    assert(parsed, "parsed data required")
    return setmetatable({...}, Class)
end

function Class:__tostring()
    return string.format("Class<...>", ...)
end

return Class
```

### Type Checking

Consumers can check types via:
```lua
local gameobjects = require("gameobjects")

if getmetatable(obj) == gameobjects.Unit then
    -- It's a unit
end
```

### Documentation Style

Use LuaDoc-compatible comments:
```lua
--- Short description.
-- Longer description if needed.
-- @param name Description of parameter
-- @return Description of return value
function Class:method(name)
```

---

## Related Documents

- issues/206a-206f (predecessor sub-issues)
- issues/206-design-game-object-types.md (parent)
- docs/table-of-contents.md (to be updated)

---

## Acceptance Criteria

- [ ] init.lua exports all 5 classes
- [ ] All classes have consistent metatable pattern
- [ ] All classes have __tostring metamethod
- [ ] All public methods have documentation comments
- [ ] Integration test passes
- [ ] Real parser output test passes
- [ ] docs/table-of-contents.md updated

---

## Notes

This finalization issue ensures the gameobjects module is production-ready
before moving to the registry system (207). Quality checks here prevent
issues downstream.
