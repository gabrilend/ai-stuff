-- Projectile System
-- Handles projectile creation, physics simulation, collision detection,
-- and visual effects for ranged combat

local ProjectileSystem = {}

-- Module requires
local Vector2 = require("src.utils.vector2")
local Colors = require("src.config.colors")
local Debug = require("src.utils.debug")

-- System state
local active_projectiles = {}
local projectile_id_counter = 0

-- {{{ local function update_projectile_system
local function update_projectile_system(dt)
    if not active_projectiles then
        active_projectiles = {}
    end
    
    local projectiles_to_remove = {}
    
    for i, projectile in ipairs(active_projectiles) do
        update_projectile(projectile, dt)
        
        if projectile.should_remove then
            table.insert(projectiles_to_remove, i)
        end
    end
    
    -- Remove completed projectiles (in reverse order)
    for i = #projectiles_to_remove, 1, -1 do
        table.remove(active_projectiles, projectiles_to_remove[i])
    end
end
-- }}}

-- {{{ local function create_projectile
local function create_projectile(attacker_id, target_id, projectile_type)
    local attacker_pos = EntityManager:get_component(attacker_id, "position")
    local target_pos = EntityManager:get_component(target_id, "position")
    
    if not attacker_pos or not target_pos then
        return nil
    end
    
    local start_position = Vector2:new(attacker_pos.x, attacker_pos.y)
    local target_position = Vector2:new(target_pos.x, target_pos.y)
    
    -- Predict target movement for more accurate shots
    local predicted_target = predict_target_position(target_id, start_position)
    if predicted_target then
        target_position = predicted_target
    end
    
    local projectile = {
        id = generate_projectile_id(),
        type = projectile_type or "basic_arrow",
        attacker_id = attacker_id,
        target_id = target_id,
        
        -- Position and movement
        position = start_position,
        target_position = target_position,
        velocity = Vector2:new(0, 0),
        speed = get_projectile_speed(projectile_type),
        
        -- Properties
        damage = calculate_projectile_damage(attacker_id, projectile_type),
        lifetime = calculate_projectile_lifetime(start_position, target_position, projectile_type),
        creation_time = love.timer.getTime(),
        
        -- State
        has_hit = false,
        should_remove = false,
        trail_positions = {},
        
        -- Visual properties
        size = get_projectile_size(projectile_type),
        color = get_projectile_color(projectile_type),
        trail_length = get_projectile_trail_length(projectile_type)
    }
    
    -- Calculate initial velocity
    local direction = target_position:subtract(start_position):normalize()
    projectile.velocity = direction:multiply(projectile.speed)
    
    -- Add physics effects (gravity, arc, etc.)
    apply_projectile_physics(projectile, projectile_type)
    
    table.insert(active_projectiles, projectile)
    
    -- Create muzzle flash effect
    create_muzzle_flash(attacker_id, projectile_type)
    
    Debug:log("Created projectile " .. projectile.id .. " from " .. attacker_id .. " to " .. target_id)
    return projectile.id
end
-- }}}

-- {{{ local function update_projectile
local function update_projectile(projectile, dt)
    local current_time = love.timer.getTime()
    
    -- Check if projectile has expired
    if current_time - projectile.creation_time > projectile.lifetime then
        projectile.should_remove = true
        return
    end
    
    -- Update position
    local old_position = Vector2:new(projectile.position.x, projectile.position.y)
    projectile.position = projectile.position:add(projectile.velocity:multiply(dt))
    
    -- Update trail
    update_projectile_trail(projectile, old_position)
    
    -- Apply physics effects
    apply_projectile_physics_update(projectile, dt)
    
    -- Check for collisions
    if not projectile.has_hit then
        check_projectile_collisions(projectile)
    end
    
    -- Check if projectile is out of bounds
    if is_projectile_out_of_bounds(projectile) then
        projectile.should_remove = true
    end
end
-- }}}

-- {{{ local function generate_projectile_id
local function generate_projectile_id()
    projectile_id_counter = projectile_id_counter + 1
    return "projectile_" .. projectile_id_counter
end
-- }}}

-- {{{ local function predict_target_position
local function predict_target_position(target_id, projectile_start)
    local target_pos = EntityManager:get_component(target_id, "position")
    local target_moveable = EntityManager:get_component(target_id, "moveable")
    
    if not target_pos or not target_moveable or not target_moveable.is_moving then
        return nil
    end
    
    local target_position = Vector2:new(target_pos.x, target_pos.y)
    local target_velocity = Vector2:new(target_moveable.velocity_x, target_moveable.velocity_y)
    
    -- Calculate time for projectile to reach target
    local distance = projectile_start:distance_to(target_position)
    local projectile_speed = 150  -- Assume standard speed for prediction
    local travel_time = distance / projectile_speed
    
    -- Predict where target will be
    local predicted_position = target_position:add(target_velocity:multiply(travel_time))
    
    return predicted_position
end
-- }}}

-- {{{ local function check_projectile_collisions
local function check_projectile_collisions(projectile)
    -- Check collision with intended target first
    if check_target_collision(projectile) then
        handle_projectile_hit(projectile, projectile.target_id)
        return
    end
    
    -- Check collision with other units
    local nearby_units = get_units_near_position(projectile.position, projectile.size)
    
    for _, unit_id in ipairs(nearby_units) do
        if unit_id ~= projectile.attacker_id and unit_id ~= projectile.target_id then
            if check_unit_collision(projectile, unit_id) then
                handle_projectile_hit(projectile, unit_id)
                return
            end
        end
    end
    
    -- Check collision with terrain/obstacles
    if check_terrain_collision(projectile) then
        handle_projectile_terrain_hit(projectile)
    end
end
-- }}}

-- {{{ local function check_target_collision
local function check_target_collision(projectile)
    local target_pos = EntityManager:get_component(projectile.target_id, "position")
    local target_unit = EntityManager:get_component(projectile.target_id, "unit")
    
    if not target_pos or not target_unit then
        return false
    end
    
    local target_position = Vector2:new(target_pos.x, target_pos.y)
    local distance = projectile.position:distance_to(target_position)
    
    -- Consider target size for collision
    local target_size = target_unit.size or 8
    local collision_radius = target_size / 2 + projectile.size / 2
    
    return distance <= collision_radius
end
-- }}}

-- {{{ local function check_unit_collision
local function check_unit_collision(projectile, unit_id)
    local unit_pos = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local unit_health = EntityManager:get_component(unit_id, "health")
    
    if not unit_pos or not unit_data or not unit_health or not unit_health.is_alive then
        return false
    end
    
    local unit_position = Vector2:new(unit_pos.x, unit_pos.y)
    local distance = projectile.position:distance_to(unit_position)
    
    local unit_size = unit_data.size or 8
    local collision_radius = unit_size / 2 + projectile.size / 2
    
    return distance <= collision_radius
end
-- }}}

-- {{{ local function check_terrain_collision
local function check_terrain_collision(projectile)
    -- For now, check if projectile is in lane bounds
    local sub_path = LaneSystem:get_sub_path_at_position(projectile.position)
    if not sub_path then
        return true  -- Hit terrain if outside lane
    end
    
    return false
end
-- }}}

-- {{{ local function get_units_near_position
local function get_units_near_position(position, search_radius)
    local nearby_units = {}
    local all_units = EntityManager:get_entities_with_component("position")
    
    for _, unit_id in ipairs(all_units) do
        local unit_pos = EntityManager:get_component(unit_id, "position")
        if unit_pos then
            local unit_position = Vector2:new(unit_pos.x, unit_pos.y)
            local distance = position:distance_to(unit_position)
            
            if distance <= search_radius + 10 then  -- Add some buffer
                table.insert(nearby_units, unit_id)
            end
        end
    end
    
    return nearby_units
end
-- }}}

-- {{{ local function handle_projectile_hit
local function handle_projectile_hit(projectile, hit_unit_id)
    projectile.has_hit = true
    projectile.should_remove = true
    
    -- Apply damage to hit unit
    local damage_dealt = apply_damage_to_unit(hit_unit_id, projectile.damage, projectile.attacker_id)
    
    -- Create hit effect
    create_projectile_hit_effect(projectile, hit_unit_id, damage_dealt)
    
    -- Check for special projectile effects
    apply_projectile_special_effects(projectile, hit_unit_id)
    
    Debug:log("Projectile " .. projectile.id .. " hit unit " .. hit_unit_id .. " for " .. damage_dealt .. " damage")
end
-- }}}

-- {{{ local function handle_projectile_terrain_hit
local function handle_projectile_terrain_hit(projectile)
    projectile.has_hit = true
    projectile.should_remove = true
    
    -- Create terrain impact effect
    create_terrain_impact_effect(projectile)
    
    Debug:log("Projectile " .. projectile.id .. " hit terrain")
end
-- }}}

-- {{{ local function apply_projectile_physics
local function apply_projectile_physics(projectile, projectile_type)
    if projectile_type == "arrow" or projectile_type == "basic_arrow" then
        -- Arrows have slight arc due to gravity
        projectile.gravity = 20
        projectile.arc_factor = 0.1
        
    elseif projectile_type == "magic_bolt" then
        -- Magic bolts fly straight with no gravity
        projectile.gravity = 0
        projectile.homing_factor = 0.2  -- Slight homing ability
        
    elseif projectile_type == "cannon_ball" then
        -- Heavy projectiles with strong arc
        projectile.gravity = 40
        projectile.arc_factor = 0.3
        
    else
        -- Default physics
        projectile.gravity = 15
        projectile.arc_factor = 0.05
    end
end
-- }}}

-- {{{ local function apply_projectile_physics_update
local function apply_projectile_physics_update(projectile, dt)
    -- Apply gravity
    if projectile.gravity and projectile.gravity > 0 then
        projectile.velocity.y = projectile.velocity.y + projectile.gravity * dt
    end
    
    -- Apply homing behavior
    if projectile.homing_factor and projectile.homing_factor > 0 then
        apply_homing_behavior(projectile, dt)
    end
    
    -- Apply air resistance
    if projectile.air_resistance then
        local resistance_factor = 1 - (projectile.air_resistance * dt)
        projectile.velocity = projectile.velocity:multiply(resistance_factor)
    end
end
-- }}}

-- {{{ local function apply_homing_behavior
local function apply_homing_behavior(projectile, dt)
    local target_pos = EntityManager:get_component(projectile.target_id, "position")
    
    if not target_pos then
        return
    end
    
    local target_position = Vector2:new(target_pos.x, target_pos.y)
    local direction_to_target = target_position:subtract(projectile.position):normalize()
    
    -- Blend current velocity with homing direction
    local homing_strength = projectile.homing_factor * dt
    local current_direction = projectile.velocity:normalize()
    
    local blended_direction = current_direction:multiply(1 - homing_strength):add(
        direction_to_target:multiply(homing_strength)
    ):normalize()
    
    projectile.velocity = blended_direction:multiply(projectile.velocity:length())
end
-- }}}

-- {{{ local function update_projectile_trail
local function update_projectile_trail(projectile, old_position)
    -- Add current position to trail
    table.insert(projectile.trail_positions, old_position)
    
    -- Limit trail length
    while #projectile.trail_positions > projectile.trail_length do
        table.remove(projectile.trail_positions, 1)
    end
end
-- }}}

-- {{{ local function create_projectile_hit_effect
local function create_projectile_hit_effect(projectile, hit_unit_id, damage)
    local hit_position = Vector2:new(projectile.position.x, projectile.position.y)
    
    -- Main impact effect
    local impact_effect = {
        type = "projectile_impact",
        position = hit_position,
        duration = 0.4,
        start_time = love.timer.getTime(),
        projectile_type = projectile.type,
        damage = damage,
        max_radius = 12
    }
    EffectSystem:add_effect(impact_effect)
    
    -- Spark particles
    for i = 1, 5 do
        local angle = (i / 5) * 2 * math.pi
        local particle_velocity = Vector2:new(
            math.cos(angle) * 40,
            math.sin(angle) * 40
        )
        
        local spark_effect = {
            type = "impact_spark",
            position = hit_position,
            velocity = particle_velocity,
            duration = 0.3,
            start_time = love.timer.getTime(),
            size = 1,
            color = projectile.color
        }
        EffectSystem:add_effect(spark_effect)
    end
end
-- }}}

-- {{{ local function create_terrain_impact_effect
local function create_terrain_impact_effect(projectile)
    local impact_position = Vector2:new(projectile.position.x, projectile.position.y)
    
    local terrain_effect = {
        type = "terrain_impact",
        position = impact_position,
        duration = 0.6,
        start_time = love.timer.getTime(),
        projectile_type = projectile.type,
        max_radius = 8
    }
    EffectSystem:add_effect(terrain_effect)
end
-- }}}

-- {{{ local function create_muzzle_flash
local function create_muzzle_flash(attacker_id, projectile_type)
    local attacker_pos = EntityManager:get_component(attacker_id, "position")
    
    if attacker_pos then
        local flash_effect = {
            type = "muzzle_flash",
            position = Vector2:new(attacker_pos.x, attacker_pos.y),
            duration = 0.15,
            start_time = love.timer.getTime(),
            projectile_type = projectile_type,
            color = get_muzzle_flash_color(projectile_type)
        }
        EffectSystem:add_effect(flash_effect)
    end
end
-- }}}

-- {{{ local function apply_projectile_special_effects
local function apply_projectile_special_effects(projectile, hit_unit_id)
    if projectile.type == "magic_bolt" then
        -- Magic bolts might have mana drain or magical effects
        local hit_unit_data = EntityManager:get_component(hit_unit_id, "unit")
        if hit_unit_data and hit_unit_data.mana then
            hit_unit_data.mana = math.max(0, hit_unit_data.mana - 5)
        end
        
    elseif projectile.type == "cannon_ball" then
        -- Cannon balls might have knockback effect
        create_knockback_effect(hit_unit_id, 8)
        
        -- Area damage
        local nearby_units = get_units_near_position(projectile.position, 15)
        for _, nearby_unit_id in ipairs(nearby_units) do
            if nearby_unit_id ~= hit_unit_id and nearby_unit_id ~= projectile.attacker_id then
                apply_damage_to_unit(nearby_unit_id, projectile.damage * 0.3, projectile.attacker_id)
            end
        end
    end
end
-- }}}

-- {{{ local function calculate_projectile_damage
local function calculate_projectile_damage(attacker_id, projectile_type)
    local unit_data = EntityManager:get_component(attacker_id, "unit")
    if not unit_data then
        return 10  -- Default damage
    end
    
    local base_damage = unit_data.attack_damage or 15
    
    -- Projectile type modifiers
    local damage_multipliers = {
        basic_arrow = 1.0,
        arrow = 1.1,
        magic_bolt = 0.9,
        cannon_ball = 1.5,
        crossbow_bolt = 1.2
    }
    
    local multiplier = damage_multipliers[projectile_type] or 1.0
    return math.floor(base_damage * multiplier)
end
-- }}}

-- {{{ local function calculate_projectile_lifetime
local function calculate_projectile_lifetime(start_pos, target_pos, projectile_type)
    local distance = start_pos:distance_to(target_pos)
    local speed = get_projectile_speed(projectile_type)
    
    -- Add extra time for physics effects and potential misses
    local base_time = distance / speed
    local extra_time = 2.0  -- Extra seconds for safety
    
    return base_time + extra_time
end
-- }}}

-- {{{ local function is_projectile_out_of_bounds
local function is_projectile_out_of_bounds(projectile)
    -- Check if projectile has traveled too far from map
    local map_bounds = {
        min_x = -100,
        max_x = 900,
        min_y = -100,
        max_y = 700
    }
    
    return projectile.position.x < map_bounds.min_x or 
           projectile.position.x > map_bounds.max_x or
           projectile.position.y < map_bounds.min_y or 
           projectile.position.y > map_bounds.max_y
end
-- }}}

-- {{{ local function get_projectile_speed
local function get_projectile_speed(projectile_type)
    local speeds = {
        basic_arrow = 120,
        arrow = 120,
        magic_bolt = 180,
        cannon_ball = 80,
        crossbow_bolt = 140
    }
    
    return speeds[projectile_type] or 100
end
-- }}}

-- {{{ local function get_projectile_size
local function get_projectile_size(projectile_type)
    local sizes = {
        basic_arrow = 2,
        arrow = 2,
        magic_bolt = 3,
        cannon_ball = 6,
        crossbow_bolt = 2
    }
    
    return sizes[projectile_type] or 2
end
-- }}}

-- {{{ local function get_projectile_color
local function get_projectile_color(projectile_type)
    local colors = {
        basic_arrow = Colors.BROWN,
        arrow = Colors.BROWN,
        magic_bolt = Colors.BLUE,
        cannon_ball = Colors.DARK_GRAY,
        crossbow_bolt = Colors.GRAY
    }
    
    return colors[projectile_type] or Colors.WHITE
end
-- }}}

-- {{{ local function get_projectile_trail_length
local function get_projectile_trail_length(projectile_type)
    local trail_lengths = {
        basic_arrow = 8,
        arrow = 8,
        magic_bolt = 12,
        cannon_ball = 6,
        crossbow_bolt = 10
    }
    
    return trail_lengths[projectile_type] or 8
end
-- }}}

-- {{{ local function get_muzzle_flash_color
local function get_muzzle_flash_color(projectile_type)
    local colors = {
        basic_arrow = Colors.ORANGE,
        arrow = Colors.ORANGE,
        magic_bolt = Colors.CYAN,
        cannon_ball = Colors.RED,
        crossbow_bolt = Colors.YELLOW
    }
    
    return colors[projectile_type] or Colors.WHITE
end
-- }}}

-- {{{ local function render_projectiles
local function render_projectiles(renderer)
    if not active_projectiles then
        return
    end
    
    for _, projectile in ipairs(active_projectiles) do
        render_projectile(renderer, projectile)
    end
end
-- }}}

-- {{{ local function render_projectile
local function render_projectile(renderer, projectile)
    -- Render trail
    if #projectile.trail_positions > 1 then
        render_projectile_trail(renderer, projectile)
    end
    
    -- Render projectile body
    local pos = projectile.position
    renderer:draw_filled_circle(pos.x, pos.y, projectile.size, projectile.color, 1.0)
    
    -- Add projectile-specific visual elements
    if projectile.type == "arrow" or projectile.type == "basic_arrow" then
        render_arrow_details(renderer, projectile)
    elseif projectile.type == "magic_bolt" then
        render_magic_bolt_details(renderer, projectile)
    end
end
-- }}}

-- {{{ local function render_projectile_trail
local function render_projectile_trail(renderer, projectile)
    local trail_positions = projectile.trail_positions
    
    for i = 1, #trail_positions - 1 do
        local alpha = i / #trail_positions  -- Fade trail over distance
        local thickness = projectile.size * alpha
        
        local start_pos = trail_positions[i]
        local end_pos = trail_positions[i + 1]
        
        renderer:draw_line(
            start_pos.x, start_pos.y,
            end_pos.x, end_pos.y,
            projectile.color, thickness, alpha * 0.7
        )
    end
end
-- }}}

-- {{{ local function render_arrow_details
local function render_arrow_details(renderer, projectile)
    -- Draw arrow head direction indicator
    local velocity_dir = projectile.velocity:normalize()
    local head_pos = projectile.position:add(velocity_dir:multiply(projectile.size + 2))
    
    renderer:draw_filled_circle(head_pos.x, head_pos.y, 1, Colors.DARK_GRAY, 1.0)
end
-- }}}

-- {{{ local function render_magic_bolt_details
local function render_magic_bolt_details(renderer, projectile)
    -- Draw magical glow effect
    local glow_color = {projectile.color[1], projectile.color[2], projectile.color[3], 0.3}
    renderer:draw_filled_circle(
        projectile.position.x, 
        projectile.position.y, 
        projectile.size + 2, 
        glow_color, 
        0.3
    )
end
-- }}}

-- Public API
function ProjectileSystem:update(dt)
    update_projectile_system(dt)
end

function ProjectileSystem:create_projectile(attacker_id, target_id, projectile_type)
    return create_projectile(attacker_id, target_id, projectile_type)
end

function ProjectileSystem:render(renderer)
    render_projectiles(renderer)
end

function ProjectileSystem:get_active_projectiles()
    return active_projectiles
end

function ProjectileSystem:clear_all_projectiles()
    active_projectiles = {}
end

return ProjectileSystem