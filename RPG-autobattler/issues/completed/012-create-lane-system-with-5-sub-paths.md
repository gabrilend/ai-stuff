# Issue #012: Create Lane System with 5 Sub-Paths

## Current Behavior
No lane system exists to organize unit movement within the generated pathways.

## Intended Behavior
Each pathway should be divided into 5 parallel sub-paths that units can follow, enabling formation control and tactical positioning.

## Implementation Details

### Lane System (src/systems/lane_system.lua)
```lua
local LaneSystem = {}
local Vector2 = require("src.utils.vector2")

function LaneSystem:create_lane(start_point, end_point, width)
    local lane = {
        start_point = start_point,
        end_point = end_point,
        width = width or 60,
        sub_paths = {},
        length = start_point:distance_to(end_point),
        direction = end_point:subtract(start_point):normalize()
    }
    
    self:generate_sub_paths(lane)
    return lane
end

function LaneSystem:generate_sub_paths(lane)
    local perpendicular = Vector2:new(-lane.direction.y, lane.direction.x)
    local sub_path_width = lane.width / 5
    
    for i = 1, 5 do
        -- Calculate offset from center of lane
        local offset = (i - 3) * sub_path_width  -- -2, -1, 0, 1, 2 spacing
        local side_offset = perpendicular:multiply(offset)
        
        local sub_path = {
            id = i,
            start_point = lane.start_point:add(side_offset),
            end_point = lane.end_point:add(side_offset),
            width = sub_path_width * 0.8,  -- Leave small gaps between sub-paths
            center_line = {},
            waypoints = {}
        }
        
        self:generate_waypoints(sub_path, lane)
        lane.sub_paths[i] = sub_path
    end
end

function LaneSystem:generate_waypoints(sub_path, lane)
    local waypoint_count = math.max(3, math.floor(lane.length / 50))
    
    for i = 0, waypoint_count do
        local t = i / waypoint_count
        local point = sub_path.start_point:add(
            sub_path.end_point:subtract(sub_path.start_point):multiply(t)
        )
        
        -- Add slight random variation to make paths look more natural
        if i > 0 and i < waypoint_count then
            local variation = Vector2:new(
                (love.math.random() - 0.5) * 10,
                (love.math.random() - 0.5) * 10
            )
            point = point:add(variation)
        end
        
        table.insert(sub_path.waypoints, point)
    end
    
    -- Generate smooth center line
    self:smooth_path(sub_path)
end

function LaneSystem:smooth_path(sub_path)
    -- Simple smoothing using control points
    if #sub_path.waypoints < 3 then
        sub_path.center_line = sub_path.waypoints
        return
    end
    
    local smoothed = {}
    local resolution = 10  -- Points per segment
    
    for i = 1, #sub_path.waypoints - 1 do
        local p0 = sub_path.waypoints[math.max(1, i - 1)]
        local p1 = sub_path.waypoints[i]
        local p2 = sub_path.waypoints[i + 1] 
        local p3 = sub_path.waypoints[math.min(#sub_path.waypoints, i + 2)]
        
        for t = 0, resolution - 1 do
            local u = t / resolution
            local point = self:catmull_rom_spline(p0, p1, p2, p3, u)
            table.insert(smoothed, point)
        end
    end
    
    table.insert(smoothed, sub_path.waypoints[#sub_path.waypoints])
    sub_path.center_line = smoothed
end

function LaneSystem:catmull_rom_spline(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    
    local x = 0.5 * ((2 * p1.x) +
                     (-p0.x + p2.x) * t +
                     (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                     (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
    
    local y = 0.5 * ((2 * p1.y) +
                     (-p0.y + p2.y) * t +
                     (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
                     (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
    
    return Vector2:new(x, y)
end

function LaneSystem:get_position_on_sub_path(sub_path, progress)
    -- Progress from 0 to 1 along the path
    progress = math.max(0, math.min(1, progress))
    
    local total_points = #sub_path.center_line
    if total_points < 2 then
        return sub_path.start_point
    end
    
    local segment_index = math.floor(progress * (total_points - 1)) + 1
    segment_index = math.min(segment_index, total_points - 1)
    
    local segment_progress = (progress * (total_points - 1)) - (segment_index - 1)
    
    local p1 = sub_path.center_line[segment_index]
    local p2 = sub_path.center_line[segment_index + 1]
    
    return p1:add(p2:subtract(p1):multiply(segment_progress))
end

function LaneSystem:find_nearest_sub_path(lane, position)
    local nearest_sub_path = nil
    local min_distance = math.huge
    
    for _, sub_path in ipairs(lane.sub_paths) do
        -- Check distance to sub-path center line
        for _, point in ipairs(sub_path.center_line) do
            local distance = position:distance_to(point)
            if distance < min_distance then
                min_distance = distance
                nearest_sub_path = sub_path
            end
        end
    end
    
    return nearest_sub_path, min_distance
end

return LaneSystem
```

### Sub-Path Properties
1. **Width**: ~20% of total lane width per sub-path
2. **Spacing**: Small gaps between sub-paths for visual clarity  
3. **Smoothing**: Natural-looking curves using spline interpolation
4. **Waypoints**: Configurable resolution for path detail

### Considerations
- Ensure sub-paths don't cross each other
- Maintain consistent spacing across different lane lengths
- Optimize path calculations for real-time pathfinding
- Consider curved lanes and complex geometries
- Plan for dynamic path modification if needed

### Tool Suggestions
- Use Write tool to create lane system
- Test sub-path generation with various lane configurations
- Verify smooth path interpolation works correctly
- Check performance with many lanes

### Acceptance Criteria
- [ ] Each lane has exactly 5 distinct sub-paths
- [ ] Sub-paths are properly spaced and parallel
- [ ] Path smoothing creates natural-looking curves
- [ ] Position calculation along sub-paths is accurate
- [ ] Sub-path finding algorithms work efficiently
- [ ] Visual representation shows clear lane structure