# Issue 510b: Hero Mode UI (RPG Interface)

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** High
**Dependencies:** 506 (UI Framework), 510 (Root)

---

## Current Behavior

No RPG-style game interface exists.

---

## Intended Behavior

A World of Warcraft-style RPG interface for playing as a single hero character.

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────────────────┐
│ PLAYER FRAME                              TARGET FRAME           MINIMAP│
│ ┌─────────────────────┐                  ┌─────────────────────┐ ┌────┐│
│ │[Port] Thrall    Lv42│                  │[Port] Ogre Mauler   │ │    ││
│ │ HP ████████████░░░░ │                  │ HP ██████████░░░░░░ │ │ ▲  ││
│ │ MP ██████░░░░░░░░░░ │                  │ MP ░░░░░░░░░░░░░░░░ │ │  ● ││
│ │ [Buffs: ⚔ 🛡 ✨]    │                  │ [Debuffs: 🔥 ☠]     │ └────┘│
│ └─────────────────────┘                  └─────────────────────┘       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                                                                         │
│                                                                         │
│                        GAME VIEWPORT                                    │
│                   (Third-person camera)                                 │
│                                                                         │
│                          ┌───┐                                          │
│                          │ ● │  ← Your character                        │
│                          └───┘                                          │
│                                                                   ┌─────┤
│                                                                   │QUEST│
│                                                                   │TRACK│
│                                                                   │     │
│                                                                   │○ Sla│
│                                                                   │  Ogr│
│                                                                   │  3/5│
│                                                                   │     │
│                                                                   │○ Ret│
│                                                                   │  to │
│                                                                   │  Thr│
├───────────────────────────────────────────────────────────────────┴─────┤
│  CHAT                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │ [General] Player1: LFG Deadmines                                    ││
│  │ [Guild] Officer: Raid at 8pm                                        ││
│  └─────────────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────────────┤
│  ACTION BAR 1                                                           │
│  ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐  [Bags][Char][Menu] │
│  │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │ 0 │ - │ = │                     │
│  └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘                     │
│  ACTION BAR 2 (Shift+)                                                  │
│  ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐                     │
│  │S+1│S+2│S+3│S+4│S+5│S+6│S+7│S+8│S+9│S+0│S+-│S+=│                     │
│  └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘                     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. Player Frame (Top-Left)
```lua
player_frame = {
    portrait = {
        size = {64, 64},
        show_class_icon = true,
        flash_on_damage = true,
        gray_when_dead = true,
    },

    name = {
        font_size = 14,
        show_level = true,
        show_guild = false,  -- Optional
    },

    health_bar = {
        width = 200,
        height = 24,
        show_text = true,         -- "2450 / 2800"
        show_percent = false,     -- Or "87%"
        color = "class_color",    -- Or fixed green
        deficit_color = "red",    -- Missing HP portion
    },

    mana_bar = {
        width = 200,
        height = 16,
        resource_type = "mana",   -- mana/rage/energy/runic_power
        color = "resource_color", -- Blue for mana, red for rage, etc.
    },

    -- Secondary resource (combo points, holy power, etc.)
    secondary_resource = {
        type = nil,  -- Set per class
        display = "pips",  -- pips, bar, or stacks
    },

    buff_bar = {
        position = "below",
        max_display = 16,
        show_duration = true,
        highlight_dispellable = true,
    },
}
```

### 2. Target Frame (Top-Center/Right)
```lua
target_frame = {
    -- Mirror of player frame structure
    portrait = { size = {64, 64} },
    name = { show_level = true, show_elite = true },
    health_bar = { show_percent = true },

    -- Target-specific
    reaction = {
        friendly = "green",
        neutral = "yellow",
        hostile = "red",
    },

    -- Rare/Elite indicator
    classification = {
        normal = nil,
        elite = "gold_dragon",
        rare = "silver_dragon",
        rare_elite = "silver_dragon_gold_border",
        boss = "skull",
    },

    -- Debuffs you applied
    debuff_bar = {
        filter = "player",  -- Only show your debuffs
        position = "below",
    },

    -- Casting bar
    cast_bar = {
        show = true,
        interruptible = { color = "yellow" },
        uninterruptible = { color = "gray", shield_icon = true },
    },
}
```

### 3. Action Bars (Bottom)
```lua
action_bars = {
    -- Primary bar (always visible)
    bar1 = {
        slots = 12,
        hotkeys = {"1","2","3","4","5","6","7","8","9","0","-","="},
        position = "bottom_center",
        show_hotkey_text = true,
        show_cooldown = true,
        show_range = true,  -- Red tint when out of range
        show_usable = true, -- Desaturate when unusable
    },

    -- Secondary bar (Shift modifier)
    bar2 = {
        slots = 12,
        modifier = "shift",
        position = "above_bar1",
        visible = true,  -- Can be toggled
    },

    -- Additional bars (configurable)
    bar3 = { modifier = "ctrl", visible = false },
    bar4 = { modifier = "alt", visible = false },

    -- Stance/form bar
    stance_bar = {
        position = "left_of_bar1",
        visible_when = "has_stances",
    },

    -- Pet bar
    pet_bar = {
        position = "above_stance",
        visible_when = "has_pet",
    },
}
```

### 4. Minimap (Top-Right)
```lua
minimap = {
    shape = "circle",  -- Classic WoW circular minimap
    size = 140,

    features = {
        terrain = true,
        player_arrow = true,    -- "You are here" indicator
        party_members = true,
        tracking_icons = true,  -- Herbs, ore, etc.
        quest_objectives = true,
        zone_name = true,       -- Text above minimap
    },

    buttons = {
        zoom_in = true,
        zoom_out = true,
        calendar = true,  -- Or clock
        tracking = true,  -- Tracking type selector
    },

    border = "ornate",  -- Decorative frame
}
```

### 5. Quest Tracker (Right Side)
```lua
quest_tracker = {
    position = "right",
    width = 250,
    max_quests = 5,  -- Auto-collapse if more

    quest_display = {
        show_title = true,
        show_objectives = true,
        show_progress = true,  -- "3/5 Ogres slain"
        collapse_complete = true,
    },

    interactions = {
        click = "open_quest_log",
        shift_click = "untrack",
    },
}
```

### 6. Chat Window (Bottom-Left)
```lua
chat = {
    position = "bottom_left",
    size = {400, 150},

    tabs = {
        general = { channels = {"say", "yell", "general", "trade"} },
        combat = { channels = {"combat_log"} },
        whisper = { channels = {"whisper"} },
    },

    input = {
        position = "below_messages",
        slash_commands = true,  -- /say, /guild, /whisper
    },

    formatting = {
        timestamps = false,
        class_colors = true,
        clickable_links = true,
        clickable_names = true,
    },
}
```

### 7. Bags / Inventory
```lua
inventory = {
    bag_bar = {
        position = "bottom_right",
        slots = 5,  -- Backpack + 4 bags
    },

    bag_windows = {
        open_all_hotkey = "B",
        open_direction = "up",  -- Stack upward from bag bar
        slot_size = 37,
        columns = 4,  -- Per bag (16-slot = 4x4)
    },

    currency = {
        show_gold = true,
        show_silver = true,
        show_copper = true,
    },
}
```

### 8. Character Panel
```lua
character_panel = {
    hotkey = "C",

    tabs = {
        stats = {
            primary = {"strength", "agility", "stamina", "intellect", "spirit"},
            secondary = {"crit", "haste", "mastery", "versatility"},
            defense = {"armor", "dodge", "parry", "block"},
        },
        equipment = {
            slots = {
                "head", "neck", "shoulder", "back", "chest",
                "wrist", "hands", "waist", "legs", "feet",
                "finger1", "finger2", "trinket1", "trinket2",
                "main_hand", "off_hand", "ranged",
            },
            show_item_level = true,
        },
        reputation = {},
        titles = {},
    },
}
```

---

## Keybindings (Hero Mode)

| Key | Action |
|-----|--------|
| W/A/S/D | Move forward/left/backward/right |
| Space | Jump |
| Left Click | Target / Interact |
| Right Click | Auto-attack / Context action |
| Tab | Target nearest enemy |
| Esc | Clear target / Close window |
| 1-0, -, = | Action bar 1 |
| Shift+1-0 | Action bar 2 |
| F1 | Target self |
| F2-F5 | Target party member 1-4 |
| B | Open bags |
| C | Open character panel |
| M | Open world map |
| L | Open quest log |
| P | Open spellbook |
| Enter | Open chat |
| / | Open chat with slash |

---

## Combat Feedback

| Event | Feedback |
|-------|----------|
| Taking damage | Screen edge red flash, portrait shake |
| Low health | Heartbeat sound, screen vignette |
| Ability on cooldown | Error sound, cooldown sweep on button |
| Out of range | Ability icon tinted red |
| Out of mana | Ability icon desaturated |
| Critical hit | Floating combat text, screen shake |
| Level up | Fanfare, golden glow |
| Quest complete | Fanfare, tracker update |

---

## Floating Combat Text
```lua
combat_text = {
    position = "above_character",

    damage = {
        outgoing = { color = "white", size = "normal" },
        outgoing_crit = { color = "yellow", size = "large", prefix = "*" },
        incoming = { color = "red", direction = "down" },
    },

    healing = {
        outgoing = { color = "green" },
        incoming = { color = "green", prefix = "+" },
    },

    status = {
        miss = { color = "white", text = "Miss" },
        dodge = { color = "white", text = "Dodge" },
        parry = { color = "white", text = "Parry" },
        immune = { color = "purple", text = "Immune" },
    },
}
```

---

## Acceptance Criteria

- [ ] Player frame shows health, mana, buffs correctly
- [ ] Target frame shows enemy health, debuffs, cast bar
- [ ] Action bars respond to keybindings
- [ ] Action bar shows cooldowns, range, usability state
- [ ] Minimap renders and shows player position
- [ ] Quest tracker displays active quests
- [ ] Chat window works with multiple channels
- [ ] Bags open and display inventory
- [ ] Character panel shows stats and equipment
- [ ] Floating combat text displays damage/healing
- [ ] WASD movement controls work
- [ ] Tab targeting cycles enemies
- [ ] Unit tests for UI state management

---

## Notes

The Hero UI is about **immersion and personal investment**. You ARE this character.
The interface should make you feel powerful and connected to your hero.

Unlike Warlord mode's efficiency focus, Hero mode can be more spacious. The player
has fewer things to track (one character vs an army) so information can breathe.

WoW's brilliance was making the MMO interface feel like home. After a few hours,
the action bars become extensions of your will.

---

## AzerothCore Integration Note

This UI can be rendered by:
1. **Raylib** (our engine) - for standalone play
2. **AzerothCore client** - via protocol translation

The data structures should be game-agnostic so either renderer can consume them.

