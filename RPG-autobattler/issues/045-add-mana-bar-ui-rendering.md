# Issue #404: Add Mana Bar UI Rendering

## Current Behavior
Mana system exists internally but lacks visual representation, making it impossible for players to understand unit ability states.

## Intended Behavior
Implement comprehensive mana bar UI rendering that clearly displays each unit's ability mana levels with colorblind-accessible design and tactical information.

## Implementation Details

### Enhanced Mana Bar Rendering (src/systems/mana_ui_system.lua)
```lua
-- {{{ ManaUISystem
local ManaUISystem = {}
ManaUISystem.__index = ManaUISystem

function ManaUISystem:new()
    local system = {
        -- Bar dimensions and positioning
        bar_width = 28,
        bar_height = 3,
        bar_spacing = 1,
        bar_offset_y = -18,
        
        -- Visual settings
        background_alpha = 0.7,
        border_alpha = 0.9,
        fill_alpha = 0.8,
        
        -- Animation settings
        pulse_duration = 0.5,
        ready_flash_duration = 0.3,
        generation_indicator_duration = 0.2,
        
        -- Colorblind accessibility
        use_patterns = true,
        use_shapes = true,
        show_ability_icons = true,
        
        -- Performance optimization
        render_distance = 200,
        detail_distance = 100,
        animation_timers = {}
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function ManaUISystem:render
function ManaUISystem:render(entity_manager, camera)
    love.graphics.push()
    
    for entity_id, mana_component in entity_manager:iterate_components("mana") do
        local position = entity_manager:get_component(entity_id, "position")
        local unit = entity_manager:get_component(entity_id, "unit")
        
        if position and unit then
            local screen_pos = camera:world_to_screen(position.value)
            local distance_to_camera = camera:distance_to(position.value)
            
            -- Only render if within visible range
            if distance_to_camera <= self.render_distance then
                local detail_level = self:get_detail_level(distance_to_camera)
                self:render_unit_mana_bars(screen_pos, mana_component, unit, detail_level)
            end
        end
    end
    
    love.graphics.pop()
end
-- }}}

-- {{{ function ManaUISystem:get_detail_level
function ManaUISystem:get_detail_level(distance)
    if distance <= self.detail_distance then
        return "high" -- Full detail with animations and patterns
    elseif distance <= self.render_distance * 0.7 then
        return "medium" -- Basic bars with colors
    else
        return "low" -- Simple colored dots
    end
end
-- }}}

-- {{{ function ManaUISystem:render_unit_mana_bars
function ManaUISystem:render_unit_mana_bars(screen_pos, mana_component, unit, detail_level)
    local num_abilities = #mana_component.abilities
    if num_abilities == 0 then return end
    
    if detail_level == "low" then
        self:render_simplified_indicators(screen_pos, mana_component)
        return
    end
    
    -- Calculate layout
    local total_height = (num_abilities * self.bar_height) + ((num_abilities - 1) * self.bar_spacing)
    local start_y = screen_pos.y + self.bar_offset_y - (total_height / 2)
    local start_x = screen_pos.x - (self.bar_width / 2)
    
    -- Render each ability's mana bar
    for i, ability in ipairs(mana_component.abilities) do
        local bar_y = start_y + ((i - 1) * (self.bar_height + self.bar_spacing))
        local mana_percentage = mana_component:get_mana_percentage(i)
        
        self:render_ability_mana_bar(
            start_x, bar_y, 
            mana_percentage, ability, i,
            detail_level, mana_component
        )
    end
    
    -- Render generation indicators if high detail
    if detail_level == "high" then
        self:render_generation_indicators(screen_pos, mana_component, unit)
    end
end
-- }}}

-- {{{ function ManaUISystem:render_ability_mana_bar
function ManaUISystem:render_ability_mana_bar(x, y, percentage, ability, ability_index, detail_level, mana_component)
    -- Get ability visual properties
    local colors = self:get_ability_colors(ability, percentage)
    local pattern = self:get_ability_pattern(ability)
    local is_ready = percentage >= 1.0
    local is_generating = self:is_ability_generating_mana(ability_index, mana_component)
    
    -- Animation effects
    local pulse_alpha = 1.0
    local flash_alpha = 1.0
    
    if is_ready then
        flash_alpha = self:get_ready_flash_alpha(ability_index)
    end
    
    if is_generating and detail_level == "high" then
        pulse_alpha = self:get_generation_pulse_alpha(ability_index)
    end
    
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.1, self.background_alpha * flash_alpha)
    love.graphics.rectangle("fill", x, y, self.bar_width, self.bar_height)
    
    -- Mana fill
    local fill_width = self.bar_width * percentage
    if fill_width > 0 then
        love.graphics.setColor(
            colors.fill.r, colors.fill.g, colors.fill.b, 
            self.fill_alpha * pulse_alpha * flash_alpha
        )
        
        if self.use_patterns and detail_level == "high" then
            self:render_patterned_fill(x, y, fill_width, self.bar_height, pattern)
        else
            love.graphics.rectangle("fill", x, y, fill_width, self.bar_height)
        end
    end
    
    -- Border
    love.graphics.setColor(colors.border.r, colors.border.g, colors.border.b, self.border_alpha)
    love.graphics.rectangle("line", x, y, self.bar_width, self.bar_height)
    
    -- Ability type indicator (for colorblind accessibility)
    if self.use_shapes and detail_level == "high" then
        self:render_ability_shape_indicator(x + self.bar_width + 2, y, ability)
    end
    
    -- Ready indicator
    if is_ready and detail_level == "high" then
        self:render_ready_indicator(x, y, ability)
    end
end
-- }}}

-- {{{ function ManaUISystem:get_ability_colors
function ManaUISystem:get_ability_colors(ability, percentage)
    local base_colors = {
        primary = {fill = {r = 0.2, g = 0.6, b = 1.0}, border = {r = 0.4, g = 0.8, b = 1.0}},
        damage = {fill = {r = 1.0, g = 0.2, b = 0.2}, border = {r = 1.0, g = 0.5, b = 0.5}},
        heal = {fill = {r = 0.2, g = 1.0, b = 0.2}, border = {r = 0.5, g = 1.0, b = 0.5}},
        buff = {fill = {r = 1.0, g = 1.0, b = 0.2}, border = {r = 1.0, g = 1.0, b = 0.5}},
        debuff = {fill = {r = 0.8, g = 0.2, b = 0.8}, border = {r = 1.0, g = 0.5, b = 1.0}},
        area = {fill = {r = 1.0, g = 0.5, b = 0.0}, border = {r = 1.0, g = 0.7, b = 0.3}}
    }
    
    local color_set = base_colors[ability.type] or base_colors.primary
    
    -- Dim colors when mana is low
    local dim_factor = math.max(0.3, percentage)
    
    return {
        fill = {
            r = color_set.fill.r * dim_factor,
            g = color_set.fill.g * dim_factor,
            b = color_set.fill.b * dim_factor
        },
        border = color_set.border
    }
end
-- }}}

-- {{{ function ManaUISystem:get_ability_pattern
function ManaUISystem:get_ability_pattern(ability)
    local patterns = {
        primary = "solid",
        damage = "diagonal_lines",
        heal = "cross_hatch",
        buff = "dots",
        debuff = "vertical_lines",
        area = "waves"
    }
    
    return patterns[ability.type] or "solid"
end
-- }}}

-- {{{ function ManaUISystem:render_patterned_fill
function ManaUISystem:render_patterned_fill(x, y, width, height, pattern)
    if pattern == "solid" then
        love.graphics.rectangle("fill", x, y, width, height)
    elseif pattern == "diagonal_lines" then
        self:render_diagonal_pattern(x, y, width, height)
    elseif pattern == "cross_hatch" then
        self:render_cross_hatch_pattern(x, y, width, height)
    elseif pattern == "dots" then
        self:render_dot_pattern(x, y, width, height)
    elseif pattern == "vertical_lines" then
        self:render_vertical_lines_pattern(x, y, width, height)
    elseif pattern == "waves" then
        self:render_wave_pattern(x, y, width, height)
    else
        love.graphics.rectangle("fill", x, y, width, height)
    end
end
-- }}}

-- {{{ function ManaUISystem:render_diagonal_pattern
function ManaUISystem:render_diagonal_pattern(x, y, width, height)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Add diagonal lines for visual distinction
    love.graphics.setColor(1, 1, 1, 0.3)
    local line_spacing = 2
    for i = 0, width + height, line_spacing do
        love.graphics.line(
            x + i, y,
            x + i - height, y + height
        )
    end
end
-- }}}

-- {{{ function ManaUISystem:render_cross_hatch_pattern
function ManaUISystem:render_cross_hatch_pattern(x, y, width, height)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Add cross-hatch pattern
    love.graphics.setColor(1, 1, 1, 0.2)
    local spacing = 1.5
    
    -- Horizontal lines
    for i = y, y + height, spacing do
        love.graphics.line(x, i, x + width, i)
    end
    
    -- Vertical lines
    for i = x, x + width, spacing do
        love.graphics.line(i, y, i, y + height)
    end
end
-- }}}

-- {{{ function ManaUISystem:render_dot_pattern
function ManaUISystem:render_dot_pattern(x, y, width, height)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Add dot pattern
    love.graphics.setColor(1, 1, 1, 0.4)
    local dot_spacing = 2
    local dot_size = 0.5
    
    for dot_x = x + 1, x + width - 1, dot_spacing do
        for dot_y = y + 1, y + height - 1, dot_spacing do
            love.graphics.circle("fill", dot_x, dot_y, dot_size)
        end
    end
end
-- }}}

-- {{{ function ManaUISystem:render_ability_shape_indicator
function ManaUISystem:render_ability_shape_indicator(x, y, ability)
    local shape_size = 2
    local center_x = x + shape_size
    local center_y = y + (self.bar_height / 2)
    
    love.graphics.setColor(1, 1, 1, 0.8)
    
    if ability.type == "damage" then
        -- Triangle for damage
        love.graphics.polygon("fill", 
            center_x, center_y - shape_size,
            center_x - shape_size, center_y + shape_size,
            center_x + shape_size, center_y + shape_size
        )
    elseif ability.type == "heal" then
        -- Cross for healing
        love.graphics.rectangle("fill", center_x - 0.5, center_y - shape_size, 1, shape_size * 2)
        love.graphics.rectangle("fill", center_x - shape_size, center_y - 0.5, shape_size * 2, 1)
    elseif ability.type == "buff" then
        -- Plus sign for buffs
        love.graphics.rectangle("fill", center_x - 0.5, center_y - shape_size, 1, shape_size * 2)
        love.graphics.rectangle("fill", center_x - shape_size, center_y - 0.5, shape_size * 2, 1)
    elseif ability.type == "debuff" then
        -- Minus sign for debuffs
        love.graphics.rectangle("fill", center_x - shape_size, center_y - 0.5, shape_size * 2, 1)
    elseif ability.type == "area" then
        -- Circle for area effects
        love.graphics.circle("line", center_x, center_y, shape_size)
    else
        -- Square for primary/unknown
        love.graphics.rectangle("fill", center_x - shape_size, center_y - shape_size, shape_size * 2, shape_size * 2)
    end
end
-- }}}

-- {{{ function ManaUISystem:render_simplified_indicators
function ManaUISystem:render_simplified_indicators(screen_pos, mana_component)
    -- For distant units, show simple colored dots
    local dot_size = 1.5
    local dot_spacing = 3
    local start_x = screen_pos.x - ((#mana_component.abilities * dot_spacing) / 2)
    local y = screen_pos.y + self.bar_offset_y
    
    for i, ability in ipairs(mana_component.abilities) do
        local x = start_x + ((i - 1) * dot_spacing)
        local percentage = mana_component:get_mana_percentage(i)
        local colors = self:get_ability_colors(ability, percentage)
        
        if percentage >= 1.0 then
            love.graphics.setColor(colors.fill.r, colors.fill.g, colors.fill.b, 1.0)
            love.graphics.circle("fill", x, y, dot_size)
        else
            love.graphics.setColor(colors.fill.r, colors.fill.g, colors.fill.b, 0.3)
            love.graphics.circle("line", x, y, dot_size)
        end
    end
end
-- }}}

-- {{{ function ManaUISystem:update_animations
function ManaUISystem:update_animations(dt)
    local current_time = love.timer.getTime()
    
    -- Update animation timers
    for ability_key, timer_data in pairs(self.animation_timers) do
        timer_data.elapsed = timer_data.elapsed + dt
    end
    
    -- Clean up expired timers
    for ability_key, timer_data in pairs(self.animation_timers) do
        if timer_data.elapsed > timer_data.duration then
            self.animation_timers[ability_key] = nil
        end
    end
end
-- }}}

-- {{{ function ManaUISystem:get_ready_flash_alpha
function ManaUISystem:get_ready_flash_alpha(ability_index)
    local timer_key = "ready_flash_" .. ability_index
    local timer_data = self.animation_timers[timer_key]
    
    if not timer_data then
        -- Start new flash animation
        self.animation_timers[timer_key] = {
            elapsed = 0,
            duration = self.ready_flash_duration
        }
        return 1.0
    end
    
    local progress = timer_data.elapsed / timer_data.duration
    return 0.7 + (0.3 * math.sin(progress * math.pi * 4)) -- Flash effect
end
-- }}}

-- {{{ function ManaUISystem:is_ability_generating_mana
function ManaUISystem:is_ability_generating_mana(ability_index, mana_component)
    if mana_component.generation_state and mana_component.generation_state[ability_index] then
        return mana_component.generation_state[ability_index].base_rate
    end
    return ability_index == 1 -- Primary ability always generates
end
-- }}}

return ManaUISystem
```

### Camera Integration (src/systems/camera.lua enhancement)
```lua
-- {{{ function Camera:world_to_screen
function Camera:world_to_screen(world_pos)
    return {
        x = (world_pos.x - self.position.x) * self.zoom + self.screen_width / 2,
        y = (world_pos.y - self.position.y) * self.zoom + self.screen_height / 2
    }
end
-- }}}

-- {{{ function Camera:distance_to
function Camera:distance_to(world_pos)
    return self.position:distance_to(world_pos)
end
-- }}}
```

### Settings Integration (src/utils/accessibility_settings.lua)
```lua
-- {{{ AccessibilitySettings
local AccessibilitySettings = {
    colorblind_mode = false,
    enhanced_patterns = true,
    large_ui_elements = false,
    high_contrast = false,
    reduce_animations = false
}

-- {{{ function AccessibilitySettings:apply_to_mana_ui
function AccessibilitySettings:apply_to_mana_ui(mana_ui_system)
    if self.colorblind_mode then
        mana_ui_system.use_patterns = true
        mana_ui_system.use_shapes = true
    end
    
    if self.large_ui_elements then
        mana_ui_system.bar_width = mana_ui_system.bar_width * 1.5
        mana_ui_system.bar_height = mana_ui_system.bar_height * 1.5
    end
    
    if self.reduce_animations then
        mana_ui_system.pulse_duration = 0
        mana_ui_system.ready_flash_duration = 0
    end
end
-- }}}

return AccessibilitySettings
```

### Performance Optimization Features
- Distance-based level of detail rendering
- Animation timer cleanup to prevent memory leaks
- Batch rendering of similar mana bars
- Culling of off-screen mana bars

### Acceptance Criteria
- [ ] All unit abilities display individual mana bars with distinct visual styles
- [ ] Colorblind accessibility through patterns and shapes
- [ ] Distance-based level of detail for performance
- [ ] Ready abilities have clear visual indicators
- [ ] Generating abilities show visual feedback
- [ ] Mana efficiency effects are visually represented
- [ ] UI scales appropriately with zoom levels
- [ ] Minimal performance impact with 100+ units visible