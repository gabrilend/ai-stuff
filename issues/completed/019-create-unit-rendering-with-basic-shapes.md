# Issue #019: Create Unit Rendering with Basic Shapes

## Current Behavior
Unit rendering system exists but needs enhancement for clear visual distinction and colorblind accessibility.

## Intended Behavior
Units should be rendered with distinct shapes based on their type, team, and state, following colorblind-friendly design principles using shapes as primary identifiers.

## Implementation Details

### Enhanced Unit Rendering (src/systems/unit_render_system.lua)
```lua
-- {{{ local function render_unit
local function render_unit(renderer, unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    local renderable = EntityManager:get_component(unit_id, "renderable")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local health = EntityManager:get_component(unit_id, "health")
    
    if not position or not renderable or not unit_data or not renderable.visible then
        return
    end
    
    -- Get unit visual configuration
    local visual_config = get_unit_visual_config(unit_data, health)
    
    -- Render main unit shape
    render_unit_shape(renderer, position, visual_config, unit_data.unit_type)
    
    -- Render team indicator
    render_team_indicator(renderer, position, visual_config, unit_data)
    
    -- Render health bar if damaged
    if health.current < health.maximum then
        render_health_bar(renderer, position, health, visual_config.size)
    end
    
    -- Render state indicators
    render_state_indicators(renderer, position, unit_data, visual_config)
end
-- }}}

-- {{{ local function get_unit_visual_config
local function get_unit_visual_config(unit_data, health)
    local config = {
        size = unit_data.size or 8,
        primary_color = Colors.WHITE,
        secondary_color = Colors.GRAY,
        outline_color = Colors.BLACK,
        alpha = 1.0
    }
    
    -- Team-based coloring (secondary to shape identification)
    local team = EntityManager:get_component(unit_data.entity_id, "team")
    if team then
        if team.id == 1 then
            config.primary_color = Colors.BLUE
            config.secondary_color = Colors.LIGHT_BLUE
        else
            config.primary_color = Colors.RED
            config.secondary_color = Colors.LIGHT_RED
        end
    end
    
    -- Health-based alpha
    local health_ratio = health.current / health.maximum
    if health_ratio < 0.3 then
        config.alpha = 0.7  -- Slightly transparent when heavily damaged
    end
    
    -- State-based modifications
    if unit_data.state == "spawning" then
        config.alpha = 0.5
    elseif unit_data.state == "dead" then
        config.alpha = 0.3
        config.primary_color = Colors.DARK_GRAY
    end
    
    return config
end
-- }}}

-- {{{ local function render_unit_shape
local function render_unit_shape(renderer, position, config, unit_type)
    local x, y = position.x, position.y
    local size = config.size
    
    -- Shape determines unit type (primary identifier for colorblind accessibility)
    if unit_type == "melee" then
        -- Melee units: Square shape
        renderer:draw_filled_rectangle(
            x - size/2, y - size/2, size, size,
            config.primary_color, config.alpha
        )
        renderer:draw_rectangle(
            x - size/2, y - size/2, size, size,
            config.outline_color, 2
        )
        
    elseif unit_type == "ranged" then
        -- Ranged units: Triangle shape
        local triangle_points = {
            x, y - size/2,              -- Top point
            x - size/2, y + size/2,     -- Bottom left
            x + size/2, y + size/2      -- Bottom right
        }
        
        renderer:draw_filled_polygon(triangle_points, config.primary_color, config.alpha)
        renderer:draw_polygon(triangle_points, config.outline_color, 2)
        
    else
        -- Default: Circle shape
        renderer:draw_filled_circle(x, y, size/2, config.primary_color, config.alpha)
        renderer:draw_circle(x, y, size/2, config.outline_color, 2)
    end
end
-- }}}

-- {{{ local function render_team_indicator
local function render_team_indicator(renderer, position, config, unit_data)
    local team = EntityManager:get_component(unit_data.entity_id, "team")
    if not team then return end
    
    local x, y = position.x, position.y
    local indicator_size = config.size / 4
    local offset_y = -config.size/2 - 5
    
    -- Team indicator shape (additional visual distinction)
    if team.id == 1 then
        -- Player team: Small circle above unit
        renderer:draw_filled_circle(
            x, y + offset_y, indicator_size,
            config.secondary_color, config.alpha
        )
    else
        -- Enemy team: Small diamond above unit
        local diamond_points = {
            x, y + offset_y - indicator_size,     -- Top
            x + indicator_size, y + offset_y,     -- Right
            x, y + offset_y + indicator_size,     -- Bottom
            x - indicator_size, y + offset_y      -- Left
        }
        renderer:draw_filled_polygon(diamond_points, config.secondary_color, config.alpha)
    end
end
-- }}}

-- {{{ local function render_health_bar
local function render_health_bar(renderer, position, health, unit_size)
    local x, y = position.x, position.y
    local bar_width = unit_size * 1.2
    local bar_height = 3
    local bar_y = y - unit_size/2 - 8
    
    local health_ratio = health.current / health.maximum
    
    -- Background bar
    renderer:draw_filled_rectangle(
        x - bar_width/2, bar_y, bar_width, bar_height,
        Colors.DARK_RED, 0.8
    )
    
    -- Health bar
    local health_width = bar_width * health_ratio
    local health_color = Colors.GREEN
    
    if health_ratio < 0.3 then
        health_color = Colors.RED
    elseif health_ratio < 0.6 then
        health_color = Colors.YELLOW
    end
    
    renderer:draw_filled_rectangle(
        x - bar_width/2, bar_y, health_width, bar_height,
        health_color, 1.0
    )
    
    -- Border
    renderer:draw_rectangle(
        x - bar_width/2, bar_y, bar_width, bar_height,
        Colors.BLACK, 1
    )
end
-- }}}

-- {{{ local function render_state_indicators
local function render_state_indicators(renderer, position, unit_data, config)
    local x, y = position.x, position.y
    local indicator_offset = config.size/2 + 3
    
    -- Movement indicator
    local moveable = EntityManager:get_component(unit_data.entity_id, "moveable")
    if moveable and moveable.is_moving then
        -- Small arrow indicating movement direction
        local arrow_size = 4
        local dir_x = moveable.velocity_x
        local dir_y = moveable.velocity_y
        local length = math.sqrt(dir_x*dir_x + dir_y*dir_y)
        
        if length > 0 then
            dir_x = dir_x / length
            dir_y = dir_y / length
            
            local arrow_x = x + dir_x * indicator_offset
            local arrow_y = y + dir_y * indicator_offset
            
            local arrow_points = {
                arrow_x + dir_x * arrow_size, arrow_y + dir_y * arrow_size,
                arrow_x - dir_x * arrow_size + dir_y * arrow_size/2, arrow_y - dir_y * arrow_size - dir_x * arrow_size/2,
                arrow_x - dir_x * arrow_size - dir_y * arrow_size/2, arrow_y - dir_y * arrow_size + dir_x * arrow_size/2
            }
            
            renderer:draw_filled_polygon(arrow_points, Colors.WHITE, 0.8)
        end
    end
    
    -- Combat state indicator
    if unit_data.state == "combat" then
        -- Small exclamation mark or flash effect
        renderer:draw_filled_circle(
            x + indicator_offset, y - indicator_offset, 2,
            Colors.YELLOW, 0.9
        )
    end
end
-- }}}
```

### Visual Design Features
1. **Shape-Based Types**: Squares for melee, triangles for ranged
2. **Team Indicators**: Circles for player, diamonds for enemy
3. **Health Visualization**: Color-coded health bars
4. **State Indicators**: Movement arrows and combat markers
5. **Colorblind Support**: Shapes as primary identifiers

### Accessibility Considerations
- Shapes are the primary visual distinction method
- Colors enhance but don't replace shape identification
- High contrast outlines for visibility
- Consistent visual language across all units

### Performance Optimization
- Batch rendering calls where possible
- Only render visible units
- Simple geometric shapes for efficiency
- Optional detail levels based on zoom

### Tool Suggestions
- Use Edit tool to enhance rendering system
- Test visual clarity with different unit configurations
- Verify colorblind accessibility
- Check performance with many units on screen

### Acceptance Criteria
- [ ] Melee units display as squares, ranged as triangles
- [ ] Team identification works without relying solely on color
- [ ] Health bars accurately represent unit status
- [ ] Visual indicators clearly show unit state
- [ ] Rendering performs well with many units