-- {{{ Area ability
-- An ability that affects every target within a circle. Adds to the base
-- ability:
--   area_effect   "damage" (default) or "heal"
--   area_radius   the circle's radius (default 30)
--   falloff       0-1: how much weaker the effect is at the edge than at
--                 the centre (default 0.5, half strength at the edge)
--   damage_type   as for damage abilities, when area_effect is "damage"
-- A lasting zone (needs a PersistentEffectsSystem):
--   zone_duration         seconds the circle stays after the cast
--                         (default 0, no zone)
--   zone_interval         seconds between the zone's pulses (default 1)
--   zone_power            damage or healing per pulse to each unit inside
--   zone_modifiers,       an effect each pulse puts on the units inside,
--   zone_flat_modifiers   as for buffs and debuffs (a slow, say); it lasts
--                         zone_effect_duration (default a pulse and a half)
--                         so it fades soon after a unit walks out
--   zone_effect_name      the effect's name (default the ability's + "_zone")
-- `power` is the effect on each target at a full bar.
local Ability = require("src.components.ability")
local DamageAbility = require("src.components.abilities.damage_ability")

local AreaAbility = Ability.extend("area", function(ability, config)
    ability.area_effect = config.area_effect or "damage"
    if ability.area_radius <= 0 then
        ability.area_radius = 30
    end
    ability.falloff = config.falloff or 0.5
    ability.damage_type = config.damage_type or "magical"
    ability.armor_penetration = config.armor_penetration or 0
    ability.zone_duration = config.zone_duration or 0
    ability.zone_interval = config.zone_interval or 1
    ability.zone_power = config.zone_power or 0
    ability.zone_modifiers = config.zone_modifiers
    ability.zone_flat_modifiers = config.zone_flat_modifiers
    ability.zone_effect_duration = config.zone_effect_duration or ability.zone_interval * 1.5
    ability.zone_effect_name = config.zone_effect_name or (ability.name .. "_zone")
end)

-- {{{ AreaAbility:distance_factor
-- 1 at the centre, 1 - falloff at the edge, 0 outside.
function AreaAbility:distance_factor(distance)
    if distance == nil then
        return 1
    end
    if distance > self.area_radius then
        return 0
    end
    return 1 - self.falloff * (distance / self.area_radius)
end
-- }}}

-- {{{ AreaAbility:calculate_effect
-- context.distance is the target's distance from the circle's centre.
function AreaAbility:calculate_effect(target, share, context)
    context = context or {}
    local amount = self.power * self.scaling * (share or 1) * self:distance_factor(context.distance)
    if self.area_effect == "heal" then
        local missing = target and math.max(0, target.max_health - target.current_health) or amount
        return {amount = math.min(amount, missing), overheal = math.max(0, amount - missing), effect = "heal"}
    end
    local target_stats = context.target_stats or (target and target.stats)
    return {
        amount = DamageAbility.reduce(amount, self.damage_type, self.armor_penetration, target_stats),
        before_defence = amount,
        damage_type = self.damage_type,
        effect = "damage"
    }
end
-- }}}

return AreaAbility
-- }}}
