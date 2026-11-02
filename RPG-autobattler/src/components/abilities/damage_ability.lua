-- {{{ Damage ability
-- An ability that hurts one enemy. Adds to the base ability:
--   damage_type          "physical" (armor reduces it), "magical" (magic
--                        resist reduces it) or "true" (nothing does)
--   armor_penetration    armor ignored by physical damage
--   critical_chance      0-1
--   critical_multiplier  damage times this on a critical hit (default 2)
local Ability = require("src.components.ability")

local DamageAbility = Ability.extend("damage", function(ability, config)
    ability.damage_type = config.damage_type or "physical"
    ability.armor_penetration = config.armor_penetration or 0
    ability.critical_chance = config.critical_chance or 0
    ability.critical_multiplier = config.critical_multiplier or 2.0
end)

-- {{{ DamageAbility.reduce
-- Damage left after the target's armor or magic resist: each point of
-- defence takes away a little less than the last (defence / (defence +
-- 100) of the damage), so no amount of armor makes a unit immune.
function DamageAbility.reduce(damage, damage_type, penetration, target_stats)
    if not target_stats or damage_type == "true" then
        return damage
    end
    local defence
    if damage_type == "magical" then
        defence = target_stats.magic_resist or 0
    else
        defence = math.max(0, (target_stats.armor or 0) - (penetration or 0))
    end
    return damage * (1 - defence / (defence + 100))
end
-- }}}

-- {{{ DamageAbility:calculate_effect
-- context: caster_stats.attack (a multiplier, default 1), target_stats
-- (armor, magic_resist; also read from target.stats), random (0-1).
function DamageAbility:calculate_effect(target, share, context)
    context = context or {}
    local damage = self.power * self.scaling * (share or 1)
    if context.caster_stats and context.caster_stats.attack then
        damage = damage * context.caster_stats.attack
    end

    local is_critical = false
    if self.critical_chance > 0 then
        local roll = (context.random or math.random)()
        is_critical = roll < self.critical_chance
        if is_critical then
            damage = damage * self.critical_multiplier
        end
    end

    local target_stats = context.target_stats or (target and target.stats)
    local final = DamageAbility.reduce(damage, self.damage_type, self.armor_penetration, target_stats)
    return {
        amount = final,
        before_defence = damage,
        is_critical = is_critical,
        damage_type = self.damage_type
    }
end
-- }}}

return DamageAbility
-- }}}
