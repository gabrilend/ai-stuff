# Issue #413: Create Area-of-Effect Abilities

## Current Behavior
Single-target abilities exist but the game lacks area-of-effect (AoE) abilities to handle multiple targets and create tactical positioning decisions.

## Intended Behavior
Implement comprehensive AoE ability system with damage, healing, and utility effects that reward tactical positioning and create strategic depth in unit deployment.

## Implementation Details

### Area Damage Ability (src/abilities/meteor_strike.lua)
```lua
-- {{{ MeteorStrike
local AbilityComponent = require("src.components.ability")
local MeteorStrike = {}
MeteorStrike.__index = MeteorStrike
setmetatable(MeteorStrike, AbilityComponent)

function MeteorStrike:new(config)
    local ability = AbilityComponent:new({
        name = config.name or "Meteor Strike",
        type = "area_effect",
        category = "secondary",
        targeting_type = "area",
        range = config.range or 90,
        area_of_effect = config.area_radius or 35,
        max_mana_cost = 100,
        mana_generation_rate = config.mana_rate or 3,
        base_power = config.base_power or 40,
        
        -- Area damage properties
        area_effect_type = "damage",
        damage_type = "magical",
        area_target_type = "enemies",
        optimal_targets = config.optimal_targets or 3,
        
        -- Damage distribution
        center_damage_multiplier = config.center_multiplier or 1.0,
        edge_damage_multiplier = config.edge_multiplier or 0.6,
        damage_falloff = config.damage_falloff or "linear", -- linear, exponential, step
        
        -- Special effects
        knockback_force = config.knockback or 15,
        burn_duration = config.burn_duration or 3,
        burn_damage = config.burn_damage or 5,
        
        -- Casting properties
        cast_time = config.cast_time or 1.5,
        impact_delay = config.impact_delay or 0.5,
        warning_time = config.warning_time or 1.0,
        
        -- Generation conditions
        generation_conditions = {
            {type = "enemies_in_range", operator = ">=", value = 2},
            {type = "unit_type", value = config.required_unit_type or "any"}
        },
        
        -- Visual and audio
        visual_effect = config.visual_effect or "meteor_impact",
        sound_effect = config.sound_effect or "explosion",
        warning_effect = config.warning_effect or "target_indicator"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function MeteorStrike:find_targets
function MeteorStrike:find_targets(caster_id, entity_manager, targeting_system)
    -- Find optimal impact point for maximum damage
    local impact_center = targeting_system:find_optimal_area_center(
        caster_id,
        entity_manager:get_component(caster_id, "position"),
        entity_manager:get_component(caster_id, "team"),
        self, entity_manager
    )
    
    if not impact_center then return {} end
    
    -- Find all enemies within blast radius
    local targets_in_area = {}
    
    for entity_id, position_component in entity_manager:iterate_components("position") do
        local team = entity_manager:get_component(entity_id, "team")
        local health = entity_manager:get_component(entity_id, "health")
        local caster_team = entity_manager:get_component(caster_id, "team")
        
        if team and health and caster_team and 
           team.value ~= caster_team.value and health.current > 0 then
            
            local distance_to_center = position_component.value:distance_to(impact_center)
            
            if distance_to_center <= self.area_of_effect then
                table.insert(targets_in_area, {
                    id = entity_id,
                    position = position_component.value,
                    distance_to_center = distance_to_center,
                    health = health,
                    damage_multiplier = self:calculate_distance_multiplier(distance_to_center)
                })
            end
        end
    end
    
    -- Store impact center for effect application
    self.impact_center = impact_center
    
    return targets_in_area
end
-- }}}

-- {{{ function MeteorStrike:calculate_distance_multiplier
function MeteorStrike:calculate_distance_multiplier(distance_to_center)
    local radius = self.area_of_effect
    local distance_ratio = distance_to_center / radius
    
    if self.damage_falloff == "linear" then
        -- Linear falloff from center to edge
        local multiplier = self.center_damage_multiplier - 
                          (distance_ratio * (self.center_damage_multiplier - self.edge_damage_multiplier))
        return math.max(self.edge_damage_multiplier, multiplier)
        
    elseif self.damage_falloff == "exponential" then
        -- Exponential falloff (damage drops off quickly)
        local multiplier = self.center_damage_multiplier * math.exp(-distance_ratio * 2)
        return math.max(self.edge_damage_multiplier, multiplier)
        
    elseif self.damage_falloff == "step" then
        -- Step falloff (full damage in inner radius, reduced at edge)
        local inner_radius = radius * 0.5
        if distance_to_center <= inner_radius then
            return self.center_damage_multiplier
        else
            return self.edge_damage_multiplier
        end
        
    else
        return self.center_damage_multiplier
    end
end
-- }}}

-- {{{ function MeteorStrike:calculate_damage
function MeteorStrike:calculate_damage(caster_id, target, entity_manager)
    local base_damage = self.base_power * target.damage_multiplier
    
    -- Apply caster's magical power
    local caster_unit = entity_manager:get_component(caster_id, "unit")
    if caster_unit and caster_unit.stats then
        local magic_power = caster_unit.stats.magic_power or caster_unit.stats.attack or 1.0
        base_damage = base_damage * magic_power
    end
    
    -- Apply target's magic resistance
    local target_unit = entity_manager:get_component(target.id, "unit")
    if target_unit and target_unit.stats then
        local magic_resist = target_unit.stats.magic_resist or 0
        local damage_reduction = magic_resist / (magic_resist + 100)
        base_damage = base_damage * (1 - damage_reduction)
    end
    
    return math.floor(base_damage)
end
-- }}}

return MeteorStrike
```

### Area Healing Ability (src/abilities/healing_circle.lua)
```lua
-- {{{ HealingCircle
local AbilityComponent = require("src.components.ability")
local HealingCircle = {}
HealingCircle.__index = HealingCircle
setmetatable(HealingCircle, AbilityComponent)

function HealingCircle:new(config)
    local ability = AbilityComponent:new({
        name = config.name or "Healing Circle",
        type = "area_effect",
        category = "secondary",
        targeting_type = "area",
        range = config.range or 50,
        area_of_effect = config.area_radius or 40,
        max_mana_cost = 100,
        mana_generation_rate = config.mana_rate or 4,
        base_power = config.base_power or 25,
        
        -- Area healing properties
        area_effect_type = "heal",
        area_target_type = "allies",
        max_targets = config.max_targets or 5,
        
        -- Healing distribution
        equal_distribution = config.equal_distribution or false,
        prioritize_injured = config.prioritize_injured or true,
        healing_efficiency_bonus = config.efficiency_bonus or 0.1, -- 10% per target
        
        -- Special effects
        cleanse_debuffs = config.cleanse_debuffs or true,
        apply_regeneration = config.apply_regen or false,
        regeneration_duration = config.regen_duration or 5,
        
        -- Generation conditions
        generation_conditions = {
            {type = "allies_nearby", operator = ">=", value = 2}
        },
        
        -- Visual and audio
        visual_effect = config.visual_effect or "healing_wave",
        sound_effect = config.sound_effect or "group_heal"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function HealingCircle:find_targets
function HealingCircle:find_targets(caster_id, entity_manager, targeting_system)
    -- Find optimal center point for healing the most injured allies
    local healing_center = self:find_optimal_healing_center(caster_id, entity_manager)
    
    if not healing_center then return {} end
    
    -- Find all allies within healing radius
    local allies_in_area = {}
    local caster_team = entity_manager:get_component(caster_id, "team")
    
    for entity_id, position_component in entity_manager:iterate_components("position") do
        local team = entity_manager:get_component(entity_id, "team")
        local health = entity_manager:get_component(entity_id, "health")
        
        if team and health and caster_team and 
           team.value == caster_team.value then
            
            local distance_to_center = position_component.value:distance_to(healing_center)
            
            if distance_to_center <= self.area_of_effect then
                local health_missing = health.max - health.current
                
                -- Only include allies who need healing
                if health_missing > 0 then
                    table.insert(allies_in_area, {
                        id = entity_id,
                        position = position_component.value,
                        distance_to_center = distance_to_center,
                        health = health,
                        health_missing = health_missing,
                        health_percentage = health.current / health.max,
                        healing_priority = self:calculate_healing_priority(entity_id, health, entity_manager)
                    })
                end
            end
        end
    end
    
    if #allies_in_area == 0 then return {} end
    
    -- Sort by healing priority and limit to max targets
    table.sort(allies_in_area, function(a, b) 
        return a.healing_priority > b.healing_priority 
    end)
    
    if #allies_in_area > self.max_targets then
        local limited_targets = {}
        for i = 1, self.max_targets do
            table.insert(limited_targets, allies_in_area[i])
        end
        allies_in_area = limited_targets
    end
    
    -- Store healing center for effect application
    self.healing_center = healing_center
    
    return allies_in_area
end
-- }}}

-- {{{ function HealingCircle:find_optimal_healing_center
function HealingCircle:find_optimal_healing_center(caster_id, entity_manager)
    local caster_position = entity_manager:get_component(caster_id, "position")
    local caster_team = entity_manager:get_component(caster_id, "team")
    
    if not caster_position or not caster_team then return nil end
    
    local best_center = nil
    local best_score = 0
    
    -- Test potential centers within casting range
    local search_resolution = 15
    local search_range = self.range
    
    for x = -search_range, search_range, search_resolution do
        for y = -search_range, search_range, search_resolution do
            local test_center = caster_position.value:add(Vector2:new(x, y))
            local distance_to_caster = caster_position.value:distance_to(test_center)
            
            if distance_to_caster <= search_range then
                local score = self:evaluate_healing_center(test_center, caster_team, entity_manager)
                
                if score > best_score then
                    best_score = score
                    best_center = test_center
                end
            end
        end
    end
    
    return best_center
end
-- }}}

-- {{{ function HealingCircle:evaluate_healing_center
function HealingCircle:evaluate_healing_center(center, caster_team, entity_manager)
    local score = 0
    local allies_in_range = 0
    local total_healing_need = 0
    
    for entity_id, position_component in entity_manager:iterate_components("position") do
        local team = entity_manager:get_component(entity_id, "team")
        local health = entity_manager:get_component(entity_id, "health")
        
        if team and health and team.value == caster_team.value then
            local distance = position_component.value:distance_to(center)
            
            if distance <= self.area_of_effect then
                allies_in_range = allies_in_range + 1
                
                local health_missing = health.max - health.current
                local healing_need = health_missing / health.max
                total_healing_need = total_healing_need + healing_need
                
                -- Bonus for critically injured allies
                if healing_need > 0.5 then
                    score = score + 25
                elseif healing_need > 0.3 then
                    score = score + 15
                end
                
                -- Bonus for important unit types
                local unit = entity_manager:get_component(entity_id, "unit")
                if unit then
                    local type_bonuses = {
                        healer = 20,
                        ranged = 15,
                        melee = 10
                    }
                    score = score + (type_bonuses[unit.unit_type] or 10)
                end
            end
        end
    end
    
    -- Base score from number of allies and their healing needs
    score = score + (allies_in_range * 20) + (total_healing_need * 40)
    
    -- Bonus for efficiency (more targets = better efficiency)
    if allies_in_range >= 3 then
        score = score + (allies_in_range - 2) * 10
    end
    
    return score
end
-- }}}

-- {{{ function HealingCircle:calculate_healing_distribution
function HealingCircle:calculate_healing_distribution(targets, total_healing_power)
    local healing_distribution = {}
    
    if self.equal_distribution then
        -- Equal healing for all targets
        local healing_per_target = total_healing_power / #targets
        
        for _, target in ipairs(targets) do
            healing_distribution[target.id] = healing_per_target
        end
        
    else
        -- Proportional healing based on health missing and priority
        local total_priority = 0
        
        for _, target in ipairs(targets) do
            total_priority = total_priority + target.healing_priority
        end
        
        for _, target in ipairs(targets) do
            local healing_share = target.healing_priority / total_priority
            healing_distribution[target.id] = total_healing_power * healing_share
        end
    end
    
    return healing_distribution
end
-- }}}

return HealingCircle
```

### Area Utility Ability (src/abilities/static_field.lua)
```lua
-- {{{ StaticField
local AbilityComponent = require("src.components.ability")
local StaticField = {}
StaticField.__index = StaticField
setmetatable(StaticField, AbilityComponent)

function StaticField:new(config)
    local ability = AbilityComponent:new({
        name = config.name or "Static Field",
        type = "area_effect",
        category = "secondary",
        targeting_type = "area",
        range = config.range or 70,
        area_of_effect = config.area_radius or 45,
        max_mana_cost = 100,
        mana_generation_rate = config.mana_rate or 5,
        
        -- Utility area effect properties
        area_effect_type = "utility",
        effect_duration = config.duration or 8,
        persistent_area = true,
        
        -- Static field effects
        slow_effect = config.slow_factor or 0.4, -- 40% movement speed reduction
        damage_per_second = config.dps or 8,
        mana_drain_per_second = config.mana_drain or 5,
        
        -- Special mechanics
        chain_lightning_chance = config.chain_chance or 0.3,
        chain_lightning_damage = config.chain_damage or 15,
        chain_max_targets = config.chain_targets or 3,
        
        -- Generation conditions
        generation_conditions = {
            {type = "enemies_in_range", operator = ">=", value = 1},
            {type = "combat_state", value = "in_combat"}
        },
        
        -- Visual and audio
        visual_effect = config.visual_effect or "electric_field",
        sound_effect = config.sound_effect or "static_crackle"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function StaticField:find_targets
function StaticField:find_targets(caster_id, entity_manager, targeting_system)
    -- Find optimal position to place the static field
    local field_center = self:find_optimal_field_position(caster_id, entity_manager)
    
    if not field_center then return {} end
    
    -- Static field doesn't have immediate targets, but affects area over time
    self.field_center = field_center
    
    return {{
        id = "static_field_center",
        position = field_center,
        is_area_effect = true
    }}
end
-- }}}

-- {{{ function StaticField:find_optimal_field_position
function StaticField:find_optimal_field_position(caster_id, entity_manager)
    local caster_position = entity_manager:get_component(caster_id, "position")
    local caster_team = entity_manager:get_component(caster_id, "team")
    
    if not caster_position or not caster_team then return nil end
    
    local best_position = nil
    local best_score = 0
    
    -- Look for positions that will affect the most enemies over time
    local search_resolution = 20
    local search_range = self.range
    
    for x = -search_range, search_range, search_resolution do
        for y = -search_range, search_range, search_resolution do
            local test_position = caster_position.value:add(Vector2:new(x, y))
            local distance_to_caster = caster_position.value:distance_to(test_position)
            
            if distance_to_caster <= search_range then
                local score = self:evaluate_field_position(test_position, caster_team, entity_manager)
                
                if score > best_score then
                    best_score = score
                    best_position = test_position
                end
            end
        end
    end
    
    return best_position
end
-- }}}

-- {{{ function StaticField:evaluate_field_position
function StaticField:evaluate_field_position(position, caster_team, entity_manager)
    local score = 0
    local enemies_in_field = 0
    local allies_in_field = 0
    
    for entity_id, position_component in entity_manager:iterate_components("position") do
        local team = entity_manager:get_component(entity_id, "team")
        local health = entity_manager:get_component(entity_id, "health")
        
        if team and health and health.current > 0 then
            local distance = position_component.value:distance_to(position)
            
            if distance <= self.area_of_effect then
                if team.value ~= caster_team.value then
                    enemies_in_field = enemies_in_field + 1
                    
                    -- Higher score for more enemies
                    score = score + 20
                    
                    -- Bonus for high-value targets
                    local unit = entity_manager:get_component(entity_id, "unit")
                    if unit then
                        if unit.unit_type == "ranged" then
                            score = score + 15 -- Ranged units hate being slowed
                        elseif unit.unit_type == "healer" then
                            score = score + 25 -- Disrupt healers
                        end
                    end
                else
                    allies_in_field = allies_in_field + 1
                    score = score - 10 -- Penalty for affecting allies
                end
            end
        end
    end
    
    -- Bonus for tactical chokepoints (predicted enemy movement)
    score = score + self:evaluate_tactical_value(position, entity_manager)
    
    return score
end
-- }}}

-- {{{ function StaticField:evaluate_tactical_value
function StaticField:evaluate_tactical_value(position, entity_manager)
    local tactical_score = 0
    
    -- This would integrate with pathfinding to find chokepoints
    -- For now, simple heuristics
    
    -- Bonus for positions near lane centers
    -- Bonus for positions that block common movement paths
    -- Bonus for positions that protect important allies
    
    return tactical_score
end
-- }}}

return StaticField
```

### AoE Effect Manager (src/systems/area_effect_system.lua)
```lua
-- {{{ AreaEffectSystem
local AreaEffectSystem = {}
AreaEffectSystem.__index = AreaEffectSystem

function AreaEffectSystem:new(entity_manager)
    local system = {
        entity_manager = entity_manager,
        
        -- Active area effects
        active_areas = {}, -- [area_id] = area_data
        area_id_counter = 1,
        
        -- Update timing
        update_interval = 0.1, -- Update every 100ms
        last_update = 0,
        
        -- Effect types
        area_types = {
            damage_field = "damage_field",
            healing_field = "healing_field",
            utility_field = "utility_field",
            buff_aura = "buff_aura",
            debuff_aura = "debuff_aura"
        }
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function AreaEffectSystem:update
function AreaEffectSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update >= self.update_interval then
        self:update_active_areas(self.last_update)
        self.last_update = 0
    end
end
-- }}}

-- {{{ function AreaEffectSystem:create_persistent_area
function AreaEffectSystem:create_persistent_area(ability, center_position, caster_id)
    local area_id = self.area_id_counter
    self.area_id_counter = self.area_id_counter + 1
    
    local area_data = {
        id = area_id,
        center = center_position,
        radius = ability.area_of_effect,
        caster_id = caster_id,
        ability = ability,
        duration = ability.effect_duration,
        remaining_time = ability.effect_duration,
        last_tick_time = 0,
        tick_interval = ability.tick_interval or 1.0,
        affected_entities = {},
        creation_time = love.timer.getTime()
    }
    
    self.active_areas[area_id] = area_data
    
    -- Create visual effect for area
    self:create_area_visual_effect(area_data)
    
    return area_id
end
-- }}}

-- {{{ function AreaEffectSystem:update_active_areas
function AreaEffectSystem:update_active_areas(dt)
    local areas_to_remove = {}
    
    for area_id, area_data in pairs(self.active_areas) do
        area_data.remaining_time = area_data.remaining_time - dt
        area_data.last_tick_time = area_data.last_tick_time + dt
        
        -- Apply area effects if it's time for a tick
        if area_data.last_tick_time >= area_data.tick_interval then
            self:apply_area_tick(area_data)
            area_data.last_tick_time = 0
        end
        
        -- Check for expiration
        if area_data.remaining_time <= 0 then
            table.insert(areas_to_remove, area_id)
        end
    end
    
    -- Remove expired areas
    for _, area_id in ipairs(areas_to_remove) do
        self:remove_area_effect(area_id)
    end
end
-- }}}

-- {{{ function AreaEffectSystem:apply_area_tick
function AreaEffectSystem:apply_area_tick(area_data)
    local current_entities = self:find_entities_in_area(area_data)
    
    -- Apply effects to entities in area
    for _, entity_data in ipairs(current_entities) do
        self:apply_area_effect_to_entity(area_data, entity_data)
    end
    
    -- Update affected entities list
    area_data.affected_entities = current_entities
end
-- }}}

-- {{{ function AreaEffectSystem:find_entities_in_area
function AreaEffectSystem:find_entities_in_area(area_data)
    local entities_in_area = {}
    
    for entity_id, position_component in self.entity_manager:iterate_components("position") do
        local distance = position_component.value:distance_to(area_data.center)
        
        if distance <= area_data.radius then
            local health = self.entity_manager:get_component(entity_id, "health")
            local team = self.entity_manager:get_component(entity_id, "team")
            
            if health and team and health.current > 0 then
                table.insert(entities_in_area, {
                    id = entity_id,
                    position = position_component.value,
                    distance = distance,
                    health = health,
                    team = team
                })
            end
        end
    end
    
    return entities_in_area
end
-- }}}

-- {{{ function AreaEffectSystem:apply_area_effect_to_entity
function AreaEffectSystem:apply_area_effect_to_entity(area_data, entity_data)
    local ability = area_data.ability
    local caster_team = self.entity_manager:get_component(area_data.caster_id, "team")
    
    if not caster_team then return end
    
    local is_ally = entity_data.team.value == caster_team.value
    local is_enemy = entity_data.team.value ~= caster_team.value
    
    -- Apply effects based on ability type
    if ability.area_effect_type == "damage" and is_enemy then
        self:apply_area_damage(area_data, entity_data)
    elseif ability.area_effect_type == "heal" and is_ally then
        self:apply_area_healing(area_data, entity_data)
    elseif ability.area_effect_type == "utility" then
        self:apply_area_utility(area_data, entity_data)
    end
end
-- }}}

-- {{{ function AreaEffectSystem:apply_area_damage
function AreaEffectSystem:apply_area_damage(area_data, entity_data)
    local ability = area_data.ability
    local damage = ability.damage_per_second or 10
    
    -- Apply distance-based damage reduction
    local distance_factor = 1.0 - (entity_data.distance / area_data.radius) * 0.3
    local final_damage = damage * distance_factor
    
    -- Apply damage
    local actual_damage = math.min(final_damage, entity_data.health.current)
    entity_data.health.current = entity_data.health.current - actual_damage
    
    -- Create visual effect
    self:create_area_damage_visual(entity_data.id, actual_damage)
end
-- }}}

return AreaEffectSystem
```

### Acceptance Criteria
- [ ] Area damage abilities hit multiple enemies with appropriate falloff
- [ ] Area healing abilities efficiently heal multiple allies
- [ ] Area utility abilities create persistent tactical effects
- [ ] Optimal targeting finds best positions for maximum effect
- [ ] Damage distribution respects distance and line-of-sight
- [ ] Visual indicators clearly show area effect boundaries
- [ ] Performance scales with multiple simultaneous area effects
- [ ] Integration with existing targeting and effect systems works
- [ ] Balance between area power and single-target abilities is appropriate
- [ ] Tactical positioning becomes important for both offense and defense