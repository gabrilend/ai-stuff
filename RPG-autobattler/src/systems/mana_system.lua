-- {{{ ManaSystem
-- Fills each unit's mana bars, following the vision's rules:
--   * the primary ability (the first bar) always gains mana;
--   * the other abilities gain mana only when the unit's condition is met:
--       ranged-style units  while standing still (fighting, or waiting
--                           behind the front and unable to move up);
--       melee-style units   while an enemy is within their reach, moving
--                           or not.
-- A full bar stays full until an ability spends it (issue 048), so no mana
-- is generated past the top and none is lost while waiting for a target.
-- Issues 042 and 043 add: ranged units must have stood still for a quarter
-- of a second; secondary bars charge faster in combat (see BONUS); and a
-- dead unit's bars empty. docs/mana-generation-rules.md sets the rules out.
local ManaSystem = {}

local Unit = require("src.entities.unit")
local UnitAbilities = require("src.components.unit_abilities")
local Colors = require("src.constants.colors")
local debug = require("src.utils.debug")

-- {{{ Fighting styles and reach
-- Which rule a unit type's secondary bars follow. Support units stay back
-- and heal from a distance like ranged units; tanks and special units close
-- in like melee units.
ManaSystem.STYLE = {
    melee = "melee",
    tank = "melee",
    special = "melee",
    ranged = "ranged",
    support = "ranged"
}

-- How close an enemy must be for a melee-style unit to count as "in range".
-- These match the engagement ranges in combat_detection_system.lua.
ManaSystem.REACH = {
    melee = 12,
    tank = 15,
    special = 20
}

-- How far a ranged-style unit can shoot: an enemy this close while it
-- stands still means it is in combat. Matches combat_detection_system.lua.
ManaSystem.ATTACK_RANGE = {
    ranged = 30,
    support = 25
}

-- Below this speed (pixels per second) a unit counts as standing still,
-- and it must stay still this many seconds before ranged charging starts.
ManaSystem.STILL_SPEED = 0.1
ManaSystem.STILL_TIME = 0.25

-- Extra charging speed for the secondary bars (issues 042 and 043).
ManaSystem.BONUS = {
    ranged_in_combat = 0.2,     -- still, with an enemy in shooting range
    melee_outnumbered = 0.15    -- two or more enemies within reach
}
ManaSystem.OUTNUMBERED_COUNT = 2
-- }}}

-- {{{ Bar colors by ability type
-- Distinct hues so each kind of ability reads at a glance; drawing them is
-- issue 045.
ManaSystem.TYPE_COLORS = {
    damage = Colors.RED or {1, 0, 0, 1},
    heal = Colors.GREEN or {0, 1, 0, 1},
    buff = Colors.YELLOW or {1, 1, 0, 1},
    debuff = {0.7, 0.2, 1, 1},
    area = {1, 0.5, 0, 1}
}
-- }}}

-- {{{ ManaSystem:new
function ManaSystem:new(entity_manager)
    local system = {
        entity_manager = entity_manager,
        name = "mana_system"
    }
    setmetatable(system, {__index = ManaSystem})

    debug.info("ManaSystem created", "MANA")
    return system
end
-- }}}

-- {{{ ManaSystem.get_style
function ManaSystem.get_style(unit_type)
    return ManaSystem.STYLE[unit_type] or "melee"
end
-- }}}

-- {{{ ManaSystem:get_speed
function ManaSystem:get_speed(entity)
    local moveable = self.entity_manager:get_component(entity, "moveable")
    if not moveable then
        return 0
    end
    local vx, vy = moveable.velocity_x or 0, moveable.velocity_y or 0
    return math.sqrt(vx * vx + vy * vy)
end
-- }}}

-- {{{ ManaSystem:is_standing_still
-- True when the unit is not moving this frame (it may not yet have been
-- still long enough to charge; see STILL_TIME).
function ManaSystem:is_standing_still(entity)
    return self:get_speed(entity) < ManaSystem.STILL_SPEED
end
-- }}}

-- {{{ ManaSystem:snapshot_units
-- Every living unit's team and position, read once per update so each
-- unit's range checks do not query the entity manager again.
function ManaSystem:snapshot_units()
    local em = self.entity_manager
    local snapshot = {}
    for _, other in ipairs(em:get_entities_with_components({"position", "health", "team"})) do
        if Unit.is_alive(em, other) then
            local pos = em:get_component(other, "position")
            table.insert(snapshot, {entity = other, team = Unit.get_team_id(em, other), x = pos.x, y = pos.y})
        end
    end
    return snapshot
end
-- }}}

-- {{{ ManaSystem:count_enemies_within
function ManaSystem:count_enemies_within(entity, range, snapshot)
    local em = self.entity_manager
    local position = em:get_component(entity, "position")
    if not position then
        return 0
    end
    snapshot = snapshot or self:snapshot_units()
    local team_id = Unit.get_team_id(em, entity)
    local range_sq = range * range
    local count = 0
    for _, other in ipairs(snapshot) do
        if other.entity ~= entity and other.team ~= team_id then
            local dx, dy = other.x - position.x, other.y - position.y
            if dx * dx + dy * dy <= range_sq then
                count = count + 1
            end
        end
    end
    return count
end
-- }}}

-- {{{ ManaSystem:has_enemy_in_reach
function ManaSystem:has_enemy_in_reach(entity, reach, snapshot)
    return self:count_enemies_within(entity, reach, snapshot) > 0
end
-- }}}

-- {{{ ManaSystem:secondary_state
-- How this unit's secondary bars charge right now. Returns the rate
-- multiplier (0 when the condition is not met) and a short reason, used
-- for debugging and the bars' drawing:
--   ranged-style  still for STILL_TIME          x1.0  "still"
--                 ...with an enemy in range     x1.2  "still, in combat"
--   melee-style   one enemy within reach        x1.0  "enemy in reach"
--                 two or more                   x1.15 "outnumbered"
function ManaSystem:secondary_state(entity, mana, snapshot)
    local unit_type = Unit.get_unit_type(self.entity_manager, entity)
    if ManaSystem.get_style(unit_type) == "ranged" then
        if (mana.still_time or 0) < ManaSystem.STILL_TIME then
            return 0, "moving"
        end
        local range = ManaSystem.ATTACK_RANGE[unit_type] or ManaSystem.ATTACK_RANGE.ranged
        if self:count_enemies_within(entity, range, snapshot) > 0 then
            return 1 + ManaSystem.BONUS.ranged_in_combat, "still, in combat"
        end
        return 1, "still"
    end

    local reach = ManaSystem.REACH[unit_type] or ManaSystem.REACH.melee
    local enemies = self:count_enemies_within(entity, reach, snapshot)
    if enemies >= ManaSystem.OUTNUMBERED_COUNT then
        return 1 + ManaSystem.BONUS.melee_outnumbered, "outnumbered"
    elseif enemies > 0 then
        return 1, "enemy in reach"
    end
    return 0, "no enemy in reach"
end
-- }}}

-- {{{ ManaSystem:secondary_condition_met
-- Whether this unit's secondary bars charge right now.
function ManaSystem:secondary_condition_met(entity, snapshot)
    local mana = self.entity_manager:get_component(entity, "mana") or {still_time = math.huge}
    return (self:secondary_state(entity, mana, snapshot)) > 0
end
-- }}}

-- {{{ ManaSystem:update
function ManaSystem:update(dt)
    local em = self.entity_manager
    local snapshot = nil
    for _, entity in ipairs(em:get_entities_with_component("mana")) do
        if Unit.is_alive(em, entity) then
            snapshot = snapshot or self:snapshot_units()
            self:update_unit(entity, dt, snapshot)
        else
            ManaSystem.empty_bars(em:get_component(entity, "mana"))
        end
    end
end
-- }}}

-- {{{ ManaSystem:update_unit
function ManaSystem:update_unit(entity, dt, snapshot)
    local mana = self.entity_manager:get_component(entity, "mana")

    -- Time spent standing still. Only the part of this frame after the
    -- unit has been still for STILL_TIME counts toward ranged charging, so
    -- a unit that pauses for a moment while walking gains nothing.
    local still_before = mana.still_time or 0
    if self:is_standing_still(entity) then
        mana.still_time = still_before + dt
    else
        mana.still_time = 0
    end

    local multiplier, reason = nil, nil
    local abilities = self.entity_manager:get_component(entity, "abilities")
    local unit_state = nil
    for index, bar in ipairs(mana.bars) do
        local gain_time, rate = 0, bar.rate
        if bar.is_primary then
            gain_time = dt
        elseif bar.current < bar.max then
            if multiplier == nil then
                multiplier, reason = self:secondary_state(entity, mana, snapshot)
                mana.secondary_reason = reason
                mana.secondary_multiplier = multiplier
            end
            if multiplier > 0 then
                rate = bar.rate * multiplier
                local style = ManaSystem.get_style(Unit.get_unit_type(self.entity_manager, entity))
                if style == "ranged" then
                    gain_time = math.min(dt, mana.still_time - ManaSystem.STILL_TIME)
                else
                    gain_time = dt
                end
            end
        end
        -- An ability may add its own generation conditions on top of
        -- these rules (src/components/ability.lua).
        if gain_time > 0 and abilities and abilities.abilities[index]
            and #abilities.abilities[index].generation_conditions > 0 then
            unit_state = unit_state or UnitAbilities.unit_state(self.entity_manager, entity, snapshot)
            if not abilities.abilities[index]:can_generate_mana(unit_state) then
                gain_time = 0
            end
        end
        bar.charging = gain_time > 0 and bar.current < bar.max
        if bar.charging then
            bar.current = math.min(bar.max, bar.current + rate * gain_time)
        end
    end
end
-- }}}

-- {{{ ManaSystem.empty_bars
-- A dead unit loses all its mana, so a revived unit starts from nothing.
function ManaSystem.empty_bars(mana)
    if not mana then
        return
    end
    for _, bar in ipairs(mana.bars) do
        bar.current = 0
        bar.charging = false
    end
    mana.still_time = 0
end
-- }}}

-- {{{ ManaSystem.is_full
function ManaSystem.is_full(mana, index)
    local bar = mana.bars[index]
    return bar ~= nil and bar.current >= bar.max
end
-- }}}

-- {{{ ManaSystem.get_fraction
function ManaSystem.get_fraction(mana, index)
    local bar = mana.bars[index]
    if not bar then
        return 0
    end
    return bar.current / bar.max
end
-- }}}

-- {{{ ManaSystem.spend
-- Removes up to `amount` mana from a bar and returns what was removed.
-- Abilities that need only part of their bar (issue 044) spend just that.
function ManaSystem.spend(mana, index, amount)
    local bar = mana.bars[index]
    if not bar or amount <= 0 then
        return 0
    end
    local spent = math.min(amount, bar.current)
    bar.current = bar.current - spent
    return spent
end
-- }}}

-- {{{ ManaSystem.get_bar_color
function ManaSystem.get_bar_color(mana, index)
    local bar = mana.bars[index]
    return ManaSystem.TYPE_COLORS[bar and bar.type] or {1, 1, 1, 1}
end
-- }}}

return ManaSystem
-- }}}
