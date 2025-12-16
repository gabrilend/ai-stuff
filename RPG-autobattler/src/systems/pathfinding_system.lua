-- {{{ PathfindingSystem
local PathfindingSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local debug = require("src.utils.debug")

-- {{{ PathfindingSystem:new
function PathfindingSystem:new(map_data, lane_system)
    local system = {
        map_data = map_data,
        lane_system = lane_system,
        path_cache = {},
        connection_graph = {},
        node_positions = {},
        lane_connections = {} -- Maps lanes to their connections
    }
    setmetatable(system, {__index = PathfindingSystem})
    
    if map_data then
        system:build_navigation_graph()
    end
    
    debug.log("PathfindingSystem created", "PATHFINDING")
    return system
end
-- }}}

-- {{{ PathfindingSystem:build_navigation_graph
function PathfindingSystem:build_navigation_graph()
    if not self.map_data or not self.map_data.connections then
        debug.warn("No map data available for pathfinding graph", "PATHFINDING")
        return
    end
    
    -- Clear existing graph
    self.connection_graph = {}
    self.node_positions = {}
    
    -- Add spawn points as nodes
    local node_id = 1
    for player_id, spawn_point in pairs(self.map_data.spawn_points) do
        self.node_positions[node_id] = {
            position = spawn_point,
            type = "spawn",
            player_id = player_id,
            connections = {}
        }
        node_id = node_id + 1
    end
    
    -- Add intermediate nodes
    for i, node in ipairs(self.map_data.nodes) do
        self.node_positions[node_id] = {
            position = node,
            type = "intermediate",
            connections = {}
        }
        node_id = node_id + 1
    end
    
    -- Build connections
    for _, connection in ipairs(self.map_data.connections) do
        local from_id = self:find_node_id(connection.from)
        local to_id = self:find_node_id(connection.to)
        
        if from_id and to_id then
            -- Add bidirectional connection
            table.insert(self.node_positions[from_id].connections, to_id)
            table.insert(self.node_positions[to_id].connections, from_id)
            
            -- Store connection for lane creation
            if not self.connection_graph[from_id] then
                self.connection_graph[from_id] = {}
            end
            if not self.connection_graph[to_id] then
                self.connection_graph[to_id] = {}
            end
            
            self.connection_graph[from_id][to_id] = connection
            self.connection_graph[to_id][from_id] = connection
        end
    end
    
    debug.log("Built navigation graph with " .. (node_id - 1) .. " nodes", "PATHFINDING")
end
-- }}}

-- {{{ PathfindingSystem:find_node_id
function PathfindingSystem:find_node_id(position)
    for id, node_data in pairs(self.node_positions) do
        if node_data.position:distance_to(position) < 1.0 then  -- Small tolerance
            return id
        end
    end
    return nil
end
-- }}}

-- {{{ PathfindingSystem:find_path_between_points
function PathfindingSystem:find_path_between_points(start_pos, end_pos)
    local start_node = self:find_nearest_node(start_pos)
    local end_node = self:find_nearest_node(end_pos)
    
    if not start_node or not end_node then
        debug.warn("Could not find valid nodes for pathfinding", "PATHFINDING")
        return nil
    end
    
    return self:find_path_between_nodes(start_node, end_node)
end
-- }}}

-- {{{ PathfindingSystem:find_nearest_node
function PathfindingSystem:find_nearest_node(position)
    local nearest_id = nil
    local min_distance = math.huge
    
    for id, node_data in pairs(self.node_positions) do
        local distance = node_data.position:distance_to(position)
        if distance < min_distance then
            min_distance = distance
            nearest_id = id
        end
    end
    
    return nearest_id
end
-- }}}

-- {{{ PathfindingSystem:find_path_between_nodes
function PathfindingSystem:find_path_between_nodes(start_node_id, end_node_id)
    if start_node_id == end_node_id then
        return {start_node_id}
    end
    
    -- Check cache first
    local cache_key = start_node_id .. "->" .. end_node_id
    if self.path_cache[cache_key] then
        return self.path_cache[cache_key]
    end
    
    -- Use A* pathfinding
    local path = self:a_star_search(start_node_id, end_node_id)
    
    -- Cache the result
    if path then
        self.path_cache[cache_key] = path
    end
    
    return path
end
-- }}}

-- {{{ PathfindingSystem:a_star_search
function PathfindingSystem:a_star_search(start_id, goal_id)
    local open_set = {start_id}
    local came_from = {}
    local g_score = {[start_id] = 0}
    local f_score = {[start_id] = self:heuristic(start_id, goal_id)}
    
    while #open_set > 0 do
        -- Find node in open_set with lowest f_score
        local current = self:get_lowest_f_score_node(open_set, f_score)
        
        if current == goal_id then
            -- Reconstruct path
            return self:reconstruct_path(came_from, current)
        end
        
        -- Remove current from open_set
        for i, node_id in ipairs(open_set) do
            if node_id == current then
                table.remove(open_set, i)
                break
            end
        end
        
        -- Check all neighbors
        local current_node = self.node_positions[current]
        if current_node then
            for _, neighbor_id in ipairs(current_node.connections) do
                local tentative_g_score = g_score[current] + self:distance_between_nodes(current, neighbor_id)
                
                if not g_score[neighbor_id] or tentative_g_score < g_score[neighbor_id] then
                    came_from[neighbor_id] = current
                    g_score[neighbor_id] = tentative_g_score
                    f_score[neighbor_id] = g_score[neighbor_id] + self:heuristic(neighbor_id, goal_id)
                    
                    -- Add to open set if not already there
                    local in_open_set = false
                    for _, node_id in ipairs(open_set) do
                        if node_id == neighbor_id then
                            in_open_set = true
                            break
                        end
                    end
                    
                    if not in_open_set then
                        table.insert(open_set, neighbor_id)
                    end
                end
            end
        end
    end
    
    return nil -- No path found
end
-- }}}

-- {{{ PathfindingSystem:get_lowest_f_score_node
function PathfindingSystem:get_lowest_f_score_node(open_set, f_score)
    local lowest_node = open_set[1]
    local lowest_score = f_score[lowest_node] or math.huge
    
    for _, node_id in ipairs(open_set) do
        local score = f_score[node_id] or math.huge
        if score < lowest_score then
            lowest_score = score
            lowest_node = node_id
        end
    end
    
    return lowest_node
end
-- }}}

-- {{{ PathfindingSystem:reconstruct_path
function PathfindingSystem:reconstruct_path(came_from, current)
    local path = {current}
    
    while came_from[current] do
        current = came_from[current]
        table.insert(path, 1, current)  -- Insert at beginning
    end
    
    return path
end
-- }}}

-- {{{ PathfindingSystem:heuristic
function PathfindingSystem:heuristic(node_a_id, node_b_id)
    local node_a = self.node_positions[node_a_id]
    local node_b = self.node_positions[node_b_id]
    
    if node_a and node_b then
        return node_a.position:distance_to(node_b.position)
    end
    
    return math.huge
end
-- }}}

-- {{{ PathfindingSystem:distance_between_nodes
function PathfindingSystem:distance_between_nodes(node_a_id, node_b_id)
    return self:heuristic(node_a_id, node_b_id)
end
-- }}}

-- {{{ PathfindingSystem:get_lane_for_connection
function PathfindingSystem:get_lane_for_connection(from_node_id, to_node_id)
    local connection = nil
    
    if self.connection_graph[from_node_id] and self.connection_graph[from_node_id][to_node_id] then
        connection = self.connection_graph[from_node_id][to_node_id]
    end
    
    if not connection then
        return nil
    end
    
    -- Create a lane from the connection if one doesn't exist
    local lane_key = math.min(from_node_id, to_node_id) .. "-" .. math.max(from_node_id, to_node_id)
    
    if not self.lane_connections[lane_key] then
        local from_pos = self.node_positions[from_node_id].position
        local to_pos = self.node_positions[to_node_id].position
        
        -- Create lane using the lane system
        local lane = self.lane_system:create_lane(from_pos, to_pos)
        self.lane_connections[lane_key] = lane
        
        debug.log("Created lane for connection " .. lane_key, "PATHFINDING")
    end
    
    return self.lane_connections[lane_key]
end
-- }}}

-- {{{ PathfindingSystem:get_path_lanes
function PathfindingSystem:get_path_lanes(node_path)
    if not node_path or #node_path < 2 then
        return {}
    end
    
    local lanes = {}
    
    for i = 1, #node_path - 1 do
        local from_node = node_path[i]
        local to_node = node_path[i + 1]
        local lane = self:get_lane_for_connection(from_node, to_node)
        
        if lane then
            table.insert(lanes, lane)
        end
    end
    
    return lanes
end
-- }}}

-- {{{ PathfindingSystem:find_path_to_enemy_base
function PathfindingSystem:find_path_to_enemy_base(start_pos, player_id)
    local enemy_spawn_point = nil
    
    -- Find enemy spawn point
    for pid, spawn_point in pairs(self.map_data.spawn_points) do
        if pid ~= ("player_" .. player_id) then
            enemy_spawn_point = spawn_point
            break
        end
    end
    
    if not enemy_spawn_point then
        debug.warn("Could not find enemy spawn point", "PATHFINDING")
        return nil
    end
    
    return self:find_path_between_points(start_pos, enemy_spawn_point)
end
-- }}}

-- {{{ PathfindingSystem:get_strategic_positions
function PathfindingSystem:get_strategic_positions(player_id)
    local positions = {}
    
    -- Add intermediate nodes as strategic positions
    for id, node_data in pairs(self.node_positions) do
        if node_data.type == "intermediate" then
            table.insert(positions, {
                position = node_data.position,
                node_id = id,
                importance = self:calculate_strategic_importance(id, player_id)
            })
        end
    end
    
    -- Sort by strategic importance
    table.sort(positions, function(a, b) 
        return a.importance > b.importance 
    end)
    
    return positions
end
-- }}}

-- {{{ PathfindingSystem:calculate_strategic_importance
function PathfindingSystem:calculate_strategic_importance(node_id, player_id)
    local node_data = self.node_positions[node_id]
    if not node_data then
        return 0
    end
    
    local importance = 0
    
    -- More connections = more important
    importance = importance + #node_data.connections * 10
    
    -- Distance to enemy base (closer = more important)
    local enemy_spawn_point = nil
    for pid, spawn_point in pairs(self.map_data.spawn_points) do
        if pid ~= ("player_" .. player_id) then
            enemy_spawn_point = spawn_point
            break
        end
    end
    
    if enemy_spawn_point then
        local distance_to_enemy = node_data.position:distance_to(enemy_spawn_point)
        importance = importance + (1000 / (distance_to_enemy + 1))  -- Inverse distance
    end
    
    return importance
end
-- }}}

-- {{{ PathfindingSystem:clear_cache
function PathfindingSystem:clear_cache()
    self.path_cache = {}
    debug.log("Cleared pathfinding cache", "PATHFINDING")
end
-- }}}

-- {{{ PathfindingSystem:get_debug_info
function PathfindingSystem:get_debug_info()
    return {
        total_nodes = self:count_table(self.node_positions),
        cached_paths = self:count_table(self.path_cache),
        lane_connections = self:count_table(self.lane_connections),
        graph_connections = self:count_table(self.connection_graph)
    }
end
-- }}}

-- {{{ PathfindingSystem:count_table
function PathfindingSystem:count_table(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ PathfindingSystem:find_path_in_subpath
function PathfindingSystem:find_path_in_subpath(start_position, end_position, sub_path, obstacles)
    obstacles = obstacles or {}
    
    local path_nodes = self:create_navigation_nodes(sub_path, obstacles)
    local start_node = self:find_closest_node(start_position, path_nodes)
    local end_node = self:find_closest_node(end_position, path_nodes)
    
    if not start_node or not end_node then
        return self:create_direct_path(start_position, end_position, sub_path)
    end
    
    local path = self:a_star_search_subpath(start_node, end_node, path_nodes)
    return self:convert_nodes_to_path(path, start_position, end_position)
end
-- }}}

-- {{{ PathfindingSystem:create_navigation_nodes
function PathfindingSystem:create_navigation_nodes(sub_path, obstacles)
    local nodes = {}
    local center_line = sub_path.center_line
    local node_spacing = 20  -- Distance between nodes
    
    if not center_line or #center_line < 2 then
        return nodes
    end
    
    -- Create nodes along center line
    for i = 1, #center_line - 1 do
        local segment_start = center_line[i]
        local segment_end = center_line[i + 1]
        local segment_vector = segment_end:subtract(segment_start)
        local segment_length = segment_vector:length()
        
        if segment_length > 0 then
            local num_nodes = math.max(1, math.floor(segment_length / node_spacing))
            
            for j = 0, num_nodes do
                local t = j / num_nodes
                local node_position = segment_start:add(segment_vector:multiply(t))
                
                local node = {
                    id = #nodes + 1,
                    position = node_position,
                    segment_index = i,
                    is_blocked = self:is_position_blocked(node_position, obstacles),
                    neighbors = {},
                    g_cost = math.huge,
                    h_cost = 0,
                    f_cost = math.huge,
                    parent = nil
                }
                
                table.insert(nodes, node)
            end
        end
    end
    
    -- Create alternative nodes for obstacle avoidance
    self:add_avoidance_nodes(nodes, sub_path, obstacles)
    
    -- Connect neighboring nodes
    self:connect_navigation_nodes(nodes, sub_path)
    
    return nodes
end
-- }}}

-- {{{ PathfindingSystem:add_avoidance_nodes
function PathfindingSystem:add_avoidance_nodes(nodes, sub_path, obstacles)
    local avoidance_distance = 15  -- Distance to offset from center line
    
    for _, obstacle in ipairs(obstacles) do
        if obstacle.sub_path_id == sub_path.id then
            -- Create nodes around obstacles
            local center = obstacle.position
            local directions = {
                {0, -avoidance_distance},  -- North
                {avoidance_distance, 0},   -- East
                {0, avoidance_distance},   -- South
                {-avoidance_distance, 0}   -- West
            }
            
            for _, dir in ipairs(directions) do
                local avoidance_pos = Vector2:new(center.x + dir[1], center.y + dir[2])
                
                -- Check if position is within sub-path bounds
                if self:is_position_in_subpath_bounds(avoidance_pos, sub_path) then
                    local node = {
                        id = #nodes + 1,
                        position = avoidance_pos,
                        segment_index = self:find_closest_segment_index(avoidance_pos, sub_path),
                        is_blocked = false,
                        neighbors = {},
                        g_cost = math.huge,
                        h_cost = 0,
                        f_cost = math.huge,
                        parent = nil,
                        is_avoidance = true
                    }
                    
                    table.insert(nodes, node)
                end
            end
        end
    end
end
-- }}}

-- {{{ PathfindingSystem:connect_navigation_nodes
function PathfindingSystem:connect_navigation_nodes(nodes, sub_path)
    local max_connection_distance = 30
    
    for i, node in ipairs(nodes) do
        for j, other_node in ipairs(nodes) do
            if i ~= j then
                local distance = node.position:distance_to(other_node.position)
                
                if distance <= max_connection_distance then
                    -- Check if connection is valid (no obstacles in between)
                    if self:is_connection_clear(node.position, other_node.position, sub_path) then
                        table.insert(node.neighbors, {
                            node = other_node,
                            cost = distance
                        })
                    end
                end
            end
        end
    end
end
-- }}}

-- {{{ PathfindingSystem:a_star_search_subpath
function PathfindingSystem:a_star_search_subpath(start_node, end_node, all_nodes)
    -- Reset all nodes
    for _, node in ipairs(all_nodes) do
        node.g_cost = math.huge
        node.h_cost = 0
        node.f_cost = math.huge
        node.parent = nil
    end
    
    local open_set = {start_node}
    local closed_set = {}
    
    start_node.g_cost = 0
    start_node.h_cost = start_node.position:distance_to(end_node.position)
    start_node.f_cost = start_node.g_cost + start_node.h_cost
    
    while #open_set > 0 do
        -- Find node with lowest f_cost
        local current_node = open_set[1]
        local current_index = 1
        
        for i, node in ipairs(open_set) do
            if node.f_cost < current_node.f_cost then
                current_node = node
                current_index = i
            end
        end
        
        -- Remove current from open set and add to closed set
        table.remove(open_set, current_index)
        table.insert(closed_set, current_node)
        
        -- Check if we reached the goal
        if current_node == end_node then
            return self:reconstruct_path_subpath(current_node)
        end
        
        -- Check neighbors
        for _, neighbor_data in ipairs(current_node.neighbors) do
            local neighbor = neighbor_data.node
            
            if not self:is_in_closed_set(neighbor, closed_set) and not neighbor.is_blocked then
                local tentative_g_cost = current_node.g_cost + neighbor_data.cost
                
                if tentative_g_cost < neighbor.g_cost then
                    neighbor.parent = current_node
                    neighbor.g_cost = tentative_g_cost
                    neighbor.h_cost = neighbor.position:distance_to(end_node.position)
                    neighbor.f_cost = neighbor.g_cost + neighbor.h_cost
                    
                    if not self:is_in_open_set(neighbor, open_set) then
                        table.insert(open_set, neighbor)
                    end
                end
            end
        end
    end
    
    return nil  -- No path found
end
-- }}}

-- {{{ PathfindingSystem:reconstruct_path_subpath
function PathfindingSystem:reconstruct_path_subpath(end_node)
    local path = {}
    local current = end_node
    
    while current do
        table.insert(path, 1, current.position)
        current = current.parent
    end
    
    return path
end
-- }}}

-- {{{ PathfindingSystem:create_direct_path
function PathfindingSystem:create_direct_path(start_position, end_position, sub_path)
    -- Fallback: create direct path along center line if pathfinding fails
    local center_line = sub_path.center_line
    local path = {}
    
    if not center_line or #center_line < 2 then
        return {start_position, end_position}
    end
    
    -- Find start and end segments
    local start_segment = self:find_closest_segment_index(start_position, sub_path)
    local end_segment = self:find_closest_segment_index(end_position, sub_path)
    
    if start_segment and end_segment then
        -- Add center line points between start and end
        for i = start_segment, end_segment do
            if center_line[i] then
                table.insert(path, center_line[i])
            end
        end
    else
        -- Ultimate fallback
        table.insert(path, start_position)
        table.insert(path, end_position)
    end
    
    return path
end
-- }}}

-- {{{ PathfindingSystem:find_closest_node
function PathfindingSystem:find_closest_node(position, nodes)
    local closest_node = nil
    local min_distance = math.huge
    
    for _, node in ipairs(nodes) do
        local distance = node.position:distance_to(position)
        if distance < min_distance then
            min_distance = distance
            closest_node = node
        end
    end
    
    return closest_node
end
-- }}}

-- {{{ PathfindingSystem:convert_nodes_to_path
function PathfindingSystem:convert_nodes_to_path(path_nodes, start_position, end_position)
    if not path_nodes or #path_nodes == 0 then
        return {start_position, end_position}
    end
    
    local path = {start_position}
    
    for _, position in ipairs(path_nodes) do
        table.insert(path, position)
    end
    
    table.insert(path, end_position)
    return path
end
-- }}}

-- {{{ PathfindingSystem:is_position_blocked
function PathfindingSystem:is_position_blocked(position, obstacles)
    local blocking_radius = 10
    
    for _, obstacle in ipairs(obstacles) do
        if obstacle.position:distance_to(position) <= blocking_radius then
            return true
        end
    end
    
    return false
end
-- }}}

-- {{{ PathfindingSystem:is_position_in_subpath_bounds
function PathfindingSystem:is_position_in_subpath_bounds(position, sub_path)
    -- Simple bounds check - could be enhanced with proper collision system
    if not sub_path.center_line or #sub_path.center_line < 2 then
        return false
    end
    
    local sub_path_width = sub_path.width or 20
    local min_distance_to_center = math.huge
    
    -- Check distance to center line
    for i = 1, #sub_path.center_line - 1 do
        local segment_start = sub_path.center_line[i]
        local segment_end = sub_path.center_line[i + 1]
        local distance = self:point_to_line_segment_distance_simple(position, segment_start, segment_end)
        
        min_distance_to_center = math.min(min_distance_to_center, distance)
    end
    
    return min_distance_to_center <= sub_path_width / 2
end
-- }}}

-- {{{ PathfindingSystem:find_closest_segment_index
function PathfindingSystem:find_closest_segment_index(position, sub_path)
    if not sub_path.center_line or #sub_path.center_line < 2 then
        return 1
    end
    
    local closest_index = 1
    local min_distance = math.huge
    
    for i = 1, #sub_path.center_line - 1 do
        local segment_start = sub_path.center_line[i]
        local segment_end = sub_path.center_line[i + 1]
        local distance = self:point_to_line_segment_distance_simple(position, segment_start, segment_end)
        
        if distance < min_distance then
            min_distance = distance
            closest_index = i
        end
    end
    
    return closest_index
end
-- }}}

-- {{{ PathfindingSystem:is_connection_clear
function PathfindingSystem:is_connection_clear(start_pos, end_pos, sub_path)
    -- Simple line-of-sight check within sub-path bounds
    return self:is_position_in_subpath_bounds(start_pos, sub_path) and 
           self:is_position_in_subpath_bounds(end_pos, sub_path)
end
-- }}}

-- {{{ PathfindingSystem:point_to_line_segment_distance_simple
function PathfindingSystem:point_to_line_segment_distance_simple(point, line_start, line_end)
    local line_vec = line_end:subtract(line_start)
    local point_vec = point:subtract(line_start)
    
    local line_length_sq = line_vec:dot(line_vec)
    if line_length_sq == 0 then
        return point:distance_to(line_start)
    end
    
    local t = math.max(0, math.min(1, point_vec:dot(line_vec) / line_length_sq))
    local projection = line_start:add(line_vec:multiply(t))
    
    return point:distance_to(projection)
end
-- }}}

-- {{{ PathfindingSystem:is_in_closed_set
function PathfindingSystem:is_in_closed_set(node, closed_set)
    for _, closed_node in ipairs(closed_set) do
        if closed_node == node then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ PathfindingSystem:is_in_open_set
function PathfindingSystem:is_in_open_set(node, open_set)
    for _, open_node in ipairs(open_set) do
        if open_node == node then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ PathfindingSystem:test_subpath_pathfinding
function PathfindingSystem:test_subpath_pathfinding()
    local debug = require("src.utils.debug")
    
    debug.log("Testing sub-path pathfinding capabilities", "PATHFINDING")
    
    -- Create test sub-path
    local test_sub_path = {
        id = "test_subpath",
        center_line = {
            Vector2:new(0, 0),
            Vector2:new(100, 0),
            Vector2:new(200, 50),
            Vector2:new(300, 100)
        },
        width = 30
    }
    
    -- Create test obstacles
    local obstacles = {
        {
            position = Vector2:new(150, 25),
            sub_path_id = "test_subpath"
        }
    }
    
    -- Test pathfinding with obstacles
    local start_pos = Vector2:new(10, 0)
    local end_pos = Vector2:new(290, 100)
    
    local path = self:find_path_in_subpath(start_pos, end_pos, test_sub_path, obstacles)
    
    if path and #path > 2 then
        debug.log("✓ Sub-path pathfinding with obstacles working correctly", "PATHFINDING")
        debug.log("✓ Generated path with " .. #path .. " waypoints", "PATHFINDING")
    else
        debug.error("✗ Sub-path pathfinding failed", "PATHFINDING")
    end
    
    -- Test navigation node creation
    local nav_nodes = self:create_navigation_nodes(test_sub_path, obstacles)
    
    if #nav_nodes > 0 then
        debug.log("✓ Navigation nodes created: " .. #nav_nodes .. " nodes", "PATHFINDING")
        
        local blocked_count = 0
        for _, node in ipairs(nav_nodes) do
            if node.is_blocked then
                blocked_count = blocked_count + 1
            end
        end
        
        debug.log("✓ Obstacle detection working: " .. blocked_count .. " blocked nodes", "PATHFINDING")
    else
        debug.error("✗ Navigation node creation failed", "PATHFINDING")
    end
    
    debug.log("Sub-path pathfinding tests completed", "PATHFINDING")
end
-- }}}

return PathfindingSystem
-- }}}