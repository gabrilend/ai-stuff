# Issue 207a: Core Registry Class

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** High
**Dependencies:** 206-design-game-object-types
**Parent Issue:** 207-build-object-registry-system

---

## Current Behavior

No centralized system for storing and accessing game objects. Each parser
returns arrays of objects with no unified lookup mechanism.

---

## Intended Behavior

Implement the base ObjectRegistry class with storage tables, registration
methods, and basic lookup methods.

```lua
local ObjectRegistry = require("registry")

local registry = ObjectRegistry.new()

-- Register objects
registry:add_doodad(doodad)
registry:add_unit(unit)
registry:add_region(region)
registry:add_camera(camera)
registry:add_sound(sound)

-- Lookup by creation ID (cross-type)
local obj = registry:get_by_creation_id(1234)

-- Lookup by name (for named objects)
local cam = registry:get_by_name("Camera 001")

-- Get counts
print(registry.counts.units)  -- number of units
```

---

## Suggested Implementation Steps

1. **Create registry module structure**
   ```
   src/registry/
   └── init.lua     (ObjectRegistry class)
   ```

2. **Implement ObjectRegistry.new() constructor**
   - Storage tables for each type: doodads, units, regions, cameras, sounds
   - Cross-type index: by_creation_id
   - Named object index: by_name
   - Statistics: counts table

3. **Implement add_* methods**
   - add_doodad(doodad)
   - add_unit(unit)
   - add_region(region)
   - add_camera(camera)
   - add_sound(sound)

   Each method should:
   - Insert into type-specific array
   - Increment count
   - Index by creation_id if present
   - Index by name if present

4. **Implement lookup methods**
   - get_by_creation_id(id) - returns object or nil
   - get_by_name(name) - returns object or nil

5. **Add basic tests**
   - Test object registration
   - Test lookup by creation_id
   - Test lookup by name
   - Test counts

---

## Technical Notes

### Creation ID Scope

Creation IDs are unique within their own file, but we store them in a
unified cross-type index. If there's a collision (doodad and unit with
same creation_id), the later registration wins. This is acceptable because
triggers typically know the object type they're looking for.

### Storage Strategy

Use arrays for iteration (ipairs-compatible) and hash tables for lookup.
Objects are stored by reference, not copied.

---

## Related Documents

- issues/207-build-object-registry-system.md (parent)
- issues/206-design-game-object-types.md (object types)

---

## Acceptance Criteria

- [x] ObjectRegistry.new() creates empty registry
- [x] add_doodad stores doodad and updates indexes
- [x] add_unit stores unit and updates indexes
- [x] add_region stores region and updates indexes
- [x] add_camera stores camera and updates indexes
- [x] add_sound stores sound and updates indexes
- [x] get_by_creation_id returns correct object
- [x] get_by_name returns correct object
- [x] counts accurately track object numbers
- [x] Unit tests for basic operations

---

## Notes

This is the foundation for all registry functionality. Keep the API simple
and focused on storage/retrieval. Filtering and spatial queries come in
later sub-issues.

---

## Implementation Notes

*Completed 2025-12-21*

### Changes Made

1. **Created registry module structure:**
   ```
   src/registry/
   └── init.lua     (ObjectRegistry class)
   ```

2. **Implemented ObjectRegistry class with:**
   - Type-specific storage arrays: doodads, units, regions, cameras, sounds
   - Cross-type index: by_creation_id (supports both creation_id and creation_number)
   - Named object index: by_name (skips empty names)
   - Counts tracking per type
   - get_total_count() convenience method
   - __tostring metamethod for debugging

3. **Collision handling:**
   - creation_id collisions: later registration wins in index, both remain in arrays
   - name collisions: same behavior (later wins in index)
   - This matches the note in Technical Notes about acceptable collision behavior

4. **Parser output compatibility:**
   - Supports both creation_id and creation_number fields (parsers use creation_number)

### Test Results

48/48 tests pass covering:
- Empty registry creation
- All 5 add_* methods
- Both lookup methods (creation_id and name)
- Collision handling
- Edge cases (empty name, unknown lookups)
