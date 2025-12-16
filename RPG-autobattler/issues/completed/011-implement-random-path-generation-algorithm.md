# Issue #011: Implement Random Path Generation Algorithm

## Current Behavior
No map generation system exists to create the network of pathways between bases.

## Intended Behavior
A procedural generation algorithm should create randomly generated networks of pathways inspired by pipe screensavers, with multiple routes between player bases.

## Implementation Details

### Map Generator (src/systems/map_generator.lua)
```lua
local MapGenerator = {}
local Vector2 = require("src.utils.vector2")

function MapGenerator:generate_map(width, height, complexity)
    local map = {
        width = width,
        height = height,
        nodes = {},
        connections = {},
        spawn_points = {},
        paths = {}
    }
    
    -- Place base nodes at opposite corners
    local base_a = Vector2:new(width * 0.1, height * 0.5)
    local base_b = Vector2:new(width * 0.9, height * 0.5)
    
    map.spawn_points = {
        player_1 = base_a,
        player_2 = base_b
    }
    
    -- Generate intermediate nodes
    self:generate_intermediate_nodes(map, complexity)
    
    -- Create connections between nodes
    self:generate_connections(map)
    
    -- Ensure connectivity between bases
    self:ensure_base_connectivity(map)
    
    -- Generate actual path geometry
    self:generate_path_geometry(map)
    
    return map
end

function MapGenerator:generate_intermediate_nodes(map, complexity)
    local node_count = math.floor(complexity * 8) + 6  -- 6-22 nodes based on complexity
    
    for i = 1, node_count do
        local attempts = 0
        local node
        
        repeat
            node = Vector2:new(
                love.math.random() * map.width * 0.8 + map.width * 0.1,
                love.math.random() * map.height * 0.8 + map.height * 0.1
            )
            attempts = attempts + 1
        until self:is_valid_node_position(map, node) or attempts > 50
        
        if attempts <= 50 then
            table.insert(map.nodes, node)
        end
    end
end

function MapGenerator:is_valid_node_position(map, node)
    local min_distance = 80  -- Minimum distance between nodes
    
    -- Check distance from spawn points
    if node:distance_to(map.spawn_points.player_1) < min_distance then
        return false
    end
    if node:distance_to(map.spawn_points.player_2) < min_distance then
        return false
    end
    
    -- Check distance from existing nodes
    for _, existing_node in ipairs(map.nodes) do
        if node:distance_to(existing_node) < min_distance then
            return false
        end
    end
    
    return true
end

function MapGenerator:generate_connections(map)
    local all_nodes = {map.spawn_points.player_1, map.spawn_points.player_2}
    for _, node in ipairs(map.nodes) do
        table.insert(all_nodes, node)
    end
    
    for i, node_a in ipairs(all_nodes) do
        local connections = 0
        local max_connections = love.math.random(2, 4)
        
        for j, node_b in ipairs(all_nodes) do
            if i ~= j and connections < max_connections then
                local distance = node_a:distance_to(node_b)
                
                if distance < 200 and love.math.random() < 0.4 then
                    self:add_connection(map, node_a, node_b)
                    connections = connections + 1
                end
            end
        end
    end
end

function MapGenerator:add_connection(map, node_a, node_b)
    local connection = {
        from = node_a,
        to = node_b,
        id = #map.connections + 1
    }
    
    table.insert(map.connections, connection)
end

return MapGenerator
```

### Path Finding for Connectivity
```lua
function MapGenerator:ensure_base_connectivity(map)
    -- Use simple pathfinding to ensure bases are connected
    local function find_path(start, goal, connections)
        -- Basic breadth-first search
        local visited = {}
        local queue = {{node = start, path = {start}}}
        
        while #queue > 0 do
            local current = table.remove(queue, 1)
            
            if current.node == goal then
                return current.path
            end
            
            if not visited[current.node] then
                visited[current.node] = true
                
                for _, connection in ipairs(connections) do
                    local next_node = nil
                    if connection.from == current.node then
                        next_node = connection.to
                    elseif connection.to == current.node then
                        next_node = connection.from
                    end
                    
                    if next_node and not visited[next_node] then
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
        
        return nil
    end
    
    local path = find_path(map.spawn_points.player_1, map.spawn_points.player_2, map.connections)
    
    if not path then
        -- Force connectivity by adding direct connections
        self:create_forced_path(map)
    end
end
```

### Considerations
- Ensure multiple paths exist between bases for strategic variety
- Maintain appropriate spacing between pathways
- Consider path lengths for game balance
- Add randomization seed for reproducible maps
- Plan for different map sizes and complexity levels

### Tool Suggestions
- Use Write tool to create map generator
- Test with different complexity levels
- Verify connectivity between all nodes
- Check that paths don't overlap inappropriately

### Acceptance Criteria
- [ ] Algorithm generates varied map layouts
- [ ] Multiple paths exist between player bases
- [ ] Nodes are appropriately spaced
- [ ] Path connectivity is guaranteed
- [ ] Generated maps are visually interesting
- [ ] Performance is acceptable for real-time generation