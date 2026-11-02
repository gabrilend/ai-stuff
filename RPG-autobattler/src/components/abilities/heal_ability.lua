-- {{{ Heal ability
-- An ability that restores an ally's health. Adds to the base ability:
--   bonus_low_health  extra healing (0.5 = +50%) on a target under half
--                     health
--   self_heal_ratio   the caster also heals this share of what it healed
--   cleanse           true to also remove the target's debuffs
local Ability = require("src.components.ability")

local HealAbility = Ability.extend("heal", function(ability, config)
    ability.bonus_low_health = config.bonus_low_health or 0
    ability.self_heal_ratio = config.self_heal_ratio or 0
    ability.cleanse = config.cleanse or config.cleanse_debuffs or false
end)

-- {{{ HealAbility:calculate_effect
-- Never heals past full: what would go past is reported as overheal.
-- context: caster_stats.healing_power (a multiplier, default 1).
function HealAbility:calculate_effect(target, share, context)
    context = context or {}
    local healing = self.power * self.scaling * (share or 1)
    if context.caster_stats and context.caster_stats.healing_power then
        healing = healing * context.caster_stats.healing_power
    end
    if target and target.max_health and target.max_health > 0
        and target.current_health / target.max_health < 0.5 then
        healing = healing * (1 + self.bonus_low_health)
    end

    local missing = target and math.max(0, target.max_health - target.current_health) or healing
    local effective = math.min(healing, missing)
    return {
        amount = effective,
        overheal = healing - effective,
        self_heal = effective * self.self_heal_ratio,
        cleanse = self.cleanse
    }
end
-- }}}

return HealAbility
-- }}}
