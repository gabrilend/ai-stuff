# Issue #509: Add Point Budget Display and Validation

## Current Behavior
Template editor lacks clear visual feedback for point budget management and real-time validation.

## Intended Behavior
Implement comprehensive point budget tracking with visual indicators, validation warnings, and optimization suggestions to help players create balanced templates.

## Implementation Details

### Point Budget Manager (src/ui/components/point_budget_manager.lua)
```lua
-- {{{ PointBudgetManager
local PointBudgetManager = {}
PointBudgetManager.__index = PointBudgetManager

function PointBudgetManager:new(template_editor)
    local manager = {
        template_editor = template_editor,
        BalanceCalculator = require("src.systems.balance_calculator"),
        calculator = nil,
        
        -- Budget state
        total_budget = 100,
        points_used = 0,
        stat_costs = {},
        ability_costs = {},
        type_costs = 0,
        synergy_costs = 0,
        
        -- UI Configuration
        display_bounds = {x = 20, y = 680, width = 760, height = 80},
        warning_threshold = 0.9, -- Warn when 90% of budget used
        
        -- Visual elements
        budget_bar = {},
        cost_breakdown = {},
        validation_panel = {},
        
        -- Animation state
        animation_timer = 0,
        last_points_used = 0,
        shake_intensity = 0
    }
    
    manager.calculator = manager.BalanceCalculator:new()
    manager:initialize_ui_elements()
    setmetatable(manager, self)
    return manager
end
-- }}}

-- {{{ function PointBudgetManager:initialize_ui_elements
function PointBudgetManager:initialize_ui_elements()
    local bounds = self.display_bounds
    
    -- Main budget bar
    self.budget_bar = {
        x = bounds.x + 20,
        y = bounds.y + 20,
        width = 300,
        height = 25,
        segments = {} -- For showing different cost categories
    }
    
    -- Cost breakdown display
    self.cost_breakdown = {
        x = bounds.x + 340,
        y = bounds.y + 10,
        width = 200,
        height = 60,
        categories = {"stats", "abilities", "type", "synergy"}
    }
    
    -- Validation panel
    self.validation_panel = {
        x = bounds.x + 560,
        y = bounds.y + 10,
        width = 180,
        height = 60,
        messages = {}
    }
end
-- }}}

-- {{{ function PointBudgetManager:update_from_template
function PointBudgetManager:update_from_template(template)
    if not template then
        self:reset_budget_display()
        return
    end
    
    -- Store previous value for animation
    self.last_points_used = self.points_used
    
    -- Calculate all costs
    self.stat_costs = self:calculate_stat_costs(template.stats)
    self.ability_costs = self:calculate_ability_costs(template.abilities)
    self.type_costs = self:calculate_type_costs(template.stats.unit_type)
    self.synergy_costs = self:calculate_synergy_costs(template)
    
    -- Update total
    self.points_used = self.stat_costs.total + self.ability_costs.total + 
                      self.type_costs + self.synergy_costs
    
    -- Update budget segments
    self:update_budget_segments()
    
    -- Validate budget
    self:validate_budget()
    
    -- Trigger animations if needed
    if math.abs(self.points_used - self.last_points_used) > 5 then
        self:trigger_change_animation()
    end
end
-- }}}

-- {{{ function PointBudgetManager:calculate_stat_costs
function PointBudgetManager:calculate_stat_costs(stats)
    local costs = {
        health = 0,
        speed = 0,
        armor = 0,
        detection_range = 0,
        total = 0
    }
    
    if not stats then return costs end
    
    -- Use balance calculator for accurate costs
    local total_stat_cost = self.calculator:calculate_stat_costs(stats)
    costs.total = total_stat_cost
    
    -- Break down by individual stats for display
    local stat_config = require("src.config.template_costs").stat_costs
    
    for stat_name, value in pairs(stats) do
        if stat_config[stat_name] and stat_name ~= "unit_type" then
            local base = stat_config[stat_name].base_value
            local cost_per_unit = stat_config[stat_name].cost_per_unit
            
            if value > base then
                costs[stat_name] = (value - base) * cost_per_unit
            end
        end
    end
    
    return costs
end
-- }}}

-- {{{ function PointBudgetManager:calculate_ability_costs
function PointBudgetManager:calculate_ability_costs(abilities)
    local costs = {
        primary = 0,
        secondary = {},
        total = 0
    }
    
    if not abilities then return costs end
    
    for i, ability in ipairs(abilities) do
        local ability_cost = self.calculator:calculate_single_ability_cost(ability, i == 1)
        
        if i == 1 then
            costs.primary = ability_cost
        else
            costs.secondary[i] = ability_cost
        end
        
        costs.total = costs.total + ability_cost
    end
    
    return costs
end
-- }}}

-- {{{ function PointBudgetManager:calculate_type_costs
function PointBudgetManager:calculate_type_costs(unit_type)
    local type_costs = require("src.config.template_costs").type_costs
    return type_costs[unit_type] or 0
end
-- }}}

-- {{{ function PointBudgetManager:calculate_synergy_costs
function PointBudgetManager:calculate_synergy_costs(template)
    return self.calculator:calculate_synergy_costs(template)
end
-- }}}

-- {{{ function PointBudgetManager:update_budget_segments
function PointBudgetManager:update_budget_segments()
    local total_budget = self.total_budget
    local bar_width = self.budget_bar.width
    
    self.budget_bar.segments = {}
    
    -- Calculate segment widths based on cost proportions
    local stat_width = (self.stat_costs.total / total_budget) * bar_width
    local ability_width = (self.ability_costs.total / total_budget) * bar_width
    local type_width = (self.type_costs / total_budget) * bar_width
    local synergy_width = (self.synergy_costs / total_budget) * bar_width
    
    local current_x = self.budget_bar.x
    
    -- Stats segment
    if stat_width > 0 then
        table.insert(self.budget_bar.segments, {
            type = "stats",
            x = current_x,
            width = stat_width,
            color = {0.3, 0.6, 0.8, 1.0},
            cost = self.stat_costs.total
        })
        current_x = current_x + stat_width
    end
    
    -- Abilities segment
    if ability_width > 0 then
        table.insert(self.budget_bar.segments, {
            type = "abilities",
            x = current_x,
            width = ability_width,
            color = {0.8, 0.3, 0.6, 1.0},
            cost = self.ability_costs.total
        })
        current_x = current_x + ability_width
    end
    
    -- Type segment
    if type_width > 0 then
        table.insert(self.budget_bar.segments, {
            type = "type",
            x = current_x,
            width = type_width,
            color = {0.6, 0.8, 0.3, 1.0},
            cost = self.type_costs
        })
        current_x = current_x + type_width
    end
    
    -- Synergy segment
    if synergy_width > 0 then
        table.insert(self.budget_bar.segments, {
            type = "synergy",
            x = current_x,
            width = synergy_width,
            color = {0.8, 0.6, 0.3, 1.0},
            cost = self.synergy_costs
        })
    end
end
-- }}}

-- {{{ function PointBudgetManager:validate_budget
function PointBudgetManager:validate_budget()
    self.validation_panel.messages = {}
    
    local remaining_points = self.total_budget - self.points_used
    local usage_percentage = self.points_used / self.total_budget
    
    -- Over budget
    if self.points_used > self.total_budget then
        table.insert(self.validation_panel.messages, {
            text = string.format("OVER BUDGET: %.1f points", self.points_used - self.total_budget),
            severity = "error",
            color = {1.0, 0.2, 0.2, 1.0}
        })
    
    -- Near budget limit
    elseif usage_percentage > self.warning_threshold then
        table.insert(self.validation_panel.messages, {
            text = string.format("%.1f points remaining", remaining_points),
            severity = "warning",
            color = {1.0, 0.8, 0.2, 1.0}
        })
    
    -- Unused points
    elseif remaining_points > self.total_budget * 0.15 then
        table.insert(self.validation_panel.messages, {
            text = string.format("%.1f points unused", remaining_points),
            severity = "info",
            color = {0.2, 0.8, 1.0, 1.0}
        })
    
    -- Good balance
    else
        table.insert(self.validation_panel.messages, {
            text = "Good point usage",
            severity = "success",
            color = {0.2, 1.0, 0.2, 1.0}
        })
    end
    
    -- Add efficiency suggestions
    local efficiency_messages = self:get_efficiency_suggestions()
    for _, msg in ipairs(efficiency_messages) do
        table.insert(self.validation_panel.messages, msg)
    end
end
-- }}}

-- {{{ function PointBudgetManager:get_efficiency_suggestions
function PointBudgetManager:get_efficiency_suggestions()
    local suggestions = {}
    
    -- Check for expensive categories
    local total_points = math.max(1, self.points_used)
    
    if self.stat_costs.total / total_points > 0.6 then
        table.insert(suggestions, {
            text = "High stat costs",
            severity = "info",
            color = {0.7, 0.7, 0.7, 1.0}
        })
    end
    
    if self.ability_costs.total / total_points > 0.7 then
        table.insert(suggestions, {
            text = "Expensive abilities",
            severity = "info",
            color = {0.7, 0.7, 0.7, 1.0}
        })
    end
    
    if self.synergy_costs > 10 then
        table.insert(suggestions, {
            text = "High synergy penalty",
            severity = "warning",
            color = {1.0, 0.6, 0.2, 1.0}
        })
    end
    
    return suggestions
end
-- }}}

-- {{{ function PointBudgetManager:trigger_change_animation
function PointBudgetManager:trigger_change_animation()
    self.animation_timer = 0.5 -- Animation duration
    
    if self.points_used > self.total_budget then
        self.shake_intensity = 0.3 -- Shake on over-budget
    end
end
-- }}}

-- {{{ function PointBudgetManager:reset_budget_display
function PointBudgetManager:reset_budget_display()
    self.points_used = 0
    self.stat_costs = {total = 0}
    self.ability_costs = {total = 0}
    self.type_costs = 0
    self.synergy_costs = 0
    self.budget_bar.segments = {}
    self.validation_panel.messages = {}
end
-- }}}

-- {{{ function PointBudgetManager:get_cost_breakdown
function PointBudgetManager:get_cost_breakdown()
    return {
        stats = self.stat_costs,
        abilities = self.ability_costs,
        type = self.type_costs,
        synergy = self.synergy_costs,
        total = self.points_used,
        budget = self.total_budget,
        remaining = self.total_budget - self.points_used,
        percentage_used = (self.points_used / self.total_budget) * 100
    }
end
-- }}}

-- {{{ function PointBudgetManager:suggest_reductions
function PointBudgetManager:suggest_reductions(target_reduction)
    local suggestions = {}
    
    if target_reduction <= 0 then return suggestions end
    
    -- Suggest stat reductions
    local most_expensive_stat = ""
    local highest_cost = 0
    
    for stat_name, cost in pairs(self.stat_costs) do
        if stat_name ~= "total" and cost > highest_cost then
            highest_cost = cost
            most_expensive_stat = stat_name
        end
    end
    
    if highest_cost > 0 then
        table.insert(suggestions, {
            type = "reduce_stat",
            stat = most_expensive_stat,
            current_cost = highest_cost,
            suggested_reduction = math.min(target_reduction, highest_cost * 0.5),
            message = string.format("Consider reducing %s (costs %.1f points)", 
                                   most_expensive_stat, highest_cost)
        })
    end
    
    -- Suggest ability simplifications
    if self.ability_costs.total > target_reduction then
        table.insert(suggestions, {
            type = "simplify_abilities",
            current_cost = self.ability_costs.total,
            suggested_reduction = target_reduction,
            message = "Consider simplifying abilities or reducing their power"
        })
    end
    
    return suggestions
end
-- }}}

-- {{{ function PointBudgetManager:update
function PointBudgetManager:update(dt)
    -- Update animations
    if self.animation_timer > 0 then
        self.animation_timer = self.animation_timer - dt
        
        if self.shake_intensity > 0 then
            self.shake_intensity = self.shake_intensity * (1 - dt * 2)
            if self.shake_intensity < 0.05 then
                self.shake_intensity = 0
            end
        end
    end
end
-- }}}

-- {{{ function PointBudgetManager:render
function PointBudgetManager:render()
    local bounds = self.display_bounds
    
    -- Apply shake effect if active
    local shake_x = 0
    local shake_y = 0
    if self.shake_intensity > 0 then
        shake_x = (math.random() - 0.5) * self.shake_intensity * 10
        shake_y = (math.random() - 0.5) * self.shake_intensity * 10
    end
    
    love.graphics.push()
    love.graphics.translate(shake_x, shake_y)
    
    -- Background panel
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", bounds.x, bounds.y, bounds.width, bounds.height)
    
    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Point Budget", bounds.x + 10, bounds.y + 5)
    
    -- Main budget info
    local budget_text = string.format("%.1f / %d points (%.1f%%)", 
                                     self.points_used, self.total_budget,
                                     (self.points_used / self.total_budget) * 100)
    love.graphics.print(budget_text, bounds.x + 120, bounds.y + 5)
    
    -- Render budget bar
    self:render_budget_bar()
    
    -- Render cost breakdown
    self:render_cost_breakdown()
    
    -- Render validation panel
    self:render_validation_panel()
    
    -- Border
    local border_color = self.points_used > self.total_budget and 
                        {1.0, 0.2, 0.2, 1.0} or {0.4, 0.4, 0.4, 1.0}
    love.graphics.setColor(border_color)
    love.graphics.rectangle("line", bounds.x, bounds.y, bounds.width, bounds.height)
    
    love.graphics.pop()
end
-- }}}

-- {{{ function PointBudgetManager:render_budget_bar
function PointBudgetManager:render_budget_bar()
    local bar = self.budget_bar
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 1.0)
    love.graphics.rectangle("fill", bar.x, bar.y, bar.width, bar.height)
    
    -- Render segments
    for _, segment in ipairs(bar.segments) do
        love.graphics.setColor(segment.color)
        love.graphics.rectangle("fill", segment.x, bar.y, segment.width, bar.height)
    end
    
    -- Over-budget indicator
    if self.points_used > self.total_budget then
        local over_budget_width = ((self.points_used - self.total_budget) / self.total_budget) * bar.width
        love.graphics.setColor(1.0, 0.2, 0.2, 0.7)
        love.graphics.rectangle("fill", bar.x + bar.width, bar.y, over_budget_width, bar.height)
    end
    
    -- Border
    love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
    love.graphics.rectangle("line", bar.x, bar.y, bar.width, bar.height)
    
    -- Budget markers (25%, 50%, 75%, 100%)
    love.graphics.setColor(0.8, 0.8, 0.8, 0.5)
    for i = 1, 3 do
        local marker_x = bar.x + (bar.width * i * 0.25)
        love.graphics.line(marker_x, bar.y, marker_x, bar.y + bar.height)
    end
end
-- }}}

-- {{{ function PointBudgetManager:render_cost_breakdown
function PointBudgetManager:render_cost_breakdown()
    local breakdown = self.cost_breakdown
    local y_offset = 0
    local line_height = 15
    
    love.graphics.setColor(0.9, 0.9, 0.9, 1.0)
    love.graphics.print("Cost Breakdown:", breakdown.x, breakdown.y + y_offset)
    y_offset = y_offset + line_height
    
    -- Stats
    love.graphics.setColor(0.3, 0.6, 0.8, 1.0)
    love.graphics.print(string.format("Stats: %.1f", self.stat_costs.total), 
                       breakdown.x, breakdown.y + y_offset)
    y_offset = y_offset + line_height
    
    -- Abilities
    love.graphics.setColor(0.8, 0.3, 0.6, 1.0)
    love.graphics.print(string.format("Abilities: %.1f", self.ability_costs.total), 
                       breakdown.x, breakdown.y + y_offset)
    y_offset = y_offset + line_height
    
    -- Type and synergy (if significant)
    if self.type_costs > 0 or self.synergy_costs > 0 then
        love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
        love.graphics.print(string.format("Other: %.1f", self.type_costs + self.synergy_costs), 
                           breakdown.x, breakdown.y + y_offset)
    end
end
-- }}}

-- {{{ function PointBudgetManager:render_validation_panel
function PointBudgetManager:render_validation_panel()
    local panel = self.validation_panel
    local y_offset = 0
    local line_height = 12
    
    for _, message in ipairs(panel.messages) do
        love.graphics.setColor(message.color)
        love.graphics.print(message.text, panel.x, panel.y + y_offset)
        y_offset = y_offset + line_height
        
        if y_offset > panel.height then
            break -- Don't overflow panel
        end
    end
end
-- }}}

-- {{{ function PointBudgetManager:handle_mouse_hover
function PointBudgetManager:handle_mouse_hover(x, y)
    local tooltip = nil
    
    -- Check if hovering over budget bar segments
    for _, segment in ipairs(self.budget_bar.segments) do
        if x >= segment.x and x <= segment.x + segment.width and
           y >= self.budget_bar.y and y <= self.budget_bar.y + self.budget_bar.height then
            
            tooltip = {
                title = string.upper(segment.type),
                text = string.format("Cost: %.1f points\nPercentage: %.1f%%", 
                                    segment.cost, (segment.cost / self.total_budget) * 100),
                x = x + 10,
                y = y - 30
            }
            break
        end
    end
    
    return tooltip
end
-- }}}

return PointBudgetManager
```

### Budget Optimization Helper (src/utils/budget_optimizer.lua)
```lua
-- {{{ BudgetOptimizer
local BudgetOptimizer = {}

function BudgetOptimizer:suggest_optimizations(template, target_budget)
    local suggestions = {}
    local current_cost = template.points_used or 0
    local excess = current_cost - target_budget
    
    if excess <= 0 then
        return suggestions -- Already within budget
    end
    
    -- Analyze cost distribution
    local cost_analysis = self:analyze_cost_distribution(template)
    
    -- Generate specific suggestions
    local stat_suggestions = self:suggest_stat_optimizations(template, excess, cost_analysis)
    local ability_suggestions = self:suggest_ability_optimizations(template, excess, cost_analysis)
    
    -- Combine and prioritize suggestions
    for _, suggestion in ipairs(stat_suggestions) do
        table.insert(suggestions, suggestion)
    end
    
    for _, suggestion in ipairs(ability_suggestions) do
        table.insert(suggestions, suggestion)
    end
    
    -- Sort by effectiveness (reduction per difficulty)
    table.sort(suggestions, function(a, b)
        return (a.point_reduction / a.difficulty) > (b.point_reduction / b.difficulty)
    end)
    
    return suggestions
end

function BudgetOptimizer:analyze_cost_distribution(template)
    -- This would analyze which parts of the template are most expensive
    -- and suggest the most efficient reductions
    return {
        dominant_category = "stats", -- or "abilities"
        most_expensive_stat = "health",
        most_expensive_ability = 1,
        efficiency_score = 0.75
    }
end

return BudgetOptimizer
```

### Acceptance Criteria
- [ ] Clear visual representation of point budget usage with color-coded segments
- [ ] Real-time validation with appropriate warning levels
- [ ] Detailed cost breakdown showing contribution of stats, abilities, and synergies
- [ ] Visual feedback for budget violations with shake animations
- [ ] Hover tooltips showing detailed cost information
- [ ] Optimization suggestions when over budget
- [ ] Smooth animations for budget changes