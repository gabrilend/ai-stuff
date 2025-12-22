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

- [x] Directory src/gameobjects/ created
- [x] init.lua with commented-out requires
- [x] Placeholder files for all 5 classes
- [x] Module loads without error
- [x] Basic test verifies module structure

---

## Notes

This is the foundation issue - must be completed before 206b-206f can proceed.
Keep implementation minimal; the goal is structure, not functionality.

---

## Implementation Notes

*Completed 2025-12-21*

### Files Created

```
src/gameobjects/
├── init.lua       # Module exports (requires all 5 classes)
├── doodad.lua     # Doodad class with placeholder methods
├── unit.lua       # Unit class with placeholder methods
├── region.lua     # Region class with placeholder methods
├── camera.lua     # Camera class with placeholder methods
└── sound.lua      # Sound class with placeholder methods

src/tests/
└── test_gameobjects.lua   # Module structure tests
```

### Design Decisions

1. **Active requires instead of commented-out:** Init.lua requires all classes
   immediately rather than using commented placeholders. This ensures the module
   is testable from the start and any load errors surface immediately.

2. **Functional placeholders:** Each class has working new() constructors and
   placeholder methods that return sensible defaults. This allows dependent code
   to be written before full implementations are complete.

3. **__tostring metamethods:** All classes include __tostring for debugging,
   making it easier to inspect objects during development.

### Test Results

34/34 tests pass - validates module structure and basic class instantiation.
