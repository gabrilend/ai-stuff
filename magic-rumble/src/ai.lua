local ai_timer = 0
local AI_TURN_INTERVAL = 15

function ai_init()
    ai_timer = 0
end

function ai_update(dt)
    ai_timer = ai_timer + dt
    
    if ai_timer >= AI_TURN_INTERVAL then
        ai_timer = 0
        ai_make_decision()
    end
end

function ai_make_decision()
    local enemy_gold = get_enemy_gold()
    local enemy_controlled_rooms = get_enemy_controlled_rooms()
    
    if #enemy_controlled_rooms > 0 and enemy_gold >= 4 then  -- Minimum cost building is 4
        -- Try to place a building in a random controlled room
        local attempts = 0
        while attempts < 5 and enemy_gold >= 4 do  -- Try up to 5 times
            local room = enemy_controlled_rooms[math.random(#enemy_controlled_rooms)]
            
            -- Check if room has space for more buildings
            if ai_room_has_space(room) then
                local building_types = get_building_types()
                local affordable_buildings = {}
                
                for i, building_type in ipairs(building_types) do
                    if building_type.cost <= enemy_gold then
                        table.insert(affordable_buildings, {type = building_type, index = i})
                    end
                end
                
                if #affordable_buildings > 0 then
                    local choice = affordable_buildings[math.random(#affordable_buildings)]
                    if enemy_spend_gold(choice.type.cost) and ai_place_building(room, choice.type, choice.index) then
                        enemy_gold = get_enemy_gold()  -- Update local copy
                        break  -- Successfully placed a building
                    end
                end
            end
            
            attempts = attempts + 1
        end
    end
end

function ai_room_has_space(room)
    -- Check if room has available grid spaces
    local total_spaces = room.grid_width * room.grid_height
    local occupied_spaces = 0
    
    for x = 1, room.grid_width do
        for y = 1, room.grid_height do
            if room.building_grid[x][y] then
                occupied_spaces = occupied_spaces + 1
            end
        end
    end
    
    return occupied_spaces < total_spaces * 0.8  -- Don't fill more than 80% of room
end

function ai_place_building(room, building_type, type_index)
    return ai_place_building_direct(room, building_type)
end

function get_enemy_controlled_rooms()
    local controlled = {}
    local rooms = get_rooms()
    for _, room in ipairs(rooms) do
        if room.owner == 2 then
            table.insert(controlled, room)
        end
    end
    return controlled
end