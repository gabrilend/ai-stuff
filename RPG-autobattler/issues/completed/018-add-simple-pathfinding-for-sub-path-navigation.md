# Issue #018: Add Simple Pathfinding for Sub-Path Navigation

## Current Behavior
Units can move along paths but lack intelligent pathfinding to navigate around obstacles and make routing decisions.

## Intended Behavior
Units should have basic pathfinding capabilities to navigate their assigned sub-paths while avoiding obstacles and making smart routing choices.

## Implementation Details

### Pathfinding System Enhancement (src/systems/pathfinding_system.lua)
```lua
-- {{{ local function find_path_in_subpath
local function find_path_in_subpath(start_position, end_position, sub_path, obstacles)
    local path_nodes = create_navigation_nodes(sub_path, obstacles)
    local start_node = find_closest_node(start_position, path_nodes)
    local end_node = find_closest_node(end_position, path_nodes)
    
    if not start_node or not end_node then
        return create_direct_path(start_position, end_position, sub_path)
    end
    
    local path = a_star_search(start_node, end_node, path_nodes)
    return convert_nodes_to_path(path, start_position, end_position)
end
-- }}}

-- {{{ local function create_navigation_nodes
local function create_navigation_nodes(sub_path, obstacles)
    local nodes = {}
    local center_line = sub_path.center_line
    local node_spacing = 20  -- Distance between nodes
    
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
                    is_blocked = is_position_blocked(node_position, obstacles),
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
    add_avoidance_nodes(nodes, sub_path, obstacles)
    
    -- Connect neighboring nodes
    connect_navigation_nodes(nodes, sub_path)
    
    return nodes
end
-- }}}

-- {{{ local function add_avoidance_nodes
local function add_avoidance_nodes(nodes, sub_path, obstacles)
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
                
                if CollisionSystem:check_unit_in_bounds({position = avoidance_pos}, sub_path) then
                    local node = {
                        id = #nodes + 1,
                        position = avoidance_pos,
                        segment_index = find_closest_segment_index(avoidance_pos, sub_path),
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

-- {{{ local function connect_navigation_nodes
local function connect_navigation_nodes(nodes, sub_path)
    local max_connection_distance = 30
    
    for i, node in ipairs(nodes) do
        for j, other_node in ipairs(nodes) do
            if i ~= j then
                local distance = node.position:distance_to(other_node.position)
                
                if distance <= max_connection_distance then
                    -- Check if connection is valid (no obstacles in between)
                    if is_connection_clear(node.position, other_node.position, sub_path) then
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

-- {{{ local function a_star_search
local function a_star_search(start_node, end_node, all_nodes)
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
            return reconstruct_path(current_node)
        end
        
        -- Check neighbors
        for _, neighbor_data in ipairs(current_node.neighbors) do
            local neighbor = neighbor_data.node
            
            if not is_in_closed_set(neighbor, closed_set) and not neighbor.is_blocked then
                local tentative_g_cost = current_node.g_cost + neighbor_data.cost
                
                if tentative_g_cost < neighbor.g_cost then
                    neighbor.parent = current_node
                    neighbor.g_cost = tentative_g_cost
                    neighbor.h_cost = neighbor.position:distance_to(end_node.position)
                    neighbor.f_cost = neighbor.g_cost + neighbor.h_cost
                    
                    if not is_in_open_set(neighbor, open_set) then
                        table.insert(open_set, neighbor)
                    end
                end
            end
        end
    end
    
    return nil  -- No path found
end
-- }}}

-- {{{ local function reconstruct_path
local function reconstruct_path(end_node)
    local path = {}
    local current = end_node
    
    while current do
        table.insert(path, 1, current.position)
        current = current.parent
    end
    
    return path
end
-- }}}

-- {{{ local function create_direct_path
local function create_direct_path(start_position, end_position, sub_path)
    -- Fallback: create direct path along center line if pathfinding fails
    local center_line = sub_path.center_line
    local path = {}
    
    -- Find start and end segments
    local start_segment = find_closest_segment_index(start_position, sub_path)
    local end_segment = find_closest_segment_index(end_position, sub_path)
    
    if start_segment and end_segment then
        -- Add center line points between start and end
        for i = start_segment, end_segment do
            if center_line[i] then
                table.insert(path, center_line[i])
            end
        end
    end
    
    return path
end
-- }}}
```

### Pathfinding Features
1. **A* Algorithm**: Efficient pathfinding with heuristics
2. **Dynamic Node Generation**: Create navigation nodes based on sub-path
3. **Obstacle Avoidance**: Generate alternative routes around obstacles
4. **Fallback System**: Direct path when advanced pathfinding fails
5. **Bounds Checking**: Ensure paths stay within sub-path boundaries

### Integration Points
- Connect with movement system for path execution
- Interface with collision system for obstacle detection
- Work with lane system for sub-path information

### Considerations
- Balance node density vs performance
- Handle dynamic obstacles (other units)
- Consider future expansion for different unit behaviors
- Optimize for real-time pathfinding requests

### Tool Suggestions
- Use Edit tool to enhance pathfinding system
- Test with various obstacle configurations
- Verify path quality and smoothness
- Check performance with multiple pathfinding requests

### Acceptance Criteria
- [ ] Units can navigate around static obstacles
- [ ] Pathfinding respects sub-path boundaries
- [ ] A* algorithm finds optimal routes
- [ ] Fallback system prevents units from getting stuck
- [ ] Performance is acceptable for real-time gameplay