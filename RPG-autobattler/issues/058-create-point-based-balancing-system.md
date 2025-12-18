# Issue #502: Create Point-Based Balancing System

## Current Behavior
No balancing mechanism exists to ensure unit templates are equivalent in power level.

## Intended Behavior
Implement a comprehensive point-based balancing system that ensures all unit templates have equal potential power while allowing diverse strategies and builds.

## Implementation Details

### Balance Calculator (src/systems/balance_calculator.lua)
```lua
-- {{{ BalanceCalculator
local BalanceCalculator = {}
BalanceCalculator.__index = BalanceCalculator

function BalanceCalculator:new(cost_config)
    local calculator = {
        cost_config = cost_config or require("src.config.template_costs"),
        balance_metrics = {},
        effectiveness_cache = {}
    }
    setmetatable(calculator, self)
    return calculator
end
-- }}}

-- {{{ function BalanceCalculator:calculate_total_cost
function BalanceCalculator:calculate_total_cost(template)
    local total = 0
    
    total = total + self:calculate_stat_costs(template.stats)
    total = total + self:calculate_ability_costs(template.abilities)
    total = total + self:calculate_type_costs(template.stats.unit_type)
    total = total + self:calculate_synergy_costs(template)
    
    return total
end
-- }}}

-- {{{ function BalanceCalculator:calculate_stat_costs
function BalanceCalculator:calculate_stat_costs(stats)
    local cost = 0
    local config = self.cost_config.stat_costs
    
    for stat_name, value in pairs(stats) do
        if config[stat_name] and stat_name ~= "unit_type" then
            local base = config[stat_name].base_value
            local cost_per_unit = config[stat_name].cost_per_unit
            
            if value > base then
                local excess = value - base
                cost = cost + (excess * cost_per_unit)
            elseif value < base then
                -- Negative cost for stats below base (with diminishing returns)
                local deficit = base - value
                local savings = deficit * cost_per_unit * 0.5 -- Half value for going below base
                cost = cost - savings
            end
        end
    end
    
    return math.max(0, cost) -- Minimum 0 cost
end
-- }}}

-- {{{ function BalanceCalculator:calculate_ability_costs
function BalanceCalculator:calculate_ability_costs(abilities)
    local total_cost = 0
    
    for i, ability in ipairs(abilities) do
        local ability_cost = self:calculate_single_ability_cost(ability, i == 1)
        total_cost = total_cost + ability_cost
    end
    
    -- Diminishing returns for many abilities
    if #abilities > 2 then
        local penalty = (#abilities - 2) * 5 -- 5 points per ability beyond 2
        total_cost = total_cost + penalty
    end
    
    return total_cost
end
-- }}}

-- {{{ function BalanceCalculator:calculate_single_ability_cost
function BalanceCalculator:calculate_single_ability_cost(ability, is_primary)
    local config = self.cost_config.ability_costs
    local base_cost = is_primary and config.primary_base or config.secondary_base
    
    -- Effect value cost
    local effect_cost = 0
    if ability.effect_type == "damage" then
        effect_cost = ability.base_value * config.damage_multiplier
    elseif ability.effect_type == "heal" then
        effect_cost = ability.base_value * config.heal_multiplier
    elseif ability.effect_type == "buff" or ability.effect_type == "debuff" then
        effect_cost = (ability.base_value or 10) * (ability.duration or 5) * 0.1
    end
    
    -- Range cost
    local range_cost = 0
    if ability.range > 50 then
        range_cost = (ability.range - 50) * config.range_cost
    end
    
    -- Area effect cost
    local area_cost = 0
    if ability.area_radius and ability.area_radius > 0 then
        area_cost = ability.area_radius * config.area_cost
        -- Area effects multiply the effect cost
        effect_cost = effect_cost * (1 + ability.area_radius / 50)
    end
    
    -- Special ability modifiers
    local special_cost = self:calculate_special_ability_costs(ability)
    
    return base_cost + effect_cost + range_cost + area_cost + special_cost
end
-- }}}

-- {{{ function BalanceCalculator:calculate_special_ability_costs
function BalanceCalculator:calculate_special_ability_costs(ability)
    local cost = 0
    
    -- Multi-target abilities
    if ability.max_targets and ability.max_targets > 1 then
        cost = cost + (ability.max_targets - 1) * 3
    end
    
    -- Piercing/penetration
    if ability.piercing then
        cost = cost + 8
    end
    
    -- Status effects
    if ability.status_effect then
        local status_costs = {
            slow = 5,
            stun = 12,
            poison = 8,
            armor_break = 10,
            regeneration = 6,
            haste = 7
        }
        cost = cost + (status_costs[ability.status_effect] or 5)
    end
    
    -- Conditional effects
    if ability.conditional_bonus then
        cost = cost + 3 -- Small cost for situational power
    end
    
    return cost
end
-- }}}

-- {{{ function BalanceCalculator:calculate_type_costs
function BalanceCalculator:calculate_type_costs(unit_type)
    return self.cost_config.type_costs[unit_type] or 0
end
-- }}}

-- {{{ function BalanceCalculator:calculate_synergy_costs
function BalanceCalculator:calculate_synergy_costs(template)
    local synergy_cost = 0
    
    -- High health + high armor synergy
    if template.stats.health > 150 and template.stats.armor > 2 then
        synergy_cost = synergy_cost + 5
    end
    
    -- High speed + ranged synergy
    if template.stats.speed > 70 and template.stats.unit_type == "ranged" then
        synergy_cost = synergy_cost + 3
    end
    
    -- Multiple damage abilities synergy
    local damage_abilities = 0
    for _, ability in ipairs(template.abilities) do
        if ability.effect_type == "damage" then
            damage_abilities = damage_abilities + 1
        end
    end
    if damage_abilities > 2 then
        synergy_cost = synergy_cost + (damage_abilities - 2) * 4
    end
    
    return synergy_cost
end
-- }}}

-- {{{ function BalanceCalculator:calculate_combat_effectiveness
function BalanceCalculator:calculate_combat_effectiveness(template)
    local cache_key = self:generate_template_hash(template)
    
    if self.effectiveness_cache[cache_key] then
        return self.effectiveness_cache[cache_key]
    end
    
    local effectiveness = {
        dps = self:calculate_dps(template),
        survivability = self:calculate_survivability(template),
        utility = self:calculate_utility(template),
        mobility = self:calculate_mobility(template)
    }
    
    effectiveness.total_score = (effectiveness.dps * 0.4) + 
                               (effectiveness.survivability * 0.3) + 
                               (effectiveness.utility * 0.2) + 
                               (effectiveness.mobility * 0.1)
    
    self.effectiveness_cache[cache_key] = effectiveness
    return effectiveness
end
-- }}}

-- {{{ function BalanceCalculator:calculate_dps
function BalanceCalculator:calculate_dps(template)
    local total_dps = 0
    
    for _, ability in ipairs(template.abilities) do
        if ability.effect_type == "damage" then
            local damage_per_cast = ability.base_value or 0
            local mana_cost = ability.max_mana or 100
            local mana_generation_rate = 10 -- Base rate, would need actual mana system integration
            local cast_frequency = mana_generation_rate / mana_cost
            
            total_dps = total_dps + (damage_per_cast * cast_frequency)
        end
    end
    
    return total_dps
end
-- }}}

-- {{{ function BalanceCalculator:calculate_survivability
function BalanceCalculator:calculate_survivability(template)
    local health = template.stats.health or 100
    local armor = template.stats.armor or 0
    local speed = template.stats.speed or 50
    
    -- Effective HP considering armor
    local effective_hp = health * (1 + armor * 0.1)
    
    -- Speed contributes to survivability for ranged units
    if template.stats.unit_type == "ranged" then
        effective_hp = effective_hp * (1 + (speed - 50) * 0.01)
    end
    
    return effective_hp
end
-- }}}

-- {{{ function BalanceCalculator:calculate_utility
function BalanceCalculator:calculate_utility(template)
    local utility = 0
    
    for _, ability in ipairs(template.abilities) do
        if ability.effect_type == "heal" then
            utility = utility + (ability.base_value or 0) * 0.8
        elseif ability.effect_type == "buff" then
            utility = utility + 15
        elseif ability.effect_type == "debuff" then
            utility = utility + 12
        end
        
        if ability.area_radius and ability.area_radius > 0 then
            utility = utility + 10
        end
    end
    
    return utility
end
-- }}}

-- {{{ function BalanceCalculator:calculate_mobility
function BalanceCalculator:calculate_mobility(template)
    local speed = template.stats.speed or 50
    local detection_range = template.stats.detection_range or 60
    
    local mobility_score = speed + (detection_range * 0.5)
    
    -- Ranged units benefit more from mobility
    if template.stats.unit_type == "ranged" then
        mobility_score = mobility_score * 1.2
    end
    
    return mobility_score
end
-- }}}

-- {{{ function BalanceCalculator:generate_template_hash
function BalanceCalculator:generate_template_hash(template)
    -- Simple hash based on template content for caching
    local hash_string = template.name .. 
                       tostring(template.stats.health) ..
                       tostring(template.stats.speed) ..
                       tostring(#template.abilities)
    
    return hash_string
end
-- }}}

-- {{{ function BalanceCalculator:validate_balance
function BalanceCalculator:validate_balance(template1, template2, tolerance)
    tolerance = tolerance or 0.15 -- 15% tolerance by default
    
    local eff1 = self:calculate_combat_effectiveness(template1)
    local eff2 = self:calculate_combat_effectiveness(template2)
    
    local difference = math.abs(eff1.total_score - eff2.total_score)
    local average = (eff1.total_score + eff2.total_score) / 2
    local relative_difference = difference / average
    
    return relative_difference <= tolerance, relative_difference, eff1, eff2
end
-- }}}

return BalanceCalculator
```

### Balance Validation System (src/systems/balance_validator.lua)
```lua
-- {{{ BalanceValidator
local BalanceValidator = {}
BalanceValidator.__index = BalanceValidator

function BalanceValidator:new()
    local validator = {
        BalanceCalculator = require("src.systems.balance_calculator"),
        calculator = nil,
        test_scenarios = {},
        balance_reports = {}
    }
    
    validator.calculator = validator.BalanceCalculator:new()
    setmetatable(validator, self)
    return validator
end
-- }}}

-- {{{ function BalanceValidator:run_comprehensive_balance_test
function BalanceValidator:run_comprehensive_balance_test(templates)
    local report = {
        timestamp = love.timer.getTime(),
        templates_tested = #templates,
        balance_issues = {},
        effectiveness_scores = {},
        recommendations = {}
    }
    
    -- Calculate effectiveness for all templates
    for _, template in ipairs(templates) do
        local effectiveness = self.calculator:calculate_combat_effectiveness(template)
        report.effectiveness_scores[template.name] = effectiveness
    end
    
    -- Compare all template pairs
    for i = 1, #templates do
        for j = i + 1, #templates do
            local is_balanced, difference, eff1, eff2 = self.calculator:validate_balance(templates[i], templates[j])
            
            if not is_balanced then
                table.insert(report.balance_issues, {
                    template1 = templates[i].name,
                    template2 = templates[j].name,
                    difference = difference,
                    stronger = eff1.total_score > eff2.total_score and templates[i].name or templates[j].name
                })
            end
        end
    end
    
    -- Generate recommendations
    report.recommendations = self:generate_balance_recommendations(report)
    
    return report
end
-- }}}

-- {{{ function BalanceValidator:generate_balance_recommendations
function BalanceValidator:generate_balance_recommendations(report)
    local recommendations = {}
    
    -- Find overpowered templates
    local scores = {}
    for name, effectiveness in pairs(report.effectiveness_scores) do
        table.insert(scores, {name = name, score = effectiveness.total_score})
    end
    
    table.sort(scores, function(a, b) return a.score > b.score end)
    
    local average_score = 0
    for _, score_data in ipairs(scores) do
        average_score = average_score + score_data.score
    end
    average_score = average_score / #scores
    
    for _, score_data in ipairs(scores) do
        local deviation = (score_data.score - average_score) / average_score
        
        if deviation > 0.2 then
            table.insert(recommendations, {
                template = score_data.name,
                issue = "overpowered",
                suggestion = "Reduce stats or ability power by " .. math.ceil(deviation * 100) .. "%"
            })
        elseif deviation < -0.2 then
            table.insert(recommendations, {
                template = score_data.name,
                issue = "underpowered", 
                suggestion = "Increase stats or ability power by " .. math.ceil(math.abs(deviation) * 100) .. "%"
            })
        end
    end
    
    return recommendations
end
-- }}}

return BalanceValidator
```

### Acceptance Criteria
- [ ] Point costs accurately reflect unit power levels
- [ ] All templates with equal points have similar combat effectiveness
- [ ] Balance system accounts for synergies between stats and abilities
- [ ] Validation system identifies overpowered/underpowered templates
- [ ] Cost calculations encourage diverse build strategies
- [ ] System provides actionable feedback for template improvements