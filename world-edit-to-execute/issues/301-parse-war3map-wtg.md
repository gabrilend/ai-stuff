# Issue 301: Parse war3map.wtg (Trigger Definitions)

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 102-implement-mpq-archive-parser

---

## Current Behavior

Cannot read trigger definitions. GUI-created triggers from World Editor are
inaccessible, preventing trigger-based gameplay from functioning.

---

## Intended Behavior

A parser that extracts all trigger definitions from war3map.wtg:
- Trigger categories (folders in the editor)
- Trigger names and descriptions
- Trigger events (what activates the trigger)
- Trigger conditions (when it should fire)
- Trigger actions (what it does)
- Variable definitions
- Trigger enable/disable state

---

## Suggested Implementation Steps

1. **Create parser module**
   ```
   src/parsers/
   └── wtg.lua          (this issue)
   ```

2. **Implement header parsing**
   ```lua
   -- war3map.wtg header structure:
   -- Offset  Type      Description
   -- 0x00    char[4]   File ID "WTG!"
   -- 0x04    int32     File format version (7 for TFT)
   -- 0x08    int32     Number of trigger categories
   -- 0x0C    Category[] Category definitions
   ```

3. **Parse trigger categories**
   ```lua
   -- Each category:
   -- int32:  Category index
   -- string: Category name (null-terminated)
   -- int32:  Category type (0=normal, 1=comment)
   ```

4. **Parse variable definitions**
   ```lua
   -- int32:  Number of variables
   -- For each variable:
   --   string: Variable name
   --   string: Variable type (e.g., "unit", "integer", "real")
   --   int32:  Unknown (always 1?)
   --   int32:  Is array (0/1)
   --   int32:  Array size (if array)
   --   int32:  Is initialized (0/1)
   --   string: Initial value (if initialized)
   ```

5. **Parse triggers**
   ```lua
   -- int32:  Number of triggers
   -- For each trigger:
   --   string: Trigger name
   --   string: Trigger description
   --   int32:  Is comment (0/1)
   --   int32:  Is enabled (0/1)
   --   int32:  Is custom text (0/1)
   --   int32:  Is initially on (0/1)
   --   int32:  Run on map init (0/1)
   --   int32:  Category index
   --   int32:  Number of ECA functions
   --   ECA[]:  Event/Condition/Action functions
   ```

6. **Parse ECA (Event/Condition/Action) functions**
   ```lua
   -- Each ECA function:
   -- int32:  Function type (0=event, 1=condition, 2=action)
   -- string: Function name (e.g., "TriggerRegisterTimerEvent")
   -- int32:  Is enabled (0/1)
   -- int32:  Number of parameters
   -- Param[]: Parameter values
   -- int32:  Number of nested ECAs (for if/then/else, loops)
   -- ECA[]:  Nested ECA functions (recursive)
   ```

7. **Parse parameters**
   ```lua
   -- Each parameter:
   -- int32:  Parameter type
   --         0 = preset
   --         1 = variable
   --         2 = function call
   --         3 = string literal
   --         -1 = invalid/disabled
   -- string: Parameter value
   -- int32:  Has sub-parameters (0/1)
   -- Param[]: Sub-parameters (if function call)
   -- int32:  Is array index (0/1)
   -- Param:  Array index parameter (if array)
   ```

8. **Return structured data**
   ```lua
   return {
       version = 7,
       categories = {
           { index = 0, name = "Initialization", type = "normal" },
           { index = 1, name = "Combat", type = "normal" },
       },
       variables = {
           {
               name = "udg_Hero",
               type = "unit",
               is_array = false,
               is_initialized = true,
               initial_value = nil,
           },
       },
       triggers = {
           {
               name = "Init_Trigger",
               description = "Runs on map start",
               category = 0,
               is_enabled = true,
               is_initially_on = true,
               run_on_init = true,
               events = { ... },
               conditions = { ... },
               actions = { ... },
           },
       },
   }
   ```

---

## Technical Notes

### ECA Function Types

The function type determines trigger behavior:
- **Events (0):** What causes the trigger to evaluate (e.g., unit enters region)
- **Conditions (1):** Boolean checks that must pass (e.g., unit is hero)
- **Actions (2):** What happens when trigger fires (e.g., create unit)

### Common Function Names

```lua
-- Events
"TriggerRegisterTimerEvent"       -- Periodic timer
"TriggerRegisterEnterRegion"      -- Unit enters rect
"TriggerRegisterPlayerEvent"      -- Player-based events
"TriggerRegisterUnitEvent"        -- Unit-based events

-- Conditions
"GetTriggerUnit"                  -- Get the triggering unit
"IsUnitType"                      -- Check unit classification
"CompareInteger"                  -- Numeric comparison

-- Actions
"CreateUnit"                      -- Spawn a unit
"DisplayTextToPlayer"             -- Show message
"SetUnitPosition"                 -- Move unit
"PauseTimer"                      -- Timer control
```

### Variable Naming Convention

Editor-generated variables have `udg_` prefix:
- `udg_` = User-Defined Global
- Example: `udg_SpawnCount`, `udg_HeroUnit`

### Nested ECA Structures

Control flow actions contain nested ECAs:
- `IfThenElse` - Contains conditions + actions
- `ForLoop` - Contains loop body actions
- `AndMultiple` / `OrMultiple` - Contains condition children

---

## Related Documents

- docs/formats/wtg-triggers.md (to be created)
- issues/102-implement-mpq-archive-parser.md (provides file access)
- issues/302-parse-war3map-wct.md (custom trigger text)
- issues/307-implement-trigger-framework.md (runtime execution)

---

## Acceptance Criteria

- [ ] Can parse war3map.wtg from test archives
- [ ] Correctly extracts trigger categories
- [ ] Correctly extracts variable definitions
- [ ] Correctly extracts trigger metadata
- [ ] Correctly extracts events, conditions, actions
- [ ] Handles nested ECA structures (if/then/else, loops)
- [ ] Handles parameter types (presets, variables, function calls)
- [ ] Returns structured Lua table
- [ ] Unit tests for parser

---

## Notes

The wtg format is the most complex of the trigger files. It represents the
GUI trigger editor's internal representation. Understanding this format
enables:

1. Displaying triggers in a custom editor
2. Converting GUI triggers to JASS/Lua
3. Analyzing map logic without decompilation

The format is recursive due to nested control flow structures. Care must
be taken to handle arbitrarily deep nesting.

Reference: [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
Reference: [Wurst WTG Parser](https://github.com/wurstscript/WurstScript)

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-19 03:10*

Looking at this issue, it's a substantial parsing task with clear logical divisions. The WTG format has several distinct components that would benefit from separation.

## Sub-Issue Analysis

**Recommendation: Split into 5 sub-issues**

The issue covers header parsing, categories, variables, triggers, and the recursive ECA structure. Each is a distinct concern with clear boundaries.

---

### 301a-parse-wtg-header-and-categories

**Description:** Parse the WTG file header (magic bytes, version) and trigger category definitions. Categories are simple structures that provide organizational context for triggers.

**Covers:**
- File ID validation ("WTG!")
- Format version detection
- Category array parsing (index, name, type)

**Dependencies:** None (entry point)

---

### 301b-parse-wtg-variables

**Description:** Parse the variable definitions section. These are user-defined globals (udg_*) that triggers reference.

**Covers:**
- Variable count and iteration
- Variable properties (name, type, array status)
- Initialization state and default values
- Array size handling

**Dependencies:** 301a (needs header parsed first to reach variable section)

---

### 301c-parse-wtg-trigger-metadata

**Description:** Parse trigger definitions excluding their ECA content. This includes names, descriptions, flags, and category assignments.

**Covers:**
- Trigger count and iteration
- Name and description strings
- Boolean flags (enabled, initially_on, run_on_init, is_comment, is_custom_text)
- Category index linking

**Dependencies:** 301a (needs categories parsed for validation)

---

### 301d-parse-wtg-eca-functions

**Description:** Parse the recursive ECA (Event/Condition/Action) function structures. This is the most complex component due to arbitrary nesting depth.

**Covers:**
- Function type discrimination (event=0, condition=1, action=2)
- Function name and enabled state
- Nested ECA handling (IfThenElse, ForLoop, AndMultiple, OrMultiple)
- Recursive descent parsing

**Dependencies:** 301c (ECA arrays are part of trigger structures)

---

### 301e-parse-wtg-parameters

**Description:** Parse function parameters with their various types and potential sub-parameters.

**Covers:**
- Parameter type handling (preset=0, variable=1, function_call=2, string=3, invalid=-1)
- Parameter value extraction
- Sub-parameter recursion (function calls have parameter children)
- Array index parameter handling

**Dependencies:** 301d (parameters are components of ECA functions)

---

## Dependency Graph

```
301a (header/categories)
  │
  ├──▶ 301b (variables)
  │
  └──▶ 301c (trigger metadata)
          │
          └──▶ 301d (ECA functions)
                  │
                  └──▶ 301e (parameters)
```

---

## Rationale for Splitting

1. **Recursive complexity isolation** - The ECA and parameter parsing (301d, 301e) involve recursive structures that deserve focused attention and testing.

2. **Incremental testability** - Each sub-issue can have focused unit tests. Header/category parsing can be validated before tackling the more complex structures.

3. **Clear data flow** - The sequential nature (header → variables → triggers → ECAs → parameters) maps naturally to sub-issues.

4. **Risk management** - If the ECA recursion proves problematic, it won't block progress on simpler components.

The issue is complex enough that splitting provides real value - each sub-issue represents roughly one focused implementation session.
