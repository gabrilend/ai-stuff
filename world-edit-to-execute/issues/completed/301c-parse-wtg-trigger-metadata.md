# Issue 301c: Parse WTG Trigger Metadata

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent:** 301-parse-war3map-wtg.md
**Dependencies:** 301a-parse-wtg-header-categories

---

## Current Behavior

After 301a and 301b complete, the WTG parser can read header, categories, and variables, but cannot extract trigger definitions. The trigger metadata (names, flags, category assignments) remains inaccessible.

---

## Intended Behavior

Extend the WTG parser to extract trigger metadata for all triggers, excluding the ECA (Event/Condition/Action) content which is handled by 301d:

**Trigger metadata to extract:**
- Trigger name
- Trigger description (editor comment)
- Is comment flag (disabled trigger category)
- Is enabled flag
- Is custom text flag (uses JASS instead of GUI)
- Is initially on flag
- Run on map init flag
- Category index (links to parsed categories)
- ECA function count (for 301d to process)

**Output structure addition:**
```lua
{
    -- ... header, categories, variables from 301a/301b ...
    triggers = {
        {
            name = "Melee Initialization",
            description = "Standard melee game setup",
            is_comment = false,
            is_enabled = true,
            is_custom_text = false,
            is_initially_on = true,
            run_on_init = true,
            category_index = 0,
            eca_count = 5,
            -- events, conditions, actions populated by 301d
            events = {},
            conditions = {},
            actions = {},
        },
        {
            name = "Hero Respawn",
            description = "",
            is_comment = false,
            is_enabled = true,
            is_custom_text = false,
            is_initially_on = true,
            run_on_init = false,
            category_index = 1,
            eca_count = 8,
            events = {},
            conditions = {},
            actions = {},
        },
    },
    _trigger_eca_offsets = { <offset1>, <offset2>, ... },  -- for 301d
    _offset = <number>,
}
```

---

## Suggested Implementation Steps

1. **Read the existing wtg.lua module**
   - Understand structure from 301a/301b
   - Locate where trigger parsing should be inserted

2. **Add trigger metadata parsing function**
   ```lua
   -- {{{ local function parse_trigger_metadata
   local function parse_trigger_metadata(data, offset)
       -- Read trigger count
       local count = compat.unpack("<I4", data, offset)
       offset = offset + 4

       local triggers = {}
       local eca_offsets = {}

       for i = 1, count do
           local trigger = {}

           -- Trigger name (null-terminated)
           trigger.name, offset = read_string(data, offset)

           -- Trigger description (null-terminated)
           trigger.description, offset = read_string(data, offset)

           -- Is comment trigger (int32: 0 or 1)
           trigger.is_comment = compat.unpack("<I4", data, offset) == 1
           offset = offset + 4

           -- Is enabled (int32: 0 or 1)
           trigger.is_enabled = compat.unpack("<I4", data, offset) == 1
           offset = offset + 4

           -- Is custom text (int32: 0 or 1)
           trigger.is_custom_text = compat.unpack("<I4", data, offset) == 1
           offset = offset + 4

           -- Is initially on (int32: 0 or 1)
           trigger.is_initially_on = compat.unpack("<I4", data, offset) == 1
           offset = offset + 4

           -- Run on map init (int32: 0 or 1)
           trigger.run_on_init = compat.unpack("<I4", data, offset) == 1
           offset = offset + 4

           -- Category index (int32)
           trigger.category_index = compat.unpack("<I4", data, offset)
           offset = offset + 4

           -- ECA count (int32) - number of top-level ECA functions
           trigger.eca_count = compat.unpack("<I4", data, offset)
           offset = offset + 4

           -- Record where ECA data starts for this trigger
           eca_offsets[#eca_offsets + 1] = offset

           -- Initialize empty ECA arrays (populated by 301d)
           trigger.events = {}
           trigger.conditions = {}
           trigger.actions = {}

           -- Skip ECA data for now - 301d will parse it
           -- We need to walk through to find the end
           offset = skip_eca_section(data, offset, trigger.eca_count)

           triggers[#triggers + 1] = trigger
       end

       return triggers, eca_offsets, offset, nil
   end
   -- }}}
   ```

3. **Implement ECA section skipper**
   This is a simplified version that counts bytes to skip, not full parsing:
   ```lua
   -- {{{ local function skip_eca_section
   local function skip_eca_section(data, offset, count)
       -- Skip 'count' ECA functions
       -- Each ECA has recursive structure - must walk through
       for i = 1, count do
           offset = skip_single_eca(data, offset)
       end
       return offset
   end
   -- }}}

   -- {{{ local function skip_single_eca
   local function skip_single_eca(data, offset)
       -- Function type (int32)
       offset = offset + 4

       -- Function name (null-terminated)
       local _, new_offset = read_string(data, offset)
       offset = new_offset

       -- Is enabled (int32)
       offset = offset + 4

       -- Parameter count and parameters
       local param_count = compat.unpack("<I4", data, offset)
       offset = offset + 4

       for p = 1, param_count do
           offset = skip_parameter(data, offset)
       end

       -- Nested ECA count and recursion
       local nested_count = compat.unpack("<I4", data, offset)
       offset = offset + 4

       for n = 1, nested_count do
           offset = skip_single_eca(data, offset)
       end

       return offset
   end
   -- }}}

   -- {{{ local function skip_parameter
   local function skip_parameter(data, offset)
       -- Parameter type (int32)
       local param_type = compat.unpack("<i4", data, offset)  -- signed!
       offset = offset + 4

       -- Parameter value (null-terminated)
       local _, new_offset = read_string(data, offset)
       offset = new_offset

       -- Has sub-parameters (int32)
       local has_sub = compat.unpack("<I4", data, offset) == 1
       offset = offset + 4

       if has_sub then
           -- Sub-parameter count
           local sub_count = compat.unpack("<I4", data, offset)
           offset = offset + 4

           for s = 1, sub_count do
               offset = skip_parameter(data, offset)
           end
       end

       -- Is array index (int32)
       local is_array = compat.unpack("<I4", data, offset) == 1
       offset = offset + 4

       if is_array then
           -- Array index parameter (recursive)
           offset = skip_parameter(data, offset)
       end

       return offset
   end
   -- }}}
   ```

4. **Integrate into main parse function**
   ```lua
   function wtg.parse(data)
       -- ... existing header, category, variable parsing ...

       -- Parse trigger metadata
       local triggers, eca_offsets, offset, trig_err =
           parse_trigger_metadata(data, result._offset)
       if trig_err then
           return nil, trig_err
       end

       result.triggers = triggers
       result._trigger_eca_offsets = eca_offsets
       result._offset = offset

       return result, nil
   end
   ```

5. **Add category validation helper**
   ```lua
   -- {{{ function wtg.validate_categories
   function wtg.validate_categories(parsed)
       -- Verify all trigger category_index values reference valid categories
       local category_indices = {}
       for _, cat in ipairs(parsed.categories) do
           category_indices[cat.index] = true
       end

       local errors = {}
       for i, trigger in ipairs(parsed.triggers) do
           if not category_indices[trigger.category_index] then
               errors[#errors + 1] = string.format(
                   "Trigger '%s' references invalid category %d",
                   trigger.name, trigger.category_index
               )
           end
       end

       return #errors == 0, errors
   end
   -- }}}
   ```

6. **Create unit test**
   ```
   src/tests/test_wtg_triggers.lua
   ```

7. **Test with synthetic trigger data**
   ```lua
   local function make_test_trigger_section()
       local parts = {}
       -- Trigger count
       parts[#parts + 1] = string.pack("<I4", 1)

       -- Trigger 1
       parts[#parts + 1] = "Test Trigger\0"      -- name
       parts[#parts + 1] = "A test trigger\0"    -- description
       parts[#parts + 1] = string.pack("<I4", 0) -- is_comment
       parts[#parts + 1] = string.pack("<I4", 1) -- is_enabled
       parts[#parts + 1] = string.pack("<I4", 0) -- is_custom_text
       parts[#parts + 1] = string.pack("<I4", 1) -- is_initially_on
       parts[#parts + 1] = string.pack("<I4", 1) -- run_on_init
       parts[#parts + 1] = string.pack("<I4", 0) -- category_index
       parts[#parts + 1] = string.pack("<I4", 0) -- eca_count (empty trigger)

       return table.concat(parts)
   end
   ```

---

## Related Documents

- issues/301-parse-war3map-wtg.md (parent issue)
- issues/301a-parse-wtg-header-categories.md (prerequisite)
- issues/301b-parse-wtg-variables.md (prerequisite)
- issues/301d-parse-wtg-eca-functions.md (next - uses eca_offsets)
- src/parsers/wtg.lua (implementation location)

---

## Acceptance Criteria

- [x] Trigger count correctly parsed
- [x] Trigger names extracted (null-terminated strings)
- [x] Trigger descriptions extracted
- [x] All boolean flags correctly interpreted:
  - [x] is_comment
  - [x] is_enabled
  - [x] is_custom_text
  - [x] is_initially_on
  - [x] run_on_init
- [x] category_index correctly parsed
- [x] eca_count correctly parsed
- [x] ECA section correctly skipped (offset advances properly)
- [x] _trigger_eca_offsets array populated for 301d
- [x] Unit test passes with synthetic trigger data
- [x] Parser handles 0 triggers (empty map)
- [x] Works on real WTG file from test archive (N/A - test maps are protected)

---

## Notes

**Why skip ECA instead of parsing it here?**

The ECA parsing is complex and recursive. This issue focuses on the simpler trigger envelope (metadata) while leaving the ECA content to 301d. The `skip_*` functions provide just enough parsing to advance the offset correctly.

The `_trigger_eca_offsets` array records where each trigger's ECA data begins, allowing 301d to later populate the `events`, `conditions`, and `actions` arrays.

**Trigger flags explained:**
- `is_comment` - Trigger is in a "comment" category, treated as disabled
- `is_enabled` - Trigger can fire (can be disabled at runtime)
- `is_custom_text` - Trigger uses JASS code instead of GUI, see war3map.wct
- `is_initially_on` - Trigger starts enabled when map loads
- `run_on_init` - Trigger runs automatically at map initialization

**Category index:**
- Links to a category parsed in 301a
- Index 0 is typically "Initialization" or the first user category
- The `validate_categories` function can detect orphaned references

---

## Implementation Notes

*Completed 2025-12-27*

**Files Modified:**
- `src/parsers/wtg.lua` - Added trigger metadata parsing with ECA skipping
- `src/tests/test_wtg_header.lua` - Updated test data to include trigger count
- `src/tests/test_wtg_variables.lua` - Updated test data to include trigger count

**Files Created:**
- `src/tests/test_wtg_triggers.lua` - 9 tests covering trigger metadata parsing

**Implementation Details:**
- Added `parse_triggers()` function that extracts metadata and skips ECA content
- Added ECA skipping functions: `skip_parameter()`, `skip_single_eca()`, `skip_eca_section()`
- Skip functions handle recursive ECA/parameter structures with depth limits (100/50)
- Stores `_trigger_eca_offsets` array for 301d to use when parsing ECA content
- Added `wtg.validate_categories()` to check category references
- Updated `wtg.format()` to display trigger information with flags
- Exposed internal functions and ECA_TYPE constants for testing

**Key Implementation Decisions:**
- ECA skipping rather than parsing keeps 301c focused on metadata
- Depth limits prevent stack overflow on malformed data
- Parameter sub-parameters have different structure (func type + name + begin flag + count)
- is_comment, is_enabled, is_custom_text, is_initially_on, run_on_init all extracted as booleans

**Test Coverage:**
- 0 triggers (empty map)
- Simple trigger with no ECAs
- Trigger with multiple ECAs (event, condition, action with parameter)
- Multiple triggers with various flag combinations
- Category validation
- ECA offset recording
- Format output verification

**Run tests with:** `luajit src/tests/test_wtg_triggers.lua`
