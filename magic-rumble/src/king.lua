local player_king = nil
local enemy_king = nil

local King = {}
King.__index = King

function King:new(x, y, owner)
    local king = {
        x = x,
        y = y,
        target_x = x,
        target_y = y,
        owner = owner,
        radius = 12,
        speed = 35,
        current_room = nil,
        move_timer = 0,
        move_path = nil,
        move_path_index = 1,
        is_moving_to_room = false
    }
    setmetatable(king, King)
    return king
end

function King:draw()
    local color = {1, 1, 0}
    if self.owner == 2 then
        color = {0.8, 0.8, 0}
    end
    
    love.graphics.setColor(color)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.circle("line", self.x, self.y, self.radius)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("♔", self.x - 6, self.y - 8)
end

function King:update(dt)
    self.move_timer = self.move_timer + dt
    self:update_room()
    
    if self.is_moving_to_room then
        self:move_along_path(dt)
    else
        self:avoid_enemies(dt)
    end
    
    self:check_enemy_collision()
end

function King:update_room()
    local rooms = get_rooms()
    for _, room in ipairs(rooms) do
        if self.x >= room.x and self.x <= room.x + room.width and
           self.y >= room.y and self.y <= room.y + room.height then
            
            if self.current_room ~= room then
                self.current_room = room
            end
            break
        end
    end
end

function King:avoid_enemies(dt)
    if not self.current_room then
        return
    end
    
    local closest_enemy = nil
    local closest_distance = math.huge
    
    for _, unit in ipairs(self.current_room.units) do
        if unit.owner ~= self.owner then
            local distance = self:distance_to_point(unit.x, unit.y)
            if distance < closest_distance then
                closest_distance = distance
                closest_enemy = unit
            end
        end
    end
    
    if closest_enemy and closest_distance < 100 then
        local avoid_x = self.x - (closest_enemy.x - self.x) * 0.5
        local avoid_y = self.y - (closest_enemy.y - self.y) * 0.5
        
        avoid_x = math.max(self.current_room.x + self.radius, 
                          math.min(self.current_room.x + self.current_room.width - self.radius, avoid_x))
        avoid_y = math.max(self.current_room.y + self.radius, 
                          math.min(self.current_room.y + self.current_room.height - self.radius, avoid_y))
        
        local dx = avoid_x - self.x
        local dy = avoid_y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 5 then
            self.x = self.x + (dx / distance) * self.speed * dt
            self.y = self.y + (dy / distance) * self.speed * dt
        end
    else
        if self.move_timer > 3 then
            self.move_timer = 0
            if self.current_room then
                self.target_x = self.current_room.x + math.random(self.radius, self.current_room.width - self.radius)
                self.target_y = self.current_room.y + math.random(self.radius, self.current_room.height - self.radius)
            end
        end
        
        local dx = self.target_x - self.x
        local dy = self.target_y - self.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 5 then
            self.x = self.x + (dx / distance) * self.speed * 0.3 * dt
            self.y = self.y + (dy / distance) * self.speed * 0.3 * dt
        end
    end
end

function King:check_enemy_collision()
    if not self.current_room then
        return
    end
    
    for _, unit in ipairs(self.current_room.units) do
        if unit.owner ~= self.owner then
            local distance = self:distance_to_point(unit.x, unit.y)
            if distance < self.radius + unit.radius then
                if self.owner == 1 then
                    player_lose_heart()
                else
                    enemy_lose_heart()
                end
                return
            end
        end
    end
end

function King:distance_to_point(x, y)
    local dx = self.x - x
    local dy = self.y - y
    return math.sqrt(dx * dx + dy * dy)
end

function King:move_to_room(target_room)
    if not self.current_room then
        return false
    end
    
    local path = find_king_path_to_room(self.current_room, target_room)
    if path then
        self.move_path = path
        self.move_path_index = 1
        self.is_moving_to_room = true
        return true
    end
    return false
end

function King:move_along_path(dt)
    if not self.move_path or self.move_path_index > #self.move_path then
        self.is_moving_to_room = false
        self.move_path = nil
        return
    end
    
    local target_room = self.move_path[self.move_path_index]
    local room_center_x = target_room.x + target_room.width / 2
    local room_center_y = target_room.y + target_room.height / 2
    
    local dx = room_center_x - self.x
    local dy = room_center_y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance < 20 then
        self.move_path_index = self.move_path_index + 1
        if self.move_path_index > #self.move_path then
            self.is_moving_to_room = false
            self.move_path = nil
        end
    else
        local move_x = (dx / distance) * self.speed * dt
        local move_y = (dy / distance) * self.speed * dt
        
        self.x = self.x + move_x
        self.y = self.y + move_y
    end
end

function king_init()
    local rooms = get_rooms()
    
    for _, room in ipairs(rooms) do
        if room.owner == 1 then
            player_king = King:new(room.x + room.width / 2, room.y + room.height / 2, 1)
            player_king.current_room = room
            break
        end
    end
    
    for i = #rooms, 1, -1 do
        local room = rooms[i]
        if room.owner == 2 then
            enemy_king = King:new(room.x + room.width / 2, room.y + room.height / 2, 2)
            enemy_king.current_room = room
            break
        end
    end
end

function king_update(dt)
    if player_king then
        player_king:update(dt)
    end
    if enemy_king then
        enemy_king:update(dt)
    end
end

function king_draw()
    if player_king then
        player_king:draw()
    end
    if enemy_king then
        enemy_king:draw()
    end
end

function king_try_move_to_room(world_x, world_y)
    if not player_king then
        return false
    end
    
    local target_room = get_room_at_position(world_x, world_y)
    if target_room then
        return player_king:move_to_room(target_room)
    end
    return false
end

function find_king_path_to_room(start_room, target_room)
    if start_room == target_room then
        return {target_room}
    end
    
    -- Check if target room is safe for king (controlled by player, no enemies)
    if not is_room_safe_for_king(target_room) then
        return nil
    end
    
    local visited = {}
    local queue = {{room = start_room, path = {start_room}}}
    
    while #queue > 0 do
        local current = table.remove(queue, 1)
        local room = current.room
        
        if visited[room.id] then
            goto continue
        end
        visited[room.id] = true
        
        if room == target_room then
            return current.path
        end
        
        local connected = get_connected_rooms(room)
        for _, next_room in ipairs(connected) do
            if not visited[next_room.id] and is_room_safe_for_king(next_room) then
                local new_path = {}
                for _, r in ipairs(current.path) do
                    table.insert(new_path, r)
                end
                table.insert(new_path, next_room)
                table.insert(queue, {room = next_room, path = new_path})
            end
        end
        
        ::continue::
    end
    
    return nil
end

function is_room_safe_for_king(room)
    -- Room must be controlled by player
    if room.owner ~= 1 then
        return false
    end
    
    -- Room must not have enemy units
    for _, unit in ipairs(room.units) do
        if unit.owner == 2 then
            return false
        end
    end
    
    return true
end