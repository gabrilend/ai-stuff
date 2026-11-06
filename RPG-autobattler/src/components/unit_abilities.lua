-- {{{ Unit abilities component
-- Holds a unit's abilities (one to four, the first is its primary) and
-- their cooldowns. Ability number i spends mana bar number i of the
-- unit's "mana" component, so attach() adds both components at once.
--
-- The container is a plain table so the entity manager can store it:
--   abilities        list of abilities (src/components/ability.lua)
--   cooldowns        seconds left before ability i may fire again
--   global_cooldown  seconds left before any ability may fire
--   last_used        index of the ability that fired last
--   last_target      what it was aimed at (an entity or a point)
-- Functions here take the container as their first argument.
local UnitAbilities = {}

local Ability = require("src.components.ability")
local ManaComponent = require("src.components.mana")

UnitAbilities.MAX_ABILITIES = 4
UnitAbilities.MOVING_SPEED = 0.1   -- slower than this counts as standing still

-- {{{ UnitAbilities.new
-- configs is a list of ability configs or abilities.
function UnitAbilities.new(configs)
    configs = configs or {}
    if #configs < 1 or #configs > UnitAbilities.MAX_ABILITIES then
        error("A unit needs between 1 and 4 abilities, got " .. #configs)
    end
    local container = {
        abilities = {},
        cooldowns = {},
        global_cooldown = 0,
        last_used = nil,
        last_target = nil
    }
    for index, config in ipairs(configs) do
        container.abilities[index] = Ability.is_ability(config) and config or Ability.new(config)
        container.cooldowns[index] = 0
    end
    return container
end
-- }}}

-- {{{ UnitAbilities.mana_for
-- A mana component with one bar sized and paced for each ability.
function UnitAbilities.mana_for(container)
    local bars = {}
    for index, ability in ipairs(container.abilities) do
        bars[index] = {
            name = ability.name,
            type = ability.type,
            max_mana = ability.max_mana,
            mana_rate = ability.mana_rate
        }
    end
    return ManaComponent(bars)
end
-- }}}

-- {{{ UnitAbilities.attach
-- Gives an entity its abilities and the mana bars to charge them.
-- Returns the abilities component and the mana component.
function UnitAbilities.attach(entity_manager, entity, configs)
    local container = UnitAbilities.new(configs)
    local mana = UnitAbilities.mana_for(container)
    entity_manager:add_component(entity, "abilities", container)
    entity_manager:add_component(entity, "mana", mana)
    return container, mana
end
-- }}}

-- {{{ UnitAbilities.update_cooldowns
function UnitAbilities.update_cooldowns(container, dt)
    for index, remaining in ipairs(container.cooldowns) do
        if remaining > 0 then
            container.cooldowns[index] = math.max(0, remaining - dt)
        end
    end
    if container.global_cooldown > 0 then
        container.global_cooldown = math.max(0, container.global_cooldown - dt)
    end
end
-- }}}

-- {{{ UnitAbilities.priority_of
-- Lower fires first. An ability's own priority wins; otherwise its slot,
-- so the primary ability comes before the secondaries.
function UnitAbilities.priority_of(container, index)
    local ability = container.abilities[index]
    return (ability and ability.priority) or index
end
-- }}}

-- {{{ local function snapshot_from
local function snapshot_from(entity_manager)
    local snapshot = {}
    for _, other in ipairs(entity_manager:get_entities_with_components({"position", "health", "team"})) do
        local health = entity_manager:get_component(other, "health")
        if health.alive and health.current_hp > 0 then
            local pos = entity_manager:get_component(other, "position")
            local team = entity_manager:get_component(other, "team")
            table.insert(snapshot, {entity = other, team = team.player_id, x = pos.x, y = pos.y})
        end
    end
    return snapshot
end
-- }}}

-- {{{ UnitAbilities.unit_state
-- What conditions are checked against: a description of the unit now.
-- snapshot is a list of living units {entity, team, x, y}, as ManaSystem
-- builds; it's made here when not given. Range counts are worked out only
-- when a condition asks, and remembered per range.
function UnitAbilities.unit_state(entity_manager, entity, snapshot)
    local em = entity_manager
    local health = em:get_component(entity, "health")
    local position = em:get_component(entity, "position")
    local team = em:get_component(entity, "team")
    local unit_data = em:get_component(entity, "unit_data")
    local moveable = em:get_component(entity, "moveable")
    local mana = em:get_component(entity, "mana")
    local effects = em:get_component(entity, "effects")

    local speed = 0
    if moveable then
        local vx, vy = moveable.velocity_x or 0, moveable.velocity_y or 0
        speed = math.sqrt(vx * vx + vy * vy)
    end

    local state = {
        entity = entity,
        unit_type = unit_data and unit_data.unit_type or "unknown",
        team = team and team.player_id or 0,
        alive = health ~= nil and health.alive and health.current_hp > 0,
        health_fraction = (health and health.max_hp > 0) and health.current_hp / health.max_hp or 0,
        moving = speed >= UnitAbilities.MOVING_SPEED,
        still_time = mana and mana.still_time or 0,
        combat_state = unit_data and unit_data.combat_state or "idle",
        active_effects = effects and effects.active or {},
        x = position and position.x or 0,
        y = position and position.y or 0
    }

    local counts = {enemies = {}, allies = {}}
    -- {{{ local function count_within
    local function count_within(range, enemies)
        local memo = enemies and counts.enemies or counts.allies
        if memo[range] then
            return memo[range]
        end
        snapshot = snapshot or snapshot_from(em)
        local range_sq = range * range
        local count = 0
        for _, other in ipairs(snapshot) do
            if other.entity ~= entity and (other.team ~= state.team) == enemies then
                local dx, dy = other.x - state.x, other.y - state.y
                if dx * dx + dy * dy <= range_sq then
                    count = count + 1
                end
            end
        end
        memo[range] = count
        return count
    end
    -- }}}

    function state.enemies_within(range)
        return count_within(range, true)
    end
    function state.allies_within(range)
        return count_within(range, false)
    end
    return state
end
-- }}}

-- {{{ UnitAbilities.get_ready
-- The abilities that may fire now, in the order they should be tried
-- (by priority), as {index, ability}. Also returns, for each ability that
-- may not, the reason ("mana_not_full", "on_cooldown",
-- "global_cooldown", "passive" or "condition_failed:<type>").
function UnitAbilities.get_ready(container, mana, state)
    local ready, blocked = {}, {}
    for index, ability in ipairs(container.abilities) do
        local bar = mana and mana.bars[index]
        local ok, reason = ability:can_activate(bar, state, container.cooldowns[index])
        if ok and container.global_cooldown > 0 then
            ok, reason = false, "global_cooldown"
        end
        if ok then
            table.insert(ready, {index = index, ability = ability})
        else
            blocked[index] = reason
        end
    end
    table.sort(ready, function(a, b)
        local pa, pb = UnitAbilities.priority_of(container, a.index), UnitAbilities.priority_of(container, b.index)
        if pa ~= pb then
            return pa < pb
        end
        return a.index < b.index
    end)
    return ready, blocked
end
-- }}}

-- {{{ UnitAbilities.get_debug_info
-- One row per ability: its settings, its bar, its cooldown.
function UnitAbilities.get_debug_info(container, mana)
    local rows = {}
    for index, ability in ipairs(container.abilities) do
        local row = ability:get_debug_info(mana and mana.bars[index])
        row.index = index
        row.cooldown = container.cooldowns[index]
        row.priority = UnitAbilities.priority_of(container, index)
        rows[index] = row
    end
    return {
        abilities = rows,
        global_cooldown = container.global_cooldown,
        last_used = container.last_used
    }
end
-- }}}

return UnitAbilities
-- }}}
