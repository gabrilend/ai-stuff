-- {{{ Spawn Point entity for player unit deployment
local SpawnPoint = {}
SpawnPoint.__index = SpawnPoint

-- {{{ SpawnPoint:new
function SpawnPoint:new(position, player_id, connected_lanes)
    local Vector2 = require("src.utils.vector2")
    
    local spawn_point = {
        position = position or Vector2:new(0, 0),
        player_id = player_id or 1,
        connected_lanes = connected_lanes or {},
        spawn_queue = {},
        spawn_radius = 25,
        deployment_areas = {},
        active = true,
        max_concurrent_spawns = 3,
        spawn_cooldown = 0.5
    }
    
    setmetatable(spawn_point, SpawnPoint)
    spawn_point:generate_deployment_areas()
    
    return spawn_point
end
-- }}}

-- {{{ SpawnPoint:generate_deployment_areas
function SpawnPoint:generate_deployment_areas()
    local Vector2 = require("src.utils.vector2")
    
    self.deployment_areas = {}
    
    -- Create deployment zones for each connected lane
    for i, lane in ipairs(self.connected_lanes) do
        -- Calculate lane direction
        local lane_direction = Vector2:new(
            lane.end_x - lane.start_x,
            lane.end_y - lane.start_y
        ):normalize()
        
        local perpendicular = Vector2:new(-lane_direction.y, lane_direction.x)
        
        -- Create deployment area in front of this lane
        local deployment_center = self.position:add(lane_direction:multiply(40))
        
        local deployment_area = {
            center = deployment_center,
            lane_id = lane.id or i,
            width = lane.width or 60,
            height = 30,
            sub_path_slots = {},
            max_units = 10,  -- Maximum units that can queue here
            current_units = 0,
            lane_direction = lane_direction,
            perpendicular = perpendicular
        }
        
        -- Generate deployment slots for each sub-path
        for j = 1, 5 do
            local sub_path_offset = (j - 3) * (deployment_area.width / 5)
            local slot_position = deployment_center:add(perpendicular:multiply(sub_path_offset))
            
            deployment_area.sub_path_slots[j] = {
                position = slot_position,
                sub_path_id = j,
                occupied = false,
                queue = {},
                max_queue_size = 3
            }
        end
        
        self.deployment_areas[i] = deployment_area
    end
end
-- }}}

-- {{{ SpawnPoint:can_deploy_unit
function SpawnPoint:can_deploy_unit(lane_id, sub_path_id)
    local deployment_area = self:find_deployment_area_by_lane(lane_id)
    if not deployment_area then
        return false
    end
    
    if deployment_area.current_units >= deployment_area.max_units then
        return false
    end
    
    local slot = deployment_area.sub_path_slots[sub_path_id]
    return slot and #slot.queue < slot.max_queue_size
end
-- }}}

-- {{{ SpawnPoint:deploy_unit
function SpawnPoint:deploy_unit(unit, lane_id, sub_path_id)
    local Vector2 = require("src.utils.vector2")
    
    if not self:can_deploy_unit(lane_id, sub_path_id) then
        return false
    end
    
    local deployment_area = self:find_deployment_area_by_lane(lane_id)
    if not deployment_area then
        return false
    end
    
    local slot = deployment_area.sub_path_slots[sub_path_id]
    if not slot then
        return false
    end
    
    -- Position unit in deployment queue
    local queue_position = #slot.queue
    local queue_offset = Vector2:new(0, queue_position * 20)  -- Stack units vertically
    unit.position = slot.position:add(queue_offset)
    unit.target_lane = lane_id
    unit.target_sub_path = sub_path_id
    unit.spawn_timer = 1.0 + (queue_position * 0.2)  -- Staggered spawn timing
    unit.state = "deploying"
    
    table.insert(slot.queue, unit)
    deployment_area.current_units = deployment_area.current_units + 1
    
    return true
end
-- }}}

-- {{{ SpawnPoint:update
function SpawnPoint:update(dt)
    if not self.active then
        return
    end
    
    -- Process deployment queues
    for _, deployment_area in ipairs(self.deployment_areas) do
        for _, slot in ipairs(deployment_area.sub_path_slots) do
            for i = #slot.queue, 1, -1 do
                local unit = slot.queue[i]
                if unit.spawn_timer then
                    unit.spawn_timer = unit.spawn_timer - dt
                    
                    if unit.spawn_timer <= 0 then
                        -- Release unit to its target lane
                        self:release_unit_to_lane(unit, deployment_area)
                        table.remove(slot.queue, i)
                        deployment_area.current_units = deployment_area.current_units - 1
                        
                        -- Move remaining units forward in queue
                        self:adjust_queue_positions(slot)
                    end
                end
            end
        end
    end
end
-- }}}

-- {{{ SpawnPoint:release_unit_to_lane
function SpawnPoint:release_unit_to_lane(unit, deployment_area)
    local Vector2 = require("src.utils.vector2")
    
    -- Find the connected lane
    local target_lane = nil
    for _, lane in ipairs(self.connected_lanes) do
        if (lane.id or 0) == unit.target_lane then
            target_lane = lane
            break
        end
    end
    
    if not target_lane then
        -- Fallback to first connected lane
        target_lane = self.connected_lanes[1]
        if not target_lane then
            return
        end
    end
    
    -- Calculate start position for the sub-path
    local sub_path_offset = (unit.target_sub_path - 3) * (target_lane.width / 5)
    local lane_direction = deployment_area.lane_direction
    local perpendicular = deployment_area.perpendicular
    
    local start_position = Vector2:new(target_lane.start_x, target_lane.start_y)
    unit.position = start_position:add(perpendicular:multiply(sub_path_offset))
    unit.path_progress = 0
    unit.state = "moving"
    unit.current_lane = target_lane
    unit.current_sub_path_id = unit.target_sub_path
    unit.spawn_timer = nil
end
-- }}}

-- {{{ SpawnPoint:find_deployment_area_by_lane
function SpawnPoint:find_deployment_area_by_lane(lane_id)
    for _, area in ipairs(self.deployment_areas) do
        if area.lane_id == lane_id then
            return area
        end
    end
    return nil
end
-- }}}

-- {{{ SpawnPoint:adjust_queue_positions
function SpawnPoint:adjust_queue_positions(slot)
    local Vector2 = require("src.utils.vector2")
    
    for i, unit in ipairs(slot.queue) do
        local queue_offset = Vector2:new(0, (i - 1) * 20)
        unit.target_position = slot.position:add(queue_offset)
        
        -- Smoothly move unit to new position
        if unit.position then
            unit.position = unit.position:lerp(unit.target_position, 0.1)
        else
            unit.position = unit.target_position
        end
    end
end
-- }}}

-- {{{ SpawnPoint:get_available_lanes
function SpawnPoint:get_available_lanes()
    local available = {}
    
    for _, lane in ipairs(self.connected_lanes) do
        local deployment_area = self:find_deployment_area_by_lane(lane.id or 0)
        if deployment_area and deployment_area.current_units < deployment_area.max_units then
            table.insert(available, {
                lane = lane,
                capacity = deployment_area.max_units - deployment_area.current_units
            })
        end
    end
    
    return available
end
-- }}}

-- {{{ SpawnPoint:get_sub_path_status
function SpawnPoint:get_sub_path_status(lane_id)
    local deployment_area = self:find_deployment_area_by_lane(lane_id)
    if not deployment_area then
        return {}
    end
    
    local status = {}
    for i, slot in ipairs(deployment_area.sub_path_slots) do
        status[i] = {
            sub_path_id = i,
            queue_size = #slot.queue,
            max_queue_size = slot.max_queue_size,
            available = #slot.queue < slot.max_queue_size
        }
    end
    
    return status
end
-- }}}

-- {{{ SpawnPoint:clear_deployment_area
function SpawnPoint:clear_deployment_area(lane_id)
    local deployment_area = self:find_deployment_area_by_lane(lane_id)
    if not deployment_area then
        return false
    end
    
    local cleared_units = 0
    for _, slot in ipairs(deployment_area.sub_path_slots) do
        cleared_units = cleared_units + #slot.queue
        slot.queue = {}
    end
    
    deployment_area.current_units = 0
    return cleared_units
end
-- }}}

-- {{{ SpawnPoint:set_active
function SpawnPoint:set_active(active)
    self.active = active
end
-- }}}

-- {{{ SpawnPoint:draw
function SpawnPoint:draw(renderer)
    if not renderer then
        return
    end
    
    -- Determine player color
    local player_color = {1, 0, 0}  -- Red for player 1
    if self.player_id == 2 then
        player_color = {0, 0, 1}    -- Blue for player 2
    end
    
    -- Draw spawn point marker
    renderer:draw_circle(self.position.x, self.position.y, self.spawn_radius, player_color, "line")
    
    -- Draw activation indicator
    if self.active then
        renderer:draw_circle(self.position.x, self.position.y, 5, player_color, "fill")
    end
    
    -- Draw deployment areas
    for _, area in ipairs(self.deployment_areas) do
        local area_color = {player_color[1] * 0.5, player_color[2] * 0.5, player_color[3] * 0.5}
        
        -- Draw deployment area boundary
        renderer:draw_rectangle(
            area.center.x - area.width/2,
            area.center.y - area.height/2,
            area.width,
            area.height,
            area_color,
            "line"
        )
        
        -- Draw sub-path slots
        for _, slot in ipairs(area.sub_path_slots) do
            local slot_color = player_color
            if #slot.queue > 0 then
                slot_color = {0, 1, 0}  -- Green when occupied
            elseif #slot.queue >= slot.max_queue_size then
                slot_color = {1, 1, 0}  -- Yellow when full
            end
            
            renderer:draw_circle(slot.position.x, slot.position.y, 8, slot_color, "fill")
            
            -- Draw queue indicator
            if #slot.queue > 0 then
                renderer:draw_text(tostring(#slot.queue), slot.position.x - 3, slot.position.y - 5)
            end
        end
    end
end
-- }}}

-- {{{ SpawnPoint:get_stats
function SpawnPoint:get_stats()
    local total_capacity = 0
    local total_deployed = 0
    local active_lanes = 0
    
    for _, area in ipairs(self.deployment_areas) do
        total_capacity = total_capacity + area.max_units
        total_deployed = total_deployed + area.current_units
        
        if area.current_units > 0 then
            active_lanes = active_lanes + 1
        end
    end
    
    return {
        player_id = self.player_id,
        active = self.active,
        total_capacity = total_capacity,
        total_deployed = total_deployed,
        available_capacity = total_capacity - total_deployed,
        connected_lanes = #self.connected_lanes,
        active_lanes = active_lanes,
        utilization = total_capacity > 0 and (total_deployed / total_capacity) or 0
    }
end
-- }}}

return SpawnPoint
-- }}}