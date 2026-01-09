# Issue 702g: Profession UI Abstraction Layer

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Feature
**Priority:** Medium
**Dependencies:** 702a-f (Full profession system), 506 (UI Framework)

---

## Current Behavior

No UI abstraction for profession systems. Different modes (WoW/WC3) would
need completely separate UI implementations.

---

## Intended Behavior

An abstraction layer that presents profession data to UI systems, allowing
the same underlying profession engine to render as:
- WoW-style profession window (skill bars, recipe lists, trainers)
- WC3-style command cards (ability icons, upgrade buttons, building queues)
- Custom presentations (hybrid modes, mobile layouts)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      UI ABSTRACTION LAYER                        │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    ProfessionUIProvider                      ││
│  │                                                              ││
│  │  - Queries profession state                                  ││
│  │  - Formats data for display                                  ││
│  │  - Handles mode-specific transformations                     ││
│  │  - Emits UI events                                           ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                   │
│          ┌───────────────────┼───────────────────┐              │
│          ▼                   ▼                   ▼              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐        │
│  │  WoW Renderer│   │ WC3 Renderer │   │Custom Renderer│        │
│  │              │   │              │   │              │        │
│  │ - Skill bars │   │ - Cmd cards  │   │ - Minimal    │        │
│  │ - Recipe list│   │ - Upgrade btns│  │ - Mobile     │        │
│  │ - Trainer UI │   │ - Build queue│   │ - Chat-based │        │
│  └──────────────┘   └──────────────┘   └──────────────┘        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## UI Provider Interface

```lua
-- {{{ ProfessionUIProvider
local ProfessionUIProvider = {}

-- {{{ Initialization
function ProfessionUIProvider:new(entity, mode)
    local provider = {
        entity = entity,
        mode = mode or "wow",  -- "wow", "wc3", "minimal"
        cache = {},
        dirty = true,
    }
    setmetatable(provider, {__index = self})
    return provider
end
-- }}}

-- {{{ Profession List
function ProfessionUIProvider:get_professions()
    -- Returns list of professions for this entity
    -- Format adapts to mode
    return {
        {
            id = "blacksmithing",
            name = "Blacksmithing",
            icon = "icon_blacksmithing",
            skill_current = 215,
            skill_max = 300,
            skill_percent = 0.72,
            tier = "Artisan",
            specialization = "Armorsmith",
            is_primary = true,
        },
        -- ...
    }
end
-- }}}

-- {{{ Recipe List
function ProfessionUIProvider:get_recipes(profession_id, filter)
    -- Returns recipes for display
    -- filter: "all", "craftable", "by_category", "favorites"
    return {
        {
            id = "iron_sword",
            name = "Iron Sword",
            icon = "icon_iron_sword",
            category = "weapon",
            difficulty = "yellow",      -- Color for skill-up chance
            skill_required = 100,
            can_craft = true,
            has_materials = true,
            cooldown_remaining = 0,

            -- Material preview
            reagents = {
                {item = "iron_bar", icon = "icon_iron_bar", have = 12, need = 4},
                {item = "coal", icon = "icon_coal", have = 5, need = 2},
            },
        },
        -- ...
    }
end
-- }}}

-- {{{ Recipe Details
function ProfessionUIProvider:get_recipe_details(recipe_id)
    -- Full recipe information for detail panel
    return {
        id = "iron_sword",
        name = "Iron Sword",
        description = "A sturdy sword forged from iron.",
        icon = "icon_iron_sword",

        skill_required = 100,
        difficulty_color = "yellow",
        skillup_chance = 0.75,

        cast_time = 3.0,
        cooldown = 0,

        reagents = { ... },
        optional_reagents = { ... },

        output = {
            item = "iron_sword",
            count = 1,
            item_link = "[Iron Sword]",
        },

        source = "Trainer: Expert Blacksmith",
        times_crafted = 47,
    }
end
-- }}}

-- {{{ Trainer Interface
function ProfessionUIProvider:get_trainer_data(trainer_entity)
    -- Data for trainer window
    return {
        trainer_name = "Bengus Deepforge",
        profession = "Blacksmithing",
        tier = "Artisan",

        can_train_tier = true,
        tier_cost = {gold = 50000},

        available_recipes = { ... },
        unavailable_recipes = { ... },  -- Shown grayed out
    }
end
-- }}}

-- {{{ WC3-Specific: Command Card
function ProfessionUIProvider:get_command_card(unit_or_building)
    -- Returns command card layout for WC3 mode
    return {
        -- Row 1: Main abilities
        {
            {cmd = "harvest", icon = "icon_harvest", hotkey = "G"},
            {cmd = "repair", icon = "icon_repair", hotkey = "R"},
            {cmd = "build", icon = "icon_build", hotkey = "B"},
            nil,
        },
        -- Row 2: Context-specific
        { ... },
        -- Row 3: Cancel/Rally
        { ... },
    }
end
-- }}}

-- {{{ WC3-Specific: Building Queue
function ProfessionUIProvider:get_production_queue(building)
    return {
        current = {
            type = "unit",
            id = "footman",
            name = "Footman",
            icon = "icon_footman",
            progress = 0.65,
            time_remaining = 7,
        },
        queue = {
            {type = "unit", id = "footman", icon = "icon_footman"},
            {type = "unit", id = "rifleman", icon = "icon_rifleman"},
        },
        max_queue = 5,
    }
end
-- }}}

-- {{{ WC3-Specific: Upgrade Panel
function ProfessionUIProvider:get_upgrades(building)
    return {
        available = {
            {
                id = "iron_swords",
                name = "Iron Forged Swords",
                icon = "icon_iron_swords",
                cost = {gold = 100, lumber = 50},
                time = 60,
                hotkey = "S",
                tooltip = "+1 Attack Damage to melee units",
            },
            -- ...
        },
        researching = nil,  -- Current research in progress
        completed = {"steel_armor"},  -- Already researched
    }
end
-- }}}
-- }}}
```

---

## Mode-Specific Renderers

### WoW Renderer

```lua
-- {{{ WoW profession window
local WoWProfessionRenderer = {}

function WoWProfessionRenderer:render(provider, ui_parent)
    local frame = ui.create_frame("profession_window", ui_parent)

    -- Header: Profession name, skill bar
    self:render_header(frame, provider:get_professions()[1])

    -- Left: Category tabs
    self:render_category_tabs(frame)

    -- Center: Recipe list (scrollable)
    self:render_recipe_list(frame, provider:get_recipes("blacksmithing"))

    -- Right: Recipe details + craft button
    self:render_details_panel(frame)

    -- Bottom: Skill-up progress, specialization info
    self:render_footer(frame)

    return frame
end

function WoWProfessionRenderer:render_skill_bar(parent, skill, max, color)
    -- Progress bar showing 215/300
    local bar = ui.create_progress_bar(parent, {
        value = skill,
        max = max,
        color = color,
        text = string.format("%d / %d", skill, max),
    })
    return bar
end

function WoWProfessionRenderer:render_recipe_row(parent, recipe)
    local row = ui.create_row(parent)

    -- Icon
    ui.create_icon(row, recipe.icon, 32)

    -- Name (colored by difficulty)
    ui.create_text(row, recipe.name, {
        color = self:difficulty_to_color(recipe.difficulty),
    })

    -- Skill requirement
    ui.create_text(row, tostring(recipe.skill_required), {
        color = recipe.can_craft and "white" or "red",
    })

    return row
end
-- }}}
```

### WC3 Renderer

```lua
-- {{{ WC3 command card renderer
local WC3ProfessionRenderer = {}

function WC3ProfessionRenderer:render_command_card(provider, unit, ui_parent)
    local card = provider:get_command_card(unit)

    local grid = ui.create_grid(ui_parent, {
        rows = 3,
        cols = 4,
        cell_size = 48,
    })

    for row = 1, 3 do
        for col = 1, 4 do
            local cmd = card[row] and card[row][col]
            if cmd then
                self:render_command_button(grid, row, col, cmd)
            end
        end
    end

    return grid
end

function WC3ProfessionRenderer:render_command_button(grid, row, col, cmd)
    local btn = ui.create_button(grid, {
        position = {row = row, col = col},
        icon = cmd.icon,
        hotkey = cmd.hotkey,
        tooltip = cmd.tooltip,
        on_click = function()
            self:execute_command(cmd.cmd)
        end,
    })

    -- Cooldown overlay if applicable
    if cmd.cooldown then
        ui.add_cooldown_overlay(btn, cmd.cooldown)
    end

    return btn
end

function WC3ProfessionRenderer:render_production_queue(provider, building, ui_parent)
    local queue = provider:get_production_queue(building)

    -- Current production with progress bar
    if queue.current then
        local current = ui.create_production_frame(ui_parent, {
            icon = queue.current.icon,
            progress = queue.current.progress,
            time_text = string.format("%ds", queue.current.time_remaining),
        })
    end

    -- Queue icons
    local queue_bar = ui.create_row(ui_parent)
    for i, item in ipairs(queue.queue) do
        ui.create_icon(queue_bar, item.icon, 24)
    end

    return queue_bar
end

function WC3ProfessionRenderer:render_upgrade_buttons(provider, building, ui_parent)
    local upgrades = provider:get_upgrades(building)

    for _, upgrade in ipairs(upgrades.available) do
        local btn = ui.create_button(ui_parent, {
            icon = upgrade.icon,
            hotkey = upgrade.hotkey,
            tooltip = self:format_upgrade_tooltip(upgrade),
            enabled = self:can_afford(upgrade.cost),
            on_click = function()
                self:start_upgrade(building, upgrade.id)
            end,
        })
    end
end
-- }}}
```

---

## Event Bindings

```lua
-- {{{ UI events to profession actions
local ProfessionUIEvents = {
    -- Crafting
    CRAFT_CLICKED = function(entity, recipe_id, quantity)
        crafting.start_craft(entity, recipe_id, quantity)
    end,

    CRAFT_CANCELED = function(entity)
        crafting.cancel_craft(entity)
    end,

    -- Learning
    LEARN_RECIPE_CLICKED = function(entity, trainer, recipe_id)
        trainers.learn_recipe(entity, trainer, recipe_id)
    end,

    TRAIN_TIER_CLICKED = function(entity, trainer)
        trainers.train_tier(entity, trainer)
    end,

    -- WC3
    COMMAND_ISSUED = function(unit, command, target)
        orders.issue(unit, command, target)
    end,

    QUEUE_UNIT = function(building, unit_type)
        production.queue(building, "unit", unit_type)
    end,

    START_RESEARCH = function(building, upgrade_id)
        production.queue(building, "upgrade", upgrade_id)
    end,

    CANCEL_QUEUE = function(building, index)
        production.cancel(building, index)
    end,
}
-- }}}
```

---

## Tooltip Formatting

```lua
-- {{{ Tooltip generators
local ProfessionTooltips = {}

function ProfessionTooltips:recipe(recipe)
    local lines = {
        {text = recipe.name, color = "white", size = "large"},
        {text = recipe.description, color = "gray"},
        "",
        {text = "Requires:", color = "orange"},
    }

    for _, reagent in ipairs(recipe.reagents) do
        local color = reagent.have >= reagent.need and "white" or "red"
        table.insert(lines, {
            text = string.format("  %s (%d/%d)", reagent.name, reagent.have, reagent.need),
            color = color,
        })
    end

    if recipe.cast_time > 0 then
        table.insert(lines, "")
        table.insert(lines, {
            text = string.format("Cast Time: %.1f sec", recipe.cast_time),
            color = "gray",
        })
    end

    return lines
end

function ProfessionTooltips:upgrade(upgrade)
    local lines = {
        {text = upgrade.name, color = "gold", size = "large"},
        {text = upgrade.tooltip, color = "white"},
        "",
    }

    -- Cost
    for resource, amount in pairs(upgrade.cost) do
        local have = resources.get(resource)
        local color = have >= amount and "white" or "red"
        table.insert(lines, {
            text = string.format("%s: %d", resource, amount),
            color = color,
            icon = "icon_" .. resource,
        })
    end

    -- Research time
    table.insert(lines, "")
    table.insert(lines, {
        text = string.format("Research Time: %d seconds", upgrade.time),
        color = "gray",
    })

    return lines
end
-- }}}
```

---

## Configuration

```lua
-- {{{ UI configuration per mode
PROFESSION_UI_CONFIG = {
    wow = {
        renderer = "WoWProfessionRenderer",
        window_style = "blizzard",
        show_skill_bars = true,
        show_difficulty_colors = true,
        recipe_grouping = "category",
        tooltip_style = "wow",
    },

    wc3 = {
        renderer = "WC3ProfessionRenderer",
        window_style = "wc3",
        command_card = true,
        production_queue = true,
        upgrade_panel = true,
        tooltip_style = "wc3",
    },

    minimal = {
        renderer = "MinimalProfessionRenderer",
        window_style = "simple",
        text_only = true,
        tooltip_style = "basic",
    },

    chat = {
        renderer = "ChatProfessionRenderer",
        output_target = "chat_frame",
        commands = {
            "/craft", "/recipes", "/profession",
        },
    },
}
-- }}}
```

---

## Acceptance Criteria

- [ ] ProfessionUIProvider works for both WoW and WC3 modes
- [ ] WoW renderer shows skill bars, recipe lists, difficulty colors
- [ ] WC3 renderer shows command cards, queues, upgrade buttons
- [ ] Tooltips format correctly per mode
- [ ] UI events trigger correct profession actions
- [ ] Mode switching works without code changes
- [ ] Custom renderers can be plugged in
- [ ] Performance acceptable with large recipe lists
- [ ] Accessibility considerations (keyboard nav, screen reader hints)
- [ ] Unit tests for provider data formatting

---

## Notes

The UI abstraction is crucial for the dual-mode design. A recipe is a recipe,
but it might be shown as:
- A row in a WoW crafting window with skill-up chance colors
- A button on a WC3 command card
- A line in a chat-based interface

The provider formats the same data differently based on mode, and the
renderer draws it with the appropriate visual style.

This also enables:
- Theming (Horde vs Alliance, Night Elf vs Undead)
- Platform adaptation (desktop vs mobile)
- Accessibility modes (high contrast, text-only)
