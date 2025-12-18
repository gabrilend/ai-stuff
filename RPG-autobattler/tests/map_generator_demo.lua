-- {{{ Map Generator Demo - Visual demonstration of map generation
local Demo = {}

local MapGenerator = require("src.systems.map_generator")
local Renderer = require("src.systems.renderer")
local Colors = require("src.constants.colors")
local Shapes = require("src.constants.shapes")

-- {{{ Demo:init
function Demo:init()
    self.renderer = {}
    setmetatable(self.renderer, {__index = Renderer})
    self.renderer:init()
    
    self.generator = {}
    setmetatable(self.generator, {__index = MapGenerator})
    
    self.current_map = nil
    self.complexity = 1.0
    self.current_seed = 1
    self.show_stats = true
    self.animate_generation = false
    
    -- Generate initial map
    self:generate_new_map()
end
-- }}}

-- {{{ Demo:generate_new_map
function Demo:generate_new_map()
    local width, height = 800, 600
    self.current_map = self.generator:generate_map(width, height, self.complexity, self.current_seed)
    self.map_stats = self.generator:get_map_stats(self.current_map)
end
-- }}}

-- {{{ Demo:update
function Demo:update(dt)
    -- Auto-generate new map every 5 seconds if animating
    if self.animate_generation then
        self.generation_timer = (self.generation_timer or 0) + dt
        if self.generation_timer > 5 then
            self.generation_timer = 0
            self.current_seed = self.current_seed + 1
            self:generate_new_map()
        end
    end
end
-- }}}

-- {{{ Demo:draw
function Demo:draw()
    if not self.current_map then return end
    
    self.renderer:begin_frame()
    
    -- Draw paths first (underneath everything)
    self:draw_paths()
    
    -- Draw connections
    self:draw_connections()
    
    -- Draw nodes
    self:draw_nodes()
    
    -- Draw spawn points
    self:draw_spawn_points()
    
    -- Draw UI and stats
    if self.show_stats then
        self:draw_stats()
    end
    
    self:draw_controls()
    
    self.renderer:end_frame()
end
-- }}}

-- {{{ Demo:draw_paths
function Demo:draw_paths()
    for _, path in ipairs(self.current_map.paths) do
        -- Draw path as connected line segments
        for i = 1, #path.points - 1 do
            local p1 = path.points[i]
            local p2 = path.points[i + 1]
            
            -- Draw wide path background
            self.renderer:draw_line(p1.x, p1.y, p2.x, p2.y, Colors.LANE_PATH, path.width)
            
            -- Draw path borders
            self.renderer:draw_line(p1.x, p1.y, p2.x, p2.y, Colors.LANE_BORDER, 2)
        end
        
        -- Draw control points for debugging
        if self.show_debug then
            for _, cp in ipairs(path.control_points) do
                self.renderer:draw_circle(cp.x, cp.y, 3, Colors.DEBUG_PATH)
            end
        end
    end
end
-- }}}

-- {{{ Demo:draw_connections
function Demo:draw_connections()
    for _, connection in ipairs(self.current_map.connections) do
        -- Draw connection as simple line
        self.renderer:draw_line(
            connection.from.x, connection.from.y,
            connection.to.x, connection.to.y,
            Colors.NEUTRAL, 1
        )
    end
end
-- }}}

-- {{{ Demo:draw_nodes
function Demo:draw_nodes()
    for _, node in ipairs(self.current_map.nodes) do
        -- Draw node
        self.renderer:draw_circle(node.x, node.y, 8, Colors.NEUTRAL)
        
        -- Draw node border
        self.renderer:draw_circle(node.x, node.y, 8, Colors.WHITE, "line")
    end
end
-- }}}

-- {{{ Demo:draw_spawn_points
function Demo:draw_spawn_points()
    local spawn_shape = Shapes.SPAWN_POINT
    
    -- Player 1 spawn
    local p1 = self.current_map.spawn_points.player_1
    self.renderer:draw_circle(p1.x, p1.y, spawn_shape.radius, Colors.PLAYER_1)
    self.renderer:draw_text("P1", p1.x - 8, p1.y - 6, Colors.WHITE)
    
    -- Player 2 spawn
    local p2 = self.current_map.spawn_points.player_2
    self.renderer:draw_circle(p2.x, p2.y, spawn_shape.radius, Colors.PLAYER_2)
    self.renderer:draw_text("P2", p2.x - 8, p2.y - 6, Colors.WHITE)
end
-- }}}

-- {{{ Demo:draw_stats
function Demo:draw_stats()
    local stats_text = string.format(
        "Map Statistics:\n" ..
        "Seed: %d\n" ..
        "Complexity: %.1f\n" ..
        "Nodes: %d intermediate + 2 spawn\n" ..
        "Connections: %d\n" ..
        "Paths: %d\n" ..
        "Total Path Length: %.0f\n" ..
        "Generation Time: %.3fms\n" ..
        "Avg Connections/Node: %.1f",
        self.current_map.seed or 0,
        self.complexity,
        #self.current_map.nodes,
        #self.current_map.connections,
        #self.current_map.paths,
        self.map_stats.paths.total_length,
        self.map_stats.generation_time * 1000,
        self.map_stats.connections.average_per_node
    )
    
    -- Draw background
    self.renderer:draw_rectangle(10, 10, 250, 180, Colors.UI_BG)
    
    -- Draw stats text
    self.renderer:draw_text(stats_text, 15, 15, Colors.UI_TEXT)
end
-- }}}

-- {{{ Demo:draw_controls
function Demo:draw_controls()
    local controls_text = 
        "Controls:\n" ..
        "Space: Generate New Map\n" ..
        "C: Change Complexity\n" ..
        "S: Toggle Stats\n" ..
        "A: Toggle Animation\n" ..
        "R: Reset Seed"
    
    local y_offset = 200
    
    -- Draw background
    self.renderer:draw_rectangle(10, y_offset, 200, 120, Colors.UI_BG)
    
    -- Draw controls text
    self.renderer:draw_text(controls_text, 15, y_offset + 5, Colors.UI_TEXT)
end
-- }}}

-- {{{ Demo:keypressed
function Demo:keypressed(key)
    if key == "space" then
        self.current_seed = self.current_seed + 1
        self:generate_new_map()
        
    elseif key == "c" then
        self.complexity = self.complexity + 0.5
        if self.complexity > 2.0 then
            self.complexity = 0.5
        end
        self:generate_new_map()
        
    elseif key == "s" then
        self.show_stats = not self.show_stats
        
    elseif key == "a" then
        self.animate_generation = not self.animate_generation
        if self.animate_generation then
            self.generation_timer = 0
        end
        
    elseif key == "r" then
        self.current_seed = 1
        self:generate_new_map()
        
    elseif key == "d" then
        self.show_debug = not self.show_debug
    end
end
-- }}}

return Demo
-- }}}