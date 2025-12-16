-- {{{ Map Generator for procedural pathway networks
local MapGenerator = {}

local Vector2 = require("src.utils.vector2")
local debug = require("src.utils.debug")

-- {{{ MapGenerator:generate_map
function MapGenerator:generate_map(width, height, complexity, seed)
    width = width or 1024
    height = height or 768
    complexity = complexity or 1.0  -- 0.0 to 2.0
    
    -- Set random seed for reproducible maps
    if seed then
        math.randomseed(seed)
        debug.log("Generating map with seed: " .. seed, "MAP_GEN")
    end
    
    local map = {
        width = width,
        height = height,
        complexity = complexity,
        seed = seed,
        nodes = {},
        connections = {},
        spawn_points = {},
        paths = {},
        metadata = {
            generation_time = 0,
            node_count = 0,
            connection_count = 0,
            path_count = 0
        }
    }
    
    local start_time = os.clock()
    
    -- Step 1: Place base spawn points
    self:place_spawn_points(map)
    
    -- Step 2: Generate intermediate nodes
    self:generate_intermediate_nodes(map, complexity)
    
    -- Step 3: Create connections between nodes
    self:generate_connections(map)
    
    -- Step 4: Ensure connectivity between bases
    self:ensure_base_connectivity(map)
    
    -- Step 4.5: Ensure all intermediate nodes are connected
    self:ensure_all_nodes_connected(map)
    
    -- Step 5: Generate actual path geometry with curves
    self:generate_path_geometry(map)
    
    -- Step 6: Add metadata
    map.metadata.generation_time = os.clock() - start_time
    map.metadata.node_count = #map.nodes + 2  -- +2 for spawn points
    map.metadata.connection_count = #map.connections
    map.metadata.path_count = #map.paths
    
    debug.log(string.format("Map generated: %d nodes, %d connections, %.3fs", 
              map.metadata.node_count, map.metadata.connection_count, map.metadata.generation_time), "MAP_GEN")
    
    return map
end
-- }}}

-- {{{ MapGenerator:place_spawn_points
function MapGenerator:place_spawn_points(map)
    -- Place bases on opposite sides with some vertical variation
    local margin = math.min(map.width, map.height) * 0.1
    local vertical_variation = map.height * 0.3
    
    local base_a_y = map.height * 0.5 + (math.random() - 0.5) * vertical_variation
    local base_b_y = map.height * 0.5 + (math.random() - 0.5) * vertical_variation
    
    map.spawn_points = {
        player_1 = Vector2:new(margin, base_a_y),
        player_2 = Vector2:new(map.width - margin, base_b_y)
    }
    
    debug.log("Spawn points placed", "MAP_GEN")
end
-- }}}

-- {{{ MapGenerator:generate_intermediate_nodes
function MapGenerator:generate_intermediate_nodes(map, complexity)
    local base_node_count = 8
    local complexity_nodes = math.floor(complexity * 12)
    local node_count = base_node_count + complexity_nodes
    
    local min_distance = math.min(map.width, map.height) * 0.08  -- Minimum spacing
    local safe_zone = math.min(map.width, map.height) * 0.12    -- Distance from spawn points
    
    local placed_nodes = 0
    local max_attempts = node_count * 10
    local attempts = 0
    
    while placed_nodes < node_count and attempts < max_attempts do
        attempts = attempts + 1
        
        -- Generate candidate position
        local margin = map.width * 0.15
        local x = margin + math.random() * (map.width - 2 * margin)
        local y = margin + math.random() * (map.height - 2 * margin)
        local candidate = Vector2:new(x, y)
        
        if self:is_valid_node_position(map, candidate, min_distance, safe_zone) then
            table.insert(map.nodes, candidate)
            placed_nodes = placed_nodes + 1
        end
    end
    
    debug.log(string.format("Placed %d intermediate nodes (%d attempts)", placed_nodes, attempts), "MAP_GEN")
end
-- }}}

-- {{{ MapGenerator:is_valid_node_position
function MapGenerator:is_valid_node_position(map, candidate, min_distance, safe_zone)
    -- Check distance from spawn points
    if candidate:distance_to(map.spawn_points.player_1) < safe_zone then
        return false
    end
    if candidate:distance_to(map.spawn_points.player_2) < safe_zone then
        return false
    end
    
    -- Check distance from existing nodes
    for _, existing_node in ipairs(map.nodes) do
        if candidate:distance_to(existing_node) < min_distance then
            return false
        end
    end
    
    return true
end
-- }}}

-- {{{ MapGenerator:generate_connections
function MapGenerator:generate_connections(map)
    -- Collect all nodes (spawn points + intermediate nodes)
    local all_nodes = {
        {node = map.spawn_points.player_1, type = "spawn"},
        {node = map.spawn_points.player_2, type = "spawn"}
    }
    
    for _, node in ipairs(map.nodes) do
        table.insert(all_nodes, {node = node, type = "intermediate"})
    end
    
    -- Generate connections using distance-based probability
    for i, node_a in ipairs(all_nodes) do
        local target_connections = self:get_target_connections(node_a.type, map.complexity)
        local connections_made = 0
        
        -- Create list of potential connections sorted by distance
        local candidates = {}
        for j, node_b in ipairs(all_nodes) do
            if i ~= j then
                local distance = node_a.node:distance_to(node_b.node)
                local max_distance = math.min(map.width, map.height) * 0.4
                
                if distance < max_distance then
                    table.insert(candidates, {
                        node = node_b,
                        distance = distance,
                        index = j
                    })
                end
            end
        end
        
        -- Sort by distance (closest first)
        table.sort(candidates, function(a, b) return a.distance < b.distance end)
        
        -- Connect to nearest nodes with probability
        for _, candidate in ipairs(candidates) do
            if connections_made >= target_connections then
                break
            end
            
            local connection_probability = self:calculate_connection_probability(
                candidate.distance, node_a.type, candidate.node.type, map.complexity
            )
            
            if math.random() < connection_probability then
                if not self:connection_exists(map, node_a.node, candidate.node.node) then
                    self:add_connection(map, node_a.node, candidate.node.node)
                    connections_made = connections_made + 1
                end
            end
        end
    end
    
    debug.log(string.format("Generated %d initial connections", #map.connections), "MAP_GEN")
end
-- }}}

-- {{{ MapGenerator:get_target_connections
function MapGenerator:get_target_connections(node_type, complexity)
    if node_type == "spawn" then
        return math.floor(2 + complexity * 2)  -- 2-4 connections for spawn points
    else
        return math.floor(1 + complexity * 3)  -- 1-4 connections for intermediate nodes
    end
end
-- }}}

-- {{{ MapGenerator:calculate_connection_probability
function MapGenerator:calculate_connection_probability(distance, type_a, type_b, complexity)
    local base_probability = 0.3 + complexity * 0.2
    
    -- Closer nodes are more likely to connect
    local max_distance = 300
    local distance_factor = 1.0 - (distance / max_distance)
    distance_factor = math.max(0.1, distance_factor)
    
    -- Spawn points are more likely to connect
    local type_factor = 1.0
    if type_a == "spawn" or type_b == "spawn" then
        type_factor = 1.5
    end
    
    return base_probability * distance_factor * type_factor
end
-- }}}

-- {{{ MapGenerator:connection_exists
function MapGenerator:connection_exists(map, node_a, node_b)
    for _, connection in ipairs(map.connections) do
        if (connection.from == node_a and connection.to == node_b) or
           (connection.from == node_b and connection.to == node_a) then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ MapGenerator:add_connection
function MapGenerator:add_connection(map, node_a, node_b)
    local connection = {
        from = node_a,
        to = node_b,
        id = #map.connections + 1,
        bidirectional = true
    }
    
    table.insert(map.connections, connection)
end
-- }}}

-- {{{ MapGenerator:ensure_base_connectivity
function MapGenerator:ensure_base_connectivity(map)
    local path = self:find_path(map.spawn_points.player_1, map.spawn_points.player_2, map.connections)
    
    if not path then
        debug.log("No path found between bases, creating forced connections", "MAP_GEN")
        self:create_forced_path(map)
        
        -- Verify connectivity after forced path
        path = self:find_path(map.spawn_points.player_1, map.spawn_points.player_2, map.connections)
        if not path then
            debug.error("Failed to create connectivity between bases", "MAP_GEN")
        else
            debug.log("Forced connectivity established", "MAP_GEN")
        end
    else
        debug.log("Bases are connected via " .. #path .. " nodes", "MAP_GEN")
    end
end
-- }}}

-- {{{ MapGenerator:find_path
function MapGenerator:find_path(start, goal, connections)
    local visited = {}
    local queue = {{node = start, path = {start}}}
    
    while #queue > 0 do
        local current = table.remove(queue, 1)
        
        if current.node == goal then
            return current.path
        end
        
        local node_id = tostring(current.node.x) .. "," .. tostring(current.node.y)
        if not visited[node_id] then
            visited[node_id] = true
            
            for _, connection in ipairs(connections) do
                local next_node = nil
                if connection.from == current.node then
                    next_node = connection.to
                elseif connection.to == current.node then
                    next_node = connection.from
                end
                
                if next_node then
                    local next_id = tostring(next_node.x) .. "," .. tostring(next_node.y)
                    if not visited[next_id] then
                        local new_path = {}
                        for _, node in ipairs(current.path) do
                            table.insert(new_path, node)
                        end
                        table.insert(new_path, next_node)
                        table.insert(queue, {node = next_node, path = new_path})
                    end
                end
            end
        end
    end
    
    return nil
end
-- }}}

-- {{{ MapGenerator:create_forced_path
function MapGenerator:create_forced_path(map)
    -- Find the closest intermediate nodes to each spawn point
    local closest_to_p1 = self:find_closest_node(map.spawn_points.player_1, map.nodes)
    local closest_to_p2 = self:find_closest_node(map.spawn_points.player_2, map.nodes)
    
    if closest_to_p1 then
        self:add_connection(map, map.spawn_points.player_1, closest_to_p1)
    end
    
    if closest_to_p2 then
        self:add_connection(map, map.spawn_points.player_2, closest_to_p2)
    end
    
    -- If we have both intermediate nodes, connect them
    if closest_to_p1 and closest_to_p2 and closest_to_p1 ~= closest_to_p2 then
        self:add_connection(map, closest_to_p1, closest_to_p2)
    end
    
    -- If no intermediate nodes exist, create direct connection
    if not closest_to_p1 and not closest_to_p2 then
        self:add_connection(map, map.spawn_points.player_1, map.spawn_points.player_2)
    end
end
-- }}}

-- {{{ MapGenerator:find_closest_node
function MapGenerator:find_closest_node(target, nodes)
    local closest = nil
    local min_distance = math.huge
    
    for _, node in ipairs(nodes) do
        local distance = target:distance_to(node)
        if distance < min_distance then
            min_distance = distance
            closest = node
        end
    end
    
    return closest
end
-- }}}

-- {{{ MapGenerator:ensure_all_nodes_connected
function MapGenerator:ensure_all_nodes_connected(map)
    local all_nodes = {map.spawn_points.player_1, map.spawn_points.player_2}
    for _, node in ipairs(map.nodes) do
        table.insert(all_nodes, node)
    end
    
    -- Find isolated nodes
    local isolated_count = 0
    
    for _, node in ipairs(map.nodes) do  -- Only check intermediate nodes
        local connected = false
        for _, connection in ipairs(map.connections) do
            if connection.from == node or connection.to == node then
                connected = true
                break
            end
        end
        
        if not connected then
            isolated_count = isolated_count + 1
            -- Connect isolated node to its nearest neighbor (excluding self)
            local candidates = {}
            for _, candidate in ipairs(all_nodes) do
                if candidate ~= node then
                    table.insert(candidates, candidate)
                end
            end
            local closest = self:find_closest_node(node, candidates)
            if closest then
                self:add_connection(map, node, closest)
                debug.log("Connected isolated node", "MAP_GEN")
            end
        end
    end
    
    if isolated_count > 0 then
        debug.log(string.format("Fixed %d isolated nodes", isolated_count), "MAP_GEN")
    end
end
-- }}}

-- {{{ MapGenerator:generate_path_geometry
function MapGenerator:generate_path_geometry(map)
    local path_width = 60
    local curve_segments = 8
    
    for _, connection in ipairs(map.connections) do
        local path = self:create_curved_path(connection.from, connection.to, path_width, curve_segments)
        table.insert(map.paths, path)
    end
    
    debug.log(string.format("Generated %d curved paths", #map.paths), "MAP_GEN")
end
-- }}}

-- {{{ MapGenerator:create_curved_path
function MapGenerator:create_curved_path(start, end_point, width, segments)
    local path = {
        start_point = start:copy(),
        end_point = end_point:copy(),
        width = width,
        points = {},
        control_points = {}
    }
    
    -- Calculate control points for a curved path
    local direction = end_point:subtract(start)
    local distance = direction:length()
    local normal = direction:perpendicular():normalize()
    
    -- Add some randomness to the curve
    local curve_strength = distance * 0.2 + math.random() * distance * 0.1
    local curve_direction = (math.random() < 0.5) and 1 or -1
    
    local mid_point = start:add(direction:multiply(0.5))
    local control_offset = normal:multiply(curve_strength * curve_direction)
    local control_point = mid_point:add(control_offset)
    
    path.control_points = {start:copy(), control_point, end_point:copy()}
    
    -- Generate path points using quadratic bezier curve
    for i = 0, segments do
        local t = i / segments
        local point = self:quadratic_bezier(start, control_point, end_point, t)
        table.insert(path.points, point)
    end
    
    return path
end
-- }}}

-- {{{ MapGenerator:quadratic_bezier
function MapGenerator:quadratic_bezier(p0, p1, p2, t)
    local one_minus_t = 1 - t
    local x = one_minus_t * one_minus_t * p0.x + 2 * one_minus_t * t * p1.x + t * t * p2.x
    local y = one_minus_t * one_minus_t * p0.y + 2 * one_minus_t * t * p1.y + t * t * p2.y
    return Vector2:new(x, y)
end
-- }}}

-- {{{ MapGenerator:get_map_stats
function MapGenerator:get_map_stats(map)
    local stats = {
        dimensions = {width = map.width, height = map.height},
        complexity = map.complexity,
        nodes = {
            total = map.metadata.node_count,
            intermediate = #map.nodes,
            spawn_points = 2
        },
        connections = {
            total = map.metadata.connection_count,
            average_per_node = map.metadata.connection_count / map.metadata.node_count
        },
        paths = {
            total = map.metadata.path_count,
            total_length = 0
        },
        generation_time = map.metadata.generation_time
    }
    
    -- Calculate total path length
    for _, path in ipairs(map.paths) do
        for i = 1, #path.points - 1 do
            stats.paths.total_length = stats.paths.total_length + 
                path.points[i]:distance_to(path.points[i + 1])
        end
    end
    
    return stats
end
-- }}}

return MapGenerator
-- }}}