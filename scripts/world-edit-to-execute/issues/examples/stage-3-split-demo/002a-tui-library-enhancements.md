# Issue 002a: TUI Library Enhancements

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** High
**Dependencies:** None

---

## Current Behavior

The TUI menu library (`libs/lua-menu.sh` and `libs/tui.lua`) provides basic menu functionality:
- Checkbox items that can be toggled
- Dependencies that disable items based on other items' state
- Section-based organization

However, it lacks several features needed for sophisticated menu interactions:
- No way to programmatically enable an item with visual feedback
- No "suggested" state (yellow highlight for recommended-but-optional items)
- No mid-process pause/prompt capability for batch operations
- No animation/flash capability for visual feedback
- No prerequisite chaining (selecting item X auto-enables item Y)

---

## Intended Behavior

Add five new genericizable functions to the TUI menu library:

### 1. Force Enable with Flash

```lua
menu_force_enable(item_id, flash_count, flash_color)
```

Programmatically enables an item and flashes it to draw attention. Used when selecting one option requires enabling another (e.g., "Generate Complete Issues" requires "Session Mode").

### 2. Suggested State

```lua
menu_add_dependency(item, trigger, trigger_value, "suggest", message, "yellow")
```

New dependency type that highlights an item in yellow when a trigger condition is met but the item itself is not yet selected. Indicates "you probably want this" without forcing it.

### 3. Batch Pause Prompt

```lua
menu_batch_pause(options_table)
-- e.g., {c = "continue", r = "read file", p = "provide context", s = "skip"}
-- Returns selected option key
```

Displays a mid-process prompt during batch operations, allowing user to continue, inject context, or abort.

### 4. Item Flash Animation

```lua
menu_flash_item(item_id, count, color, interval_ms)
```

Generic flash function that pulses an item's color. Foundation for force_enable feedback and rejection feedback (Issue 003).

### 5. Prerequisite Auto-Enable

```lua
menu_add_prerequisite(item_id, prerequisite_id)
```

When `item_id` is selected, `prerequisite_id` is automatically enabled (with flash feedback). Enables mode chaining.

---

## Suggested Implementation Steps

### Step 1: Implement `menu_flash_item()`

This is the foundation - other features use it.

```lua
-- In libs/tui.lua or libs/lua-menu.sh

function menu_flash_item(item_id, count, color, interval_ms)
    count = count or 2
    color = color or "red"
    interval_ms = interval_ms or 100

    local item = get_item_by_id(item_id)
    if not item then return end

    local original_color = item.color

    for i = 1, count do
        item.color = color
        render_menu()
        sleep_ms(interval_ms)
        item.color = original_color
        render_menu()
        sleep_ms(interval_ms)
    end
end
```

### Step 2: Implement `menu_force_enable()`

Uses flash to indicate the auto-enable action.

```lua
function menu_force_enable(item_id, flash_count, flash_color)
    flash_count = flash_count or 3
    flash_color = flash_color or "red"

    local item = get_item_by_id(item_id)
    if not item then return end

    -- Enable the item
    item.value = "1"  -- or true, depending on implementation

    -- Flash to draw attention
    menu_flash_item(item_id, flash_count, flash_color)
end
```

### Step 3: Implement suggested dependency type

Extend the dependency system to support "suggest" as a dependency behavior.

```lua
-- In dependency evaluation logic

if dep.behavior == "suggest" then
    if trigger_condition_met and item.value ~= "1" then
        item.highlight = dep.color or "yellow"
    else
        item.highlight = nil
    end
elseif dep.behavior == "disable" then
    -- existing disable logic
end
```

### Step 4: Implement `menu_add_prerequisite()`

Hook into item selection to trigger prerequisite enabling.

```lua
function menu_add_prerequisite(item_id, prerequisite_id)
    local item = get_item_by_id(item_id)
    item.prerequisites = item.prerequisites or {}
    table.insert(item.prerequisites, prerequisite_id)
end

-- In selection handler
function on_item_selected(item_id)
    local item = get_item_by_id(item_id)
    for _, prereq_id in ipairs(item.prerequisites or {}) do
        menu_force_enable(prereq_id, 3, "red")
    end
end
```

### Step 5: Implement `menu_batch_pause()`

Create a modal prompt overlay.

```lua
function menu_batch_pause(options)
    -- Build prompt string: "[c]ontinue | [r]ead file | [s]kip"
    local prompt_parts = {}
    for key, label in pairs(options) do
        table.insert(prompt_parts, string.format("[%s]%s", key, label))
    end
    local prompt = table.concat(prompt_parts, " | ")

    -- Display prompt and wait for valid key
    display_prompt(prompt)
    while true do
        local key = read_key()
        if options[key] then
            return key
        end
    end
end
```

### Step 6: Add unit tests

Test each function in isolation:
- Flash renders correctly
- Force enable changes state and flashes
- Suggested state applies yellow highlight correctly
- Prerequisites chain correctly
- Batch pause returns correct key

### Step 7: Update documentation

Add usage examples to library header comments.

---

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh` (bash wrapper)
- `/home/ritz/programming/ai-stuff/scripts/libs/tui.lua` (core Lua implementation)
- 002-generate-complete-issue-files.md (parent issue)
- 002b-script-integration.md (sibling - uses these features)
- Issue 003: Flash Disabled Items (uses `menu_flash_item`)

---

## Acceptance Criteria

- [ ] `menu_flash_item(item_id, count, color, interval_ms)` flashes specified item
- [ ] `menu_force_enable(item_id, flash_count, flash_color)` enables item with flash
- [ ] `menu_add_dependency(..., "suggest", ...)` creates yellow highlight for suggested items
- [ ] `menu_add_prerequisite(item, prereq)` auto-enables prereq when item selected
- [ ] `menu_batch_pause(options)` displays prompt and returns selected key
- [ ] All functions work with existing menu infrastructure
- [ ] Unit tests pass for each function
- [ ] Functions are documented with usage examples

---

## Notes

*These are generic TUI features - they should work for any script using the menu library, not just issue-splitter.*

*Flash timing (100ms default) should be perceptible but not annoying. May need tuning based on user feedback.*

*Consider accessibility: provide option to disable animations for users with photosensitivity (reference Issue 003 notes).*
