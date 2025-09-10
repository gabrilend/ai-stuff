local buildings = {}
local selected_building_type = nil

local building_types = {
    {name = "Barracks", cost = 5, mana_rate = 1, max_mana = 10, 
     spawn_unit = "warrior", grid_width = 2, grid_height = 2},
    {name = "Archery Range", cost = 8, mana_rate = 0.8, max_mana = 12, 
     spawn_unit = "archer", grid_width = 2, grid_height = 2},
    {name = "Mage Tower", cost = 12, mana_rate = 0.6, max_mana = 15, 
     spawn_unit = "mage", grid_width = 1, grid_height = 1},
    {name = "Shop", cost = 6, mana_rate = 0.5, max_mana = 8, 
     spawn_unit = nil, grid_width = 2, grid_height = 1},
    {name = "Inn", cost = 4, mana_rate = 0.3, max_mana = 6, 
     spawn_unit = nil, grid_width = 2, grid_height = 1}
}

local Building = {}
Building.__index = Building

function Building:new(x, y, type_data, room, grid_x, grid_y)
    local building = {
        x = x,
        y = y,
        width = type_data.grid_width * 20,
        height = type_data.grid_height * 20,
        type = type_data,
        mana = 0,
        room = room,
        owner = 1,
        grid_x = grid_x,
        grid_y = grid_y
    }
    setmetatable(building, Building)
    return building
end

function Building:draw()
    local color
    if self.type.name == "Barracks" then
        color = {0.8, 0.4, 0.2}
    elseif self.type.name == "Archery Range" then
        color = {0.4, 0.8, 0.2}
    elseif self.type.name == "Mage Tower" then
        color = {0.2, 0.4, 0.8}
    elseif self.type.name == "Shop" then
        color = {0.8, 0.8, 0.2}
    elseif self.type.name == "Inn" then
        color = {0.6, 0.4, 0.8}
    else
        color = {0.5, 0.5, 0.5}
    end
    
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    if self.mana > 0 then
        local mana_percent = self.mana / self.type.max_mana
        love.graphics.setColor(0, 0, 1)
        love.graphics.rectangle("fill", self.x, self.y - 8, 
                              self.width * mana_percent, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", self.x, self.y - 8, 
                              self.width, 4)
    end
end

function Building:update(dt)
    self.mana = self.mana + self.type.mana_rate * dt
    
    if self.mana >= self.type.max_mana then
        self.mana = 0
        self:activate_effect()
    end
end

function Building:activate_effect()
    if self.type.spawn_unit then
        local unit_type = self.type.spawn_unit
        spawn_unit_at_building(self, unit_type)
    elseif self.type.name == "Shop" then
        -- Shop effect - units can buy items here
    elseif self.type.name == "Inn" then
        -- Inn effect - units can rest and heal here
    end
end

function building_init()
    buildings = {}
    selected_building_type = nil
end

function building_update(dt)
    for _, building in ipairs(buildings) do
        building:update(dt)
    end
end

function building_draw()
    for _, building in ipairs(buildings) do
        building:draw()
    end
end

function building_try_place(world_x, world_y)
    if not selected_building_type then
        return false
    end
    
    local room = get_room_at_position(world_x, world_y)
    if not room or room.owner ~= 1 then
        return false
    end
    
    local building_type = building_types[selected_building_type]
    if not player_spend_gold(building_type.cost) then
        return false
    end
    
    -- Convert world position to grid position
    local grid_x, grid_y = room:world_to_grid(world_x, world_y)
    
    -- Check if building can be placed at this grid position
    if not room:can_place_building_at_grid(grid_x, grid_y, 
                                         building_type.grid_width, 
                                         building_type.grid_height) then
        -- Refund gold if placement fails
        player_add_gold(building_type.cost)
        return false
    end
    
    -- Calculate actual world position from grid
    local world_build_x, world_build_y = room:grid_to_world(grid_x, grid_y)
    
    local building = Building:new(world_build_x, world_build_y, building_type, room, grid_x, grid_y)
    table.insert(buildings, building)
    room:add_building(building)
    
    -- Mark grid spaces as occupied
    room:occupy_grid_space(grid_x, grid_y, building_type.grid_width, building_type.grid_height)
    
    selected_building_type = nil
    ui_clear_selection()
    
    return true
end

function set_selected_building_type(index)
    selected_building_type = index
end

function get_selected_building_type()
    return selected_building_type
end

function get_building_types()
    return building_types
end

function require_building_class()
    return Building
end

function get_buildings_table()
    return buildings
end

function ai_place_building_direct(room, building_type)
    -- Check if AI controls this room
    if room.owner ~= 2 then
        return false
    end
    
    -- Find a valid grid position for AI building
    for grid_x = 1, room.grid_width - building_type.grid_width + 1 do
        for grid_y = 1, room.grid_height - building_type.grid_height + 1 do
            if ai_can_place_building_at_grid(room, grid_x, grid_y, 
                                             building_type.grid_width, 
                                             building_type.grid_height) then
                local world_x, world_y = room:grid_to_world(grid_x, grid_y)
                
                local building = Building:new(world_x, world_y, building_type, room, grid_x, grid_y)
                building.owner = 2
                
                table.insert(buildings, building)
                room:add_building(building)
                room:occupy_grid_space(grid_x, grid_y, building_type.grid_width, building_type.grid_height)
                
                return true
            end
        end
    end
    
    return false
end

function ai_can_place_building_at_grid(room, grid_x, grid_y, width, height)
    if room.owner ~= 2 then
        return false
    end
    
    if grid_x < 1 or grid_y < 1 or 
       grid_x + width - 1 > room.grid_width or 
       grid_y + height - 1 > room.grid_height then
        return false
    end
    
    for x = grid_x, grid_x + width - 1 do
        for y = grid_y, grid_y + height - 1 do
            if room.building_grid[x][y] then
                return false
            end
        end
    end
    
    return true
end