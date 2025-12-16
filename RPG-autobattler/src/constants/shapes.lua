-- {{{ Shape definitions for game entities
local Shapes = {}

-- {{{ Unit shapes
Shapes.UNIT_MELEE = {
    type = "rectangle",
    width = 12,
    height = 12,
    origin_x = 6,    -- Center point
    origin_y = 6,
    pattern = "solid",
    accessibility_shape = "square"
}

Shapes.UNIT_RANGED = {
    type = "circle",
    radius = 8,
    origin_x = 0,    -- Center of circle
    origin_y = 0,
    pattern = "dashed",
    accessibility_shape = "circle"
}

Shapes.UNIT_TANK = {
    type = "rectangle",
    width = 16,
    height = 16,
    origin_x = 8,
    origin_y = 8,
    pattern = "thick_border",
    accessibility_shape = "large_square"
}

Shapes.UNIT_SUPPORT = {
    type = "polygon",
    points = {0, -8, 6, 4, -6, 4}, -- Triangle pointing up
    origin_x = 0,
    origin_y = 0,
    pattern = "crossed",
    accessibility_shape = "triangle"
}

Shapes.UNIT_SPECIAL = {
    type = "polygon",
    points = {0, -10, 8, -3, 5, 5, -5, 5, -8, -3}, -- Pentagon
    origin_x = 0,
    origin_y = 0,
    pattern = "striped",
    accessibility_shape = "pentagon"
}
-- }}}

-- {{{ Building shapes
Shapes.BASE = {
    type = "rectangle",
    width = 40,
    height = 40,
    origin_x = 20,
    origin_y = 20
}

Shapes.TOWER = {
    type = "circle",
    radius = 15,
    origin_x = 0,
    origin_y = 0
}

Shapes.SPAWN_POINT = {
    type = "rectangle",
    width = 20,
    height = 20,
    origin_x = 10,
    origin_y = 10
}
-- }}}

-- {{{ Projectile shapes
Shapes.PROJECTILE_ARROW = {
    type = "rectangle",
    width = 8,
    height = 3,
    origin_x = 4,
    origin_y = 1.5
}

Shapes.PROJECTILE_BULLET = {
    type = "circle",
    radius = 2,
    origin_x = 0,
    origin_y = 0
}

Shapes.PROJECTILE_FIREBALL = {
    type = "circle",
    radius = 5,
    origin_x = 0,
    origin_y = 0
}

Shapes.PROJECTILE_MAGIC = {
    type = "polygon",
    points = {0, -4, 3, 0, 0, 4, -3, 0}, -- Diamond
    origin_x = 0,
    origin_y = 0
}
-- }}}

-- {{{ UI shapes
Shapes.BUTTON_SMALL = {
    type = "rectangle",
    width = 80,
    height = 30,
    origin_x = 40,
    origin_y = 15
}

Shapes.BUTTON_MEDIUM = {
    type = "rectangle",
    width = 120,
    height = 40,
    origin_x = 60,
    origin_y = 20
}

Shapes.BUTTON_LARGE = {
    type = "rectangle",
    width = 160,
    height = 50,
    origin_x = 80,
    origin_y = 25
}

Shapes.HEALTH_BAR = {
    type = "rectangle",
    width = 20,
    height = 4,
    origin_x = 10,
    origin_y = 2
}

Shapes.MANA_BAR = {
    type = "rectangle",
    width = 20,
    height = 3,
    origin_x = 10,
    origin_y = 1.5
}
-- }}}

-- {{{ Environmental shapes
Shapes.LANE_MARKER = {
    type = "circle",
    radius = 3,
    origin_x = 0,
    origin_y = 0
}

Shapes.OBSTACLE_SMALL = {
    type = "circle",
    radius = 8,
    origin_x = 0,
    origin_y = 0
}

Shapes.OBSTACLE_LARGE = {
    type = "rectangle",
    width = 24,
    height = 24,
    origin_x = 12,
    origin_y = 12
}
-- }}}

-- {{{ Effect shapes
Shapes.EXPLOSION_SMALL = {
    type = "circle",
    radius = 12,
    origin_x = 0,
    origin_y = 0
}

Shapes.EXPLOSION_LARGE = {
    type = "circle",
    radius = 25,
    origin_x = 0,
    origin_y = 0
}

Shapes.HEAL_EFFECT = {
    type = "polygon",
    points = {0, -6, 2, -2, 6, 0, 2, 2, 0, 6, -2, 2, -6, 0, -2, -2}, -- Star
    origin_x = 0,
    origin_y = 0
}

Shapes.BUFF_INDICATOR = {
    type = "polygon",
    points = {0, -5, 4, 0, 0, 5, -4, 0}, -- Diamond
    origin_x = 0,
    origin_y = 0
}
-- }}}

-- {{{ Utility functions

-- {{{ Shapes.get_bounds
function Shapes.get_bounds(shape)
    if shape.type == "circle" then
        return {
            x = -shape.radius,
            y = -shape.radius,
            width = shape.radius * 2,
            height = shape.radius * 2
        }
    elseif shape.type == "rectangle" then
        return {
            x = -shape.origin_x,
            y = -shape.origin_y,
            width = shape.width,
            height = shape.height
        }
    elseif shape.type == "polygon" then
        local min_x, max_x = math.huge, -math.huge
        local min_y, max_y = math.huge, -math.huge
        
        for i = 1, #shape.points, 2 do
            local x, y = shape.points[i], shape.points[i + 1]
            min_x = math.min(min_x, x)
            max_x = math.max(max_x, x)
            min_y = math.min(min_y, y)
            max_y = math.max(max_y, y)
        end
        
        return {
            x = min_x,
            y = min_y,
            width = max_x - min_x,
            height = max_y - min_y
        }
    end
    
    return {x = 0, y = 0, width = 0, height = 0}
end
-- }}}

-- {{{ Shapes.scale
function Shapes.scale(shape, scale_x, scale_y)
    scale_y = scale_y or scale_x
    
    local scaled = {}
    for k, v in pairs(shape) do
        scaled[k] = v
    end
    
    if shape.type == "circle" then
        scaled.radius = shape.radius * scale_x
    elseif shape.type == "rectangle" then
        scaled.width = shape.width * scale_x
        scaled.height = shape.height * scale_y
        scaled.origin_x = shape.origin_x * scale_x
        scaled.origin_y = shape.origin_y * scale_y
    elseif shape.type == "polygon" then
        scaled.points = {}
        for i = 1, #shape.points, 2 do
            scaled.points[i] = shape.points[i] * scale_x
            scaled.points[i + 1] = shape.points[i + 1] * scale_y
        end
        scaled.origin_x = shape.origin_x * scale_x
        scaled.origin_y = shape.origin_y * scale_y
    end
    
    return scaled
end
-- }}}

-- {{{ Shapes.get_collision_radius
function Shapes.get_collision_radius(shape)
    if shape.type == "circle" then
        return shape.radius
    elseif shape.type == "rectangle" then
        return math.sqrt(shape.width * shape.width + shape.height * shape.height) / 2
    elseif shape.type == "polygon" then
        local max_dist = 0
        for i = 1, #shape.points, 2 do
            local x, y = shape.points[i], shape.points[i + 1]
            local dist = math.sqrt(x * x + y * y)
            max_dist = math.max(max_dist, dist)
        end
        return max_dist
    end
    
    return 0
end
-- }}}

-- {{{ Shapes.copy
function Shapes.copy(shape)
    local copy = {}
    for k, v in pairs(shape) do
        if type(v) == "table" then
            copy[k] = {}
            for i, val in ipairs(v) do
                copy[k][i] = val
            end
        else
            copy[k] = v
        end
    end
    return copy
end
-- }}}

-- {{{ Pattern drawing functions

-- {{{ Shapes.draw_pattern
function Shapes.draw_pattern(renderer, pattern, x, y, width, height, color)
    if pattern == "solid" then
        -- Already drawn as base shape
        return
        
    elseif pattern == "striped" then
        -- Draw diagonal stripes
        local stripe_spacing = 4
        for i = -width, width + height, stripe_spacing do
            local x1 = x + i
            local y1 = y
            local x2 = x + i + height
            local y2 = y + height
            
            -- Clip lines to rectangle bounds
            if x1 < x + width and x2 > x and y1 < y + height and y2 > y then
                x1 = math.max(x1, x)
                x2 = math.min(x2, x + width)
                y1 = math.max(y1, y)
                y2 = math.min(y2, y + height)
                renderer:draw_line(x1, y1, x2, y2, color, 1)
            end
        end
        
    elseif pattern == "dotted" then
        -- Draw dots in a grid
        local dot_spacing = 6
        for dx = dot_spacing / 2, width - dot_spacing / 2, dot_spacing do
            for dy = dot_spacing / 2, height - dot_spacing / 2, dot_spacing do
                renderer:draw_circle(x + dx, y + dy, 1, color)
            end
        end
        
    elseif pattern == "dashed" then
        -- Draw dashed border
        local dash_length = 4
        local gap_length = 2
        local total_length = dash_length + gap_length
        
        -- Top and bottom edges
        for i = 0, width, total_length do
            local dash_end = math.min(i + dash_length, width)
            renderer:draw_line(x + i, y, x + dash_end, y, color, 2)
            renderer:draw_line(x + i, y + height, x + dash_end, y + height, color, 2)
        end
        
        -- Left and right edges  
        for i = 0, height, total_length do
            local dash_end = math.min(i + dash_length, height)
            renderer:draw_line(x, y + i, x, y + dash_end, color, 2)
            renderer:draw_line(x + width, y + i, x + width, y + dash_end, color, 2)
        end
        
    elseif pattern == "crossed" then
        -- Draw X pattern
        renderer:draw_line(x, y, x + width, y + height, color, 2)
        renderer:draw_line(x + width, y, x, y + height, color, 2)
        
    elseif pattern == "thick_border" then
        -- Draw thick border
        renderer:draw_rectangle(x - 2, y - 2, width + 4, height + 4, color, "line")
        renderer:draw_rectangle(x - 1, y - 1, width + 2, height + 2, color, "line")
    end
end
-- }}}

-- {{{ Shapes.draw_circle_pattern
function Shapes.draw_circle_pattern(renderer, pattern, x, y, radius, color)
    if pattern == "solid" then
        -- Already drawn as base shape
        return
        
    elseif pattern == "dashed" then
        -- Draw dashed circle
        local segments = 16
        local dash_angle = math.pi / 12  -- 15 degrees
        local gap_angle = math.pi / 24   -- 7.5 degrees
        
        for i = 0, segments - 1 do
            local start_angle = i * (dash_angle + gap_angle)
            local end_angle = start_angle + dash_angle
            
            -- Draw arc as multiple line segments
            local arc_segments = 4
            for j = 0, arc_segments - 1 do
                local a1 = start_angle + j * dash_angle / arc_segments
                local a2 = start_angle + (j + 1) * dash_angle / arc_segments
                
                local x1 = x + math.cos(a1) * radius
                local y1 = y + math.sin(a1) * radius
                local x2 = x + math.cos(a2) * radius
                local y2 = y + math.sin(a2) * radius
                
                renderer:draw_line(x1, y1, x2, y2, color, 2)
            end
        end
        
    elseif pattern == "dotted" then
        -- Draw dots around circle
        local num_dots = 12
        for i = 0, num_dots - 1 do
            local angle = i * 2 * math.pi / num_dots
            local dot_x = x + math.cos(angle) * radius
            local dot_y = y + math.sin(angle) * radius
            renderer:draw_circle(dot_x, dot_y, 2, color)
        end
        
    elseif pattern == "crossed" then
        -- Draw cross inside circle
        renderer:draw_line(x - radius * 0.7, y, x + radius * 0.7, y, color, 2)
        renderer:draw_line(x, y - radius * 0.7, x, y + radius * 0.7, color, 2)
        
    elseif pattern == "thick_border" then
        -- Draw thick circle border
        renderer:draw_circle(x, y, radius + 2, color, "line")
        renderer:draw_circle(x, y, radius + 1, color, "line")
    end
end
-- }}}

-- {{{ Shapes.draw_shape_with_pattern
function Shapes.draw_shape_with_pattern(renderer, shape_def, x, y, color, scale)
    scale = scale or 1
    
    if shape_def.type == "rectangle" then
        local w = shape_def.width * scale
        local h = shape_def.height * scale
        local rect_x = x - shape_def.origin_x * scale
        local rect_y = y - shape_def.origin_y * scale
        
        -- Draw base shape
        renderer:draw_rectangle(rect_x, rect_y, w, h, color)
        
        -- Draw pattern overlay
        if shape_def.pattern then
            Shapes.draw_pattern(renderer, shape_def.pattern, rect_x, rect_y, w, h, color)
        end
        
    elseif shape_def.type == "circle" then
        local r = shape_def.radius * scale
        
        -- Draw base shape
        renderer:draw_circle(x, y, r, color)
        
        -- Draw pattern overlay
        if shape_def.pattern then
            Shapes.draw_circle_pattern(renderer, shape_def.pattern, x, y, r, color)
        end
        
    elseif shape_def.type == "polygon" then
        -- Scale and position polygon points
        local scaled_points = {}
        for i = 1, #shape_def.points, 2 do
            scaled_points[i] = x + shape_def.points[i] * scale
            scaled_points[i + 1] = y + shape_def.points[i + 1] * scale
        end
        
        -- Draw base shape
        renderer:draw_polygon(scaled_points, color)
        
        -- Draw pattern overlay for polygons
        if shape_def.pattern == "crossed" then
            -- Get bounding box for cross pattern
            local bounds = Shapes.get_bounds(shape_def)
            local w = bounds.width * scale
            local h = bounds.height * scale
            renderer:draw_line(x - w/2, y, x + w/2, y, color, 2)
            renderer:draw_line(x, y - h/2, x, y + h/2, color, 2)
        elseif shape_def.pattern == "striped" then
            -- Simple diagonal line for polygon striping
            local bounds = Shapes.get_bounds(shape_def)
            local w = bounds.width * scale
            local h = bounds.height * scale
            for i = -w, w, 4 do
                renderer:draw_line(x + i, y - h/2, x + i + h, y + h/2, color, 1)
            end
        end
    end
end
-- }}}

-- {{{ Shapes.get_accessibility_description
function Shapes.get_accessibility_description(shape_def)
    local desc = shape_def.accessibility_shape or "unknown shape"
    if shape_def.pattern and shape_def.pattern ~= "solid" then
        desc = desc .. " with " .. shape_def.pattern .. " pattern"
    end
    return desc
end
-- }}}

-- }}} End pattern drawing functions

-- }}} End utility functions

return Shapes
-- }}}