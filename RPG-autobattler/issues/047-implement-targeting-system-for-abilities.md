# Issue #406: Implement Targeting System for Abilities

## Current Behavior
Ability components exist but lack a comprehensive targeting system to identify, validate, and select appropriate targets for ability execution.

## Intended Behavior
Implement a sophisticated targeting system that handles different targeting types, range validation, line-of-sight checking, and target prioritization for all ability types.

## Implementation Details

### Core Targeting System (src/systems/targeting_system.lua)
```lua
-- {{{ TargetingSystem
local TargetingSystem = {}
TargetingSystem.__index = TargetingSystem

function TargetingSystem:new()
    local system = {
        -- Targeting parameters
        max_search_distance = 200,
        line_of_sight_precision = 5, -- points to check along line
        area_search_precision = 8, -- segments for circular areas
        
        -- Performance optimization
        target_cache = {},
        cache_duration = 0.1, -- seconds
        last_cache_clear = 0,
        
        -- Targeting modes
        targeting_modes = {
            "closest_enemy",
            "weakest_enemy", 
            "strongest_enemy",
            "closest_ally",
            "weakest_ally",
            "ground_point",
            "area_center",
            "self",
            "most_enemies_in_area",
            "priority_target"
        }
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function TargetingSystem:find_targets
function TargetingSystem:find_targets(caster_id, ability, entity_manager)
    local caster_position = entity_manager:get_component(caster_id, "position")
    local caster_team = entity_manager:get_component(caster_id, "team")
    
    if not caster_position or not caster_team then
        return {}
    end
    
    local targeting_type = ability.targeting_type
    local targets = {}
    
    if targeting_type == "enemy" then
        targets = self:find_enemy_targets(caster_id, caster_position, caster_team, ability, entity_manager)
    elseif targeting_type == "ally" then
        targets = self:find_ally_targets(caster_id, caster_position, caster_team, ability, entity_manager)
    elseif targeting_type == "self" then
        targets = {caster_id}
    elseif targeting_type == "ground" then
        targets = self:find_ground_targets(caster_id, caster_position, ability, entity_manager)
    elseif targeting_type == "area" then
        targets = self:find_area_targets(caster_id, caster_position, caster_team, ability, entity_manager)
    elseif targeting_type == "any" then
        targets = self:find_any_targets(caster_id, caster_position, ability, entity_manager)
    end
    
    -- Apply target validation and filtering
    targets = self:validate_targets(caster_id, targets, ability, entity_manager)
    
    -- Apply target prioritization
    targets = self:prioritize_targets(caster_id, targets, ability, entity_manager)
    
    -- Limit to max targets
    if ability.max_targets and #targets > ability.max_targets then
        local limited_targets = {}
        for i = 1, ability.max_targets do
            table.insert(limited_targets, targets[i])
        end
        targets = limited_targets
    end
    
    return targets
end
-- }}}

-- {{{ function TargetingSystem:find_enemy_targets
function TargetingSystem:find_enemy_targets(caster_id, caster_position, caster_team, ability, entity_manager)
    local potential_targets = {}
    local search_range = ability.range or self.max_search_distance
    
    for entity_id, team_component in entity_manager:iterate_components("team") do
        if entity_id ~= caster_id and team_component.value ~= caster_team.value then
            local target_position = entity_manager:get_component(entity_id, "position")
            local target_health = entity_manager:get_component(entity_id, "health")
            
            if target_position and target_health and target_health.current > 0 then
                local distance = caster_position.value:distance_to(target_position.value)
                
                if distance <= search_range then
                    table.insert(potential_targets, {
                        id = entity_id,
                        distance = distance,
                        position = target_position.value,
                        health = target_health
                    })
                end
            end
        end
    end
    
    return potential_targets
end
-- }}}

-- {{{ function TargetingSystem:find_ally_targets
function TargetingSystem:find_ally_targets(caster_id, caster_position, caster_team, ability, entity_manager)
    local potential_targets = {}
    local search_range = ability.range or self.max_search_distance
    
    for entity_id, team_component in entity_manager:iterate_components("team") do
        if team_component.value == caster_team.value then
            local target_position = entity_manager:get_component(entity_id, "position")
            local target_health = entity_manager:get_component(entity_id, "health")
            
            if target_position and target_health and target_health.current > 0 then
                local distance = caster_position.value:distance_to(target_position.value)
                
                if distance <= search_range then
                    -- Include self unless specifically excluded
                    if entity_id == caster_id then
                        if ability.can_target_self ~= false then
                            table.insert(potential_targets, {
                                id = entity_id,
                                distance = 0,
                                position = target_position.value,
                                health = target_health,
                                is_self = true
                            })
                        end
                    else
                        table.insert(potential_targets, {
                            id = entity_id,
                            distance = distance,
                            position = target_position.value,
                            health = target_health
                        })
                    end
                end
            end
        end
    end
    
    return potential_targets
end
-- }}}

-- {{{ function TargetingSystem:find_ground_targets
function TargetingSystem:find_ground_targets(caster_id, caster_position, ability, entity_manager)
    -- For ground-targeted abilities, we need to find optimal ground positions
    local potential_positions = {}
    local search_range = ability.range or 100
    local grid_resolution = 20 -- Check positions every 20 units
    
    -- Generate grid points within range
    for x = -search_range, search_range, grid_resolution do
        for y = -search_range, search_range, grid_resolution do
            local test_position = caster_position.value:add(Vector2:new(x, y))
            local distance = caster_position.value:distance_to(test_position)
            
            if distance <= search_range then
                -- Check if position is valid (not blocked by terrain)
                if self:is_position_valid(test_position, entity_manager) then
                    local score = self:evaluate_ground_position(test_position, ability, entity_manager)
                    
                    if score > 0 then
                        table.insert(potential_positions, {
                            position = test_position,
                            distance = distance,
                            score = score
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by score (highest first)
    table.sort(potential_positions, function(a, b) return a.score > b.score end)
    
    return potential_positions
end
-- }}}

-- {{{ function TargetingSystem:find_area_targets
function TargetingSystem:find_area_targets(caster_id, caster_position, caster_team, ability, entity_manager)
    local area_radius = ability.area_of_effect or 50
    local base_range = ability.range or 100
    
    -- First find the best center point for the area effect
    local best_center = self:find_optimal_area_center(caster_id, caster_position, caster_team, ability, entity_manager)
    
    if not best_center then
        return {}
    end
    
    -- Find all entities within the area
    local targets_in_area = {}
    
    for entity_id, position_component in entity_manager:iterate_components("position") do
        if entity_id ~= caster_id then
            local distance_to_center = position_component.value:distance_to(best_center)
            
            if distance_to_center <= area_radius then
                local health = entity_manager:get_component(entity_id, "health")
                local team = entity_manager:get_component(entity_id, "team")
                
                if health and health.current > 0 and team then
                    -- Check if this entity type is valid for this ability
                    local is_valid_target = false
                    
                    if ability.targeting_type == "area" and ability.area_target_type == "enemies" then
                        is_valid_target = team.value ~= caster_team.value
                    elseif ability.targeting_type == "area" and ability.area_target_type == "allies" then
                        is_valid_target = team.value == caster_team.value
                    else -- any
                        is_valid_target = true
                    end
                    
                    if is_valid_target then
                        table.insert(targets_in_area, {
                            id = entity_id,
                            distance_to_caster = caster_position.value:distance_to(position_component.value),
                            distance_to_center = distance_to_center,
                            position = position_component.value,
                            health = health,
                            team = team
                        })
                    end
                end
            end
        end
    end
    
    return targets_in_area
end
-- }}}

-- {{{ function TargetingSystem:find_optimal_area_center
function TargetingSystem:find_optimal_area_center(caster_id, caster_position, caster_team, ability, entity_manager)
    local search_range = ability.range or 100
    local area_radius = ability.area_of_effect or 50
    local grid_resolution = 15
    
    local best_position = nil
    local best_score = 0
    
    -- Search grid points within casting range
    for x = -search_range, search_range, grid_resolution do
        for y = -search_range, search_range, grid_resolution do
            local test_center = caster_position.value:add(Vector2:new(x, y))
            local distance_to_caster = caster_position.value:distance_to(test_center)
            
            if distance_to_caster <= search_range then
                local score = self:evaluate_area_center(test_center, area_radius, caster_team, ability, entity_manager)
                
                if score > best_score then
                    best_score = score
                    best_position = test_center
                end
            end
        end
    end
    
    return best_position
end
-- }}}

-- {{{ function TargetingSystem:evaluate_area_center
function TargetingSystem:evaluate_area_center(center, radius, caster_team, ability, entity_manager)
    local score = 0
    local target_count = 0
    local ally_count = 0
    
    for entity_id, position_component in entity_manager:iterate_components("position") do
        local distance = position_component.value:distance_to(center)
        
        if distance <= radius then
            local team = entity_manager:get_component(entity_id, "team")
            local health = entity_manager:get_component(entity_id, "health")
            
            if team and health and health.current > 0 then
                if team.value ~= caster_team.value then
                    -- Enemy in area
                    target_count = target_count + 1
                    score = score + (health.current / health.max) * 10 -- Weight by current health
                else
                    -- Ally in area
                    ally_count = ally_count + 1
                    
                    -- For damage abilities, allies reduce score
                    if ability.type == "damage" then
                        score = score - 5
                    elseif ability.type == "heal" then
                        -- For healing, missing health increases score
                        local health_missing = health.max - health.current
                        score = score + (health_missing / health.max) * 8
                    end
                end
            end
        end
    end
    
    -- Bonus for hitting multiple targets
    if target_count >= 2 then
        score = score * (1 + (target_count - 1) * 0.3)
    end
    
    return score
end
-- }}}

-- {{{ function TargetingSystem:validate_targets
function TargetingSystem:validate_targets(caster_id, targets, ability, entity_manager)
    local valid_targets = {}
    local caster_position = entity_manager:get_component(caster_id, "position")
    
    for _, target in ipairs(targets) do
        local is_valid = true
        local target_id = target.id
        local target_position = target.position
        
        -- Check line of sight if required
        if ability.line_of_sight_required and target_position then
            if not self:has_line_of_sight(caster_position.value, target_position, entity_manager) then
                is_valid = false
            end
        end
        
        -- Check if target is still alive and valid
        if target_id then
            local health = entity_manager:get_component(target_id, "health")
            if not health or health.current <= 0 then
                is_valid = false
            end
        end
        
        -- Custom validation based on ability type
        if is_valid then
            is_valid = self:custom_target_validation(caster_id, target, ability, entity_manager)
        end
        
        if is_valid then
            table.insert(valid_targets, target)
        end
    end
    
    return valid_targets
end
-- }}}

-- {{{ function TargetingSystem:has_line_of_sight
function TargetingSystem:has_line_of_sight(start_pos, end_pos, entity_manager)
    local direction = end_pos:subtract(start_pos)
    local distance = direction:length()
    
    if distance == 0 then return true end
    
    direction = direction:normalize()
    
    -- Check points along the line for obstructions
    local check_interval = distance / self.line_of_sight_precision
    
    for i = 1, self.line_of_sight_precision - 1 do
        local check_point = start_pos:add(direction:multiply(check_interval * i))
        
        if self:is_position_blocked(check_point, entity_manager) then
            return false
        end
    end
    
    return true
end
-- }}}

-- {{{ function TargetingSystem:is_position_blocked
function TargetingSystem:is_position_blocked(position, entity_manager)
    -- Check for terrain obstacles
    local collision_system = entity_manager:get_system("collision")
    if collision_system then
        return collision_system:is_position_blocked(position)
    end
    
    -- For now, no blocking - this would integrate with map/terrain system
    return false
end
-- }}}

-- {{{ function TargetingSystem:prioritize_targets
function TargetingSystem:prioritize_targets(caster_id, targets, ability, entity_manager)
    local priority_mode = ability.target_priority or "closest"
    
    if priority_mode == "closest" then
        table.sort(targets, function(a, b) return a.distance < b.distance end)
    elseif priority_mode == "weakest" then
        table.sort(targets, function(a, b) 
            return (a.health and a.health.current or 0) < (b.health and b.health.current or 0)
        end)
    elseif priority_mode == "strongest" then
        table.sort(targets, function(a, b) 
            return (a.health and a.health.current or 0) > (b.health and b.health.current or 0)
        end)
    elseif priority_mode == "lowest_health_percentage" then
        table.sort(targets, function(a, b) 
            local a_pct = a.health and (a.health.current / a.health.max) or 1
            local b_pct = b.health and (b.health.current / b.health.max) or 1
            return a_pct < b_pct
        end)
    elseif priority_mode == "highest_value" then
        -- Custom priority based on unit value/threat
        table.sort(targets, function(a, b) 
            local a_value = self:calculate_target_value(a.id, entity_manager)
            local b_value = self:calculate_target_value(b.id, entity_manager)
            return a_value > b_value
        end)
    end
    
    return targets
end
-- }}}

-- {{{ function TargetingSystem:calculate_target_value
function TargetingSystem:calculate_target_value(target_id, entity_manager)
    local unit = entity_manager:get_component(target_id, "unit")
    local health = entity_manager:get_component(target_id, "health")
    
    if not unit or not health then return 0 end
    
    local base_value = health.current
    
    -- Add value based on unit type
    if unit.unit_type == "ranged" then
        base_value = base_value * 1.2 -- Prioritize ranged units
    end
    
    -- Add value based on abilities
    local abilities = entity_manager:get_component(target_id, "abilities")
    if abilities then
        base_value = base_value * (1 + abilities.ability_count * 0.1)
    end
    
    return base_value
end
-- }}}

-- {{{ function TargetingSystem:custom_target_validation
function TargetingSystem:custom_target_validation(caster_id, target, ability, entity_manager)
    -- Override in specialized systems for custom validation logic
    return true
end
-- }}}

return TargetingSystem
```

### Target Information Component (src/components/target_info.lua)
```lua
-- {{{ TargetInfoComponent
local TargetInfoComponent = {}
TargetInfoComponent.__index = TargetInfoComponent

function TargetInfoComponent:new()
    local component = {
        current_target = nil,
        target_history = {},
        target_priority_list = {},
        preferred_target_types = {},
        avoid_target_types = {},
        last_target_search = 0,
        search_cooldown = 0.2, -- seconds between target searches
        target_lock_duration = 1.0 -- stick to target for this long
    }
    setmetatable(component, self)
    return component
end
-- }}}

-- {{{ function TargetInfoComponent:set_target
function TargetInfoComponent:set_target(target_data)
    if self.current_target and self.current_target.id ~= target_data.id then
        -- Add previous target to history
        table.insert(self.target_history, {
            target = self.current_target,
            lost_time = love.timer.getTime()
        })
        
        -- Keep history limited
        if #self.target_history > 10 then
            table.remove(self.target_history, 1)
        end
    end
    
    self.current_target = target_data
    self.current_target.acquired_time = love.timer.getTime()
end
-- }}}

-- {{{ function TargetInfoComponent:clear_target
function TargetInfoComponent:clear_target()
    if self.current_target then
        table.insert(self.target_history, {
            target = self.current_target,
            lost_time = love.timer.getTime()
        })
    end
    self.current_target = nil
end
-- }}}

-- {{{ function TargetInfoComponent:should_retarget
function TargetInfoComponent:should_retarget()
    if not self.current_target then return true end
    
    local current_time = love.timer.getTime()
    local target_age = current_time - self.current_target.acquired_time
    
    -- Allow retargeting after lock duration
    return target_age >= self.target_lock_duration
end
-- }}}

return TargetInfoComponent
```

### Integration with Ability System
```lua
-- Enhancement to ability activation system
-- {{{ function AbilityActivationSystem:execute_ability
function AbilityActivationSystem:execute_ability(caster_id, ability_index)
    local abilities = self.entity_manager:get_component(caster_id, "abilities")
    if not abilities then return false end
    
    local ability = abilities:get_ability(ability_index)
    if not ability then return false end
    
    -- Find targets using targeting system
    local targets = self.targeting_system:find_targets(caster_id, ability, self.entity_manager)
    
    if #targets == 0 then
        return false, "no_valid_targets"
    end
    
    -- Execute ability with found targets
    return self:apply_ability_effect(caster_id, ability, targets)
end
-- }}}
```

### Acceptance Criteria
- [ ] All targeting types (enemy, ally, self, ground, area) work correctly
- [ ] Line of sight validation prevents targeting through obstacles
- [ ] Target prioritization respects ability-specific preferences
- [ ] Area effect abilities find optimal center points
- [ ] Range validation ensures targets are within ability reach
- [ ] Performance scales well with large numbers of potential targets
- [ ] Target caching reduces redundant calculations
- [ ] System integrates seamlessly with ability activation