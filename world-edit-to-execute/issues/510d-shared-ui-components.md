# Issue 510d: Shared UI Components

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** Medium
**Dependencies:** 506 (UI Framework), 510 (Root)

---

## Current Behavior

No shared UI components exist between perspectives.

---

## Intended Behavior

UI components that function identically (or very similarly) in both Warlord and
Hero modes, reducing code duplication and providing consistency.

---

## Shared Components

### 1. Minimap

The minimap exists in both modes but with different presentations:

```lua
minimap_shared = {
    -- Core functionality (shared)
    core = {
        terrain_rendering = true,
        unit_dots = true,
        fog_of_war = true,
        camera_indicator = true,
        click_to_move_camera = true,
    },

    -- Mode-specific presentation
    warlord_style = {
        shape = "square",
        position = "bottom_left",
        size = {160, 160},
        border = "stone_frame",
    },

    hero_style = {
        shape = "circle",
        position = "top_right",
        size = 140,  -- diameter
        border = "ornate_gold",
        player_arrow = true,  -- "You are here" facing indicator
    },
}
```

### 2. Chat Window

Chat is identical in both modes:

```lua
chat = {
    position = "bottom_left",  -- Same in both modes
    size = {400, 150},

    channels = {
        say = { color = "white", prefix = "[Say]" },
        yell = { color = "red", prefix = "[Yell]" },
        whisper = { color = "pink", prefix = "[Whisper]" },
        party = { color = "light_blue", prefix = "[Party]" },
        guild = { color = "green", prefix = "[Guild]" },
        general = { color = "orange", prefix = "[General]" },
        trade = { color = "gray", prefix = "[Trade]" },
    },

    input = {
        hotkey = "Enter",
        slash_commands = {
            ["/s"] = "say",
            ["/y"] = "yell",
            ["/p"] = "party",
            ["/g"] = "guild",
            ["/w"] = "whisper",
            ["/r"] = "reply",
        },
    },

    -- Integration with AzerothCore chat
    azerothcore_bridge = {
        enabled = true,
        sync_channels = true,
    },
}
```

### 3. Alert/Notification System

```lua
alerts = {
    -- Alert types
    types = {
        unit_under_attack = {
            icon = "sword",
            sound = "warning",
            minimap_ping = true,
            priority = "high",
        },
        building_complete = {
            icon = "hammer",
            sound = "complete",
            minimap_ping = false,
            priority = "medium",
        },
        resource_depleted = {
            icon = "gold",
            sound = "ding",
            minimap_ping = true,
            priority = "low",
        },
        quest_objective_update = {
            icon = "quest",
            sound = "quest_update",
            tracker_flash = true,
            priority = "low",
        },
    },

    -- Display area
    queue = {
        position = "center_left",
        max_visible = 3,
        duration = 5.0,
        stack_similar = true,
    },

    -- "Space to center" feature
    space_centers = true,
    center_history = [],  -- Stack of alert locations
}
```

### 4. Tooltip System

```lua
tooltip = {
    delay = 0.5,  -- Seconds before showing
    position = "follow_cursor",
    offset = {16, 16},

    -- Shared tooltip types
    types = {
        ability = {
            fields = {"name", "cost", "cooldown", "range", "description"},
            show_hotkey = true,
        },
        unit = {
            fields = {"name", "level", "hp", "abilities"},
        },
        item = {
            fields = {"name", "quality", "item_level", "stats", "effects"},
            compare_equipped = true,  -- Show comparison if relevant
        },
        buff = {
            fields = {"name", "duration", "effect", "source"},
        },
    },

    -- Rich text formatting
    formatting = {
        quality_colors = {
            poor = "gray",
            common = "white",
            uncommon = "green",
            rare = "blue",
            epic = "purple",
            legendary = "orange",
        },
        stat_colors = {
            positive = "green",
            negative = "red",
        },
    },
}
```

### 5. Buff/Debuff Display

```lua
buff_display = {
    -- Buff bar (appears on frames)
    bar = {
        icon_size = 24,
        max_icons = 16,
        wrap = false,
        show_duration = true,  -- Time remaining text
        show_stacks = true,    -- Stack count if applicable
    },

    -- Duration display modes
    duration = {
        format = "seconds",   -- Or "minutes" or "smart"
        threshold = {
            show_text = 60,   -- Show text if < 60 seconds
            show_sweep = 10,  -- Show sweep animation if < 10 seconds
        },
    },

    -- Categorization
    categories = {
        buff = { border = "green" },
        debuff = { border = "red" },
        magic = { border = "blue" },
        poison = { border = "dark_green" },
        disease = { border = "brown" },
        curse = { border = "purple" },
    },
}
```

### 6. Menu System

```lua
menu = {
    -- Game menu (Esc)
    game_menu = {
        hotkey = "Escape",
        options = {
            "Return to Game",
            "Options",
            "Key Bindings",
            "Sound Options",
            "Video Options",
            "Help",
            "Exit Game",
        },
    },

    -- Right-click context menu
    context_menu = {
        unit = {"Attack", "Follow", "Patrol", "Hold Position"},
        friendly_unit = {"Heal", "Buff", "Trade", "Follow"},
        npc = {"Talk", "Trade", "Attack"},
        player = {"Whisper", "Invite", "Inspect", "Trade"},
        item = {"Use", "Equip", "Drop", "Destroy"},
    },
}
```

### 7. Error/Status Messages

```lua
status_messages = {
    position = "top_center",
    duration = 3.0,

    categories = {
        error = {
            color = "red",
            sound = "error",
            examples = {"Not enough gold", "Ability not ready", "Out of range"},
        },
        info = {
            color = "yellow",
            sound = nil,
            examples = {"Inventory full", "Target is friendly"},
        },
        success = {
            color = "green",
            sound = "success",
            examples = {"Quest accepted", "Item purchased"},
        },
    },

    -- Throttle repeated messages
    throttle = {
        enabled = true,
        window = 2.0,  -- Don't repeat same message within 2 seconds
    },
}
```

### 8. Confirmation Dialogs

```lua
dialogs = {
    confirm = {
        layout = "modal",
        buttons = {"Accept", "Cancel"},
        default = "Cancel",  -- Esc selects this

        templates = {
            delete_item = "Destroy {item_name}?",
            quit_game = "Are you sure you want to quit?",
            abandon_quest = "Abandon {quest_name}?",
            spend_resources = "Spend {gold} gold?",
        },
    },

    input = {
        layout = "modal",
        text_field = true,

        templates = {
            set_rally = "Set rally point name:",
            rename_group = "Rename control group:",
        },
    },
}
```

### 9. Loading/Progress Indicators

```lua
loading = {
    -- Full screen loading
    screen = {
        background = "loading_bg",
        progress_bar = true,
        tips = true,  -- Show gameplay tips
    },

    -- In-game progress (training, building, etc.)
    progress = {
        bar = {
            height = 8,
            color = "gold",
            background = "dark_gray",
        },
        percentage = {
            show = true,
            format = "percent",  -- Or "time_remaining"
        },
    },
}
```

### 10. Ping System

```lua
ping = {
    hotkeys = {
        generic = "G",          -- Click to ping location
        attack = "Ctrl+G",      -- "Attack here"
        defend = "Alt+G",       -- "Defend here"
        help = "Shift+G",       -- "Need help here"
    },

    visual = {
        ring_animation = true,
        minimap_indicator = true,
        duration = 5.0,
    },

    audio = {
        generic = "ping",
        attack = "attack_ping",
        defend = "defend_ping",
        help = "help_ping",
    },

    -- Smart ping (context-aware)
    smart_ping = {
        over_enemy = "attack",
        over_ally = "defend",
        over_ground = "generic",
    },
}
```

---

## Component Architecture

```lua
-- Shared component base class
SharedComponent = {
    -- Core interface
    update = function(self, dt) end,
    render = function(self) end,
    on_input = function(self, event) end,

    -- Mode adaptation
    apply_mode = function(self, mode)
        local style = self.styles[mode]
        if style then
            self.position = style.position or self.position
            self.size = style.size or self.size
            self.appearance = style.appearance or self.appearance
        end
    end,

    -- State serialization
    save_state = function(self) end,
    load_state = function(self, state) end,
}
```

---

## Acceptance Criteria

- [ ] Minimap works in both modes with appropriate styling
- [ ] Chat window functions identically in both modes
- [ ] Alert queue works with space-to-center
- [ ] Tooltips display for abilities, units, items, buffs
- [ ] Buff/debuff icons show duration and stacks
- [ ] Game menu accessible via Escape
- [ ] Context menus appear on right-click
- [ ] Error messages display and throttle correctly
- [ ] Confirmation dialogs work for destructive actions
- [ ] Ping system works with minimap integration
- [ ] All components persist state across mode switches
- [ ] Unit tests for shared component behavior

---

## Notes

Shared components are the glue between modes. By making chat, alerts, and tooltips
work identically, players feel like they're in one unified game, not two different
interfaces bolted together.

The key principle: **same data, different presentation**. A buff is a buff whether
you're commanding an army or swinging a sword. The component handles both.

