# Issue 301a: Parse WTG Header and Categories

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent:** 301-parse-war3map-wtg.md
**Dependencies:** 102-implement-mpq-archive-parser

---

## Current Behavior

No WTG parsing capability exists. The `src/parsers/` directory contains parsers for w3i and wts formats, but cannot read trigger definition files.

---

## Intended Behavior

A parser module that validates the WTG file header and extracts all trigger categories:

**Header validation:**
- Verify magic bytes "WTG!" at offset 0x00
- Extract format version (typically 7 for TFT maps)
- Return error on invalid/unsupported format

**Category extraction:**
- Parse the category count from header
- Extract each category's index, name, and type
- Return structured category array

**Output structure:**
```lua
{
    version = 7,
    categories = {
        { index = 0, name = "Initialization", type = "normal" },
        { index = 1, name = "Combat", type = "normal" },
        { index = 2, name = "// Disabled triggers", type = "comment" },
    },
    -- Cursor position for subsequent parsing
    _offset = <number>,
}
```

---

## Suggested Implementation Steps

1. **Create the parser module file**
   ```
   src/parsers/wtg.lua
   ```

2. **Add required dependencies**
   ```lua
   local compat = require("compat")

   local wtg = {}
   ```

3. **Implement header validation function**
   ```lua
   -- {{{ local function parse_header
   local function parse_header(data, offset)
       offset = offset or 1

       -- Validate magic bytes "WTG!"
       local magic = data:sub(offset, offset + 3)
       if magic ~= "WTG!" then
           return nil, "Invalid WTG file: expected 'WTG!' magic, got '" .. magic .. "'"
       end
       offset = offset + 4

       -- Extract version (int32 little-endian)
       local version = compat.unpack("<I4", data, offset)
       offset = offset + 4

       -- Validate supported version
       if version ~= 4 and version ~= 7 then
           return nil, "Unsupported WTG version: " .. version .. " (expected 4 or 7)"
       end

       return {
           version = version,
           _offset = offset,
       }, nil
   end
   -- }}}
   ```

4. **Implement null-terminated string reader**
   ```lua
   -- {{{ local function read_string
   local function read_string(data, offset)
       local end_pos = data:find("\0", offset, true)
       if not end_pos then
           return nil, offset, "Unterminated string at offset " .. offset
       end
       local str = data:sub(offset, end_pos - 1)
       return str, end_pos + 1, nil
   end
   -- }}}
   ```

5. **Implement category parsing function**
   ```lua
   -- {{{ local function parse_categories
   local function parse_categories(data, offset)
       -- Read category count
       local count = compat.unpack("<I4", data, offset)
       offset = offset + 4

       local categories = {}

       for i = 1, count do
           -- Category index (int32)
           local index = compat.unpack("<I4", data, offset)
           offset = offset + 4

           -- Category name (null-terminated string)
           local name, new_offset, err = read_string(data, offset)
           if err then
               return nil, offset, err
           end
           offset = new_offset

           -- Category type (int32): 0 = normal, 1 = comment
           local cat_type_num = compat.unpack("<I4", data, offset)
           offset = offset + 4

           local cat_type = "normal"
           if cat_type_num == 1 then
               cat_type = "comment"
           end

           categories[#categories + 1] = {
               index = index,
               name = name,
               type = cat_type,
           }
       end

       return categories, offset, nil
   end
   -- }}}
   ```

6. **Create main parse entry point**
   ```lua
   -- {{{ function wtg.parse
   function wtg.parse(data)
       -- Parse header
       local result, err = parse_header(data)
       if err then
           return nil, err
       end

       -- Parse categories
       local categories, offset, cat_err = parse_categories(data, result._offset)
       if cat_err then
           return nil, cat_err
       end

       result.categories = categories
       result._offset = offset

       return result, nil
   end
   -- }}}
   ```

7. **Export internal functions for sub-issue use**
   ```lua
   -- Expose utilities for sibling parsers (301b-301e)
   wtg._read_string = read_string
   wtg._parse_header = parse_header
   wtg._parse_categories = parse_categories

   return wtg
   ```

8. **Create unit test file**
   ```
   src/tests/test_wtg_header.lua
   ```

9. **Implement test with synthetic data**
   ```lua
   -- Create minimal valid WTG data
   local function make_test_wtg()
       local parts = {}
       -- Header
       parts[#parts + 1] = "WTG!"                    -- magic
       parts[#parts + 1] = string.pack("<I4", 7)    -- version
       -- Categories
       parts[#parts + 1] = string.pack("<I4", 2)    -- count
       -- Category 0
       parts[#parts + 1] = string.pack("<I4", 0)    -- index
       parts[#parts + 1] = "Initialization\0"        -- name
       parts[#parts + 1] = string.pack("<I4", 0)    -- type (normal)
       -- Category 1
       parts[#parts + 1] = string.pack("<I4", 1)    -- index
       parts[#parts + 1] = "// Comments\0"           -- name
       parts[#parts + 1] = string.pack("<I4", 1)    -- type (comment)

       return table.concat(parts)
   end
   ```

10. **Test against real WTG file if available**
    - Extract war3map.wtg from test archive using MPQ parser
    - Validate header parsing succeeds
    - Print category names for manual verification

---

## Related Documents

- issues/301-parse-war3map-wtg.md (parent issue)
- issues/301b-parse-wtg-variables.md (next in sequence)
- src/parsers/w3i.lua (reference for parser structure)
- src/compat.lua (provides unpack compatibility)

---

## Acceptance Criteria

- [x] `src/parsers/wtg.lua` exists with header/category parsing
- [x] Magic byte validation returns clear error on invalid files
- [x] Version number correctly extracted (handles both v4 and v7)
- [x] Category count correctly parsed
- [x] Category names correctly extracted (null-terminated strings)
- [x] Category types correctly mapped (0=normal, 1=comment)
- [x] Returns offset position for subsequent parsing (301b)
- [x] Unit test passes with synthetic WTG data
- [x] Parser works on real WTG file from test archive (N/A - test maps are protected)

---

## Notes

This is the entry point for WTG parsing. The `_offset` field in the return value is critical - it tells subsequent parsers (301b variables, 301c triggers) where to continue reading in the file.

The category parsing is straightforward compared to later sub-issues. Categories simply provide organizational structure for triggers in the World Editor UI.

Version 4 is pre-TFT (Reign of Chaos), version 7 is TFT (The Frozen Throne). Most maps in the wild use version 7.

---

## Implementation Notes

*Completed 2025-12-27*

**Files Created:**
- `src/parsers/wtg.lua` - WTG parser module with header and category parsing
- `src/tests/test_wtg_header.lua` - Comprehensive test suite with synthetic data

**Implementation Details:**
- Uses `compat.unpack_uint32()` and `compat.unpack_int32()` for binary parsing
- Exposes internal functions (`_read_string`, `_parse_header`, `_parse_categories`) for use by 301b-301e
- Includes `wtg.format()` for human-readable output
- Returns `_offset` field for subsequent parsers to continue reading

**Test Coverage:**
- 11 tests covering valid parsing, error handling, and edge cases
- Tests both version 4 (RoC) and version 7 (TFT) formats
- Validates magic bytes, version checking, truncation handling
- Synthetic data generators for reliable, repeatable tests

**Note on Real Map Testing:**
All test maps in `assets/` are protected/optimized and do not contain `war3map.wtg` files (triggers are embedded differently in protected maps). The synthetic tests validate parser correctness. A map with visible WTG files would be needed for full integration testing.

**Run tests with:** `luajit src/tests/test_wtg_header.lua`
