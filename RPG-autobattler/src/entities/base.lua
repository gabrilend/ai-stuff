-- {{{ Base entity factory
-- A base is the structure each team defends. When a base's health reaches
-- zero, that team has lost. This file creates bases and holds the rules for
-- how they take damage, show damage, lose effectiveness and repair.
--
-- Health is measured in "average units": the mean starting health of the
-- unit types in src/entities/unit.lua. The base core holds about five of
-- them, as the vision asks. The three defence shields (issue 037) add five
-- each, giving about twenty average units in all.
local Base = {}

local Colors = require("src.constants.colors")
local Unit = require("src.entities.unit")
local debug = require("src.utils.debug")

local PositionComponent = require("src.components.position")
local HealthComponent = require("src.components.health")
local TeamComponent = require("src.components.team")
local RenderableComponent = require("src.components.renderable")

-- {{{ local function compute_average_unit_health
-- The mean starting health of the unit types, so bases stay in step with
-- unit balance changes instead of holding a copied number.
local function compute_average_unit_health()
    local unit_types = {"melee", "ranged", "tank", "support", "special"}
    local total = 0
    for _, unit_type in ipairs(unit_types) do
        total = total + Unit.get_unit_base_health(unit_type)
    end
    return total / #unit_types
end
-- }}}

Base.AVERAGE_UNIT_HEALTH = compute_average_unit_health()
Base.CORE_HEALTH_IN_UNITS = 5

-- Seconds without damage before a base starts to repair itself.
Base.REGEN_DELAY = 8.0

-- {{{ Base types
-- health_multiplier scales the core's health; damage_reduction is the share
-- of each hit that the walls shrug off; regen_rate is health per second once
-- REGEN_DELAY has passed without damage.
Base.TYPES = {
    standard = {
        health_multiplier = 1.0,
        damage_reduction = 0.0,
        regen_rate = 1.0,
        size = 25
    },
    fortified = {
        health_multiplier = 1.1,
        damage_reduction = 0.15,
        regen_rate = 0.75,
        size = 27
    },
    command_center = {
        health_multiplier = 1.4,
        damage_reduction = 0.0,
        regen_rate = 1.5,
        size = 30
    },
    fortress = {
        health_multiplier = 1.25,
        damage_reduction = 0.25,
        regen_rate = 0.5,
        size = 32
    }
}
-- }}}

-- {{{ Damage sections
-- Ordered from healthiest to most damaged. A base is in the first section
-- whose threshold its health fraction is at or above. effectiveness scales
-- what the base can do (its turret, issue 038) as it falls apart.
Base.DAMAGE_SECTIONS = {
    {name = "pristine", threshold = 0.8, effectiveness = 1.0},
    {name = "damaged",  threshold = 0.6, effectiveness = 0.9},
    {name = "battered", threshold = 0.4, effectiveness = 0.75},
    {name = "critical", threshold = 0.2, effectiveness = 0.6},
    {name = "failing",  threshold = 0.0, effectiveness = 0.4}
}
-- }}}

-- {{{ Base.get_core_max_health
function Base.get_core_max_health(base_type)
    local type_data = Base.TYPES[base_type] or Base.TYPES.standard
    return Base.AVERAGE_UNIT_HEALTH * Base.CORE_HEALTH_IN_UNITS * type_data.health_multiplier
end
-- }}}

-- {{{ Base.get_damage_section
function Base.get_damage_section(health_fraction)
    for _, section in ipairs(Base.DAMAGE_SECTIONS) do
        if health_fraction >= section.threshold then
            return section
        end
    end
    return Base.DAMAGE_SECTIONS[#Base.DAMAGE_SECTIONS]
end
-- }}}

-- {{{ Base.create_base
-- Creates a base for team_id at position ({x, y} or a Vector2). Returns the
-- entity table, as EntityManager:create_entity does.
function Base.create_base(entity_manager, team_id, position, base_type)
    base_type = base_type or "standard"
    local type_data = Base.TYPES[base_type]
    if not type_data then
        error("Unknown base type: " .. tostring(base_type))
    end

    local entity = entity_manager:create_entity("base_team" .. team_id)

    local position_component = PositionComponent(position.x, position.y)
    position_component.is_static = true
    entity_manager:add_component(entity, "position", position_component)

    local max_hp = Base.get_core_max_health(base_type)
    local health = HealthComponent(max_hp)
    health.is_alive = true
    health.maximum = max_hp
    health.last_damage_time = 0
    entity_manager:add_component(entity, "health", health)

    local team_color = Unit.get_team_color(team_id)
    local team = TeamComponent(team_id, team_color)
    team.alliance = team_id == 1 and "player" or "enemy"
    entity_manager:add_component(entity, "team", team)

    entity_manager:add_component(entity, "base", {
        base_type = base_type,
        damage_reduction = type_data.damage_reduction,
        regen_rate = type_data.regen_rate,
        damage_section = Base.DAMAGE_SECTIONS[1].name,
        structural_integrity = 1.0,
        time_since_damage = Base.REGEN_DELAY,
        destroyed = false,
        destroyed_by = nil,
        total_damage_taken = 0,
        total_repaired = 0
    })

    local renderable = RenderableComponent("base_structure", team_color, type_data.size)
    renderable.render_layer = "structures"
    entity_manager:add_component(entity, "renderable", renderable)

    debug.info("Created " .. base_type .. " base for team " .. team_id ..
        " at " .. position.x .. "," .. position.y .. " with " .. max_hp .. " health", "BASE")
    return entity
end
-- }}}

-- {{{ Base.is_base
function Base.is_base(entity_manager, entity)
    return entity_manager:has_components(entity, {"base", "health", "team", "position"})
end
-- }}}

-- {{{ Base.is_destroyed
function Base.is_destroyed(entity_manager, entity)
    local base = entity_manager:get_component(entity, "base")
    return base == nil or base.destroyed
end
-- }}}

-- {{{ Base.get_health_fraction
function Base.get_health_fraction(entity_manager, entity)
    local health = entity_manager:get_component(entity, "health")
    if not health or health.max_hp <= 0 then
        return 0
    end
    return health.current_hp / health.max_hp
end
-- }}}

-- {{{ Base.get_effectiveness
-- How well the base's defences work, from 1.0 (pristine) down to the failing
-- section's value; 0 once destroyed.
function Base.get_effectiveness(entity_manager, entity)
    local base = entity_manager:get_component(entity, "base")
    if not base or base.destroyed then
        return 0
    end
    return base.structural_integrity
end
-- }}}

-- {{{ local function refresh_condition
local function refresh_condition(entity_manager, entity)
    local base = entity_manager:get_component(entity, "base")
    local section = Base.get_damage_section(Base.get_health_fraction(entity_manager, entity))
    local changed = section.name ~= base.damage_section
    base.damage_section = section.name
    base.structural_integrity = section.effectiveness
    if changed then
        debug.info("Base of team " .. Unit.get_team_id(entity_manager, entity) ..
            " is now " .. section.name, "BASE")
    end
end
-- }}}

-- {{{ Base.damage_core
-- Applies damage straight to the core, after the base type's damage
-- reduction. Returns the health actually removed. attacker_team is recorded
-- as the winner if this hit destroys the base.
function Base.damage_core(entity_manager, entity, amount, attacker_team)
    local base = entity_manager:get_component(entity, "base")
    local health = entity_manager:get_component(entity, "health")
    if not base or not health or base.destroyed or amount <= 0 then
        return 0
    end

    local reduced = amount * (1 - base.damage_reduction)
    local dealt = math.min(reduced, health.current_hp)
    health.current_hp = health.current_hp - dealt
    health.damage_taken = health.damage_taken + dealt
    base.total_damage_taken = base.total_damage_taken + dealt
    base.time_since_damage = 0

    if health.current_hp <= 0 then
        health.current_hp = 0
        health.alive = false
        health.is_alive = false
        base.destroyed = true
        base.destroyed_by = attacker_team
        base.structural_integrity = 0
        base.damage_section = "destroyed"
        debug.info("Base of team " .. Unit.get_team_id(entity_manager, entity) ..
            " destroyed by team " .. tostring(attacker_team), "BASE")
    else
        refresh_condition(entity_manager, entity)
    end

    return dealt
end
-- }}}

-- {{{ Base.apply_damage
-- The entry point for anything that attacks a base. Later layers (shields)
-- wrap this; for now every hit goes to the core.
function Base.apply_damage(entity_manager, entity, amount, attacker_team)
    return Base.damage_core(entity_manager, entity, amount, attacker_team)
end
-- }}}

-- {{{ Base.update
-- Advances one base by dt seconds: slow self-repair once REGEN_DELAY has
-- passed without damage. A destroyed base never repairs.
function Base.update(entity_manager, entity, dt)
    local base = entity_manager:get_component(entity, "base")
    local health = entity_manager:get_component(entity, "health")
    if not base or not health or base.destroyed then
        return
    end

    -- Only the part of dt that falls after the delay counts as repair time,
    -- so a long frame that crosses the delay does not over-repair.
    local before = base.time_since_damage
    base.time_since_damage = before + dt
    local repair_time = base.time_since_damage - math.max(before, Base.REGEN_DELAY)
    if repair_time <= 0 or health.current_hp >= health.max_hp then
        return
    end

    local repaired = math.min(base.regen_rate * repair_time, health.max_hp - health.current_hp)
    health.current_hp = health.current_hp + repaired
    health.healing_received = health.healing_received + repaired
    base.total_repaired = base.total_repaired + repaired
    refresh_condition(entity_manager, entity)
end
-- }}}

-- {{{ Base.get_render_color
-- The team color, dimmed as the base loses integrity, so damage reads by
-- brightness as well as by the section name drawn beside it.
function Base.get_render_color(entity_manager, entity)
    local renderable = entity_manager:get_component(entity, "renderable")
    local base = entity_manager:get_component(entity, "base")
    local color = renderable and renderable.color or Colors.WHITE or {1, 1, 1, 1}
    local brightness = 0.35 + 0.65 * (base and base.structural_integrity or 0)
    return {color[1] * brightness, color[2] * brightness, color[3] * brightness, color[4] or 1}
end
-- }}}

return Base
-- }}}
