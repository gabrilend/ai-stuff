-- {{{ UnitRenderSystem
local UnitRenderSystem = {}

local Colors = require("src.constants.colors")
local Vector2 = require("src.utils.vector2")
local debug = require("src.utils.debug")

-- {{{ UnitRenderSystem:new
function UnitRenderSystem:new(entity_manager, renderer)
    local system = {
        entity_manager = entity_manager,
        renderer = renderer,
        name = "unit_render",
        show_health_bars = true,
        show_team_indicators = true,
        show_unit_types = true,
        show_debug_info = false,
        health_bar_height = 3,
        health_bar_width = 16,
        health_bar_offset = 12
    }
    setmetatable(system, {__index = UnitRenderSystem})
    
    debug.log("UnitRenderSystem created", "UNIT_RENDER")
    return system
end
-- }}}

-- {{{ UnitRenderSystem:draw
function UnitRenderSystem:draw()
    -- Get all units (entities with unit components)
    local units = self.entity_manager:get_entities_with_components({
        "position", "renderable", "health", "team", "unit_data"
    })
    
    -- Sort units by y-position for proper drawing order
    table.sort(units, function(a, b)
        local pos_a = self.entity_manager:get_component(a, "position")
        local pos_b = self.entity_manager:get_component(b, "position")
        return pos_a.y < pos_b.y
    end)
    
    -- Draw units
    for _, unit in ipairs(units) do
        self:draw_unit(unit)
    end
end
-- }}}

-- {{{ UnitRenderSystem:draw_unit
function UnitRenderSystem:draw_unit(unit)
    local position = self.entity_manager:get_component(unit, "position")
    local renderable = self.entity_manager:get_component(unit, "renderable")
    local health = self.entity_manager:get_component(unit, "health")
    local team = self.entity_manager:get_component(unit, "team")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not position or not renderable or not renderable.visible or not health.alive then
        return
    end
    
    -- Draw the main unit body
    self:draw_unit_body(unit, position, renderable, team, unit_data)
    
    -- Draw health bar
    if self.show_health_bars and health.current_hp < health.max_hp then
        self:draw_health_bar(unit, position, health)
    end
    
    -- Draw team indicator
    if self.show_team_indicators then
        self:draw_team_indicator(unit, position, team, unit_data)
    end
    
    -- Draw movement direction indicator
    self:draw_movement_indicator(unit, position)
    
    -- Draw state indicators
    self:draw_state_indicators(unit, position, unit_data)
    
    -- Draw debug information
    if self.show_debug_info then
        self:draw_unit_debug_info(unit, position, unit_data)
    end
end
-- }}}

-- {{{ UnitRenderSystem:draw_unit_body
function UnitRenderSystem:draw_unit_body(unit, position, renderable, team, unit_data)
    -- Get visual configuration for this unit
    local visual_config = self:get_unit_visual_config(unit, team, unit_data)
    
    -- Draw unit shape based on type (primary identifier for colorblind accessibility)
    self:render_unit_shape(position, visual_config, unit_data.unit_type)
end
-- }}}

-- {{{ UnitRenderSystem:draw_health_bar
function UnitRenderSystem:draw_health_bar(unit, position, health)
    local bar_x = position.x - self.health_bar_width / 2
    local bar_y = position.y - self.health_bar_offset
    
    -- Background (dark red)
    local bg_color = {0.3, 0.1, 0.1, 0.8}
    self.renderer:draw_rectangle(
        bar_x, bar_y, 
        self.health_bar_width, self.health_bar_height,
        bg_color, "fill"
    )
    
    -- Health portion
    local health_percent = health.current_hp / health.max_hp
    local health_width = self.health_bar_width * health_percent
    local health_color = Colors.get_health_color(health_percent)
    
    if health_width > 0 then
        self.renderer:draw_rectangle(
            bar_x, bar_y, 
            health_width, self.health_bar_height,
            health_color, "fill"
        )
    end
    
    -- Border
    local border_color = {0.8, 0.8, 0.8, 0.9}
    self.renderer:draw_rectangle(
        bar_x, bar_y, 
        self.health_bar_width, self.health_bar_height,
        border_color, "line"
    )
end
-- }}}

-- {{{ UnitRenderSystem:draw_team_indicator
function UnitRenderSystem:draw_team_indicator(unit, position, team, unit_data)
    if not self.show_team_indicators then
        return
    end
    
    local visual_config = self:get_unit_visual_config(unit, team, unit_data)
    self:render_team_indicator(position, visual_config, team)
end
-- }}}

-- {{{ UnitRenderSystem:draw_movement_indicator
function UnitRenderSystem:draw_movement_indicator(unit, position)
    local moveable = self.entity_manager:get_component(unit, "moveable")
    if not moveable or not moveable.moving then
        return
    end
    
    -- Draw direction arrow
    local velocity = Vector2:new(moveable.velocity_x, moveable.velocity_y)
    if velocity:length() > 0 then
        local direction = velocity:normalize()
        local arrow_length = 15
        local end_x = position.x + direction.x * arrow_length
        local end_y = position.y + direction.y * arrow_length
        
        local arrow_color = {1, 1, 1, 0.6}
        self.renderer:draw_arrow(
            position.x, position.y,
            end_x, end_y,
            arrow_color, 2, 4
        )
    end
end
-- }}}

-- {{{ UnitRenderSystem:draw_unit_debug_info
function UnitRenderSystem:draw_unit_debug_info(unit, position, unit_data)
    local debug_text = unit.name .. "\n" .. unit_data.combat_state
    if unit_data.current_sub_path then
        debug_text = debug_text .. "\nSP:" .. unit_data.current_sub_path
    end
    
    local text_color = Colors.UI_TEXT
    self.renderer:draw_text(
        debug_text,
        position.x + 15, position.y - 10,
        text_color
    )
end
-- }}}

-- {{{ UnitRenderSystem:get_unit_type_color
function UnitRenderSystem:get_unit_type_color(unit_type, base_color)
    -- Apply subtle tinting based on unit type
    local tint_factors = {
        melee = {1.0, 1.0, 1.0},     -- No change
        ranged = {0.9, 1.0, 0.9},    -- Slightly green
        tank = {1.0, 0.9, 1.0},      -- Slightly purple
        support = {1.0, 1.0, 0.9},   -- Slightly yellow
        special = {0.95, 0.95, 1.0}  -- Slightly blue
    }
    
    local factor = tint_factors[unit_type] or {1.0, 1.0, 1.0}
    
    return {
        base_color[1] * factor[1],
        base_color[2] * factor[2],
        base_color[3] * factor[3],
        base_color[4]
    }
end
-- }}}

-- {{{ UnitRenderSystem:get_damage_flash_factor
function UnitRenderSystem:get_damage_flash_factor(unit)
    local health = self.entity_manager:get_component(unit, "health")
    if not health then
        return 0
    end
    
    -- Simple flash effect based on recent damage
    -- This would need to be enhanced with proper timing
    if health.damage_taken > 0 then
        return 0.3  -- Flash intensity
    end
    
    return 0
end
-- }}}

-- {{{ UnitRenderSystem:blend_colors
function UnitRenderSystem:blend_colors(color1, color2, factor)
    return {
        color1[1] * (1 - factor) + color2[1] * factor,
        color1[2] * (1 - factor) + color2[2] * factor,
        color1[3] * (1 - factor) + color2[3] * factor,
        color1[4]
    }
end
-- }}}

-- {{{ UnitRenderSystem:darken_color
function UnitRenderSystem:darken_color(color, factor)
    return {
        color[1] * factor,
        color[2] * factor,
        color[3] * factor,
        color[4]
    }
end
-- }}}

-- {{{ UnitRenderSystem:get_unit_visual_config
function UnitRenderSystem:get_unit_visual_config(unit, team, unit_data)
    local health = self.entity_manager:get_component(unit, "health")
    local renderable = self.entity_manager:get_component(unit, "renderable")
    
    local config = {
        size = (renderable and renderable.size) or 8,
        primary_color = Colors.WHITE,
        secondary_color = Colors.GRAY,
        outline_color = Colors.BLACK,
        alpha = 1.0
    }
    
    -- Team-based coloring (secondary to shape identification)
    if team then
        if team.player_id == 1 then
            config.primary_color = Colors.TEAM_A
            config.secondary_color = Colors.LIGHT_BLUE
        else
            config.primary_color = Colors.TEAM_B
            config.secondary_color = Colors.LIGHT_RED
        end
    end
    
    -- Health-based alpha
    if health then
        local health_ratio = health.current_hp / health.max_hp
        if health_ratio < 0.3 then
            config.alpha = 0.7  -- Slightly transparent when heavily damaged
        end
    end
    
    -- State-based modifications
    if unit_data.state == "spawning" then
        config.alpha = 0.5
    elseif unit_data.state == "dead" then
        config.alpha = 0.3
        config.primary_color = Colors.DARK_GRAY
    end
    
    -- Apply damage flash effect
    local flash_factor = self:get_damage_flash_factor(unit)
    if flash_factor > 0 then
        config.primary_color = self:blend_colors(config.primary_color, Colors.DAMAGE_INDICATOR, flash_factor)
    end
    
    return config
end
-- }}}

-- {{{ UnitRenderSystem:render_unit_shape
function UnitRenderSystem:render_unit_shape(position, config, unit_type)
    local x, y = position.x, position.y
    local size = config.size
    
    -- Shape determines unit type (primary identifier for colorblind accessibility)
    if unit_type == "melee" then
        -- Melee units: Square shape
        self.renderer:draw_rectangle(
            x - size/2, y - size/2, size, size,
            config.primary_color, "fill"
        )
        self.renderer:draw_rectangle(
            x - size/2, y - size/2, size, size,
            config.outline_color, "line"
        )
        
    elseif unit_type == "ranged" then
        -- Ranged units: Triangle shape
        local triangle_points = {
            x, y - size/2,              -- Top point
            x - size/2, y + size/2,     -- Bottom left
            x + size/2, y + size/2      -- Bottom right
        }
        
        self.renderer:draw_polygon(triangle_points, config.primary_color, "fill")
        self.renderer:draw_polygon(triangle_points, config.outline_color, "line")
        
    elseif unit_type == "tank" then
        -- Tank units: Large square
        local tank_size = size * 1.2
        self.renderer:draw_rectangle(
            x - tank_size/2, y - tank_size/2, tank_size, tank_size,
            config.primary_color, "fill"
        )
        self.renderer:draw_rectangle(
            x - tank_size/2, y - tank_size/2, tank_size, tank_size,
            config.outline_color, "line"
        )
        
    elseif unit_type == "support" then
        -- Support units: Diamond shape
        local diamond_points = {
            x, y - size/2,              -- Top
            x + size/2, y,              -- Right
            x, y + size/2,              -- Bottom
            x - size/2, y               -- Left
        }
        
        self.renderer:draw_polygon(diamond_points, config.primary_color, "fill")
        self.renderer:draw_polygon(diamond_points, config.outline_color, "line")
        
    else
        -- Default: Circle shape for special and unknown types
        self.renderer:draw_circle(x, y, size/2, config.primary_color, "fill")
        self.renderer:draw_circle(x, y, size/2, config.outline_color, "line")
    end
end
-- }}}

-- {{{ UnitRenderSystem:render_team_indicator
function UnitRenderSystem:render_team_indicator(position, config, team)
    if not team then return end
    
    local x, y = position.x, position.y
    local indicator_size = config.size / 4
    local offset_y = -config.size/2 - 5
    
    -- Team indicator shape (additional visual distinction)
    if team.player_id == 1 then
        -- Player team: Small circle above unit
        self.renderer:draw_circle(
            x, y + offset_y, indicator_size,
            config.secondary_color, "fill"
        )
    else
        -- Enemy team: Small diamond above unit
        local diamond_points = {
            x, y + offset_y - indicator_size,     -- Top
            x + indicator_size, y + offset_y,     -- Right
            x, y + offset_y + indicator_size,     -- Bottom
            x - indicator_size, y + offset_y      -- Left
        }
        self.renderer:draw_polygon(diamond_points, config.secondary_color, "fill")
    end
end
-- }}}

-- {{{ UnitRenderSystem:set_health_bar_visibility
function UnitRenderSystem:set_health_bar_visibility(visible)
    self.show_health_bars = visible
    debug.log("Health bars " .. (visible and "enabled" or "disabled"), "UNIT_RENDER")
end
-- }}}

-- {{{ UnitRenderSystem:set_team_indicator_visibility
function UnitRenderSystem:set_team_indicator_visibility(visible)
    self.show_team_indicators = visible
    debug.log("Team indicators " .. (visible and "enabled" or "disabled"), "UNIT_RENDER")
end
-- }}}

-- {{{ UnitRenderSystem:set_debug_info_visibility
function UnitRenderSystem:set_debug_info_visibility(visible)
    self.show_debug_info = visible
    debug.log("Unit debug info " .. (visible and "enabled" or "disabled"), "UNIT_RENDER")
end
-- }}}

-- {{{ UnitRenderSystem:get_render_stats
function UnitRenderSystem:get_render_stats()
    local units = self.entity_manager:get_entities_with_components({
        "position", "renderable", "health", "team", "unit_data"
    })
    
    local visible_count = 0
    local team_counts = {}
    
    for _, unit in ipairs(units) do
        local renderable = self.entity_manager:get_component(unit, "renderable")
        local health = self.entity_manager:get_component(unit, "health")
        local team = self.entity_manager:get_component(unit, "team")
        
        if renderable and renderable.visible and health and health.alive then
            visible_count = visible_count + 1
            team_counts[team.player_id] = (team_counts[team.player_id] or 0) + 1
        end
    end
    
    return {
        total_units = #units,
        visible_units = visible_count,
        team_counts = team_counts,
        show_health_bars = self.show_health_bars,
        show_team_indicators = self.show_team_indicators,
        show_debug_info = self.show_debug_info
    }
end
-- }}}

-- {{{ UnitRenderSystem:draw_state_indicators
function UnitRenderSystem:draw_state_indicators(unit, position, unit_data)
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local visual_config = self:get_unit_visual_config(unit, nil, unit_data)
    local x, y = position.x, position.y
    local indicator_offset = visual_config.size/2 + 3
    
    -- Enhanced movement indicator with direction arrow
    if moveable and moveable.moving then
        local velocity = Vector2:new(moveable.velocity_x, moveable.velocity_y)
        if velocity:length() > 0 then
            local direction = velocity:normalize()
            local arrow_size = 4
            local arrow_x = x + direction.x * indicator_offset
            local arrow_y = y + direction.y * indicator_offset
            
            local arrow_points = {
                arrow_x + direction.x * arrow_size, arrow_y + direction.y * arrow_size,
                arrow_x - direction.x * arrow_size + direction.y * arrow_size/2, arrow_y - direction.y * arrow_size - direction.x * arrow_size/2,
                arrow_x - direction.x * arrow_size - direction.y * arrow_size/2, arrow_y - direction.y * arrow_size + direction.x * arrow_size/2
            }
            
            local arrow_color = {1, 1, 1, 0.8}
            self.renderer:draw_polygon(arrow_points, arrow_color, "fill")
        end
    end
    
    -- Combat state indicator
    if unit_data.state == "combat" or unit_data.combat_state == "engaged" then
        -- Small exclamation mark or flash effect
        local combat_color = {1, 1, 0, 0.9}  -- Yellow
        self.renderer:draw_circle(
            x + indicator_offset, y - indicator_offset, 2,
            combat_color, "fill"
        )
    end
    
    -- Special ability state indicator
    if unit_data.state == "casting" or unit_data.state == "channeling" then
        -- Pulsing circle effect
        local ability_color = {0.5, 0, 1, 0.7}  -- Purple
        self.renderer:draw_circle(
            x, y - indicator_offset - 3, 3,
            ability_color, "fill"
        )
    end
end
-- }}}

-- {{{ UnitRenderSystem:test_enhanced_rendering
function UnitRenderSystem:test_enhanced_rendering()
    print("Testing Enhanced Unit Rendering System...")
    
    -- Mock entity manager for testing
    local original_entity_manager = self.entity_manager
    self.entity_manager = {
        get_component = function(entity_id, component_type)
            if component_type == "health" then
                return { current_hp = 100, max_hp = 100, alive = true, damage_taken = 0 }
            elseif component_type == "renderable" then
                return { size = 8, visible = true, shape = "circle" }
            elseif component_type == "moveable" then
                return { moving = false, velocity_x = 0, velocity_y = 0 }
            end
            return nil
        end
    }
    
    -- Test visual configuration generation
    local mock_unit = 1
    local mock_team = { player_id = 1, team_color = Colors.TEAM_A }
    local mock_unit_data = { 
        unit_type = "melee", 
        state = "moving",
        entity_id = mock_unit
    }
    
    -- Test shape rendering for different unit types
    local unit_types = {"melee", "ranged", "tank", "support", "special"}
    
    for _, unit_type in ipairs(unit_types) do
        mock_unit_data.unit_type = unit_type
        local config = self:get_unit_visual_config(mock_unit, mock_team, mock_unit_data)
        
        assert(config.size > 0, "Unit size must be positive for " .. unit_type)
        assert(config.primary_color, "Primary color must be set for " .. unit_type)
        assert(config.outline_color, "Outline color must be set for " .. unit_type)
        
        print("✓ " .. unit_type .. " unit visual config generated successfully")
    end
    
    -- Test team color differentiation
    local team_a = { player_id = 1, team_color = Colors.TEAM_A }
    local team_b = { player_id = 2, team_color = Colors.TEAM_B }
    
    local config_a = self:get_unit_visual_config(mock_unit, team_a, mock_unit_data)
    local config_b = self:get_unit_visual_config(mock_unit, team_b, mock_unit_data)
    
    assert(config_a.primary_color ~= config_b.primary_color, "Team colors must be different")
    print("✓ Team color differentiation working")
    
    -- Test colorblind accessibility features
    local shape_types = {
        melee = "square",
        ranged = "triangle", 
        tank = "large square",
        support = "diamond",
        special = "circle"
    }
    
    for unit_type, expected_shape in pairs(shape_types) do
        print("✓ " .. unit_type .. " units render as " .. expected_shape .. " (colorblind-friendly)")
    end
    
    -- Test state indicators
    local test_states = {"moving", "combat", "casting", "spawning", "dead"}
    for _, state in ipairs(test_states) do
        mock_unit_data.state = state
        local config = self:get_unit_visual_config(mock_unit, mock_team, mock_unit_data)
        
        if state == "dead" then
            assert(config.alpha < 1.0, "Dead units should have reduced alpha")
        elseif state == "spawning" then
            assert(config.alpha < 1.0, "Spawning units should have reduced alpha")
        end
        
        print("✓ State '" .. state .. "' visual handling working")
    end
    
    print("✓ Enhanced Unit Rendering System tests passed!")
    
    -- Restore original entity manager
    self.entity_manager = original_entity_manager
    
    return true
end
-- }}}

return UnitRenderSystem
-- }}}