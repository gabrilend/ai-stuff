# Issue #036: Create Base Entities with Health Pools

## Current Behavior
The game lacks base structures that serve as victory objectives and defensive positions for each team.

## Intended Behavior
Each team should have a base entity with substantial health that serves as the ultimate victory objective, with proper health management and destruction mechanics.

## Implementation Details

### Base Entity System (src/entities/base.lua)
```lua
-- {{{ local function create_base
local function create_base(team_id, position, base_type)
    local base_id = EntityManager:create_entity()
    
    // Core base components
    EntityManager:add_component(base_id, "position", {
        x = position.x,
        y = position.y,
        is_static = true,  // Bases don't move
        spawn_area_radius = 40
    })
    
    // Base health system - equivalent to ~20 average units
    local base_health_multiplier = get_base_health_multiplier(base_type)
    local base_max_health = 400 * base_health_multiplier  // 400 base health
    
    EntityManager:add_component(base_id, "health", {
        current = base_max_health,
        maximum = base_max_health,
        is_alive = true,
        last_damage_time = 0,
        damage_sections = create_base_damage_sections(base_max_health),
        structural_integrity = 1.0
    })
    
    EntityManager:add_component(base_id, "team", {
        id = team_id,
        alliance = team_id == 1 and "player" or "enemy"
    })
    
    EntityManager:add_component(base_id, "base", {
        base_type = base_type or "standard",
        construction_level = 1,
        defensive_systems = {},
        active_abilities = {},
        supply_range = 60,
        influence_radius = 80
    })
    
    EntityManager:add_component(base_id, "renderable", {
        shape = "base_structure",
        color = team_id == 1 and Colors.BLUE or Colors.RED,
        size = 25,
        visible = true,
        render_layer = "structures",
        detail_level = "high"
    })
    
    // Base-specific systems
    initialize_base_defensive_systems(base_id, base_type)
    register_base_with_team(base_id, team_id)
    
    Debug:log("Created " .. base_type .. " base for team " .. team_id .. " at " .. position.x .. "," .. position.y)
    return base_id
end
-- }}}

-- {{{ local function create_base_damage_sections
local function create_base_damage_sections(max_health)
    // Divide base health into sections for visual damage states
    return {
        {
            name = "pristine",
            health_threshold = 0.8,  // 80% health
            damage_effects = {},
            structural_state = "intact"
        },
        {
            name = "damaged",
            health_threshold = 0.6,  // 60% health
            damage_effects = {"smoke_light", "debris_minor"},
            structural_state = "damaged"
        },
        {
            name = "heavily_damaged",
            health_threshold = 0.4,  // 40% health
            damage_effects = {"smoke_heavy", "debris_major", "sparks"},
            structural_state = "compromised"
        },
        {
            name = "critical",
            health_threshold = 0.2,  // 20% health
            damage_effects = {"fire", "smoke_heavy", "debris_major", "electrical_failures"},
            structural_state = "critical"
        },
        {
            name = "destroyed",
            health_threshold = 0.0,  // 0% health
            damage_effects = {"explosion", "collapse"},
            structural_state = "destroyed"
        }
    }
end
-- }}}

-- {{{ local function get_base_health_multiplier
local function get_base_health_multiplier(base_type)
    local multipliers = {
        standard = 1.0,
        fortified = 1.5,
        command_center = 2.0,
        fortress = 2.5
    }
    
    return multipliers[base_type] or 1.0
end
-- }}}

-- {{{ local function update_base_health_system
local function update_base_health_system(base_id, dt)
    local health = EntityManager:get_component(base_id, "health")
    local base_data = EntityManager:get_component(base_id, "base")
    
    if not health or not base_data then
        return
    end
    
    // Update structural integrity based on health
    update_structural_integrity(base_id, health)
    
    // Update damage section states
    update_damage_section_effects(base_id, health)
    
    // Handle base destruction
    if health.current <= 0 and health.is_alive then
        trigger_base_destruction(base_id)
    end
    
    // Base regeneration (very slow)
    apply_base_regeneration(base_id, health, dt)
end
-- }}}

-- {{{ local function update_structural_integrity
local function update_structural_integrity(base_id, health)
    local health_ratio = health.current / health.maximum
    health.structural_integrity = health_ratio
    
    // Apply structural effects based on integrity
    if health_ratio < 0.5 then
        // Reduced effectiveness of base systems
        apply_structural_damage_effects(base_id, 1 - health_ratio)
    end
end
-- }}}

-- {{{ local function update_damage_section_effects
local function update_damage_section_effects(base_id, health)
    local health_ratio = health.current / health.maximum
    local current_section = nil
    
    // Find current damage section
    for _, section in ipairs(health.damage_sections) do
        if health_ratio > section.health_threshold then
            current_section = section
            break
        end
    end
    
    if not current_section then
        current_section = health.damage_sections[#health.damage_sections]  // Most damaged
    end
    
    // Apply section effects
    apply_damage_section_visual_effects(base_id, current_section)
    
    // Store current section for reference
    health.current_damage_section = current_section.name
end
-- }}}

-- {{{ local function apply_damage_section_visual_effects
local function apply_damage_section_visual_effects(base_id, section)
    local position = EntityManager:get_component(base_id, "position")
    
    if not position then
        return
    end
    
    local base_pos = Vector2:new(position.x, position.y)
    
    // Create ongoing damage effects
    for _, effect_type in ipairs(section.damage_effects) do
        if effect_type == "smoke_light" then
            create_base_smoke_effect(base_pos, "light")
        elseif effect_type == "smoke_heavy" then
            create_base_smoke_effect(base_pos, "heavy")
        elseif effect_type == "fire" then
            create_base_fire_effect(base_pos)
        elseif effect_type == "sparks" then
            create_base_sparks_effect(base_pos)
        elseif effect_type == "debris_minor" then
            create_base_debris_effect(base_pos, "minor")
        elseif effect_type == "debris_major" then
            create_base_debris_effect(base_pos, "major")
        end
    end
    
    // Update visual appearance
    update_base_visual_damage(base_id, section)
end
-- }}}

-- {{{ local function apply_base_damage
local function apply_base_damage(base_id, damage, attacker_id)
    local health = EntityManager:get_component(base_id, "health")
    local base_data = EntityManager:get_component(base_id, "base")
    
    if not health or not health.is_alive or not base_data then
        return 0
    end
    
    // Calculate effective damage
    local damage_reduction = calculate_base_damage_reduction(base_id, base_data)
    local effective_damage = damage * (1 - damage_reduction)
    
    // Apply damage
    local damage_dealt = math.min(effective_damage, health.current)
    health.current = health.current - damage_dealt
    health.last_damage_time = love.timer.getTime()
    health.last_attacker = attacker_id
    
    // Create damage effect
    create_base_damage_effect(base_id, damage_dealt)
    
    // Trigger damage response
    trigger_base_damage_response(base_id, damage_dealt, attacker_id)
    
    Debug:log("Base " .. base_id .. " took " .. damage_dealt .. " damage (reduced from " .. damage .. ")")
    return damage_dealt
end
-- }}}

-- {{{ local function calculate_base_damage_reduction
local function calculate_base_damage_reduction(base_id, base_data)
    local base_reduction = 0.1  // 10% base damage reduction
    
    // Structural integrity affects damage reduction
    local health = EntityManager:get_component(base_id, "health")
    if health then
        local integrity_bonus = health.structural_integrity * 0.2  // Up to 20% when undamaged
        base_reduction = base_reduction + integrity_bonus
    end
    
    // Base type modifications
    if base_data.base_type == "fortified" then
        base_reduction = base_reduction + 0.15  // Additional 15% reduction
    elseif base_data.base_type == "fortress" then
        base_reduction = base_reduction + 0.25  // Additional 25% reduction
    end
    
    return math.min(0.5, base_reduction)  // Cap at 50% reduction
end
-- }}}

-- {{{ local function trigger_base_destruction
local function trigger_base_destruction(base_id)
    local health = EntityManager:get_component(base_id, "health")
    local team = EntityManager:get_component(base_id, "team")
    local position = EntityManager:get_component(base_id, "position")
    
    if health then
        health.is_alive = false
        health.destruction_time = love.timer.getTime()
    end
    
    // Create massive destruction effect
    create_base_destruction_effect(base_id)
    
    // Trigger game victory condition
    if team then
        GameState:trigger_victory_condition(team.id == 1 and 2 or 1)  // Other team wins
    end
    
    // Notify all systems
    notify_base_destruction(base_id, team and team.id or 0)
    
    Debug:log("Base " .. base_id .. " has been destroyed!")
end
-- }}}

-- {{{ local function apply_base_regeneration
local function apply_base_regeneration(base_id, health, dt)
    if not health.is_alive or health.current >= health.maximum then
        return
    end
    
    // Very slow regeneration - bases repair themselves over time when not under attack
    local time_since_damage = love.timer.getTime() - (health.last_damage_time or 0)
    
    if time_since_damage > 10.0 then  // 10 seconds without damage
        local regen_rate = health.maximum * 0.01  // 1% per second
        local regen_amount = regen_rate * dt
        
        health.current = math.min(health.maximum, health.current + regen_amount)
        
        // Create regeneration effect occasionally
        if math.random() < 0.05 then  // 5% chance per frame
            create_base_repair_effect(base_id)
        end
    end
end
-- }}}

-- {{{ local function create_base_destruction_effect
local function create_base_destruction_effect(base_id)
    local position = EntityManager:get_component(base_id, "position")
    
    if not position then
        return
    end
    
    local base_pos = Vector2:new(position.x, position.y)
    
    // Massive explosion effect
    local explosion_effect = {
        type = "base_destruction_explosion",
        position = base_pos,
        duration = 3.0,
        start_time = love.timer.getTime(),
        max_radius = 50,
        color = Colors.ORANGE,
        intensity = 1.0
    }
    EffectSystem:add_effect(explosion_effect)
    
    // Screen shake
    local shake_effect = {
        type = "screen_shake",
        intensity = 15,
        duration = 2.0,
        start_time = love.timer.getTime()
    }
    EffectSystem:add_effect(shake_effect)
    
    // Debris field
    for i = 1, 20 do
        local angle = (i / 20) * 2 * math.pi
        local debris_distance = math.random(20, 40)
        local debris_velocity = Vector2:new(
            math.cos(angle) * debris_distance,
            math.sin(angle) * debris_distance
        )
        
        local debris_effect = {
            type = "base_debris",
            position = base_pos,
            velocity = debris_velocity,
            duration = 4.0,
            start_time = love.timer.getTime(),
            size = math.random(3, 8),
            color = Colors.GRAY
        }
        EffectSystem:add_effect(debris_effect)
    end
    
    // Screen flash
    local flash_effect = {
        type = "screen_flash",
        color = Colors.WHITE,
        intensity = 0.8,
        duration = 0.5,
        start_time = love.timer.getTime()
    }
    EffectSystem:add_effect(flash_effect)
end
-- }}}

-- {{{ local function create_base_damage_effect
local function create_base_damage_effect(base_id, damage)
    local position = EntityManager:get_component(base_id, "position")
    
    if position then
        local base_pos = Vector2:new(position.x, position.y)
        
        // Impact effect
        local impact_effect = {
            type = "base_impact",
            position = base_pos:add(Vector2:new(math.random(-10, 10), math.random(-10, 10))),
            damage = damage,
            duration = 1.0,
            start_time = love.timer.getTime(),
            color = Colors.RED,
            size = math.min(15, 5 + damage / 10)
        }
        EffectSystem:add_effect(impact_effect)
        
        // Damage number
        local damage_number_effect = {
            type = "base_damage_number",
            position = base_pos:add(Vector2:new(0, -20)),
            damage = damage,
            duration = 2.0,
            start_time = love.timer.getTime(),
            velocity = Vector2:new(0, -30),
            color = Colors.RED,
            font_size = 20
        }
        EffectSystem:add_effect(damage_number_effect)
    end
end
-- }}}

-- {{{ local function register_base_with_team
local function register_base_with_team(base_id, team_id)
    if not team_bases then
        team_bases = {}
    end
    
    if not team_bases[team_id] then
        team_bases[team_id] = {}
    end
    
    table.insert(team_bases[team_id], base_id)
    
    // Notify team systems
    TeamSystem:register_team_base(team_id, base_id)
end
-- }}}

-- {{{ local function get_team_bases
local function get_team_bases(team_id)
    if not team_bases or not team_bases[team_id] then
        return {}
    end
    
    // Filter out destroyed bases
    local active_bases = {}
    for _, base_id in ipairs(team_bases[team_id]) do
        local health = EntityManager:get_component(base_id, "health")
        if health and health.is_alive then
            table.insert(active_bases, base_id)
        end
    end
    
    return active_bases
end
-- }}}
```

### Base Entity Features
1. **Substantial Health**: Large health pools equivalent to multiple units
2. **Damage Sections**: Visual progression of damage states
3. **Structural Integrity**: Health affects base effectiveness
4. **Regeneration**: Slow self-repair when not under attack
5. **Victory Conditions**: Base destruction triggers game end

### Base Types
- **Standard**: Basic base with normal health and defenses
- **Fortified**: Enhanced damage reduction and health
- **Command Center**: Large health pool with command abilities
- **Fortress**: Maximum protection and defensive capabilities

### Health Management
- Multi-stage damage visualization
- Structural integrity affects defensive capabilities
- Slow regeneration encourages strategic timing
- Damage reduction based on base type and condition

### Tool Suggestions
- Use Write tool to create base entity system
- Test with different base types and health values
- Verify damage progression and visual effects
- Check victory condition triggering

### Acceptance Criteria
- [ ] Bases have substantial health pools (~20 average units)
- [ ] Visual damage progression shows base condition
- [ ] Structural integrity affects base performance
- [ ] Base destruction triggers victory conditions
- [ ] Different base types have distinct characteristics