# Issue 301b: Parse WTG Variables

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent:** 301-parse-war3map-wtg.md
**Dependencies:** 301a-parse-wtg-header-categories

---

## Current Behavior

After 301a completes, the WTG parser can read header and categories but stops before the variable definitions section. User-defined globals (udg_* variables) cannot be extracted.

---

## Intended Behavior

Extend the WTG parser to extract all variable definitions from the variables section:

**Variable properties to extract:**
- Variable name (with `udg_` prefix in runtime)
- Variable type (unit, integer, real, string, etc.)
- Is array flag
- Array size (if array)
- Is initialized flag
- Initial value string (if initialized)

**Output structure addition:**
```lua
{
    -- ... header and categories from 301a ...
    variables = {
        {
            name = "Hero",           -- becomes udg_Hero at runtime
            type = "unit",
            is_array = false,
            array_size = 0,
            is_initialized = false,
            initial_value = nil,
        },
        {
            name = "SpawnPoints",
            type = "location",
            is_array = true,
            array_size = 10,
            is_initialized = false,
            initial_value = nil,
        },
        {
            name = "DifficultyLevel",
            type = "integer",
            is_array = false,
            array_size = 0,
            is_initialized = true,
            initial_value = "1",
        },
    },
    _offset = <number>,  -- updated for 301c
}
```

---

## Suggested Implementation Steps

1. **Read the existing wtg.lua module**
   - Understand the current structure from 301a
   - Locate where variable parsing should be inserted

2. **Add variable parsing function**
   ```lua
   -- {{{ local function parse_variables
   local function parse_variables(data, offset)
       -- Read variable count
       local count = compat.unpack("<I4", data, offset)
       offset = offset + 4

       local variables = {}

       for i = 1, count do
           local var = {}

           -- Variable name (null-terminated)
           var.name, offset = read_string(data, offset)

           -- Variable type (null-terminated)
           var.type, offset = read_string(data, offset)

           -- Unknown field (always 1?)
           local unknown = compat.unpack("<I4", data, offset)
           offset = offset + 4

           -- Is array (int32: 0 or 1)
           var.is_array = compat.unpack("<I4", data, offset) == 1
           offset = offset + 4

           -- Array size (int32, only meaningful if is_array)
           if var.is_array then
               var.array_size = compat.unpack("<I4", data, offset)
           else
               var.array_size = 0
               -- Still need to skip the field
           end
           offset = offset + 4

           -- Is initialized (int32: 0 or 1)
           var.is_initialized = compat.unpack("<I4", data, offset) == 1
           offset = offset + 4

           -- Initial value (null-terminated, only present if initialized)
           if var.is_initialized then
               var.initial_value, offset = read_string(data, offset)
           else
               var.initial_value = nil
           end

           variables[#variables + 1] = var
       end

       return variables, offset, nil
   end
   -- }}}
   ```

3. **Integrate into main parse function**
   ```lua
   function wtg.parse(data)
       -- ... existing header parsing ...
       -- ... existing category parsing ...

       -- Parse variables
       local variables, offset, var_err = parse_variables(data, result._offset)
       if var_err then
           return nil, var_err
       end

       result.variables = variables
       result._offset = offset

       return result, nil
   end
   ```

4. **Handle variable type mapping**
   Common WC3 variable types to expect:
   ```lua
   -- Type string examples:
   -- "unit"       - Unit reference
   -- "integer"    - 32-bit integer
   -- "real"       - Floating point
   -- "string"     - Text string
   -- "boolean"    - True/false
   -- "location"   - Point on map
   -- "rect"       - Region rectangle
   -- "group"      - Unit group
   -- "timer"      - Timer handle
   -- "trigger"    - Trigger reference
   -- "player"     - Player reference
   -- "force"      - Force (player group)
   -- "effect"     - Special effect
   -- "sound"      - Sound handle
   ```

5. **Add error handling for malformed data**
   ```lua
   -- Validate we haven't overrun the buffer
   if offset > #data then
       return nil, offset, "Unexpected end of data while parsing variables"
   end
   ```

6. **Create unit test additions**
   ```
   src/tests/test_wtg_variables.lua
   ```

7. **Test with synthetic variable section**
   ```lua
   local function make_test_variables()
       local parts = {}
       -- Variable count
       parts[#parts + 1] = string.pack("<I4", 2)

       -- Variable 1: simple integer
       parts[#parts + 1] = "Counter\0"           -- name
       parts[#parts + 1] = "integer\0"           -- type
       parts[#parts + 1] = string.pack("<I4", 1) -- unknown
       parts[#parts + 1] = string.pack("<I4", 0) -- is_array
       parts[#parts + 1] = string.pack("<I4", 0) -- array_size
       parts[#parts + 1] = string.pack("<I4", 1) -- is_initialized
       parts[#parts + 1] = "0\0"                 -- initial_value

       -- Variable 2: unit array
       parts[#parts + 1] = "Enemies\0"           -- name
       parts[#parts + 1] = "unit\0"              -- type
       parts[#parts + 1] = string.pack("<I4", 1) -- unknown
       parts[#parts + 1] = string.pack("<I4", 1) -- is_array
       parts[#parts + 1] = string.pack("<I4", 20)-- array_size
       parts[#parts + 1] = string.pack("<I4", 0) -- is_initialized

       return table.concat(parts)
   end
   ```

8. **Verify parsing continues to correct offset**
   - After variable parsing, offset should point to trigger count
   - Test that subsequent parsing (301c) works correctly

---

## Related Documents

- issues/301-parse-war3map-wtg.md (parent issue)
- issues/301a-parse-wtg-header-categories.md (prerequisite)
- issues/301c-parse-wtg-trigger-metadata.md (next in sequence)
- src/parsers/wtg.lua (implementation location)

---

## Acceptance Criteria

- [x] Variable count correctly parsed
- [x] Variable names extracted (null-terminated strings)
- [x] Variable types extracted (null-terminated strings)
- [x] is_array flag correctly interpreted (0=false, 1=true)
- [x] array_size correctly parsed for array variables
- [x] is_initialized flag correctly interpreted
- [x] initial_value extracted only when is_initialized=true
- [x] Returns updated offset for 301c trigger parsing
- [x] Unit test passes with synthetic variable data
- [x] Parser handles 0 variables (empty section)
- [x] Works on real WTG file from test archive (N/A - test maps are protected)

---

## Notes

The `udg_` prefix is NOT stored in the WTG file - it's added at runtime by the JASS compiler. A variable named "Hero" in the editor becomes `udg_Hero` in JASS code.

The "unknown" field after the type string appears to always be 1 in observed files. Its purpose is unclear - possibly a version marker or reserved field. We read and discard it.

Initial values are stored as strings regardless of type:
- Integer "5" → stored as "5\0"
- Real "3.14" → stored as "3.14\0"
- Boolean true → stored as "true\0"

Array variables without initialization have uninitialized elements (null/0 depending on type).

---

## Implementation Notes

*Completed 2025-12-27*

**Files Modified:**
- `src/parsers/wtg.lua` - Added `parse_variables()` function and integrated into main parse flow

**Files Created:**
- `src/tests/test_wtg_variables.lua` - 9 tests covering variable parsing

**Implementation Details:**
- Added `parse_variables()` function that parses variable count, then iterates through each variable
- Variable structure: name (string), type (string), unknown (int32), is_array (bool), array_size (int32), is_initialized (bool), initial_value (string if initialized)
- The unknown field (always 1) is read and discarded per format documentation
- Initial values are only present in the file when `is_initialized=1`
- Updated `wtg.format()` to display variables with array notation and initial values
- Exposed `wtg._parse_variables` and `wtg.VARIABLE_TYPES` for testing and future use
- Updated 301a test data generators to include variable count (0) for backwards compatibility

**Test Coverage:**
- Empty variables (0 count)
- Multiple variables with different configurations
- All common variable types (unit, integer, real, string, boolean, location, rect, group, timer)
- Initialized variables with string-encoded values
- Array variables with various sizes

**Run tests with:** `luajit src/tests/test_wtg_variables.lua`
