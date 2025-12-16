# Issue #010: Create Color Palette and Shape Definitions

## Current Behavior
No standardized color palette or shape definitions exist for consistent visual design.

## Intended Behavior
A comprehensive color palette and shape definition system should ensure consistent, accessible visual design throughout the game.

## Implementation Details

### Accessibility-First Color System (src/constants/colors.lua)
```lua
local Colors = {
    -- Base colors (high contrast)
    BLACK = {0, 0, 0, 1},
    WHITE = {1, 1, 1, 1},
    
    -- Primary game colors (colorblind-friendly)
    TEAM_A = {0.1, 0.4, 1, 1},      -- Blue (distinguishable)
    TEAM_B = {1, 0.3, 0.1, 1},      -- Orange-red (not pure red)
    NEUTRAL = {0.7, 0.7, 0.7, 1},   -- Gray
    
    -- UI colors
    UI_BACKGROUND = {0, 0, 0, 1},
    UI_TEXT = {1, 1, 1, 1},
    UI_ACCENT = {1, 1, 0, 1},       -- Yellow for highlights
    UI_SUCCESS = {0, 1, 0, 1},      -- Green for positive actions
    UI_WARNING = {1, 0.8, 0, 1},    -- Amber for warnings
    UI_ERROR = {1, 0.2, 0.2, 1},    -- Light red for errors
    
    -- Game element colors
    HEALTH_FULL = {0, 1, 0, 1},     -- Green
    HEALTH_MID = {1, 1, 0, 1},      -- Yellow
    HEALTH_LOW = {1, 0.4, 0, 1},    -- Orange
    MANA_BAR = {0, 0.6, 1, 1},      -- Light blue
    
    -- Special effects
    DAMAGE_FLASH = {1, 1, 1, 0.8},  -- White semi-transparent
    HEAL_FLASH = {0, 1, 0, 0.6},    -- Green semi-transparent
    
    -- Colorblind alternatives
    patterns = {
        SOLID = "solid",
        STRIPED = "striped", 
        DOTTED = "dotted",
        DASHED = "dashed"
    }
}

-- Colorblind-friendly color validation
function Colors.validate_contrast(color1, color2)
    -- Simple luminance contrast calculation
    local function luminance(color)
        return 0.299 * color[1] + 0.587 * color[2] + 0.114 * color[3]
    end
    
    local l1 = luminance(color1)
    local l2 = luminance(color2)
    local contrast = (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05)
    return contrast >= 4.5  -- WCAG AA standard
end

return Colors
```

### Shape System (src/constants/shapes.lua)
```lua
local Shapes = {
    -- Unit shapes (distinguishable without color)
    UNIT_MELEE = {
        type = "rectangle",
        width = 14,
        height = 14,
        pattern = "solid"
    },
    
    UNIT_RANGED = {
        type = "circle", 
        radius = 8,
        pattern = "solid"
    },
    
    UNIT_SUPPORT = {
        type = "triangle",
        size = 12,
        pattern = "solid"
    },
    
    UNIT_TANK = {
        type = "rectangle",
        width = 18,
        height = 18,
        pattern = "thick_border"
    },
    
    -- Building shapes
    BASE = {
        type = "rectangle",
        width = 50,
        height = 50,
        pattern = "fortress"
    },
    
    SHIELD = {
        type = "circle",
        radius = 25,
        pattern = "dashed_circle"
    },
    
    TURRET = {
        type = "triangle",
        size = 15,
        pattern = "solid"
    },
    
    -- UI shapes
    BUTTON = {
        type = "rectangle",
        width = 100,
        height = 30,
        pattern = "solid",
        border = true
    },
    
    HEALTH_BAR = {
        type = "rectangle",
        width = 20,
        height = 4,
        pattern = "solid"
    },
    
    MANA_BAR = {
        type = "rectangle", 
        width = 16,
        height = 3,
        pattern = "solid"
    },
    
    -- Map elements
    PATH = {
        type = "line",
        width = 60,
        pattern = "center_line"
    },
    
    SPAWN_POINT = {
        type = "circle",
        radius = 20,
        pattern = "dotted_circle"
    }
}

-- Shape rendering functions
function Shapes.draw_shape(renderer, shape_def, x, y, color, scale)
    scale = scale or 1
    
    if shape_def.type == "rectangle" then
        local w = shape_def.width * scale
        local h = shape_def.height * scale
        renderer:draw_rectangle(x - w/2, y - h/2, w, h, color)
        
        if shape_def.pattern == "thick_border" then
            renderer:draw_rectangle(x - w/2, y - h/2, w, h, Colors.WHITE, "line")
        end
        
    elseif shape_def.type == "circle" then
        local r = shape_def.radius * scale
        renderer:draw_circle(x, y, r, color)
        
        if shape_def.pattern == "dashed_circle" then
            -- Draw dashed circle outline
            for i = 0, 7 do
                local angle = (i / 8) * math.pi * 2
                local x1 = x + math.cos(angle) * r
                local y1 = y + math.sin(angle) * r
                local x2 = x + math.cos(angle + 0.2) * r
                local y2 = y + math.sin(angle + 0.2) * r
                renderer:draw_line(x1, y1, x2, y2, color, 2)
            end
        end
        
    elseif shape_def.type == "triangle" then
        local size = shape_def.size * scale
        -- Draw triangle using lines
        local height = size * 0.866
        renderer:draw_line(x, y - height/2, x - size/2, y + height/2, color, 2)
        renderer:draw_line(x - size/2, y + height/2, x + size/2, y + height/2, color, 2)
        renderer:draw_line(x + size/2, y + height/2, x, y - height/2, color, 2)
    end
end

return Shapes
```

### Pattern System for Accessibility
1. **Solid**: Standard filled shapes
2. **Striped**: Diagonal lines for alternative identification
3. **Dotted**: Small dots for texture
4. **Dashed**: Broken lines for borders
5. **Thick Border**: Bold outlines for emphasis

### Considerations
- Ensure all colors meet WCAG contrast standards
- Test with colorblind simulation tools
- Make shapes distinguishable by form alone
- Plan for pattern overlays on shapes
- Consider animation/movement as additional identifiers

### Tool Suggestions
- Use Write tool to create color and shape files
- Test color combinations for contrast
- Verify shapes are visually distinct
- Create colorblind testing scenarios

### Acceptance Criteria
- [ ] All color combinations have sufficient contrast
- [ ] Shapes are distinguishable without color
- [ ] Pattern system works for accessibility
- [ ] Color palette is consistent throughout game
- [ ] Shape drawing functions work correctly
- [ ] System supports colorblind users effectively