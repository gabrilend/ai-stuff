# Issue #402: Add Conditional Mana Generation (Ranged Standing Still, Melee in Range)

## Current Behavior
Mana generation rules exist but need refined implementation of the specific conditional logic for different unit types.

## Intended Behavior
Implement precise conditional mana generation where ranged units generate secondary mana only when standing still, and melee units generate secondary mana only when enemies are in range.

## Implementation Details

### Enhanced Conditional Detection (src/systems/conditional_mana_system.lua)
```lua
-- {{{ ConditionalManaSystem
local ConditionalManaSystem = {}
ConditionalManaSystem.__index = ConditionalManaSystem

function ConditionalManaSystem:new()
    local system = {
        -- Ranged unit conditions
        stationary_velocity_threshold = 0.3,
        stationary_duration_required = 0.25, -- seconds
        ranged_comfort_distance = 45, -- preferred distance from enemies
        
        -- Melee unit conditions  
        melee_engagement_range = 55,
        melee_optimal_range = 35,
        charge_velocity_threshold = 15, -- still generating mana while charging
        
        -- Performance optimization
        condition_check_interval = 0.1, -- check conditions every 100ms
        last_check_time = 0
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function ConditionalManaSystem:update
function ConditionalManaSystem:update(dt, entity_manager)
    self.last_check_time = self.last_check_time + dt
    
    -- Optimize by checking conditions less frequently
    if self.last_check_time >= self.condition_check_interval then
        for entity_id, mana_component in entity_manager:iterate_components("mana") do
            self:update_conditional_generation(entity_id, mana_component, entity_manager, self.last_check_time)
        end
        self.last_check_time = 0
    end
    
    -- Always update mana values based on current conditions
    for entity_id, mana_component in entity_manager:iterate_components("mana") do
        self:apply_mana_generation(mana_component, self.condition_check_interval)
    end
end
-- }}}

-- {{{ function ConditionalManaSystem:update_conditional_generation
function ConditionalManaSystem:update_conditional_generation(entity_id, mana_component, entity_manager, dt)
    local unit = entity_manager:get_component(entity_id, "unit")
    if not unit then return end
    
    if unit.unit_type == "ranged" then
        self:update_ranged_conditions(entity_id, mana_component, entity_manager, dt)
    elseif unit.unit_type == "melee" then
        self:update_melee_conditions(entity_id, mana_component, entity_manager, dt)
    end
end
-- }}}

-- {{{ function ConditionalManaSystem:update_ranged_conditions
function ConditionalManaSystem:update_ranged_conditions(entity_id, mana_component, entity_manager, dt)
    local position = entity_manager:get_component(entity_id, "position")
    local moveable = entity_manager:get_component(entity_id, "moveable")
    local unit = entity_manager:get_component(entity_id, "unit")
    
    if not position or not moveable or not unit then return end
    
    -- Check if unit is standing still
    local current_velocity = moveable.velocity:length()
    local is_currently_still = current_velocity <= self.stationary_velocity_threshold
    
    -- Track stationary duration
    if not unit.stationary_duration then
        unit.stationary_duration = 0
    end
    
    if is_currently_still then
        unit.stationary_duration = unit.stationary_duration + dt
    else
        unit.stationary_duration = 0
    end
    
    -- Check if standing still long enough
    local qualified_stationary = unit.stationary_duration >= self.stationary_duration_required
    
    -- Additional context for better generation decisions
    local enemies_nearby = self:get_enemies_in_detection_range(entity_id, position, entity_manager)
    local is_in_combat_position = self:is_ranged_in_good_position(position, enemies_nearby)
    local is_providing_cover_fire = self:is_providing_cover_fire(entity_id, position, entity_manager)
    
    -- Set generation state for secondary abilities
    for i = 2, #mana_component.abilities do
        local should_generate = qualified_stationary
        
        -- Bonus conditions for enhanced generation
        if should_generate then
            mana_component.generation_state = mana_component.generation_state or {}
            mana_component.generation_state[i] = {
                base_rate = true,
                bonus_combat_position = is_in_combat_position,
                bonus_cover_fire = is_providing_cover_fire,
                stationary_duration = unit.stationary_duration
            }
        else
            if mana_component.generation_state then
                mana_component.generation_state[i] = nil
            end
        end
    end
end
-- }}}

-- {{{ function ConditionalManaSystem:update_melee_conditions
function ConditionalManaSystem:update_melee_conditions(entity_id, mana_component, entity_manager, dt)
    local position = entity_manager:get_component(entity_id, "position")
    local moveable = entity_manager:get_component(entity_id, "moveable")
    local unit = entity_manager:get_component(entity_id, "unit")
    
    if not position or not unit then return end
    
    -- Find enemies in range
    local enemies_in_range = self:get_enemies_in_melee_range(entity_id, position, entity_manager)
    local has_enemies_in_range = #enemies_in_range > 0
    
    -- Additional melee-specific conditions
    local is_charging = moveable and moveable.velocity:length() > self.charge_velocity_threshold
    local is_engaged_in_melee = self:is_engaged_in_melee(entity_id, enemies_in_range)
    local is_flanking = self:is_flanking_enemies(position, enemies_in_range)
    
    -- Track engagement time
    if not unit.engagement_duration then
        unit.engagement_duration = 0
    end
    
    if has_enemies_in_range then
        unit.engagement_duration = unit.engagement_duration + dt
    else
        unit.engagement_duration = 0
    end
    
    -- Set generation state for secondary abilities
    for i = 2, #mana_component.abilities do
        local should_generate = has_enemies_in_range
        
        if should_generate then
            mana_component.generation_state = mana_component.generation_state or {}
            mana_component.generation_state[i] = {
                base_rate = true,
                bonus_engaged = is_engaged_in_melee,
                bonus_charging = is_charging,
                bonus_flanking = is_flanking,
                enemy_count = #enemies_in_range,
                engagement_duration = unit.engagement_duration
            }
        else
            if mana_component.generation_state then
                mana_component.generation_state[i] = nil
            end
        end
    end
end
-- }}}

-- {{{ function ConditionalManaSystem:get_enemies_in_detection_range
function ConditionalManaSystem:get_enemies_in_detection_range(entity_id, position, entity_manager)
    local enemies = {}
    local team = entity_manager:get_component(entity_id, "team")
    if not team then return enemies end
    
    for other_id, other_team in entity_manager:iterate_components("team") do
        if other_id ~= entity_id and other_team.value ~= team.value then
            local other_position = entity_manager:get_component(other_id, "position")
            local other_health = entity_manager:get_component(other_id, "health")
            
            if other_position and other_health and other_health.current > 0 then
                local distance = position.value:distance_to(other_position.value)
                if distance <= 80 then -- detection range
                    table.insert(enemies, {
                        id = other_id,
                        distance = distance,
                        position = other_position.value
                    })
                end
            end
        end
    end
    
    return enemies
end
-- }}}

-- {{{ function ConditionalManaSystem:get_enemies_in_melee_range
function ConditionalManaSystem:get_enemies_in_melee_range(entity_id, position, entity_manager)
    local enemies = {}
    local team = entity_manager:get_component(entity_id, "team")
    if not team then return enemies end
    
    for other_id, other_team in entity_manager:iterate_components("team") do
        if other_id ~= entity_id and other_team.value ~= team.value then
            local other_position = entity_manager:get_component(other_id, "position")
            local other_health = entity_manager:get_component(other_id, "health")
            
            if other_position and other_health and other_health.current > 0 then
                local distance = position.value:distance_to(other_position.value)
                if distance <= self.melee_engagement_range then
                    table.insert(enemies, {
                        id = other_id,
                        distance = distance,
                        position = other_position.value
                    })
                end
            end
        end
    end
    
    return enemies
end
-- }}}

-- {{{ function ConditionalManaSystem:is_ranged_in_good_position
function ConditionalManaSystem:is_ranged_in_good_position(position, enemies)
    for _, enemy in ipairs(enemies) do
        if enemy.distance < self.ranged_comfort_distance then
            return false -- too close to enemies
        end
    end
    return #enemies > 0 -- has targets but at safe distance
end
-- }}}

-- {{{ function ConditionalManaSystem:is_providing_cover_fire
function ConditionalManaSystem:is_providing_cover_fire(entity_id, position, entity_manager)
    -- Check if there are allies between this unit and enemies
    local allies_in_front = 0
    local team = entity_manager:get_component(entity_id, "team")
    if not team then return false end
    
    for other_id, other_team in entity_manager:iterate_components("team") do
        if other_id ~= entity_id and other_team.value == team.value then
            local other_position = entity_manager:get_component(other_id, "position")
            if other_position then
                local distance = position.value:distance_to(other_position.value)
                if distance <= 40 and self:is_ally_in_front(position.value, other_position.value) then
                    allies_in_front = allies_in_front + 1
                end
            end
        end
    end
    
    return allies_in_front >= 1
end
-- }}}

-- {{{ function ConditionalManaSystem:is_engaged_in_melee
function ConditionalManaSystem:is_engaged_in_melee(entity_id, enemies_in_range)
    for _, enemy in ipairs(enemies_in_range) do
        if enemy.distance <= self.melee_optimal_range then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ function ConditionalManaSystem:is_flanking_enemies
function ConditionalManaSystem:is_flanking_enemies(position, enemies)
    -- Simple flanking detection: are we approaching from side/behind?
    if #enemies == 0 then return false end
    
    -- This would need more sophisticated logic based on enemy facing
    -- For now, just check if we're at optimal range with multiple enemies
    return #enemies >= 2
end
-- }}}

-- {{{ function ConditionalManaSystem:is_ally_in_front
function ConditionalManaSystem:is_ally_in_front(my_position, ally_position)
    -- Simplified: ally is "in front" if they're closer to the enemy base
    -- This would need to account for actual map layout and lane direction
    return ally_position.x > my_position.x -- assuming rightward movement
end
-- }}}

-- {{{ function ConditionalManaSystem:apply_mana_generation
function ConditionalManaSystem:apply_mana_generation(mana_component, dt)
    if not mana_component.generation_state then return end
    
    for ability_index, generation_info in pairs(mana_component.generation_state) do
        if generation_info.base_rate then
            local base_rate = 8 -- secondary ability base rate
            local bonus_multiplier = 1.0
            
            -- Apply bonuses based on conditions
            if generation_info.bonus_combat_position then
                bonus_multiplier = bonus_multiplier + 0.15
            end
            if generation_info.bonus_cover_fire then
                bonus_multiplier = bonus_multiplier + 0.10
            end
            if generation_info.bonus_engaged then
                bonus_multiplier = bonus_multiplier + 0.25
            end
            if generation_info.bonus_charging then
                bonus_multiplier = bonus_multiplier + 0.20
            end
            if generation_info.bonus_flanking then
                bonus_multiplier = bonus_multiplier + 0.15
            end
            
            local final_rate = base_rate * bonus_multiplier
            local mana_gain = final_rate * dt
            
            mana_component.current_mana[ability_index] = math.min(
                mana_component.max_mana[ability_index],
                mana_component.current_mana[ability_index] + mana_gain
            )
        end
    end
end
-- }}}

return ConditionalManaSystem
```

### Unit Behavior State Tracking (src/components/unit_state.lua)
```lua
-- {{{ UnitStateComponent
local UnitStateComponent = {}
UnitStateComponent.__index = UnitStateComponent

function UnitStateComponent:new()
    local component = {
        -- Ranged unit state
        stationary_duration = 0,
        last_movement_time = 0,
        preferred_distance_to_enemies = 50,
        
        -- Melee unit state  
        engagement_duration = 0,
        last_enemy_contact = 0,
        charge_start_time = 0,
        
        -- Shared state
        current_target = nil,
        last_ability_use = {},
        tactical_position = "advancing", -- advancing, positioned, retreating, engaged
        
        -- Condition flags (updated each frame)
        is_stationary_qualified = false,
        has_enemies_in_range = false,
        is_in_combat = false,
        is_providing_support = false
    }
    setmetatable(component, self)
    return component
end
-- }}}

return UnitStateComponent
```

### Performance Optimizations
- Spatial hashing for enemy detection to reduce O(n²) searches
- Condition caching to avoid recalculating every frame
- Batch processing of units with similar states
- Early exit when mana is already at maximum

### Acceptance Criteria
- [ ] Ranged units only generate secondary mana when stationary for ≥0.25 seconds
- [ ] Melee units only generate secondary mana when enemies within 55 units
- [ ] Bonus generation rates apply correctly for tactical positioning
- [ ] State transitions (moving→stationary, in range→out of range) work smoothly
- [ ] System handles edge cases (no enemies, no allies, unit death)
- [ ] Performance scales well with 100+ units