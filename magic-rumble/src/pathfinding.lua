-- Flow Field Pathfinding System for Magic Rumble
-- Uses influence maps and Dijkstra flow fields for sophisticated unit movement

-- Import map constants (these should match the values in map.lua)
local MAP_WIDTH = 2000
local MAP_HEIGHT = 1400
local GRID_SIZE = 20

local PathfindingGrid = {
    grid_width = 0,
    grid_height = 0,
    passable = {},
    
    -- Influence layer system - different maps for different motivations
    influence_layers = {
        enemy_threat = {},      -- Negative values repel, positive attract
        treasure_appeal = {},   -- Attracts treasure-seeking units
        ally_support = {},      -- Attracts units that prefer group tactics
        strategic_value = {},   -- Room capture importance, choke points
        room_ownership = {}     -- Prefer friendly vs enemy territory
    },
    
    -- Cached flow fields for different unit archetypes
    flow_fields = {},
    
    -- Dirty flags to track when flow fields need recalculation
    dirty_flags = {
        enemy_threat = true,
        treasure_appeal = true,
        ally_support = true,
        strategic_value = true,
        room_ownership = true
    },
    
    -- Update frequency control
    last_update_time = 0,
    update_interval = 0.5  -- Update influence maps every 0.5 seconds
}

-- Unit archetype preferences - how much each type cares about each influence
local unit_archetypes = {
    aggressive_warrior = {
        enemy_threat = 0.6,      -- Moderately seeks combat
        treasure_appeal = 0.1,
        ally_support = 0.2,
        strategic_value = 0.4,   -- Cares about strategic objectives
        room_ownership = 0.3
    },
    
    cautious_archer = {
        enemy_threat = 0.2,      -- More aggressive - they're confident!
        treasure_appeal = 0.2,
        ally_support = 0.3,      -- Less dependent on group support
        strategic_value = 0.4,   -- More strategic thinking
        room_ownership = 0.2
    },
    
    spell_caster = {
        enemy_threat = 0.1,      -- Neutral on combat - depends on range
        treasure_appeal = 0.4,   -- Interested in magical items
        ally_support = 0.3,
        strategic_value = 0.5,   -- Good at strategic objectives
        room_ownership = 0.2
    },
    
    treasure_scout = {
        enemy_threat = -0.7,     -- Highly risk-averse
        treasure_appeal = 0.9,   -- Primary motivation
        ally_support = 0.1,
        strategic_value = 0.2,
        room_ownership = -0.1    -- Prefers neutral territory
    },
    
    berserker = {
        enemy_threat = 1.0,      -- Maximum aggression
        treasure_appeal = 0.0,
        ally_support = -0.2,     -- Prefers solo combat
        strategic_value = 0.1,
        room_ownership = 0.0
    },
    
    independent_defender = {
        enemy_threat = 0.8,      -- Aggressive but focused on defense
        treasure_appeal = 0.0,
        ally_support = 0.2,      -- Some coordination with other independents
        strategic_value = 0.0,   -- Don't care about strategic objectives
        room_ownership = -0.5    -- Strong preference to stay in home territory
    }
}

function pathfinding_init()
    PathfindingGrid.grid_width = math.ceil(MAP_WIDTH / GRID_SIZE)
    PathfindingGrid.grid_height = math.ceil(MAP_HEIGHT / GRID_SIZE)
    
    -- Initialize all grids
    pathfinding_init_grids()
    
    -- Build initial passability map from rooms and hallways
    pathfinding_build_passability_map()
    
    -- Initialize influence layers
    pathfinding_clear_influence_layers()
    
    PathfindingGrid.last_update_time = 0
    print("Pathfinding system initialized: " .. PathfindingGrid.grid_width .. "x" .. PathfindingGrid.grid_height)
end

function pathfinding_init_grids()
    -- Initialize passability grid
    PathfindingGrid.passable = {}
    for x = 1, PathfindingGrid.grid_width do
        PathfindingGrid.passable[x] = {}
        for y = 1, PathfindingGrid.grid_height do
            PathfindingGrid.passable[x][y] = false  -- Default impassable
        end
    end
    
    -- Initialize influence layers
    for layer_name, _ in pairs(PathfindingGrid.influence_layers) do
        PathfindingGrid.influence_layers[layer_name] = {}
        for x = 1, PathfindingGrid.grid_width do
            PathfindingGrid.influence_layers[layer_name][x] = {}
            for y = 1, PathfindingGrid.grid_height do
                PathfindingGrid.influence_layers[layer_name][x][y] = 0.0
            end
        end
    end
    
    -- Initialize flow fields
    PathfindingGrid.flow_fields = {}
    for archetype, _ in pairs(unit_archetypes) do
        PathfindingGrid.flow_fields[archetype] = {}
        for x = 1, PathfindingGrid.grid_width do
            PathfindingGrid.flow_fields[archetype][x] = {}
            for y = 1, PathfindingGrid.grid_height do
                PathfindingGrid.flow_fields[archetype][x][y] = {
                    value = math.huge,
                    flow_x = 0,
                    flow_y = 0
                }
            end
        end
    end
end

function pathfinding_build_passability_map()
    -- First, mark everything as impassable
    for x = 1, PathfindingGrid.grid_width do
        for y = 1, PathfindingGrid.grid_height do
            PathfindingGrid.passable[x][y] = false
        end
    end
    
    local rooms = get_rooms()
    local connections = get_connections()
    
    -- Mark room areas as passable
    for _, room in ipairs(rooms) do
        local start_x = math.max(1, math.floor(room.x / GRID_SIZE) + 1)
        local end_x = math.min(PathfindingGrid.grid_width, math.floor((room.x + room.width) / GRID_SIZE) + 1)
        local start_y = math.max(1, math.floor(room.y / GRID_SIZE) + 1)
        local end_y = math.min(PathfindingGrid.grid_height, math.floor((room.y + room.height) / GRID_SIZE) + 1)
        
        for x = start_x, end_x do
            for y = start_y, end_y do
                PathfindingGrid.passable[x][y] = true
            end
        end
    end
    
    -- Mark hallway areas as passable
    for _, connection in ipairs(connections) do
        pathfinding_mark_hallway_passable(connection)
    end
end

function pathfinding_mark_hallway_passable(connection)
    local x1, y1 = connection.x1, connection.y1
    local x2, y2 = connection.x2, connection.y2
    local width = connection.width or 40
    
    -- Use Bresenham-style line drawing to mark hallway cells
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local steps = math.max(dx, dy)
    
    if steps == 0 then return end
    
    local step_x = (x2 - x1) / steps
    local step_y = (y2 - y1) / steps
    
    for i = 0, steps do
        local world_x = x1 + (step_x * i)
        local world_y = y1 + (step_y * i)
        
        -- Mark cells around this point as passable
        local half_width = width / 2
        local grid_radius = math.ceil(half_width / GRID_SIZE)
        
        local center_grid_x = math.floor(world_x / GRID_SIZE) + 1
        local center_grid_y = math.floor(world_y / GRID_SIZE) + 1
        
        for x = center_grid_x - grid_radius, center_grid_x + grid_radius do
            for y = center_grid_y - grid_radius, center_grid_y + grid_radius do
                if x >= 1 and x <= PathfindingGrid.grid_width and 
                   y >= 1 and y <= PathfindingGrid.grid_height then
                    PathfindingGrid.passable[x][y] = true
                end
            end
        end
    end
end

function pathfinding_clear_influence_layers()
    for layer_name, layer in pairs(PathfindingGrid.influence_layers) do
        for x = 1, PathfindingGrid.grid_width do
            for y = 1, PathfindingGrid.grid_height do
                layer[x][y] = 0.0
            end
        end
        PathfindingGrid.dirty_flags[layer_name] = true
    end
end

function pathfinding_update(dt)
    PathfindingGrid.last_update_time = PathfindingGrid.last_update_time + dt
    
    -- Update influence layers periodically
    if PathfindingGrid.last_update_time >= PathfindingGrid.update_interval then
        pathfinding_update_influence_layers()
        PathfindingGrid.last_update_time = 0
    end
end

function pathfinding_update_influence_layers()
    -- Clear all influence layers
    pathfinding_clear_influence_layers()
    
    -- Update enemy threat influence
    pathfinding_update_enemy_threat_influence()
    
    -- Update ally support influence
    pathfinding_update_ally_support_influence()
    
    -- Update strategic value influence
    pathfinding_update_strategic_influence()
    
    -- Update room ownership influence
    pathfinding_update_room_ownership_influence()
    
    -- Mark all flow fields as needing recalculation
    for archetype, _ in pairs(unit_archetypes) do
        PathfindingGrid.dirty_flags[archetype] = true
    end
end

function pathfinding_update_enemy_threat_influence()
    local units = get_all_units()  -- We'll need to expose this from unit.lua
    if not units then return end
    
    for _, unit in ipairs(units) do
        local grid_x, grid_y = pathfinding_world_to_grid(unit.x, unit.y)
        
        if pathfinding_is_valid_grid_pos(grid_x, grid_y) then
            -- Create threat gradient around enemy units
            local threat_strength = 0.8
            local threat_radius = 4  -- Grid cells
            
            -- Different threat levels based on unit type and health
            if unit.type == "melee" then
                threat_strength = 1.0
                threat_radius = 3
            elseif unit.type == "ranged" then
                threat_strength = 0.6
                threat_radius = 6
            elseif unit.type == "spell" then
                threat_strength = 0.7
                threat_radius = 5
            end
            
            -- Scale by unit health (wounded units less threatening)
            threat_strength = threat_strength * (unit.health / unit.max_health)
            
            -- Apply threat gradient
            pathfinding_apply_radial_influence("enemy_threat", grid_x, grid_y, 
                                             threat_radius, threat_strength, unit.owner)
        end
    end
end

function pathfinding_update_ally_support_influence()
    local units = get_all_units()
    if not units then return end
    
    for _, unit in ipairs(units) do
        local grid_x, grid_y = pathfinding_world_to_grid(unit.x, unit.y)
        
        if pathfinding_is_valid_grid_pos(grid_x, grid_y) then
            -- Create positive influence around allied units
            local support_strength = 0.3
            local support_radius = 3
            
            pathfinding_apply_radial_influence("ally_support", grid_x, grid_y,
                                             support_radius, support_strength, unit.owner)
        end
    end
end

function pathfinding_update_strategic_influence()
    local rooms = get_rooms()
    
    for _, room in ipairs(rooms) do
        local grid_x, grid_y = pathfinding_world_to_grid(room.x + room.width/2, 
                                                       room.y + room.height/2)
        
        if pathfinding_is_valid_grid_pos(grid_x, grid_y) then
            local strategic_value = 0.2  -- Base strategic value
            
            -- Contested rooms are more strategically important
            if room.capture_progress > 0 then
                strategic_value = 0.6
            end
            
            -- Enemy-controlled rooms are strategic targets
            if room.owner == 2 then
                strategic_value = 0.4
            end
            
            -- Apply strategic influence in room area
            local room_radius = math.max(room.width, room.height) / (GRID_SIZE * 2)
            pathfinding_apply_radial_influence("strategic_value", grid_x, grid_y,
                                             room_radius, strategic_value, 0)
        end
    end
end

function pathfinding_update_room_ownership_influence()
    local rooms = get_rooms()
    
    for _, room in ipairs(rooms) do
        local start_x = math.max(1, math.floor(room.x / GRID_SIZE) + 1)
        local end_x = math.min(PathfindingGrid.grid_width, math.floor((room.x + room.width) / GRID_SIZE) + 1)
        local start_y = math.max(1, math.floor(room.y / GRID_SIZE) + 1)
        local end_y = math.min(PathfindingGrid.grid_height, math.floor((room.y + room.height) / GRID_SIZE) + 1)
        
        local ownership_value = 0.0
        if room.owner == 1 then
            ownership_value = 0.2   -- Slight preference for friendly territory
        elseif room.owner == 2 then
            ownership_value = -0.1  -- Slight penalty for enemy territory
        elseif room.owner == 3 then
            ownership_value = -0.05 -- Small penalty for neutral (defended) territory
        end
        
        for x = start_x, end_x do
            for y = start_y, end_y do
                if pathfinding_is_valid_grid_pos(x, y) then
                    PathfindingGrid.influence_layers.room_ownership[x][y] = ownership_value
                end
            end
        end
    end
end

function pathfinding_apply_radial_influence(layer_name, center_x, center_y, radius, strength, exclude_owner)
    local layer = PathfindingGrid.influence_layers[layer_name]
    if not layer then 
        print("Warning: Layer not found: " .. tostring(layer_name))
        return 
    end
    
    for x = center_x - radius, center_x + radius do
        for y = center_y - radius, center_y + radius do
            if pathfinding_is_valid_grid_pos(x, y) then
                -- Double-check that the layer and position exist
                if layer[x] and layer[x][y] ~= nil then
                    local dx = x - center_x
                    local dy = y - center_y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    
                    if distance <= radius then
                        -- Apply falloff based on distance
                        local falloff = 1.0 - (distance / radius)
                        local influence = strength * falloff * falloff  -- Quadratic falloff
                        
                        -- For threat layers, make it repel same team and attract enemies
                        if layer_name == "enemy_threat" then
                            if exclude_owner == 1 then
                                layer[x][y] = layer[x][y] - influence  -- Repel player units
                            elseif exclude_owner == 2 then
                                layer[x][y] = layer[x][y] + influence  -- Attract enemy units
                            end
                        elseif layer_name == "ally_support" then
                            if exclude_owner == 1 then
                                layer[x][y] = layer[x][y] + influence  -- Attract friendly units
                            elseif exclude_owner == 2 then
                                layer[x][y] = layer[x][y] - influence  -- Repel enemy units
                            end
                        else
                            layer[x][y] = layer[x][y] + influence
                        end
                    end
                end
            end
        end
    end
end

-- Utility functions
function pathfinding_world_to_grid(world_x, world_y)
    return math.floor(world_x / GRID_SIZE) + 1, math.floor(world_y / GRID_SIZE) + 1
end

function pathfinding_grid_to_world(grid_x, grid_y)
    return (grid_x - 1) * GRID_SIZE + GRID_SIZE/2, (grid_y - 1) * GRID_SIZE + GRID_SIZE/2
end

function pathfinding_is_valid_grid_pos(x, y)
    return x >= 1 and x <= PathfindingGrid.grid_width and 
           y >= 1 and y <= PathfindingGrid.grid_height
end

-- Flow field generation (Dijkstra's algorithm)
function pathfinding_generate_flow_field(archetype)
    if not unit_archetypes[archetype] then
        print("Warning: Unknown unit archetype: " .. archetype)
        return
    end
    
    local preferences = unit_archetypes[archetype]
    local flow_field = PathfindingGrid.flow_fields[archetype]
    
    -- Reset flow field
    for x = 1, PathfindingGrid.grid_width do
        for y = 1, PathfindingGrid.grid_height do
            flow_field[x][y].value = math.huge
            flow_field[x][y].flow_x = 0
            flow_field[x][y].flow_y = 0
        end
    end
    
    -- Calculate composite influence map for this archetype
    local composite_influence = pathfinding_calculate_composite_influence(preferences)
    
    -- Use Dijkstra's algorithm to create flow field
    pathfinding_dijkstra_flow_field(flow_field, composite_influence)
    
    -- Calculate flow directions
    pathfinding_calculate_flow_directions(flow_field)
    
    PathfindingGrid.dirty_flags[archetype] = false
end

function pathfinding_calculate_composite_influence(preferences)
    local composite = {}
    
    -- Initialize composite influence map
    for x = 1, PathfindingGrid.grid_width do
        composite[x] = {}
        for y = 1, PathfindingGrid.grid_height do
            composite[x][y] = 0.0
        end
    end
    
    -- Combine all influence layers based on preferences
    for layer_name, weight in pairs(preferences) do
        local layer = PathfindingGrid.influence_layers[layer_name]
        if layer and weight ~= 0 then
            for x = 1, PathfindingGrid.grid_width do
                for y = 1, PathfindingGrid.grid_height do
                    composite[x][y] = composite[x][y] + (layer[x][y] * weight)
                end
            end
        end
    end
    
    return composite
end

function pathfinding_dijkstra_flow_field(flow_field, influence_map)
    -- Priority queue for Dijkstra's algorithm
    local open_set = {}
    local open_set_size = 0
    
    -- Find all goal cells (high positive influence) - lower threshold for more goals
    local goal_threshold = 0.1
    for x = 1, PathfindingGrid.grid_width do
        for y = 1, PathfindingGrid.grid_height do
            if PathfindingGrid.passable[x][y] and influence_map[x][y] > goal_threshold then
                flow_field[x][y].value = 0
                open_set_size = open_set_size + 1
                open_set[open_set_size] = {x = x, y = y, value = 0}
            end
        end
    end
    
    -- If no goals found, create some default goals in enemy territory
    if open_set_size == 0 then
        local rooms = get_rooms()
        for _, room in ipairs(rooms) do
            if room.owner == 2 or room.owner == 3 then  -- Enemy or neutral territory
                local grid_x, grid_y = pathfinding_world_to_grid(room.x + room.width/2, room.y + room.height/2)
                if pathfinding_is_valid_grid_pos(grid_x, grid_y) and PathfindingGrid.passable[grid_x][grid_y] then
                    flow_field[grid_x][grid_y].value = 0
                    open_set_size = open_set_size + 1
                    open_set[open_set_size] = {x = grid_x, y = grid_y, value = 0}
                end
            end
        end
    end
    
    -- Dijkstra's algorithm
    while open_set_size > 0 do
        -- Find minimum value cell (simple linear search for now)
        local min_idx = 1
        for i = 2, open_set_size do
            if open_set[i].value < open_set[min_idx].value then
                min_idx = i
            end
        end
        
        local current = open_set[min_idx]
        
        -- Remove from open set
        open_set[min_idx] = open_set[open_set_size]
        open_set_size = open_set_size - 1
        
        -- Check all neighbors
        local neighbors = {
            {current.x - 1, current.y},
            {current.x + 1, current.y},
            {current.x, current.y - 1},
            {current.x, current.y + 1}
        }
        
        for _, neighbor in ipairs(neighbors) do
            local nx, ny = neighbor[1], neighbor[2]
            
            if pathfinding_is_valid_grid_pos(nx, ny) and PathfindingGrid.passable[nx][ny] then
                -- Calculate cost to move to neighbor
                local move_cost = 1.0
                
                -- Apply influence as movement cost modifier
                local influence = influence_map[nx][ny]
                if influence < 0 then
                    move_cost = move_cost + (math.abs(influence) * 2)  -- Penalty for negative influence
                end
                
                local new_value = current.value + move_cost
                
                if new_value < flow_field[nx][ny].value then
                    flow_field[nx][ny].value = new_value
                    
                    -- Add to open set if not already there
                    local found = false
                    for i = 1, open_set_size do
                        if open_set[i].x == nx and open_set[i].y == ny then
                            open_set[i].value = new_value
                            found = true
                            break
                        end
                    end
                    
                    if not found then
                        open_set_size = open_set_size + 1
                        open_set[open_set_size] = {x = nx, y = ny, value = new_value}
                    end
                end
            end
        end
    end
end

function pathfinding_calculate_flow_directions(flow_field)
    for x = 1, PathfindingGrid.grid_width do
        for y = 1, PathfindingGrid.grid_height do
            if PathfindingGrid.passable[x][y] and flow_field[x][y].value ~= math.huge then
                local best_x, best_y = 0, 0
                local best_value = flow_field[x][y].value
                
                -- Check all neighbors to find the direction of steepest descent
                local neighbors = {
                    {x - 1, y, -1, 0},
                    {x + 1, y, 1, 0},
                    {x, y - 1, 0, -1},
                    {x, y + 1, 0, 1}
                }
                
                for _, neighbor in ipairs(neighbors) do
                    local nx, ny, dx, dy = neighbor[1], neighbor[2], neighbor[3], neighbor[4]
                    
                    if pathfinding_is_valid_grid_pos(nx, ny) and PathfindingGrid.passable[nx][ny] then
                        if flow_field[nx][ny].value < best_value then
                            best_value = flow_field[nx][ny].value
                            best_x, best_y = dx, dy
                        end
                    end
                end
                
                flow_field[x][y].flow_x = best_x
                flow_field[x][y].flow_y = best_y
            end
        end
    end
end

-- Public interface for unit movement
function pathfinding_get_movement_direction(unit_x, unit_y, archetype)
    local grid_x, grid_y = pathfinding_world_to_grid(unit_x, unit_y)
    
    if not pathfinding_is_valid_grid_pos(grid_x, grid_y) then
        return 0, 0
    end
    
    -- Generate flow field if it's dirty
    if PathfindingGrid.dirty_flags[archetype] then
        pathfinding_generate_flow_field(archetype)
    end
    
    local flow_field = PathfindingGrid.flow_fields[archetype]
    if not flow_field then
        return 0, 0
    end
    
    return flow_field[grid_x][grid_y].flow_x, flow_field[grid_x][grid_y].flow_y
end

-- Debug visualization
function pathfinding_draw_debug_layer(layer_name, alpha)
    alpha = alpha or 0.5
    local layer = PathfindingGrid.influence_layers[layer_name]
    if not layer then return end
    
    for x = 1, PathfindingGrid.grid_width do
        for y = 1, PathfindingGrid.grid_height do
            local value = layer[x][y]
            if math.abs(value) > 0.01 then
                local world_x, world_y = pathfinding_grid_to_world(x, y)
                
                if value > 0 then
                    love.graphics.setColor(0, 1, 0, alpha * math.min(1, value))
                else
                    love.graphics.setColor(1, 0, 0, alpha * math.min(1, math.abs(value)))
                end
                
                love.graphics.rectangle("fill", world_x - GRID_SIZE/2, world_y - GRID_SIZE/2, 
                                      GRID_SIZE, GRID_SIZE)
            end
        end
    end
end

-- Force recalculation for specific archetype (helps with stuck units)
function pathfinding_force_recalculation(archetype)
    if PathfindingGrid.dirty_flags[archetype] ~= nil then
        PathfindingGrid.dirty_flags[archetype] = true
    end
end

return {
    init = pathfinding_init,
    update = pathfinding_update,
    get_movement_direction = pathfinding_get_movement_direction,
    draw_debug_layer = pathfinding_draw_debug_layer,
    world_to_grid = pathfinding_world_to_grid,
    grid_to_world = pathfinding_grid_to_world,
    force_recalculation = pathfinding_force_recalculation
}