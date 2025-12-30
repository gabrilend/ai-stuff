# Issue 510e: UI State Persistence

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** Medium
**Dependencies:** 510a-510d

---

## Current Behavior

No UI state is saved between sessions or preserved across perspective switches.

---

## Intended Behavior

Comprehensive UI state persistence that:
- Saves player preferences across game sessions
- Preserves layout customizations
- Remembers action bar configurations
- Maintains window positions
- Syncs state across perspective switches

---

## State Categories

### 1. Per-Character State

Saved per character, persists across sessions:

```lua
character_state = {
    -- Action bar configurations
    action_bars = {
        bar1 = { slot1 = "ability_lightning_bolt", slot2 = "ability_heal", ... },
        bar2 = { ... },
        bar3 = { ... },
        bar4 = { ... },
    },

    -- Equipment sets
    equipment_sets = {
        ["Combat"] = { head = "item_123", chest = "item_456", ... },
        ["Gathering"] = { ... },
    },

    -- Quest tracking
    tracked_quests = { "quest_123", "quest_456" },

    -- Minimap settings
    minimap = {
        zoom_level = 1.5,
        tracking_enabled = { "herbs", "ore" },
    },

    -- Chat settings
    chat = {
        active_channels = { "general", "guild" },
        channel_colors = { ... },
    },
}
```

### 2. Account-Wide State

Shared across all characters:

```lua
account_state = {
    -- Keybindings
    keybinds = {
        move_forward = "W",
        action_bar_1 = "1",
        open_bags = "B",
        toggle_perspective = "F5",
        -- ... all bindings
    },

    -- UI layout preferences
    layout = {
        ui_scale = 1.0,
        minimap_position = "top_right",
        action_bar_position = "bottom_center",
    },

    -- Audio settings
    audio = {
        master_volume = 0.8,
        music_volume = 0.6,
        sfx_volume = 1.0,
    },

    -- Video settings
    video = {
        fullscreen = true,
        resolution = { 1920, 1080 },
        vsync = true,
    },

    -- Accessibility
    accessibility = {
        colorblind_mode = false,
        screen_shake = true,
        floating_combat_text = true,
    },
}
```

### 3. Session State

Not saved to disk, but preserved during gameplay:

```lua
session_state = {
    -- Control groups (Warlord mode)
    control_groups = {
        [1] = { entity_ids = {101, 102, 103} },
        [2] = { entity_ids = {104, 105} },
        -- ...
    },

    -- Current selection
    selection = {
        entities = { 101, 102 },
        subgroup_index = 1,
    },

    -- Camera positions
    camera = {
        warlord = { x = 0, y = 0, zoom = 1.0, angle = 60 },
        hero = { x = 100, y = 200, zoom = 0.5, angle = 45 },
    },

    -- Open windows
    open_windows = { "character_panel", "quest_log" },

    -- Current perspective
    perspective = "warlord",
}
```

---

## Persistence Format

### File Structure

```
save/
├── account.json           # Account-wide settings
└── characters/
    ├── thrall.json        # Character-specific state
    ├── jaina.json
    └── arthas.json
```

### JSON Schema (Character)

```json
{
    "version": 1,
    "character_name": "Thrall",
    "last_played": "2025-12-29T20:00:00Z",
    "action_bars": {
        "bar1": [
            {"slot": 1, "type": "ability", "id": "lightning_bolt"},
            {"slot": 2, "type": "item", "id": "healing_potion"},
            {"slot": 3, "type": "macro", "id": "macro_1"}
        ]
    },
    "tracked_quests": ["quest_slay_ogres", "quest_return_tome"],
    "minimap": {
        "zoom": 1.5,
        "tracking": ["herbs", "ore"]
    }
}
```

---

## State Operations

### Save/Load API

```lua
local persistence = require("ui.persistence")

-- Character state
persistence.save_character(character_name, state)
persistence.load_character(character_name) --> state or nil
persistence.delete_character(character_name)
persistence.list_characters() --> { "Thrall", "Jaina", ... }

-- Account state
persistence.save_account(state)
persistence.load_account() --> state

-- Session state (not persisted, but API for consistency)
persistence.save_session(state)  -- Stores in memory
persistence.load_session() --> state
persistence.clear_session()
```

### Auto-Save Triggers

```lua
AUTO_SAVE_TRIGGERS = {
    -- Periodic
    interval = 60,  -- Save every 60 seconds

    -- Event-based
    events = {
        "on_logout",
        "on_action_bar_change",
        "on_keybind_change",
        "on_settings_close",
        "on_perspective_switch",
    },

    -- Debounce rapid changes
    debounce = 1.0,  -- Wait 1 second after last change
}
```

---

## Default States

### First-Time Setup

```lua
function get_default_character_state(character_class)
    local defaults = {
        action_bars = get_class_default_bars(character_class),
        tracked_quests = {},
        minimap = {
            zoom = 1.0,
            tracking = {},
        },
    }
    return defaults
end

function get_default_account_state()
    return {
        keybinds = DEFAULT_KEYBINDS,
        layout = DEFAULT_LAYOUT,
        audio = { master = 0.8, music = 0.5, sfx = 1.0 },
        video = detect_optimal_settings(),
    }
end
```

### Class-Specific Defaults

```lua
CLASS_ACTION_BAR_DEFAULTS = {
    shaman = {
        bar1 = {
            [1] = "lightning_bolt",
            [2] = "flame_shock",
            [3] = "earth_shock",
            [4] = "healing_wave",
            -- ...
        },
    },
    warrior = {
        bar1 = {
            [1] = "charge",
            [2] = "heroic_strike",
            [3] = "thunder_clap",
            -- ...
        },
    },
    -- ...
}
```

---

## Cross-Perspective State

When switching between Warlord and Hero mode:

```lua
function on_perspective_switch(from_mode, to_mode)
    -- Save current mode's state
    session_state.perspectives[from_mode] = {
        camera = camera.save_state(),
        selection = selection.save_state(),
        open_windows = get_open_windows(),
    }

    -- Restore target mode's state
    local saved = session_state.perspectives[to_mode]
    if saved then
        camera.load_state(saved.camera)
        selection.load_state(saved.selection)
        restore_windows(saved.open_windows)
    end

    -- Shared state remains unchanged
    -- (chat, alerts, etc. don't need transition)
end
```

---

## Migration Support

Handle state format upgrades:

```lua
CURRENT_VERSION = 1

function migrate_state(state)
    local version = state.version or 0

    if version < 1 then
        -- Example migration from v0 to v1
        state.action_bars = convert_old_action_bar_format(state.abilities)
        state.abilities = nil
        state.version = 1
    end

    -- Future migrations
    -- if version < 2 then ... end

    return state
end
```

---

## Import/Export

Allow players to share configurations:

```lua
-- Export to shareable string
function export_action_bars()
    local data = persistence.load_character(current_character)
    local encoded = base64_encode(json_encode(data.action_bars))
    return encoded
end

-- Import from string
function import_action_bars(encoded_string)
    local decoded = json_decode(base64_decode(encoded_string))
    local current = persistence.load_character(current_character)
    current.action_bars = decoded
    persistence.save_character(current_character, current)
end
```

---

## Acceptance Criteria

- [ ] Character state saves and loads correctly
- [ ] Account state persists across all characters
- [ ] Session state preserved during gameplay
- [ ] Auto-save triggers on configured events
- [ ] Default states provided for new characters
- [ ] Class-specific action bar defaults work
- [ ] Perspective switch preserves per-mode state
- [ ] State migration handles version upgrades
- [ ] Import/export works for action bars
- [ ] Corrupt state files handled gracefully (fallback to defaults)
- [ ] Unit tests for state serialization

---

## Notes

State persistence is invisible when done right. Players don't think about it until
it breaks. The goal is zero surprises:
- Log out, log in → everything exactly as you left it
- Switch to Hero mode, switch back to Warlord → camera in same spot
- New character → sensible defaults that feel good immediately

The import/export feature enables community sharing of optimized action bar setups,
similar to WeakAuras or ElvUI profiles in WoW.

---

## Related Documents

- issues/510a-warlord-mode-ui.md (control groups, selection state)
- issues/510b-hero-mode-ui.md (action bars, equipment sets)
- issues/510c-perspective-switching.md (cross-mode state preservation)

