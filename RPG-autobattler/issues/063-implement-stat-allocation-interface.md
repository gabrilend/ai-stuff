# Issue #507: Implement Stat Allocation Interface

## Current Behavior
Template editor UI exists but lacks sophisticated stat allocation controls with real-time cost calculation and constraint enforcement.

## Intended Behavior
Create an advanced stat allocation interface that provides precise control over unit stats with visual feedback, smart constraints, and optimization suggestions.

## Implementation Details

### Advanced Stat Allocator (src/ui/components/stat_allocator.lua)
```lua
-- {{{ StatAllocator
local StatAllocator = {}
StatAllocator.__index = StatAllocator

function StatAllocator:new(template_editor)
    local allocator = {
        template_editor = template_editor,
        BalanceCalculator = require("src.systems.balance_calculator"),
        calculator = nil,
        
        -- UI Elements
        stat_controls = {},
        constraint_indicators = {},
        cost_displays = {},
        
        -- State
        current_template = nil,
        point_budget = 100,
        points_used = 0,
        stat_costs = {},
        
        -- Configuration
        stat_definitions = self:load_stat_definitions(),
        allocation_presets = {},
        
        -- Interaction state
        drag_state = {
            active = false,
            stat_name = nil,
            start_value = 0,
            start_mouse_x = 0
        }
    }
    
    allocator.calculator = allocator.BalanceCalculator:new()
    allocator:initialize_presets()
    setmetatable(allocator, self)
    return allocator
end
-- }}}

-- {{{ function StatAllocator:load_stat_definitions
function StatAllocator:load_stat_definitions()
    return {
        health = {
            name = "Health",
            description = "Total hit points - higher values increase survivability",
            min_value = 30,
            max_value = 500,
            default_value = 100,
            base_cost = 100, -- Base value that costs 0 points
            cost_per_unit = 0.1, -- Points per unit above base
            increment = 5,
            display_format = "%d HP",
            category = "survivability",
            icon = "♥",
            color = {0.8, 0.2, 0.2}
        },
        speed = {
            name = "Speed",
            description = "Movement speed - affects positioning and combat mobility",
            min_value = 5,
            max_value = 200,
            default_value = 50,
            base_cost = 50,
            cost_per_unit = 0.2,
            increment = 5,
            display_format = "%d units/sec",
            category = "mobility",
            icon = "⚡",
            color = {0.2, 0.8, 0.8}
        },
        armor = {
            name = "Armor",
            description = "Damage reduction - each point reduces incoming damage",
            min_value = 0,
            max_value = 25,
            default_value = 0,
            base_cost = 0,
            cost_per_unit = 3,
            increment = 1,
            display_format = "%d armor",
            category = "survivability",
            icon = "🛡",
            color = {0.6, 0.6, 0.6}
        },
        detection_range = {
            name = "Detection Range",
            description = "How far the unit can detect enemies and use abilities",
            min_value = 20,
            max_value = 300,
            default_value = 60,
            base_cost = 60,
            cost_per_unit = 0.05,
            increment = 5,
            display_format = "%d range",
            category = "utility",
            icon = "👁",
            color = {0.8, 0.8, 0.2}
        }
    }
end
-- }}}

-- {{{ function StatAllocator:initialize_presets
function StatAllocator:initialize_presets()
    self.allocation_presets = {
        balanced = {
            name = "Balanced",
            description = "Well-rounded stats for general purpose",
            stats = {health = 120, speed = 55, armor = 2, detection_range = 65}
        },
        tank = {
            name = "Tank",
            description = "High health and armor, low speed",
            stats = {health = 200, speed = 30, armor = 8, detection_range = 45}
        },
        glass_cannon = {
            name = "Glass Cannon",
            description = "Minimum survivability, maximum other stats",
            stats = {health = 50, speed = 80, armor = 0, detection_range = 100}
        },
        scout = {
            name = "Scout",
            description = "High speed and detection for reconnaissance",
            stats = {health = 70, speed = 90, armor = 0, detection_range = 120}
        },
        fortress = {
            name = "Fortress",
            description = "Maximum defensive stats",
            stats = {health = 250, speed = 20, armor = 12, detection_range = 40}
        }
    }
end
-- }}}

-- {{{ function StatAllocator:create_stat_controls
function StatAllocator:create_stat_controls(container_x, container_y, container_width)
    local y_offset = 0
    local control_height = 80
    local control_spacing = 10
    
    for stat_name, stat_def in pairs(self.stat_definitions) do
        local control_y = container_y + y_offset
        
        self.stat_controls[stat_name] = self:create_single_stat_control(
            stat_name, stat_def, container_x, control_y, container_width, control_height
        )
        
        y_offset = y_offset + control_height + control_spacing
    end
    
    -- Add preset selector
    self:create_preset_selector(container_x, container_y + y_offset, container_width)
end
-- }}}

-- {{{ function StatAllocator:create_single_stat_control
function StatAllocator:create_single_stat_control(stat_name, stat_def, x, y, width, height)
    local control = {
        stat_name = stat_name,
        stat_def = stat_def,
        bounds = {x = x, y = y, width = width, height = height},
        current_value = stat_def.default_value,
        
        -- Sub-components
        slider = {
            x = x + 20,
            y = y + 35,
            width = width - 180,
            height = 20,
            dragging = false
        },
        
        value_input = {
            x = x + width - 150,
            y = y + 30,
            width = 60,
            height = 25,
            editing = false,
            text = tostring(stat_def.default_value)
        },
        
        cost_display = {
            x = x + width - 80,
            y = y + 30,
            width = 70,
            height = 25
        },
        
        increment_buttons = {
            minus = {x = x + width - 150 - 30, y = y + 30, width = 25, height = 25},
            plus = {x = x + width - 150 + 65, y = y + 30, width = 25, height = 25}
        }
    }
    
    return control
end
-- }}}

-- {{{ function StatAllocator:create_preset_selector
function StatAllocator:create_preset_selector(x, y, width)
    local preset_height = 120
    
    self.preset_selector = {
        bounds = {x = x, y = y, width = width, height = preset_height},
        buttons = {},
        expanded = false
    }
    
    -- Create preset buttons
    local button_width = (width - 40) / 3
    local button_height = 25
    local row = 0
    local col = 0
    
    for preset_name, preset_data in pairs(self.allocation_presets) do
        local button_x = x + 10 + col * (button_width + 5)
        local button_y = y + 30 + row * (button_height + 5)
        
        self.preset_selector.buttons[preset_name] = {
            bounds = {x = button_x, y = button_y, width = button_width, height = button_height},
            preset_data = preset_data
        }
        
        col = col + 1
        if col >= 3 then
            col = 0
            row = row + 1
        end
    end
end
-- }}}

-- {{{ function StatAllocator:update_stat_value
function StatAllocator:update_stat_value(stat_name, new_value)
    local stat_def = self.stat_definitions[stat_name]
    if not stat_def then return end
    
    -- Clamp to valid range
    new_value = math.max(stat_def.min_value, math.min(stat_def.max_value, new_value))
    
    -- Round to increment
    new_value = math.floor(new_value / stat_def.increment + 0.5) * stat_def.increment
    
    -- Update control state
    local control = self.stat_controls[stat_name]
    if control then
        control.current_value = new_value
        control.value_input.text = tostring(new_value)
    end
    
    -- Update template
    if self.current_template then
        self.current_template.stats[stat_name] = new_value
        self:recalculate_costs()
        self:update_template_editor()
    end
end
-- }}}

-- {{{ function StatAllocator:handle_mouse_input
function StatAllocator:handle_mouse_input(x, y, button, pressed)
    if button == 1 then -- Left mouse button
        if pressed then
            return self:handle_mouse_press(x, y)
        else
            return self:handle_mouse_release(x, y)
        end
    end
    return false
end
-- }}}

-- {{{ function StatAllocator:handle_mouse_press
function StatAllocator:handle_mouse_press(x, y)
    -- Check stat control interactions
    for stat_name, control in pairs(self.stat_controls) do
        -- Slider interaction
        if self:point_in_bounds(x, y, control.slider) then
            self.drag_state.active = true
            self.drag_state.stat_name = stat_name
            self.drag_state.start_value = control.current_value
            self.drag_state.start_mouse_x = x
            self:update_slider_from_mouse(control, x)
            return true
        end
        
        -- Increment buttons
        if self:point_in_bounds(x, y, control.increment_buttons.minus) then
            local new_value = control.current_value - control.stat_def.increment
            self:update_stat_value(stat_name, new_value)
            return true
        end
        
        if self:point_in_bounds(x, y, control.increment_buttons.plus) then
            local new_value = control.current_value + control.stat_def.increment
            self:update_stat_value(stat_name, new_value)
            return true
        end
        
        -- Value input field
        if self:point_in_bounds(x, y, control.value_input) then
            control.value_input.editing = true
            return true
        end
    end
    
    -- Check preset button interactions
    if self.preset_selector then
        for preset_name, button in pairs(self.preset_selector.buttons) do
            if self:point_in_bounds(x, y, button.bounds) then
                self:apply_preset(preset_name)
                return true
            end
        end
    end
    
    return false
end
-- }}}

-- {{{ function StatAllocator:handle_mouse_release
function StatAllocator:handle_mouse_release(x, y)
    if self.drag_state.active then
        self.drag_state.active = false
        self.drag_state.stat_name = nil
        return true
    end
    return false
end
-- }}}

-- {{{ function StatAllocator:handle_mouse_move
function StatAllocator:handle_mouse_move(x, y)
    if self.drag_state.active and self.drag_state.stat_name then
        local control = self.stat_controls[self.drag_state.stat_name]
        if control then
            self:update_slider_from_mouse(control, x)
        end
    end
end
-- }}}

-- {{{ function StatAllocator:update_slider_from_mouse
function StatAllocator:update_slider_from_mouse(control, mouse_x)
    local slider = control.slider
    local relative_x = mouse_x - slider.x
    local percentage = math.max(0, math.min(1, relative_x / slider.width))
    
    local stat_def = control.stat_def
    local value_range = stat_def.max_value - stat_def.min_value
    local new_value = stat_def.min_value + (value_range * percentage)
    
    self:update_stat_value(control.stat_name, new_value)
end
-- }}}

-- {{{ function StatAllocator:apply_preset
function StatAllocator:apply_preset(preset_name)
    local preset = self.allocation_presets[preset_name]
    if not preset then return end
    
    for stat_name, value in pairs(preset.stats) do
        self:update_stat_value(stat_name, value)
    end
    
    -- Visual feedback
    self:show_preset_applied_feedback(preset_name)
end
-- }}}

-- {{{ function StatAllocator:show_preset_applied_feedback
function StatAllocator:show_preset_applied_feedback(preset_name)
    -- TODO: Implement visual feedback (e.g., brief highlight, notification)
    print("Applied preset: " .. preset_name)
end
-- }}}

-- {{{ function StatAllocator:recalculate_costs
function StatAllocator:recalculate_costs()
    if not self.current_template then return end
    
    self.stat_costs = {}
    local total_cost = 0
    
    for stat_name, value in pairs(self.current_template.stats) do
        if stat_name ~= "unit_type" then
            local stat_def = self.stat_definitions[stat_name]
            if stat_def then
                local cost = self:calculate_stat_cost(stat_name, value, stat_def)
                self.stat_costs[stat_name] = cost
                total_cost = total_cost + cost
            end
        end
    end
    
    self.points_used = total_cost
end
-- }}}

-- {{{ function StatAllocator:calculate_stat_cost
function StatAllocator:calculate_stat_cost(stat_name, value, stat_def)
    if value <= stat_def.base_cost then
        return 0
    end
    
    local excess = value - stat_def.base_cost
    return excess * stat_def.cost_per_unit
end
-- }}}

-- {{{ function StatAllocator:get_stat_cost_breakdown
function StatAllocator:get_stat_cost_breakdown()
    local breakdown = {}
    
    for stat_name, cost in pairs(self.stat_costs) do
        local stat_def = self.stat_definitions[stat_name]
        local current_value = self.current_template.stats[stat_name]
        
        breakdown[stat_name] = {
            name = stat_def.name,
            current_value = current_value,
            base_value = stat_def.base_cost,
            excess_value = math.max(0, current_value - stat_def.base_cost),
            cost_per_unit = stat_def.cost_per_unit,
            total_cost = cost,
            percentage = (cost / math.max(1, self.points_used)) * 100
        }
    end
    
    return breakdown
end
-- }}}

-- {{{ function StatAllocator:suggest_optimizations
function StatAllocator:suggest_optimizations()
    local suggestions = {}
    
    if not self.current_template then return suggestions end
    
    local remaining_points = self.point_budget - self.points_used
    
    -- Suggest if points are being wasted
    if remaining_points > self.point_budget * 0.1 then
        table.insert(suggestions, {
            type = "unused_points",
            message = string.format("You have %d unused points (%.1f%% of budget)", 
                                   remaining_points, (remaining_points / self.point_budget) * 100),
            severity = "warning"
        })
    end
    
    -- Suggest balanced allocation
    local stat_distribution = self:analyze_stat_distribution()
    if stat_distribution.max_percentage > 0.7 then
        table.insert(suggestions, {
            type = "unbalanced_stats",
            message = string.format("%.1f%% of points spent on %s - consider more balanced allocation", 
                                   stat_distribution.max_percentage * 100, stat_distribution.dominant_stat),
            severity = "info"
        })
    end
    
    -- Suggest efficiency improvements
    local efficiency_suggestions = self:analyze_cost_efficiency()
    for _, suggestion in ipairs(efficiency_suggestions) do
        table.insert(suggestions, suggestion)
    end
    
    return suggestions
end
-- }}}

-- {{{ function StatAllocator:analyze_stat_distribution
function StatAllocator:analyze_stat_distribution()
    local total_points = math.max(1, self.points_used)
    local max_percentage = 0
    local dominant_stat = ""
    
    for stat_name, cost in pairs(self.stat_costs) do
        local percentage = cost / total_points
        if percentage > max_percentage then
            max_percentage = percentage
            dominant_stat = self.stat_definitions[stat_name].name
        end
    end
    
    return {
        max_percentage = max_percentage,
        dominant_stat = dominant_stat
    }
end
-- }}}

-- {{{ function StatAllocator:analyze_cost_efficiency
function StatAllocator:analyze_cost_efficiency()
    local suggestions = {}
    
    -- Check for expensive stats that could be optimized
    for stat_name, cost in pairs(self.stat_costs) do
        local percentage = cost / math.max(1, self.points_used)
        local stat_def = self.stat_definitions[stat_name]
        local current_value = self.current_template.stats[stat_name]
        
        if percentage > 0.4 and current_value > stat_def.base_cost * 1.5 then
            table.insert(suggestions, {
                type = "expensive_stat",
                message = string.format("%s is very expensive - consider reducing for better point efficiency", stat_def.name),
                severity = "info",
                stat_name = stat_name
            })
        end
    end
    
    return suggestions
end
-- }}}

-- {{{ function StatAllocator:render
function StatAllocator:render()
    -- Render stat controls
    for stat_name, control in pairs(self.stat_controls) do
        self:render_stat_control(control)
    end
    
    -- Render preset selector
    if self.preset_selector then
        self:render_preset_selector()
    end
    
    -- Render optimization suggestions
    self:render_suggestions()
end
-- }}}

-- {{{ function StatAllocator:render_stat_control
function StatAllocator:render_stat_control(control)
    local bounds = control.bounds
    local stat_def = control.stat_def
    
    -- Background
    love.graphics.setColor(0.15, 0.15, 0.15, 1.0)
    love.graphics.rectangle("fill", bounds.x, bounds.y, bounds.width, bounds.height)
    
    -- Header with icon and name
    love.graphics.setColor(stat_def.color)
    love.graphics.print(stat_def.icon .. " " .. stat_def.name, bounds.x + 10, bounds.y + 5)
    
    -- Cost display
    local cost = self.stat_costs[control.stat_name] or 0
    love.graphics.setColor(0.8, 0.8, 0.2, 1.0)
    love.graphics.print(string.format("%.1f pts", cost), control.cost_display.x, control.cost_display.y)
    
    -- Slider
    self:render_slider(control.slider, control.current_value, stat_def)
    
    -- Value input
    self:render_value_input(control.value_input, control.current_value, stat_def)
    
    -- Increment buttons
    self:render_increment_buttons(control.increment_buttons)
    
    -- Border
    love.graphics.setColor(0.3, 0.3, 0.3, 1.0)
    love.graphics.rectangle("line", bounds.x, bounds.y, bounds.width, bounds.height)
end
-- }}}

-- {{{ function StatAllocator:render_slider
function StatAllocator:render_slider(slider, current_value, stat_def)
    -- Background track
    love.graphics.setColor(0.2, 0.2, 0.2, 1.0)
    love.graphics.rectangle("fill", slider.x, slider.y, slider.width, slider.height)
    
    -- Fill based on current value
    local percentage = (current_value - stat_def.min_value) / (stat_def.max_value - stat_def.min_value)
    local fill_width = slider.width * percentage
    
    love.graphics.setColor(stat_def.color)
    love.graphics.rectangle("fill", slider.x, slider.y, fill_width, slider.height)
    
    -- Handle
    local handle_x = slider.x + fill_width - 5
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", handle_x, slider.y - 3, 10, slider.height + 6)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
    love.graphics.rectangle("line", slider.x, slider.y, slider.width, slider.height)
end
-- }}}

-- {{{ function StatAllocator:render_value_input
function StatAllocator:render_value_input(input, current_value, stat_def)
    -- Background
    local bg_color = input.editing and {0.3, 0.3, 0.4, 1.0} or {0.25, 0.25, 0.25, 1.0}
    love.graphics.setColor(bg_color)
    love.graphics.rectangle("fill", input.x, input.y, input.width, input.height)
    
    -- Text
    love.graphics.setColor(1, 1, 1, 1)
    local display_text = string.format(stat_def.display_format, current_value)
    love.graphics.print(display_text, input.x + 5, input.y + 5)
    
    -- Border
    love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
    love.graphics.rectangle("line", input.x, input.y, input.width, input.height)
end
-- }}}

-- {{{ function StatAllocator:render_increment_buttons
function StatAllocator:render_increment_buttons(buttons)
    -- Minus button
    love.graphics.setColor(0.6, 0.3, 0.3, 1.0)
    love.graphics.rectangle("fill", buttons.minus.x, buttons.minus.y, buttons.minus.width, buttons.minus.height)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("-", buttons.minus.x + 8, buttons.minus.y + 5)
    
    -- Plus button
    love.graphics.setColor(0.3, 0.6, 0.3, 1.0)
    love.graphics.rectangle("fill", buttons.plus.x, buttons.plus.y, buttons.plus.width, buttons.plus.height)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("+", buttons.plus.x + 8, buttons.plus.y + 5)
    
    -- Borders
    love.graphics.setColor(0.5, 0.5, 0.5, 1.0)
    love.graphics.rectangle("line", buttons.minus.x, buttons.minus.y, buttons.minus.width, buttons.minus.height)
    love.graphics.rectangle("line", buttons.plus.x, buttons.plus.y, buttons.plus.width, buttons.plus.height)
end
-- }}}

-- {{{ function StatAllocator:point_in_bounds
function StatAllocator:point_in_bounds(x, y, bounds)
    return x >= bounds.x and x <= bounds.x + bounds.width and
           y >= bounds.y and y <= bounds.y + bounds.height
end
-- }}}

return StatAllocator
```

### Acceptance Criteria
- [ ] Precise stat control with sliders, input fields, and increment buttons
- [ ] Real-time cost calculation and point budget tracking
- [ ] Visual feedback for stat costs and efficiency
- [ ] Preset allocation templates for common builds
- [ ] Smart suggestions for stat optimization
- [ ] Responsive interaction with drag and drop support
- [ ] Clear visual representation of stat categories and relationships