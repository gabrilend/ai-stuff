local building_preview = {
    visible = false,
    world_x = 0,
    world_y = 0,
    building_type = nil,
    can_place = false
}

function preview_init()
    building_preview.visible = false
end

function preview_update(world_x, world_y)
    local selected_type = get_selected_building_type()
    if selected_type then
        building_preview.visible = true
        building_preview.world_x = world_x
        building_preview.world_y = world_y
        building_preview.building_type = get_building_types()[selected_type]
        
        -- Check if we can place the building here
        local room = get_room_at_position(world_x, world_y)
        if room and room.owner == 1 then
            local grid_x, grid_y = room:world_to_grid(world_x, world_y)
            building_preview.can_place = room:can_place_building_at_grid(
                grid_x, grid_y, 
                building_preview.building_type.grid_width,
                building_preview.building_type.grid_height
            ) and player_get_gold() >= building_preview.building_type.cost
        else
            building_preview.can_place = false
        end
    else
        building_preview.visible = false
    end
end

function preview_draw()
    if not building_preview.visible or not building_preview.building_type then
        return
    end
    
    local room = get_room_at_position(building_preview.world_x, building_preview.world_y)
    if not room then
        return
    end
    
    local grid_x, grid_y = room:world_to_grid(building_preview.world_x, building_preview.world_y)
    local snap_x, snap_y = room:grid_to_world(grid_x, grid_y)
    
    local width = building_preview.building_type.grid_width * 20
    local height = building_preview.building_type.grid_height * 20
    
    -- Draw preview with appropriate color
    if building_preview.can_place then
        love.graphics.setColor(0, 1, 0, 0.5)  -- Green for valid placement
    else
        love.graphics.setColor(1, 0, 0, 0.5)  -- Red for invalid placement
    end
    
    love.graphics.rectangle("fill", snap_x, snap_y, width, height)
    
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.rectangle("line", snap_x, snap_y, width, height)
end

function get_preview()
    return building_preview
end