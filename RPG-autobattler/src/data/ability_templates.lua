-- {{{ Ability templates
-- Ready-made ability settings by name, for src/factories/ability_factory.lua
-- to build abilities from. Field names are those of
-- src/components/ability.lua and its kinds. Numbers are first guesses
-- for balancing in play.
--
-- Health percentages are 0-100. Unit health is 80-200 (see
-- Unit.get_unit_base_health), and a bar of 100 mana at 10 a second
-- fills in ten seconds.
local AbilityTemplates = {}

AbilityTemplates.abilities = {
    -- {{{ Primary abilities
    primary_melee_attack = {
        type = "damage", range = 15, power = 25, max_mana = 100, mana_rate = 10,
        damage_type = "physical",
        visual_effect = "melee_slash", sound_effect = "sword_hit"
    },
    primary_ranged_attack = {
        type = "damage", delivery = "projectile", projectile_speed = 150,
        range = 30, power = 20, max_mana = 100, mana_rate = 10,
        damage_type = "physical",
        visual_effect = "arrow_shot", sound_effect = "bow_release"
    },
    -- }}}

    -- {{{ Damage
    power_strike = {
        type = "damage", range = 15, power = 45, max_mana = 100, mana_rate = 8,
        damage_type = "physical", critical_chance = 0.3, critical_multiplier = 2.5,
        generation_conditions = {{type = "enemies_in_range", operator = ">", value = 0}},
        visual_effect = "power_strike", sound_effect = "heavy_hit"
    },
    piercing_shot = {
        type = "damage", delivery = "projectile", projectile_speed = 200, pierce = 3,
        range = 40, power = 35, max_mana = 100, mana_rate = 8,
        damage_type = "physical", armor_penetration = 10,
        generation_conditions = {{type = "is_stationary", value = true}},
        visual_effect = "piercing_arrow", sound_effect = "pierce_shot"
    },
    -- }}}

    -- {{{ Healing
    minor_heal = {
        type = "heal", range = 30, power = 30, max_mana = 100, mana_rate = 6,
        bonus_low_health = 0.5,
        generation_conditions = {{type = "allies_in_range", operator = ">", value = 0}},
        visual_effect = "healing_light", sound_effect = "heal_cast"
    },
    regeneration = {
        type = "heal", range = 25, power = 10, max_mana = 100, mana_rate = 5,
        heal_over_time = 6, over_time_duration = 8, over_time_interval = 1,
        cooldown = 4,
        generation_conditions = {{type = "allies_in_range", operator = ">", value = 0}},
        visual_effect = "regeneration_aura", sound_effect = "regen_cast"
    },
    purifying_touch = {
        type = "heal", range = 20, power = 15, max_mana = 100, mana_rate = 5,
        cleanse = true,
        visual_effect = "purify", sound_effect = "chime"
    },
    -- }}}

    -- {{{ Buffs
    battle_fury = {
        type = "buff", range = 20, max_mana = 100, mana_rate = 4, duration = 12,
        effect_name = "battle_fury", stacking = "stack", max_stacks = 3,
        modifiers = {attack = 0.25},
        generation_conditions = {{type = "combat_state", value = "combat"}},
        visual_effect = "fury_aura", sound_effect = "buff_cast"
    },
    protective_ward = {
        type = "buff", range = 30, max_mana = 100, mana_rate = 4, duration = 15,
        effect_name = "protective_ward",
        modifiers = {}, flat_modifiers = {armor = 10, magic_resist = 8},
        generation_conditions = {{type = "allies_in_range", operator = ">=", value = 2}},
        visual_effect = "protective_shield", sound_effect = "ward_cast"
    },
    focus = {
        type = "buff", targeting = "self", max_mana = 100, mana_rate = 3, duration = 10,
        effect_name = "focus", modifiers = {}, flat_modifiers = {cooldown_reduction = 0.3},
        visual_effect = "focus_glow", sound_effect = "hum"
    },
    -- }}}

    -- {{{ Debuffs
    poison_dart = {
        type = "damage", delivery = "projectile", projectile_speed = 180,
        range = 30, power = 8, max_mana = 100, mana_rate = 7,
        damage_type = "true", damage_over_time = 4, over_time_duration = 5, over_time_interval = 1,
        visual_effect = "poison_dart", sound_effect = "blowpipe"
    },
    crippling_blow = {
        type = "debuff", range = 15, max_mana = 100, mana_rate = 5, duration = 4,
        effect_name = "crippled", modifiers = {speed = -0.4},
        visual_effect = "cripple", sound_effect = "thud"
    },
    stunning_bash = {
        type = "debuff", range = 15, max_mana = 100, mana_rate = 3, duration = 1.5,
        effect_name = "stunned", modifiers = {}, stun = true,
        visual_effect = "stars", sound_effect = "clang"
    },
    sunder_armor = {
        type = "debuff", range = 20, max_mana = 100, mana_rate = 5, duration = 8,
        effect_name = "sundered", modifiers = {}, flat_modifiers = {armor = -20},
        visual_effect = "crack", sound_effect = "shatter"
    },
    -- }}}

    -- {{{ Area
    meteor_strike = {
        type = "area", area_effect = "damage", range = 45, area_radius = 35,
        power = 40, max_mana = 100, mana_rate = 3, max_targets = 3,
        cooldown = 6, shared_cooldown = "spell",
        damage_type = "magical",
        generation_conditions = {{type = "enemies_in_range", operator = ">=", value = 2}},
        visual_effect = "meteor_impact", sound_effect = "explosion"
    },
    healing_circle = {
        type = "area", area_effect = "heal", range = 25, area_radius = 40,
        power = 25, max_mana = 100, mana_rate = 4, max_targets = 4,
        cooldown = 6, shared_cooldown = "spell",
        generation_conditions = {{type = "allies_in_range", operator = ">=", value = 2}},
        visual_effect = "healing_wave", sound_effect = "group_heal"
    }
    -- }}}
}

-- Sets of templates for a unit, primary first.
AbilityTemplates.sets = {
    basic_warrior = {"primary_melee_attack", "power_strike"},
    basic_archer = {"primary_ranged_attack", "piercing_shot"},
    support_cleric = {"primary_melee_attack", "minor_heal", "protective_ward"},
    battle_mage = {"primary_ranged_attack", "meteor_strike", "battle_fury"},
    brute = {"primary_melee_attack", "stunning_bash", "crippling_blow", "sunder_armor"},
    druid = {"primary_ranged_attack", "regeneration", "healing_circle", "focus"},
    skirmisher = {"primary_ranged_attack", "poison_dart", "piercing_shot"}
}

return AbilityTemplates
-- }}}
