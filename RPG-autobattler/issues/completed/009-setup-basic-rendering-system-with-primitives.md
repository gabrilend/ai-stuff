# Issue #009: Setup Basic Rendering System with Primitives

## Current Behavior
No structured rendering system exists beyond basic Love2D graphics calls.

## Intended Behavior
A modular rendering system should provide convenient functions for drawing game primitives with consistent styling and performance optimization.

## Implementation Details

### Renderer Module (src/systems/renderer.lua)
```lua
local Renderer = {}

function Renderer:init()
    self.draw_calls = 0
    self.shapes = {
        circle = {},
        rectangle = {},
        line = {},
        text = {}
    }
end

function Renderer:begin_frame()
    self.draw_calls = 0
    love.graphics.clear(0, 0, 0, 1)  -- Black background
end

function Renderer:end_frame()
    -- Flush any batched operations
    -- Update debug info
end

function Renderer:draw_circle(x, y, radius, color, fill_mode)
    fill_mode = fill_mode or "fill"
    self:set_color(color)
    love.graphics.circle(fill_mode, x, y, radius)
    self.draw_calls = self.draw_calls + 1
end

function Renderer:draw_rectangle(x, y, width, height, color, fill_mode)
    fill_mode = fill_mode or "fill"
    self:set_color(color)
    love.graphics.rectangle(fill_mode, x, y, width, height)
    self.draw_calls = self.draw_calls + 1
end

function Renderer:draw_line(x1, y1, x2, y2, color, width)
    width = width or 1
    self:set_color(color)
    love.graphics.setLineWidth(width)
    love.graphics.line(x1, y1, x2, y2)
    self.draw_calls = self.draw_calls + 1
end

function Renderer:draw_text(text, x, y, color, font)
    self:set_color(color)
    if font then love.graphics.setFont(font) end
    love.graphics.print(text, x, y)
    self.draw_calls = self.draw_calls + 1
end

function Renderer:set_color(color)
    if type(color) == "table" then
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    else
        love.graphics.setColor(1, 1, 1, 1)  -- Default white
    end
end

return Renderer
```

### Color Palette (src/constants/colors.lua)
```lua
local Colors = {
    BLACK = {0, 0, 0, 1},
    WHITE = {1, 1, 1, 1},
    RED = {1, 0, 0, 1},
    GREEN = {0, 1, 0, 1},
    BLUE = {0, 0, 1, 1},
    YELLOW = {1, 1, 0, 1},
    CYAN = {0, 1, 1, 1},
    MAGENTA = {1, 0, 1, 1},
    
    -- Game-specific colors
    PLAYER_1 = {0.2, 0.6, 1, 1},    -- Light blue
    PLAYER_2 = {1, 0.3, 0.3, 1},    -- Light red
    NEUTRAL = {0.7, 0.7, 0.7, 1},   -- Gray
    UI_BG = {0.1, 0.1, 0.1, 0.8},   -- Dark semi-transparent
    UI_TEXT = {0.9, 0.9, 0.9, 1}    -- Light gray
}

return Colors
```

### Shape Definitions (src/constants/shapes.lua)
```lua
local Shapes = {
    UNIT_MELEE = {
        type = "rectangle",
        width = 12,
        height = 12
    },
    UNIT_RANGED = {
        type = "circle",
        radius = 8
    },
    BASE = {
        type = "rectangle",
        width = 40,
        height = 40
    },
    PROJECTILE = {
        type = "circle",
        radius = 3
    }
}

return Shapes
```

### Rendering Helpers
1. **Batch Operations**: Group similar draw calls
2. **Transform Stack**: Handle coordinate transformations
3. **Debug Rendering**: Optional wireframes and debug info
4. **Performance Monitoring**: Track draw calls and performance

### Considerations
- Plan for sprite support later (but start with primitives)
- Implement efficient batching for many similar objects
- Consider z-ordering for layered rendering
- Add screen-to-world coordinate conversion
- Include viewport/camera support

### Tool Suggestions
- Use Write tool to create renderer and constant files
- Test all primitive rendering functions
- Verify color system works with Love2D
- Check performance with many draw calls

### Acceptance Criteria
- [ ] All primitive shapes render correctly
- [ ] Color system works consistently
- [ ] Rendering performance is acceptable
- [ ] Draw call counting works
- [ ] Debug rendering features function
- [ ] Shape definitions are consistent and usable