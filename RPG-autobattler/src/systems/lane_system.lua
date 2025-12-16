-- {{{ Lane System for organizing unit movement with 5 sub-paths
local LaneSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local debug = require("src.utils.debug")

-- Constants
LaneSystem.SUB_PATH_COUNT = 5
LaneSystem.DEFAULT_LANE_WIDTH = 60
LaneSystem.WAYPOINT_SPACING = 50
LaneSystem.SMOOTHING_RESOLUTION = 10

-- {{{ LaneSystem:create_lane
function LaneSystem:create_lane(start_point, end_point, width, curve_points)
    width = width or LaneSystem.DEFAULT_LANE_WIDTH
    curve_points = curve_points or {}
    
    local lane = {
        start_point = start_point:copy(),
        end_point = end_point:copy(),
        width = width,
        sub_paths = {},
        curve_points = {},
        metadata = {
            length = 0,
            direction = Vector2:new(0, 0),
            perpendicular = Vector2:new(0, 0),
            segments = 0
        }
    }
    
    -- Copy curve points for bezier path
    for _, point in ipairs(curve_points) do
        table.insert(lane.curve_points, point:copy())
    end
    
    -- Calculate lane properties
    self:calculate_lane_properties(lane)
    
    -- Generate the 5 sub-paths
    self:generate_sub_paths(lane)
    
    debug.log(string.format("Created lane with %d sub-paths, length %.1f", 
              #lane.sub_paths, lane.metadata.length), "LANE_SYSTEM")
    
    return lane
end
-- }}}

-- {{{ LaneSystem:calculate_lane_properties
function LaneSystem:calculate_lane_properties(lane)
    if #lane.curve_points > 0 then
        -- For curved lanes, calculate properties along the curve
        local total_length = 0
        local sample_points = {}
        
        -- Sample points along the curve
        local samples = 20
        for i = 0, samples do
            local t = i / samples
            local point = self:evaluate_curve(lane, t)
            table.insert(sample_points, point)
            
            if i > 0 then
                total_length = total_length + sample_points[i]:distance_to(sample_points[i + 1])
            end
        end
        
        lane.metadata.length = total_length
        
        -- Average direction (approximate)
        local overall_direction = lane.end_point:subtract(lane.start_point):normalize()
        lane.metadata.direction = overall_direction
        lane.metadata.perpendicular = Vector2:new(-overall_direction.y, overall_direction.x)
        
    else
        -- Straight lane
        local direction = lane.end_point:subtract(lane.start_point)
        lane.metadata.length = direction:length()
        lane.metadata.direction = direction:normalize()
        lane.metadata.perpendicular = Vector2:new(-lane.metadata.direction.y, lane.metadata.direction.x)
    end
end
-- }}}

-- {{{ LaneSystem:evaluate_curve
function LaneSystem:evaluate_curve(lane, t)
    if #lane.curve_points == 0 then
        -- Linear interpolation for straight lanes
        return lane.start_point:lerp(lane.end_point, t)
    elseif #lane.curve_points == 1 then
        -- Quadratic bezier curve
        return self:quadratic_bezier(lane.start_point, lane.curve_points[1], lane.end_point, t)
    else
        -- Use first control point for now (could extend to cubic bezier)
        return self:quadratic_bezier(lane.start_point, lane.curve_points[1], lane.end_point, t)
    end
end
-- }}}

-- {{{ LaneSystem:quadratic_bezier
function LaneSystem:quadratic_bezier(p0, p1, p2, t)
    local one_minus_t = 1 - t
    local x = one_minus_t * one_minus_t * p0.x + 2 * one_minus_t * t * p1.x + t * t * p2.x
    local y = one_minus_t * one_minus_t * p0.y + 2 * one_minus_t * t * p1.y + t * t * p2.y
    return Vector2:new(x, y)
end
-- }}}

-- {{{ LaneSystem:generate_sub_paths
function LaneSystem:generate_sub_paths(lane)
    local sub_path_width = lane.width / LaneSystem.SUB_PATH_COUNT
    local gap_factor = 0.85  -- Slightly narrow sub-paths to create visual gaps
    
    for i = 1, LaneSystem.SUB_PATH_COUNT do
        -- Calculate offset from center (-2, -1, 0, 1, 2)
        local offset_multiplier = i - (LaneSystem.SUB_PATH_COUNT + 1) / 2
        
        local sub_path = {
            id = i,
            lane_id = lane.id or 0,
            width = sub_path_width * gap_factor,
            offset = offset_multiplier * sub_path_width,
            waypoints = {},
            center_line = {},
            metadata = {
                length = 0,
                point_count = 0,
                smoothed = false
            }
        }
        
        -- Generate waypoints along the lane path
        self:generate_waypoints(sub_path, lane)
        
        -- Smooth the path using spline interpolation
        self:smooth_path(sub_path)
        
        lane.sub_paths[i] = sub_path
    end
    
    debug.log("Generated " .. #lane.sub_paths .. " sub-paths", "LANE_SYSTEM")
end
-- }}}

-- {{{ LaneSystem:generate_waypoints
function LaneSystem:generate_waypoints(sub_path, lane)
    local waypoint_count = math.max(3, math.floor(lane.metadata.length / LaneSystem.WAYPOINT_SPACING))
    waypoint_count = math.min(waypoint_count, 20)  -- Cap for performance
    
    for i = 0, waypoint_count do
        local t = i / waypoint_count
        
        -- Get the main path point
        local main_point = self:evaluate_curve(lane, t)
        
        -- Calculate perpendicular offset for this sub-path
        local perpendicular_offset = self:get_perpendicular_at_t(lane, t, sub_path.offset)
        local sub_path_point = main_point:add(perpendicular_offset)
        
        -- Add subtle random variation to middle waypoints for natural look
        if i > 0 and i < waypoint_count then
            local variation_strength = 3.0
            local random_offset = Vector2:new(
                (math.random() - 0.5) * variation_strength,
                (math.random() - 0.5) * variation_strength
            )
            sub_path_point = sub_path_point:add(random_offset)
        end
        
        table.insert(sub_path.waypoints, sub_path_point)
    end
    
    sub_path.metadata.point_count = #sub_path.waypoints
    debug.log(string.format("Generated %d waypoints for sub-path %d", 
              #sub_path.waypoints, sub_path.id), "LANE_SYSTEM")
end
-- }}}

-- {{{ LaneSystem:get_perpendicular_at_t
function LaneSystem:get_perpendicular_at_t(lane, t, offset)
    local epsilon = 0.01
    local t1 = math.max(0, t - epsilon)
    local t2 = math.min(1, t + epsilon)
    
    local p1 = self:evaluate_curve(lane, t1)
    local p2 = self:evaluate_curve(lane, t2)
    
    local tangent = p2:subtract(p1):normalize()
    local perpendicular = Vector2:new(-tangent.y, tangent.x)
    
    return perpendicular:multiply(offset)
end
-- }}}

-- {{{ LaneSystem:smooth_path
function LaneSystem:smooth_path(sub_path)
    if #sub_path.waypoints < 3 then
        sub_path.center_line = {}
        for _, waypoint in ipairs(sub_path.waypoints) do
            table.insert(sub_path.center_line, waypoint:copy())
        end
        sub_path.metadata.smoothed = false
        return
    end
    
    local smoothed = {}
    local resolution = LaneSystem.SMOOTHING_RESOLUTION
    
    -- Use Catmull-Rom spline for smooth interpolation
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
    
    -- Add the final waypoint
    table.insert(smoothed, sub_path.waypoints[#sub_path.waypoints]:copy())
    
    sub_path.center_line = smoothed
    sub_path.metadata.smoothed = true
    
    -- Calculate path length
    local total_length = 0
    for i = 1, #sub_path.center_line - 1 do
        total_length = total_length + sub_path.center_line[i]:distance_to(sub_path.center_line[i + 1])
    end
    sub_path.metadata.length = total_length
    
    debug.log(string.format("Smoothed sub-path %d: %d points, length %.1f", 
              sub_path.id, #sub_path.center_line, sub_path.metadata.length), "LANE_SYSTEM")
end
-- }}}

-- {{{ LaneSystem:catmull_rom_spline
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
-- }}}

-- {{{ LaneSystem:get_position_on_sub_path
function LaneSystem:get_position_on_sub_path(sub_path, progress)
    progress = MathUtils.clamp(progress, 0, 1)
    
    if #sub_path.center_line < 2 then
        return sub_path.waypoints[1] or Vector2:new(0, 0)
    end
    
    local total_points = #sub_path.center_line
    local exact_index = progress * (total_points - 1) + 1
    local segment_index = math.floor(exact_index)
    local segment_progress = exact_index - segment_index
    
    segment_index = MathUtils.clamp(segment_index, 1, total_points - 1)
    
    local p1 = sub_path.center_line[segment_index]
    local p2 = sub_path.center_line[segment_index + 1]
    
    return p1:lerp(p2, segment_progress)
end
-- }}}

-- {{{ LaneSystem:get_direction_on_sub_path
function LaneSystem:get_direction_on_sub_path(sub_path, progress)
    progress = MathUtils.clamp(progress, 0, 1)
    
    if #sub_path.center_line < 2 then
        return Vector2:new(1, 0)  -- Default direction
    end
    
    local total_points = #sub_path.center_line
    local exact_index = progress * (total_points - 1) + 1
    local segment_index = math.floor(exact_index)
    
    segment_index = MathUtils.clamp(segment_index, 1, total_points - 1)
    
    local p1 = sub_path.center_line[segment_index]
    local p2 = sub_path.center_line[segment_index + 1]
    
    return p2:subtract(p1):normalize()
end
-- }}}

-- {{{ LaneSystem:find_nearest_sub_path
function LaneSystem:find_nearest_sub_path(lane, position)
    local nearest_sub_path = nil
    local min_distance = math.huge
    local nearest_progress = 0
    
    for _, sub_path in ipairs(lane.sub_paths) do
        local distance, progress = self:distance_to_sub_path(sub_path, position)
        
        if distance < min_distance then
            min_distance = distance
            nearest_sub_path = sub_path
            nearest_progress = progress
        end
    end
    
    return nearest_sub_path, min_distance, nearest_progress
end
-- }}}

-- {{{ LaneSystem:distance_to_sub_path
function LaneSystem:distance_to_sub_path(sub_path, position)
    local min_distance = math.huge
    local best_progress = 0
    
    -- Check distance to all points on the center line
    for i, point in ipairs(sub_path.center_line) do
        local distance = position:distance_to(point)
        if distance < min_distance then
            min_distance = distance
            best_progress = (i - 1) / (#sub_path.center_line - 1)
        end
    end
    
    return min_distance, best_progress
end
-- }}}

-- {{{ LaneSystem:get_sub_path_by_id
function LaneSystem:get_sub_path_by_id(lane, sub_path_id)
    if sub_path_id >= 1 and sub_path_id <= #lane.sub_paths then
        return lane.sub_paths[sub_path_id]
    end
    return nil
end
-- }}}

-- {{{ LaneSystem:get_available_sub_paths
function LaneSystem:get_available_sub_paths(lane, excluded_ids)
    excluded_ids = excluded_ids or {}
    local excluded_set = {}
    for _, id in ipairs(excluded_ids) do
        excluded_set[id] = true
    end
    
    local available = {}
    for _, sub_path in ipairs(lane.sub_paths) do
        if not excluded_set[sub_path.id] then
            table.insert(available, sub_path)
        end
    end
    
    return available
end
-- }}}

-- {{{ LaneSystem:calculate_formation_positions
function LaneSystem:calculate_formation_positions(lane, formation_type, unit_count, base_progress)
    base_progress = base_progress or 0
    formation_type = formation_type or "line"
    
    local positions = {}
    
    if formation_type == "line" then
        -- Spread units across multiple sub-paths at the same progress
        local sub_paths_needed = math.min(unit_count, #lane.sub_paths)
        local start_sub_path = math.max(1, math.floor((#lane.sub_paths - sub_paths_needed) / 2) + 1)
        
        for i = 1, unit_count do
            local sub_path_index = start_sub_path + ((i - 1) % sub_paths_needed)
            local sub_path = lane.sub_paths[sub_path_index]
            local position = self:get_position_on_sub_path(sub_path, base_progress)
            local direction = self:get_direction_on_sub_path(sub_path, base_progress)
            
            table.insert(positions, {
                position = position,
                direction = direction,
                sub_path_id = sub_path_index,
                progress = base_progress
            })
        end
        
    elseif formation_type == "column" then
        -- Single sub-path, units spread along it
        local center_sub_path = lane.sub_paths[3]  -- Use center sub-path
        local spacing = 0.05  -- 5% of path length between units
        
        for i = 1, unit_count do
            local progress = base_progress - (i - 1) * spacing
            progress = math.max(0, progress)
            
            local position = self:get_position_on_sub_path(center_sub_path, progress)
            local direction = self:get_direction_on_sub_path(center_sub_path, progress)
            
            table.insert(positions, {
                position = position,
                direction = direction,
                sub_path_id = 3,
                progress = progress
            })
        end
        
    elseif formation_type == "wedge" then
        -- V-formation using multiple sub-paths
        local center_sub_path = 3
        local positions_per_side = math.floor(unit_count / 2)
        
        -- Center unit
        if unit_count % 2 == 1 then
            local sub_path = lane.sub_paths[center_sub_path]
            local position = self:get_position_on_sub_path(sub_path, base_progress)
            local direction = self:get_direction_on_sub_path(sub_path, base_progress)
            
            table.insert(positions, {
                position = position,
                direction = direction,
                sub_path_id = center_sub_path,
                progress = base_progress
            })
        end
        
        -- Side units
        for i = 1, positions_per_side do
            local offset_progress = base_progress - i * 0.03
            
            -- Left side
            local left_sub_path = math.max(1, center_sub_path - i)
            if lane.sub_paths[left_sub_path] then
                local sub_path = lane.sub_paths[left_sub_path]
                local position = self:get_position_on_sub_path(sub_path, offset_progress)
                local direction = self:get_direction_on_sub_path(sub_path, offset_progress)
                
                table.insert(positions, {
                    position = position,
                    direction = direction,
                    sub_path_id = left_sub_path,
                    progress = offset_progress
                })
            end
            
            -- Right side
            local right_sub_path = math.min(#lane.sub_paths, center_sub_path + i)
            if lane.sub_paths[right_sub_path] then
                local sub_path = lane.sub_paths[right_sub_path]
                local position = self:get_position_on_sub_path(sub_path, offset_progress)
                local direction = self:get_direction_on_sub_path(sub_path, offset_progress)
                
                table.insert(positions, {
                    position = position,
                    direction = direction,
                    sub_path_id = right_sub_path,
                    progress = offset_progress
                })
            end
        end
    end
    
    return positions
end
-- }}}

-- {{{ LaneSystem:get_lane_stats
function LaneSystem:get_lane_stats(lane)
    local stats = {
        sub_path_count = #lane.sub_paths,
        total_length = lane.metadata.length,
        width = lane.width,
        has_curves = #lane.curve_points > 0,
        sub_paths = {}
    }
    
    for _, sub_path in ipairs(lane.sub_paths) do
        table.insert(stats.sub_paths, {
            id = sub_path.id,
            length = sub_path.metadata.length,
            waypoint_count = sub_path.metadata.point_count,
            center_line_points = #sub_path.center_line,
            smoothed = sub_path.metadata.smoothed
        })
    end
    
    return stats
end
-- }}}

return LaneSystem
-- }}}