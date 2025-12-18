-- {{{ Unit entity factory
local Unit = {}

local Vector2 = require("src.utils.vector2")
local Colors = require("src.constants.colors")

-- Component factories
local PositionComponent = require("src.components.position")
local HealthComponent = require("src.components.health")
local TeamComponent = require("src.components.team")
local MoveableComponent = require("src.components.moveable")
local RenderableComponent = require("src.components.renderable")

-- Unit templates for standardized creation
local unit_templates = {
    melee = {
        id = "melee",
        unit_type = "melee",
        max_health = 120,
        speed = 60,
        size = 8,
        shape = "circle"
    },
    ranged = {
        id = "ranged", 
        unit_type = "ranged",
        max_health = 80,
        speed = 45,
        size = 7,
        shape = "triangle"
    },
    tank = {
        id = "tank",
        unit_type = "tank", 
        max_health = 200,
        speed = 30,
        size = 12,
        shape = "rectangle"
    },
    support = {
        id = "support",
        unit_type = "support",
        max_health = 60,
        speed = 50,
        size = 6,
        shape = "circle"
    },
    special = {
        id = "special",
        unit_type = "special",
        max_health = 100,
        speed = 70,
        size = 9,
        shape = "triangle"
    }
}

-- {{{ local function validate_unit_template
local function validate_unit_template(template)
    local required_fields = {
        "id", "max_health", "unit_type", "speed"
    }
    
    for _, field in ipairs(required_fields) do
        if not template[field] then
            error("Unit template missing required field: " .. field)
        end
    end
    
    if template.unit_type ~= "melee" and template.unit_type ~= "ranged" and 
       template.unit_type ~= "tank" and template.unit_type ~= "support" and 
       template.unit_type ~= "special" then
        error("Invalid unit_type: " .. tostring(template.unit_type))
    end
    
    if template.max_health <= 0 then
        error("Unit max_health must be positive")
    end
    
    if template.speed <= 0 then
        error("Unit speed must be positive")
    end
    
    return true
end
-- }}}

-- {{{ local function create_unit
local function create_unit(entity_manager, template, team, spawn_position, sub_path_id)
    validate_unit_template(template)
    
    local unit_name = "unit_" .. template.unit_type .. "_p" .. team .. "_" .. os.time()
    local unit_id = entity_manager:create_entity(unit_name)
    
    -- Core properties - Position
    local position = PositionComponent(spawn_position.x, spawn_position.y)
    position.previous_x = spawn_position.x
    position.previous_y = spawn_position.y
    position.sub_path_id = sub_path_id
    entity_manager:add_component(unit_id, "position", position)
    
    -- Core properties - Health
    local health = HealthComponent(template.max_health)
    health.maximum = template.max_health
    health.is_alive = true
    health.last_damage_time = 0
    entity_manager:add_component(unit_id, "health", health)
    
    -- Core properties - Team
    local team_component = TeamComponent(team, Unit.get_team_color(team))
    team_component.alliance = team == 1 and "player" or "enemy"
    entity_manager:add_component(unit_id, "team", team_component)
    
    -- Core properties - Unit data
    local unit_data = {
        template_id = template.id,
        unit_type = template.unit_type,
        speed = template.speed,
        size = template.size or 8,
        state = "spawning", -- spawning, moving, combat, dead
        current_sub_path = sub_path_id,
        target_position = nil,
        formation_position = nil,
        combat_state = "idle",
        last_move_time = 0,
        spawn_time = love and love.timer and love.timer.getTime() or 0
    }
    entity_manager:add_component(unit_id, "unit_data", unit_data)
    
    -- Core properties - Movement
    local moveable = MoveableComponent(0, 0, spawn_position.x, spawn_position.y)
    moveable.velocity_x = 0
    moveable.velocity_y = 0
    moveable.is_moving = false
    moveable.path_progress = 0
    moveable.speed = template.speed
    moveable.max_speed = template.speed * 1.5
    entity_manager:add_component(unit_id, "moveable", moveable)
    
    -- Core properties - Rendering
    local team_color = Unit.get_team_color(team)
    local renderable = RenderableComponent(template.shape or "circle", team_color, template.size or 8)
    renderable.visible = true
    renderable.render_layer = "units"
    entity_manager:add_component(unit_id, "renderable", renderable)
    
    return unit_id
end
-- }}}

-- {{{ Unit.create_unit_from_template
function Unit.create_unit_from_template(entity_manager, template_id, team, spawn_position, sub_path_id)
    local template = unit_templates[template_id]
    if not template then
        error("Unknown unit template: " .. tostring(template_id))
    end
    
    return create_unit(entity_manager, template, team, spawn_position, sub_path_id)
end
-- }}}

-- {{{ Unit.create_unit_from_custom_template
function Unit.create_unit_from_custom_template(entity_manager, template, team, spawn_position, sub_path_id)
    return create_unit(entity_manager, template, team, spawn_position, sub_path_id)
end
-- }}}

-- {{{ Unit.get_template
function Unit.get_template(template_id)
    return unit_templates[template_id]
end
-- }}}

-- {{{ Unit.get_all_templates
function Unit.get_all_templates()
    return unit_templates
end
-- }}}

-- {{{ Unit.create_basic_unit
function Unit.create_basic_unit(entity_manager, x, y, player_id, unit_type)
    unit_type = unit_type or "melee"
    local unit_name = "unit_" .. unit_type .. "_p" .. player_id .. "_" .. os.time()
    
    -- Create entity
    local entity = entity_manager:create_entity(unit_name)
    
    -- Add position component
    local position = PositionComponent(x, y)
    entity_manager:add_component(entity, "position", position)
    
    -- Add health component based on unit type
    local max_hp = Unit.get_unit_base_health(unit_type)
    local health = HealthComponent(max_hp)
    entity_manager:add_component(entity, "health", health)
    
    -- Add team component
    local team_color = Unit.get_team_color(player_id)
    local team = TeamComponent(player_id, team_color)
    entity_manager:add_component(entity, "team", team)
    
    -- Add movement component
    local movement = MoveableComponent(0, 0, nil, nil)
    movement.speed = Unit.get_unit_base_speed(unit_type)
    movement.max_speed = movement.speed * 1.5
    entity_manager:add_component(entity, "moveable", movement)
    
    -- Add renderable component
    local unit_color = team_color
    local unit_shape = Unit.get_unit_shape(unit_type)
    local unit_size = Unit.get_unit_size(unit_type)
    local renderable = RenderableComponent(unit_shape, unit_color, unit_size)
    entity_manager:add_component(entity, "renderable", renderable)
    
    -- Add unit-specific data component
    local unit_data = {
        unit_type = unit_type,
        current_sub_path = nil,
        target_position = nil,
        formation_position = nil,
        combat_state = "idle", -- idle, moving, combat, retreating
        last_move_time = 0,
        spawn_time = love and love.timer and love.timer.getTime() or 0
    }
    entity_manager:add_component(entity, "unit_data", unit_data)
    
    return entity
end
-- }}}

-- {{{ Unit.get_unit_base_health
function Unit.get_unit_base_health(unit_type)
    local health_values = {
        melee = 120,
        ranged = 80,
        tank = 200,
        support = 60,
        special = 100
    }
    return health_values[unit_type] or 100
end
-- }}}

-- {{{ Unit.get_unit_base_speed
function Unit.get_unit_base_speed(unit_type)
    local speed_values = {
        melee = 60,    -- Medium speed
        ranged = 45,   -- Slower speed
        tank = 30,     -- Slow speed
        support = 50,  -- Medium-slow speed
        special = 70   -- Fast speed
    }
    return speed_values[unit_type] or 50
end
-- }}}

-- {{{ Unit.get_team_color
function Unit.get_team_color(player_id)
    if player_id == 1 then
        return Colors.TEAM_A
    elseif player_id == 2 then
        return Colors.TEAM_B
    else
        return Colors.NEUTRAL
    end
end
-- }}}

-- {{{ Unit.get_unit_shape
function Unit.get_unit_shape(unit_type)
    local shapes = {
        melee = "circle",      -- Circles for melee units
        ranged = "triangle",   -- Triangles for ranged units
        tank = "rectangle",    -- Rectangles for tanks
        support = "circle",    -- Circles for support
        special = "triangle"   -- Triangles for special units
    }
    return shapes[unit_type] or "circle"
end
-- }}}

-- {{{ Unit.get_unit_size
function Unit.get_unit_size(unit_type)
    local sizes = {
        melee = 8,
        ranged = 7,
        tank = 12,
        support = 6,
        special = 9
    }
    return sizes[unit_type] or 8
end
-- }}}

-- {{{ Unit.get_unit_color_by_type
function Unit.get_unit_color_by_type(unit_type, player_id)
    local base_color = Unit.get_team_color(player_id)
    
    -- Modify base color slightly based on unit type for variety
    local type_modifiers = {
        melee = {1.0, 1.0, 1.0},     -- No change
        ranged = {0.8, 1.0, 0.8},    -- Slightly green tint
        tank = {1.0, 0.8, 1.0},      -- Slightly purple tint
        support = {1.0, 1.0, 0.8},   -- Slightly yellow tint
        special = {0.9, 0.9, 1.0}    -- Slightly blue tint
    }
    
    local modifier = type_modifiers[unit_type] or {1.0, 1.0, 1.0}
    
    return {
        base_color[1] * modifier[1],
        base_color[2] * modifier[2],
        base_color[3] * modifier[3],
        base_color[4]
    }
end
-- }}}

-- {{{ Unit.create_melee_unit
function Unit.create_melee_unit(entity_manager, x, y, player_id)
    local spawn_position = Vector2:new(x, y)
    return Unit.create_unit_from_template(entity_manager, "melee", player_id, spawn_position, nil)
end
-- }}}

-- {{{ Unit.create_ranged_unit
function Unit.create_ranged_unit(entity_manager, x, y, player_id)
    local spawn_position = Vector2:new(x, y)
    return Unit.create_unit_from_template(entity_manager, "ranged", player_id, spawn_position, nil)
end
-- }}}

-- {{{ Unit.create_tank_unit
function Unit.create_tank_unit(entity_manager, x, y, player_id)
    local spawn_position = Vector2:new(x, y)
    return Unit.create_unit_from_template(entity_manager, "tank", player_id, spawn_position, nil)
end
-- }}}

-- {{{ Unit.create_support_unit
function Unit.create_support_unit(entity_manager, x, y, player_id)
    local spawn_position = Vector2:new(x, y)
    return Unit.create_unit_from_template(entity_manager, "support", player_id, spawn_position, nil)
end
-- }}}

-- {{{ Unit.create_special_unit
function Unit.create_special_unit(entity_manager, x, y, player_id)
    local spawn_position = Vector2:new(x, y)
    return Unit.create_unit_from_template(entity_manager, "special", player_id, spawn_position, nil)
end
-- }}}

-- {{{ Unit.is_unit
function Unit.is_unit(entity_manager, entity)
    return entity_manager:has_components(entity, {"position", "health", "team", "moveable", "renderable", "unit_data"})
end
-- }}}

-- {{{ Unit.get_unit_type
function Unit.get_unit_type(entity_manager, entity)
    local unit_data = entity_manager:get_component(entity, "unit_data")
    return unit_data and unit_data.unit_type or "unknown"
end
-- }}}

-- {{{ Unit.is_alive
function Unit.is_alive(entity_manager, entity)
    local health = entity_manager:get_component(entity, "health")
    return health and health.alive and health.current_hp > 0
end
-- }}}

-- {{{ Unit.get_team_id
function Unit.get_team_id(entity_manager, entity)
    local team = entity_manager:get_component(entity, "team")
    return team and team.player_id or 0
end
-- }}}

-- {{{ Unit.are_enemies
function Unit.are_enemies(entity_manager, unit1, entity2)
    local team1 = entity_manager:get_component(unit1, "team")
    local team2 = entity_manager:get_component(unit2, "team")
    
    if not team1 or not team2 then
        return false
    end
    
    return team1.player_id ~= team2.player_id
end
-- }}}

-- {{{ Unit.get_position
function Unit.get_position(entity_manager, entity)
    local position = entity_manager:get_component(entity, "position")
    if position then
        return Vector2:new(position.x, position.y)
    end
    return Vector2:new(0, 0)
end
-- }}}

-- {{{ Unit.set_position
function Unit.set_position(entity_manager, entity, x, y)
    local position = entity_manager:get_component(entity, "position")
    if position then
        position.previous_x = position.x
        position.previous_y = position.y
        position.x = x
        position.y = y
        return true
    end
    return false
end
-- }}}

-- {{{ Unit.damage_unit
function Unit.damage_unit(entity_manager, entity, damage)
    local health = entity_manager:get_component(entity, "health")
    if not health or not health.alive then
        return false
    end
    
    health.current_hp = math.max(0, health.current_hp - damage)
    health.damage_taken = health.damage_taken + damage
    
    if health.current_hp <= 0 then
        health.alive = false
        health.current_hp = 0
    end
    
    return true
end
-- }}}

-- {{{ Unit.heal_unit
function Unit.heal_unit(entity_manager, entity, healing)
    local health = entity_manager:get_component(entity, "health")
    if not health or not health.alive then
        return false
    end
    
    local actual_healing = math.min(healing, health.max_hp - health.current_hp)
    health.current_hp = health.current_hp + actual_healing
    health.healing_received = health.healing_received + actual_healing
    
    return actual_healing > 0
end
-- }}}

-- {{{ Unit.test_template_validation
function Unit.test_template_validation()
    local debug = require("src.utils.debug")
    
    debug.log("Testing unit template validation", "UNIT")
    
    -- Test valid templates
    for template_id, template in pairs(unit_templates) do
        local success, err = pcall(validate_unit_template, template)
        if success then
            debug.log("✓ Template '" .. template_id .. "' is valid", "UNIT")
        else
            debug.error("✗ Template '" .. template_id .. "' failed validation: " .. err, "UNIT")
        end
    end
    
    -- Test invalid template (missing field)
    local invalid_template = {
        id = "invalid",
        unit_type = "melee"
        -- missing max_health and speed
    }
    local success, err = pcall(validate_unit_template, invalid_template)
    if not success then
        debug.log("✓ Invalid template correctly rejected: " .. err, "UNIT")
    else
        debug.error("✗ Invalid template was incorrectly accepted", "UNIT")
    end
    
    -- Test invalid unit type
    local bad_type_template = {
        id = "bad_type",
        unit_type = "invalid_type",
        max_health = 100,
        speed = 50
    }
    success, err = pcall(validate_unit_template, bad_type_template)
    if not success then
        debug.log("✓ Invalid unit_type correctly rejected: " .. err, "UNIT")
    else
        debug.error("✗ Invalid unit_type was incorrectly accepted", "UNIT")
    end
    
    debug.log("Template validation tests completed", "UNIT")
end
-- }}}

-- {{{ Unit.test_unit_creation
function Unit.test_unit_creation()
    local debug = require("src.utils.debug")
    local EntityManager = require("src.systems.entity_manager")
    
    debug.log("Testing unit creation with templates", "UNIT")
    
    local entity_manager = EntityManager:new()
    local spawn_position = Vector2:new(100, 100)
    
    -- Test creating units from each template
    for template_id, _ in pairs(unit_templates) do
        local success, unit_id = pcall(Unit.create_unit_from_template, 
            entity_manager, template_id, 1, spawn_position, nil)
        
        if success then
            -- Verify all required components exist
            local has_all_components = entity_manager:has_components(unit_id, 
                {"position", "health", "team", "unit_data", "moveable", "renderable"})
            
            if has_all_components then
                debug.log("✓ Unit created successfully from template '" .. template_id .. "'", "UNIT")
                
                -- Verify component data
                local unit_data = entity_manager:get_component(unit_id, "unit_data")
                local health = entity_manager:get_component(unit_id, "health")
                local position = entity_manager:get_component(unit_id, "position")
                
                if unit_data.template_id == template_id and 
                   health.maximum == unit_templates[template_id].max_health and
                   position.x == spawn_position.x and position.y == spawn_position.y then
                    debug.log("✓ Unit components properly initialized for '" .. template_id .. "'", "UNIT")
                else
                    debug.error("✗ Unit components incorrectly initialized for '" .. template_id .. "'", "UNIT")
                end
            else
                debug.error("✗ Unit missing required components for template '" .. template_id .. "'", "UNIT")
            end
        else
            debug.error("✗ Failed to create unit from template '" .. template_id .. "': " .. unit_id, "UNIT")
        end
    end
    
    debug.log("Unit creation tests completed", "UNIT")
end
-- }}}

return Unit
-- }}}