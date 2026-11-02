-- {{{ Mana component
-- Creates a mana component: one mana bar for each of a unit's abilities.
-- A unit has between one and four abilities; the first is its primary.
-- abilities is a list of tables, each with:
--   name       a label for the bar
--   type       "damage", "heal", "buff", "debuff" or "area"; sets the bar color
--   max_mana   how much mana fills the bar (default 100)
--   mana_rate  mana gained per second while the bar is charging (default 10)
-- Bars start empty. src/systems/mana_system.lua fills them.
return function(abilities)
    abilities = abilities or {}
    if #abilities < 1 or #abilities > 4 then
        error("A unit needs between 1 and 4 abilities, got " .. #abilities)
    end

    local bars = {}
    for index, ability in ipairs(abilities) do
        local max_mana = ability.max_mana or 100
        if max_mana <= 0 then
            error("Ability " .. index .. " needs a positive max_mana")
        end
        bars[index] = {
            name = ability.name or ("ability_" .. index),
            type = ability.type or "damage",
            is_primary = index == 1,
            current = 0,
            max = max_mana,
            rate = ability.mana_rate or 10,
            charging = false   -- whether the bar gained mana last update
        }
    end

    return {
        bars = bars
    }
end
-- }}}
