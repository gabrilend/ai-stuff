# Issue 206a: Create Gameobjects Module Structure

**Phase:** 2 - Data Model
**Type:** Architecture
**Priority:** High
**Dependencies:** None
**Parent Issue:** 206-design-game-object-types

---

## Current Behavior

No gameobjects module exists. Each parser returns plain tables with no unified type system.

---

## Intended Behavior

Create the foundational module structure for game object types:

```
src/gameobjects/
├── init.lua       (module exports)
├── doodad.lua     (placeholder)
├── unit.lua       (placeholder)
├── region.lua     (placeholder)
├── camera.lua     (placeholder)
└── sound.lua      (placeholder)
```

The init.lua should establish the export pattern that will be populated as each
class is implemented in subsequent sub-issues.

---

## Suggested Implementation Steps

1. **Create directory structure**
   ```bash
   mkdir -p src/gameobjects
   ```

2. **Create init.lua with export pattern**
   ```lua
   -- src/gameobjects/init.lua
   -- Game object type system
   -- Each class wraps parser output in a consistent API

   -- Classes will be required as they are implemented
   -- local Doodad = require("gameobjects.doodad")
   -- local Unit = require("gameobjects.unit")
   -- local Region = require("gameobjects.region")
   -- local Camera = require("gameobjects.camera")
   -- local Sound = require("gameobjects.sound")

   return {
       -- Doodad = Doodad,
       -- Unit = Unit,
       -- Region = Region,
       -- Camera = Camera,
       -- Sound = Sound,
   }
   ```

3. **Create placeholder files for each class**
   - Each file should have a comment header explaining its purpose
   - Include the basic metatable structure as a template
   - Leave implementation to respective sub-issues

4. **Add basic test file**
   - Verify module loads without errors
   - Verify exported table structure

---

## Technical Notes

### Module Pattern

Using require-based module pattern for consistency with existing codebase:
- `local mod = require("gameobjects")` loads the module
- `mod.Unit`, `mod.Doodad`, etc. access individual classes
- Classes use metatables for method dispatch

### Placeholder Pattern

Placeholders should be minimal but valid:
```lua
-- src/gameobjects/doodad.lua
-- Doodad class: Trees, destructibles, decorative objects
-- Implementation: 206b-implement-doodad-class

local Doodad = {}
Doodad.__index = Doodad

-- TODO: Implement in 206b

return Doodad
```

---

## Related Documents

- issues/206-design-game-object-types.md (parent)
- src/data/init.lua (similar module pattern)

---

## Acceptance Criteria

- [ ] Directory src/gameobjects/ created
- [ ] init.lua with commented-out requires
- [ ] Placeholder files for all 5 classes
- [ ] Module loads without error
- [ ] Basic test verifies module structure

---

## Notes

This is the foundation issue - must be completed before 206b-206f can proceed.
Keep implementation minimal; the goal is structure, not functionality.
