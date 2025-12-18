# Issue #401: Create Mana Generation Rules (Primary vs Secondary)

## Current Behavior
Basic mana bar system exists but lacks the sophisticated generation rules that differentiate primary and secondary abilities.

## Intended Behavior
Implement comprehensive mana generation rules where primary abilities generate continuously while secondary abilities have conditional generation based on unit type and state.

## Implementation Details

### Enhanced Mana Generation Logic (src/systems/mana_generation_system.lua)
```lua
-- {{{ ManaGenerationSystem
local ManaGenerationSystem = {}
ManaGenerationSystem.__index = ManaGenerationSystem

function ManaGenerationSystem:new()
    local system = {
        base_generation_rate = 10, -- mana per second for primary abilities
        conditional_generation_rate = 8, -- mana per second for secondary abilities
        range_detection_distance = 60,
        stationary_threshold = 0.5, -- velocity below this is considered stationary
        stationary_time_requirement = 0.2 -- must be stationary for this long
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function ManaGenerationSystem:update
function ManaGenerationSystem:update(dt, entity_manager)
    for entity_id, mana_component in entity_manager:iterate_components("mana") do
        local unit_state = self:get_comprehensive_unit_state(entity_id, entity_manager)
        self:update_mana_generation(mana_component, unit_state, dt)
    end
end
-- }}}

-- {{{ function ManaGenerationSystem:get_comprehensive_unit_state
function ManaGenerationSystem:get_comprehensive_unit_state(entity_id, entity_manager)
    local position = entity_manager:get_component(entity_id, "position")
    local moveable = entity_manager:get_component(entity_id, "moveable")
    local unit = entity_manager:get_component(entity_id, "unit")
    local team = entity_manager:get_component(entity_id, "team")
    
    -- Track stationary time
    local current_velocity = moveable and moveable.velocity:length() or 0
    local is_currently_stationary = current_velocity < self.stationary_threshold
    
    if not unit.stationary_timer then
        unit.stationary_timer = 0
    end
    
    if is_currently_stationary then
        unit.stationary_timer = unit.stationary_timer + (1/60) -- assuming 60fps
    else
        unit.stationary_timer = 0
    end
    
    local qualified_stationary = unit.stationary_timer >= self.stationary_time_requirement
    
    return {
        unit_type = unit and unit.unit_type or "melee",
        is_stationary = qualified_stationary,
        is_moving = not qualified_stationary,
        velocity = current_velocity,
        enemies_in_range = self:get_enemies_in_range(entity_id, position, team, entity_manager),
        allies_nearby = self:get_allies_nearby(entity_id, position, team, entity_manager),
        combat_state = self:determine_combat_state(entity_id, entity_manager),
        position = position
    }
end
-- }}}

-- {{{ function ManaGenerationSystem:update_mana_generation
function ManaGenerationSystem:update_mana_generation(mana_component, unit_state, dt)
    for i, ability in ipairs(mana_component.abilities) do
        local generation_rate = self:calculate_generation_rate(i, ability, unit_state)
        
        if generation_rate > 0 and mana_component.current_mana[i] < mana_component.max_mana[i] then
            local mana_gain = generation_rate * dt
            mana_component.current_mana[i] = math.min(
                mana_component.max_mana[i],
                mana_component.current_mana[i] + mana_gain
            )
        end
    end
end
-- }}}

-- {{{ function ManaGenerationSystem:calculate_generation_rate
function ManaGenerationSystem:calculate_generation_rate(ability_index, ability, unit_state)
    -- Primary ability (index 1) always generates at base rate
    if ability_index == 1 then
        return self.base_generation_rate
    end
    
    -- Secondary abilities have conditional generation
    local can_generate = false
    
    if unit_state.unit_type == "ranged" then
        -- Ranged units: generate when standing still
        can_generate = unit_state.is_stationary
        
        -- Bonus generation when in combat but stationary
        if can_generate and unit_state.combat_state == "in_combat" then
            return self.conditional_generation_rate * 1.2
        end
        
    elseif unit_state.unit_type == "melee" then
        -- Melee units: generate when enemies are in range
        can_generate = #unit_state.enemies_in_range > 0
        
        -- Bonus generation when actually engaged in melee
        if can_generate and unit_state.combat_state == "melee_engaged" then
            return self.conditional_generation_rate * 1.3
        end
    end
    
    return can_generate and self.conditional_generation_rate or 0
end
-- }}}

-- {{{ function ManaGenerationSystem:get_enemies_in_range
function ManaGenerationSystem:get_enemies_in_range(entity_id, position, team, entity_manager)
    local enemies = {}
    
    if not position or not team then return enemies end
    
    for other_id, other_team in entity_manager:iterate_components("team") do
        if other_id ~= entity_id and other_team.value ~= team.value then
            local other_position = entity_manager:get_component(other_id, "position")
            local other_health = entity_manager:get_component(other_id, "health")
            
            if other_position and other_health and other_health.current > 0 then
                local distance = position.value:distance_to(other_position.value)
                if distance <= self.range_detection_distance then
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

-- {{{ function ManaGenerationSystem:get_allies_nearby
function ManaGenerationSystem:get_allies_nearby(entity_id, position, team, entity_manager)
    local allies = {}
    
    if not position or not team then return allies end
    
    for other_id, other_team in entity_manager:iterate_components("team") do
        if other_id ~= entity_id and other_team.value == team.value then
            local other_position = entity_manager:get_component(other_id, "position")
            
            if other_position then
                local distance = position.value:distance_to(other_position.value)
                if distance <= self.range_detection_distance then
                    table.insert(allies, {
                        id = other_id,
                        distance = distance,
                        position = other_position.value
                    })
                end
            end
        end
    end
    
    return allies
end
-- }}}

-- {{{ function ManaGenerationSystem:determine_combat_state
function ManaGenerationSystem:determine_combat_state(entity_id, entity_manager)
    -- This would integrate with combat detection system
    -- For now, return basic states
    local unit = entity_manager:get_component(entity_id, "unit")
    
    if unit and unit.current_target then
        if unit.unit_type == "melee" then
            return "melee_engaged"
        else
            return "ranged_combat"
        end
    end
    
    return "no_combat"
end
-- }}}

return ManaGenerationSystem
```

### Conditional Generation Rules Documentation (docs/mana-generation-rules.md)
```markdown
# Mana Generation Rules

## Primary Abilities
- **Generation Rate**: Continuous at base rate (10 mana/second)
- **Conditions**: Always active, no restrictions
- **Purpose**: Ensures units always have access to their core ability

## Secondary Abilities (Ranged Units)
- **Generation Rate**: 8 mana/second when conditions met
- **Primary Condition**: Unit must be stationary for ≥0.2 seconds
- **Bonus Conditions**: 
  - In combat while stationary: +20% generation rate
  - Provides covering fire: +10% generation rate
- **Rationale**: Encourages positioning and tactical patience

## Secondary Abilities (Melee Units)
- **Generation Rate**: 8 mana/second when conditions met
- **Primary Condition**: Enemies within range (60 units)
- **Bonus Conditions**:
  - Actually engaged in melee: +30% generation rate
  - Outnumbered (2+ enemies): +15% generation rate
- **Rationale**: Rewards aggressive positioning and engagement

## Special Cases
- **No Valid Targets**: Mana stops at maximum until targets available
- **Interrupted Actions**: No penalty, generation resumes when conditions met
- **Unit Death**: All mana resets to 0 (if unit is revived)
```

### Integration with Ability Framework
- Connect with targeting system for valid target detection
- Interface with movement system for stationary state tracking
- Coordinate with combat system for engagement state
- Provide hooks for future ability activation system

### Performance Considerations
- Cache enemy/ally searches per frame rather than per unit
- Use spatial partitioning for range queries with many units
- Limit generation calculations to units with secondary abilities
- Batch state updates for multiple units with same conditions

### Acceptance Criteria
- [ ] Primary abilities generate mana continuously regardless of conditions
- [ ] Ranged units generate secondary mana only when stationary
- [ ] Melee units generate secondary mana only when enemies in range
- [ ] Bonus generation rates apply in appropriate combat situations
- [ ] Generation stops appropriately when conditions not met
- [ ] Performance remains stable with 50+ units