-- {{{ BaseAssaultSystem
-- Lets units attack the enemy base (issue 040b). A unit with no enemy unit
-- within its reach, but within reach of the enemy base, hits it with its
-- normal attack:
--   while any shield stands  the front shield, at the shield's position
--   once all are down        the core, at the base's position
-- Hits go through Base.apply_damage with the attacker's team and id, so
-- the front shield takes them, and concentrated fire from several units
-- is recognised (issue 039).
--
-- With `march` on, a unit with nothing to attack also walks straight
-- toward its target at its own speed and stops at its reach. This stands
-- in for lane following, which the match doesn't run yet. A unit with an
-- enemy unit in its reach is left alone: fighting units is the combat
-- systems' job.
--
-- Units being removed by a reset (issue 040) neither attack nor walk.
-- Each hit is recorded as a "base_attacked" event.
local BaseAssaultSystem = {}
BaseAssaultSystem.__index = BaseAssaultSystem

local Base = require("src.entities.base")
local DefenseShield = require("src.entities.defense_shield")
local Unit = require("src.entities.unit")

-- A unit's normal attack, by type: how far it reaches (from its centre to
-- the edge of the target), the damage of one hit, and the seconds between
-- hits. Melee matches MeleeCombatSystem's 15 damage a second at reach 15;
-- ranged matches the projectile system's default 15 damage, from the 30
-- pixels ranged units shoot from.
BaseAssaultSystem.ATTACKS = {
    melee = {reach = 15, damage = 15, interval = 1.0},
    tank = {reach = 15, damage = 12, interval = 1.2},
    ranged = {reach = 30, damage = 15, interval = 1.5},
    support = {reach = 25, damage = 8, interval = 1.5},
    special = {reach = 20, damage = 18, interval = 1.5}
}
BaseAssaultSystem.DEFAULT_ATTACK = BaseAssaultSystem.ATTACKS.melee

-- How big a target is, added to a unit's reach.
BaseAssaultSystem.SHIELD_RADIUS = 9

-- {{{ BaseAssaultSystem:new
-- options.march: walk toward the enemy base when there is nothing to hit
-- (default true).
function BaseAssaultSystem:new(entity_manager, options)
    options = options or {}
    local system = {
        name = "base_assault_system",
        entity_manager = entity_manager,
        march = options.march ~= false,
        timers = {},        -- unit id -> seconds until it may hit again
        events = {},
        stats = {hits = 0, damage = 0, shield_hits = 0, core_hits = 0}
    }
    return setmetatable(system, BaseAssaultSystem)
end
-- }}}

-- {{{ BaseAssaultSystem.attack_of
function BaseAssaultSystem.attack_of(entity_manager, unit)
    return BaseAssaultSystem.ATTACKS[Unit.get_unit_type(entity_manager, unit)] or BaseAssaultSystem.DEFAULT_ATTACK
end
-- }}}

-- {{{ BaseAssaultSystem:find_enemy_base
-- The enemy team's living base, or nil.
function BaseAssaultSystem:find_enemy_base(team)
    local em = self.entity_manager
    for _, entity in ipairs(em:get_entities_with_component("base")) do
        if Unit.get_team_id(em, entity) ~= team and not Base.is_destroyed(em, entity) then
            return entity
        end
    end
    return nil
end
-- }}}

-- {{{ BaseAssaultSystem:target_point
-- Where a unit must reach to hit a base, and how big the target is there:
-- the front shield while one stands, otherwise the core.
function BaseAssaultSystem:target_point(base_entity)
    local em = self.entity_manager
    local front = DefenseShield.get_front_shield(Base.get_shields(em, base_entity))
    if front then
        return front.x, front.y, BaseAssaultSystem.SHIELD_RADIUS, "shield"
    end
    local pos = em:get_component(base_entity, "position")
    local renderable = em:get_component(base_entity, "renderable")
    local radius = renderable and renderable.size and renderable.size / 2 or 10
    return pos.x, pos.y, radius, "core"
end
-- }}}

-- {{{ BaseAssaultSystem:enemy_unit_in_reach
function BaseAssaultSystem:enemy_unit_in_reach(unit, team, x, y, reach)
    local em = self.entity_manager
    for _, other in ipairs(em:get_entities_with_components({"unit_data", "position", "team"})) do
        if other ~= unit and Unit.get_team_id(em, other) ~= team and Unit.is_alive(em, other) then
            local pos = em:get_component(other, "position")
            local dx, dy = pos.x - x, pos.y - y
            if dx * dx + dy * dy <= reach * reach then
                return true
            end
        end
    end
    return false
end
-- }}}

-- {{{ BaseAssaultSystem:update_unit
function BaseAssaultSystem:update_unit(unit, dt)
    local em = self.entity_manager
    local unit_data = em:get_component(unit, "unit_data")
    if not Unit.is_alive(em, unit) or (unit_data and unit_data.reset_in_progress) then
        return
    end
    local team = Unit.get_team_id(em, unit)
    local base = self:find_enemy_base(team)
    if not base then
        return
    end

    local pos = em:get_component(unit, "position")
    local attack = BaseAssaultSystem.attack_of(em, unit)
    if self:enemy_unit_in_reach(unit, team, pos.x, pos.y, attack.reach) then
        return
    end

    local tx, ty, radius, kind = self:target_point(base)
    local dx, dy = tx - pos.x, ty - pos.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local reach = attack.reach + radius
    local timer = (self.timers[unit.id] or 0) - dt

    if distance <= reach + 1e-6 then
        if timer <= 0 then
            local dealt = Base.apply_damage(em, base, attack.damage, team, unit.id)
            timer = timer + attack.interval
            if timer < 0 then
                timer = 0
            end
            self.stats.hits = self.stats.hits + 1
            self.stats.damage = self.stats.damage + dealt
            if kind == "shield" then
                self.stats.shield_hits = self.stats.shield_hits + 1
            else
                self.stats.core_hits = self.stats.core_hits + 1
            end
            table.insert(self.events, {
                type = "base_attacked",
                attacker = unit,
                team = team,
                defending_team = Unit.get_team_id(em, base),
                target = kind,
                amount = dealt
            })
        end
        if unit_data then
            unit_data.combat_state = "combat"
        end
    else
        -- Not in reach: the first hit comes as soon as it arrives.
        timer = math.max(0, timer)
        if self.march then
            local moveable = em:get_component(unit, "moveable")
            local speed = moveable and moveable.speed or 0
            local step = math.min(speed * dt, distance - reach)
            if step > 0 then
                Unit.set_position(em, unit, pos.x + dx / distance * step, pos.y + dy / distance * step)
                if unit_data then
                    unit_data.combat_state = "moving"
                end
            end
        end
    end
    self.timers[unit.id] = timer
end
-- }}}

-- {{{ BaseAssaultSystem:update
function BaseAssaultSystem:update(dt)
    local em = self.entity_manager
    local units = em:get_entities_with_components({"unit_data", "position", "team"})
    local seen = {}
    for _, unit in ipairs(units) do
        seen[unit.id] = true
        self:update_unit(unit, dt)
    end
    -- Forget removed units.
    for id in pairs(self.timers) do
        if not seen[id] then
            self.timers[id] = nil
        end
    end
end
-- }}}

-- {{{ BaseAssaultSystem:pop_events
function BaseAssaultSystem:pop_events()
    local events = self.events
    self.events = {}
    return events
end
-- }}}

-- {{{ BaseAssaultSystem:get_debug_info
function BaseAssaultSystem:get_debug_info()
    return {
        hits = self.stats.hits,
        damage = self.stats.damage,
        shield_hits = self.stats.shield_hits,
        core_hits = self.stats.core_hits
    }
end
-- }}}

return BaseAssaultSystem
-- }}}
