# Issue 905: Trigger Editor

**Phase:** 9
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 901 (Editor core), Phase 3 (Triggers/JASS)

---

## Current Behavior

Triggers can be parsed and executed but not created or edited visually.

## Intended Behavior

Full trigger editing with feature parity to WC3 World Editor, PLUS:
- Lua source editing with syntax highlighting
- Bidirectional GUI ↔ Lua conversion
- Lua source is the canonical format, GUI is a view

### Dual-Mode Architecture

```
           ┌─────────────────────────────────────────┐
           │              TRIGGER FILE               │
           │            (trigger.lua)                │
           └─────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
            ▼               │               ▼
    ┌───────────────┐       │       ┌───────────────┐
    │   GUI VIEW    │◀──────┴──────▶│   CODE VIEW   │
    │               │               │               │
    │ Visual blocks │  Bidirectional│ Lua source    │
    │ Drag & drop   │  conversion   │ Syntax color  │
    │ Menus         │               │ Autocomplete  │
    └───────────────┘               └───────────────┘
```

### GUI Trigger View

```
TRIGGER LIST                        TRIGGER EDITOR
┌────────────────────────┐         ┌─────────────────────────────────────┐
│ ▶ Initialization       │         │ ⚡ Kill Count Victory               │
│   ├─ ⚡ Melee Init     │         ├─────────────────────────────────────┤
│   └─ ⚡ Player Setup   │         │ Events                              │
│ ▶ Combat               │         │   ├─ 🔔 A unit dies                 │
│   ├─ ⚡ Hero Death     │         │   └─ [+ Add Event]                  │
│   └─ ⚡ Kill Count     │◀────────│                                     │
│ ▶ Victory              │         │ Conditions                          │
│   └─ ⚡ Check Winner   │         │   ├─ ❓ (Killing unit) belongs to   │
│ ▶ Custom Scripts       │         │   │     Player 1 (Red)              │
│   └─ 📜 Helper Funcs   │         │   └─ [+ Add Condition]              │
│                        │         │                                     │
│ [+ New Trigger]        │         │ Actions                             │
│ [+ New Category]       │         │   ├─ 📋 Set KillCount = KillCount+1│
│                        │         │   ├─ ⚡ If KillCount >= 10 then    │
│ [ ] Initially Off      │         │   │   └─ 🏆 Player 1 Wins          │
│ [x] Initially On       │         │   └─ [+ Add Action]                 │
└────────────────────────┘         └─────────────────────────────────────┘
```

### Code View

```lua
-- triggers/combat/kill_count.lua
-- Auto-generated from GUI, editable

local trigger = Trigger.create("Kill Count Victory")

trigger:on("unit_dies", function(event)
    -- Conditions
    if event.killing_unit:get_owner() ~= Player(1) then
        return
    end

    -- Actions
    KillCount = KillCount + 1

    if KillCount >= 10 then
        Player(1):set_victory()
    end
end)

return trigger
```

### GUI Block Types

| Block Type | Description | Example |
|------------|-------------|---------|
| **Event** | What triggers execution | "A unit dies" |
| **Condition** | Filter checks | "Killing unit belongs to Player 1" |
| **Action** | What happens | "Set variable KillCount" |
| **Control** | Flow control | "If/Then/Else", "Loop" |
| **Variable** | Data references | "KillCount", "TriggeringUnit" |
| **Function** | Custom functions | "GetRandomHero()" |

### Block Editor Popup

```
ACTION EDITOR
┌─────────────────────────────────────────────────────┐
│ Action: Set Variable                                │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Variable: [KillCount ▼]                             │
│                                                     │
│ Operator: [= (Set) ▼]                               │
│           ○ = (Set)                                 │
│           ○ += (Add)                                │
│           ○ -= (Subtract)                           │
│           ○ *= (Multiply)                           │
│                                                     │
│ Value:    [KillCount + 1________]                   │
│           [Insert Value ▼] [Insert Variable ▼]     │
│                                                     │
│                          [OK] [Cancel]              │
└─────────────────────────────────────────────────────┘
```

### Variable Manager

```
VARIABLES
┌────────────────────────────────────────────────────┐
│ Name          Type       Initial    Array         │
├────────────────────────────────────────────────────┤
│ KillCount     Integer    0          [ ]           │
│ SpawnRegion   Region     <none>     [ ]           │
│ Heroes        Unit       <none>     [x] Size: 12  │
│ GameTimer     Timer      <none>     [ ]           │
│                                                    │
│ [+ Add Variable]  [Delete]  [Rename]              │
└────────────────────────────────────────────────────┘
```

### API Design

```lua
local trigger_editor = require("editor.triggers")

-- Create trigger
local trigger = trigger_editor.create("My Trigger")

-- Add components via GUI operations
trigger_editor.add_event(trigger, "unit_dies", {})
trigger_editor.add_condition(trigger, "unit_owner_equals", {
    unit = "TriggeringUnit",
    player = 1,
})
trigger_editor.add_action(trigger, "set_variable", {
    variable = "KillCount",
    operator = "add",
    value = 1,
})

-- Convert to Lua source
local lua_source = trigger_editor.to_lua(trigger)

-- Parse Lua source back to GUI model
local trigger = trigger_editor.from_lua(lua_source)

-- Validate trigger
local errors = trigger_editor.validate(trigger)

-- Variables
trigger_editor.create_variable("KillCount", "integer", 0)
trigger_editor.create_variable("Heroes", "unit", nil, {array = true, size = 12})

-- Code view
trigger_editor.open_code_view(trigger)
trigger_editor.open_gui_view(trigger)
trigger_editor.sync_views()  -- Bidirectional sync
```

### Lua ↔ GUI Conversion

The GUI model maps to specific Lua patterns:

```lua
-- GUI: Event "A unit dies"
trigger:on("unit_dies", function(event) ... end)

-- GUI: Condition "Killing unit belongs to Player 1"
if event.killing_unit:get_owner() ~= Player(1) then return end

-- GUI: Action "Set KillCount = KillCount + 1"
KillCount = KillCount + 1

-- GUI: Control "If/Then/Else"
if condition then
    -- then actions
else
    -- else actions
end

-- GUI: Control "For each integer A from 1 to 10"
for A = 1, 10 do
    -- loop actions
end
```

Parsing Lua back to GUI:
- Pattern matching on AST
- Unrecognized patterns become "custom code" blocks
- Comments preserved as annotations

## Suggested Implementation Steps

1. Create `src/editor/triggers/` module structure
2. Define GUI block data model
3. Implement trigger list and category management
4. Implement event/condition/action block UI
5. Implement block editor popups
6. Implement variable manager
7. Implement Lua code view with syntax highlighting
8. Implement GUI → Lua conversion
9. Implement Lua → GUI parsing (pattern matching)
10. Implement bidirectional sync
11. Implement autocomplete for code view
12. Integrate with undo/redo
13. Create comprehensive tests

## Acceptance Criteria

- [ ] Triggers creatable with events, conditions, actions
- [ ] All WC3 trigger block types supported
- [ ] Variable manager functional
- [ ] Control structures work (if/else, loops)
- [ ] Lua code view with syntax highlighting
- [ ] Autocomplete in code view
- [ ] GUI → Lua conversion produces valid code
- [ ] Lua → GUI parsing works for standard patterns
- [ ] Unrecognized Lua becomes "custom code" block
- [ ] Bidirectional editing (change GUI, see in code; change code, see in GUI)
- [ ] All operations support undo/redo
- [ ] Trigger validation with error highlighting

## Related Documents

- `src/jass/` - JASS/Lua transpiler
- `src/runtime/triggers/` - Trigger runtime
- Phase 3 - Trigger system
- Issue 307 - Trigger framework

## Notes

- This is the most complex editor component
- Consider incremental parsing for large scripts
- May want "trigger templates" for common patterns
- Error highlighting in code view critical for usability
- Consider "trigger debugging" (breakpoints, step-through)
- Custom code blocks allow advanced users to bypass GUI limitations
- May want "convert to custom code" for any block
