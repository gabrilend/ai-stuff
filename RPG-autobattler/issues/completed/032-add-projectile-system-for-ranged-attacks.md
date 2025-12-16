# Issue #032: Add Projectile System for Ranged Attacks

## Current Behavior
Ranged units lack a proper projectile system, making their attacks feel instantaneous and unrealistic.

## Intended Behavior
Ranged units should fire visible projectiles that travel from the attacker to the target, with proper physics, hit detection, and visual effects.

## Implementation Details

### Projectile System (src/systems/projectile_system.lua)
```lua
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
    
    // Remove completed projectiles (in reverse order)
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
    
    // Predict target movement for more accurate shots
    local predicted_target = predict_target_position(target_id, start_position)
    if predicted_target then
        target_position = predicted_target
    end
    
    local projectile = {
        id = generate_projectile_id(),
        type = projectile_type or "basic_arrow",
        attacker_id = attacker_id,
        target_id = target_id,
        
        // Position and movement
        position = start_position,
        target_position = target_position,
        velocity = Vector2:new(0, 0),
        speed = get_projectile_speed(projectile_type),
        
        // Properties
        damage = calculate_projectile_damage(attacker_id, projectile_type),
        lifetime = calculate_projectile_lifetime(start_position, target_position, projectile_type),
        creation_time = love.timer.getTime(),
        
        // State
        has_hit = false,
        should_remove = false,
        trail_positions = {},
        
        // Visual properties
        size = get_projectile_size(projectile_type),
        color = get_projectile_color(projectile_type),
        trail_length = get_projectile_trail_length(projectile_type)
    }
    
    // Calculate initial velocity
    local direction = target_position:subtract(start_position):normalize()
    projectile.velocity = direction:multiply(projectile.speed)
    
    // Add physics effects (gravity, arc, etc.)
    apply_projectile_physics(projectile, projectile_type)
    
    table.insert(active_projectiles, projectile)
    
    // Create muzzle flash effect
    create_muzzle_flash(attacker_id, projectile_type)
    
    Debug:log("Created projectile " .. projectile.id .. " from " .. attacker_id .. " to " .. target_id)
    return projectile.id
end
-- }}}

-- {{{ local function update_projectile
local function update_projectile(projectile, dt)
    local current_time = love.timer.getTime()
    
    // Check if projectile has expired
    if current_time - projectile.creation_time > projectile.lifetime then
        projectile.should_remove = true
        return
    end
    
    // Update position
    local old_position = Vector2:new(projectile.position.x, projectile.position.y)
    projectile.position = projectile.position:add(projectile.velocity:multiply(dt))
    
    // Update trail
    update_projectile_trail(projectile, old_position)
    
    // Apply physics effects
    apply_projectile_physics_update(projectile, dt)
    
    // Check for collisions
    if not projectile.has_hit then
        check_projectile_collisions(projectile)
    end
    
    // Check if projectile is out of bounds
    if is_projectile_out_of_bounds(projectile) then
        projectile.should_remove = true
    end
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
    
    // Calculate time for projectile to reach target
    local distance = projectile_start:distance_to(target_position)
    local projectile_speed = 150  // Assume standard speed for prediction
    local travel_time = distance / projectile_speed
    
    // Predict where target will be
    local predicted_position = target_position:add(target_velocity:multiply(travel_time))
    
    return predicted_position
end
-- }}}

-- {{{ local function check_projectile_collisions
local function check_projectile_collisions(projectile)
    // Check collision with intended target first
    if check_target_collision(projectile) then
        handle_projectile_hit(projectile, projectile.target_id)
        return
    end
    
    // Check collision with other units
    local nearby_units = get_units_near_position(projectile.position, projectile.size)
    
    for _, unit_id in ipairs(nearby_units) do
        if unit_id ~= projectile.attacker_id and unit_id ~= projectile.target_id then
            if check_unit_collision(projectile, unit_id) then
                handle_projectile_hit(projectile, unit_id)
                return
            end
        end
    end
    
    // Check collision with terrain/obstacles
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
    
    // Consider target size for collision
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

-- {{{ local function handle_projectile_hit
local function handle_projectile_hit(projectile, hit_unit_id)
    projectile.has_hit = true
    projectile.should_remove = true
    
    // Apply damage to hit unit
    local damage_dealt = apply_damage_to_unit(hit_unit_id, projectile.damage, projectile.attacker_id)
    
    // Create hit effect
    create_projectile_hit_effect(projectile, hit_unit_id, damage_dealt)
    
    // Check for special projectile effects
    apply_projectile_special_effects(projectile, hit_unit_id)
    
    Debug:log("Projectile " .. projectile.id .. " hit unit " .. hit_unit_id .. " for " .. damage_dealt .. " damage")
end
-- }}}

-- {{{ local function handle_projectile_terrain_hit
local function handle_projectile_terrain_hit(projectile)
    projectile.has_hit = true
    projectile.should_remove = true
    
    // Create terrain impact effect
    create_terrain_impact_effect(projectile)
    
    Debug:log("Projectile " .. projectile.id .. " hit terrain")
end
-- }}}

-- {{{ local function apply_projectile_physics
local function apply_projectile_physics(projectile, projectile_type)
    if projectile_type == "arrow" or projectile_type == "basic_arrow" then
        // Arrows have slight arc due to gravity
        projectile.gravity = 20
        projectile.arc_factor = 0.1
        
    elseif projectile_type == "magic_bolt" then
        // Magic bolts fly straight with no gravity
        projectile.gravity = 0
        projectile.homing_factor = 0.2  // Slight homing ability
        
    elseif projectile_type == "cannon_ball" then
        // Heavy projectiles with strong arc
        projectile.gravity = 40
        projectile.arc_factor = 0.3
        
    else
        // Default physics
        projectile.gravity = 15
        projectile.arc_factor = 0.05
    end
end
-- }}}

-- {{{ local function apply_projectile_physics_update
local function apply_projectile_physics_update(projectile, dt)
    // Apply gravity
    if projectile.gravity and projectile.gravity > 0 then
        projectile.velocity.y = projectile.velocity.y + projectile.gravity * dt
    end
    
    // Apply homing behavior
    if projectile.homing_factor and projectile.homing_factor > 0 then
        apply_homing_behavior(projectile, dt)
    end
    
    // Apply air resistance
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
    
    // Blend current velocity with homing direction
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
    // Add current position to trail
    table.insert(projectile.trail_positions, old_position)
    
    // Limit trail length
    while #projectile.trail_positions > projectile.trail_length do
        table.remove(projectile.trail_positions, 1)
    end
end
-- }}}

-- {{{ local function create_projectile_hit_effect
local function create_projectile_hit_effect(projectile, hit_unit_id, damage)
    local hit_position = Vector2:new(projectile.position.x, projectile.position.y)
    
    // Main impact effect
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
    
    // Spark particles
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
    // Render trail
    if #projectile.trail_positions > 1 then
        render_projectile_trail(renderer, projectile)
    end
    
    // Render projectile body
    local pos = projectile.position
    renderer:draw_filled_circle(pos.x, pos.y, projectile.size, projectile.color, 1.0)
    
    // Add projectile-specific visual elements
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
        local alpha = i / #trail_positions  // Fade trail over distance
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
```

### Projectile Features
1. **Physics Simulation**: Gravity, arc, and trajectory calculations
2. **Hit Detection**: Collision with targets and terrain
3. **Visual Trail**: Motion blur and trail effects
4. **Target Prediction**: Lead targets for moving enemies
5. **Special Effects**: Type-specific behaviors and visuals

### Projectile Types
- **Arrows**: Standard ranged projectiles with slight arc
- **Magic Bolts**: Fast, straight-flying magical projectiles
- **Cannon Balls**: Heavy projectiles with strong gravity arc
- **Crossbow Bolts**: Fast, accurate mechanical projectiles

### Physics Systems
- Gravity and ballistic trajectories
- Homing behavior for magical projectiles
- Air resistance and velocity decay
- Collision detection and response

### Tool Suggestions
- Use Write tool to create projectile system
- Test with various projectile types and ranges
- Verify hit detection and physics simulation
- Check visual effects and trail rendering

### Acceptance Criteria
- [ ] Projectiles travel visibly from attacker to target
- [ ] Hit detection works accurately for moving targets
- [ ] Different projectile types have distinct behaviors
- [ ] Visual trails and effects enhance combat clarity
- [ ] Physics simulation creates realistic projectile arcs