-- {{{ Template constraints
-- The rules a unit template must keep (errors) and the ones it should
-- keep (warnings), for src/validators/template_validator.lua. Change a
-- number here and every template is judged by it; no rule is written
-- twice. Prices live separately in src/data/template_costs.lua.
--
-- Distances are in this game's units: melee reach is about 15 and ranged
-- about 30 (see src/data/ability_templates.lua).
local TemplateConstraints = {}

TemplateConstraints.name = {
    min_length = 3,
    max_length = 30,
    -- Letters, digits, spaces, hyphens, underscores and apostrophes.
    disallowed_pattern = "[^%w%s%-_']",
    max_description_length = 200
}

-- Hard limits (min, max) and the comfortable range a warning starts
-- outside (recommended_min, recommended_max).
TemplateConstraints.stats = {
    health = {min = 50, max = 500, recommended_min = 60, recommended_max = 300},
    speed = {min = 10, max = 150, recommended_min = 20, recommended_max = 100},
    armor = {min = 0, max = 40, recommended_min = 0, recommended_max = 20},
    magic_resist = {min = 0, max = 40, recommended_min = 0, recommended_max = 20},
    detection_range = {min = 30, max = 200, recommended_min = 40, recommended_max = 150}
}

TemplateConstraints.abilities = {
    min_count = 1,
    max_count = 4,
    -- The first ability is the always-charging primary: a basic attack
    -- or heal.
    primary_types = {damage = true, heal = true},
    max_power = 200,
    max_range = 100,
    max_area_radius = 50,
    max_duration = 30,
    max_cooldown = 60,
    min_mana_rate = 1,
    max_mana_rate = 50,
    max_over_time_duration = 20,
    max_zone_duration = 15,
    max_pierce = 5,
    max_cleave_targets = 3
}

TemplateConstraints.balance = {
    -- More than this many abilities of one kind earns a warning.
    max_same_kind = 2,
    -- Melee bodies with a damage ability reaching further than this, or
    -- ranged bodies with armor above this, earn a warning.
    melee_max_reach = 25,
    ranged_max_armor = 10,
    -- A template spending less than this share of its budget earns a
    -- warning that it may be underpowered.
    min_budget_share = 0.5
}

return TemplateConstraints
-- }}}
