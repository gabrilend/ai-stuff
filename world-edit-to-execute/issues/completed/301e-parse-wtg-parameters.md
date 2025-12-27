# Issue 301e: Parse WTG Parameters

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent:** 301-parse-war3map-wtg.md
**Dependencies:** 301d-parse-wtg-eca-functions

---

## Current Behavior

After 301d completes, the WTG parser can read ECA function structures but parameter values are not fully parsed. The actual values passed to trigger functions (unit types, locations, strings, variable references) are inaccessible.

---

## Intended Behavior

Complete the WTG parser by implementing full parameter parsing:

**Parameter types to handle:**
- Type -1: Invalid/disabled parameter
- Type 0: Preset (predefined value from trigger data)
- Type 1: Variable reference
- Type 2: Function call (nested parameters)
- Type 3: String literal

**Parameter structure:**
```lua
{
    type = "variable",      -- human-readable type name
    type_id = 1,           -- original numeric type
    value = "udg_Hero",    -- the parameter value/name
    sub_parameters = {},   -- for function calls
    array_index = nil,     -- for array variable access
}
```

**Full example with nested parameters:**
```lua
-- Action: Set udg_Counter = udg_Counter + 1
{
    type = "action",
    name = "SetVariable",
    parameters = {
        {
            type = "variable",
            type_id = 1,
            value = "udg_Counter",
            sub_parameters = {},
            array_index = nil,
        },
        {
            type = "function",
            type_id = 2,
            value = "OperatorInt",
            sub_parameters = {
                {
                    type = "variable",
                    type_id = 1,
                    value = "udg_Counter",
                    sub_parameters = {},
                    array_index = nil,
                },
                {
                    type = "preset",
                    type_id = 0,
                    value = "OperatorAdd",
                    sub_parameters = {},
                    array_index = nil,
                },
                {
                    type = "string",
                    type_id = 3,
                    value = "1",
                    sub_parameters = {},
                    array_index = nil,
                },
            },
            array_index = nil,
        },
    },
}
```

---

## Suggested Implementation Steps

1. **Read the existing wtg.lua module**
   - Locate the placeholder parse_parameter function from 301d
   - Understand how it integrates with ECA parsing

2. **Define parameter type constants**
   ```lua
   local PARAM_TYPE = {
       INVALID = -1,
       PRESET = 0,
       VARIABLE = 1,
       FUNCTION = 2,
       STRING = 3,
   }

   local PARAM_TYPE_NAMES = {
       [-1] = "invalid",
       [0] = "preset",
       [1] = "variable",
       [2] = "function",
       [3] = "string",
   }
   ```

3. **Implement parameter parser**
   ```lua
   -- {{{ local function parse_parameter
   local function parse_parameter(data, offset, depth)
       depth = depth or 0

       -- Prevent infinite recursion
       if depth > 50 then
           return nil, offset, "Parameter nesting too deep (>50 levels)"
       end

       local param = {}

       -- Parameter type (int32, SIGNED - can be -1)
       local type_id = compat.unpack("<i4", data, offset)  -- lowercase i = signed
       offset = offset + 4

       param.type_id = type_id
       param.type = PARAM_TYPE_NAMES[type_id] or "unknown"

       -- Parameter value (null-terminated string)
       param.value, offset = read_string(data, offset)

       -- Has sub-parameters (int32: 0 or 1)
       local has_sub = compat.unpack("<I4", data, offset) == 1
       offset = offset + 4

       param.sub_parameters = {}

       if has_sub then
           -- For function calls, parse nested parameters
           -- First: the function type/name (repeated structure)
           local func_type = compat.unpack("<I4", data, offset)
           offset = offset + 4

           local func_name
           func_name, offset = read_string(data, offset)

           -- Begin sub-parameter flag (int32)
           local begin_flag = compat.unpack("<I4", data, offset)
           offset = offset + 4

           -- Number of sub-parameters
           local sub_count = compat.unpack("<I4", data, offset)
           offset = offset + 4

           for s = 1, sub_count do
               local sub_param, new_offset, err = parse_parameter(data, offset, depth + 1)
               if err then
                   return nil, new_offset, err
               end
               param.sub_parameters[#param.sub_parameters + 1] = sub_param
               offset = new_offset
           end
       end

       -- Is array index access (int32: 0 or 1)
       local is_array = compat.unpack("<I4", data, offset) == 1
       offset = offset + 4

       param.array_index = nil

       if is_array then
           -- Array index is itself a parameter (recursive)
           local index_param, new_offset, err = parse_parameter(data, offset, depth + 1)
           if err then
               return nil, new_offset, err
           end
           param.array_index = index_param
           offset = new_offset
       end

       return param, offset, nil
   end
   -- }}}
   ```

4. **Handle invalid/disabled parameters**
   ```lua
   -- Type -1 indicates disabled parameter
   -- These occur in disabled trigger branches
   -- The value field may still contain data, but it's not used
   if param.type_id == -1 then
       param.value = nil  -- or keep original for debugging
       param.sub_parameters = {}
       param.array_index = nil
   end
   ```

5. **Add parameter validation helper**
   ```lua
   -- {{{ function wtg.validate_parameters
   function wtg.validate_parameters(param)
       -- Check for common issues
       local issues = {}

       -- Variable references should have names
       if param.type == "variable" and (not param.value or param.value == "") then
           issues[#issues + 1] = "Variable parameter missing name"
       end

       -- Function calls should have sub-parameters
       if param.type == "function" and #param.sub_parameters == 0 then
           -- Note: some functions have no parameters, this is just a warning
       end

       -- Recursively validate sub-parameters
       for _, sub in ipairs(param.sub_parameters) do
           local sub_issues = wtg.validate_parameters(sub)
           for _, issue in ipairs(sub_issues) do
               issues[#issues + 1] = "Sub-parameter: " .. issue
           end
       end

       -- Validate array index if present
       if param.array_index then
           local idx_issues = wtg.validate_parameters(param.array_index)
           for _, issue in ipairs(idx_issues) do
               issues[#issues + 1] = "Array index: " .. issue
           end
       end

       return issues
   end
   -- }}}
   ```

6. **Add parameter pretty-printer for debugging**
   ```lua
   -- {{{ function wtg.format_parameter
   function wtg.format_parameter(param, indent)
       indent = indent or 0
       local prefix = string.rep("  ", indent)
       local lines = {}

       lines[#lines + 1] = string.format(
           "%s[%s] %s",
           prefix, param.type, param.value or "(none)"
       )

       for i, sub in ipairs(param.sub_parameters) do
           lines[#lines + 1] = wtg.format_parameter(sub, indent + 1)
       end

       if param.array_index then
           lines[#lines + 1] = prefix .. "  [index]:"
           lines[#lines + 1] = wtg.format_parameter(param.array_index, indent + 2)
       end

       return table.concat(lines, "\n")
   end
   -- }}}
   ```

7. **Update 301d to use the real parser**
   - Replace placeholder/skip in parse_eca with actual parse_parameter calls
   - Ensure parameter parsing is properly integrated

8. **Create unit test**
   ```
   src/tests/test_wtg_params.lua
   ```

9. **Test each parameter type**
   ```lua
   local function make_preset_param()
       local parts = {}
       parts[#parts + 1] = string.pack("<i4", 0)  -- type = preset
       parts[#parts + 1] = "OperatorAdd\0"        -- value
       parts[#parts + 1] = string.pack("<I4", 0)  -- has_sub = false
       parts[#parts + 1] = string.pack("<I4", 0)  -- is_array = false
       return table.concat(parts)
   end

   local function make_variable_param()
       local parts = {}
       parts[#parts + 1] = string.pack("<i4", 1)  -- type = variable
       parts[#parts + 1] = "udg_Counter\0"        -- value
       parts[#parts + 1] = string.pack("<I4", 0)  -- has_sub = false
       parts[#parts + 1] = string.pack("<I4", 0)  -- is_array = false
       return table.concat(parts)
   end

   local function make_string_param()
       local parts = {}
       parts[#parts + 1] = string.pack("<i4", 3)  -- type = string
       parts[#parts + 1] = "Hello World\0"        -- value
       parts[#parts + 1] = string.pack("<I4", 0)  -- has_sub = false
       parts[#parts + 1] = string.pack("<I4", 0)  -- is_array = false
       return table.concat(parts)
   end
   ```

10. **Test array index access**
    ```lua
    local function make_array_variable_param()
        local parts = {}
        -- Main parameter: array variable
        parts[#parts + 1] = string.pack("<i4", 1)  -- type = variable
        parts[#parts + 1] = "udg_Units\0"          -- value
        parts[#parts + 1] = string.pack("<I4", 0)  -- has_sub = false
        parts[#parts + 1] = string.pack("<I4", 1)  -- is_array = true
        -- Index parameter
        parts[#parts + 1] = string.pack("<i4", 3)  -- type = string (literal index)
        parts[#parts + 1] = "5\0"                  -- index value
        parts[#parts + 1] = string.pack("<I4", 0)  -- has_sub = false
        parts[#parts + 1] = string.pack("<I4", 0)  -- is_array = false

        return table.concat(parts)
    end
    ```

11. **Test function call with sub-parameters**
    Create nested function structure and verify tree parses correctly

---

## Related Documents

- issues/301-parse-war3map-wtg.md (parent issue)
- issues/301d-parse-wtg-eca-functions.md (prerequisite, uses this parser)
- issues/307-implement-trigger-framework.md (evaluates parsed parameters)
- src/parsers/wtg.lua (implementation location)

---

## Acceptance Criteria

- [x] Parameter type -1 (invalid) correctly handled
- [x] Parameter type 0 (preset) correctly parsed
- [x] Parameter type 1 (variable) correctly parsed
- [x] Parameter type 2 (function) correctly parsed with sub-parameters
- [x] Parameter type 3 (string) correctly parsed
- [x] Sub-parameter recursion works (function calls within function calls)
- [x] Array index parameters correctly parsed
- [x] Array index can be a variable or literal
- [x] Depth limit prevents stack overflow
- [x] format_parameter produces readable debug output
- [x] Unit test passes for all parameter types
- [x] Works on real WTG file from test archive (N/A - test maps are protected)

---

## Notes

**Signed vs unsigned for type field:**

The parameter type is stored as a SIGNED int32 because -1 is a valid value (disabled). Use `"<i4"` (lowercase) in unpack, not `"<I4"` (uppercase).

**Sub-parameter structure quirk:**

When `has_sub` is true, there's additional structure before the sub-parameter array:
1. Function type (int32) - usually 0
2. Function name (string) - may repeat the parent function name
3. Begin flag (int32) - usually 1
4. Sub-parameter count (int32)
5. Sub-parameters

This structure seems redundant but must be parsed correctly to advance the offset.

**Common presets:**

Preset values (type 0) reference constants defined in trigger data files:
- `OperatorAdd`, `OperatorSubtract`, `OperatorMultiply`, `OperatorDivide`
- `ComparisonEqual`, `ComparisonLessThan`, `ComparisonGreaterThan`
- Unit type codes like `hfoo` (Footman), `Hpal` (Paladin)

**Variable naming:**

Variable references include the `udg_` prefix in the stored value. The parser preserves this as-is; runtime will resolve the actual variable.

**String literals:**

Numeric values are stored as strings: integer 5 becomes `"5"`, real 3.14 becomes `"3.14"`. The trigger runtime handles type conversion.

---

## Implementation Notes

*Completed 2025-12-27*

The parameter parsing was implemented as part of the WTG parser:

**Implementation:**
- `parse_parameter()` - Full parameter parser (renamed from placeholder)
- `PARAM_TYPE` / `PARAM_TYPE_NAMES` - Type constants and name mappings
- `wtg.format_parameter()` - Human-readable parameter tree output
- `wtg.validate_parameter()` - Recursive parameter validation

**Key Changes:**
1. Renamed `parse_parameter_placeholder` to `parse_parameter` (alias kept for compatibility)
2. Added `type_name` field to parsed parameters for convenience
3. Added recursive formatting and validation helper functions
4. Exposed `PARAM_TYPE` and `PARAM_TYPE_NAMES` constants

**Output Structure:**
```lua
{
    type = 1,                    -- numeric type ID
    type_name = "variable",      -- human-readable type name
    value = "udg_Counter",       -- parameter value
    has_sub = false,             -- has sub-parameters
    sub_function = nil,          -- sub-function details (if has_sub)
    is_array = false,            -- is array access
    array_index = nil,           -- array index parameter (if is_array)
}
```

**Test Coverage:**
- 17 tests in `src/tests/test_wtg_params.lua`
- Tests cover: all parameter types, sub-parameters, array indices
- Tests cover: format_parameter, validate_parameter, nested functions

**Run with:** `luajit src/tests/test_wtg_params.lua`
