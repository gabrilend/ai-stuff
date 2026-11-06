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
local ManaSystem = {}

local Unit = require("src.entities.unit")
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

-- Below this speed (pixels per second) a unit counts as standing still.
ManaSystem.STILL_SPEED = 0.1
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

-- {{{ ManaSystem:is_standing_still
function ManaSystem:is_standing_still(entity)
    local moveable = self.entity_manager:get_component(entity, "moveable")
    if not moveable then
        return true
    end
    local vx, vy = moveable.velocity_x or 0, moveable.velocity_y or 0
    return vx * vx + vy * vy < ManaSystem.STILL_SPEED * ManaSystem.STILL_SPEED
end
-- }}}

-- {{{ ManaSystem:has_enemy_in_reach
function ManaSystem:has_enemy_in_reach(entity, reach)
    local em = self.entity_manager
    local position = em:get_component(entity, "position")
    if not position then
        return false
    end
    local team_id = Unit.get_team_id(em, entity)
    local reach_sq = reach * reach
    for _, other in ipairs(em:get_entities_with_components({"position", "health", "team"})) do
        if other ~= entity and Unit.get_team_id(em, other) ~= team_id and Unit.is_alive(em, other) then
            local other_pos = em:get_component(other, "position")
            local dx, dy = other_pos.x - position.x, other_pos.y - position.y
            if dx * dx + dy * dy <= reach_sq then
                return true
            end
        end
    end
    return false
end
-- }}}

-- {{{ ManaSystem:secondary_condition_met
-- Whether this unit's secondary bars charge right now.
function ManaSystem:secondary_condition_met(entity)
    local unit_type = Unit.get_unit_type(self.entity_manager, entity)
    if ManaSystem.get_style(unit_type) == "ranged" then
        return self:is_standing_still(entity)
    end
    return self:has_enemy_in_reach(entity, ManaSystem.REACH[unit_type] or ManaSystem.REACH.melee)
end
-- }}}

-- {{{ ManaSystem:update
function ManaSystem:update(dt)
    local em = self.entity_manager
    for _, entity in ipairs(em:get_entities_with_component("mana")) do
        if Unit.is_alive(em, entity) then
            self:update_unit(entity, dt)
        end
    end
end
-- }}}

-- {{{ ManaSystem:update_unit
function ManaSystem:update_unit(entity, dt)
    local mana = self.entity_manager:get_component(entity, "mana")
    -- Only work out the condition when some secondary bar could use it.
    local condition = nil
    for _, bar in ipairs(mana.bars) do
        local gains = bar.is_primary
        if not gains and bar.current < bar.max then
            if condition == nil then
                condition = self:secondary_condition_met(entity)
            end
            gains = condition
        end
        bar.charging = gains and bar.current < bar.max
        if bar.charging then
            bar.current = math.min(bar.max, bar.current + bar.rate * dt)
        end
    end
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
