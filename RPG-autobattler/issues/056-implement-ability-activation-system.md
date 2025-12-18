# Issue #500: Implement Ability Activation System

## Current Behavior
Units have mana bars that fill up but no mechanism to actually use abilities when mana reaches maximum capacity.

## Intended Behavior
Units should automatically trigger abilities when mana is full and valid targets are available, with proper mana consumption based on damage/healing effectiveness.

## Implementation Details

### Ability Activation Component (src/components/ability_activator.lua)
```lua
-- {{{ AbilityActivatorComponent
local AbilityActivatorComponent = {}
AbilityActivatorComponent.__index = AbilityActivatorComponent

function AbilityActivatorComponent:new(abilities_config)
    local component = {
        abilities = abilities_config or {},
        last_activation_times = {},
        cooldown_remaining = {},
        target_cache = {},
        activation_queue = {}
    }
    
    for i, ability in ipairs(component.abilities) do
        component.last_activation_times[i] = 0
        component.cooldown_remaining[i] = 0
    end
    
    setmetatable(component, self)
    return component
end
-- }}}

-- {{{ function AbilityActivatorComponent:can_activate
function AbilityActivatorComponent:can_activate(ability_index, current_time)
    return self.cooldown_remaining[ability_index] <= 0
end
-- }}}

-- {{{ function AbilityActivatorComponent:queue_activation
function AbilityActivatorComponent:queue_activation(ability_index, target_id, effectiveness)
    table.insert(self.activation_queue, {
        ability_index = ability_index,
        target_id = target_id,
        effectiveness = effectiveness,
        timestamp = love.timer.getTime()
    })
end
-- }}}

return AbilityActivatorComponent
```

### Ability Activation System (src/systems/ability_activation_system.lua)
```lua
-- {{{ AbilityActivationSystem
local AbilityActivationSystem = {}
AbilityActivationSystem.__index = AbilityActivationSystem

function AbilityActivationSystem:new()
    local system = {
        activation_range = 80,
        target_refresh_rate = 0.1, -- seconds between target scans
        last_target_scan = 0
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function AbilityActivationSystem:update
function AbilityActivationSystem:update(dt, entity_manager)
    local current_time = love.timer.getTime()
    
    -- Refresh targets periodically for performance
    if current_time - self.last_target_scan > self.target_refresh_rate then
        self:refresh_all_targets(entity_manager)
        self.last_target_scan = current_time
    end
    
    for entity_id, activator in entity_manager:iterate_components("ability_activator") do
        self:process_ability_activations(entity_id, activator, entity_manager, dt)
    end
end
-- }}}

-- {{{ function AbilityActivationSystem:process_ability_activations
function AbilityActivationSystem:process_ability_activations(entity_id, activator, entity_manager, dt)
    local mana_component = entity_manager:get_component(entity_id, "mana")
    if not mana_component then return end
    
    -- Update cooldowns
    for i, _ in ipairs(activator.abilities) do
        if activator.cooldown_remaining[i] > 0 then
            activator.cooldown_remaining[i] = math.max(0, activator.cooldown_remaining[i] - dt)
        end
    end
    
    -- Check each ability for activation
    for i, ability in ipairs(activator.abilities) do
        self:check_ability_activation(entity_id, i, ability, activator, mana_component, entity_manager)
    end
    
    -- Process queued activations
    self:execute_activation_queue(entity_id, activator, entity_manager)
end
-- }}}

-- {{{ function AbilityActivationSystem:check_ability_activation
function AbilityActivationSystem:check_ability_activation(entity_id, ability_index, ability, activator, mana_component, entity_manager)
    -- Check if mana is at maximum
    if mana_component.current_mana[ability_index] < mana_component.max_mana[ability_index] then
        return
    end
    
    -- Check if ability is off cooldown
    if not activator:can_activate(ability_index, love.timer.getTime()) then
        return
    end
    
    -- Find valid targets
    local targets = self:find_valid_targets(entity_id, ability, entity_manager)
    if #targets == 0 then
        return -- Keep mana at max until targets appear
    end
    
    -- Select best target and calculate effectiveness
    local best_target, effectiveness = self:select_optimal_target(ability, targets, entity_manager)
    if best_target and effectiveness > 0 then
        activator:queue_activation(ability_index, best_target, effectiveness)
    end
end
-- }}}

-- {{{ function AbilityActivationSystem:find_valid_targets
function AbilityActivationSystem:find_valid_targets(entity_id, ability, entity_manager)
    local caster_position = entity_manager:get_component(entity_id, "position")
    local caster_team = entity_manager:get_component(entity_id, "team")
    
    if not caster_position or not caster_team then return {} end
    
    local targets = {}
    local target_component_name = ability.target_type == "enemy" and "team" or "health"
    
    for target_id, component in entity_manager:iterate_components(target_component_name) do
        if target_id ~= entity_id and self:is_valid_target(entity_id, target_id, ability, entity_manager) then
            local target_position = entity_manager:get_component(target_id, "position")
            if target_position then
                local distance = caster_position.value:distance_to(target_position.value)
                if distance <= ability.range then
                    table.insert(targets, {
                        id = target_id,
                        distance = distance,
                        position = target_position.value
                    })
                end
            end
        end
    end
    
    return targets
end
-- }}}

-- {{{ function AbilityActivationSystem:is_valid_target
function AbilityActivationSystem:is_valid_target(caster_id, target_id, ability, entity_manager)
    local caster_team = entity_manager:get_component(caster_id, "team")
    local target_team = entity_manager:get_component(target_id, "team")
    local target_health = entity_manager:get_component(target_id, "health")
    
    if not caster_team or not target_team or not target_health then return false end
    if target_health.current <= 0 then return false end
    
    if ability.target_type == "enemy" then
        return caster_team.value ~= target_team.value
    elseif ability.target_type == "ally" then
        return caster_team.value == target_team.value and target_health.current < target_health.max
    end
    
    return false
end
-- }}}

-- {{{ function AbilityActivationSystem:select_optimal_target
function AbilityActivationSystem:select_optimal_target(ability, targets, entity_manager)
    if #targets == 0 then return nil, 0 end
    
    local best_target = nil
    local best_effectiveness = 0
    
    for _, target_info in ipairs(targets) do
        local effectiveness = self:calculate_target_effectiveness(ability, target_info.id, entity_manager)
        if effectiveness > best_effectiveness then
            best_effectiveness = effectiveness
            best_target = target_info.id
        end
    end
    
    return best_target, best_effectiveness
end
-- }}}

-- {{{ function AbilityActivationSystem:calculate_target_effectiveness
function AbilityActivationSystem:calculate_target_effectiveness(ability, target_id, entity_manager)
    local target_health = entity_manager:get_component(target_id, "health")
    if not target_health then return 0 end
    
    if ability.effect_type == "damage" then
        -- For damage, effectiveness is how much of the damage will be useful
        local potential_damage = ability.base_value
        local actual_damage = math.min(potential_damage, target_health.current)
        return actual_damage / potential_damage
        
    elseif ability.effect_type == "heal" then
        -- For healing, effectiveness is how much healing is needed
        local potential_healing = ability.base_value
        local needed_healing = target_health.max - target_health.current
        local actual_healing = math.min(potential_healing, needed_healing)
        return actual_healing / potential_healing
    end
    
    return 1.0 -- Default for buffs/debuffs
end
-- }}}

-- {{{ function AbilityActivationSystem:execute_activation_queue
function AbilityActivationSystem:execute_activation_queue(entity_id, activator, entity_manager)
    local mana_component = entity_manager:get_component(entity_id, "mana")
    if not mana_component then return end
    
    for i = #activator.activation_queue, 1, -1 do
        local activation = activator.activation_queue[i]
        local ability = activator.abilities[activation.ability_index]
        
        -- Calculate proportional mana cost based on effectiveness
        local mana_cost = mana_component.max_mana[activation.ability_index] * activation.effectiveness
        
        if mana_component:consume_mana(activation.ability_index, mana_cost) then
            self:execute_ability_effect(entity_id, activation.target_id, ability, activation.effectiveness, entity_manager)
            
            -- Set cooldown
            activator.cooldown_remaining[activation.ability_index] = ability.cooldown or 0
            
            -- Remove from queue
            table.remove(activator.activation_queue, i)
        end
    end
end
-- }}}

-- {{{ function AbilityActivationSystem:execute_ability_effect
function AbilityActivationSystem:execute_ability_effect(caster_id, target_id, ability, effectiveness, entity_manager)
    local target_health = entity_manager:get_component(target_id, "health")
    if not target_health then return end
    
    local effect_amount = ability.base_value * effectiveness
    
    if ability.effect_type == "damage" then
        target_health.current = math.max(0, target_health.current - effect_amount)
    elseif ability.effect_type == "heal" then
        target_health.current = math.min(target_health.max, target_health.current + effect_amount)
    end
    
    -- TODO: Add visual effects system integration
    -- TODO: Add audio effects system integration
end
-- }}}

return AbilityActivationSystem
```

### Integration Points
- Connect with mana system for mana consumption
- Interface with targeting system for valid target detection
- Coordinate with health system for damage/healing application
- Add hooks for visual and audio effects

### Acceptance Criteria
- [ ] Abilities activate automatically when mana reaches maximum
- [ ] Mana consumption is proportional to effectiveness
- [ ] No mana wasted on overkill damage or overhealing
- [ ] Abilities respect range and targeting rules
- [ ] Multiple abilities can be queued and executed in same frame
- [ ] System performs well with 50+ units using abilities simultaneously