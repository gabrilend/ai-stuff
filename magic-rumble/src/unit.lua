local units = {}

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
        speed = 25,
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
        path_to_enemy = nil,
        path_index = 1,
        exploration_timer = math.random(3, 8),
        room_wait_timer = 0,
        orbit_angle = math.random() * 2 * math.pi,
        orbit_direction = (math.random() < 0.5) and 1 or -1,
        personal_space_timer = 0,
        kiting_direction = 0
    }
    setmetatable(unit, Unit)
    return unit
end

function Unit:draw()
    local draw_color = self.color
    if self.owner == 2 then
        draw_color = {self.color[1] * 0.5, self.color[2] * 0.5, self.color[3] * 0.5}
    end
    
    love.graphics.setColor(draw_color)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("line", self.x, self.y, self.radius)
    
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
    
    self:update_room()
    self:find_target()
    
    if not self.target then
        self:explore_for_enemies(dt)
    else
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
    
    for _, unit in ipairs(self.current_room.units) do
        if unit.owner ~= self.owner then
            local distance = self:distance_to(unit)
            if distance < closest_distance then
                closest_distance = distance
                closest_enemy = unit
            end
        end
    end
    
    self.target = closest_enemy
end

function Unit:explore_for_enemies(dt)
    if not self.current_room then
        return
    end
    
    -- Stay in room if it's not controlled by our team and we can capture it
    if self.current_room.owner ~= self.owner then
        self:idle_movement(dt)
        return
    end
    
    if self.room_wait_timer > 0 then
        self:idle_movement(dt)
        return
    end
    
    if not self.path_to_enemy or self.exploration_timer <= 0 then
        self.path_to_enemy = find_path_to_enemy_room(self.current_room, self.owner)
        self.path_index = 1
        self.exploration_timer = math.random(5, 10)
        
        if not self.path_to_enemy then
            self.room_wait_timer = 3
            return
        end
    end
    
    if self.path_to_enemy and self.path_index <= #self.path_to_enemy then
        local target_room = self.path_to_enemy[self.path_index]
        local room_center_x = target_room.x + target_room.width / 2
        local room_center_y = target_room.y + target_room.height / 2
        
        local dx = room_center_x - self.x
        local dy = room_center_y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance < 30 then
            self.path_index = self.path_index + 1
        else
            local move_x = (dx / distance) * self.speed * dt
            local move_y = (dy / distance) * self.speed * dt
            
            self:move_with_collision(move_x, move_y)
        end
    else
        self:idle_movement(dt)
    end
end

function Unit:idle_movement(dt)
    if not self.current_room then
        return
    end
    
    local center_x = self.current_room.x + self.current_room.width / 2
    local center_y = self.current_room.y + self.current_room.height / 2
    
    local dx = center_x - self.x + math.random(-30, 30)
    local dy = center_y - self.y + math.random(-30, 30)
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 5 then
        local move_x = (dx / distance) * self.speed * 0.3 * dt
        local move_y = (dy / distance) * self.speed * 0.3 * dt
        
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
    local optimal_distance = self.target.radius + self.radius + 10
    
    if distance_to_target > optimal_distance + 5 then
        -- Move closer to target
        local angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
        local move_x = math.cos(angle) * self.speed * dt
        local move_y = math.sin(angle) * self.speed * dt
        self:move_with_collision(move_x, move_y)
    else
        -- Orbit the target
        self.orbit_angle = self.orbit_angle + (self.orbit_direction * dt * 2)
        
        local orbit_radius = optimal_distance
        local target_x = self.target.x + math.cos(self.orbit_angle) * orbit_radius
        local target_y = self.target.y + math.sin(self.orbit_angle) * orbit_radius
        
        local dx = target_x - self.x
        local dy = target_y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 3 then
            local move_x = (dx / distance) * self.speed * 0.7 * dt
            local move_y = (dy / distance) * self.speed * 0.7 * dt
            self:move_with_collision(move_x, move_y)
        end
        
        -- Occasionally change orbit direction
        if math.random() < 0.02 then
            self.orbit_direction = -self.orbit_direction
        end
    end
end

function Unit:ranged_combat_movement(dt, distance_to_target)
    -- Check for nearby enemies to kite away from
    local too_close_enemy = self:find_closest_enemy_within_range(25)
    
    if too_close_enemy then
        -- Kite away from close enemies
        local angle = math.atan2(self.y - too_close_enemy.y, self.x - too_close_enemy.x)
        local move_x = math.cos(angle) * self.speed * dt
        local move_y = math.sin(angle) * self.speed * dt
        self:move_with_collision(move_x, move_y)
    elseif distance_to_target > self.range * 0.9 then
        -- Move closer to get in range
        local angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
        local move_x = math.cos(angle) * self.speed * dt
        local move_y = math.sin(angle) * self.speed * dt
        self:move_with_collision(move_x, move_y)
    else
        -- Maintain position and try to maintain line of sight
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
    if not self.target or self.attack_cooldown > 0 then
        return
    end
    
    local distance = self:distance_to(self.target)
    
    if distance <= self.range then
        if self.type == "ranged" and self.ammo > 0 then
            self.ammo = self.ammo - 1
            self.target:take_damage(self.damage)
            self.attack_cooldown = 1.5
        elseif self.type == "melee" and distance <= self.radius + self.target.radius + 12 then
            self.target:take_damage(self.damage)
            self.attack_cooldown = 1.0
        elseif self.type == "spell" then
            self.target:take_damage(self.damage)
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

function unit_init()
    units = {}
end

function unit_update(dt)
    for i = #units, 1, -1 do
        if units[i].health > 0 then
            units[i]:update(dt)
        end
    end
end

function unit_draw()
    for _, unit in ipairs(units) do
        unit:draw()
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