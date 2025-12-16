# Issue #409: Implement Ability Cooldowns and Effects

## Current Behavior
Abilities can be activated but lack sophisticated cooldown management and persistent effect tracking systems.

## Intended Behavior
Implement comprehensive cooldown and effect management system that handles individual ability cooldowns, global cooldowns, persistent effects (DoT/HoT), and effect stacking mechanics.

## Implementation Details

### Cooldown Management System (src/systems/cooldown_system.lua)
```lua
-- {{{ CooldownSystem
local CooldownSystem = {}
CooldownSystem.__index = CooldownSystem

function CooldownSystem:new()
    local system = {
        -- Cooldown tracking
        ability_cooldowns = {}, -- [entity_id][ability_index] = remaining_time
        global_cooldowns = {}, -- [entity_id] = remaining_time
        
        -- Cooldown types
        cooldown_types = {
            ability_specific = "ability_specific",
            global = "global",
            category = "category", -- e.g., all damage abilities
            resource = "resource" -- e.g., mana-based cooldown
        },
        
        -- Cooldown reduction effects
        cooldown_modifiers = {}, -- [entity_id] = {type = modifier_value}
        
        -- Performance optimization
        update_interval = 0.02, -- Update every 20ms
        last_update = 0
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function CooldownSystem:update
function CooldownSystem:update(dt, entity_manager)
    self.last_update = self.last_update + dt
    
    if self.last_update >= self.update_interval then
        self:update_cooldowns(self.last_update, entity_manager)
        self.last_update = 0
    end
end
-- }}}

-- {{{ function CooldownSystem:update_cooldowns
function CooldownSystem:update_cooldowns(dt, entity_manager)
    -- Update ability-specific cooldowns
    for entity_id, ability_cooldowns in pairs(self.ability_cooldowns) do
        for ability_index, remaining_time in pairs(ability_cooldowns) do
            local reduction_factor = self:get_cooldown_reduction_factor(entity_id, ability_index, entity_manager)
            local effective_dt = dt * (1 + reduction_factor)
            
            remaining_time = remaining_time - effective_dt
            
            if remaining_time <= 0 then
                ability_cooldowns[ability_index] = nil
                self:on_ability_cooldown_complete(entity_id, ability_index, entity_manager)
            else
                ability_cooldowns[ability_index] = remaining_time
            end
        end
        
        -- Clean up empty cooldown tables
        if next(ability_cooldowns) == nil then
            self.ability_cooldowns[entity_id] = nil
        end
    end
    
    -- Update global cooldowns
    for entity_id, remaining_time in pairs(self.global_cooldowns) do
        local reduction_factor = self:get_global_cooldown_reduction_factor(entity_id, entity_manager)
        local effective_dt = dt * (1 + reduction_factor)
        
        remaining_time = remaining_time - effective_dt
        
        if remaining_time <= 0 then
            self.global_cooldowns[entity_id] = nil
            self:on_global_cooldown_complete(entity_id, entity_manager)
        else
            self.global_cooldowns[entity_id] = remaining_time
        end
    end
end
-- }}}

-- {{{ function CooldownSystem:start_ability_cooldown
function CooldownSystem:start_ability_cooldown(entity_id, ability_index, cooldown_duration, cooldown_type)
    cooldown_type = cooldown_type or "ability_specific"
    
    if cooldown_type == "ability_specific" then
        if not self.ability_cooldowns[entity_id] then
            self.ability_cooldowns[entity_id] = {}
        end
        self.ability_cooldowns[entity_id][ability_index] = cooldown_duration
        
    elseif cooldown_type == "global" then
        self.global_cooldowns[entity_id] = cooldown_duration
        
    elseif cooldown_type == "category" then
        -- Apply cooldown to all abilities of the same category
        self:start_category_cooldown(entity_id, ability_index, cooldown_duration)
    end
end
-- }}}

-- {{{ function CooldownSystem:start_category_cooldown
function CooldownSystem:start_category_cooldown(entity_id, triggering_ability_index, cooldown_duration)
    local abilities_component = entity_manager:get_component(entity_id, "abilities")
    if not abilities_component then return end
    
    local triggering_ability = abilities_component:get_ability(triggering_ability_index)
    if not triggering_ability then return end
    
    local category = triggering_ability.category or triggering_ability.type
    
    -- Apply reduced cooldown to other abilities in same category
    for i, ability in pairs(abilities_component.abilities) do
        if i ~= triggering_ability_index and 
           (ability.category == category or ability.type == category) then
            local reduced_cooldown = cooldown_duration * 0.5 -- 50% of full cooldown
            self:start_ability_cooldown(entity_id, i, reduced_cooldown, "ability_specific")
        end
    end
end
-- }}}

-- {{{ function CooldownSystem:is_ability_on_cooldown
function CooldownSystem:is_ability_on_cooldown(entity_id, ability_index)
    -- Check global cooldown
    if self.global_cooldowns[entity_id] then
        return true, "global_cooldown", self.global_cooldowns[entity_id]
    end
    
    -- Check ability-specific cooldown
    if self.ability_cooldowns[entity_id] and self.ability_cooldowns[entity_id][ability_index] then
        return true, "ability_cooldown", self.ability_cooldowns[entity_id][ability_index]
    end
    
    return false, "ready", 0
end
-- }}}

-- {{{ function CooldownSystem:get_cooldown_reduction_factor
function CooldownSystem:get_cooldown_reduction_factor(entity_id, ability_index, entity_manager)
    local base_reduction = 0
    
    -- Check for cooldown reduction buffs
    local unit = entity_manager:get_component(entity_id, "unit")
    if unit and unit.active_buffs then
        for buff_name, buff_data in pairs(unit.active_buffs) do
            if buff_data.special_effects and buff_data.special_effects.cooldown_reduction then
                base_reduction = base_reduction + buff_data.special_effects.cooldown_reduction
            end
        end
    end
    
    -- Check for ability-specific cooldown reduction
    local abilities_component = entity_manager:get_component(entity_id, "abilities")
    if abilities_component then
        local ability = abilities_component:get_ability(ability_index)
        if ability and ability.cooldown_reduction_bonus then
            base_reduction = base_reduction + ability.cooldown_reduction_bonus
        end
    end
    
    -- Cap cooldown reduction at 75%
    return math.min(base_reduction, 0.75)
end
-- }}}

-- {{{ function CooldownSystem:reset_all_cooldowns
function CooldownSystem:reset_all_cooldowns(entity_id)
    self.ability_cooldowns[entity_id] = nil
    self.global_cooldowns[entity_id] = nil
end
-- }}}

return CooldownSystem
```

### Persistent Effects System (src/systems/persistent_effects_system.lua)
```lua
-- {{{ PersistentEffectsSystem
local PersistentEffectsSystem = {}
PersistentEffectsSystem.__index = PersistentEffectsSystem

function PersistentEffectsSystem:new(entity_manager)
    local system = {
        entity_manager = entity_manager,
        
        -- Active persistent effects
        damage_over_time_effects = {}, -- [effect_id] = effect_data
        heal_over_time_effects = {},
        periodic_effects = {},
        
        -- Effect tracking
        effect_id_counter = 1,
        effect_update_interval = 0.5, -- Update every 500ms
        last_effect_update = 0,
        
        -- Effect types
        effect_types = {
            damage_over_time = "dot",
            heal_over_time = "hot", 
            periodic_damage = "periodic_damage",
            periodic_heal = "periodic_heal",
            aura_effect = "aura",
            channeled_effect = "channeled"
        }
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function PersistentEffectsSystem:update
function PersistentEffectsSystem:update(dt)
    self.last_effect_update = self.last_effect_update + dt
    
    if self.last_effect_update >= self.effect_update_interval then
        self:update_damage_over_time_effects(self.last_effect_update)
        self:update_heal_over_time_effects(self.last_effect_update)
        self:update_periodic_effects(self.last_effect_update)
        self.last_effect_update = 0
    end
end
-- }}}

-- {{{ function PersistentEffectsSystem:add_damage_over_time
function PersistentEffectsSystem:add_damage_over_time(caster_id, target_id, damage_per_tick, duration, tick_interval, damage_type)
    local effect_id = self.effect_id_counter
    self.effect_id_counter = self.effect_id_counter + 1
    
    local effect_data = {
        id = effect_id,
        caster_id = caster_id,
        target_id = target_id,
        damage_per_tick = damage_per_tick,
        total_duration = duration,
        remaining_duration = duration,
        tick_interval = tick_interval or 1.0,
        time_since_last_tick = 0,
        damage_type = damage_type or "magical",
        total_damage_dealt = 0,
        start_time = love.timer.getTime()
    }
    
    self.damage_over_time_effects[effect_id] = effect_data
    
    -- Visual effect for DoT application
    self:create_dot_visual_effect(target_id, damage_type)
    
    return effect_id
end
-- }}}

-- {{{ function PersistentEffectsSystem:add_heal_over_time
function PersistentEffectsSystem:add_heal_over_time(caster_id, target_id, heal_per_tick, duration, tick_interval)
    local effect_id = self.effect_id_counter
    self.effect_id_counter = self.effect_id_counter + 1
    
    local effect_data = {
        id = effect_id,
        caster_id = caster_id,
        target_id = target_id,
        heal_per_tick = heal_per_tick,
        total_duration = duration,
        remaining_duration = duration,
        tick_interval = tick_interval or 1.0,
        time_since_last_tick = 0,
        total_healing_done = 0,
        start_time = love.timer.getTime()
    }
    
    self.heal_over_time_effects[effect_id] = effect_data
    
    -- Visual effect for HoT application
    self:create_hot_visual_effect(target_id)
    
    return effect_id
end
-- }}}

-- {{{ function PersistentEffectsSystem:update_damage_over_time_effects
function PersistentEffectsSystem:update_damage_over_time_effects(dt)
    local effects_to_remove = {}
    
    for effect_id, effect_data in pairs(self.damage_over_time_effects) do
        effect_data.remaining_duration = effect_data.remaining_duration - dt
        effect_data.time_since_last_tick = effect_data.time_since_last_tick + dt
        
        -- Check if it's time for a tick
        if effect_data.time_since_last_tick >= effect_data.tick_interval then
            local damage_dealt = self:apply_dot_tick(effect_data)
            effect_data.total_damage_dealt = effect_data.total_damage_dealt + damage_dealt
            effect_data.time_since_last_tick = 0
        end
        
        -- Check if effect has expired
        if effect_data.remaining_duration <= 0 then
            table.insert(effects_to_remove, effect_id)
        end
    end
    
    -- Remove expired effects
    for _, effect_id in ipairs(effects_to_remove) do
        self:remove_damage_over_time_effect(effect_id)
    end
end
-- }}}

-- {{{ function PersistentEffectsSystem:apply_dot_tick
function PersistentEffectsSystem:apply_dot_tick(effect_data)
    local target_health = self.entity_manager:get_component(effect_data.target_id, "health")
    if not target_health or target_health.current <= 0 then
        return 0 -- Target is dead, no damage dealt
    end
    
    -- Calculate actual damage (considering resistances)
    local base_damage = effect_data.damage_per_tick
    local final_damage = self:calculate_dot_damage(effect_data.caster_id, effect_data.target_id, base_damage, effect_data.damage_type)
    
    -- Apply damage
    local actual_damage = math.min(final_damage, target_health.current)
    target_health.current = target_health.current - actual_damage
    
    -- Create tick visual effect
    self:create_dot_tick_visual_effect(effect_data.target_id, actual_damage, effect_data.damage_type)
    
    -- Check for death
    if target_health.current <= 0 then
        self:handle_dot_death(effect_data.caster_id, effect_data.target_id)
    end
    
    return actual_damage
end
-- }}}

-- {{{ function PersistentEffectsSystem:calculate_dot_damage
function PersistentEffectsSystem:calculate_dot_damage(caster_id, target_id, base_damage, damage_type)
    -- Get target resistances
    local target_unit = self.entity_manager:get_component(target_id, "unit")
    local target_stats = target_unit and target_unit.stats or {}
    
    local final_damage = base_damage
    
    if damage_type == "physical" then
        local armor = target_stats.armor or 0
        local damage_reduction = armor / (armor + 100)
        final_damage = base_damage * (1 - damage_reduction)
    elseif damage_type == "magical" then
        local magic_resist = target_stats.magic_resist or 0
        local damage_reduction = magic_resist / (magic_resist + 100)
        final_damage = base_damage * (1 - damage_reduction)
    end
    -- "true" damage bypasses resistances
    
    return math.floor(final_damage)
end
-- }}}

-- {{{ function PersistentEffectsSystem:update_heal_over_time_effects
function PersistentEffectsSystem:update_heal_over_time_effects(dt)
    local effects_to_remove = {}
    
    for effect_id, effect_data in pairs(self.heal_over_time_effects) do
        effect_data.remaining_duration = effect_data.remaining_duration - dt
        effect_data.time_since_last_tick = effect_data.time_since_last_tick + dt
        
        -- Check if it's time for a tick
        if effect_data.time_since_last_tick >= effect_data.tick_interval then
            local healing_done = self:apply_hot_tick(effect_data)
            effect_data.total_healing_done = effect_data.total_healing_done + healing_done
            effect_data.time_since_last_tick = 0
        end
        
        -- Check if effect has expired
        if effect_data.remaining_duration <= 0 then
            table.insert(effects_to_remove, effect_id)
        end
    end
    
    -- Remove expired effects
    for _, effect_id in ipairs(effects_to_remove) do
        self:remove_heal_over_time_effect(effect_id)
    end
end
-- }}}

-- {{{ function PersistentEffectsSystem:apply_hot_tick
function PersistentEffectsSystem:apply_hot_tick(effect_data)
    local target_health = self.entity_manager:get_component(effect_data.target_id, "health")
    if not target_health then
        return 0 -- Target doesn't exist
    end
    
    -- Calculate healing needed
    local base_healing = effect_data.heal_per_tick
    local health_missing = target_health.max - target_health.current
    local actual_healing = math.min(base_healing, health_missing)
    
    -- Apply healing
    target_health.current = target_health.current + actual_healing
    
    -- Create tick visual effect
    self:create_hot_tick_visual_effect(effect_data.target_id, actual_healing)
    
    return actual_healing
end
-- }}}

-- {{{ function PersistentEffectsSystem:remove_damage_over_time_effect
function PersistentEffectsSystem:remove_damage_over_time_effect(effect_id)
    local effect_data = self.damage_over_time_effects[effect_id]
    if effect_data then
        -- Create removal visual effect
        self:create_dot_removal_visual_effect(effect_data.target_id, effect_data.damage_type)
        
        -- Remove the effect
        self.damage_over_time_effects[effect_id] = nil
    end
end
-- }}}

-- {{{ function PersistentEffectsSystem:get_effects_on_target
function PersistentEffectsSystem:get_effects_on_target(target_id)
    local effects = {
        damage_over_time = {},
        heal_over_time = {},
        periodic = {}
    }
    
    -- Find DoT effects
    for effect_id, effect_data in pairs(self.damage_over_time_effects) do
        if effect_data.target_id == target_id then
            table.insert(effects.damage_over_time, effect_data)
        end
    end
    
    -- Find HoT effects
    for effect_id, effect_data in pairs(self.heal_over_time_effects) do
        if effect_data.target_id == target_id then
            table.insert(effects.heal_over_time, effect_data)
        end
    end
    
    return effects
end
-- }}}

-- {{{ function PersistentEffectsSystem:cleanse_effects
function PersistentEffectsSystem:cleanse_effects(target_id, effect_types)
    effect_types = effect_types or {"damage_over_time", "debuff"}
    
    local effects_removed = 0
    
    for _, effect_type in ipairs(effect_types) do
        if effect_type == "damage_over_time" then
            local effects_to_remove = {}
            for effect_id, effect_data in pairs(self.damage_over_time_effects) do
                if effect_data.target_id == target_id then
                    table.insert(effects_to_remove, effect_id)
                end
            end
            
            for _, effect_id in ipairs(effects_to_remove) do
                self:remove_damage_over_time_effect(effect_id)
                effects_removed = effects_removed + 1
            end
        end
    end
    
    if effects_removed > 0 then
        self:create_cleanse_visual_effect(target_id, effects_removed)
    end
    
    return effects_removed
end
-- }}}

return PersistentEffectsSystem
```

### Enhanced Ability Activation Integration (src/systems/ability_activation_system.lua enhancement)
```lua
-- {{{ AbilityActivationSystem enhancement
-- Add cooldown integration to existing activation system

-- {{{ function AbilityActivationSystem:attempt_ability_activation enhancement
function AbilityActivationSystem:attempt_ability_activation(entity_id, ability_index, ability)
    -- Check cooldowns before other validation
    local on_cooldown, cooldown_type, remaining_time = self.cooldown_system:is_ability_on_cooldown(entity_id, ability_index)
    
    if on_cooldown then
        self:record_activation_failure(entity_id, ability_index, cooldown_type .. "_" .. remaining_time)
        return false
    end
    
    -- Existing validation logic...
    local unit_state = self:get_unit_state(entity_id)
    local can_activate, reason = ability:can_activate(unit_state, self:get_game_context())
    
    if not can_activate then
        self:record_activation_failure(entity_id, ability_index, reason)
        return false
    end
    
    -- Find targets and execute...
    local targets = self.targeting_system:find_targets(entity_id, ability, self.entity_manager)
    
    if #targets == 0 then
        self:record_activation_failure(entity_id, ability_index, "no_targets")
        return false
    end
    
    local success = self:execute_ability(entity_id, ability_index, ability, targets)
    
    if success then
        -- Start cooldowns after successful activation
        if ability.cooldown_duration and ability.cooldown_duration > 0 then
            self.cooldown_system:start_ability_cooldown(entity_id, ability_index, ability.cooldown_duration)
        end
        
        -- Global cooldown
        local global_cooldown = ability.global_cooldown or 0.2
        self.cooldown_system:start_ability_cooldown(entity_id, ability_index, global_cooldown, "global")
        
        return true
    end
    
    return false
end
-- }}}

-- Add persistent effects to ability execution
-- {{{ function AbilityActivationSystem:execute_ability enhancement
function AbilityActivationSystem:execute_ability(entity_id, ability_index, ability, targets)
    -- Existing execution logic...
    local success = ability:consume_mana(ability.max_mana_cost)
    if not success then return false end
    
    -- Apply immediate effects
    self.effect_system:process_ability_activation({
        caster_id = entity_id,
        ability = ability,
        targets = targets
    })
    
    -- Apply persistent effects
    for _, target in ipairs(targets) do
        if ability.damage_over_time and ability.damage_over_time > 0 then
            self.persistent_effects_system:add_damage_over_time(
                entity_id, target.id, 
                ability.damage_over_time, 
                ability.damage_over_time_duration or 5,
                ability.damage_over_time_interval or 1
            )
        end
        
        if ability.heal_over_time and ability.heal_over_time > 0 then
            self.persistent_effects_system:add_heal_over_time(
                entity_id, target.id,
                ability.heal_over_time,
                ability.heal_over_time_duration or 8,
                ability.heal_over_time_interval or 1
            )
        end
    end
    
    return true
end
-- }}}
```

### Acceptance Criteria
- [ ] Individual ability cooldowns prevent premature reuse
- [ ] Global cooldowns prevent ability spam across all abilities
- [ ] Cooldown reduction from buffs/stats works correctly
- [ ] Damage over time effects tick at proper intervals
- [ ] Heal over time effects restore health efficiently
- [ ] Persistent effects are properly cleaned up when expired
- [ ] Cleanse abilities remove appropriate effect types
- [ ] Visual feedback clearly shows cooldown and effect status
- [ ] System performance scales with many simultaneous effects
- [ ] Integration with existing ability and effect systems works seamlessly