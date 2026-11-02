-- {{{ Damage ability
-- An ability that hurts one enemy. Adds to the base ability:
--   damage_type          "physical" (armor reduces it), "magical" (magic
--                        resist reduces it) or "true" (nothing does)
--   armor_penetration    armor ignored by physical damage
--   critical_chance      0-1
--   critical_multiplier  damage times this on a critical hit (default 2)
--   weapon_type          a name for the weapon ("sword", "axe", "bow"...);
--                        the template's numbers carry its differences
--   cleave_targets       extra enemies a melee hit also strikes (default 0)
--   cleave_ratio         their share of the damage (default 0.7)
--   attack_arc           degrees, centred on the main target, that cleave
--                        reaches within the ability's range (default 90)
--   accuracy             0-1 chance a projectile hits each enemy it reaches
--                        (default 1, never misses)
--   drop_off_distance    beyond this distance a projectile weakens,
--                        reaching drop_off_min of its damage at the
--                        ability's range (default: no drop-off)
--   drop_off_min         default 0.7
local Ability = require("src.components.ability")

local DamageAbility = Ability.extend("damage", function(ability, config)
    ability.damage_type = config.damage_type or "physical"
    ability.armor_penetration = config.armor_penetration or 0
    ability.critical_chance = config.critical_chance or 0
    ability.critical_multiplier = config.critical_multiplier or 2.0
    ability.weapon_type = config.weapon_type
    ability.cleave_targets = config.cleave_targets or 0
    ability.cleave_ratio = config.cleave_ratio or 0.7
    ability.attack_arc = config.attack_arc or 90
    ability.accuracy = config.accuracy or 1
    ability.drop_off_distance = config.drop_off_distance
    ability.drop_off_min = config.drop_off_min or 0.7
end)

-- {{{ DamageAbility:drop_off_factor
-- 1 up to drop_off_distance, falling evenly to drop_off_min at the
-- ability's range and staying there beyond it.
function DamageAbility:drop_off_factor(distance)
    local start = self.drop_off_distance
    if not start or not distance or distance <= start then
        return 1
    end
    if self.range <= start then
        return self.drop_off_min
    end
    local along = math.min(1, (distance - start) / (self.range - start))
    return 1 - (1 - self.drop_off_min) * along
end
-- }}}

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
-- (armor, magic_resist; also read from target.stats), random (0-1),
-- distance (how far a projectile flew, for drop-off) and cleave (true
-- for a cleave hit, which takes cleave_ratio of the damage).
function DamageAbility:calculate_effect(target, share, context)
    context = context or {}
    local damage = self.power * self.scaling * (share or 1)
    if context.caster_stats and context.caster_stats.attack then
        damage = damage * context.caster_stats.attack
    end
    damage = damage * self:drop_off_factor(context.distance)
    if context.cleave then
        damage = damage * self.cleave_ratio
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
