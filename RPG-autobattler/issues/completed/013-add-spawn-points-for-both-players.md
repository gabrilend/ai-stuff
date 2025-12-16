# Issue #013: Add Spawn Points for Both Players

## Current Behavior
No designated spawn points exist for players to deploy their units.

## Intended Behavior
Each player should have clearly defined spawn areas where they can deploy units and select which lanes to send them down.

## Implementation Details

### Spawn Point System (src/entities/spawn_point.lua)
```lua
local SpawnPoint = {}
local Vector2 = require("src.utils.vector2")

function SpawnPoint:new(position, player_id, connected_lanes)
    local spawn_point = {
        position = position,
        player_id = player_id,
        connected_lanes = connected_lanes or {},
        spawn_queue = {},
        spawn_radius = 25,
        deployment_areas = {},
        active = true
    }
    
    self:generate_deployment_areas(spawn_point)
    return spawn_point
end

function SpawnPoint:generate_deployment_areas(spawn_point)
    -- Create deployment zones for each connected lane
    for i, lane in ipairs(spawn_point.connected_lanes) do
        local lane_direction = lane.direction
        local perpendicular = Vector2:new(-lane_direction.y, lane_direction.x)
        
        -- Create deployment area in front of this lane
        local deployment_center = spawn_point.position:add(lane_direction:multiply(40))
        
        local deployment_area = {
            center = deployment_center,
            lane_id = lane.id,
            width = lane.width,
            height = 30,
            sub_path_slots = {},
            max_units = 10,  -- Maximum units that can queue here
            current_units = 0
        }
        
        -- Generate deployment slots for each sub-path
        for j = 1, 5 do
            local sub_path_offset = (j - 3) * (lane.width / 5)
            local slot_position = deployment_center:add(perpendicular:multiply(sub_path_offset))
            
            deployment_area.sub_path_slots[j] = {
                position = slot_position,
                sub_path_id = j,
                occupied = false,
                queue = {}
            }
        end
        
        spawn_point.deployment_areas[i] = deployment_area
    end
end

function SpawnPoint:can_deploy_unit(lane_id, sub_path_id)
    local deployment_area = self:find_deployment_area_by_lane(lane_id)
    if not deployment_area then
        return false
    end
    
    if deployment_area.current_units >= deployment_area.max_units then
        return false
    end
    
    local slot = deployment_area.sub_path_slots[sub_path_id]
    return slot and #slot.queue < 3  -- Max 3 units queued per sub-path
end

function SpawnPoint:deploy_unit(unit, lane_id, sub_path_id)
    local deployment_area = self:find_deployment_area_by_lane(lane_id)
    if not deployment_area then
        return false
    end
    
    local slot = deployment_area.sub_path_slots[sub_path_id]
    if not slot or #slot.queue >= 3 then
        return false
    end
    
    -- Position unit in deployment queue
    local queue_position = #slot.queue
    local queue_offset = Vector2:new(0, queue_position * 20)  -- Stack units vertically
    unit.position = slot.position:add(queue_offset)
    unit.target_lane = lane_id
    unit.target_sub_path = sub_path_id
    unit.spawn_timer = 1.0  -- 1 second delay before moving to lane
    
    table.insert(slot.queue, unit)
    deployment_area.current_units = deployment_area.current_units + 1
    
    return true
end

function SpawnPoint:update(dt)
    -- Process deployment queues
    for _, deployment_area in ipairs(self.deployment_areas) do
        for _, slot in ipairs(deployment_area.sub_path_slots) do
            for i = #slot.queue, 1, -1 do
                local unit = slot.queue[i]
                unit.spawn_timer = unit.spawn_timer - dt
                
                if unit.spawn_timer <= 0 then
                    -- Release unit to its target lane
                    self:release_unit_to_lane(unit)
                    table.remove(slot.queue, i)
                    deployment_area.current_units = deployment_area.current_units - 1
                    
                    -- Move remaining units forward in queue
                    self:adjust_queue_positions(slot)
                end
            end
        end
    end
end

function SpawnPoint:release_unit_to_lane(unit)
    -- Move unit to the start of its assigned lane/sub-path
    local lane = self:find_lane_by_id(unit.target_lane)
    if not lane then return end
    
    local sub_path = lane.sub_paths[unit.target_sub_path]
    if not sub_path then return end
    
    unit.position = sub_path.start_point
    unit.path_progress = 0
    unit.state = "moving"
    unit.current_lane = lane
    unit.current_sub_path = sub_path
end

function SpawnPoint:find_deployment_area_by_lane(lane_id)
    for _, area in ipairs(self.deployment_areas) do
        if area.lane_id == lane_id then
            return area
        end
    end
    return nil
end

function SpawnPoint:adjust_queue_positions(slot)
    for i, unit in ipairs(slot.queue) do
        local queue_offset = Vector2:new(0, (i - 1) * 20)
        unit.target_position = slot.position:add(queue_offset)
    end
end

function SpawnPoint:draw(renderer)
    -- Draw spawn point marker
    local colors = require("src.constants.colors")
    local player_color = self.player_id == 1 and colors.TEAM_A or colors.TEAM_B
    
    renderer:draw_circle(self.position.x, self.position.y, self.spawn_radius, player_color, "line")
    
    -- Draw deployment areas
    for _, area in ipairs(self.deployment_areas) do
        renderer:draw_rectangle(
            area.center.x - area.width/2,
            area.center.y - area.height/2,
            area.width,
            area.height,
            player_color,
            "line"
        )
        
        -- Draw sub-path slots
        for _, slot in ipairs(area.sub_path_slots) do
            local slot_color = #slot.queue > 0 and colors.UI_SUCCESS or colors.NEUTRAL
            renderer:draw_circle(slot.position.x, slot.position.y, 8, slot_color)
        end
    end
end

return SpawnPoint
```

### Spawn Point Features
1. **Lane Connection**: Each spawn point connects to multiple lanes
2. **Sub-Path Selection**: Players can choose which sub-path to use
3. **Unit Queuing**: Multiple units can queue for deployment
4. **Visual Feedback**: Clear indicators for deployment status
5. **Deployment Timing**: Controlled release timing to prevent clustering

### Considerations
- Ensure spawn points are positioned to avoid immediate conflicts
- Plan for different deployment strategies and timings
- Consider spawn point capacity and upgrade options
- Add visual feedback for deployment availability
- Handle edge cases like lane blockages

### Tool Suggestions
- Use Write tool to create spawn point system
- Test deployment with multiple units and lanes
- Verify queue management works correctly
- Check visual feedback is clear and helpful

### Acceptance Criteria
- [ ] Each player has functional spawn points
- [ ] Units can be deployed to specific lanes and sub-paths
- [ ] Deployment queuing works correctly
- [ ] Visual indicators show deployment status
- [ ] Spawn timing prevents unit clustering
- [ ] System handles maximum capacity gracefully