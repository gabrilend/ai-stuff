# Issue 510a: Warlord Mode UI (RTS Interface)

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** High
**Dependencies:** 506 (UI Framework), 510 (Root)

---

## Current Behavior

No RTS-style game interface exists.

---

## Intended Behavior

A complete Warcraft 3-style RTS interface for commanding armies from above.

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│ RESOURCE BAR                                                            │
│ [Icon] 1250    [Icon] 800    [Icon] 45/100         12:34  Day 1        │
│  Gold           Lumber        Food (used/cap)       Time   Day/Night   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                                                                         │
│                         GAME VIEWPORT                                   │
│                    (Isometric battlefield)                              │
│                                                                         │
│                    ┌─ Selection box ─┐                                  │
│                    │  ● ● ●          │                                  │
│                    │    ● ●          │                                  │
│                    └─────────────────┘                                  │
│                                                                         │
├────────────────┬──────────────────────────┬─────────────────────────────┤
│   MINIMAP      │     INFO PANEL           │    COMMAND PANEL            │
│                │                          │                             │
│  ┌──────────┐  │  ┌────────────────────┐  │  ┌───┬───┬───┬───┐         │
│  │    N     │  │  │   [Portrait]       │  │  │ Q │ W │ E │ R │         │
│  │  ▲       │  │  │                    │  │  ├───┼───┼───┼───┤         │
│  │ ●  ●     │  │  │   Grunt            │  │  │ A │ S │ D │ F │         │
│  │    ●●    │  │  │   Level 2          │  │  ├───┼───┼───┼───┤         │
│  │  W ─┼─ E │  │  │                    │  │  │ Z │ X │ C │ V │         │
│  │    ▼     │  │  │   HP: ████░░ 80%   │  │  └───┴───┴───┴───┘         │
│  │    S     │  │  │   MP: ██░░░░ 40%   │  │                             │
│  └──────────┘  │  │                    │  │  [Selected: 12 Grunts]     │
│                │  │   Armor: 2         │  │  [Group: 1]                │
│  [Terrain]     │  │   Attack: 12-15    │  │                             │
│  [Signals]     │  │   Speed: 270       │  │  [Build] [Rally] [Patrol]  │
└────────────────┴──────────────────────────┴─────────────────────────────┘
```

---

## Components

### 1. Resource Bar (Top)
```lua
resource_bar = {
    gold = { icon = "gold", value = 0, flash_on_insufficient = true },
    lumber = { icon = "lumber", value = 0, flash_on_insufficient = true },
    food = {
        icon = "food",
        used = 0,
        cap = 0,
        color_thresholds = {
            {0.5, "green"},   -- Under 50% = green
            {0.8, "yellow"},  -- Under 80% = yellow
            {1.0, "red"},     -- At cap = red
        }
    },
    upkeep = { icon = "upkeep", level = "none" }, -- none/low/high
    game_time = { format = "mm:ss", show_day_night = true },
}
```

### 2. Minimap Panel (Bottom-Left)
```lua
minimap = {
    size = {160, 160},
    features = {
        terrain = true,       -- Background terrain colors
        fog_of_war = true,    -- Unexplored/hidden areas
        units = true,         -- Colored dots for units
        buildings = true,     -- Building footprints
        pings = true,         -- Player signals
        camera_box = true,    -- Current viewport indicator
    },
    interactions = {
        left_click = "move_camera",
        right_click = "move_selected",
        alt_click = "ping",
    },
}
```

### 3. Info Panel (Bottom-Center)
```lua
info_panel = {
    modes = {
        single_unit = {
            portrait = true,
            name = true,
            level = true,
            hp_bar = true,
            mp_bar = true,
            stats = {"armor", "attack", "speed"},
            buffs = true,
        },
        multi_unit = {
            unit_icons = true,  -- Grid of selected unit icons
            max_display = 12,   -- Show up to 12, scroll for more
            group_stats = true, -- Aggregate HP, average level
        },
        building = {
            portrait = true,
            name = true,
            hp_bar = true,
            build_queue = true, -- Training queue
            rally_point = true,
        },
    },
}
```

### 4. Command Panel (Bottom-Right)
```lua
command_panel = {
    grid = {4, 3},  -- 4 columns, 3 rows = 12 buttons

    -- Hotkey layout (matches WC3)
    hotkeys = {
        {"Q", "W", "E", "R"},
        {"A", "S", "D", "F"},
        {"Z", "X", "C", "V"},
    },

    -- Button states
    button_states = {
        normal = {},
        hover = {highlight = true},
        pressed = {darken = true},
        disabled = {grayscale = true},
        cooldown = {sweep_overlay = true, timer_text = true},
        autocast_on = {border_glow = "blue"},
        autocast_off = {border_glow = none},
    },

    -- Context sensitivity
    contexts = {
        unit_selected = "abilities",
        building_selected = "build_options",
        hero_selected = "hero_abilities",
        nothing_selected = "global_commands",
    },
}
```

### 5. Selection Display
```lua
selection = {
    -- Box selection
    box = {
        color = {0, 255, 0, 128},  -- Green, semi-transparent
        border = 2,
    },

    -- Selected unit circles
    circles = {
        friendly = {0, 255, 0},   -- Green
        enemy = {255, 0, 0},       -- Red
        neutral = {255, 255, 0},   -- Yellow
    },

    -- Group hotkeys (Ctrl+1-9 to set, 1-9 to recall)
    groups = {
        max_groups = 9,
        double_tap_centers = true,  -- Double-tap centers camera
    },
}
```

### 6. Hero-Specific Elements
```lua
hero_panel = {
    -- Hero portrait shows level and XP
    xp_bar = true,

    -- Inventory (6 slots, 2x3)
    inventory = {
        slots = 6,
        layout = {2, 3},
        hotkeys = {"Numpad7", "Numpad8", "Numpad4", "Numpad5", "Numpad1", "Numpad2"},
    },

    -- Attribute display
    attributes = {
        strength = {icon = "str", color = "red"},
        agility = {icon = "agi", color = "green"},
        intelligence = {icon = "int", color = "blue"},
    },

    -- Skill points indicator
    skill_points = {
        show_when_available = true,
        glow_animation = true,
    },
}
```

---

## Keybindings (Warlord Mode)

| Key | Action |
|-----|--------|
| Left Click | Select unit / Issue order target |
| Right Click | Smart order (move/attack/harvest) |
| Shift+Click | Queue order / Add to selection |
| Ctrl+Click | Subgroup select (same unit type) |
| Ctrl+1-9 | Assign control group |
| 1-9 | Select control group |
| Double 1-9 | Center camera on group |
| Tab | Cycle subgroups |
| Esc | Cancel current order / Deselect |
| Space | Center on last alert |
| F1-F3 | Select hero 1-3 |
| Q/W/E/R/A/S/D/F/Z/X/C/V | Command buttons |

---

## Multi-Selection Logic

```lua
-- Selection priority (when clicking single unit in group)
SELECTION_PRIORITY = {
    hero = 1,      -- Heroes first
    unit = 2,      -- Then units
    worker = 3,    -- Workers last
    building = 4,  -- Buildings separate
}

-- Subgroup cycling
function get_subgroups(selection)
    -- Group by unit_type_id
    local subgroups = {}
    for _, unit in ipairs(selection) do
        local type_id = unit.type_id
        subgroups[type_id] = subgroups[type_id] or {}
        table.insert(subgroups[type_id], unit)
    end
    return subgroups
end
```

---

## Visual Feedback

| Event | Feedback |
|-------|----------|
| Insufficient gold | Gold text flashes red |
| Unit taking damage | Portrait flashes red, HP bar animates |
| Ability ready | Button glow pulse |
| Building complete | Alert sound + minimap ping |
| Unit created | Minimap blip |
| Upkeep threshold | Upkeep icon changes color |

---

## Acceptance Criteria

- [ ] Resource bar displays gold, lumber, food correctly
- [ ] Food shows used/cap and changes color at thresholds
- [ ] Minimap renders terrain and unit positions
- [ ] Minimap responds to clicks (camera, orders, pings)
- [ ] Info panel adapts to single unit, multi-unit, building contexts
- [ ] Command panel shows correct abilities per selection
- [ ] Command buttons respond to hotkeys
- [ ] Box selection works with drag
- [ ] Control groups (Ctrl+1-9, 1-9) work
- [ ] Tab cycles through subgroups
- [ ] Hero inventory displays and is usable
- [ ] Visual feedback for all major events
- [ ] Unit tests for selection logic

---

## Notes

The Warlord UI is about **efficiency and control**. Every pixel serves a purpose.
Information density is high because commanders need to process many units quickly.

The command grid's hotkey layout (QWER, ASDF, ZXCV) is muscle memory for millions
of players. Respect it.

