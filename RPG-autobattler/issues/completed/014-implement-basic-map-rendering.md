# Issue #014: Implement Basic Map Rendering

## Current Behavior
No visual representation exists for the generated map structure and pathways.

## Intended Behavior
The map should be clearly rendered showing all pathways, sub-paths, spawn points, and strategic elements in an accessible visual style.

## Implementation Details

### Map Renderer (src/systems/map_renderer.lua)
```lua
local MapRenderer = {}
local Colors = require("src.constants.colors")

function MapRenderer:new(renderer)
    local map_renderer = {
        renderer = renderer,
        camera = {x = 0, y = 0, zoom = 1},
        show_sub_paths = true,
        show_debug_info = false,
        background_grid = true
    }
    return setmetatable(map_renderer, {__index = MapRenderer})
end

function MapRenderer:draw_map(map)
    self:draw_background(map)
    self:draw_pathways(map)
    self:draw_sub_paths(map)
    self:draw_spawn_points(map)
    self:draw_nodes(map)
    
    if self.show_debug_info then
        self:draw_debug_info(map)
    end
end

function MapRenderer:draw_background(map)
    -- Clear background
    self.renderer:draw_rectangle(0, 0, map.width, map.height, Colors.BLACK)
    
    if self.background_grid then
        self:draw_grid(map)
    end
end

function MapRenderer:draw_grid(map)
    local grid_size = 50
    local grid_color = {0.1, 0.1, 0.1, 1}  -- Very dark gray
    
    -- Vertical lines
    for x = 0, map.width, grid_size do
        self.renderer:draw_line(x, 0, x, map.height, grid_color, 1)
    end
    
    -- Horizontal lines
    for y = 0, map.height, grid_size do
        self.renderer:draw_line(0, y, map.width, y, grid_color, 1)
    end
end

function MapRenderer:draw_pathways(map)
    for _, connection in ipairs(map.connections) do
        self:draw_pathway(connection)
    end
end

function MapRenderer:draw_pathway(connection)
    local lane_width = 60
    local pathway_color = {0.2, 0.2, 0.2, 1}  -- Dark gray
    
    -- Calculate perpendicular vector for width
    local direction = connection.to:subtract(connection.from):normalize()
    local perpendicular = {x = -direction.y, y = direction.x}
    
    -- Draw pathway as thick line
    local half_width = lane_width / 2
    local p1 = {
        x = connection.from.x + perpendicular.x * half_width,
        y = connection.from.y + perpendicular.y * half_width
    }
    local p2 = {
        x = connection.from.x - perpendicular.x * half_width,
        y = connection.from.y - perpendicular.y * half_width
    }
    local p3 = {
        x = connection.to.x - perpendicular.x * half_width,
        y = connection.to.y - perpendicular.y * half_width
    }
    local p4 = {
        x = connection.to.x + perpendicular.x * half_width,
        y = connection.to.y + perpendicular.y * half_width
    }
    
    -- Draw pathway outline
    self.renderer:draw_line(p1.x, p1.y, p4.x, p4.y, pathway_color, 3)
    self.renderer:draw_line(p2.x, p2.y, p3.x, p3.y, pathway_color, 3)
    
    -- Draw center line for reference
    local center_color = {0.3, 0.3, 0.3, 1}
    self.renderer:draw_line(
        connection.from.x, connection.from.y,
        connection.to.x, connection.to.y,
        center_color, 1
    )
end

function MapRenderer:draw_sub_paths(map)
    if not self.show_sub_paths then return end
    
    for _, lane in ipairs(map.lanes or {}) do
        self:draw_lane_sub_paths(lane)
    end
end

function MapRenderer:draw_lane_sub_paths(lane)
    local sub_path_color = {0.15, 0.15, 0.15, 0.8}  -- Slightly visible sub-paths
    
    for i, sub_path in ipairs(lane.sub_paths) do
        if #sub_path.center_line > 1 then
            -- Draw sub-path as series of connected line segments
            for j = 1, #sub_path.center_line - 1 do
                local p1 = sub_path.center_line[j]
                local p2 = sub_path.center_line[j + 1]
                self.renderer:draw_line(p1.x, p1.y, p2.x, p2.y, sub_path_color, 1)
            end
            
            -- Draw sub-path boundaries (very subtle)
            local boundary_color = {0.1, 0.1, 0.1, 0.5}
            local half_width = sub_path.width / 2
            
            for j = 1, #sub_path.center_line - 1 do
                local p1 = sub_path.center_line[j]
                local p2 = sub_path.center_line[j + 1]
                local direction = p2:subtract(p1):normalize()
                local perpendicular = {x = -direction.y, y = direction.x}
                
                -- Left boundary
                local left1 = {
                    x = p1.x + perpendicular.x * half_width,
                    y = p1.y + perpendicular.y * half_width
                }
                local left2 = {
                    x = p2.x + perpendicular.x * half_width,
                    y = p2.y + perpendicular.y * half_width
                }
                self.renderer:draw_line(left1.x, left1.y, left2.x, left2.y, boundary_color, 0.5)
                
                -- Right boundary
                local right1 = {
                    x = p1.x - perpendicular.x * half_width,
                    y = p1.y - perpendicular.y * half_width
                }
                local right2 = {
                    x = p2.x - perpendicular.x * half_width,
                    y = p2.y - perpendicular.y * half_width
                }
                self.renderer:draw_line(right1.x, right1.y, right2.x, right2.y, boundary_color, 0.5)
            end
        end
    end
end

function MapRenderer:draw_spawn_points(map)
    for player_id, spawn_point in pairs(map.spawn_points) do
        local player_color = player_id == "player_1" and Colors.TEAM_A or Colors.TEAM_B
        
        -- Draw spawn area
        self.renderer:draw_circle(spawn_point.x, spawn_point.y, 25, player_color, "line")
        self.renderer:draw_circle(spawn_point.x, spawn_point.y, 20, player_color, "line")
        
        -- Draw player indicator
        self.renderer:draw_text(
            "P" .. (player_id == "player_1" and "1" or "2"),
            spawn_point.x - 5, spawn_point.y - 8,
            player_color
        )
    end
end

function MapRenderer:draw_nodes(map)
    local node_color = {0.4, 0.4, 0.4, 1}  -- Medium gray
    
    for _, node in ipairs(map.nodes) do
        self.renderer:draw_circle(node.x, node.y, 8, node_color)
        self.renderer:draw_circle(node.x, node.y, 6, Colors.BLACK)
    end
end

function MapRenderer:draw_debug_info(map)
    local debug_color = Colors.UI_TEXT
    local y_offset = 10
    
    -- Draw map statistics
    self.renderer:draw_text("Nodes: " .. #map.nodes, 10, y_offset, debug_color)
    y_offset = y_offset + 20
    
    self.renderer:draw_text("Connections: " .. #map.connections, 10, y_offset, debug_color)
    y_offset = y_offset + 20
    
    self.renderer:draw_text("Map Size: " .. map.width .. "x" .. map.height, 10, y_offset, debug_color)
    y_offset = y_offset + 20
    
    -- Draw node IDs
    for i, node in ipairs(map.nodes) do
        self.renderer:draw_text(tostring(i), node.x + 10, node.y - 5, debug_color)
    end
    
    -- Draw connection IDs
    for i, connection in ipairs(map.connections) do
        local mid_x = (connection.from.x + connection.to.x) / 2
        local mid_y = (connection.from.y + connection.to.y) / 2
        self.renderer:draw_text(tostring(i), mid_x, mid_y, debug_color)
    end
end

function MapRenderer:toggle_sub_paths()
    self.show_sub_paths = not self.show_sub_paths
end

function MapRenderer:toggle_debug_info()
    self.show_debug_info = not self.show_debug_info
end

return MapRenderer
```

### Visual Design Elements
1. **Pathway Rendering**: Clear lane boundaries with center lines
2. **Sub-Path Indicators**: Subtle lines showing movement tracks
3. **Spawn Point Markers**: Distinct player-colored indicators
4. **Node Visualization**: Connection points in the network
5. **Debug Overlays**: Optional technical information display

### Considerations
- Ensure visual clarity at different zoom levels
- Use colorblind-friendly design patterns
- Maintain performance with complex maps
- Plan for animated elements (flowing effects, etc.)
- Consider different rendering modes for accessibility

### Tool Suggestions
- Use Write tool to create map renderer
- Test rendering with generated maps
- Verify all visual elements are clearly distinguishable
- Check performance with complex map layouts

### Acceptance Criteria
- [ ] Complete map structure is visually represented
- [ ] All pathways and sub-paths are clearly visible
- [ ] Spawn points are easily identifiable
- [ ] Rendering performance is acceptable
- [ ] Debug information aids development
- [ ] Visual design follows accessibility guidelines