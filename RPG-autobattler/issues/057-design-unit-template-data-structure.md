# Issue #501: Design Unit Template Data Structure

## Current Behavior
Units are created with hardcoded attributes and abilities, with no customization system in place.

## Intended Behavior
Implement a flexible unit template data structure that allows players to design custom units within a point-based balance system.

## Implementation Details

### Template Data Structure (src/data/unit_template.lua)
```lua
-- {{{ UnitTemplate
local UnitTemplate = {}
UnitTemplate.__index = UnitTemplate

function UnitTemplate:new(template_data)
    local template = {
        -- Basic Info
        name = template_data.name or "Unnamed Unit",
        description = template_data.description or "",
        created_by = template_data.created_by or "Player",
        version = template_data.version or 1,
        
        -- Point Budget
        point_budget = template_data.point_budget or 100,
        points_used = 0,
        
        -- Core Stats (costs points)
        stats = {
            health = template_data.stats.health or 100,
            speed = template_data.stats.speed or 50,
            armor = template_data.stats.armor or 0,
            detection_range = template_data.stats.detection_range or 60,
            unit_type = template_data.stats.unit_type or "melee" -- melee/ranged
        },
        
        -- Abilities (1-4 abilities, costs points)
        abilities = template_data.abilities or {},
        
        -- Visual Appearance
        appearance = {
            primary_color = template_data.appearance.primary_color or {1, 0, 0},
            secondary_color = template_data.appearance.secondary_color or {0.5, 0, 0},
            shape = template_data.appearance.shape or "circle",
            size_modifier = template_data.appearance.size_modifier or 1.0
        },
        
        -- Validation
        is_valid = false,
        validation_errors = {}
    }
    
    setmetatable(template, self)
    template:calculate_point_cost()
    template:validate()
    
    return template
end
-- }}}

-- {{{ function UnitTemplate:calculate_point_cost
function UnitTemplate:calculate_point_cost()
    local total_cost = 0
    
    -- Stat costs
    total_cost = total_cost + self:calculate_stat_costs()
    
    -- Ability costs
    total_cost = total_cost + self:calculate_ability_costs()
    
    self.points_used = total_cost
    return total_cost
end
-- }}}

-- {{{ function UnitTemplate:calculate_stat_costs
function UnitTemplate:calculate_stat_costs()
    local cost = 0
    local base_stats = {
        health = 100,
        speed = 50,
        armor = 0,
        detection_range = 60
    }
    
    -- Health: 1 point per 10 HP above base
    if self.stats.health > base_stats.health then
        cost = cost + math.ceil((self.stats.health - base_stats.health) / 10)
    end
    
    -- Speed: 2 points per 10 speed units above base
    if self.stats.speed > base_stats.speed then
        cost = cost + math.ceil((self.stats.speed - base_stats.speed) / 5)
    end
    
    -- Armor: 3 points per armor point
    cost = cost + (self.stats.armor * 3)
    
    -- Detection Range: 1 point per 20 units above base
    if self.stats.detection_range > base_stats.detection_range then
        cost = cost + math.ceil((self.stats.detection_range - base_stats.detection_range) / 20)
    end
    
    -- Unit type modifier
    if self.stats.unit_type == "ranged" then
        cost = cost + 10 -- Ranged units cost extra
    end
    
    return cost
end
-- }}}

-- {{{ function UnitTemplate:calculate_ability_costs
function UnitTemplate:calculate_ability_costs()
    local cost = 0
    
    for i, ability in ipairs(self.abilities) do
        cost = cost + self:get_ability_cost(ability, i == 1)
    end
    
    return cost
end
-- }}}

-- {{{ function UnitTemplate:get_ability_cost
function UnitTemplate:get_ability_cost(ability, is_primary)
    local base_cost = is_primary and 10 or 20 -- Primary abilities cost less
    local effect_multiplier = 1
    
    -- Cost modifiers based on ability type
    if ability.effect_type == "damage" then
        effect_multiplier = ability.base_value / 25 -- 1 point per 25 damage
    elseif ability.effect_type == "heal" then
        effect_multiplier = ability.base_value / 30 -- Healing is slightly cheaper
    elseif ability.effect_type == "buff" or ability.effect_type == "debuff" then
        effect_multiplier = ability.duration / 5 -- 1 point per 5 seconds
    end
    
    -- Range modifier
    local range_cost = math.max(0, (ability.range - 50) / 25) -- 1 point per 25 units above 50
    
    -- Area effect modifier
    local area_cost = 0
    if ability.area_radius and ability.area_radius > 0 then
        area_cost = ability.area_radius / 10 -- 1 point per 10 units radius
    end
    
    return math.ceil(base_cost * effect_multiplier + range_cost + area_cost)
end
-- }}}

-- {{{ function UnitTemplate:validate
function UnitTemplate:validate()
    self.validation_errors = {}
    
    -- Check point budget
    if self.points_used > self.point_budget then
        table.insert(self.validation_errors, 
            string.format("Exceeds point budget: %d/%d", self.points_used, self.point_budget))
    end
    
    -- Validate abilities count
    if #self.abilities < 1 then
        table.insert(self.validation_errors, "Must have at least 1 ability")
    elseif #self.abilities > 4 then
        table.insert(self.validation_errors, "Cannot have more than 4 abilities")
    end
    
    -- Validate stat ranges
    if self.stats.health < 50 then
        table.insert(self.validation_errors, "Health cannot be below 50")
    end
    
    if self.stats.speed < 10 then
        table.insert(self.validation_errors, "Speed cannot be below 10")
    end
    
    if self.stats.armor < 0 then
        table.insert(self.validation_errors, "Armor cannot be negative")
    end
    
    -- Validate abilities
    for i, ability in ipairs(self.abilities) do
        local ability_errors = self:validate_ability(ability, i)
        for _, error in ipairs(ability_errors) do
            table.insert(self.validation_errors, string.format("Ability %d: %s", i, error))
        end
    end
    
    self.is_valid = #self.validation_errors == 0
    return self.is_valid
end
-- }}}

-- {{{ function UnitTemplate:validate_ability
function UnitTemplate:validate_ability(ability, index)
    local errors = {}
    
    -- Required fields
    if not ability.name or ability.name == "" then
        table.insert(errors, "Must have a name")
    end
    
    if not ability.effect_type then
        table.insert(errors, "Must specify effect type")
    end
    
    if not ability.target_type then
        table.insert(errors, "Must specify target type")
    end
    
    -- Value ranges
    if ability.base_value and ability.base_value <= 0 then
        table.insert(errors, "Base value must be positive")
    end
    
    if ability.range and ability.range <= 0 then
        table.insert(errors, "Range must be positive")
    end
    
    if ability.max_mana and ability.max_mana <= 0 then
        table.insert(errors, "Max mana must be positive")
    end
    
    return errors
end
-- }}}

-- {{{ function UnitTemplate:to_save_data
function UnitTemplate:to_save_data()
    return {
        name = self.name,
        description = self.description,
        created_by = self.created_by,
        version = self.version,
        point_budget = self.point_budget,
        stats = self.stats,
        abilities = self.abilities,
        appearance = self.appearance
    }
end
-- }}}

-- {{{ function UnitTemplate.from_save_data
function UnitTemplate.from_save_data(save_data)
    return UnitTemplate:new(save_data)
end
-- }}}

return UnitTemplate
```

### Point Cost Configuration (src/config/template_costs.lua)
```lua
-- {{{ template_costs
return {
    -- Base point budget for all templates
    default_point_budget = 100,
    
    -- Stat cost formulas
    stat_costs = {
        health = {
            base_value = 100,
            cost_per_unit = 0.1, -- 1 point per 10 HP
            min_value = 50,
            max_value = 500
        },
        speed = {
            base_value = 50,
            cost_per_unit = 0.2, -- 1 point per 5 speed
            min_value = 10,
            max_value = 150
        },
        armor = {
            base_value = 0,
            cost_per_unit = 3, -- 3 points per armor
            min_value = 0,
            max_value = 20
        },
        detection_range = {
            base_value = 60,
            cost_per_unit = 0.05, -- 1 point per 20 units
            min_value = 30,
            max_value = 200
        }
    },
    
    -- Unit type modifiers
    type_costs = {
        melee = 0,
        ranged = 10
    },
    
    -- Ability cost bases
    ability_costs = {
        primary_base = 10,
        secondary_base = 20,
        damage_multiplier = 0.04, -- per damage point
        heal_multiplier = 0.033, -- per heal point  
        range_cost = 0.04, -- per range unit above 50
        area_cost = 0.1 -- per area radius unit
    }
}
-- }}}
```

### Template Manager (src/managers/template_manager.lua)
```lua
-- {{{ TemplateManager
local TemplateManager = {}
TemplateManager.__index = TemplateManager

function TemplateManager:new()
    local manager = {
        templates = {},
        default_templates = {}
    }
    setmetatable(manager, self)
    return manager
end
-- }}}

-- {{{ function TemplateManager:register_template
function TemplateManager:register_template(template)
    if template:validate() then
        self.templates[template.name] = template
        return true
    end
    return false, template.validation_errors
end
-- }}}

-- {{{ function TemplateManager:get_template
function TemplateManager:get_template(name)
    return self.templates[name]
end
-- }}}

-- {{{ function TemplateManager:create_default_templates
function TemplateManager:create_default_templates()
    local UnitTemplate = require("src.data.unit_template")
    
    -- Basic Warrior
    local warrior = UnitTemplate:new({
        name = "Basic Warrior",
        stats = {
            health = 150,
            speed = 40,
            armor = 2,
            detection_range = 50,
            unit_type = "melee"
        },
        abilities = {
            {
                name = "Sword Strike",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 30,
                range = 25,
                max_mana = 100
            }
        }
    })
    
    -- Basic Archer
    local archer = UnitTemplate:new({
        name = "Basic Archer",
        stats = {
            health = 80,
            speed = 60,
            armor = 0,
            detection_range = 100,
            unit_type = "ranged"
        },
        abilities = {
            {
                name = "Bow Shot",
                effect_type = "damage",
                target_type = "enemy",
                base_value = 25,
                range = 80,
                max_mana = 100
            }
        }
    })
    
    self.default_templates.warrior = warrior
    self.default_templates.archer = archer
    
    return self.default_templates
end
-- }}}

return TemplateManager
```

### Acceptance Criteria
- [ ] Template data structure supports all required fields and validation
- [ ] Point-based balance system accurately calculates costs
- [ ] Templates can be created, validated, and saved
- [ ] Default templates provide good starting examples
- [ ] Template manager handles registration and retrieval
- [ ] Point costs encourage meaningful trade-offs in design