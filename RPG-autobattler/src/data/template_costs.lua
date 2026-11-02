-- {{{ Template costs
-- What each part of a unit template costs, in points, for
-- src/data/unit_template.lua. Every template has a budget (100 by
-- default); a template over budget isn't valid. These are first guesses
-- for issue 058 (point-based balancing) to tune.
--
-- Stats are priced against the chosen body's own values (from
-- src/entities/unit.lua), so a tank's 200 health is free and only what a
-- player adds costs points. Lowering a stat below the body's value gives
-- no points back.
local TemplateCosts = {}

TemplateCosts.default_point_budget = 100

-- Each body's starting stats, and what choosing it costs.
TemplateCosts.bodies = {
    melee = {health = 120, speed = 60, armor = 0, magic_resist = 0, detection_range = 60, cost = 0},
    ranged = {health = 80, speed = 45, armor = 0, magic_resist = 0, detection_range = 80, cost = 10},
    tank = {health = 200, speed = 30, armor = 5, magic_resist = 0, detection_range = 50, cost = 10},
    support = {health = 60, speed = 50, armor = 0, magic_resist = 5, detection_range = 70, cost = 0},
    special = {health = 100, speed = 70, armor = 0, magic_resist = 0, detection_range = 70, cost = 10}
}

-- Points per unit of a stat above the body's value. The stats' allowed
-- ranges are in src/data/template_constraints.lua.
TemplateCosts.stats = {
    health = {per_unit = 0.1},          -- 1 point per 10 health
    speed = {per_unit = 0.2},           -- 1 point per 5 speed
    armor = {per_unit = 1.5},           -- 3 points per 2 armor
    magic_resist = {per_unit = 1.5},
    detection_range = {per_unit = 0.05} -- 1 point per 20 range
}

-- Abilities. An ability's cost is its base (the first ability, the
-- primary, is cheaper) times how strong it is next to a reference
-- ability, plus reach and area extras. See UnitTemplate.ability_cost.
TemplateCosts.abilities = {
    primary_base = 10,
    secondary_base = 20,
    -- Effect per second at a steady charge that counts as strength 1:
    -- the sword's 25 power every 10 seconds.
    reference_throughput = 2.5,
    -- Seconds of effect per second of charge that count as strength 1
    -- for buffs and debuffs: battle fury's 12 seconds every 25.
    reference_uptime = 0.48,
    reach_base = 15,          -- reach up to this is free
    per_reach = 0.2,          -- then 1 point per 5
    per_area_radius = 0.1,    -- 1 point per 10 radius
    pierce_share = 0.5,       -- each extra enemy pierced adds half again
    zone_share = 1.0          -- a zone's pulses count in full
}

return TemplateCosts
-- }}}
