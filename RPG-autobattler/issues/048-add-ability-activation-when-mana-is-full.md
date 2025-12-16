# Issue #407: Add Ability Activation When Mana is Full

## Current Behavior
Abilities have mana systems and targeting, but lack automatic activation logic to trigger abilities when mana reaches maximum capacity.

## Intended Behavior
Implement automatic ability activation system that triggers abilities when mana is full and valid targets are available, with proper sequencing and timing controls.

## Implementation Details

### Ability Activation System (src/systems/ability_activation_system.lua)
```lua
-- {{{ AbilityActivationSystem
local AbilityActivationSystem = {}
AbilityActivationSystem.__index = AbilityActivationSystem

function AbilityActivationSystem:new(entity_manager, targeting_system, effect_system)
    local system = {
        entity_manager = entity_manager,
        targeting_system = targeting_system,
        effect_system = effect_system,
        
        -- Activation parameters
        activation_check_interval = 0.05, -- Check every 50ms
        last_activation_check = 0,
        global_ability_cooldown = 0.1, -- Minimum time between any abilities
        
        -- Priority and sequencing
        ability_priority_order = {1, 2, 3, 4}, -- Primary first, then secondary
        simultaneous_ability_limit = 1, -- Max abilities per activation cycle
        
        -- Performance tracking
        activation_stats = {},
        failed_activation_reasons = {},
        
        -- State tracking
        units_with_ready_abilities = {},
        pending_activations = {}
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function AbilityActivationSystem:update
function AbilityActivationSystem:update(dt)
    self.last_activation_check = self.last_activation_check + dt
    
    if self.last_activation_check >= self.activation_check_interval then
        self:process_ability_activations()
        self.last_activation_check = 0
    end
    
    -- Process any pending activations from previous frame
    self:execute_pending_activations(dt)
end
-- }}}

-- {{{ function AbilityActivationSystem:process_ability_activations
function AbilityActivationSystem:process_ability_activations()
    -- Find all units with abilities
    for entity_id, abilities_component in self.entity_manager:iterate_components("abilities") do
        self:check_unit_ability_activation(entity_id, abilities_component)
    end
end
-- }}}

-- {{{ function AbilityActivationSystem:check_unit_ability_activation
function AbilityActivationSystem:check_unit_ability_activation(entity_id, abilities_component)
    local unit_state = self:get_unit_state(entity_id)
    if not unit_state then return end
    
    -- Check if unit is in a state where it can use abilities
    if not self:can_unit_use_abilities(entity_id, unit_state) then
        return
    end
    
    -- Get abilities that are ready to activate
    local ready_abilities = abilities_component:get_ready_abilities(unit_state, self:get_game_context())
    
    if #ready_abilities == 0 then return end
    
    -- Sort by priority order
    table.sort(ready_abilities, function(a, b)
        return self:get_ability_priority(a.index) < self:get_ability_priority(b.index)
    end)
    
    -- Attempt to activate abilities in priority order
    local activated_count = 0
    
    for _, ability_data in ipairs(ready_abilities) do
        if activated_count >= self.simultaneous_ability_limit then
            break
        end
        
        local success = self:attempt_ability_activation(entity_id, ability_data.index, ability_data.ability)
        
        if success then
            activated_count = activated_count + 1
            
            -- Add to stats
            self:record_activation_success(entity_id, ability_data.index)
        end
    end
end
-- }}}

-- {{{ function AbilityActivationSystem:can_unit_use_abilities
function AbilityActivationSystem:can_unit_use_abilities(entity_id, unit_state)
    -- Check if unit is alive
    local health = self.entity_manager:get_component(entity_id, "health")
    if not health or health.current <= 0 then
        return false
    end
    
    -- Check if unit is stunned, silenced, or disabled
    local unit = self.entity_manager:get_component(entity_id, "unit")
    if unit then
        if unit.is_stunned or unit.is_silenced or unit.is_disabled then
            return false
        end
    end
    
    -- Check if unit is in combat state that allows abilities
    if unit_state.combat_state == "retreating" or unit_state.combat_state == "fleeing" then
        return false
    end
    
    -- Check global cooldown
    local current_time = love.timer.getTime()
    if unit.last_ability_time and (current_time - unit.last_ability_time) < self.global_ability_cooldown then
        return false
    end
    
    return true
end
-- }}}

-- {{{ function AbilityActivationSystem:attempt_ability_activation
function AbilityActivationSystem:attempt_ability_activation(entity_id, ability_index, ability)
    -- Double-check that ability can still activate
    local unit_state = self:get_unit_state(entity_id)
    local can_activate, reason = ability:can_activate(unit_state, self:get_game_context())
    
    if not can_activate then
        self:record_activation_failure(entity_id, ability_index, reason)
        return false
    end
    
    -- Find valid targets
    local targets = self.targeting_system:find_targets(entity_id, ability, self.entity_manager)
    
    if #targets == 0 then
        self:record_activation_failure(entity_id, ability_index, "no_targets")
        return false
    end
    
    -- Calculate mana efficiency for this activation
    local efficiency_result = self:calculate_activation_efficiency(entity_id, ability, targets)
    
    if not efficiency_result.should_activate then
        self:record_activation_failure(entity_id, ability_index, "efficiency_too_low")
        return false
    end
    
    -- Execute the ability
    local success = self:execute_ability(entity_id, ability_index, ability, targets, efficiency_result)
    
    if success then
        -- Update unit state
        local unit = self.entity_manager:get_component(entity_id, "unit")
        if unit then
            unit.last_ability_time = love.timer.getTime()
            unit.abilities_used = (unit.abilities_used or 0) + 1
        end
        
        return true
    end
    
    return false
end
-- }}}

-- {{{ function AbilityActivationSystem:calculate_activation_efficiency
function AbilityActivationSystem:calculate_activation_efficiency(entity_id, ability, targets)
    -- Basic efficiency calculation - can be enhanced
    local efficiency_threshold = 0.3 -- Don't activate if efficiency < 30%
    
    if ability.type == "damage" then
        return self:calculate_damage_efficiency(ability, targets)
    elseif ability.type == "heal" then
        return self:calculate_heal_efficiency(ability, targets)
    elseif ability.type == "buff" then
        return self:calculate_buff_efficiency(ability, targets)
    else
        -- Default: always activate if targets are available
        return {
            should_activate = true,
            efficiency = 1.0,
            reason = "default_activation"
        }
    end
end
-- }}}

-- {{{ function AbilityActivationSystem:calculate_damage_efficiency
function AbilityActivationSystem:calculate_damage_efficiency(ability, targets)
    local total_potential_damage = 0
    local total_useful_damage = 0
    
    for _, target in ipairs(targets) do
        local potential_damage = ability.base_power
        local target_health = target.health and target.health.current or 0
        local useful_damage = math.min(potential_damage, target_health)
        
        total_potential_damage = total_potential_damage + potential_damage
        total_useful_damage = total_useful_damage + useful_damage
    end
    
    local efficiency = total_potential_damage > 0 and (total_useful_damage / total_potential_damage) or 0
    
    return {
        should_activate = efficiency >= 0.3, -- At least 30% efficiency
        efficiency = efficiency,
        total_damage = total_useful_damage,
        reason = efficiency >= 0.3 and "good_damage_efficiency" or "poor_damage_efficiency"
    }
end
-- }}}

-- {{{ function AbilityActivationSystem:calculate_heal_efficiency
function AbilityActivationSystem:calculate_heal_efficiency(ability, targets)
    local total_potential_healing = 0
    local total_useful_healing = 0
    
    for _, target in ipairs(targets) do
        local potential_healing = ability.base_power
        local health_missing = 0
        
        if target.health then
            health_missing = target.health.max - target.health.current
        end
        
        local useful_healing = math.min(potential_healing, health_missing)
        
        total_potential_healing = total_potential_healing + potential_healing
        total_useful_healing = total_useful_healing + useful_healing
    end
    
    local efficiency = total_potential_healing > 0 and (total_useful_healing / total_potential_healing) or 0
    
    return {
        should_activate = efficiency >= 0.2, -- Lower threshold for healing
        efficiency = efficiency,
        total_healing = total_useful_healing,
        reason = efficiency >= 0.2 and "good_heal_efficiency" or "poor_heal_efficiency"
    }
end
-- }}}

-- {{{ function AbilityActivationSystem:calculate_buff_efficiency
function AbilityActivationSystem:calculate_buff_efficiency(ability, targets)
    local useful_targets = 0
    
    for _, target in ipairs(targets) do
        -- Check if target already has this buff
        local unit = self.entity_manager:get_component(target.id, "unit")
        if unit and unit.active_buffs then
            if not unit.active_buffs[ability.effect_data.buff_type] then
                useful_targets = useful_targets + 1
            end
        else
            useful_targets = useful_targets + 1 -- Assume useful if no buff info
        end
    end
    
    local efficiency = #targets > 0 and (useful_targets / #targets) or 0
    
    return {
        should_activate = useful_targets > 0,
        efficiency = efficiency,
        useful_targets = useful_targets,
        reason = useful_targets > 0 and "targets_need_buff" or "targets_already_buffed"
    }
end
-- }}}

-- {{{ function AbilityActivationSystem:execute_ability
function AbilityActivationSystem:execute_ability(entity_id, ability_index, ability, targets, efficiency_result)
    -- Consume mana (accounting for efficiency)
    local mana_to_consume = ability.max_mana_cost
    
    if efficiency_result.efficiency and efficiency_result.efficiency < 1.0 then
        -- Use proportional mana based on efficiency
        mana_to_consume = math.max(
            ability.max_mana_cost * 0.1, -- Minimum 10% mana usage
            ability.max_mana_cost * efficiency_result.efficiency
        )
    end
    
    local success = ability:consume_mana(mana_to_consume)
    if not success then
        return false
    end
    
    -- Create activation event for effect system
    local activation_event = {
        caster_id = entity_id,
        ability = ability,
        ability_index = ability_index,
        targets = targets,
        efficiency = efficiency_result,
        mana_consumed = mana_to_consume,
        activation_time = love.timer.getTime()
    }
    
    -- Send to effect system for execution
    self.effect_system:process_ability_activation(activation_event)
    
    return true
end
-- }}}

-- {{{ function AbilityActivationSystem:get_unit_state
function AbilityActivationSystem:get_unit_state(entity_id)
    local position = self.entity_manager:get_component(entity_id, "position")
    local health = self.entity_manager:get_component(entity_id, "health")
    local unit = self.entity_manager:get_component(entity_id, "unit")
    local moveable = self.entity_manager:get_component(entity_id, "moveable")
    local team = self.entity_manager:get_component(entity_id, "team")
    
    if not position or not health or not unit then
        return nil
    end
    
    return {
        position = position.value,
        current_health = health.current,
        max_health = health.max,
        unit_type = unit.unit_type,
        team = team and team.value,
        is_stationary = moveable and moveable.velocity:length() < 0.5,
        combat_state = unit.combat_state or "none",
        active_buffs = unit.active_buffs or {},
        enemies_in_range = self:get_enemies_in_range(entity_id),
        allies_nearby = self:get_allies_nearby(entity_id)
    }
end
-- }}}

-- {{{ function AbilityActivationSystem:get_enemies_in_range
function AbilityActivationSystem:get_enemies_in_range(entity_id)
    -- This would integrate with the targeting system
    local position = self.entity_manager:get_component(entity_id, "position")
    local team = self.entity_manager:get_component(entity_id, "team")
    
    if not position or not team then return {} end
    
    local enemies = {}
    local detection_range = 60
    
    for other_id, other_team in self.entity_manager:iterate_components("team") do
        if other_id ~= entity_id and other_team.value ~= team.value then
            local other_position = self.entity_manager:get_component(other_id, "position")
            if other_position then
                local distance = position.value:distance_to(other_position.value)
                if distance <= detection_range then
                    table.insert(enemies, {
                        id = other_id,
                        distance = distance
                    })
                end
            end
        end
    end
    
    return enemies
end
-- }}}

-- {{{ function AbilityActivationSystem:get_ability_priority
function AbilityActivationSystem:get_ability_priority(ability_index)
    -- Primary ability (index 1) has highest priority
    if ability_index == 1 then
        return 1
    end
    
    -- Secondary abilities in order
    return ability_index
end
-- }}}

-- {{{ function AbilityActivationSystem:record_activation_success
function AbilityActivationSystem:record_activation_success(entity_id, ability_index)
    local key = entity_id .. "_" .. ability_index
    
    if not self.activation_stats[key] then
        self.activation_stats[key] = {
            successful_activations = 0,
            failed_activations = 0,
            total_damage = 0,
            total_healing = 0
        }
    end
    
    self.activation_stats[key].successful_activations = self.activation_stats[key].successful_activations + 1
end
-- }}}

-- {{{ function AbilityActivationSystem:record_activation_failure
function AbilityActivationSystem:record_activation_failure(entity_id, ability_index, reason)
    local key = entity_id .. "_" .. ability_index
    
    if not self.activation_stats[key] then
        self.activation_stats[key] = {
            successful_activations = 0,
            failed_activations = 0,
            failure_reasons = {}
        }
    end
    
    self.activation_stats[key].failed_activations = self.activation_stats[key].failed_activations + 1
    
    local reasons = self.activation_stats[key].failure_reasons
    reasons[reason] = (reasons[reason] or 0) + 1
end
-- }}}

-- {{{ function AbilityActivationSystem:get_game_context
function AbilityActivationSystem:get_game_context()
    return {
        current_time = love.timer.getTime(),
        game_phase = "combat", -- This would come from game state
        global_modifiers = {}
    }
end
-- }}}

return AbilityActivationSystem
```

### Integration with Main Game Loop (src/systems/system_manager.lua enhancement)
```lua
-- {{{ SystemManager:add_ability_activation_system
function SystemManager:add_ability_activation_system()
    local targeting_system = self:get_system("targeting")
    local effect_system = self:get_system("effect")
    
    if targeting_system and effect_system then
        local activation_system = AbilityActivationSystem:new(
            self.entity_manager, 
            targeting_system, 
            effect_system
        )
        self:add_system("ability_activation", activation_system)
    end
end
-- }}}

-- {{{ SystemManager:update enhancement
function SystemManager:update(dt)
    -- Update existing systems...
    
    -- Update ability activation system
    local activation_system = self:get_system("ability_activation")
    if activation_system then
        activation_system:update(dt)
    end
end
-- }}}
```

### Ability Queue System (src/systems/ability_queue_system.lua)
```lua
-- {{{ AbilityQueueSystem
local AbilityQueueSystem = {}
AbilityQueueSystem.__index = AbilityQueueSystem

function AbilityQueueSystem:new()
    local system = {
        queued_abilities = {}, -- Per-unit queues
        max_queue_size = 3,
        queue_timeout = 2.0, -- Remove queued abilities after this time
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function AbilityQueueSystem:queue_ability
function AbilityQueueSystem:queue_ability(entity_id, ability_index, targets, priority)
    if not self.queued_abilities[entity_id] then
        self.queued_abilities[entity_id] = {}
    end
    
    local queue = self.queued_abilities[entity_id]
    
    -- Don't exceed max queue size
    if #queue >= self.max_queue_size then
        return false
    end
    
    table.insert(queue, {
        ability_index = ability_index,
        targets = targets,
        priority = priority or 1,
        queued_time = love.timer.getTime()
    })
    
    -- Sort by priority
    table.sort(queue, function(a, b) return a.priority < b.priority end)
    
    return true
end
-- }}}

-- {{{ function AbilityQueueSystem:get_next_queued_ability
function AbilityQueueSystem:get_next_queued_ability(entity_id)
    local queue = self.queued_abilities[entity_id]
    if not queue or #queue == 0 then
        return nil
    end
    
    -- Remove and return first ability in queue
    return table.remove(queue, 1)
end
-- }}}

return AbilityQueueSystem
```

### Acceptance Criteria
- [ ] Abilities automatically activate when mana reaches 100%
- [ ] Valid targets are found and validated before activation
- [ ] Ability priority system ensures primary abilities fire first
- [ ] Efficiency calculations prevent wasteful ability usage
- [ ] Multiple abilities don't fire simultaneously (unless configured)
- [ ] Failed activations are tracked with reasons for debugging
- [ ] System integrates with existing mana and targeting systems
- [ ] Performance scales with many units using abilities simultaneously