-- {{{ Map-Lane Integration for adding lane systems to generated maps
local MapLaneIntegration = {}

-- Simple lane creation to avoid dependency issues
local function create_simple_lane(start_x, start_y, end_x, end_y, width)
    width = width or 60
    
    local lane = {
        start_x = start_x,
        start_y = start_y,
        end_x = end_x,
        end_y = end_y,
        width = width,
        length = math.sqrt((end_x - start_x)^2 + (end_y - start_y)^2),
        sub_paths = {}
    }
    
    -- Generate 5 sub-paths
    for i = 1, 5 do
        local offset = (i - 3) * (width / 5)  -- -2, -1, 0, 1, 2 spacing
        
        local sub_path = {
            id = i,
            offset = offset,
            start_x = start_x,
            start_y = start_y + offset,
            end_x = end_x,
            end_y = end_y + offset,
            waypoints = {},
            center_line = {}
        }
        
        -- Generate waypoints along the path
        local waypoint_count = math.max(3, math.floor(lane.length / 50))
        waypoint_count = math.min(waypoint_count, 15)
        
        for j = 0, waypoint_count do
            local t = j / waypoint_count
            local x = start_x + (end_x - start_x) * t
            local y = (start_y + offset) + ((end_y + offset) - (start_y + offset)) * t
            
            -- Add slight variation for natural look
            if j > 0 and j < waypoint_count then
                x = x + (math.random() - 0.5) * 6
                y = y + (math.random() - 0.5) * 6
            end
            
            table.insert(sub_path.waypoints, {x = x, y = y})
        end
        
        -- Create center line (simplified smoothing)
        for k = 1, #sub_path.waypoints do
            table.insert(sub_path.center_line, {
                x = sub_path.waypoints[k].x,
                y = sub_path.waypoints[k].y
            })
        end
        
        lane.sub_paths[i] = sub_path
    end
    
    return lane
end

-- {{{ MapLaneIntegration:add_lanes_to_map
function MapLaneIntegration:add_lanes_to_map(map)
    if not map or not map.paths then
        return map
    end
    
    -- Convert each generated path into a lane with sub-paths
    map.lanes = {}
    
    for i, path in ipairs(map.paths) do
        if #path.points >= 2 then
            local start_point = path.points[1]
            local end_point = path.points[#path.points]
            
            local lane = create_simple_lane(
                start_point.x, start_point.y,
                end_point.x, end_point.y,
                path.width
            )
            
            lane.id = i
            lane.original_path = path
            lane.connection_id = path.start_point and path.end_point and 
                               self:find_connection_id(map, path.start_point, path.end_point) or nil
            
            table.insert(map.lanes, lane)
        end
    end
    
    return map
end
-- }}}

-- {{{ MapLaneIntegration:find_connection_id
function MapLaneIntegration:find_connection_id(map, start_point, end_point)
    for i, connection in ipairs(map.connections or {}) do
        if (connection.from == start_point and connection.to == end_point) or
           (connection.from == end_point and connection.to == start_point) then
            return connection.id
        end
    end
    return nil
end
-- }}}

-- {{{ MapLaneIntegration:get_lane_by_connection
function MapLaneIntegration:get_lane_by_connection(map, connection_id)
    for _, lane in ipairs(map.lanes or {}) do
        if lane.connection_id == connection_id then
            return lane
        end
    end
    return nil
end
-- }}}

-- {{{ MapLaneIntegration:get_lanes_from_node
function MapLaneIntegration:get_lanes_from_node(map, node)
    local connected_lanes = {}
    
    for _, lane in ipairs(map.lanes or {}) do
        local start_distance = math.sqrt((lane.start_x - node.x)^2 + (lane.start_y - node.y)^2)
        local end_distance = math.sqrt((lane.end_x - node.x)^2 + (lane.end_y - node.y)^2)
        
        if start_distance < 30 or end_distance < 30 then
            table.insert(connected_lanes, {
                lane = lane,
                is_start = start_distance < end_distance
            })
        end
    end
    
    return connected_lanes
end
-- }}}

-- {{{ MapLaneIntegration:get_position_on_lane
function MapLaneIntegration:get_position_on_lane(lane, sub_path_id, progress)
    if not lane or not lane.sub_paths or not lane.sub_paths[sub_path_id] then
        return {x = 0, y = 0}
    end
    
    local sub_path = lane.sub_paths[sub_path_id]
    progress = math.max(0, math.min(1, progress))
    
    if #sub_path.center_line == 0 then
        return {x = sub_path.start_x or 0, y = sub_path.start_y or 0}
    end
    
    local segment_index = math.floor(progress * (#sub_path.center_line - 1)) + 1
    segment_index = math.min(segment_index, #sub_path.center_line - 1)
    
    local segment_progress = (progress * (#sub_path.center_line - 1)) - (segment_index - 1)
    
    local p1 = sub_path.center_line[segment_index]
    local p2 = sub_path.center_line[segment_index + 1]
    
    return {
        x = p1.x + (p2.x - p1.x) * segment_progress,
        y = p1.y + (p2.y - p1.y) * segment_progress
    }
end
-- }}}

-- {{{ MapLaneIntegration:calculate_formation_positions
function MapLaneIntegration:calculate_formation_positions(lane, formation_type, unit_count, base_progress)
    formation_type = formation_type or "line"
    base_progress = base_progress or 0
    unit_count = unit_count or 1
    
    local positions = {}
    
    if formation_type == "line" then
        -- Spread units across multiple sub-paths
        local sub_paths_used = math.min(unit_count, 5)
        local start_sub_path = math.max(1, math.floor((5 - sub_paths_used) / 2) + 1)
        
        for i = 1, unit_count do
            local sub_path_id = start_sub_path + ((i - 1) % sub_paths_used)
            local position = self:get_position_on_lane(lane, sub_path_id, base_progress)
            
            table.insert(positions, {
                position = position,
                sub_path_id = sub_path_id,
                progress = base_progress
            })
        end
        
    elseif formation_type == "column" then
        -- Single sub-path, units spread along it
        local spacing = 0.05
        
        for i = 1, unit_count do
            local progress = base_progress - (i - 1) * spacing
            progress = math.max(0, progress)
            
            local position = self:get_position_on_lane(lane, 3, progress) -- Center sub-path
            
            table.insert(positions, {
                position = position,
                sub_path_id = 3,
                progress = progress
            })
        end
    end
    
    return positions
end
-- }}}

-- {{{ MapLaneIntegration:get_map_stats
function MapLaneIntegration:get_map_stats(map)
    local stats = {
        total_lanes = #(map.lanes or {}),
        total_sub_paths = 0,
        total_lane_length = 0,
        average_lane_width = 0
    }
    
    local total_width = 0
    
    for _, lane in ipairs(map.lanes or {}) do
        stats.total_sub_paths = stats.total_sub_paths + #lane.sub_paths
        stats.total_lane_length = stats.total_lane_length + lane.length
        total_width = total_width + lane.width
    end
    
    if stats.total_lanes > 0 then
        stats.average_lane_width = total_width / stats.total_lanes
    end
    
    return stats
end
-- }}}

return MapLaneIntegration
-- }}}