-- {{{ Buff ability
-- An ability that strengthens an ally for a while. Adds to the base
-- ability:
--   effect_name  what the effect is called on the target (default the
--                ability's name); a target that already has it is skipped
--   modifiers    stat changes as fractions, e.g. {attack = 0.25,
--                speed = 0.1} for +25% attack and +10% speed
--   duration     seconds (default 5)
--   max_stacks   how many times it can stack (default 1)
--   stacking     "refresh" (recasting resets the time) or "stack"
-- The debuff kind (debuff_ability.lua) is the same with harmful modifiers
-- and enemy targeting.
local Ability = require("src.components.ability")

-- {{{ local function effect_fields
local function effect_fields(default_modifiers)
    return function(ability, config)
        ability.effect_name = config.effect_name or ability.name
        ability.modifiers = config.modifiers or default_modifiers
        if ability.duration <= 0 then
            ability.duration = 5
        end
        ability.max_stacks = config.max_stacks or 1
        ability.stacking = config.stacking or "refresh"
        -- ManaEfficiency prices buffs as all or nothing; power only
        -- matters as the strength multiplier below.
        if config.power == nil and config.base_power == nil then
            ability.power = 1
        end
    end
end
-- }}}

local BuffAbility = Ability.extend("buff", effect_fields({attack = 0.25}))
BuffAbility.effect_fields = effect_fields

-- {{{ BuffAbility.calculate_modifiers
-- Shared by buffs and debuffs: the modifiers at the ability's strength
-- (power, scaling and the share of the bar spent).
function BuffAbility.calculate_modifiers(ability, share)
    local strength = ability.power * ability.scaling * (share or 1)
    local scaled = {}
    for stat, change in pairs(ability.modifiers) do
        scaled[stat] = change * strength
    end
    return {
        name = ability.effect_name,
        modifiers = scaled,
        duration = ability.duration,
        max_stacks = ability.max_stacks,
        stacking = ability.stacking,
        amount = strength
    }
end
-- }}}

-- {{{ BuffAbility:calculate_effect
function BuffAbility:calculate_effect(target, share, context)
    return BuffAbility.calculate_modifiers(self, share)
end
-- }}}

return BuffAbility
-- }}}
