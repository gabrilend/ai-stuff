-- {{{ CollisionSystem
local CollisionSystem = {}
local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")

-- {{{ CollisionSystem:new
function CollisionSystem:new()
    local system = {
        collision_layers = {
            units = {},
            boundaries = {},
            obstacles = {}
        },
        spatial_grid = {},
        grid_size = 50
    }
    return setmetatable(system, {__index = CollisionSystem})
end
-- }}}

-- {{{ CollisionSystem:add_lane_boundaries
function CollisionSystem:add_lane_boundaries(lane)
    for _, sub_path in ipairs(lane.sub_paths) do
        self:create_sub_path_boundaries(sub_path, lane)
    end
end
-- }}}

-- {{{ CollisionSystem:create_sub_path_boundaries
function CollisionSystem:create_sub_path_boundaries(sub_path, lane)
    if #sub_path.center_line < 2 then return end
    
    local boundaries = {
        left_boundary = {},
        right_boundary = {},
        sub_path_id = sub_path.id
    }
    
    local half_width = sub_path.width / 2
    
    for i = 1, #sub_path.center_line do
        local point = sub_path.center_line[i]
        local direction
        
        if i == 1 then
            direction = sub_path.center_line[2]:subtract(point):normalize()
        elseif i == #sub_path.center_line then
            direction = point:subtract(sub_path.center_line[i-1]):normalize()
        else
            local dir1 = point:subtract(sub_path.center_line[i-1]):normalize()
            local dir2 = sub_path.center_line[i+1]:subtract(point):normalize()
            direction = dir1:add(dir2):normalize()
        end
        
        local perpendicular = Vector2:new(-direction.y, direction.x)
        
        local left_point = point:add(perpendicular:multiply(half_width))
        local right_point = point:subtract(perpendicular:multiply(half_width))
        
        table.insert(boundaries.left_boundary, left_point)
        table.insert(boundaries.right_boundary, right_point)
    end
    
    -- Store boundaries for collision checking
    sub_path.boundaries = boundaries
    table.insert(self.collision_layers.boundaries, boundaries)
end
-- }}}

-- {{{ CollisionSystem:check_unit_in_bounds
function CollisionSystem:check_unit_in_bounds(unit, sub_path)
    if not sub_path.boundaries then
        return true  -- No boundaries defined
    end
    
    local unit_pos = unit.position
    local closest_segment = self:find_closest_boundary_segment(unit_pos, sub_path)
    
    if not closest_segment then
        return false
    end
    
    -- Check if unit is within the boundary corridor
    return self:point_in_boundary_corridor(unit_pos, closest_segment)
end
-- }}}

-- {{{ CollisionSystem:find_closest_boundary_segment
function CollisionSystem:find_closest_boundary_segment(position, sub_path)
    local min_distance = math.huge
    local closest_segment = nil
    
    local boundaries = sub_path.boundaries
    if not boundaries or #boundaries.left_boundary < 2 then
        return nil
    end
    
    for i = 1, #boundaries.left_boundary - 1 do
        -- Check distance to center line segment
        local center1 = sub_path.center_line[i]
        local center2 = sub_path.center_line[i + 1]
        
        local distance = self:point_to_line_distance(position, center1, center2)
        
        if distance < min_distance then
            min_distance = distance
            closest_segment = {
                index = i,
                left1 = boundaries.left_boundary[i],
                left2 = boundaries.left_boundary[i + 1],
                right1 = boundaries.right_boundary[i],
                right2 = boundaries.right_boundary[i + 1],
                center1 = center1,
                center2 = center2
            }
        end
    end
    
    return closest_segment
end
-- }}}

-- {{{ CollisionSystem:point_to_line_distance
function CollisionSystem:point_to_line_distance(point, line_start, line_end)
    local line_vec = line_end:subtract(line_start)
    local point_vec = point:subtract(line_start)
    
    local line_len = line_vec:length()
    if line_len == 0 then
        return point:distance_to(line_start)
    end
    
    local t = math.max(0, math.min(1, point_vec:dot(line_vec) / (line_len * line_len)))
    local projection = line_start:add(line_vec:multiply(t))
    
    return point:distance_to(projection)
end
-- }}}

-- {{{ CollisionSystem:point_in_boundary_corridor
function CollisionSystem:point_in_boundary_corridor(position, segment)
    -- Use cross products to determine which side of boundary lines the point is on
    local left_line = segment.left2:subtract(segment.left1)
    local left_to_point = position:subtract(segment.left1)
    local left_cross = left_line.x * left_to_point.y - left_line.y * left_to_point.x
    
    local right_line = segment.right2:subtract(segment.right1)
    local right_to_point = position:subtract(segment.right1)
    local right_cross = right_line.x * right_to_point.y - right_line.y * right_to_point.x
    
    -- Point should be on the right side of left boundary and left side of right boundary
    return left_cross <= 0 and right_cross >= 0
end
-- }}}

-- {{{ CollisionSystem:correct_unit_position
function CollisionSystem:correct_unit_position(unit, sub_path)
    local closest_segment = self:find_closest_boundary_segment(unit.position, sub_path)
    if not closest_segment then
        return unit.position
    end
    
    -- Find closest point on center line
    local center_line = closest_segment.center2:subtract(closest_segment.center1)
    local to_unit = unit.position:subtract(closest_segment.center1)
    
    local center_len = center_line:length()
    if center_len == 0 then
        return closest_segment.center1
    end
    
    local t = math.max(0, math.min(1, to_unit:dot(center_line) / (center_len * center_len)))
    local corrected_center = closest_segment.center1:add(center_line:multiply(t))
    
    -- Project unit position to stay within bounds
    local direction_to_unit = unit.position:subtract(corrected_center)
    local distance_to_unit = direction_to_unit:length()
    
    if distance_to_unit == 0 then
        return corrected_center
    end
    
    local max_distance = sub_path.width / 2 * 0.9  -- Stay slightly inside boundary
    if distance_to_unit > max_distance then
        direction_to_unit = direction_to_unit:normalize():multiply(max_distance)
    end
    
    return corrected_center:add(direction_to_unit)
end
-- }}}

-- {{{ CollisionSystem:get_available_positions_in_subpath
function CollisionSystem:get_available_positions_in_subpath(sub_path, preferred_position)
    -- Find valid positions for unit placement
    local available_positions = {}
    local sample_count = 10
    
    local closest_segment = self:find_closest_boundary_segment(preferred_position, sub_path)
    if not closest_segment then
        return available_positions
    end
    
    -- Sample positions across the width of the sub-path
    for i = 0, sample_count do
        local t = i / sample_count
        local test_position = closest_segment.right1:add(
            closest_segment.left1:subtract(closest_segment.right1):multiply(t)
        )
        
        if self:point_in_boundary_corridor(test_position, closest_segment) then
            table.insert(available_positions, {
                position = test_position,
                distance_to_preferred = test_position:distance_to(preferred_position)
            })
        end
    end
    
    -- Sort by distance to preferred position
    table.sort(available_positions, function(a, b)
        return a.distance_to_preferred < b.distance_to_preferred
    end)
    
    return available_positions
end
-- }}}

-- {{{ CollisionSystem:draw_boundaries
function CollisionSystem:draw_boundaries(renderer, sub_path)
    if not sub_path.boundaries then return end
    
    local boundary_color = {0.5, 0.5, 0.5, 0.3}  -- Semi-transparent gray
    local boundaries = sub_path.boundaries
    
    -- Draw left boundary
    for i = 1, #boundaries.left_boundary - 1 do
        local p1 = boundaries.left_boundary[i]
        local p2 = boundaries.left_boundary[i + 1]
        renderer:draw_line(p1.x, p1.y, p2.x, p2.y, boundary_color, 1)
    end
    
    -- Draw right boundary  
    for i = 1, #boundaries.right_boundary - 1 do
        local p1 = boundaries.right_boundary[i]
        local p2 = boundaries.right_boundary[i + 1]
        renderer:draw_line(p1.x, p1.y, p2.x, p2.y, boundary_color, 1)
    end
end
-- }}}

return CollisionSystem
-- }}}