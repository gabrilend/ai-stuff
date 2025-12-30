# Issue 506d: Core UI Elements

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 506
**Priority:** Medium
**Dependencies:** 506a, 506b, 506c

---

## Current Behavior

No UI elements. All game information must be displayed via debug overlays or console.

---

## Intended Behavior

Common UI elements built on component system:

```lua
-- src/ui/elements/panel.lua
local Component = require("ui.component")
local Panel = setmetatable({}, {__index = Component})
Panel.__index = Panel

function Panel.new(config)
    local self = Component.new(config)
    setmetatable(self, Panel)

    self.type = "panel"
    self.background_color = config.background_color or {30, 30, 30, 200}
    self.border_color = config.border_color or {60, 60, 60, 255}
    self.border_width = config.border_width or 1

    return self
end

function Panel:draw_self(renderer)
    local x, y = self:get_absolute_position()

    -- Background
    renderer:draw_rect(x, y, self.width, self.height,
                       self.background_color, true)

    -- Border
    if self.border_width > 0 then
        renderer:draw_rect(x, y, self.width, self.height,
                          self.border_color, false)
    end
end

-- src/ui/elements/label.lua
local Label = setmetatable({}, {__index = Component})
Label.__index = Label

function Label.new(config)
    local self = Component.new(config)
    setmetatable(self, Label)

    self.type = "label"
    self.text = config.text or ""
    self.font_size = config.font_size or 14
    self.color = config.color or {255, 255, 255, 255}
    self.align = config.align or "left"  -- left, center, right

    return self
end

function Label:set_text(text)
    self.text = text
end

function Label:draw_self(renderer)
    local x, y = self:get_absolute_position()
    renderer:draw_text(x, y, self.text, self.font_size, self.color)
end

-- src/ui/elements/button.lua
local Button = setmetatable({}, {__index = Panel})
Button.__index = Button

function Button.new(config)
    local self = Panel.new(config)
    setmetatable(self, Button)

    self.type = "button"
    self.label = config.label or ""
    self.on_click_callback = config.on_click
    self.hotkey = config.hotkey

    -- Colors for states
    self.normal_color = config.normal_color or {50, 50, 50, 255}
    self.hover_color = config.hover_color or {70, 70, 70, 255}
    self.pressed_color = config.pressed_color or {40, 40, 40, 255}
    self.disabled_color = config.disabled_color or {30, 30, 30, 200}

    return self
end

function Button:draw_self(renderer)
    local x, y = self:get_absolute_position()

    -- Select color based on state
    local color = self.normal_color
    if not self.enabled then
        color = self.disabled_color
    elseif self.pressed then
        color = self.pressed_color
    elseif self.hovered then
        color = self.hover_color
    end

    -- Background
    renderer:draw_rect(x, y, self.width, self.height, color, true)

    -- Label (centered)
    local text_x = x + self.width / 2  -- Adjust for text width
    local text_y = y + self.height / 2 - 7  -- Approximate center
    renderer:draw_text(text_x, text_y, self.label, 14, {255, 255, 255, 255})

    -- Hotkey indicator (bottom-right)
    if self.hotkey then
        renderer:draw_text(x + self.width - 15, y + self.height - 15,
                          self.hotkey, 10, {180, 180, 180, 255})
    end
end

function Button:on_click(button, x, y)
    if button == 1 and self.on_click_callback then
        self.on_click_callback(self)
    end
end

-- src/ui/elements/progress_bar.lua
local ProgressBar = setmetatable({}, {__index = Component})
ProgressBar.__index = ProgressBar

function ProgressBar.new(config)
    local self = Component.new(config)
    setmetatable(self, ProgressBar)

    self.type = "progress_bar"
    self.value = config.value or 0
    self.max_value = config.max_value or 100
    self.bar_color = config.bar_color or {0, 200, 0, 255}
    self.background_color = config.background_color or {40, 40, 40, 255}

    return self
end

function ProgressBar:set_value(value, max)
    self.value = value
    if max then self.max_value = max end
end

function ProgressBar:draw_self(renderer)
    local x, y = self:get_absolute_position()

    -- Background
    renderer:draw_rect(x, y, self.width, self.height,
                       self.background_color, true)

    -- Fill
    local fill_width = (self.value / self.max_value) * self.width
    renderer:draw_rect(x, y, fill_width, self.height,
                       self.bar_color, true)
end
```

---

## Suggested Implementation Steps

1. **Implement Panel**
   - Background color with alpha
   - Optional border
   - Container for other elements

2. **Implement Label**
   - Text rendering
   - Font size configuration
   - Alignment options

3. **Implement Button**
   - Extends Panel
   - Hover/pressed/disabled states
   - Click callback
   - Hotkey display

4. **Implement ProgressBar**
   - HP/MP bar style
   - Value/max tracking
   - Color configuration

5. **Implement Image**
   - Texture rendering
   - Stretch/tile modes
   - Color tinting

6. **Create element registry**
   - Factory functions
   - Type validation

---

## Acceptance Criteria

- [ ] Panel renders with background and border
- [ ] Label displays text correctly
- [ ] Button responds to hover/click
- [ ] ProgressBar shows fill percentage
- [ ] All elements respect visibility/enabled
- [ ] Elements composable in hierarchy

---

## Notes

Keep elements simple. Complex widgets (dropdown, list) can be composed from primitives.

**HP/MP bar colors (WC3):**
- HP: Green when full, yellow at half, red when low
- MP: Blue
- XP: Purple

---

## Related Documents

- issues/506a-ui-component-system.md (base component)
- issues/506b-layout-system.md (positioning)
- issues/506c-input-handling.md (click/hover)
- issues/506e-command-button-grid.md (uses Button)
