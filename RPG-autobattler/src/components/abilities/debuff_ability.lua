-- {{{ Debuff ability
-- An ability that weakens an enemy for a while. The same settings as a
-- buff (see buff_ability.lua), aimed at enemies, with harmful modifiers:
-- by default -25% speed.
local Ability = require("src.components.ability")
local BuffAbility = require("src.components.abilities.buff_ability")

local DebuffAbility = Ability.extend("debuff", BuffAbility.effect_fields({speed = -0.25}))

-- {{{ DebuffAbility:calculate_effect
function DebuffAbility:calculate_effect(target, share, context)
    return BuffAbility.calculate_modifiers(self, share)
end
-- }}}

return DebuffAbility
-- }}}
