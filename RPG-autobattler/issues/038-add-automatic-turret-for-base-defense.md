# Issue #038: Add Automatic Turret for Base Defense

## Current Behavior
Bases have health and shields but lack active defensive capabilities to fight back against attacking units.

## Intended Behavior
Each base should have an automatic turret system that actively defends against enemy units, providing both offensive capability and strategic deterrent.

## Implementation Details

### Base Turret System (src/systems/base_turret_system.lua)
```lua
-- {{{ local function create_base_turret
local function create_base_turret(base_id)
    local base_position = EntityManager:get_component(base_id, "position")
    local base_team = EntityManager:get_component(base_id, "team")
    local base_data = EntityManager:get_component(base_id, "base")
    
    if not base_position or not base_team or not base_data then
        return nil
    end
    
    local turret_id = EntityManager:create_entity()
    
    // Position turret at base location
    EntityManager:add_component(turret_id, "position", {
        x = base_position.x,
        y = base_position.y,
        is_static = true,
        attached_to_base = base_id
    })
    
    EntityManager:add_component(turret_id, "team", {
        id = base_team.id,
        alliance = base_team.alliance
    })
    
    EntityManager:add_component(turret_id, "turret", {
        base_id = base_id,
        turret_type = "base_defense",
        range = 60,  // Longer range than units
        damage = 25,  // Moderate damage
        fire_rate = 1.5,  // Attacks every 1.5 seconds
        last_fire_time = 0,
        current_target = nil,
        targeting_mode = "closest_threat",
        ammunition = math.huge,  // Unlimited ammo
        rotation_angle = 0,
        rotation_speed = 90,  // Degrees per second
        accuracy = 0.9  // 90% accuracy
    })
    
    EntityManager:add_component(turret_id, "renderable", {
        shape = "base_turret",
        color = base_team.id == 1 and Colors.DARK_BLUE or Colors.DARK_RED,
        size = 15,
        visible = true,
        render_layer = "turrets",
        rotation_visual = true
    })
    
    // Register turret with base
    base_data.defensive_turret = turret_id
    
    Debug:log("Created base turret " .. turret_id .. " for base " .. base_id)
    return turret_id
end
-- }}}

-- {{{ local function update_base_turrets
local function update_base_turrets(dt)
    local all_turrets = EntityManager:get_entities_with_component("turret")
    
    for _, turret_id in ipairs(all_turrets) do
        update_turret_system(turret_id, dt)
    end
end
-- }}}

-- {{{ local function update_turret_system
local function update_turret_system(turret_id, dt)
    local turret_data = EntityManager:get_component(turret_id, "turret")
    local position = EntityManager:get_component(turret_id, "position")
    local team = EntityManager:get_component(turret_id, "team")
    
    if not turret_data or not position or not team then
        return
    end
    
    // Check if parent base is still alive
    if not is_base_alive(turret_data.base_id) then
        disable_turret(turret_id)
        return
    end
    
    // Find and track targets
    update_turret_targeting(turret_id, turret_data, position, team)
    
    // Update turret rotation
    update_turret_rotation(turret_id, turret_data, dt)
    
    // Handle firing
    update_turret_firing(turret_id, turret_data, dt)
    
    // Update visual effects
    update_turret_visual_effects(turret_id, turret_data)
end
-- }}}

-- {{{ local function update_turret_targeting
local function update_turret_targeting(turret_id, turret_data, position, team)
    local turret_pos = Vector2:new(position.x, position.y)
    
    // Check if current target is still valid
    if turret_data.current_target then
        if not is_valid_turret_target(turret_data.current_target, turret_pos, turret_data.range, team.id) then
            turret_data.current_target = nil
        end
    end
    
    // Find new target if needed
    if not turret_data.current_target then
        turret_data.current_target = find_best_turret_target(turret_pos, turret_data.range, team.id, turret_data.targeting_mode)
    end
end
-- }}}

-- {{{ local function find_best_turret_target
local function find_best_turret_target(turret_pos, range, turret_team_id, targeting_mode)
    local enemy_units = find_enemy_units_in_range_from_position(turret_pos, range, turret_team_id)
    
    if #enemy_units == 0 then
        return nil
    end
    
    local best_target = nil
    local best_score = -1
    
    for _, enemy in ipairs(enemy_units) do
        // Check line of sight
        if check_turret_line_of_sight(turret_pos, enemy.position) then
            local score = calculate_turret_target_priority(enemy, targeting_mode, turret_pos)
            
            if score > best_score then
                best_score = score
                best_target = enemy.unit_id
            end
        end
    end
    
    return best_target
end
-- }}}

-- {{{ local function calculate_turret_target_priority
local function calculate_turret_target_priority(enemy, targeting_mode, turret_pos)
    local score = 0
    
    if targeting_mode == "closest_threat" then
        // Prioritize closest enemies
        local distance_factor = math.max(0, 1 - (enemy.distance / 60))
        score = distance_factor * 50
        
        // Bonus for units approaching the base
        if is_unit_approaching_position(enemy.unit_id, turret_pos) then
            score = score + 30
        end
        
    elseif targeting_mode == "highest_threat" then
        // Prioritize dangerous unit types
        local enemy_unit_data = EntityManager:get_component(enemy.unit_id, "unit")
        if enemy_unit_data then
            if enemy_unit_data.unit_type == "melee" then
                score = score + 40  // Melee units are high threat to base
            elseif enemy_unit_data.unit_type == "ranged" then
                score = score + 20  // Ranged units moderate threat
            end
        end
        
        // Distance factor
        score = score + (1 - (enemy.distance / 60)) * 20
        
    elseif targeting_mode == "weakest_first" then
        // Prioritize damaged enemies for quick kills
        local enemy_health = EntityManager:get_component(enemy.unit_id, "health")
        if enemy_health then
            local health_ratio = enemy_health.current / enemy_health.maximum
            score = (1 - health_ratio) * 60  // Lower health = higher priority
        end
        
        // Distance factor
        score = score + (1 - (enemy.distance / 60)) * 20
    end
    
    return score
end
-- }}}

-- {{{ local function update_turret_rotation
local function update_turret_rotation(turret_id, turret_data, dt)
    if not turret_data.current_target then
        return
    end
    
    local position = EntityManager:get_component(turret_id, "position")
    local target_position = EntityManager:get_component(turret_data.current_target, "position")
    
    if not position or not target_position then
        return
    end
    
    // Calculate angle to target
    local turret_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    local direction_to_target = target_pos:subtract(turret_pos)
    
    local target_angle = math.atan2(direction_to_target.y, direction_to_target.x)
    target_angle = math.deg(target_angle)
    
    // Rotate turret toward target
    local angle_difference = target_angle - turret_data.rotation_angle
    
    // Normalize angle difference to [-180, 180]
    while angle_difference > 180 do
        angle_difference = angle_difference - 360
    end
    while angle_difference < -180 do
        angle_difference = angle_difference + 360
    end
    
    // Apply rotation
    local max_rotation = turret_data.rotation_speed * dt
    if math.abs(angle_difference) <= max_rotation then
        turret_data.rotation_angle = target_angle
    else
        local rotation_direction = angle_difference > 0 and 1 or -1
        turret_data.rotation_angle = turret_data.rotation_angle + rotation_direction * max_rotation
    end
    
    // Normalize final angle
    while turret_data.rotation_angle > 180 do
        turret_data.rotation_angle = turret_data.rotation_angle - 360
    end
    while turret_data.rotation_angle < -180 do
        turret_data.rotation_angle = turret_data.rotation_angle + 360
    end
end
-- }}}

-- {{{ local function update_turret_firing
local function update_turret_firing(turret_id, turret_data, dt)
    if not turret_data.current_target then
        return
    end
    
    local current_time = love.timer.getTime()
    
    // Check fire rate cooldown
    if current_time - turret_data.last_fire_time < turret_data.fire_rate then
        return
    end
    
    // Check if turret is aimed at target
    if not is_turret_aimed_at_target(turret_id, turret_data) then
        return
    end
    
    // Fire at target
    fire_turret_projectile(turret_id, turret_data.current_target, turret_data)
    turret_data.last_fire_time = current_time
end
-- }}}

-- {{{ local function is_turret_aimed_at_target
local function is_turret_aimed_at_target(turret_id, turret_data)
    local position = EntityManager:get_component(turret_id, "position")
    local target_position = EntityManager:get_component(turret_data.current_target, "position")
    
    if not position or not target_position then
        return false
    end
    
    // Calculate actual angle to target
    local turret_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    local direction_to_target = target_pos:subtract(turret_pos)
    
    local actual_angle = math.atan2(direction_to_target.y, direction_to_target.x)
    actual_angle = math.deg(actual_angle)
    
    // Check if turret angle is close enough to target angle
    local angle_difference = math.abs(actual_angle - turret_data.rotation_angle)
    
    // Normalize angle difference
    if angle_difference > 180 then
        angle_difference = 360 - angle_difference
    end
    
    return angle_difference < 5  // Within 5 degrees
end
-- }}}

-- {{{ local function fire_turret_projectile
local function fire_turret_projectile(turret_id, target_id, turret_data)
    // Create turret projectile
    local projectile_id = create_projectile(turret_id, target_id, "turret_shell")
    
    if projectile_id then
        // Apply turret accuracy
        apply_turret_accuracy_modifier(projectile_id, turret_data.accuracy)
        
        // Create muzzle flash effect
        create_turret_muzzle_flash(turret_id)
        
        // Create firing sound effect
        create_turret_firing_sound(turret_id)
        
        Debug:log("Turret " .. turret_id .. " fired at target " .. target_id)
    end
end
-- }}}

-- {{{ local function apply_turret_accuracy_modifier
local function apply_turret_accuracy_modifier(projectile_id, accuracy)
    if not active_projectiles then
        return
    end
    
    for _, projectile in ipairs(active_projectiles) do
        if projectile.id == projectile_id then
            // Add accuracy-based deviation
            local deviation_angle = (math.random() - 0.5) * 2 * math.pi * (1 - accuracy) * 0.05
            local cos_dev = math.cos(deviation_angle)
            local sin_dev = math.sin(deviation_angle)
            
            local original_vel = projectile.velocity
            projectile.velocity = Vector2:new(
                original_vel.x * cos_dev - original_vel.y * sin_dev,
                original_vel.x * sin_dev + original_vel.y * cos_dev
            )
            
            // Set projectile damage
            projectile.damage = 25  // Turret damage
            break
        end
    end
end
-- }}}

-- {{{ local function create_turret_muzzle_flash
local function create_turret_muzzle_flash(turret_id)
    local position = EntityManager:get_component(turret_id, "position")
    local turret_data = EntityManager:get_component(turret_id, "turret")
    
    if position and turret_data then
        // Calculate muzzle position based on turret rotation
        local angle_rad = math.rad(turret_data.rotation_angle)
        local muzzle_offset = 10  // Distance from turret center to muzzle
        
        local muzzle_x = position.x + math.cos(angle_rad) * muzzle_offset
        local muzzle_y = position.y + math.sin(angle_rad) * muzzle_offset
        
        local flash_effect = {
            type = "turret_muzzle_flash",
            position = Vector2:new(muzzle_x, muzzle_y),
            duration = 0.2,
            start_time = love.timer.getTime(),
            color = Colors.ORANGE,
            size = 8
        }
        EffectSystem:add_effect(flash_effect)
    end
end
-- }}}

-- {{{ local function update_turret_visual_effects
local function update_turret_visual_effects(turret_id, turret_data)
    local renderable = EntityManager:get_component(turret_id, "renderable")
    
    if renderable then
        // Update visual rotation
        renderable.rotation = turret_data.rotation_angle
        
        // Update targeting indicator
        if turret_data.current_target then
            renderable.targeting_active = true
            renderable.glow_intensity = 0.4
        else
            renderable.targeting_active = false
            renderable.glow_intensity = 0.1
        end
        
        // Update firing state
        local time_since_fire = love.timer.getTime() - turret_data.last_fire_time
        if time_since_fire < 0.3 then
            renderable.firing_animation = true
        else
            renderable.firing_animation = false
        end
    end
end
-- }}}

-- {{{ local function disable_turret
local function disable_turret(turret_id)
    local turret_data = EntityManager:get_component(turret_id, "turret")
    local renderable = EntityManager:get_component(turret_id, "renderable")
    
    if turret_data then
        turret_data.current_target = nil
        turret_data.disabled = true
    end
    
    if renderable then
        renderable.color = Colors.DARK_GRAY
        renderable.glow_intensity = 0
        renderable.targeting_active = false
    end
    
    Debug:log("Turret " .. turret_id .. " disabled due to base destruction")
end
-- }}}

-- {{{ local function check_turret_line_of_sight
local function check_turret_line_of_sight(turret_pos, target_pos)
    // Use simplified LOS check for turrets
    local direction = target_pos:subtract(turret_pos)
    local distance = direction:length()
    
    if distance == 0 then
        return false
    end
    
    direction = direction:normalize()
    
    // Check for major obstacles (other bases, shields)
    local step_size = 5
    local num_steps = math.ceil(distance / step_size)
    
    for i = 1, num_steps do
        local check_pos = turret_pos:add(direction:multiply(i * step_size))
        
        // Check for blocking structures
        if has_structure_at_position(check_pos) then
            return false
        end
    end
    
    return true
end
-- }}}

-- {{{ local function is_base_alive
local function is_base_alive(base_id)
    local base_health = EntityManager:get_component(base_id, "health")
    return base_health and base_health.is_alive
end
-- }}}

-- {{{ local function is_unit_approaching_position
local function is_unit_approaching_position(unit_id, position)
    local unit_pos = EntityManager:get_component(unit_id, "position")
    local unit_moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not unit_pos or not unit_moveable then
        return false
    end
    
    local unit_position = Vector2:new(unit_pos.x, unit_pos.y)
    local velocity = Vector2:new(unit_moveable.velocity_x, unit_moveable.velocity_y)
    
    if velocity:length() < 5 then
        return false
    end
    
    local direction_to_position = position:subtract(unit_position):normalize()
    local velocity_direction = velocity:normalize()
    
    return velocity_direction:dot(direction_to_position) > 0.5
end
-- }}}
```

### Base Turret Features
1. **Automatic Targeting**: Intelligent target selection and tracking
2. **Projectile Attacks**: Fires projectiles at enemy units
3. **Rotation System**: Realistic turret rotation and aiming
4. **Multiple Targeting Modes**: Different priority systems
5. **Visual Effects**: Muzzle flashes, rotation animation, targeting indicators

### Turret Capabilities
- **Long Range**: 60-unit range (longer than most units)
- **Moderate Damage**: 25 damage per shot
- **High Accuracy**: 90% base accuracy
- **Smart Targeting**: Prioritizes threats and line-of-sight

### Targeting Modes
- **Closest Threat**: Prioritize nearest enemies
- **Highest Threat**: Focus on dangerous unit types
- **Weakest First**: Target damaged enemies for quick kills

### Tool Suggestions
- Use Write tool to create base turret system
- Test turret targeting and firing mechanics
- Verify rotation and aiming accuracy
- Check visual effects and feedback

### Acceptance Criteria
- [ ] Turrets automatically target and fire at enemy units
- [ ] Rotation system realistically aims at targets
- [ ] Different targeting modes provide tactical options
- [ ] Visual effects clearly show turret activity
- [ ] Turrets provide meaningful base defense capability