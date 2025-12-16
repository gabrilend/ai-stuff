local rooms = {}
local connections = {}
local GRID_SIZE = 20
local MAP_WIDTH = 2000
local MAP_HEIGHT = 1400
local MIN_ROOM_SIZE = 120
local MAX_ROOM_SIZE = 200

local Room = {}
Room.__index = Room

function Room:new(x, y, width, height, id)
    local room = {
        x = x,
        y = y,
        id = id,
        width = width,
        height = height,
        owner = 0,
        capture_progress = 0,
        capture_time = 10,
        units = {},
        buildings = {},
        max_capacity = 50,
        building_grid = {},
        grid_width = math.floor(width / GRID_SIZE),
        grid_height = math.floor(height / GRID_SIZE)
    }
    setmetatable(room, Room)
    room:init_building_grid()
    return room
end

function Room:draw()
    local color
    if self.owner == 1 then
        color = {0.2, 0.6, 0.2}  -- Green for player
    elseif self.owner == 2 then
        color = {0.6, 0.2, 0.2}  -- Red for enemy
    elseif self.owner == 3 then
        color = {0.4, 0.4, 0.4}  -- Gray for independent neutrals
    else
        color = {0.4, 0.4, 0.4}  -- Gray for unowned
    end
    
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    if self.capture_progress > 0 and self.capture_progress < self.capture_time then
        local progress = self.capture_progress / self.capture_time
        love.graphics.setColor(1, 1, 0)
        love.graphics.rectangle("fill", self.x, self.y - 10, 
                              self.width * progress, 5)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", self.x, self.y - 10, 
                              self.width, 5)
    end
    
    self:draw_building_grid()
end

function Room:update(dt)
    local player_units = 0
    local enemy_units = 0
    local neutral_units = 0
    
    for _, unit in ipairs(self.units) do
        if unit.owner == 1 then
            player_units = player_units + 1
        elseif unit.owner == 2 then
            enemy_units = enemy_units + 1
        elseif unit.owner == 3 then
            neutral_units = neutral_units + 1
        end
    end
    
    local old_owner = self.owner
    
    -- Room can only be captured if there are NO hostile units remaining
    if player_units > 0 and enemy_units == 0 and neutral_units == 0 and self.owner ~= 1 then
        self.capture_progress = self.capture_progress + dt
        if self.capture_progress >= self.capture_time then
            self.owner = 1
            self.capture_progress = 0
            self:reset_building_mana()
        end
    elseif enemy_units > 0 and player_units == 0 and neutral_units == 0 and self.owner ~= 2 then
        self.capture_progress = self.capture_progress + dt
        if self.capture_progress >= self.capture_time then
            self.owner = 2
            self.capture_progress = 0
            self:reset_building_mana()
        end
    elseif (player_units > 0 and (enemy_units > 0 or neutral_units > 0)) or (enemy_units > 0 and (player_units > 0 or neutral_units > 0)) then
        -- Combat ongoing - pause capture progress, don't reset
    elseif player_units == 0 and enemy_units == 0 and neutral_units == 0 then
        -- No units - reset progress only if someone was capturing
        if self.capture_progress > 0 then
            self.capture_progress = 0
        end
    end
end

function Room:can_place_building()
    return self.owner == 1 and #self.buildings == 0
end

function Room:add_building(building)
    table.insert(self.buildings, building)
end

function Room:reset_building_mana()
    for _, building in ipairs(self.buildings) do
        building.mana = 0
        -- Transfer building ownership to match room owner when room is captured
        building.owner = self.owner
    end
end

function Room:init_building_grid()
    self.building_grid = {}
    for x = 1, self.grid_width do
        self.building_grid[x] = {}
        for y = 1, self.grid_height do
            self.building_grid[x][y] = false  -- false = empty, true = occupied
        end
    end
end

function Room:can_place_building_at_grid(grid_x, grid_y, width, height)
    if self.owner ~= 1 then
        return false
    end
    
    if grid_x < 1 or grid_y < 1 or 
       grid_x + width - 1 > self.grid_width or 
       grid_y + height - 1 > self.grid_height then
        return false
    end
    
    for x = grid_x, grid_x + width - 1 do
        for y = grid_y, grid_y + height - 1 do
            if self.building_grid[x][y] then
                return false
            end
        end
    end
    
    return true
end

function Room:occupy_grid_space(grid_x, grid_y, width, height)
    for x = grid_x, grid_x + width - 1 do
        for y = grid_y, grid_y + height - 1 do
            self.building_grid[x][y] = true
        end
    end
end

function Room:world_to_grid(world_x, world_y)
    local grid_x = math.floor((world_x - self.x) / GRID_SIZE) + 1
    local grid_y = math.floor((world_y - self.y) / GRID_SIZE) + 1
    return grid_x, grid_y
end

function Room:grid_to_world(grid_x, grid_y)
    local world_x = self.x + (grid_x - 1) * GRID_SIZE
    local world_y = self.y + (grid_y - 1) * GRID_SIZE
    return world_x, world_y
end

function Room:draw_building_grid()
    if get_selected_building_type() then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
        for x = 1, self.grid_width do
            for y = 1, self.grid_height do
                local world_x, world_y = self:grid_to_world(x, y)
                love.graphics.rectangle("line", world_x, world_y, GRID_SIZE, GRID_SIZE)
            end
        end
    end
end

function map_init()
    -- Seed random number generator with current time
    math.randomseed(os.time())
    
    rooms = {}
    connections = {}
    
    -- Generate organic maze layout
    generate_maze_rooms()
    generate_maze_connections()
    ensure_all_rooms_connected()
    -- Note: spawn_neutral_defenders() moved to after unit_init() in game_init()
end

function generate_maze_rooms()
    local room_id = 1
    local room_positions = {}
    
    -- Create rooms in a more organic pattern
    for layer = 0, 6 do
        local num_rooms_in_layer = math.random(3, 6)
        local angle_step = (2 * math.pi) / num_rooms_in_layer
        local base_radius = 200 + layer * 150
        
        for i = 1, num_rooms_in_layer do
            local angle = i * angle_step + math.random(-0.5, 0.5)
            local radius = base_radius + math.random(-50, 50)
            
            local center_x = MAP_WIDTH / 2 + math.cos(angle) * radius
            local center_y = MAP_HEIGHT / 2 + math.sin(angle) * radius
            
            -- Make rooms larger and randomly shaped
            local base_size = MIN_ROOM_SIZE + math.random(0, MAX_ROOM_SIZE - MIN_ROOM_SIZE)
            local width = base_size + math.random(-20, 20)
            local height = base_size + math.random(-20, 20)
            
            local room_x = center_x - width / 2
            local room_y = center_y - height / 2
            
            -- Ensure room stays within map bounds
            room_x = math.max(50, math.min(MAP_WIDTH - width - 50, room_x))
            room_y = math.max(50, math.min(MAP_HEIGHT - height - 50, room_y))
            
            -- Recalculate center after bounds correction
            center_x = room_x + width / 2
            center_y = room_y + height / 2
            
            -- Ensure rooms don't overlap too much
            local valid_position = true
            for _, pos in ipairs(room_positions) do
                local dx = center_x - pos.x
                local dy = center_y - pos.y
                local distance = math.sqrt(dx * dx + dy * dy)
                if distance < (base_size + pos.size) / 2 + 50 then
                    valid_position = false
                    break
                end
            end
            
            if valid_position then
                local room = Room:new(room_x, room_y, width, height, room_id)
                
                -- Set ownership based on position
                if layer == 0 then
                    room.owner = 1  -- Player starts in center
                elseif layer >= 5 then
                    room.owner = 2  -- Enemy owns outer rooms
                elseif layer >= 1 and layer <= 4 and math.random() < 0.6 then
                    room.owner = 3  -- Neutral territory with defenders (higher chance)
                end
                -- Default owner = 0 (unowned) for remaining rooms
                
                table.insert(rooms, room)
                table.insert(room_positions, {x = center_x, y = center_y, size = base_size})
                room_id = room_id + 1
            end
        end
    end
end

function generate_maze_connections()
    -- Connect rooms with hallways
    for i, room1 in ipairs(rooms) do
        local connected = false
        local min_connections = 0
        
        for j, room2 in ipairs(rooms) do
            if i ~= j then
                local dx = (room1.x + room1.width/2) - (room2.x + room2.width/2)
                local dy = (room1.y + room1.height/2) - (room2.y + room2.height/2)
                local distance = math.sqrt(dx * dx + dy * dy)
                
                -- Connect nearby rooms
                if distance < 300 and (not connected or math.random() < 0.4) then
                    local connection = create_hallway(room1, room2)
                    if connection then
                        table.insert(connections, connection)
                        connected = true
                        min_connections = min_connections + 1
                    end
                end
                
                if min_connections >= 3 then break end
            end
        end
        
        -- Ensure every room has at least one connection
        if not connected then
            local closest_room = nil
            local closest_distance = math.huge
            
            for j, room2 in ipairs(rooms) do
                if i ~= j then
                    local dx = (room1.x + room1.width/2) - (room2.x + room2.width/2)
                    local dy = (room1.y + room1.height/2) - (room2.y + room2.height/2)
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance < closest_distance then
                        closest_distance = distance
                        closest_room = room2
                    end
                end
            end
            
            if closest_room then
                local connection = create_hallway(room1, closest_room)
                if connection then
                    table.insert(connections, connection)
                end
            end
        end
    end
end

function create_hallway(room1, room2)
    -- Create wider hallways for better unit movement
    local x1 = room1.x + room1.width / 2
    local y1 = room1.y + room1.height / 2
    local x2 = room2.x + room2.width / 2
    local y2 = room2.y + room2.height / 2
    
    return {
        from = room1,
        to = room2,
        x1 = x1,
        y1 = y1,
        x2 = x2,
        y2 = y2,
        width = 40  -- Wide enough for two units side by side
    }
end

function ensure_all_rooms_connected()
    -- Use union-find to check connectivity and fix it
    local visited = {}
    local connected_groups = {}
    
    -- Find all connected components
    for _, room in ipairs(rooms) do
        if not visited[room.id] then
            local group = {}
            explore_connected_rooms(room, visited, group)
            table.insert(connected_groups, group)
        end
    end
    
    -- If we have multiple groups, connect them
    while #connected_groups > 1 do
        local group1 = connected_groups[1]
        local group2 = connected_groups[2]
        
        -- Find closest rooms between the two groups
        local closest_room1, closest_room2 = nil, nil
        local min_distance = math.huge
        
        for _, room1 in ipairs(group1) do
            for _, room2 in ipairs(group2) do
                local dx = (room1.x + room1.width/2) - (room2.x + room2.width/2)
                local dy = (room1.y + room1.height/2) - (room2.y + room2.height/2)
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance < min_distance then
                    min_distance = distance
                    closest_room1 = room1
                    closest_room2 = room2
                end
            end
        end
        
        -- Connect the closest rooms
        if closest_room1 and closest_room2 then
            local connection = create_hallway(closest_room1, closest_room2)
            table.insert(connections, connection)
        end
        
        -- Merge groups
        for _, room in ipairs(group2) do
            table.insert(group1, room)
        end
        table.remove(connected_groups, 2)
    end
end

function explore_connected_rooms(room, visited, group)
    visited[room.id] = true
    table.insert(group, room)
    
    -- Find all directly connected rooms
    for _, connection in ipairs(connections) do
        local connected_room = nil
        if connection.from == room then
            connected_room = connection.to
        elseif connection.to == room then
            connected_room = connection.from
        end
        
        if connected_room and not visited[connected_room.id] then
            explore_connected_rooms(connected_room, visited, group)
        end
    end
end

function map_update(dt)
    for _, room in ipairs(rooms) do
        room:update(dt)
    end
end

function map_draw()
    -- Draw hallways
    love.graphics.setColor(0.3, 0.3, 0.3)
    for _, connection in ipairs(connections) do
        -- Draw thick lines for hallways
        love.graphics.setLineWidth(connection.width or 40)
        love.graphics.line(connection.x1, connection.y1, 
                          connection.x2, connection.y2)
    end
    love.graphics.setLineWidth(1)
    
    for _, room in ipairs(rooms) do
        room:draw()
    end
end

function get_room_at_position(x, y)
    for _, room in ipairs(rooms) do
        if x >= room.x and x <= room.x + room.width and
           y >= room.y and y <= room.y + room.height then
            return room
        end
    end
    return nil
end

function get_rooms()
    return rooms
end

function get_player_controlled_rooms()
    local controlled = {}
    for _, room in ipairs(rooms) do
        if room.owner == 1 then
            table.insert(controlled, room)
        end
    end
    return controlled
end

function get_connections()
    return connections
end

function get_connected_rooms(room)
    local connected = {}
    for _, connection in ipairs(connections) do
        if connection.from == room then
            table.insert(connected, connection.to)
        elseif connection.to == room then
            table.insert(connected, connection.from)
        end
    end
    return connected
end

function find_path_to_enemy_room(start_room, owner)
    local visited = {}
    local queue = {{room = start_room, path = {start_room}}}
    
    while #queue > 0 do
        local current = table.remove(queue, 1)
        local room = current.room
        
        if visited[room.id] then
            goto continue
        end
        visited[room.id] = true
        
        local has_enemies = false
        for _, unit in ipairs(room.units) do
            if unit.owner ~= owner then
                has_enemies = true
                break
            end
        end
        
        if has_enemies or (room.owner ~= 0 and room.owner ~= owner) then
            return current.path
        end
        
        local connected = get_connected_rooms(room)
        for _, next_room in ipairs(connected) do
            if not visited[next_room.id] then
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

function spawn_neutral_defenders()
    local neutral_count = 0
    local unowned_count = 0
    local spawned_units = 0
    
    -- Count room types for debugging
    for _, room in ipairs(rooms) do
        if room.owner == 3 then
            neutral_count = neutral_count + 1
        elseif room.owner == 0 then
            unowned_count = unowned_count + 1
        end
    end
    
    print("Room distribution: Neutral=" .. neutral_count .. ", Unowned=" .. unowned_count .. ", Total=" .. #rooms)
    
    -- Spawn independent defenders in neutral territory (owner=3)
    for _, room in ipairs(rooms) do
        if room.owner == 3 then
            -- Spawn 3-6 warriors and 1-2 archers per neutral room
            local num_warriors = math.random(3, 6)
            local num_archers = math.random(1, 2)
            
            -- Spawn warriors
            for i = 1, num_warriors do
                local spawn_x = room.x + room.width * (0.2 + math.random() * 0.6)
                local spawn_y = room.y + room.height * (0.2 + math.random() * 0.6)
                
                -- Ensure spawn coordinates are within map bounds
                spawn_x = math.max(0, math.min(MAP_WIDTH, spawn_x))
                spawn_y = math.max(0, math.min(MAP_HEIGHT, spawn_y))
                
                spawn_neutral_unit(spawn_x, spawn_y, "warrior", room)
                spawned_units = spawned_units + 1
            end
            
            -- Spawn archers
            for i = 1, num_archers do
                local spawn_x = room.x + room.width * (0.2 + math.random() * 0.6)
                local spawn_y = room.y + room.height * (0.2 + math.random() * 0.6)
                
                -- Ensure spawn coordinates are within map bounds
                spawn_x = math.max(0, math.min(MAP_WIDTH, spawn_x))
                spawn_y = math.max(0, math.min(MAP_HEIGHT, spawn_y))
                
                spawn_neutral_unit(spawn_x, spawn_y, "archer", room)
                spawned_units = spawned_units + 1
            end
        end
    end
    
    -- Also spawn some independent units in unowned (owner == 0) rooms
    for _, room in ipairs(rooms) do
        if room.owner == 0 then
            if math.random() < 0.6 then  -- 60% chance to spawn defenders
                local num_warriors = math.random(2, 4)
                local num_archers = math.random(1, 2)
                
                -- Spawn warriors
                for i = 1, num_warriors do
                    local spawn_x = room.x + room.width * (0.3 + math.random() * 0.4)
                    local spawn_y = room.y + room.height * (0.3 + math.random() * 0.4)
                    
                    -- Ensure spawn coordinates are within map bounds
                    spawn_x = math.max(0, math.min(MAP_WIDTH, spawn_x))
                    spawn_y = math.max(0, math.min(MAP_HEIGHT, spawn_y))
                    
                    spawn_neutral_unit(spawn_x, spawn_y, "warrior", room)
                    spawned_units = spawned_units + 1
                end
                
                -- Spawn archers
                for i = 1, num_archers do
                    local spawn_x = room.x + room.width * (0.3 + math.random() * 0.4)
                    local spawn_y = room.y + room.height * (0.3 + math.random() * 0.4)
                    
                    -- Ensure spawn coordinates are within map bounds
                    spawn_x = math.max(0, math.min(MAP_WIDTH, spawn_x))
                    spawn_y = math.max(0, math.min(MAP_HEIGHT, spawn_y))
                    
                    spawn_neutral_unit(spawn_x, spawn_y, "archer", room)
                    spawned_units = spawned_units + 1
                end
            end
        end
    end
    
    print("Spawned " .. spawned_units .. " independent defenders")
    debug_count_units()  -- Debug: count all units
end