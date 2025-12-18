# Issue #503: Implement Template Validation and Constraints

## Current Behavior
Template system exists but lacks comprehensive validation rules to ensure templates are legal and functional within game constraints.

## Intended Behavior
Implement robust validation system with clear constraints that prevent broken templates while providing helpful feedback to template creators.

## Implementation Details

### Template Validator (src/validators/template_validator.lua)
```lua
-- {{{ TemplateValidator
local TemplateValidator = {}
TemplateValidator.__index = TemplateValidator

function TemplateValidator:new(constraint_config)
    local validator = {
        constraints = constraint_config or require("src.config.template_constraints"),
        validation_rules = {},
        error_messages = {},
        warning_messages = {}
    }
    
    validator:initialize_validation_rules()
    setmetatable(validator, self)
    return validator
end
-- }}}

-- {{{ function TemplateValidator:initialize_validation_rules
function TemplateValidator:initialize_validation_rules()
    self.validation_rules = {
        -- Core validation rules
        {name = "point_budget", func = self.validate_point_budget, critical = true},
        {name = "stat_ranges", func = self.validate_stat_ranges, critical = true},
        {name = "ability_count", func = self.validate_ability_count, critical = true},
        {name = "ability_validity", func = self.validate_abilities, critical = true},
        {name = "template_name", func = self.validate_template_name, critical = true},
        
        -- Balance validation rules  
        {name = "stat_distribution", func = self.validate_stat_distribution, critical = false},
        {name = "ability_synergy", func = self.validate_ability_synergy, critical = false},
        {name = "type_coherence", func = self.validate_type_coherence, critical = false},
        {name = "power_level", func = self.validate_power_level, critical = false}
    }
end
-- }}}

-- {{{ function TemplateValidator:validate_template
function TemplateValidator:validate_template(template)
    self.error_messages = {}
    self.warning_messages = {}
    
    local is_valid = true
    
    for _, rule in ipairs(self.validation_rules) do
        local rule_result, messages = rule.func(self, template)
        
        if not rule_result then
            if rule.critical then
                is_valid = false
                for _, msg in ipairs(messages or {}) do
                    table.insert(self.error_messages, msg)
                end
            else
                for _, msg in ipairs(messages or {}) do
                    table.insert(self.warning_messages, msg)
                end
            end
        end
    end
    
    return is_valid, self.error_messages, self.warning_messages
end
-- }}}

-- {{{ function TemplateValidator:validate_point_budget
function TemplateValidator:validate_point_budget(template)
    local messages = {}
    
    if not template.point_budget or template.point_budget <= 0 then
        table.insert(messages, "Template must have a positive point budget")
        return false, messages
    end
    
    if template.points_used > template.point_budget then
        table.insert(messages, 
            string.format("Template exceeds point budget: %d/%d points used", 
                         template.points_used, template.point_budget))
        return false, messages
    end
    
    local unused_points = template.point_budget - template.points_used
    if unused_points > template.point_budget * 0.1 then
        table.insert(messages, 
            string.format("Template has %d unused points (%.1f%% of budget)", 
                         unused_points, unused_points / template.point_budget * 100))
    end
    
    return true, messages
end
-- }}}

-- {{{ function TemplateValidator:validate_stat_ranges
function TemplateValidator:validate_stat_ranges(template)
    local messages = {}
    local is_valid = true
    local constraints = self.constraints.stat_constraints
    
    for stat_name, value in pairs(template.stats) do
        if constraints[stat_name] then
            local constraint = constraints[stat_name]
            
            if value < constraint.min then
                table.insert(messages, 
                    string.format("%s (%d) below minimum (%d)", stat_name, value, constraint.min))
                is_valid = false
            elseif value > constraint.max then
                table.insert(messages, 
                    string.format("%s (%d) exceeds maximum (%d)", stat_name, value, constraint.max))
                is_valid = false
            end
            
            -- Warning for extreme values
            if value > constraint.max * 0.9 then
                table.insert(messages, 
                    string.format("%s (%d) is very high, may cause balance issues", stat_name, value))
            elseif value < constraint.min * 1.2 then
                table.insert(messages, 
                    string.format("%s (%d) is very low, unit may be ineffective", stat_name, value))
            end
        end
    end
    
    return is_valid, messages
end
-- }}}

-- {{{ function TemplateValidator:validate_ability_count
function TemplateValidator:validate_ability_count(template)
    local messages = {}
    local ability_count = #template.abilities
    local constraints = self.constraints.ability_constraints
    
    if ability_count < constraints.min_abilities then
        table.insert(messages, 
            string.format("Template must have at least %d abilities (has %d)", 
                         constraints.min_abilities, ability_count))
        return false, messages
    end
    
    if ability_count > constraints.max_abilities then
        table.insert(messages, 
            string.format("Template cannot have more than %d abilities (has %d)", 
                         constraints.max_abilities, ability_count))
        return false, messages
    end
    
    return true, messages
end
-- }}}

-- {{{ function TemplateValidator:validate_abilities
function TemplateValidator:validate_abilities(template)
    local messages = {}
    local is_valid = true
    
    for i, ability in ipairs(template.abilities) do
        local ability_valid, ability_messages = self:validate_single_ability(ability, i, template)
        
        if not ability_valid then
            is_valid = false
        end
        
        for _, msg in ipairs(ability_messages) do
            table.insert(messages, string.format("Ability %d (%s): %s", i, ability.name or "Unnamed", msg))
        end
    end
    
    return is_valid, messages
end
-- }}}

-- {{{ function TemplateValidator:validate_single_ability
function TemplateValidator:validate_single_ability(ability, index, template)
    local messages = {}
    local is_valid = true
    local constraints = self.constraints.ability_constraints
    
    -- Required fields
    if not ability.name or ability.name == "" then
        table.insert(messages, "Must have a name")
        is_valid = false
    end
    
    if not ability.effect_type or ability.effect_type == "" then
        table.insert(messages, "Must specify effect type")
        is_valid = false
    elseif not constraints.valid_effect_types[ability.effect_type] then
        table.insert(messages, 
            string.format("Invalid effect type '%s'", ability.effect_type))
        is_valid = false
    end
    
    if not ability.target_type or ability.target_type == "" then
        table.insert(messages, "Must specify target type")
        is_valid = false
    elseif not constraints.valid_target_types[ability.target_type] then
        table.insert(messages, 
            string.format("Invalid target type '%s'", ability.target_type))
        is_valid = false
    end
    
    -- Value ranges
    if ability.base_value then
        if ability.base_value <= 0 then
            table.insert(messages, "Base value must be positive")
            is_valid = false
        elseif ability.base_value > constraints.max_base_value then
            table.insert(messages, 
                string.format("Base value (%d) exceeds maximum (%d)", 
                             ability.base_value, constraints.max_base_value))
            is_valid = false
        end
    end
    
    if ability.range then
        if ability.range <= 0 then
            table.insert(messages, "Range must be positive")
            is_valid = false
        elseif ability.range > constraints.max_range then
            table.insert(messages, 
                string.format("Range (%d) exceeds maximum (%d)", 
                             ability.range, constraints.max_range))
            is_valid = false
        end
    end
    
    -- Type-specific validation
    local type_valid, type_messages = self:validate_ability_by_type(ability, template)
    if not type_valid then
        is_valid = false
    end
    for _, msg in ipairs(type_messages) do
        table.insert(messages, msg)
    end
    
    return is_valid, messages
end
-- }}}

-- {{{ function TemplateValidator:validate_ability_by_type
function TemplateValidator:validate_ability_by_type(ability, template)
    local messages = {}
    local is_valid = true
    
    if ability.effect_type == "damage" then
        if ability.target_type ~= "enemy" then
            table.insert(messages, "Damage abilities must target enemies")
            is_valid = false
        end
        
        if template.stats.unit_type == "melee" and ability.range > 40 then
            table.insert(messages, "Melee units should not have long-range damage abilities")
        end
        
    elseif ability.effect_type == "heal" then
        if ability.target_type ~= "ally" then
            table.insert(messages, "Heal abilities must target allies")
            is_valid = false
        end
        
        if not ability.base_value then
            table.insert(messages, "Heal abilities must specify healing amount")
            is_valid = false
        end
        
    elseif ability.effect_type == "buff" or ability.effect_type == "debuff" then
        if not ability.duration then
            table.insert(messages, "Buff/debuff abilities must specify duration")
            is_valid = false
        elseif ability.duration > self.constraints.ability_constraints.max_duration then
            table.insert(messages, 
                string.format("Duration (%d) exceeds maximum (%d)", 
                             ability.duration, self.constraints.ability_constraints.max_duration))
            is_valid = false
        end
    end
    
    return is_valid, messages
end
-- }}}

-- {{{ function TemplateValidator:validate_template_name
function TemplateValidator:validate_template_name(template)
    local messages = {}
    local constraints = self.constraints.template_constraints
    
    if not template.name or template.name == "" then
        table.insert(messages, "Template must have a name")
        return false, messages
    end
    
    if string.len(template.name) > constraints.max_name_length then
        table.insert(messages, 
            string.format("Name too long (%d chars, max %d)", 
                         string.len(template.name), constraints.max_name_length))
        return false, messages
    end
    
    if string.len(template.name) < constraints.min_name_length then
        table.insert(messages, 
            string.format("Name too short (%d chars, min %d)", 
                         string.len(template.name), constraints.min_name_length))
        return false, messages
    end
    
    -- Check for invalid characters
    if string.match(template.name, "[^%w%s%-_]") then
        table.insert(messages, "Name contains invalid characters (use only letters, numbers, spaces, hyphens, underscores)")
        return false, messages
    end
    
    return true, messages
end
-- }}}

-- {{{ function TemplateValidator:validate_stat_distribution
function TemplateValidator:validate_stat_distribution(template)
    local messages = {}
    local stats = template.stats
    
    -- Check for extremely unbalanced stat distribution
    local total_stats = stats.health + stats.speed + stats.armor + stats.detection_range
    local stat_percentages = {
        health = stats.health / total_stats,
        speed = stats.speed / total_stats,
        armor = stats.armor / total_stats,
        detection_range = stats.detection_range / total_stats
    }
    
    for stat_name, percentage in pairs(stat_percentages) do
        if percentage > 0.7 then
            table.insert(messages, 
                string.format("Stat distribution heavily focused on %s (%.1f%% of total)", 
                             stat_name, percentage * 100))
        end
    end
    
    return true, messages
end
-- }}}

-- {{{ function TemplateValidator:validate_ability_synergy
function TemplateValidator:validate_ability_synergy(template)
    local messages = {}
    
    -- Check for conflicting ability types
    local has_melee_abilities = false
    local has_long_range_abilities = false
    
    for _, ability in ipairs(template.abilities) do
        if ability.range and ability.range <= 30 then
            has_melee_abilities = true
        elseif ability.range and ability.range > 80 then
            has_long_range_abilities = true
        end
    end
    
    if has_melee_abilities and has_long_range_abilities then
        table.insert(messages, "Template has both short and long range abilities - may lack focus")
    end
    
    -- Check for redundant abilities
    local effect_types = {}
    for _, ability in ipairs(template.abilities) do
        effect_types[ability.effect_type] = (effect_types[ability.effect_type] or 0) + 1
    end
    
    for effect_type, count in pairs(effect_types) do
        if count > 2 then
            table.insert(messages, 
                string.format("Template has %d %s abilities - may be redundant", count, effect_type))
        end
    end
    
    return true, messages
end
-- }}}

-- {{{ function TemplateValidator:validate_type_coherence
function TemplateValidator:validate_type_coherence(template)
    local messages = {}
    
    if template.stats.unit_type == "melee" then
        if template.stats.speed > 100 then
            table.insert(messages, "Very high speed unusual for melee units")
        end
        
        if template.stats.detection_range > 80 then
            table.insert(messages, "Very high detection range unusual for melee units")
        end
        
    elseif template.stats.unit_type == "ranged" then
        if template.stats.armor > 5 then
            table.insert(messages, "High armor unusual for ranged units")
        end
        
        if template.stats.health > 200 then
            table.insert(messages, "Very high health unusual for ranged units")
        end
    end
    
    return true, messages
end
-- }}}

-- {{{ function TemplateValidator:validate_power_level
function TemplateValidator:validate_power_level(template)
    local messages = {}
    local BalanceCalculator = require("src.systems.balance_calculator")
    local calculator = BalanceCalculator:new()
    
    local effectiveness = calculator:calculate_combat_effectiveness(template)
    local expected_effectiveness = 100 -- Baseline expectation
    
    local deviation = math.abs(effectiveness.total_score - expected_effectiveness) / expected_effectiveness
    
    if deviation > 0.3 then
        if effectiveness.total_score > expected_effectiveness then
            table.insert(messages, "Template appears significantly overpowered")
        else
            table.insert(messages, "Template appears significantly underpowered")
        end
    end
    
    return true, messages
end
-- }}}

return TemplateValidator
```

### Template Constraints Configuration (src/config/template_constraints.lua)
```lua
-- {{{ template_constraints
return {
    template_constraints = {
        min_name_length = 3,
        max_name_length = 30,
        max_description_length = 200
    },
    
    stat_constraints = {
        health = {min = 30, max = 500, recommended_min = 50, recommended_max = 300},
        speed = {min = 5, max = 200, recommended_min = 20, recommended_max = 120},
        armor = {min = 0, max = 25, recommended_min = 0, recommended_max = 15},
        detection_range = {min = 20, max = 300, recommended_min = 40, recommended_max = 150}
    },
    
    ability_constraints = {
        min_abilities = 1,
        max_abilities = 4,
        max_base_value = 200,
        max_range = 250,
        max_duration = 30,
        max_area_radius = 50,
        
        valid_effect_types = {
            damage = true,
            heal = true,
            buff = true,
            debuff = true,
            utility = true
        },
        
        valid_target_types = {
            enemy = true,
            ally = true,
            self = true,
            ground = true
        }
    },
    
    balance_constraints = {
        max_point_efficiency_deviation = 0.2, -- 20% from expected
        max_stat_dominance = 0.7, -- No single stat can be 70%+ of total
        max_ability_redundancy = 2 -- No more than 2 abilities of same type
    }
}
-- }}}
```

### Acceptance Criteria
- [ ] All invalid templates are rejected with clear error messages
- [ ] Warnings are provided for potentially problematic but legal templates
- [ ] Validation covers all critical game balance aspects
- [ ] Error messages are specific and actionable
- [ ] Validation performance is acceptable for real-time use
- [ ] Constraint system is configurable and maintainable