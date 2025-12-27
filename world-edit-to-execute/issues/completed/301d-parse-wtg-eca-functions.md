# Issue 301d: Parse WTG ECA Functions

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent:** 301-parse-war3map-wtg.md
**Dependencies:** 301c-parse-wtg-trigger-metadata

---

## Current Behavior

After 301c completes, the WTG parser can read trigger metadata but the ECA (Event/Condition/Action) function structures are skipped. The actual trigger logic (what events fire the trigger, what conditions gate it, what actions execute) is inaccessible.

---

## Intended Behavior

Extend the WTG parser to fully parse ECA function structures:

**ECA properties to extract:**
- Function type (0=event, 1=condition, 2=action)
- Function name (e.g., "TriggerRegisterTimerEvent")
- Is enabled flag
- Parameters (parsed in 301e)
- Nested ECA functions (for control flow structures)

**Output structure - populating trigger.events/conditions/actions:**
```lua
{
    triggers = {
        {
            name = "Periodic Spawn",
            -- ... metadata from 301c ...
            events = {
                {
                    type = "event",
                    name = "TriggerRegisterTimerEventPeriodic",
                    is_enabled = true,
                    parameters = { ... },  -- from 301e
                    children = {},
                },
            },
            conditions = {
                {
                    type = "condition",
                    name = "GetBooleanAnd",
                    is_enabled = true,
                    parameters = { ... },
                    children = {
                        -- AndMultiple contains child conditions
                        { type = "condition", name = "...", ... },
                        { type = "condition", name = "...", ... },
                    },
                },
            },
            actions = {
                {
                    type = "action",
                    name = "CreateNUnitsAtLoc",
                    is_enabled = true,
                    parameters = { ... },
                    children = {},
                },
                {
                    type = "action",
                    name = "IfThenElseMultiple",
                    is_enabled = true,
                    parameters = {},
                    children = {
                        -- If condition
                        { type = "condition", name = "...", ... },
                        -- Then actions
                        { type = "action", name = "...", ... },
                        -- Else actions
                        { type = "action", name = "...", ... },
                    },
                },
            },
        },
    },
}
```

---

## Suggested Implementation Steps

1. **Read the existing wtg.lua module**
   - Understand the skip_* functions from 301c
   - These will be replaced with full parsing functions

2. **Define ECA type constants**
   ```lua
   local ECA_TYPE = {
       EVENT = 0,
       CONDITION = 1,
       ACTION = 2,
   }

   local ECA_TYPE_NAMES = {
       [0] = "event",
       [1] = "condition",
       [2] = "action",
   }
   ```

3. **Implement recursive ECA parser**
   ```lua
   -- {{{ local function parse_eca
   local function parse_eca(data, offset, depth)
       depth = depth or 0

       -- Prevent stack overflow on malformed data
       if depth > 100 then
           return nil, offset, "ECA nesting too deep (>100 levels)"
       end

       local eca = {}

       -- Function type (int32)
       local type_num = compat.unpack("<I4", data, offset)
       offset = offset + 4
       eca.type = ECA_TYPE_NAMES[type_num] or "unknown"

       -- Function name (null-terminated)
       eca.name, offset = read_string(data, offset)

       -- Is enabled (int32)
       eca.is_enabled = compat.unpack("<I4", data, offset) == 1
       offset = offset + 4

       -- Parameter count
       local param_count = compat.unpack("<I4", data, offset)
       offset = offset + 4

       -- Parse parameters (delegated to 301e, placeholder for now)
       eca.parameters = {}
       for p = 1, param_count do
           local param, new_offset, err = parse_parameter(data, offset, depth + 1)
           if err then
               return nil, new_offset, err
           end
           eca.parameters[#eca.parameters + 1] = param
           offset = new_offset
       end

       -- Nested ECA count (for control flow)
       local child_count = compat.unpack("<I4", data, offset)
       offset = offset + 4

       -- Parse nested ECAs recursively
       eca.children = {}
       for c = 1, child_count do
           local child, new_offset, err = parse_eca(data, offset, depth + 1)
           if err then
               return nil, new_offset, err
           end
           eca.children[#eca.children + 1] = child
           offset = new_offset
       end

       return eca, offset, nil
   end
   -- }}}
   ```

4. **Add function to parse all ECAs for a trigger**
   ```lua
   -- {{{ local function parse_trigger_ecas
   local function parse_trigger_ecas(data, offset, eca_count)
       local events = {}
       local conditions = {}
       local actions = {}

       for i = 1, eca_count do
           local eca, new_offset, err = parse_eca(data, offset, 0)
           if err then
               return nil, nil, nil, new_offset, err
           end
           offset = new_offset

           -- Sort into appropriate category
           if eca.type == "event" then
               events[#events + 1] = eca
           elseif eca.type == "condition" then
               conditions[#conditions + 1] = eca
           elseif eca.type == "action" then
               actions[#actions + 1] = eca
           end
       end

       return events, conditions, actions, offset, nil
   end
   -- }}}
   ```

5. **Implement two-pass parsing approach**
   Option A: Parse ECAs during initial pass (replace skip with parse)
   Option B: Parse ECAs in second pass using stored offsets

   Recommended: Option B for cleaner separation
   ```lua
   -- {{{ function wtg.parse_eca_pass
   function wtg.parse_eca_pass(data, parsed)
       -- Second pass: populate trigger ECAs using stored offsets
       for i, trigger in ipairs(parsed.triggers) do
           local offset = parsed._trigger_eca_offsets[i]

           local events, conditions, actions, new_offset, err =
               parse_trigger_ecas(data, offset, trigger.eca_count)

           if err then
               return nil, string.format(
                   "Error parsing trigger '%s': %s",
                   trigger.name, err
               )
           end

           trigger.events = events
           trigger.conditions = conditions
           trigger.actions = actions
       end

       -- Clean up internal tracking
       parsed._trigger_eca_offsets = nil

       return parsed, nil
   end
   -- }}}
   ```

6. **Update main parse function to optionally include ECA pass**
   ```lua
   function wtg.parse(data, options)
       options = options or {}

       -- First pass: header, categories, variables, trigger metadata
       local result, err = wtg.parse_metadata(data)
       if err then
           return nil, err
       end

       -- Second pass: ECA functions (optional, can be slow)
       if options.parse_eca ~= false then
           result, err = wtg.parse_eca_pass(data, result)
           if err then
               return nil, err
           end
       end

       return result, nil
   end
   ```

7. **Handle control flow structures**
   Document which functions have children:
   ```lua
   -- Functions that contain nested ECAs:
   local CONTROL_FLOW_FUNCTIONS = {
       -- Actions
       "IfThenElse",              -- if-then-else (3 children: condition, then, else)
       "IfThenElseMultiple",      -- if-then-else with multiple conditions
       "ForLoopA",                -- for loop (integer)
       "ForLoopB",                -- for loop (integer)
       "ForLoopVar",              -- for loop with variable
       "ForLoopAMultiple",        -- for loop with multiple actions
       "ForLoopBMultiple",        -- for loop with multiple actions
       "ForLoopVarMultiple",      -- for loop with variable, multiple actions
       "ForForce",                -- for each player in force
       "ForGroup",                -- for each unit in group
       "EnumDestructablesInRect", -- for each destructable in rect
       "EnumItemsInRect",         -- for each item in rect

       -- Conditions
       "AndMultiple",             -- AND with multiple conditions
       "OrMultiple",              -- OR with multiple conditions
       "GetBooleanAnd",           -- legacy AND
       "GetBooleanOr",            -- legacy OR
   }
   ```

8. **Create unit test**
   ```
   src/tests/test_wtg_eca.lua
   ```

9. **Test with synthetic ECA data**
   ```lua
   local function make_simple_eca()
       local parts = {}
       -- Event: Timer periodic
       parts[#parts + 1] = string.pack("<I4", 0)  -- type = event
       parts[#parts + 1] = "TriggerRegisterTimerEventPeriodic\0"
       parts[#parts + 1] = string.pack("<I4", 1)  -- is_enabled
       parts[#parts + 1] = string.pack("<I4", 0)  -- param_count
       parts[#parts + 1] = string.pack("<I4", 0)  -- child_count

       return table.concat(parts)
   end
   ```

10. **Test nested structure parsing**
    Create test data with IfThenElse containing children
    Verify recursive parsing produces correct tree structure

---

## Related Documents

- issues/301-parse-war3map-wtg.md (parent issue)
- issues/301c-parse-wtg-trigger-metadata.md (prerequisite)
- issues/301e-parse-wtg-parameters.md (parameter parsing)
- issues/307-implement-trigger-framework.md (uses parsed ECAs)
- src/parsers/wtg.lua (implementation location)

---

## Acceptance Criteria

- [x] ECA type correctly parsed (0=event, 1=condition, 2=action)
- [x] ECA function name correctly extracted
- [x] is_enabled flag correctly parsed
- [x] Parameter count correctly parsed (parameters parsed by 301e)
- [x] Nested ECA count correctly parsed
- [x] Nested ECAs recursively parsed
- [x] ECAs correctly sorted into events/conditions/actions arrays
- [x] IfThenElse and loop structures parse with children
- [x] AndMultiple/OrMultiple conditions parse with children
- [x] Depth limit prevents stack overflow on malformed data
- [x] Unit test passes with synthetic ECA data
- [x] Works on real WTG file from test archive (N/A - test maps are protected)

---

## Notes

**Why is ECA parsing complex?**

The ECA structure is inherently recursive. An IfThenElse action contains:
1. A condition ECA (the "if" check)
2. One or more action ECAs (the "then" block)
3. Optionally more action ECAs (the "else" block)

And those child actions can themselves be IfThenElse structures, loops, etc. This creates an arbitrarily deep tree.

**Control flow semantics:**

The WTG format doesn't explicitly mark "then" vs "else" blocks. Instead:
- For IfThenElse: First child is condition, rest are then-actions, no else
- For IfThenElseMultiple: Children include conditions, then-actions, else-actions
- The semantics must be inferred from function name and child positions

**Performance note:**

ECA parsing can be slow for complex maps with many triggers. The two-pass approach allows callers to skip ECA parsing if they only need trigger names/categories (e.g., for a trigger list UI).

**Common function names to expect:**
```
Events: TriggerRegisterTimerEventPeriodic, TriggerRegisterEnterRectSimple,
        TriggerRegisterPlayerEventEndCinematic, TriggerRegisterUnitEvent

Conditions: CompareInteger, IsUnitType, IsUnitAlive, GetBooleanAnd

Actions: CreateNUnitsAtLoc, DisplayTextToForce, SetUnitPositionLoc,
         IfThenElseMultiple, ForLoopAMultiple, Wait
```

---

## Implementation Notes

*Completed 2025-12-27*

The ECA parsing was implemented as part of the incremental WTG parser development:

**Implementation:**
- `parse_single_eca()` - Recursively parses individual ECAs with parameters and children
- `parse_trigger_ecas()` - Parses all ECAs for a trigger, sorting into events/conditions/actions
- `wtg.parse_eca_pass()` - Second-pass function using stored offsets for deferred parsing
- `parse_parameter_placeholder()` - Extracts parameter type, value, sub-parameters, and array indices

**Key Design Decisions:**
1. Two-pass parsing enabled by default (`parse_eca=true`) for convenience
2. Can skip ECA parsing with `parse_eca=false` for faster metadata-only access
3. Stored `_trigger_eca_offsets` allows deferred ECA parsing via `parse_eca_pass()`
4. Both `type` (string) and `type_id` (number) preserved for flexibility

**Test Coverage:**
- 13 tests in `src/tests/test_wtg_eca.lua`
- Tests cover: simple ECAs, all three types, parameters, disabled ECAs, nested control flow
- Tests cover: deeply nested structures, two-pass parsing, format output

**Note:** All 16 test maps in `assets/` are protected and don't contain `war3map.wtg` files.
Synthetic test data validates parser correctness.

**Run with:** `luajit src/tests/test_wtg_eca.lua`
