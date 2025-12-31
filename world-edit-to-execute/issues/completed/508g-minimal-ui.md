# Issue 508g: Minimal UI

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 508d (map integration)

---

## Current Behavior

No UI. Game state is invisible to the user.

---

## Intended Behavior

Minimal HUD showing:
- Resource bar (top): Gold, Lumber, Food
- Selection panel (bottom): Selected unit info
- Simple text rendering

```
┌─────────────────────────────────────────────────────────┐
│  Gold: 500    Lumber: 200    Food: 5/12     Time: 1:23  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│                    [Game World]                         │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  Selected: Footman (1)    HP: 420/420    [Stop] [Hold]  │
└─────────────────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

### 1. UI State Structure (C)

```c
/* {{{ UIState */
typedef struct ui_state {
    // Resources (set by Lua)
    int gold;
    int lumber;
    int food_used;
    int food_cap;

    // Game time
    float game_time;

    // Selection info
    char selected_name[64];
    int selected_count;
    int selected_hp;
    int selected_hp_max;
} UIState;

UIState g_ui;
/* }}} */
```

### 2. UI Rendering (C)

```c
/* {{{ draw_ui */
void draw_ui(void) {
    int screen_w = GetScreenWidth();
    int screen_h = GetScreenHeight();

    // Resource bar (top)
    DrawRectangle(0, 0, screen_w, 30, (Color){20, 20, 30, 230});

    char buf[256];
    snprintf(buf, sizeof(buf), "Gold: %d    Lumber: %d    Food: %d/%d    Time: %.0f",
             g_ui.gold, g_ui.lumber, g_ui.food_used, g_ui.food_cap, g_ui.game_time);

    DrawText(buf, 10, 8, 16, GOLD);

    // Selection panel (bottom)
    if (g_ui.selected_count > 0) {
        int panel_y = screen_h - 50;
        DrawRectangle(0, panel_y, screen_w, 50, (Color){20, 20, 30, 230});

        snprintf(buf, sizeof(buf), "Selected: %s (%d)    HP: %d/%d",
                 g_ui.selected_name, g_ui.selected_count,
                 g_ui.selected_hp, g_ui.selected_hp_max);

        DrawText(buf, 10, panel_y + 15, 18, WHITE);
    }

    // FPS (debug)
    DrawFPS(screen_w - 80, 10);
}
/* }}} */
```

### 3. Lua Bridge for UI

```c
/* {{{ l_ui_set_resources */
// Lua: render.ui_set_resources(gold, lumber, food_used, food_cap)
static int l_ui_set_resources(lua_State* L) {
    g_ui.gold = luaL_checkinteger(L, 1);
    g_ui.lumber = luaL_checkinteger(L, 2);
    g_ui.food_used = luaL_checkinteger(L, 3);
    g_ui.food_cap = luaL_checkinteger(L, 4);
    return 0;
}
/* }}} */

/* {{{ l_ui_set_selection */
// Lua: render.ui_set_selection(name, count, hp, hp_max)
static int l_ui_set_selection(lua_State* L) {
    const char* name = luaL_checkstring(L, 1);
    strncpy(g_ui.selected_name, name, sizeof(g_ui.selected_name) - 1);
    g_ui.selected_count = luaL_checkinteger(L, 2);
    g_ui.selected_hp = luaL_checkinteger(L, 3);
    g_ui.selected_hp_max = luaL_checkinteger(L, 4);
    return 0;
}
/* }}} */

/* {{{ l_ui_set_game_time */
// Lua: render.ui_set_game_time(seconds)
static int l_ui_set_game_time(lua_State* L) {
    g_ui.game_time = luaL_checknumber(L, 1);
    return 0;
}
/* }}} */
```

### 4. Lua UI Update

```lua
-- src/demo/ui_updater.lua
-- {{{ ui_updater

local render = require("render")
local resources = require("runtime.resources")
local ecs = require("runtime.ecs")

local ui_updater = {}

-- {{{ ui_updater.update
function ui_updater.update(player_id, game_time)
    -- Update resources
    local gold = resources.get(player_id, "gold")
    local lumber = resources.get(player_id, "lumber")
    local food_used = resources.get(player_id, "food_used")
    local food_cap = resources.get(player_id, "food_cap")

    render.ui_set_resources(gold, lumber, food_used, food_cap)
    render.ui_set_game_time(game_time)
end
-- }}}

-- {{{ ui_updater.update_selection
function ui_updater.update_selection()
    local selected = render.get_selection()

    if #selected == 0 then
        render.ui_set_selection("", 0, 0, 0)
        return
    end

    -- Get first selected unit's info
    local entity_id = selected[1]
    local unit_type = ecs.get(entity_id, "unit_type")
    local stats = ecs.get(entity_id, "stats")

    local name = "Unit"
    if unit_type then
        name = unit_type.type_id or "Unit"
    end

    local hp = 100
    local hp_max = 100
    if stats then
        hp = stats.hp or 100
        hp_max = stats.hp_max or 100
    end

    render.ui_set_selection(name, #selected, hp, hp_max)
end
-- }}}

return ui_updater
-- }}}
```

### 5. Hook Into Selection Change

```lua
-- When selection changes, update UI
local function on_selection_changed()
    ui_updater.update_selection()
end

-- Call from input handler after selection changes
```

---

## Files to Create/Modify

- `src/render/ui.h` - UI state struct
- `src/render/ui.c` - UI rendering
- `src/render/bridge.c` - Add UI API
- `src/demo/ui_updater.lua` - Lua UI sync

---

## Acceptance Criteria

- [x] Resource bar displays at top
- [x] Gold, Lumber, Food values shown
- [x] Game time displayed
- [x] Selection panel shows when units selected
- [x] Selected unit name and count displayed
- [x] Selected unit HP displayed
- [x] UI updates when resources change
- [x] UI updates when selection changes
- [x] FPS counter visible (debug)

---

## Notes

This is intentionally minimal - just text. No images, no buttons (yet).
The goal is visibility into game state, not a polished interface.

More UI features (buttons, minimap) come in later issues.

---

## Related Documents

- `issues/508d-map-integration.md` - Map must be loaded
- `src/runtime/resources.lua` - Resource data source
- `src/runtime/ecs/` - Entity data source

---

## Implementation Notes

**Completed: 2025-12-31**

### Files Created

1. **`src/render/ui.h`** (~95 lines)
   - `UIState` struct with resources, game time, selection info
   - Configuration constants for bar heights and font sizes
   - Function declarations for init, draw, setters
   - Lua bridge function declarations

2. **`src/render/ui.c`** (~230 lines)
   - Global `g_ui` state with default values
   - `draw_resource_bar()` - semi-transparent bar at top with Gold/Lumber/Food/Time
   - `draw_selection_panel()` - bottom bar with unit name, count, HP bar
   - Color-coded HP bar (green > 60%, yellow > 30%, red < 30%)
   - Color-coded food display (red at cap, yellow almost full)
   - `format_time()` helper for MM:SS display
   - All 5 Lua bridge functions implemented

### Files Modified

1. **`src/render/bridge.c`**
   - Added `#include "ui.h"`
   - Registered 5 UI functions in render_funcs array

2. **`src/render/main.c`**
   - Added `#include "ui.h"`
   - Added `ui_init()` call after input_init()
   - Added `ui_draw()` call in 2D drawing phase
   - Added game time update via Lua update_game_time(dt)
   - Added selection change detection to call Lua on_selection_changed()
   - Updated debug HUD positions to offset below resource bar
   - Updated control hints for current functionality
   - Added Lua entity_info table with demo entity stats
   - Added on_selection_changed() Lua function for UI updates
   - Added update_game_time() Lua function for time display

3. **`src/render/run`**
   - Added ui.c to SOURCES list

### Demo Features

- **Resource Bar** (top, 30px height):
  - Gold: 500 (gold color)
  - Lumber: 150 (brown color)
  - Food: 0/12 (white, yellow at cap-2, red at cap)
  - Time: MM:SS format (right side)

- **Selection Panel** (bottom, 50px height):
  - Appears only when units selected
  - Shows unit name (e.g., "Red Warrior")
  - Shows count if multiple selected
  - Visual HP bar with color gradient

- **Demo Entity Stats**:
  - Red Warrior: 100/100 HP
  - Blue Mage: 80/80 HP
  - Green Scout: 60/60 HP
  - Yellow Guard: 120/120 HP

### Technical Notes

- UI state is global singleton (g_ui) for simplicity
- Lua updates flow through bridge functions to C state
- Selection change detection uses frame-to-frame count comparison
- Resource values are initialized with demo defaults, updatable via Lua
