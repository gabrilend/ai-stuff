local units = {}
local projectiles = {}

local Projectile = {}
Projectile.__index = Projectile

function Projectile:new(x, y, target_x, target_y, damage, owner, projectile_type)
    local projectile = {
        x = x,
        y = y,
        target_x = target_x,
        target_y = target_y,
        damage = damage,
        owner = owner,
        speed = projectile_type == "arrow" and 300 or 200,  -- Arrows faster than spells
        color = projectile_type == "arrow" and {0.6, 0.4, 0.2} or {0.3, 0.3, 0.9},
        radius = projectile_type == "arrow" and 3 or 5,
        lifetime = 3,  -- 3 seconds before disappearing
        projectile_type = projectile_type,
        has_hit = false
    }
    setmetatable(projectile, Projectile)
    return projectile
end

function Projectile:update(dt)
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        return false  -- Remove projectile
    end
    
    -- Move toward target
    local dx = self.target_x - self.x
    local dy = self.target_y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance < 5 or self.has_hit then
        -- Close to target or already hit, apply damage to nearby enemy
        self:check_for_hits()
        return false  -- Remove projectile
    end
    
    -- Move projectile
    local move_x = (dx / distance) * self.speed * dt
    local move_y = (dy / distance) * self.speed * dt
    self.x = self.x + move_x
    self.y = self.y + move_y
    
    -- Check for hits during flight
    self:check_for_hits()
    
    return true  -- Keep projectile alive
end

function Projectile:check_for_hits()
    if self.has_hit then return end
    
    -- Check for collision with enemy units
    for _, unit in ipairs(units) do
        if unit.owner ~= self.owner then
            local dx = unit.x - self.x
            local dy = unit.y - self.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= unit.radius + self.radius then
                unit:take_damage(self.damage)
                self.has_hit = true
                return
            end
        end
    end
end

function Projectile:draw()
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    
    -- Add a trail effect for arrows
    if self.projectile_type == "arrow" then
        love.graphics.setColor(self.color[1] * 0.5, self.color[2] * 0.5, self.color[3] * 0.5, 0.7)
        local angle = math.atan2(self.target_y - self.y, self.target_x - self.x)
        local trail_x = self.x - math.cos(angle) * 8
        local trail_y = self.y - math.sin(angle) * 8
        love.graphics.circle("fill", trail_x, trail_y, self.radius * 0.5)
    end
end

local unit_types = {
    warrior = {
        health = 15,
        damage = 3,
        speed = 30,
        range = 15,
        type = "melee",
        color = {0.8, 0.2, 0.2}
    },
    archer = {
        health = 8,
        damage = 4,
        speed = 35,  -- Faster movement - they're confident!
        range = 80,
        type = "ranged",
        ammo = 20,
        color = {0.2, 0.8, 0.2}
    },
    mage = {
        health = 6,
        damage = 6,
        speed = 20,
        range = 100,
        type = "spell",
        color = {0.2, 0.2, 0.8}
    }
}

local Unit = {}
Unit.__index = Unit

-- Map unit types to pathfinding archetypes
local unit_type_archetypes = {
    warrior = "aggressive_warrior",
    archer = "cautious_archer",
    mage = "spell_caster"
}

function Unit:new(x, y, unit_type, owner)
    local type_data = unit_types[unit_type]
    local unit = {
        x = x,
        y = y,
        target_x = x,
        target_y = y,
        health = type_data.health,
        max_health = type_data.health,
        damage = type_data.damage,
        speed = type_data.speed,
        range = type_data.range,
        type = type_data.type,
        color = type_data.color,
        owner = owner,
        radius = 8,
        target = nil,
        current_room = nil,
        ammo = type_data.ammo or 0,
        attack_cooldown = 0,
        -- Pathfinding integration
        pathfinding_archetype = unit_type_archetypes[unit_type] or "aggressive_warrior",
        flow_field_timer = 0,
        -- Simplified movement variables
        exploration_timer = math.random(3, 8),
        room_wait_timer = 0,
        orbit_angle = math.random() * 2 * math.pi,
        orbit_direction = (math.random() < 0.5) and 1 or -1,
        personal_space_timer = 0,
        kiting_direction = 0,
        last_position = {x = x, y = y},
        stuck_timer = 0,
        -- Darting strike variables
        is_striking = false,
        strike_phase = "orbit", -- "orbit", "dart_in", "attacking", "retreat"
        strike_timer = 0,
        strike_start_pos = {x = x, y = y},
        strike_target_pos = {x = x, y = y},
        orbit_time = 0,
        strikes_performed = 0,
        -- Neutral unit fields
        home_room = nil,
        is_defender = false,
        is_independent = false,
        disperse_timer = 0
    }
    setmetatable(unit, Unit)
    return unit
end

function Unit:draw()
    local draw_color = self.color
    
    -- Handle different team colors
    if self.owner == 1 then
        -- Player units: normal bright colors
        draw_color = self.color
    elseif self.owner == 2 then
        -- Enemy units: darker versions
        draw_color = {self.color[1] * 0.5, self.color[2] * 0.5, self.color[3] * 0.5}
    elseif self.owner == 3 then
        -- Neutral/Independent units: proper gray coloring
        draw_color = {0.7, 0.7, 0.7}
    else
        -- Unknown owner: gray
        draw_color = {0.5, 0.5, 0.5}
    end
    
    love.graphics.setColor(draw_color)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    
    -- Border color based on team
    if self.owner == 3 then
        love.graphics.setColor(0.9, 0.9, 0.9)  -- Light gray border for neutrals
    else
        love.graphics.setColor(1, 1, 1)  -- White border for others
    end
    love.graphics.circle("line", self.x, self.y, self.radius)
    
    
    -- Health bar
    if self.health < self.max_health then
        local health_percent = self.health / self.max_health
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", self.x - 10, self.y - 15, 
                              20 * health_percent, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", self.x - 10, self.y - 15, 20, 3)
    end
end

function Unit:update(dt)
    self.attack_cooldown = math.max(0, self.attack_cooldown - dt)
    self.exploration_timer = self.exploration_timer - dt
    self.room_wait_timer = self.room_wait_timer - dt
    self.personal_space_timer = self.personal_space_timer + dt
    self.flow_field_timer = self.flow_field_timer + dt
    
    -- Check if unit is stuck or has completed objectives
    local distance_moved = self:distance_to_point(self.last_position.x, self.last_position.y)
    if distance_moved < 5 then
        self.stuck_timer = self.stuck_timer + dt
    else
        self.stuck_timer = 0
        self.last_position.x = self.x
        self.last_position.y = self.y
    end
    
    -- If stuck for too long or achieved objective, force new exploration
    if self.stuck_timer > 2 then  -- Shorter timeout for quicker recovery
        self.stuck_timer = 0
        self.room_wait_timer = 0  -- Don't wait around
        -- Force the pathfinding system to recalculate by making flow field dirty
        if self.pathfinding_archetype then
            pathfinding_force_recalculation(self.pathfinding_archetype)
        end
    end
    
    self:update_room()
    
    -- Special behavior for neutral defenders
    if self.owner == 3 and self.is_defender then
        self:neutral_defender_behavior(dt)
        return
    end
    
    self:find_target()
    
    if not self.target then
        self:explore_for_enemies(dt)
    else
        -- If we have a target, commit to fighting it and stop exploring
        self.path_to_enemy = nil  -- Clear exploration path when in combat
        self:combat_movement(dt)
        self:attack_target(dt)
    end
end

function Unit:update_room()
    local rooms = get_rooms()
    for _, room in ipairs(rooms) do
        if self.x >= room.x and self.x <= room.x + room.width and
           self.y >= room.y and self.y <= room.y + room.height then
            
            if self.current_room ~= room then
                if self.current_room then
                    for i, unit in ipairs(self.current_room.units) do
                        if unit == self then
                            table.remove(self.current_room.units, i)
                            break
                        end
                    end
                end
                
                self.current_room = room
                table.insert(room.units, self)
            end
            break
        end
    end
end

function Unit:find_target()
    if not self.current_room then
        return
    end
    
    local closest_enemy = nil
    local closest_distance = math.huge
    
    -- Find all enemies in the room
    local enemies = {}
    for _, unit in ipairs(self.current_room.units) do
        if unit.owner ~= self.owner then
            local distance = self:distance_to(unit)
            table.insert(enemies, {unit = unit, distance = distance})
            
            if distance < closest_distance then
                closest_distance = distance
                closest_enemy = unit
            end
        end
    end
    
    -- For warriors specifically, switch targets more aggressively for multi-opponent juggling
    if self.type == "melee" then
        -- If current target is dead or invalid, clear it
        if self.target and (not self.target.health or self.target.health <= 0) then
            self.target = nil
        end
        
        if self.target then
            local current_distance = self:distance_to(self.target)
            local current_target_valid = true
            
            -- Check if current target is still in the room
            local current_target_in_room = false
            for _, unit in ipairs(self.current_room.units) do
                if unit == self.target then
                    current_target_in_room = true
                    break
                end
            end
            
            if not current_target_in_room then
                self.target = nil
                current_target_valid = false
            end
            
            -- Aggressive target switching for juggling multiple opponents
            if current_target_valid and closest_enemy then
                -- PRIORITIZE finishing off severely wounded enemies (don't let them escape!)
                if self.target.health <= self.target.max_health * 0.25 then
                    -- Current target is severely wounded - FINISH THEM! Don't switch unless something is much closer
                    if closest_distance < current_distance * 0.4 then  -- Only switch if MUCH closer
                        self.target = closest_enemy
                        self.strike_phase = "orbit"
                        self.orbit_time = 0
                        self.strike_timer = 0
                        self.orbit_angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
                    end
                    -- Stay focused on finishing wounded enemies
                elseif closest_distance < current_distance * 0.7 then
                    -- Switch if a significantly closer enemy appears (better juggling)
                    self.target = closest_enemy
                    -- Reset combat state for new target
                    self.strike_phase = "orbit"
                    self.orbit_time = 0
                    self.strike_timer = 0
                    self.orbit_angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
                -- Switch if current target is wounded but a fresh enemy is nearby
                elseif self.target.health < self.target.max_health * 0.4 and closest_distance < current_distance * 1.2 then
                    self.target = closest_enemy
                    self.strike_phase = "orbit"
                    self.orbit_time = 0  
                    self.strike_timer = 0
                    self.orbit_angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
                end
            end
        else
            self.target = closest_enemy
            -- Initialize combat state when acquiring new target
            if self.target and self.type == "melee" then
                self.strike_phase = "orbit"
                self.orbit_time = 0
                self.strike_timer = 0
                self.orbit_angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
            end
        end
    else
        -- Non-melee units use simple closest targeting
        self.target = closest_enemy
    end
end

function Unit:explore_for_enemies(dt)
    if not self.current_room then
        return
    end
    
    -- Stay in room if it's not controlled by our team and we can capture it
    if self.current_room.owner ~= self.owner then
        self:flow_field_movement(dt)
        return
    end
    
    if self.room_wait_timer > 0 then
        self:flow_field_movement(dt)
        return
    end
    
    -- Use flow field pathfinding for strategic movement
    self:flow_field_movement(dt)
end

function Unit:flow_field_movement(dt)
    -- Get movement direction from flow field pathfinding
    local flow_x, flow_y = pathfinding_get_movement_direction(self.x, self.y, self.pathfinding_archetype)
    
    -- Movement recovery system - if stuck too long, try random exploration
    if self.stuck_timer > 5 then
        -- Force exploration mode with random movement
        local angle = math.random() * 2 * math.pi
        flow_x = math.cos(angle)
        flow_y = math.sin(angle)
        self.stuck_timer = 0  -- Reset stuck timer
    elseif flow_x == 0 and flow_y == 0 then
        -- No clear direction from pathfinding, try to find enemies or strategic points
        local room = self.current_room
        if room then
            -- Look for enemies in current room first
            local has_enemies = false
            for _, unit in ipairs(room.units) do
                if unit.owner ~= self.owner then
                    has_enemies = true
                    break
                end
            end
            
            if not has_enemies then
                -- No enemies here, encourage exploration to adjacent rooms
                local connected_rooms = get_connected_rooms(room)
                if #connected_rooms > 0 then
                    local target_room = connected_rooms[math.random(#connected_rooms)]
                    local dx = (target_room.x + target_room.width/2) - self.x
                    local dy = (target_room.y + target_room.height/2) - self.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance > 0 then
                        flow_x = dx / distance
                        flow_y = dy / distance
                    end
                end
            end
        end
        
        -- Still no direction? Do idle movement
        if flow_x == 0 and flow_y == 0 then
            self:idle_movement(dt)
            return
        end
    end
    
    -- Apply movement with some smoothing
    local move_x = flow_x * self.speed * dt
    local move_y = flow_y * self.speed * dt
    
    -- Add some noise to prevent units from moving in perfect lockstep
    local noise_factor = 0.15
    local noise_x = (math.random() - 0.5) * noise_factor * self.speed * dt
    local noise_y = (math.random() - 0.5) * noise_factor * self.speed * dt
    
    move_x = move_x + noise_x
    move_y = move_y + noise_y
    
    -- Use simplified collision avoidance instead of the complex system
    self:move_with_simple_collision(move_x, move_y)
end

function Unit:move_with_simple_collision(move_x, move_y)
    local new_x = self.x + move_x
    local new_y = self.y + move_y
    
    -- Check collision with other units using simplified approach
    local too_close_units = 0
    local collision_force_x, collision_force_y = 0, 0
    
    if self.current_room then
        for _, other in ipairs(self.current_room.units) do
            if other ~= self then
                local dx = self.x - other.x
                local dy = self.y - other.y
                local distance = math.sqrt(dx * dx + dy * dy)
                local min_distance = (self.radius + other.radius) * 1.2
                
                if distance < min_distance and distance > 0 then
                    too_close_units = too_close_units + 1
                    local force = (min_distance - distance) / min_distance
                    collision_force_x = collision_force_x + (dx / distance) * force
                    collision_force_y = collision_force_y + (dy / distance) * force
                end
            end
        end
    end
    
    -- Apply collision avoidance force if needed
    if too_close_units > 0 then
        collision_force_x = collision_force_x / too_close_units
        collision_force_y = collision_force_y / too_close_units
        
        -- Blend avoidance with desired movement
        local avoidance_strength = 0.6
        move_x = move_x * (1 - avoidance_strength) + collision_force_x * self.speed * 0.1
        move_y = move_y * (1 - avoidance_strength) + collision_force_y * self.speed * 0.1
        
        new_x = self.x + move_x
        new_y = self.y + move_y
    end
    
    self.x = new_x
    self.y = new_y
end

function Unit:is_in_room(room)
    return self.x >= room.x and self.x <= room.x + room.width and
           self.y >= room.y and self.y <= room.y + room.height
end

function Unit:is_well_inside_room(room)
    local buffer = 20  -- Require unit to be 20 pixels inside the room boundaries
    return self.x >= room.x + buffer and self.x <= room.x + room.width - buffer and
           self.y >= room.y + buffer and self.y <= room.y + room.height - buffer
end

function Unit:find_accessible_room_point(room)
    -- Try the room center first
    local center_x = room.x + room.width / 2
    local center_y = room.y + room.height / 2
    
    if self:is_point_accessible(center_x, center_y, room) then
        return center_x, center_y
    end
    
    -- If center is blocked, try other points in the room
    local attempts = 0
    while attempts < 10 do
        local random_x = room.x + room.width * 0.25 + math.random() * room.width * 0.5
        local random_y = room.y + room.height * 0.25 + math.random() * room.height * 0.5
        
        if self:is_point_accessible(random_x, random_y, room) then
            return random_x, random_y
        end
        attempts = attempts + 1
    end
    
    -- Fallback to a safe point near the room entrance
    return room.x + room.width * 0.3, room.y + room.height * 0.3
end

function Unit:is_point_accessible(x, y, room)
    -- Check if point is too close to buildings
    for _, building in ipairs(room.buildings) do
        local dx = x - (building.x + building.width / 2)
        local dy = y - (building.y + building.height / 2)
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < (building.width + building.height) / 2 + 30 then
            return false
        end
    end
    
    -- Check if point is too close to other units
    for _, unit in ipairs(room.units) do
        if unit ~= self then
            local dx = x - unit.x
            local dy = y - unit.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance < 25 then
                return false
            end
        end
    end
    
    return true
end

function Unit:idle_movement(dt)
    if not self.current_room then
        return
    end
    
    -- Find a good spot to wander to in the current room
    local target_x, target_y = self:find_accessible_room_point(self.current_room)
    
    -- Add some randomness to make movement more natural
    target_x = target_x + math.random(-40, 40)
    target_y = target_y + math.random(-40, 40)
    
    -- Clamp to room boundaries
    target_x = math.max(self.current_room.x + 20, math.min(self.current_room.x + self.current_room.width - 20, target_x))
    target_y = math.max(self.current_room.y + 20, math.min(self.current_room.y + self.current_room.height - 20, target_y))
    
    local dx = target_x - self.x
    local dy = target_y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 10 then
        local move_x = (dx / distance) * self.speed * 0.4 * dt
        local move_y = (dy / distance) * self.speed * 0.4 * dt
        
        self:move_with_collision(move_x, move_y)
    end
end

function Unit:combat_movement(dt)
    if not self.target then
        return
    end
    
    local distance_to_target = self:distance_to(self.target)
    
    if self.type == "melee" then
        self:melee_combat_movement(dt, distance_to_target)
    elseif self.type == "ranged" then
        self:ranged_combat_movement(dt, distance_to_target)
    else
        self:spell_combat_movement(dt, distance_to_target)
    end
end

function Unit:melee_combat_movement(dt, distance_to_target)
    local optimal_orbit_distance = self.target.radius + self.radius + 12  -- Much closer for melee
    local strike_distance = self.target.radius + self.radius + 5
    
    -- Initialize strike phase if not set
    if not self.strike_phase then
        self.strike_phase = "orbit"
        self.orbit_time = 0
        self.strike_timer = 0
        self.orbit_angle = math.atan2(self.y - self.target.y, self.x - self.target.x)
    end
    
    self.orbit_time = self.orbit_time + dt
    self.strike_timer = self.strike_timer + dt
    
    if distance_to_target > optimal_orbit_distance + 8 then  -- Reduced threshold for approach
        -- Too far away, move closer aggressively
        self.strike_phase = "approach"
        local angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
        
        -- PURSUIT MODE: Move much faster when chasing wounded enemies
        local speed_multiplier = 1.2
        if self.target.health <= self.target.max_health * 0.25 then
            speed_multiplier = 1.8  -- Much faster pursuit of nearly dead enemies
        elseif self.target.health <= self.target.max_health * 0.5 then
            speed_multiplier = 1.5  -- Faster pursuit of wounded enemies
        end
        
        local move_x = math.cos(angle) * self.speed * speed_multiplier * dt
        local move_y = math.sin(angle) * self.speed * speed_multiplier * dt
        self:move_with_collision(move_x, move_y)
        return
    end
    
    -- Transition from approach to orbit when close enough
    if self.strike_phase == "approach" then
        self.strike_phase = "orbit"
        self.orbit_time = 0
        self.orbit_angle = math.atan2(self.y - self.target.y, self.x - self.target.x)
    end
    
    -- Handle the darting strike state machine
    if self.strike_phase == "orbit" then
        self:handle_orbit_phase(dt, optimal_orbit_distance)
    elseif self.strike_phase == "dart_in" then
        self:handle_dart_in_phase(dt, strike_distance)
    elseif self.strike_phase == "attacking" then
        self:handle_attacking_phase(dt)
    elseif self.strike_phase == "retreat" then
        self:handle_retreat_phase(dt, optimal_orbit_distance)
    end
end

function Unit:handle_orbit_phase(dt, optimal_orbit_distance)
    -- Orbit the target and look for strike opportunities
    self.orbit_angle = self.orbit_angle + (self.orbit_direction * dt * 2.2)  -- Faster orbit
    
    local orbit_radius = optimal_orbit_distance
    local target_x = self.target.x + math.cos(self.orbit_angle) * orbit_radius
    local target_y = self.target.y + math.sin(self.orbit_angle) * orbit_radius
    
    local dx = target_x - self.x
    local dy = target_y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 3 then  -- Tighter orbit control
        local move_x = (dx / distance) * self.speed * 0.8 * dt  -- Faster movement
        local move_y = (dy / distance) * self.speed * 0.8 * dt
        self:move_with_collision(move_x, move_y)
    end
    
    -- More frequent direction changes for unpredictable movement
    if math.random() < 0.05 then
        self.orbit_direction = -self.orbit_direction
    end
    
    -- Check for opportunity to switch targets during orbit (multi-opponent juggling)
    if self.orbit_time > 0.5 then  -- After brief orbit, consider switching
        self:find_target()  -- Re-evaluate targets mid-combat
    end
    
    -- Decide when to strike
    local should_strike = false
    
    -- More aggressive striking against wounded enemies
    local strike_urgency = 1.0
    if self.target.health <= self.target.max_health * 0.25 then
        strike_urgency = 3.0  -- Strike much more frequently against nearly dead enemies
    elseif self.target.health <= self.target.max_health * 0.5 then
        strike_urgency = 1.8  -- Strike more frequently against wounded enemies
    end
    
    -- Strike more frequently for aggressive melee combat
    local base_strike_time = math.random(0.8, 2.0) / strike_urgency
    if self.orbit_time > base_strike_time then
        should_strike = true
    end
    
    -- Strike if attack is off cooldown and we're in a good position
    local required_orbit_time = 0.4 / strike_urgency
    if self.attack_cooldown <= 0 and self.orbit_time > required_orbit_time then
        should_strike = true
    end
    
    -- Strike if target is close and vulnerable
    local distance_to_target = self:distance_to(self.target)
    if distance_to_target < optimal_orbit_distance * 0.95 and self.attack_cooldown <= 0 then
        should_strike = true
    end
    
    if should_strike then
        self:initiate_strike()
    end
end

function Unit:handle_dart_in_phase(dt, strike_distance)
    -- Fast movement toward target for the strike
    local angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
    local move_x = math.cos(angle) * self.speed * 2.8 * dt  -- Faster dart
    local move_y = math.sin(angle) * self.speed * 2.8 * dt
    
    self:move_with_collision(move_x, move_y)
    
    -- Check if we're close enough to attack
    local distance_to_target = self:distance_to(self.target)
    if distance_to_target <= strike_distance or self.strike_timer > 0.4 then
        self.strike_phase = "attacking"
        self.strike_timer = 0
        
        -- Perform the attack
        self.target:take_damage(self.damage)
        self.attack_cooldown = 1.0
        self.strikes_performed = self.strikes_performed + 1
    end
end

function Unit:handle_attacking_phase(dt)
    -- Brief pause during the "impact" of the attack
    if self.strike_timer > 0.1 then
        self.strike_phase = "retreat"
        self.strike_timer = 0
    end
end

function Unit:handle_retreat_phase(dt, optimal_orbit_distance)
    -- Slower retreat back to orbit distance
    local angle = math.atan2(self.y - self.target.y, self.x - self.target.x)
    local retreat_target_x = self.target.x + math.cos(angle) * optimal_orbit_distance
    local retreat_target_y = self.target.y + math.sin(angle) * optimal_orbit_distance
    
    local dx = retreat_target_x - self.x
    local dy = retreat_target_y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 8 then
        local move_x = (dx / distance) * self.speed * 0.7 * dt  -- Slower retreat
        local move_y = (dy / distance) * self.speed * 0.7 * dt
        self:move_with_collision(move_x, move_y)
    else
        -- Back to orbiting
        self.strike_phase = "orbit"
        self.orbit_time = 0
        self.strike_timer = 0
        
        -- Update orbit angle based on current position
        self.orbit_angle = math.atan2(self.y - self.target.y, self.x - self.target.x)
    end
end

function Unit:initiate_strike()
    self.strike_phase = "dart_in"
    self.strike_timer = 0
    self.orbit_time = 0
    
    -- Record starting position
    self.strike_start_pos.x = self.x
    self.strike_start_pos.y = self.y
    
    -- Calculate target position for the strike
    local angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
    local strike_distance = self.target.radius + self.radius + 3
    self.strike_target_pos.x = self.target.x - math.cos(angle) * strike_distance
    self.strike_target_pos.y = self.target.y - math.sin(angle) * strike_distance
end

function Unit:ranged_combat_movement(dt, distance_to_target)
    -- Archers are confident! Only retreat if VERY close
    local too_close_enemy = self:find_closest_enemy_within_range(15)  -- Reduced from 25
    
    if too_close_enemy then
        -- Quick tactical retreat, but not far
        local angle = math.atan2(self.y - too_close_enemy.y, self.x - too_close_enemy.x)
        local move_x = math.cos(angle) * self.speed * 0.8 * dt  -- Confident movement
        local move_y = math.sin(angle) * self.speed * 0.8 * dt
        self:move_with_simple_collision(move_x, move_y)
    elseif distance_to_target > self.range * 0.7 then  -- Move in closer - they're not afraid!
        -- Boldly advance to get in range
        local angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
        local move_x = math.cos(angle) * self.speed * dt
        local move_y = math.sin(angle) * self.speed * dt
        self:move_with_simple_collision(move_x, move_y)
    else
        -- Hold position and shoot - archers are steady
        -- Minimal movement, focused on combat
        self:maintain_line_of_sight(dt)
    end
end

function Unit:spell_combat_movement(dt, distance_to_target)
    local optimal_distance = self.range * 0.8
    
    if distance_to_target > optimal_distance + 10 then
        -- Move closer
        local angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
        local move_x = math.cos(angle) * self.speed * dt
        local move_y = math.sin(angle) * self.speed * dt
        self:move_with_collision(move_x, move_y)
    elseif distance_to_target < optimal_distance - 10 then
        -- Move away
        local angle = math.atan2(self.y - self.target.y, self.x - self.target.x)
        local move_x = math.cos(angle) * self.speed * dt
        local move_y = math.sin(angle) * self.speed * dt
        self:move_with_collision(move_x, move_y)
    end
end

function Unit:find_closest_enemy_within_range(range)
    if not self.current_room then
        return nil
    end
    
    local closest = nil
    local closest_distance = range
    
    for _, unit in ipairs(self.current_room.units) do
        if unit.owner ~= self.owner then
            local distance = self:distance_to(unit)
            if distance < closest_distance then
                closest_distance = distance
                closest = unit
            end
        end
    end
    
    return closest
end

function Unit:maintain_line_of_sight(dt)
    -- Simple line of sight maintenance - slight side-to-side movement
    if self.personal_space_timer > 2 then
        self.kiting_direction = math.random(-1, 1)
        self.personal_space_timer = 0
    end
    
    if self.kiting_direction ~= 0 then
        local perpendicular_angle = math.atan2(self.target.y - self.y, self.target.x - self.x) + math.pi/2
        local move_x = math.cos(perpendicular_angle) * self.kiting_direction * self.speed * 0.3 * dt
        local move_y = math.sin(perpendicular_angle) * self.kiting_direction * self.speed * 0.3 * dt
        self:move_with_collision(move_x, move_y)
    end
end

function Unit:attack_target(dt)
    if not self.target then
        return
    end
    
    local distance = self:distance_to(self.target)
    
    -- Melee units use the darting strike system for attacks, don't interfere
    if self.type == "melee" then
        return  -- Let the darting strike system handle all melee attacks
    end
    
    -- Handle ranged and spell attacks only
    if self.attack_cooldown > 0 then
        return
    end
    
    if distance <= self.range then
        if self.type == "ranged" and self.ammo > 0 then
            self.ammo = self.ammo - 1
            -- Create arrow projectile
            local projectile = Projectile:new(self.x, self.y, self.target.x, self.target.y, 
                                            self.damage, self.owner, "arrow")
            table.insert(projectiles, projectile)
            self.attack_cooldown = 1.5
        elseif self.type == "spell" then
            -- Create spell projectile
            local projectile = Projectile:new(self.x, self.y, self.target.x, self.target.y, 
                                            self.damage, self.owner, "spell")
            table.insert(projectiles, projectile)
            self.attack_cooldown = 2.0
        end
    end
end

function Unit:take_damage(amount)
    self.health = self.health - amount
    if self.health <= 0 then
        self:die()
    end
end

function Unit:die()
    if self.current_room then
        for i, unit in ipairs(self.current_room.units) do
            if unit == self then
                table.remove(self.current_room.units, i)
                break
            end
        end
    end
    
    for i, unit in ipairs(units) do
        if unit == self then
            table.remove(units, i)
            break
        end
    end
end

function Unit:move_with_collision(move_x, move_y)
    local new_x = self.x + move_x
    local new_y = self.y + move_y
    
    -- Enforce room boundaries - units shouldn't leave their room during combat
    if self.current_room then
        local room = self.current_room
        local boundary_buffer = self.radius + 5  -- Small buffer to prevent getting stuck
        
        new_x = math.max(room.x + boundary_buffer, math.min(room.x + room.width - boundary_buffer, new_x))
        new_y = math.max(room.y + boundary_buffer, math.min(room.y + room.height - boundary_buffer, new_y))
    end
    
    -- Check collision with other units - use smaller collision radius for better flow
    local collision = false
    local collision_unit = nil
    if self.current_room then
        for _, other in ipairs(self.current_room.units) do
            if other ~= self then
                local dx = new_x - other.x
                local dy = new_y - other.y
                local distance = math.sqrt(dx * dx + dy * dy)
                local min_distance = (self.radius + other.radius) * 0.8  -- Reduced collision
                
                if distance < min_distance then
                    collision = true
                    collision_unit = other
                    break
                end
            end
        end
    end
    
    if not collision then
        self.x = new_x
        self.y = new_y
    else
        -- More sophisticated collision avoidance
        self:avoid_unit_collision(move_x, move_y, collision_unit)
    end
end

function Unit:avoid_unit_collision(move_x, move_y, collision_unit)
    -- Try to flow around the unit more naturally
    local angle_to_collision = math.atan2(collision_unit.y - self.y, collision_unit.x - self.x)
    local desired_angle = math.atan2(move_y, move_x)
    
    -- Choose the shorter path around the obstacle
    local angle_diff = desired_angle - angle_to_collision
    while angle_diff > math.pi do angle_diff = angle_diff - 2 * math.pi end
    while angle_diff < -math.pi do angle_diff = angle_diff + 2 * math.pi end
    
    local avoid_angle
    if angle_diff > 0 then
        avoid_angle = angle_to_collision + math.pi/2  -- Go around left
    else
        avoid_angle = angle_to_collision - math.pi/2  -- Go around right
    end
    
    -- Blend the avoidance with the original movement
    local move_distance = math.sqrt(move_x * move_x + move_y * move_y)
    local avoid_x = math.cos(avoid_angle) * move_distance * 0.7
    local avoid_y = math.sin(avoid_angle) * move_distance * 0.7
    
    -- Try the avoidance movement
    local test_x = self.x + avoid_x
    local test_y = self.y + avoid_y
    
    local can_avoid = true
    if self.current_room then
        for _, other in ipairs(self.current_room.units) do
            if other ~= self then
                local dx = test_x - other.x
                local dy = test_y - other.y
                local distance = math.sqrt(dx * dx + dy * dy)
                local min_distance = (self.radius + other.radius) * 0.8
                
                if distance < min_distance then
                    can_avoid = false
                    break
                end
            end
        end
    end
    
    if can_avoid then
        self.x = test_x
        self.y = test_y
    end
    -- If we can't avoid, just don't move this frame
end

function Unit:distance_to(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    return math.sqrt(dx * dx + dy * dy)
end

function Unit:distance_to_point(x, y)
    local dx = self.x - x
    local dy = self.y - y
    return math.sqrt(dx * dx + dy * dy)
end

function unit_init()
    units = {}
    projectiles = {}
end

function unit_update(dt)
    for i = #units, 1, -1 do
        if units[i].health > 0 then
            units[i]:update(dt)
        end
    end
    
    -- Update projectiles
    for i = #projectiles, 1, -1 do
        local keep_alive = projectiles[i]:update(dt)
        if not keep_alive then
            table.remove(projectiles, i)
        end
    end
end

function unit_draw()
    for _, unit in ipairs(units) do
        unit:draw()
    end
    
    -- Draw projectiles
    for _, projectile in ipairs(projectiles) do
        projectile:draw()
    end
end

function spawn_unit_at_building(building, unit_type)
    local spawn_x = building.x + building.width / 2
    local spawn_y = building.y + building.height / 2
    
    local unit = Unit:new(spawn_x, spawn_y, unit_type, building.owner)
    table.insert(units, unit)
    
    if building.room and #building.room.units < building.room.max_capacity then
        table.insert(building.room.units, unit)
        unit.current_room = building.room
    end
end

function spawn_neutral_unit(spawn_x, spawn_y, unit_type, room)
    local unit = Unit:new(spawn_x, spawn_y, unit_type, 3)  -- Owner = 3 for neutral/independent
    table.insert(units, unit)
    
    print("Created neutral " .. unit_type .. " at (" .. spawn_x .. "," .. spawn_y .. ") owner=" .. unit.owner)
    
    if room and #room.units < room.max_capacity then
        table.insert(room.units, unit)
        unit.current_room = room
        unit.home_room = room
        unit.is_defender = true
        unit.is_independent = true  -- All neutrals are independent defenders
        unit.pathfinding_archetype = "independent_defender"
        print("  -> Added to room " .. room.id .. " (total room units: " .. #room.units .. ")")
    else
        print("  -> WARNING: Could not add to room (room full or invalid)")
    end
end

function spawn_independent_unit(spawn_x, spawn_y, unit_type, room)
    local unit = Unit:new(spawn_x, spawn_y, unit_type, 4)  -- Owner = 4 for independent neutrals
    table.insert(units, unit)
    
    print("Created independent " .. unit_type .. " at (" .. spawn_x .. "," .. spawn_y .. ") owner=" .. unit.owner)
    
    if room and #room.units < room.max_capacity then
        table.insert(room.units, unit)
        unit.current_room = room
        unit.home_room = room
        unit.is_defender = true
        unit.is_independent = true  -- Mark as truly independent
        unit.pathfinding_archetype = "independent_defender"  -- Use special archetype for territorial defense
        print("  -> Added to room " .. room.id .. " (total room units: " .. #room.units .. ")")
    else
        print("  -> WARNING: Could not add to room (room full or invalid)")
    end
end

function Unit:neutral_defender_behavior(dt)
    self.disperse_timer = self.disperse_timer + dt
    
    -- Look for enemies in current room
    local enemies_in_room = {}
    if self.current_room then
        for _, unit in ipairs(self.current_room.units) do
            -- Neutral units are hostile to players (1) and enemies (2), but not other neutrals (3)
            local is_enemy = (unit.owner == 1 or unit.owner == 2)
            
            if is_enemy then
                table.insert(enemies_in_room, unit)
            end
        end
    end
    
    if #enemies_in_room > 0 then
        -- Fight enemies in our room - find closest
        local closest_enemy = enemies_in_room[1]
        local closest_distance = self:distance_to(closest_enemy)
        
        for _, enemy in ipairs(enemies_in_room) do
            local distance = self:distance_to(enemy)
            if distance < closest_distance then
                closest_distance = distance
                closest_enemy = enemy
            end
        end
        
        self.target = closest_enemy
        self:combat_movement(dt)
        self:attack_target(dt)
        self.disperse_timer = 0  -- Reset disperse timer when fighting
    else
        -- No enemies, patrol home territory
        self:patrol_home_territory(dt)
        self.target = nil  -- Clear target when no enemies
    end
end

function Unit:patrol_home_territory(dt)
    -- Simple patrol behavior within the home room
    if not self.patrol_target_x then
        local room = self.home_room or self.current_room
        if room then
            self.patrol_target_x = room.x + math.random(room.width * 0.2, room.width * 0.8)
            self.patrol_target_y = room.y + math.random(room.height * 0.2, room.height * 0.8)
        end
    end
    
    if self.patrol_target_x and self.patrol_target_y then
        local dx = self.patrol_target_x - self.x
        local dy = self.patrol_target_y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance < 20 then
            -- Reached patrol point, pick a new one
            self.patrol_target_x = nil
            self.patrol_target_y = nil
        else
            -- Move toward patrol point
            local move_x = (dx / distance) * self.speed * 0.5 * dt
            local move_y = (dy / distance) * self.speed * 0.5 * dt
            self:move_with_collision(move_x, move_y)
        end
    end
end

function Unit:disperse_to_neutral_territory(dt)
    -- Find nearest neutral room and move toward it
    local neutral_rooms = {}
    local rooms = get_rooms()
    for _, room in ipairs(rooms) do
        if room.owner == 3 then
            table.insert(neutral_rooms, room)
        end
    end
    
    if #neutral_rooms > 0 then
        local closest_room = neutral_rooms[1]
        local closest_distance = math.huge
        
        for _, room in ipairs(neutral_rooms) do
            local dx = (room.x + room.width/2) - self.x
            local dy = (room.y + room.height/2) - self.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance < closest_distance then
                closest_distance = distance
                closest_room = room
            end
        end
        
        -- Move toward closest neutral room
        local target_x = closest_room.x + closest_room.width/2
        local target_y = closest_room.y + closest_room.height/2
        local dx = target_x - self.x
        local dy = target_y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 10 then
            local move_x = (dx / distance) * self.speed * dt
            local move_y = (dy / distance) * self.speed * dt
            self:move_with_collision(move_x, move_y)
        end
    else
        -- No neutral territory left, just idle
        self:idle_movement(dt)
    end
end

function Unit:idle_movement(dt)
    -- Random gentle movement
    if math.random() < 0.02 then
        local angle = math.random() * 2 * math.pi
        local move_x = math.cos(angle) * self.speed * 0.3 * dt
        local move_y = math.sin(angle) * self.speed * 0.3 * dt
        self:move_with_collision(move_x, move_y)
    end
end

-- Expose units array for pathfinding system
function get_all_units()
    return units
end

function debug_count_units()
    local counts = {[1] = 0, [2] = 0, [3] = 0}
    for _, unit in ipairs(units) do
        counts[unit.owner] = (counts[unit.owner] or 0) + 1
    end
    print("Unit counts - Player: " .. counts[1] .. ", Enemy: " .. counts[2] .. ", Neutral: " .. counts[3] .. ", Total: " .. #units)
end