# Issue 110a: Core Object Data Parser

**Phase:** 1
**Type:** Implementation
**Priority:** Critical
**Parent:** 110-object-data-parsers.md
**Dependencies:** None

---

## Current Behavior

No parser exists for the shared binary format used by w3u, w3t, w3a, etc.

## Intended Behavior

Core module that handles:
- Binary structure parsing (header, tables, objects, modifications)
- Variable type handling (int, real, unreal, string)
- Optional level/column fields for abilities/doodads/upgrades
- Object inheritance (custom objects reference parent)

The core parser is file-type agnostic - specific parsers (w3u, w3a) extend it.

## Suggested Implementation Steps

1. [x] Create `src/parsers/objectdata.lua`
2. [x] Implement header parsing (version check)
3. [x] Implement table parsing (original + custom)
4. [x] Implement object parsing (ID pairs, modifications)
5. [x] Implement modification parsing with variable types
6. [x] Support optional level/column fields
7. [x] Create ObjectDataTable class for results
8. [x] Add tests

## Acceptance Criteria

- [x] Parses version 2 format correctly
- [x] Handles both original and custom tables
- [x] Correctly reads int, real, unreal, string types
- [x] Level/column fields work for extended format
- [x] End marker correctly terminates modifications
- [x] ObjectDataTable provides lookup by ID
- [x] All tests pass

## API Design

```lua
local objectdata = require("parsers.objectdata")

-- Parse raw binary data
local result = objectdata.parse(data, {
    has_level_column = false,  -- true for w3a, w3d, w3q
})

-- Result structure
result.version      -- int (2)
result.original     -- {id -> {id, mods}}
result.custom       -- {new_id -> {original_id, new_id, mods}}

-- Each modification
mod.field_id        -- char[4]
mod.var_type        -- 0-3
mod.level           -- int (if has_level_column)
mod.column          -- int (if has_level_column)
mod.value           -- int/float/string
```

## Related Files

- `src/parsers/objectdata.lua` - Implementation
- `src/tests/test_objectdata.lua` - Tests
- `docs/formats/object-data.md` - Format specification

## Implementation Notes

### Completed (2025-12-31)

Core parser implemented with 23 passing tests:

- Uses `src/compat.lua` for LuaJIT/Lua 5.3+ compatibility
- Helper functions: read_char4, read_int32, read_uint32, read_float, read_string
- id_to_string handles printable and hex IDs
- parse_modification handles all 4 variable types
- parse_object handles both original and custom table entries
- ObjectDataTable class methods:
  - get(id) - Get object by ID
  - has(id) - Check if object exists
  - get_modification(id, field_id, level) - Get specific field value
  - get_all_modifications(id) - Get all mods for object
  - get_parent(id) - Get parent for custom objects
  - is_custom(id) - Check if user-created
  - count() - Get original/custom counts
  - all_ids() - Get sorted ID list
  - format() - Readable output

Test coverage includes:
- Empty files, simple original/custom objects
- All variable types (int, real, unreal, string)
- Level/column parsing for ability format
- Multiple objects, mixed tables
- Error handling (nil, empty, bad version)
