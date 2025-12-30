# Issue 506e: Command Button Grid

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 506
**Priority:** Medium
**Dependencies:** 506c, 506d

---

## Current Behavior

No command UI. Players cannot see or click ability buttons.

---

## Intended Behavior

WC3-style 4x3 command button grid:

```lua
-- src/ui/command_panel.lua
local Panel = require("ui.elements.panel")
local Button = require("ui.elements.button")
local layout = require("ui.layout")

local CommandPanel = setmetatable({}, {__index = Panel})
CommandPanel.__index = CommandPanel

-- Button grid layout (4 columns x 3 rows)
-- Hotkey layout matches WC3:
--  Q W E R
--  A S D F
--  Z X C V

local HOTKEY_GRID = {
    {"Q", "W", "E", "R"},
    {"A", "S", "D", "F"},
    {"Z", "X", "C", "V"},
}

function CommandPanel.new(config)
    local self = Panel.new(config)
    setmetatable(self, CommandPanel)

    self.type = "command_panel"
    self.buttons = {}
    self.columns = 4
    self.rows = 3
    self.button_size = config.button_size or 48
    self.spacing = config.spacing or 4

    -- Create button grid
    for row = 1, self.rows do
        self.buttons[row] = {}
        for col = 1, self.columns do
            local btn = Button.new({
                width = self.button_size,
                height = self.button_size,
                hotkey = HOTKEY_GRID[row][col],
            })
            btn.grid_row = row
            btn.grid_col = col
            self.buttons[row][col] = btn
            self:add_child(btn)
        end
    end

    self:layout_buttons()
    return self
end

function CommandPanel:layout_buttons()
    for row = 1, self.rows do
        for col = 1, self.columns do
            local btn = self.buttons[row][col]
            btn.x = (col - 1) * (self.button_size + self.spacing)
            btn.y = (row - 1) * (self.button_size + self.spacing)
        end
    end

    -- Update panel size to fit
    self.width = self.columns * self.button_size + (self.columns - 1) * self.spacing
    self.height = self.rows * self.button_size + (self.rows - 1) * self.spacing
end

function CommandPanel:set_button(row, col, config)
    local btn = self.buttons[row][col]
    if not btn then return end

    btn.label = config.label or ""
    btn.icon = config.icon  -- Texture for icon display
    btn.tooltip = config.tooltip
    btn.on_click_callback = config.on_click
    btn.enabled = config.enabled ~= false
    btn.cooldown = config.cooldown or 0
    btn.cooldown_max = config.cooldown_max or 0
end

function CommandPanel:clear_buttons()
    for row = 1, self.rows do
        for col = 1, self.columns do
            local btn = self.buttons[row][col]
            btn.label = ""
            btn.icon = nil
            btn.tooltip = nil
            btn.on_click_callback = nil
            btn.enabled = false
            btn.cooldown = 0
        end
    end
end

function CommandPanel:update_for_selection(selection)
    self:clear_buttons()

    if #selection == 0 then
        return
    end

    -- Get command set for selected unit type
    local unit = selection[1]
    local commands = get_unit_commands(unit)

    for _, cmd in ipairs(commands) do
        self:set_button(cmd.row, cmd.col, {
            label = cmd.icon and "" or cmd.name:sub(1, 1),
            icon = cmd.icon,
            tooltip = cmd.tooltip,
            on_click = function() issue_command(selection, cmd) end,
            enabled = can_use_command(unit, cmd),
            cooldown = get_command_cooldown(unit, cmd),
            cooldown_max = cmd.cooldown,
        })
    end
end

-- Cooldown overlay rendering
function CommandPanel:draw_cooldown(renderer, btn)
    if btn.cooldown <= 0 then return end

    local x, y = btn:get_absolute_position()
    local pct = btn.cooldown / btn.cooldown_max

    -- Dark overlay
    renderer:draw_rect(x, y, btn.width, btn.height * pct,
                       {0, 0, 0, 150}, true)

    -- Cooldown text
    local text = string.format("%.1f", btn.cooldown)
    renderer:draw_text(x + btn.width/2 - 10, y + btn.height/2 - 7,
                       text, 12, {255, 255, 255, 255})
end

return CommandPanel
```

---

## Suggested Implementation Steps

1. **Create CommandPanel component**
   - Extends Panel
   - 4x3 grid of Button children
   - Configurable button size and spacing

2. **Implement button layout**
   - Grid positioning
   - Auto-size panel to fit buttons

3. **Map hotkeys to grid positions**
   - QWER / ASDF / ZXCV layout
   - Register hotkeys on panel show
   - Unregister on hide

4. **Implement button configuration**
   - set_button(row, col, config)
   - Icon, label, tooltip, callback
   - Enable/disable state

5. **Implement cooldown display**
   - Overlay darkening
   - Countdown text
   - Sweep animation (optional)

6. **Connect to selection system**
   - Clear on deselect
   - Populate on select
   - Handle multi-select (shared commands)

---

## Acceptance Criteria

- [ ] 4x3 grid of buttons renders
- [ ] Hotkeys QWER/ASDF/ZXCV work
- [ ] Buttons show icon or label
- [ ] Disabled buttons appear dimmed
- [ ] Cooldown overlay displays correctly
- [ ] Selection changes update buttons

---

## Notes

The command panel is central to RTS gameplay. Must be responsive and clear.

**WC3 command organization:**
- Row 1: Primary abilities (Q, W, E, R)
- Row 2: Secondary abilities, building (A, S, D, F)
- Row 3: Cancel, stop, hold, patrol (Z, X, C, V)

**Multi-select behavior:**
Only show commands common to all selected units.

---

## Related Documents

- issues/506d-core-ui-elements.md (Button component)
- issues/506c-input-handling.md (hotkey system)
- issues/505e-input-commands.md (command issuance)
- issues/506f-tooltip-system.md (ability tooltips)
