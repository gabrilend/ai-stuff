-- {{{ Renderer Demo - Visual test of rendering system
-- This demo can be run in Love2D to visually verify all rendering features

local Renderer = require("src.systems.renderer")
local Colors = require("src.constants.colors")
local Shapes = require("src.constants.shapes")

local Demo = {}

-- {{{ Demo:init
function Demo:init()
    self.renderer = {}
    setmetatable(self.renderer, {__index = Renderer})
    self.renderer:init()
    
    -- Enable debug features for demo
    self.renderer:set_debug_wireframes(true)
    self.renderer:set_show_draw_calls(true)
    
    self.time = 0
end
-- }}}

-- {{{ Demo:update
function Demo:update(dt)
    self.time = self.time + dt
end
-- }}}

-- {{{ Demo:draw
function Demo:draw()
    self.renderer:begin_frame()
    
    -- Test basic shapes
    self.renderer:draw_rectangle(50, 50, 100, 80, Colors.PLAYER_1)
    self.renderer:draw_circle(250, 100, 40, Colors.PLAYER_2)
    
    -- Test shapes with transparency
    local semi_transparent = Colors.with_alpha(Colors.GREEN, 0.5)
    self.renderer:draw_rectangle(150, 200, 60, 60, semi_transparent)
    
    -- Test animated elements
    local x = 400 + math.sin(self.time) * 50
    local y = 100 + math.cos(self.time * 2) * 30
    self.renderer:draw_circle(x, y, 20, Colors.YELLOW)
    
    -- Test lines and arrows
    self.renderer:draw_line(50, 300, 200, 350, Colors.CYAN, 3)
    self.renderer:draw_arrow(250, 300, 400, 350, Colors.MAGENTA, 2, 10)
    
    -- Test text rendering
    self.renderer:draw_text("Renderer Demo", 50, 400, Colors.WHITE)
    self.renderer:draw_text("Time: " .. string.format("%.1f", self.time), 50, 420, Colors.LIGHT_GRAY)
    
    -- Test polygon (triangle)
    local triangle_points = {500, 200, 550, 150, 450, 150}
    self.renderer:draw_polygon(triangle_points, Colors.UNIT_SUPPORT)
    
    -- Test transforms
    self.renderer:push_transform()
    self.renderer:translate(500, 300)
    self.renderer:rotate(self.time)
    self.renderer:draw_rectangle(-15, -15, 30, 30, Colors.RED)
    self.renderer:pop_transform()
    
    -- Test health bars using shape definitions
    local health_shape = Shapes.HEALTH_BAR
    local health_percent = (math.sin(self.time) + 1) / 2 -- 0 to 1
    local health_color = Colors.get_health_color(health_percent)
    local health_width = health_shape.width * health_percent
    
    self.renderer:draw_rectangle(600, 100, health_shape.width, health_shape.height, Colors.DARK_GRAY)
    self.renderer:draw_rectangle(600, 100, health_width, health_shape.height, health_color)
    
    -- Test different unit shapes
    local unit_y = 450
    local spacing = 80
    
    -- Melee unit (rectangle)
    local melee = Shapes.UNIT_MELEE
    self.renderer:draw_rectangle(100 - melee.origin_x, unit_y - melee.origin_y, 
                                melee.width, melee.height, Colors.UNIT_MELEE)
    
    -- Ranged unit (circle)
    local ranged = Shapes.UNIT_RANGED
    self.renderer:draw_circle(100 + spacing, unit_y, ranged.radius, Colors.UNIT_RANGED)
    
    -- Tank unit (large rectangle)
    local tank = Shapes.UNIT_TANK
    self.renderer:draw_rectangle(100 + spacing * 2 - tank.origin_x, unit_y - tank.origin_y,
                                tank.width, tank.height, Colors.UNIT_TANK)
    
    -- Support unit (triangle)
    local support = Shapes.UNIT_SUPPORT
    local support_points = {}
    for i = 1, #support.points, 2 do
        support_points[i] = support.points[i] + 100 + spacing * 3
        support_points[i + 1] = support.points[i + 1] + unit_y
    end
    self.renderer:draw_polygon(support_points, Colors.UNIT_SUPPORT)
    
    self.renderer:end_frame()
end
-- }}}

return Demo
-- }}}