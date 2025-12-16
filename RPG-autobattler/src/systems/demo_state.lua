-- {{{ DemoState
local BaseState = require("src.systems.base_state")
local TutorialSystem = require("src.systems.tutorial_system")
local MapGenerator = require("src.systems.map_generator")
local MapRenderer = require("src.systems.map_renderer")
local CollisionSystem = require("src.systems.collision_system")
local LaneSystem = require("src.systems.lane_system")
local EntityManager = require("src.systems.entity_manager")
local UnitMovementSystem = require("src.systems.unit_movement_system")
local UnitSpawningSystem = require("src.systems.unit_spawning_system")
local UnitRenderSystem = require("src.systems.unit_render_system")
local LaneFollowingSystem = require("src.systems.lane_following_system")
local ObstacleAvoidanceSystem = require("src.systems.obstacle_avoidance_system")
local FormationSystem = require("src.systems.formation_system")
local UnitQueueingSystem = require("src.systems.unit_queueing_system")
local MovementTestSystem = require("src.systems.movement_test_system")
local PathfindingSystem = require("src.systems.pathfinding_system")
local Unit = require("src.entities.unit")
local Vector2 = require("src.utils.vector2")
local Colors = require("src.constants.colors")
local debug = require("src.utils.debug")

local DemoState = BaseState:new()

-- {{{ DemoState:new
function DemoState:new(renderer)
    local state = BaseState:new(renderer, "demo")
    setmetatable(state, {__index = DemoState})
    
    -- Initialize all systems
    state.entity_manager = EntityManager:new()
    state.tutorial_system = TutorialSystem:new(renderer)
    state.lane_system = LaneSystem
    state.collision_system = CollisionSystem:new()
    
    -- Generate demo map
    state.map_data = MapGenerator:generate_map(1024, 768, 1.2, 12345) -- Fixed seed for consistency
    state.map_renderer = MapRenderer:new(renderer)
    
    -- Movement and unit systems
    state.unit_movement_system = UnitMovementSystem:new(state.entity_manager, state.lane_system)
    state.unit_spawning_system = UnitSpawningSystem:new(state.entity_manager, state.map_data, state.unit_movement_system)
    state.unit_render_system = UnitRenderSystem:new(state.entity_manager, renderer)
    state.lane_following_system = LaneFollowingSystem:new(state.entity_manager, state.lane_system, state.unit_movement_system)
    state.obstacle_avoidance_system = ObstacleAvoidanceSystem:new(state.entity_manager, state.unit_movement_system)
    state.formation_system = FormationSystem:new(state.entity_manager, state.unit_movement_system, state.lane_system)
    state.queueing_system = UnitQueueingSystem:new(state.entity_manager, state.unit_movement_system, state.lane_system)
    state.pathfinding_system = PathfindingSystem:new(state.map_data, state.lane_system)
    state.test_system = MovementTestSystem:new(
        state.entity_manager, state.map_data, state.unit_movement_system, state.unit_spawning_system,
        state.lane_following_system, state.obstacle_avoidance_system, state.formation_system, state.queueing_system
    )
    
    -- Demo state
    state.demo_phase = "tutorial"
    state.spawned_units = {}
    state.demonstration_timer = 0
    state.auto_demo_active = false
    state.show_debug_info = false
    
    -- Setup tutorial steps
    state:setup_tutorial_steps()
    
    debug.log("DemoState created with all systems", "DEMO")
    return state
end
-- }}}

-- {{{ DemoState:setup_tutorial_steps
function DemoState:setup_tutorial_steps()
    self.tutorial_system:clear_steps()
    
    -- Step 1: Welcome and Map Overview
    self.tutorial_system:add_step(
        "Welcome to RPG Autobattler!",
        "This demo showcases all implemented features. You'll see procedurally generated maps, unit systems, and advanced movement mechanics.",
        Vector2:new(512, 100),
        "down",
        "Press SPACE to continue"
    )
    
    -- Step 2: Map Generation
    self.tutorial_system:add_step(
        "Procedural Map Generation",
        "Maps are generated with random pathway networks. Each connection represents a lane where units can travel between strategic points.",
        Vector2:new(400, 300),
        "left",
        "Press SPACE to see spawn points"
    )
    
    -- Step 3: Spawn Points
    local spawn1 = self.map_data.spawn_points.player_1
    self.tutorial_system:add_step(
        "Player Spawn Points",
        "Blue and orange circles show where each player's units spawn. The pathways connect these strategic positions.",
        spawn1,
        "up",
        "Press SPACE to see lane system"
    )
    
    -- Step 4: Lane System
    self.tutorial_system:add_step(
        "5-Lane Sub-Path System",
        "Each pathway contains 5 sub-paths. Units can move side-by-side like the vision describes - creating formation opportunities.",
        Vector2:new(300, 400),
        "right",
        "Press SPACE to spawn test units"
    )
    
    -- Step 5: Unit Types
    self.tutorial_system:add_step(
        "Unit System (5 Types)",
        "Press 1-5 to spawn different unit types: 1=Melee(circle), 2=Ranged(triangle), 3=Tank(rectangle), 4=Support(small circle), 5=Special(triangle)",
        Vector2:new(100, 100),
        "down",
        "Try pressing 1, 2, 3, 4, or 5"
    )
    
    -- Step 6: Unit Movement
    self.tutorial_system:add_step(
        "Lane Following Movement",
        "Units automatically follow sub-paths with smooth steering, predictive movement, and path adherence correction.",
        Vector2:new(600, 200),
        "left",
        "Press SPACE to see formations"
    )
    
    -- Step 7: Formation System
    self.tutorial_system:add_step(
        "Formation System",
        "Press F to create formations: F1=Line, F2=Column, F3=Wedge, F4=Box, F5=Spread. Units maintain formation while moving.",
        Vector2:new(200, 500),
        "up",
        "Try pressing F1, F2, F3, F4, or F5"
    )
    
    -- Step 8: Obstacle Avoidance
    self.tutorial_system:add_step(
        "Obstacle Avoidance",
        "Units avoid collisions with allies using prediction algorithms and separation forces. Watch them navigate around each other!",
        Vector2:new(700, 400),
        "left",
        "Press SPACE to see queueing"
    )
    
    -- Step 9: Queueing System
    self.tutorial_system:add_step(
        "Intelligent Queueing",
        "When paths are blocked, units form queues with patience systems. Impatient units may switch to less crowded sub-paths.",
        Vector2:new(500, 600),
        "up",
        "Press Q to spawn many units and see queueing"
    )
    
    -- Step 10: Auto Demo
    self.tutorial_system:add_step(
        "Automated Demo",
        "Press A to start an automated demonstration. Press D to toggle debug information. Press R to reset the demo.",
        Vector2:new(100, 200),
        "right",
        "Press A for auto demo, D for debug, R to reset"
    )
    
    -- Step 11: Controls Summary
    self.tutorial_system:add_step(
        "Control Summary",
        "1-5: Spawn units, F1-F5: Formations, Q: Spawn many, A: Auto demo, D: Debug, R: Reset, ESC: Exit tutorial",
        Vector2:new(400, 50),
        "down",
        "Press SPACE to start exploring!"
    )
end
-- }}}

-- {{{ DemoState:enter
function DemoState:enter()
    debug.log("Entering demo state", "DEMO")
    self.tutorial_system:start_tutorial()
    
    -- Enable debug features for demo
    self.map_renderer:toggle_debug_info()
    self.unit_render_system:set_debug_info_visibility(false) -- Start with debug off
end
-- }}}

-- {{{ DemoState:exit
function DemoState:exit()
    debug.log("Exiting demo state", "DEMO")
    self.tutorial_system:stop_tutorial()
    self:cleanup_demo_units()
end
-- }}}

-- {{{ DemoState:update
function DemoState:update(dt)
    self.demonstration_timer = self.demonstration_timer + dt
    
    -- Update tutorial system
    self.tutorial_system:update(dt)
    
    -- Update all game systems
    self.unit_movement_system:update(dt)
    self.lane_following_system:update(dt)
    self.obstacle_avoidance_system:update(dt)
    self.formation_system:update(dt)
    self.queueing_system:update(dt)
    
    -- Auto demo logic
    if self.auto_demo_active then
        self:update_auto_demo(dt)
    end
end
-- }}}

-- {{{ DemoState:update_auto_demo
function DemoState:update_auto_demo(dt)
    local demo_time = self.demonstration_timer
    
    -- Spawn units at different intervals to show different behaviors
    if math.floor(demo_time) % 8 == 1 and math.floor(demo_time) > 0 then
        -- Spawn formation every 8 seconds
        self:spawn_formation_demo()
    elseif math.floor(demo_time) % 5 == 2 then
        -- Spawn individual units every 5 seconds
        self:spawn_individual_units()
    elseif math.floor(demo_time) % 12 == 6 then
        -- Create congestion scenario every 12 seconds
        self:create_congestion_demo()
    end
end
-- }}}

-- {{{ DemoState:draw
function DemoState:draw()
    -- Draw map
    self.map_renderer:draw_map(self.map_data)
    
    -- Draw units
    self.unit_render_system:draw()
    
    -- Draw tutorial overlay
    self.tutorial_system:draw()
    
    -- Draw debug information if enabled
    if self.show_debug_info then
        self:draw_debug_overlay()
    end
    
    -- Draw controls hint
    if not self.tutorial_system:is_active() then
        self:draw_controls_hint()
    end
end
-- }}}

-- {{{ DemoState:draw_debug_overlay
function DemoState:draw_debug_overlay()
    local debug_y = 30
    local debug_color = Colors.UI_TEXT
    
    -- System information
    local queue_info = self.queueing_system:get_debug_info()
    local formation_info = self.formation_system:get_debug_info()
    local avoidance_info = self.obstacle_avoidance_system:get_debug_info()
    
    self.renderer:draw_text("=== DEBUG INFO ===", 10, debug_y, debug_color)
    debug_y = debug_y + 20
    
    self.renderer:draw_text("Units: " .. self.entity_manager:get_entity_count(), 10, debug_y, debug_color)
    debug_y = debug_y + 15
    
    self.renderer:draw_text("Queues: " .. queue_info.total_queues .. " (" .. queue_info.total_queued_units .. " units)", 10, debug_y, debug_color)
    debug_y = debug_y + 15
    
    self.renderer:draw_text("Formations: " .. formation_info.total_formations, 10, debug_y, debug_color)
    debug_y = debug_y + 15
    
    self.renderer:draw_text("Avoiding: " .. avoidance_info.units_avoiding .. "/" .. avoidance_info.total_units, 10, debug_y, debug_color)
    debug_y = debug_y + 15
    
    if self.auto_demo_active then
        self.renderer:draw_text("Auto Demo: ON", 10, debug_y, Colors.GREEN)
    else
        self.renderer:draw_text("Auto Demo: OFF", 10, debug_y, Colors.RED)
    end
end
-- }}}

-- {{{ DemoState:draw_controls_hint
function DemoState:draw_controls_hint()
    local hint_text = "1-5: Spawn Units | F1-F5: Formations | Q: Many Units | A: Auto Demo | D: Debug | R: Reset | T: Tutorial"
    local hint_color = {0.7, 0.7, 0.7, 0.8}
    
    self.renderer:draw_text(hint_text, 10, love.graphics.getHeight() - 25, hint_color)
end
-- }}}

-- {{{ DemoState:handle_input
function DemoState:handle_input(key)
    -- Tutorial system handles input first
    if self.tutorial_system:handle_input(key) then
        return true
    end
    
    -- Demo controls
    if key == "1" then
        self:spawn_unit("melee", 1)
    elseif key == "2" then
        self:spawn_unit("ranged", 1)
    elseif key == "3" then
        self:spawn_unit("tank", 1)
    elseif key == "4" then
        self:spawn_unit("support", 1)
    elseif key == "5" then
        self:spawn_unit("special", 1)
    elseif key == "6" then
        self:spawn_unit("melee", 2)
    elseif key == "7" then
        self:spawn_unit("ranged", 2)
    elseif key == "8" then
        self:spawn_unit("tank", 2)
    elseif key == "f1" then
        self:create_formation("line")
    elseif key == "f2" then
        self:create_formation("column")
    elseif key == "f3" then
        self:create_formation("wedge")
    elseif key == "f4" then
        self:create_formation("box")
    elseif key == "f5" then
        self:create_formation("spread")
    elseif key == "q" then
        self:spawn_many_units()
    elseif key == "a" then
        self:toggle_auto_demo()
    elseif key == "d" then
        self:toggle_debug_info()
    elseif key == "r" then
        self:reset_demo()
    elseif key == "t" then
        self:restart_tutorial()
    end
    
    return true
end
-- }}}

-- {{{ DemoState:spawn_unit
function DemoState:spawn_unit(unit_type, player_id)
    local success = self.unit_spawning_system:spawn_immediate(player_id, unit_type, "center")
    if success then
        debug.log("Spawned " .. unit_type .. " for player " .. player_id, "DEMO")
    end
end
-- }}}

-- {{{ DemoState:create_formation
function DemoState:create_formation(formation_type)
    -- Get some recent units to form formation
    local units = self.entity_manager:get_entities_with_components({
        "position", "team", "unit_data"
    })
    
    local player1_units = {}
    for _, unit in ipairs(units) do
        local team = self.entity_manager:get_component(unit, "team")
        if team and team.player_id == 1 and #player1_units < 6 then
            table.insert(player1_units, unit)
        end
    end
    
    if #player1_units >= 3 then
        local formation = self.formation_system:create_formation(player1_units, formation_type)
        if formation then
            debug.log("Created " .. formation_type .. " formation with " .. #player1_units .. " units", "DEMO")
        end
    else
        debug.log("Need at least 3 units to create formation (spawn some with 1-5 keys)", "DEMO")
    end
end
-- }}}

-- {{{ DemoState:spawn_many_units
function DemoState:spawn_many_units()
    -- Spawn multiple units to demonstrate queueing
    for i = 1, 8 do
        local unit_types = {"melee", "ranged", "tank", "support", "special"}
        local unit_type = unit_types[((i - 1) % #unit_types) + 1]
        self.unit_spawning_system:queue_unit_spawn(1, unit_type, "center")
    end
    
    -- Also spawn some for player 2
    for i = 1, 5 do
        local unit_types = {"melee", "ranged", "tank"}
        local unit_type = unit_types[((i - 1) % #unit_types) + 1]
        self.unit_spawning_system:queue_unit_spawn(2, unit_type, "center")
    end
    
    debug.log("Queued many units for both players", "DEMO")
end
-- }}}

-- {{{ DemoState:spawn_formation_demo
function DemoState:spawn_formation_demo()
    local unit_types = {"melee", "ranged", "tank", "support", "special", "melee"}
    local formation_types = {"line", "wedge", "column", "box"}
    local formation_type = formation_types[math.random(#formation_types)]
    
    local spawned_units = self.unit_spawning_system:spawn_formation(1, unit_types, formation_type)
    debug.log("Auto demo: spawned " .. formation_type .. " formation", "DEMO")
end
-- }}}

-- {{{ DemoState:spawn_individual_units
function DemoState:spawn_individual_units()
    local unit_types = {"melee", "ranged", "tank", "support", "special"}
    local unit_type = unit_types[math.random(#unit_types)]
    local player_id = math.random(2)
    
    self.unit_spawning_system:spawn_immediate(player_id, unit_type, "center")
end
-- }}}

-- {{{ DemoState:create_congestion_demo
function DemoState:create_congestion_demo()
    -- Spawn many units in same area to show queueing
    for i = 1, 6 do
        self.unit_spawning_system:spawn_immediate(1, "melee", "center")
    end
    debug.log("Auto demo: created congestion scenario", "DEMO")
end
-- }}}

-- {{{ DemoState:toggle_auto_demo
function DemoState:toggle_auto_demo()
    self.auto_demo_active = not self.auto_demo_active
    if self.auto_demo_active then
        self.demonstration_timer = 0
        debug.log("Started auto demo", "DEMO")
    else
        debug.log("Stopped auto demo", "DEMO")
    end
end
-- }}}

-- {{{ DemoState:toggle_debug_info
function DemoState:toggle_debug_info()
    self.show_debug_info = not self.show_debug_info
    self.unit_render_system:set_debug_info_visibility(self.show_debug_info)
    debug.log("Debug info: " .. (self.show_debug_info and "ON" or "OFF"), "DEMO")
end
-- }}}

-- {{{ DemoState:reset_demo
function DemoState:reset_demo()
    self:cleanup_demo_units()
    self.auto_demo_active = false
    self.demonstration_timer = 0
    debug.log("Reset demo", "DEMO")
end
-- }}}

-- {{{ DemoState:restart_tutorial
function DemoState:restart_tutorial()
    self:reset_demo()
    self.tutorial_system:start_tutorial()
    debug.log("Restarted tutorial", "DEMO")
end
-- }}}

-- {{{ DemoState:cleanup_demo_units
function DemoState:cleanup_demo_units()
    local units = self.entity_manager:get_entities_with_components({
        "position", "unit_data"
    })
    
    for _, unit in ipairs(units) do
        self.entity_manager:remove_entity(unit)
    end
    
    -- Clear formations and queues
    for formation_id, _ in pairs(self.formation_system.formations) do
        self.formation_system:break_formation(formation_id)
    end
    
    debug.log("Cleaned up demo units", "DEMO")
end
-- }}}

return DemoState
-- }}}