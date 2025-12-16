-- {{{ Renderer module for drawing primitives
local Renderer = {}

local debug = require("src.utils.debug")

-- {{{ Renderer:init
function Renderer:init()
    self.draw_calls = 0
    self.frame_time = 0
    self.last_frame_draw_calls = 0
    
    -- Batched shapes for optimization
    self.shapes = {
        circle = {},
        rectangle = {},
        line = {},
        text = {}
    }
    
    -- Rendering state
    self.current_color = {1, 1, 1, 1}
    self.current_line_width = 1
    
    -- Debug options
    self.debug_wireframes = false
    self.debug_bounds = false
    self.show_draw_calls = false
    
    debug.log("Renderer initialized", "RENDERER")
end
-- }}}

-- {{{ Renderer:begin_frame
function Renderer:begin_frame()
    local start_time = love.timer.getTime()
    
    self.last_frame_draw_calls = self.draw_calls
    self.draw_calls = 0
    
    -- Clear screen with black background
    love.graphics.clear(0, 0, 0, 1)
    
    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    
    self.frame_start_time = start_time
end
-- }}}

-- {{{ Renderer:end_frame
function Renderer:end_frame()
    -- Flush any remaining batched operations
    self:flush_batches()
    
    -- Calculate frame time
    self.frame_time = love.timer.getTime() - self.frame_start_time
    
    -- Draw debug information if enabled
    if self.show_draw_calls then
        self:draw_debug_info()
    end
    
    debug.log(string.format("Frame rendered: %d draw calls in %.3fms", 
              self.draw_calls, self.frame_time * 1000), "RENDERER")
end
-- }}}

-- {{{ Renderer:draw_circle
function Renderer:draw_circle(x, y, radius, color, fill_mode)
    fill_mode = fill_mode or "fill"
    
    self:set_color(color)
    love.graphics.circle(fill_mode, x, y, radius)
    self.draw_calls = self.draw_calls + 1
    
    -- Draw debug wireframe if enabled
    if self.debug_wireframes and fill_mode == "fill" then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.circle("line", x, y, radius)
        self.draw_calls = self.draw_calls + 1
    end
end
-- }}}

-- {{{ Renderer:draw_rectangle
function Renderer:draw_rectangle(x, y, width, height, color, fill_mode)
    fill_mode = fill_mode or "fill"
    
    self:set_color(color)
    love.graphics.rectangle(fill_mode, x, y, width, height)
    self.draw_calls = self.draw_calls + 1
    
    -- Draw debug wireframe if enabled
    if self.debug_wireframes and fill_mode == "fill" then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", x, y, width, height)
        self.draw_calls = self.draw_calls + 1
    end
    
    -- Draw debug bounds if enabled
    if self.debug_bounds then
        self:draw_bounds(x, y, width, height)
    end
end
-- }}}

-- {{{ Renderer:draw_line
function Renderer:draw_line(x1, y1, x2, y2, color, width)
    width = width or 1
    
    self:set_color(color)
    love.graphics.setLineWidth(width)
    love.graphics.line(x1, y1, x2, y2)
    self.draw_calls = self.draw_calls + 1
    
    self.current_line_width = width
end
-- }}}

-- {{{ Renderer:draw_text
function Renderer:draw_text(text, x, y, color, font)
    self:set_color(color)
    
    if font then 
        love.graphics.setFont(font) 
    end
    
    love.graphics.print(text, x, y)
    self.draw_calls = self.draw_calls + 1
    
    -- Draw debug bounds for text if enabled
    if self.debug_bounds then
        local font_obj = love.graphics.getFont()
        local text_width = font_obj:getWidth(text)
        local text_height = font_obj:getHeight()
        self:draw_bounds(x, y, text_width, text_height)
    end
end
-- }}}

-- {{{ Renderer:draw_polygon
function Renderer:draw_polygon(points, color, fill_mode)
    fill_mode = fill_mode or "fill"
    
    if #points < 6 then
        debug.error("Polygon needs at least 3 points (6 coordinates)", "RENDERER")
        return
    end
    
    self:set_color(color)
    love.graphics.polygon(fill_mode, points)
    self.draw_calls = self.draw_calls + 1
    
    -- Draw debug wireframe if enabled
    if self.debug_wireframes and fill_mode == "fill" then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.polygon("line", points)
        self.draw_calls = self.draw_calls + 1
    end
end
-- }}}

-- {{{ Renderer:draw_arrow
function Renderer:draw_arrow(x1, y1, x2, y2, color, width, head_size)
    width = width or 2
    head_size = head_size or 8
    
    -- Draw main line
    self:draw_line(x1, y1, x2, y2, color, width)
    
    -- Calculate arrow head
    local angle = math.atan2(y2 - y1, x2 - x1)
    local head_angle1 = angle + math.pi * 0.8
    local head_angle2 = angle - math.pi * 0.8
    
    local head_x1 = x2 + math.cos(head_angle1) * head_size
    local head_y1 = y2 + math.sin(head_angle1) * head_size
    local head_x2 = x2 + math.cos(head_angle2) * head_size
    local head_y2 = y2 + math.sin(head_angle2) * head_size
    
    -- Draw arrow head
    self:draw_line(x2, y2, head_x1, head_y1, color, width)
    self:draw_line(x2, y2, head_x2, head_y2, color, width)
end
-- }}}

-- {{{ Renderer:set_color
function Renderer:set_color(color)
    if type(color) == "table" and #color >= 3 then
        local r, g, b, a = color[1], color[2], color[3], color[4] or 1
        love.graphics.setColor(r, g, b, a)
        self.current_color = {r, g, b, a}
    else
        -- Default to white if no valid color provided
        love.graphics.setColor(1, 1, 1, 1)
        self.current_color = {1, 1, 1, 1}
    end
end
-- }}}

-- {{{ Renderer:push_transform
function Renderer:push_transform()
    love.graphics.push()
end
-- }}}

-- {{{ Renderer:pop_transform
function Renderer:pop_transform()
    love.graphics.pop()
end
-- }}}

-- {{{ Renderer:translate
function Renderer:translate(x, y)
    love.graphics.translate(x, y)
end
-- }}}

-- {{{ Renderer:rotate
function Renderer:rotate(angle)
    love.graphics.rotate(angle)
end
-- }}}

-- {{{ Renderer:scale
function Renderer:scale(sx, sy)
    sy = sy or sx
    love.graphics.scale(sx, sy)
end
-- }}}

-- {{{ Renderer:draw_bounds
function Renderer:draw_bounds(x, y, width, height)
    love.graphics.setColor(1, 1, 0, 0.5) -- Yellow with transparency
    love.graphics.rectangle("line", x, y, width, height)
    self.draw_calls = self.draw_calls + 1
end
-- }}}

-- {{{ Renderer:flush_batches
function Renderer:flush_batches()
    -- Future: Implement batched rendering for performance
    -- For now, this is a placeholder
end
-- }}}

-- {{{ Renderer:draw_debug_info
function Renderer:draw_debug_info()
    local info_text = string.format(
        "Draw Calls: %d\nFrame Time: %.2fms\nFPS: %.1f",
        self.draw_calls,
        self.frame_time * 1000,
        1 / self.frame_time
    )
    
    -- Draw background for debug text
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 150, 60)
    
    -- Draw debug text
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(info_text, 15, 15)
    
    self.draw_calls = self.draw_calls + 2
end
-- }}}

-- {{{ Renderer:set_debug_wireframes
function Renderer:set_debug_wireframes(enabled)
    self.debug_wireframes = enabled
    debug.log("Debug wireframes " .. (enabled and "enabled" or "disabled"), "RENDERER")
end
-- }}}

-- {{{ Renderer:set_debug_bounds
function Renderer:set_debug_bounds(enabled)
    self.debug_bounds = enabled
    debug.log("Debug bounds " .. (enabled and "enabled" or "disabled"), "RENDERER")
end
-- }}}

-- {{{ Renderer:set_show_draw_calls
function Renderer:set_show_draw_calls(enabled)
    self.show_draw_calls = enabled
    debug.log("Draw call display " .. (enabled and "enabled" or "disabled"), "RENDERER")
end
-- }}}

-- {{{ Renderer:get_stats
function Renderer:get_stats()
    return {
        draw_calls = self.draw_calls,
        last_frame_draw_calls = self.last_frame_draw_calls,
        frame_time = self.frame_time,
        fps = 1 / (self.frame_time > 0 and self.frame_time or 0.016)
    }
end
-- }}}

return Renderer
-- }}}