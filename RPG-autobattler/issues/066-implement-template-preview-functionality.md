# Issue #510: Implement Template Preview Functionality

## Current Behavior
Template editor lacks real-time preview capabilities to show how units will look and perform in actual gameplay.

## Intended Behavior
Create comprehensive template preview system with visual unit representation, stat comparisons, combat simulations, and effectiveness predictions.

## Implementation Details

### Template Preview Manager (src/ui/components/template_preview.lua)
```lua
-- {{{ TemplatePreview
local TemplatePreview = {}
TemplatePreview.__index = TemplatePreview

function TemplatePreview:new(template_editor)
    local preview = {
        template_editor = template_editor,
        
        -- Preview modes
        current_mode = "visual", -- visual, stats, combat, comparison
        available_modes = {"visual", "stats", "combat", "comparison"},
        
        -- Preview state
        current_template = nil,
        comparison_template = nil,
        preview_unit = nil,
        
        -- Visual preview
        visual_preview = {
            bounds = {x = 20, y = 100, width = 300, height = 200},
            unit_position = {x = 170, y = 200},
            zoom_level = 1.0,
            rotation = 0,
            animation_timer = 0,
            show_stats = true,
            show_abilities = true
        },
        
        -- Stats preview
        stats_preview = {
            bounds = {x = 340, y = 100, width = 280, height = 400},
            categories = {"combat", "survivability", "utility", "mobility"},
            comparison_enabled = false
        },
        
        -- Combat simulation
        combat_sim = {
            bounds = {x = 640, y = 100, width = 300, height = 400},
            simulation_running = false,
            simulation_results = {},
            test_scenarios = {"vs_basic_warrior", "vs_basic_archer", "vs_balanced_team"}
        },
        
        -- UI components
        mode_tabs = {},
        comparison_selector = nil,
        
        -- Performance tracking
        last_update_time = 0,
        update_interval = 0.1 -- Update 10 times per second
    }
    
    preview:initialize_ui()
    setmetatable(preview, self)
    return preview
end
-- }}}

-- {{{ function TemplatePreview:initialize_ui
function TemplatePreview:initialize_ui()
    -- Create mode tabs
    local tab_width = 70
    local tab_height = 30
    
    for i, mode in ipairs(self.available_modes) do
        local tab_x = 20 + (i - 1) * (tab_width + 5)
        
        self.mode_tabs[mode] = {
            bounds = {x = tab_x, y = 60, width = tab_width, height = tab_height},
            active = mode == self.current_mode,
            label = string.upper(string.sub(mode, 1, 1)) .. string.sub(mode, 2)
        }
    end
    
    -- Initialize comparison selector
    self.comparison_selector = {
        bounds = {x = 400, y = 60, width = 150, height = 30},
        selected_template = nil,
        dropdown_open = false,
        available_templates = {}
    }
    
    self:refresh_comparison_templates()
end
-- }}}

-- {{{ function TemplatePreview:update_template
function TemplatePreview:update_template(template)
    self.current_template = template
    
    if template then
        self:create_preview_unit()
        self:update_stats_analysis()
        self:schedule_combat_simulation()
    else
        self:clear_preview()
    end
end
-- }}}

-- {{{ function TemplatePreview:create_preview_unit
function TemplatePreview:create_preview_unit()
    if not self.current_template then return end
    
    -- Create a mock unit entity for preview
    self.preview_unit = {
        template = self.current_template,
        position = {x = self.visual_preview.unit_position.x, y = self.visual_preview.unit_position.y},
        health = {current = self.current_template.stats.health, max = self.current_template.stats.health},
        mana_bars = {},
        visual_effects = {},
        
        -- Animation state
        idle_animation = {
            timer = 0,
            phase = 0,
            breathing_intensity = 0.05
        },
        
        -- Preview-specific properties
        show_range_indicators = true,
        show_ability_previews = true,
        highlight_stats = false
    }
    
    -- Initialize mana bars for abilities
    for i, ability in ipairs(self.current_template.abilities or {}) do
        self.preview_unit.mana_bars[i] = {
            current = ability.max_mana or 100,
            max = ability.max_mana or 100,
            generation_rate = ability.mana_rate or 10,
            preview_mode = true
        }
    end
end
-- }}}

-- {{{ function TemplatePreview:update_stats_analysis
function TemplatePreview:update_stats_analysis()
    if not self.current_template then return end
    
    local BalanceCalculator = require("src.systems.balance_calculator")
    local calculator = BalanceCalculator:new()
    
    self.stats_analysis = calculator:calculate_combat_effectiveness(self.current_template)
    
    -- Add detailed breakdowns
    self.stats_analysis.detailed = {
        combat = {
            dps = self.stats_analysis.dps,
            burst_damage = self:calculate_burst_damage(),
            sustained_damage = self:calculate_sustained_damage(),
            damage_types = self:analyze_damage_types()
        },
        
        survivability = {
            effective_hp = self.stats_analysis.survivability,
            damage_reduction = self:calculate_damage_reduction(),
            healing_potential = self:calculate_healing_potential(),
            escape_potential = self:calculate_escape_potential()
        },
        
        utility = {
            support_value = self.stats_analysis.utility,
            crowd_control = self:calculate_crowd_control(),
            buff_potential = self:calculate_buff_potential(),
            area_coverage = self:calculate_area_coverage()
        },
        
        mobility = {
            movement_score = self.stats_analysis.mobility,
            positioning_flexibility = self:calculate_positioning_flexibility(),
            engagement_range = self.current_template.stats.detection_range,
            retreat_capability = self:calculate_retreat_capability()
        }
    }
end
-- }}}

-- {{{ function TemplatePreview:calculate_burst_damage
function TemplatePreview:calculate_burst_damage()
    local burst = 0
    
    for _, ability in ipairs(self.current_template.abilities or {}) do
        if ability.effect_type == "damage" then
            burst = burst + (ability.base_value or 0)
        end
    end
    
    return burst
end
-- }}}

-- {{{ function TemplatePreview:calculate_sustained_damage
function TemplatePreview:calculate_sustained_damage()
    local sustained = 0
    
    for _, ability in ipairs(self.current_template.abilities or {}) do
        if ability.effect_type == "damage" then
            local damage_per_cast = ability.base_value or 0
            local cooldown = ability.cooldown or 0
            local mana_cycle = (ability.max_mana or 100) / (ability.mana_rate or 10)
            local effective_cooldown = math.max(cooldown, mana_cycle)
            
            if effective_cooldown > 0 then
                sustained = sustained + (damage_per_cast / effective_cooldown)
            end
        end
    end
    
    return sustained
end
-- }}}

-- {{{ function TemplatePreview:analyze_damage_types
function TemplatePreview:analyze_damage_types()
    local types = {
        single_target = 0,
        area_effect = 0,
        piercing = 0,
        status_effects = 0
    }
    
    for _, ability in ipairs(self.current_template.abilities or {}) do
        if ability.effect_type == "damage" then
            if ability.area_radius and ability.area_radius > 0 then
                types.area_effect = types.area_effect + 1
            else
                types.single_target = types.single_target + 1
            end
            
            if ability.piercing then
                types.piercing = types.piercing + 1
            end
            
            if ability.status_effect then
                types.status_effects = types.status_effects + 1
            end
        end
    end
    
    return types
end
-- }}}

-- {{{ function TemplatePreview:schedule_combat_simulation
function TemplatePreview:schedule_combat_simulation()
    -- Mark simulation as needing update
    self.combat_sim.simulation_running = false
    self.combat_sim.simulation_results = {}
    
    -- Will be updated in next update cycle if combat mode is active
end
-- }}}

-- {{{ function TemplatePreview:run_combat_simulation
function TemplatePreview:run_combat_simulation()
    if not self.current_template then return end
    
    self.combat_sim.simulation_running = true
    self.combat_sim.simulation_results = {}
    
    -- Run simulations against test scenarios
    for _, scenario in ipairs(self.combat_sim.test_scenarios) do
        local result = self:simulate_combat_scenario(scenario)
        self.combat_sim.simulation_results[scenario] = result
    end
    
    self.combat_sim.simulation_running = false
end
-- }}}

-- {{{ function TemplatePreview:simulate_combat_scenario
function TemplatePreview:simulate_combat_scenario(scenario_name)
    -- Simplified combat simulation
    local opponent_template = self:get_scenario_opponent(scenario_name)
    if not opponent_template then
        return {error = "Unknown scenario"}
    end
    
    local our_effectiveness = self.stats_analysis.total_score
    local their_effectiveness = self:calculate_opponent_effectiveness(opponent_template)
    
    local win_probability = our_effectiveness / (our_effectiveness + their_effectiveness)
    local estimated_time = self:estimate_combat_duration(our_effectiveness, their_effectiveness)
    
    return {
        scenario = scenario_name,
        win_probability = win_probability,
        estimated_duration = estimated_time,
        our_score = our_effectiveness,
        their_score = their_effectiveness,
        key_factors = self:analyze_combat_factors(opponent_template)
    }
end
-- }}}

-- {{{ function TemplatePreview:get_scenario_opponent
function TemplatePreview:get_scenario_opponent(scenario_name)
    local DefaultTemplateFactory = require("src.factories.default_template_factory")
    local factory = DefaultTemplateFactory:new()
    
    local scenario_mapping = {
        vs_basic_warrior = "Basic Warrior",
        vs_basic_archer = "Basic Archer",
        vs_balanced_team = "Basic Guardian" -- Simplified for single unit
    }
    
    local template_name = scenario_mapping[scenario_name]
    if template_name then
        local templates = factory:create_all_default_templates()
        for _, template in ipairs(templates) do
            if template.name == template_name then
                return template
            end
        end
    end
    
    return nil
end
-- }}}

-- {{{ function TemplatePreview:switch_mode
function TemplatePreview:switch_mode(new_mode)
    if not self.available_modes then return end
    
    for _, mode in ipairs(self.available_modes) do
        if mode == new_mode then
            self.current_mode = new_mode
            
            -- Update tab states
            for mode_name, tab in pairs(self.mode_tabs) do
                tab.active = mode_name == new_mode
            end
            
            -- Trigger mode-specific updates
            if new_mode == "combat" and not self.combat_sim.simulation_running then
                self:run_combat_simulation()
            end
            
            break
        end
    end
end
-- }}}

-- {{{ function TemplatePreview:set_comparison_template
function TemplatePreview:set_comparison_template(template)
    self.comparison_template = template
    self.stats_preview.comparison_enabled = template ~= nil
    
    if template then
        self:update_comparison_analysis()
    end
end
-- }}}

-- {{{ function TemplatePreview:update_comparison_analysis
function TemplatePreview:update_comparison_analysis()
    if not self.comparison_template or not self.current_template then return end
    
    local BalanceCalculator = require("src.systems.balance_calculator")
    local calculator = BalanceCalculator:new()
    
    self.comparison_analysis = {
        our_template = calculator:calculate_combat_effectiveness(self.current_template),
        their_template = calculator:calculate_combat_effectiveness(self.comparison_template),
        differences = {}
    }
    
    -- Calculate differences in each category
    self.comparison_analysis.differences = {
        dps = self.comparison_analysis.our_template.dps - self.comparison_analysis.their_template.dps,
        survivability = self.comparison_analysis.our_template.survivability - self.comparison_analysis.their_template.survivability,
        utility = self.comparison_analysis.our_template.utility - self.comparison_analysis.their_template.utility,
        mobility = self.comparison_analysis.our_template.mobility - self.comparison_analysis.their_template.mobility,
        total = self.comparison_analysis.our_template.total_score - self.comparison_analysis.their_template.total_score
    }
end
-- }}}

-- {{{ function TemplatePreview:update
function TemplatePreview:update(dt)
    local current_time = love.timer.getTime()
    
    -- Throttle updates for performance
    if current_time - self.last_update_time < self.update_interval then
        return
    end
    self.last_update_time = current_time
    
    -- Update animations
    if self.preview_unit then
        self:update_preview_animations(dt)
    end
    
    -- Update mana bars
    if self.preview_unit and self.preview_unit.mana_bars then
        self:update_preview_mana_bars(dt)
    end
    
    -- Update visual effects
    self.visual_preview.animation_timer = self.visual_preview.animation_timer + dt
end
-- }}}

-- {{{ function TemplatePreview:update_preview_animations
function TemplatePreview:update_preview_animations(dt)
    if not self.preview_unit then return end
    
    local anim = self.preview_unit.idle_animation
    anim.timer = anim.timer + dt
    anim.phase = math.sin(anim.timer * 2) * anim.breathing_intensity
    
    -- Update position for breathing effect
    self.preview_unit.position.y = self.visual_preview.unit_position.y + anim.phase * 5
end
-- }}}

-- {{{ function TemplatePreview:update_preview_mana_bars
function TemplatePreview:update_preview_mana_bars(dt)
    for i, mana_bar in pairs(self.preview_unit.mana_bars) do
        if mana_bar.preview_mode then
            -- Simulate mana generation
            if mana_bar.current < mana_bar.max then
                mana_bar.current = math.min(mana_bar.max, 
                    mana_bar.current + mana_bar.generation_rate * dt)
            else
                -- Reset for continuous preview
                mana_bar.current = 0
            end
        end
    end
end
-- }}}

-- {{{ function TemplatePreview:render
function TemplatePreview:render()
    -- Render mode tabs
    self:render_mode_tabs()
    
    -- Render comparison selector
    if self.current_mode == "comparison" or self.stats_preview.comparison_enabled then
        self:render_comparison_selector()
    end
    
    -- Render current mode content
    if self.current_mode == "visual" then
        self:render_visual_preview()
    elseif self.current_mode == "stats" then
        self:render_stats_preview()
    elseif self.current_mode == "combat" then
        self:render_combat_preview()
    elseif self.current_mode == "comparison" then
        self:render_comparison_preview()
    end
end
-- }}}

-- {{{ function TemplatePreview:render_mode_tabs
function TemplatePreview:render_mode_tabs()
    for mode_name, tab in pairs(self.mode_tabs) do
        local bounds = tab.bounds
        
        -- Background
        local bg_color = tab.active and {0.3, 0.3, 0.5, 1.0} or {0.2, 0.2, 0.2, 1.0}
        love.graphics.setColor(bg_color)
        love.graphics.rectangle("fill", bounds.x, bounds.y, bounds.width, bounds.height)
        
        -- Text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(tab.label, bounds.x + 5, bounds.y + 8)
        
        -- Border
        love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
        love.graphics.rectangle("line", bounds.x, bounds.y, bounds.width, bounds.height)
    end
end
-- }}}

-- {{{ function TemplatePreview:render_visual_preview
function TemplatePreview:render_visual_preview()
    local bounds = self.visual_preview.bounds
    
    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 1.0)
    love.graphics.rectangle("fill", bounds.x, bounds.y, bounds.width, bounds.height)
    
    if self.preview_unit and self.current_template then
        -- Render unit
        self:render_preview_unit()
        
        -- Render range indicators
        if self.visual_preview.show_range_indicators then
            self:render_range_indicators()
        end
        
        -- Render mana bars
        if self.visual_preview.show_abilities then
            self:render_preview_mana_bars()
        end
        
        -- Render stat overlay
        if self.visual_preview.show_stats then
            self:render_stat_overlay()
        end
    else
        -- No template message
        love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
        love.graphics.print("No template selected", bounds.x + 20, bounds.y + 100)
    end
    
    -- Border
    love.graphics.setColor(0.4, 0.4, 0.4, 1.0)
    love.graphics.rectangle("line", bounds.x, bounds.y, bounds.width, bounds.height)
end
-- }}}

-- {{{ function TemplatePreview:render_preview_unit
function TemplatePreview:render_preview_unit()
    if not self.preview_unit or not self.current_template then return end
    
    local unit_pos = self.preview_unit.position
    local appearance = self.current_template.appearance or {}
    local size = 25 * (appearance.size_modifier or 1.0) * self.visual_preview.zoom_level
    
    -- Set color
    local primary_color = appearance.primary_color or {0.5, 0.5, 0.8}
    love.graphics.setColor(primary_color)
    
    -- Draw shape based on type
    local shape = appearance.shape or "circle"
    
    if shape == "circle" then
        love.graphics.circle("fill", unit_pos.x, unit_pos.y, size)
    elseif shape == "square" then
        love.graphics.rectangle("fill", unit_pos.x - size, unit_pos.y - size, size * 2, size * 2)
    elseif shape == "triangle" then
        love.graphics.polygon("fill",
            unit_pos.x, unit_pos.y - size,
            unit_pos.x - size, unit_pos.y + size,
            unit_pos.x + size, unit_pos.y + size)
    elseif shape == "hexagon" then
        self:draw_hexagon(unit_pos.x, unit_pos.y, size)
    end
    
    -- Draw border
    local secondary_color = appearance.secondary_color or {0.3, 0.3, 0.6}
    love.graphics.setColor(secondary_color)
    love.graphics.setLineWidth(2)
    
    if shape == "circle" then
        love.graphics.circle("line", unit_pos.x, unit_pos.y, size)
    elseif shape == "square" then
        love.graphics.rectangle("line", unit_pos.x - size, unit_pos.y - size, size * 2, size * 2)
    elseif shape == "triangle" then
        love.graphics.polygon("line",
            unit_pos.x, unit_pos.y - size,
            unit_pos.x - size, unit_pos.y + size,
            unit_pos.x + size, unit_pos.y + size)
    elseif shape == "hexagon" then
        self:draw_hexagon_outline(unit_pos.x, unit_pos.y, size)
    end
    
    love.graphics.setLineWidth(1)
end
-- }}}

-- {{{ function TemplatePreview:render_range_indicators
function TemplatePreview:render_range_indicators()
    if not self.preview_unit or not self.current_template then return end
    
    local unit_pos = self.preview_unit.position
    local detection_range = self.current_template.stats.detection_range or 60
    local zoom = self.visual_preview.zoom_level
    
    -- Detection range circle
    love.graphics.setColor(0.8, 0.8, 0.2, 0.2)
    love.graphics.circle("fill", unit_pos.x, unit_pos.y, detection_range * zoom * 0.5)
    
    love.graphics.setColor(0.8, 0.8, 0.2, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", unit_pos.x, unit_pos.y, detection_range * zoom * 0.5)
    
    -- Ability ranges
    for i, ability in ipairs(self.current_template.abilities or {}) do
        if ability.range then
            local range_color = {0.8, 0.3, 0.3, 0.3}
            if ability.effect_type == "heal" then
                range_color = {0.3, 0.8, 0.3, 0.3}
            elseif ability.effect_type == "buff" then
                range_color = {0.3, 0.3, 0.8, 0.3}
            end
            
            love.graphics.setColor(range_color)
            love.graphics.circle("line", unit_pos.x, unit_pos.y, ability.range * zoom * 0.5)
        end
    end
    
    love.graphics.setLineWidth(1)
end
-- }}}

-- {{{ function TemplatePreview:render_preview_mana_bars
function TemplatePreview:render_preview_mana_bars()
    if not self.preview_unit or not self.preview_unit.mana_bars then return end
    
    local unit_pos = self.preview_unit.position
    local bar_width = 40
    local bar_height = 4
    local bar_spacing = 2
    local num_bars = 0
    
    -- Count mana bars
    for _, _ in pairs(self.preview_unit.mana_bars) do
        num_bars = num_bars + 1
    end
    
    local total_height = (num_bars * bar_height) + ((num_bars - 1) * bar_spacing)
    local start_y = unit_pos.y - 40 - (total_height / 2)
    
    local bar_index = 0
    for i, mana_bar in pairs(self.preview_unit.mana_bars) do
        local bar_y = start_y + (bar_index * (bar_height + bar_spacing))
        local mana_percentage = mana_bar.current / mana_bar.max
        
        -- Background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", unit_pos.x - (bar_width / 2), bar_y, bar_width, bar_height)
        
        -- Mana fill
        local fill_width = bar_width * mana_percentage
        local ability = self.current_template.abilities[i]
        local ability_color = self:get_ability_color(ability)
        
        love.graphics.setColor(ability_color.r, ability_color.g, ability_color.b, 0.9)
        love.graphics.rectangle("fill", unit_pos.x - (bar_width / 2), bar_y, fill_width, bar_height)
        
        -- Border
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.rectangle("line", unit_pos.x - (bar_width / 2), bar_y, bar_width, bar_height)
        
        bar_index = bar_index + 1
    end
end
-- }}}

-- {{{ function TemplatePreview:get_ability_color
function TemplatePreview:get_ability_color(ability)
    if not ability then return {r = 0.5, g = 0.5, b = 0.5} end
    
    local ability_colors = {
        damage = {r = 1.0, g = 0.3, b = 0.3},
        heal = {r = 0.3, g = 1.0, b = 0.3},
        buff = {r = 1.0, g = 1.0, b = 0.3},
        debuff = {r = 0.8, g = 0.3, b = 0.8},
        utility = {r = 0.3, g = 0.7, b = 1.0}
    }
    
    return ability_colors[ability.effect_type] or {r = 0.5, g = 0.5, b = 0.8}
end
-- }}}

-- {{{ function TemplatePreview:draw_hexagon
function TemplatePreview:draw_hexagon(x, y, radius)
    local points = {}
    for i = 0, 5 do
        local angle = (i * math.pi * 2) / 6
        table.insert(points, x + math.cos(angle) * radius)
        table.insert(points, y + math.sin(angle) * radius)
    end
    love.graphics.polygon("fill", points)
end
-- }}}

-- {{{ function TemplatePreview:draw_hexagon_outline
function TemplatePreview:draw_hexagon_outline(x, y, radius)
    local points = {}
    for i = 0, 5 do
        local angle = (i * math.pi * 2) / 6
        table.insert(points, x + math.cos(angle) * radius)
        table.insert(points, y + math.sin(angle) * radius)
    end
    love.graphics.polygon("line", points)
end
-- }}}

-- {{{ function TemplatePreview:handle_mouse_input
function TemplatePreview:handle_mouse_input(x, y, button, pressed)
    if button == 1 and pressed then
        -- Check mode tab clicks
        for mode_name, tab in pairs(self.mode_tabs) do
            if self:point_in_bounds(x, y, tab.bounds) then
                self:switch_mode(mode_name)
                return true
            end
        end
        
        -- Check visual preview interactions
        if self.current_mode == "visual" and 
           self:point_in_bounds(x, y, self.visual_preview.bounds) then
            -- Toggle preview options or zoom
            return self:handle_visual_preview_click(x, y)
        end
    end
    
    return false
end
-- }}}

-- {{{ function TemplatePreview:handle_visual_preview_click
function TemplatePreview:handle_visual_preview_click(x, y)
    -- Simple zoom toggle for now
    if self.visual_preview.zoom_level < 1.5 then
        self.visual_preview.zoom_level = 1.5
    else
        self.visual_preview.zoom_level = 1.0
    end
    return true
end
-- }}}

-- {{{ function TemplatePreview:point_in_bounds
function TemplatePreview:point_in_bounds(x, y, bounds)
    return x >= bounds.x and x <= bounds.x + bounds.width and
           y >= bounds.y and y <= bounds.y + bounds.height
end
-- }}}

return TemplatePreview
```

### Acceptance Criteria
- [ ] Real-time visual preview of unit appearance with accurate rendering
- [ ] Comprehensive stats analysis with combat effectiveness breakdown
- [ ] Combat simulation against common opponent types
- [ ] Template comparison functionality with detailed differences
- [ ] Interactive preview controls (zoom, toggle overlays)
- [ ] Performance-optimized updates and rendering
- [ ] Clear visual feedback for all template aspects
- [ ] Animated mana bars and unit breathing effects