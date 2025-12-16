# Issue #027: Implement Mana Bars for Each Unit Ability

## Current Behavior
Units exist but lack any ability system or mana mechanics for triggering special abilities.

## Intended Behavior
Each unit should have individual mana bars for each of their abilities (1-4 abilities), with visual representation and proper mana tracking.

## Implementation Details

### Mana Component System (src/components/mana.lua)
```lua
-- {{{ ManaComponent
local ManaComponent = {}
ManaComponent.__index = ManaComponent

function ManaComponent:new(abilities_config)
    local component = {
        abilities = {},
        generation_rates = {},
        current_mana = {},
        max_mana = {},
        last_update = 0
    }
    
    -- Initialize mana bars for each ability
    for i, ability_config in ipairs(abilities_config) do
        component.abilities[i] = ability_config
        component.current_mana[i] = 0
        component.max_mana[i] = ability_config.max_mana or 100
        component.generation_rates[i] = ability_config.mana_rate or 1
    end
    
    setmetatable(component, self)
    return component
end
-- }}}

-- {{{ function ManaComponent:update
function ManaComponent:update(dt, unit_state)
    for i, ability in ipairs(self.abilities) do
        local should_generate = self:should_generate_mana(i, ability, unit_state)
        
        if should_generate and self.current_mana[i] < self.max_mana[i] then
            self.current_mana[i] = math.min(
                self.max_mana[i],
                self.current_mana[i] + (self.generation_rates[i] * dt)
            )
        end
    end
end
-- }}}

-- {{{ function ManaComponent:should_generate_mana
function ManaComponent:should_generate_mana(ability_index, ability, unit_state)
    -- Primary ability (index 1) always generates mana
    if ability_index == 1 then
        return true
    end
    
    -- Secondary abilities have conditional generation
    if unit_state.unit_type == "ranged" then
        -- Ranged units: generate when standing still
        return unit_state.is_stationary
    elseif unit_state.unit_type == "melee" then
        -- Melee units: generate when in enemy range
        return unit_state.enemies_in_range
    end
    
    return false
end
-- }}}

-- {{{ function ManaComponent:consume_mana
function ManaComponent:consume_mana(ability_index, amount)
    if self.current_mana[ability_index] >= amount then
        self.current_mana[ability_index] = self.current_mana[ability_index] - amount
        return true
    end
    return false
end
-- }}}

-- {{{ function ManaComponent:get_mana_percentage
function ManaComponent:get_mana_percentage(ability_index)
    if self.max_mana[ability_index] == 0 then return 0 end
    return self.current_mana[ability_index] / self.max_mana[ability_index]
end
-- }}}

return ManaComponent
```

### Mana System Integration (src/systems/mana_system.lua)
```lua
-- {{{ ManaSystem
local ManaSystem = {}
ManaSystem.__index = ManaSystem

function ManaSystem:new()
    local system = {
        entities_with_mana = {}
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function ManaSystem:update
function ManaSystem:update(dt, entity_manager)
    for entity_id, mana_component in pairs(self.entities_with_mana) do
        local unit_state = self:get_unit_state(entity_id, entity_manager)
        mana_component:update(dt, unit_state)
    end
end
-- }}}

-- {{{ function ManaSystem:get_unit_state
function ManaSystem:get_unit_state(entity_id, entity_manager)
    local position = entity_manager:get_component(entity_id, "position")
    local moveable = entity_manager:get_component(entity_id, "moveable")
    local unit = entity_manager:get_component(entity_id, "unit")
    
    return {
        unit_type = unit and unit.unit_type or "melee",
        is_stationary = moveable and moveable.velocity:length() < 0.1,
        enemies_in_range = self:check_enemies_in_range(entity_id, position, entity_manager),
        position = position
    }
end
-- }}}

-- {{{ function ManaSystem:check_enemies_in_range
function ManaSystem:check_enemies_in_range(entity_id, position, entity_manager)
    if not position then return false end
    
    local unit = entity_manager:get_component(entity_id, "unit")
    local team = entity_manager:get_component(entity_id, "team")
    if not unit or not team then return false end
    
    local detection_range = unit.detection_range or 50
    
    for other_id, other_team in entity_manager:iterate_components("team") do
        if other_id ~= entity_id and other_team.value ~= team.value then
            local other_position = entity_manager:get_component(other_id, "position")
            if other_position then
                local distance = position.value:distance_to(other_position.value)
                if distance <= detection_range then
                    return true
                end
            end
        end
    end
    
    return false
end
-- }}}

return ManaSystem
```

### Mana Bar Rendering (src/systems/mana_render_system.lua)
```lua
-- {{{ ManaRenderSystem
local ManaRenderSystem = {}
ManaRenderSystem.__index = ManaRenderSystem

function ManaRenderSystem:new()
    local system = {
        bar_width = 30,
        bar_height = 4,
        bar_spacing = 2,
        bar_offset_y = -15
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function ManaRenderSystem:render
function ManaRenderSystem:render(entity_manager)
    for entity_id, mana_component in entity_manager:iterate_components("mana") do
        local position = entity_manager:get_component(entity_id, "position")
        if position then
            self:render_mana_bars(position.value, mana_component)
        end
    end
end
-- }}}

-- {{{ function ManaRenderSystem:render_mana_bars
function ManaRenderSystem:render_mana_bars(unit_position, mana_component)
    local num_abilities = #mana_component.abilities
    local total_height = (num_abilities * self.bar_height) + ((num_abilities - 1) * self.bar_spacing)
    local start_y = unit_position.y + self.bar_offset_y - (total_height / 2)
    
    for i, ability in ipairs(mana_component.abilities) do
        local bar_y = start_y + ((i - 1) * (self.bar_height + self.bar_spacing))
        local mana_percentage = mana_component:get_mana_percentage(i)
        
        self:render_single_mana_bar(
            unit_position.x - (self.bar_width / 2),
            bar_y,
            mana_percentage,
            ability
        )
    end
end
-- }}}

-- {{{ function ManaRenderSystem:render_single_mana_bar
function ManaRenderSystem:render_single_mana_bar(x, y, percentage, ability)
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, self.bar_width, self.bar_height)
    
    -- Mana fill
    local fill_width = self.bar_width * percentage
    local ability_color = self:get_ability_color(ability)
    love.graphics.setColor(ability_color.r, ability_color.g, ability_color.b, 0.9)
    love.graphics.rectangle("fill", x, y, fill_width, self.bar_height)
    
    -- Border
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.rectangle("line", x, y, self.bar_width, self.bar_height)
end
-- }}}

-- {{{ function ManaRenderSystem:get_ability_color
function ManaRenderSystem:get_ability_color(ability)
    local ability_colors = {
        primary = {r = 0.3, g = 0.7, b = 1.0},   -- Blue
        damage = {r = 1.0, g = 0.3, b = 0.3},    -- Red
        heal = {r = 0.3, g = 1.0, b = 0.3},      -- Green
        buff = {r = 1.0, g = 1.0, b = 0.3},      -- Yellow
        debuff = {r = 0.8, g = 0.3, b = 0.8}     -- Purple
    }
    
    return ability_colors[ability.type] or ability_colors.primary
end
-- }}}

return ManaRenderSystem
```

### Integration Points
- Add mana component to unit creation in spawning system
- Integrate mana system with movement system for stationary detection
- Connect with combat detection system for enemy range detection
- Add mana rendering to the main render loop

### Acceptance Criteria
- [ ] Each unit displays individual mana bars for all abilities
- [ ] Primary abilities generate mana continuously
- [ ] Secondary abilities generate mana based on unit type conditions
- [ ] Mana bars visually represent current mana levels
- [ ] Different ability types have distinct colors
- [ ] Mana generation respects unit state (stationary/in-range)