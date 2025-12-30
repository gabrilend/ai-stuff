# Issue 506f: Tooltip System

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 506
**Priority:** Low
**Dependencies:** 506a, 506c

---

## Current Behavior

No tooltips. Players cannot see detailed information about abilities, items, or units on hover.

---

## Intended Behavior

Hover-triggered tooltip system:

```lua
-- src/ui/tooltip.lua
local Panel = require("ui.elements.panel")
local Label = require("ui.elements.label")

local Tooltip = {}
Tooltip.__index = Tooltip

local active_tooltip = nil
local hover_timer = 0
local HOVER_DELAY = 0.5  -- Seconds before tooltip appears

function Tooltip.new()
    local self = setmetatable({}, Tooltip)

    self.panel = Panel.new({
        background_color = {20, 20, 20, 240},
        border_color = {100, 100, 100, 255},
        border_width = 1,
    })

    self.title = Label.new({
        font_size = 14,
        color = {255, 215, 0, 255},  -- Gold for title
    })

    self.description = Label.new({
        font_size = 12,
        color = {200, 200, 200, 255},
    })

    self.hotkey_label = Label.new({
        font_size = 11,
        color = {150, 150, 255, 255},  -- Blue for hotkey
    })

    self.stats = Label.new({
        font_size = 11,
        color = {150, 255, 150, 255},  -- Green for stats
    })

    self.visible = false
    self.x = 0
    self.y = 0

    return self
end

function Tooltip:set_content(content)
    self.title:set_text(content.title or "")
    self.description:set_text(content.description or "")

    if content.hotkey then
        self.hotkey_label:set_text("Hotkey: " .. content.hotkey)
    else
        self.hotkey_label:set_text("")
    end

    if content.stats then
        self.stats:set_text(content.stats)
    else
        self.stats:set_text("")
    end

    -- Calculate size based on content
    self:calculate_size()
end

function Tooltip:calculate_size()
    -- Simple sizing - in real impl, measure text
    local max_width = 250
    local line_height = 16
    local padding = 8

    local lines = 1  -- title
    if self.description.text ~= "" then lines = lines + 2 end
    if self.hotkey_label.text ~= "" then lines = lines + 1 end
    if self.stats.text ~= "" then lines = lines + 1 end

    self.panel.width = max_width
    self.panel.height = lines * line_height + padding * 2
end

function Tooltip:show_at(x, y)
    self.visible = true

    -- Keep tooltip on screen
    local sw, sh = get_screen_size()
    if x + self.panel.width > sw then
        x = sw - self.panel.width
    end
    if y + self.panel.height > sh then
        y = y - self.panel.height - 20
    end

    self.x = x
    self.y = y
end

function Tooltip:hide()
    self.visible = false
end

function Tooltip:draw(renderer)
    if not self.visible then return end

    local x, y = self.x, self.y
    local padding = 8

    -- Panel background
    renderer:draw_rect(x, y, self.panel.width, self.panel.height,
                       self.panel.background_color, true)
    renderer:draw_rect(x, y, self.panel.width, self.panel.height,
                       self.panel.border_color, false)

    -- Content
    local cy = y + padding
    renderer:draw_text(x + padding, cy, self.title.text,
                       self.title.font_size, self.title.color)
    cy = cy + 16

    if self.description.text ~= "" then
        renderer:draw_text(x + padding, cy, self.description.text,
                          self.description.font_size, self.description.color)
        cy = cy + 28
    end

    if self.hotkey_label.text ~= "" then
        renderer:draw_text(x + padding, cy, self.hotkey_label.text,
                          self.hotkey_label.font_size, self.hotkey_label.color)
        cy = cy + 14
    end

    if self.stats.text ~= "" then
        renderer:draw_text(x + padding, cy, self.stats.text,
                          self.stats.font_size, self.stats.color)
    end
end

-- Global tooltip management
local tooltip_manager = {}
local current_provider = nil

function tooltip_manager.init()
    active_tooltip = Tooltip.new()
end

function tooltip_manager.update(dt, mouse_x, mouse_y, hovered_component)
    if hovered_component and hovered_component.tooltip then
        if current_provider ~= hovered_component then
            current_provider = hovered_component
            hover_timer = 0
        end

        hover_timer = hover_timer + dt

        if hover_timer >= HOVER_DELAY then
            active_tooltip:set_content(hovered_component.tooltip)
            active_tooltip:show_at(mouse_x + 15, mouse_y + 15)
        end
    else
        current_provider = nil
        hover_timer = 0
        active_tooltip:hide()
    end
end

function tooltip_manager.draw(renderer)
    if active_tooltip then
        active_tooltip:draw(renderer)
    end
end

return tooltip_manager
```

---

## Suggested Implementation Steps

1. **Create Tooltip component**
   - Panel with title, description, hotkey, stats
   - Auto-sizing based on content

2. **Implement show/hide logic**
   - Delay before showing (avoid flicker)
   - Instant hide on mouse move

3. **Implement screen-edge clamping**
   - Keep tooltip fully visible
   - Flip above cursor if near bottom

4. **Create tooltip manager**
   - Track hovered component
   - Manage hover timer
   - Global draw call

5. **Add tooltip data to components**
   - tooltip property on Button, etc.
   - Structured content object

6. **Style for different content types**
   - Ability: name, description, mana cost, cooldown
   - Unit: name, HP/MP, attack, armor
   - Item: name, description, stats, cost

---

## Acceptance Criteria

- [ ] Tooltip appears after hover delay
- [ ] Tooltip disappears on mouse move
- [ ] Tooltip stays on screen
- [ ] Title renders in gold
- [ ] Hotkey renders in blue
- [ ] Stats render in green

---

## Notes

Tooltips provide crucial information without cluttering the UI. They should be informative but not intrusive.

**WC3 tooltip style:**
- Dark semi-transparent background
- Gold title text
- White/grey description
- Green numbers for stats
- Blue for mana costs

**Ability tooltip example:**
```
Frost Nova                     [hotkey: N]
Blasts enemy units with frost,
dealing 100 damage and slowing
movement by 50% for 4 seconds.

Mana cost: 125
Cooldown: 8 seconds
```

---

## Related Documents

- issues/506a-ui-component-system.md (base component)
- issues/506c-input-handling.md (hover detection)
- issues/506e-command-button-grid.md (button tooltips)
- issues/506d-core-ui-elements.md (Label, Panel)
