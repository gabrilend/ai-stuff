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
    -- The sword and the bow are the defaults; the other weapons trade
    -- reach, speed (mana_rate) and power against each other. Melee
    -- reach sits near 15 and ranged near 30, matching the base assault
    -- reaches in src/systems/base_assault_system.lua. Melee strikes the
    -- closest enemy; ranged weapons pick the weakest one they can see, to
    -- finish kills.
    primary_melee_attack = {
        type = "damage", weapon_type = "sword", range = 15, power = 25, max_mana = 100, mana_rate = 10,
        damage_type = "physical",
        visual_effect = "melee_slash", sound_effect = "sword_hit"
    },
    primary_ranged_attack = {
        type = "damage", weapon_type = "bow", target_priority = "weakest", delivery = "projectile", projectile_speed = 150,
        range = 30, power = 20, max_mana = 100, mana_rate = 10,
        accuracy = 0.95, drop_off_distance = 20,
        damage_type = "physical",
        visual_effect = "arrow_shot", sound_effect = "bow_release"
    },
    axe_attack = {
        type = "damage", weapon_type = "axe", range = 13, power = 32, max_mana = 100, mana_rate = 8,
        cleave_targets = 1, attack_arc = 120,
        damage_type = "physical",
        visual_effect = "axe_swing", sound_effect = "axe_hit"
    },
    dagger_attack = {
        type = "damage", weapon_type = "dagger", range = 12, power = 18, max_mana = 100, mana_rate = 14,
        critical_chance = 0.15, critical_multiplier = 2,
        damage_type = "physical",
        visual_effect = "dagger_stab", sound_effect = "dagger_hit"
    },
    spear_attack = {
        type = "damage", weapon_type = "spear", range = 20, power = 22, max_mana = 100, mana_rate = 10,
        cleave_targets = 1, attack_arc = 20, cleave_ratio = 0.5,
        damage_type = "physical",
        visual_effect = "spear_thrust", sound_effect = "spear_hit"
    },
    crossbow_attack = {
        type = "damage", weapon_type = "crossbow", target_priority = "weakest", delivery = "projectile", projectile_speed = 200,
        range = 34, power = 28, max_mana = 100, mana_rate = 7,
        accuracy = 0.98, drop_off_distance = 26, armor_penetration = 5,
        damage_type = "physical",
        visual_effect = "bolt_shot", sound_effect = "crossbow_release"
    },
    sling_attack = {
        type = "damage", weapon_type = "sling", target_priority = "weakest", delivery = "projectile", projectile_speed = 180,
        range = 24, power = 16, max_mana = 100, mana_rate = 13,
        accuracy = 0.9, drop_off_distance = 14,
        damage_type = "physical",
        visual_effect = "stone_shot", sound_effect = "sling_release"
    },
    javelin_attack = {
        type = "damage", weapon_type = "javelin", target_priority = "weakest", delivery = "projectile", projectile_speed = 110,
        range = 20, power = 30, max_mana = 100, mana_rate = 8,
        accuracy = 0.9, drop_off_distance = 12,
        damage_type = "physical",
        visual_effect = "javelin_throw", sound_effect = "javelin_whoosh"
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
    emergency_heal = {
        type = "heal", range = 30, power = 50, max_mana = 100, mana_rate = 8,
        bonus_low_health = 1.0,
        cooldown = 5,
        generation_conditions = {{type = "allies_in_range", operator = ">", value = 0}},
        activation_conditions = {{type = "ally_health_below", value = 30}},
        visual_effect = "emergency_light", sound_effect = "urgent_chime"
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
        -- Charges while an enemy is near. (It once waited for combat
        -- state "combat", which no system sets, so it never fired.)
        generation_conditions = {{type = "enemies_in_range", operator = ">", value = 0, range = 40}},
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
    weakness_curse = {
        type = "debuff", range = 30, max_mana = 100, mana_rate = 4, duration = 8,
        effect_name = "weakened", modifiers = {attack = -0.3, healing_power = -0.3},
        generation_conditions = {{type = "enemies_in_range", operator = ">", value = 0}},
        visual_effect = "curse", sound_effect = "whisper"
    },
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
    static_field = {
        type = "area", area_effect = "damage", range = 40, area_radius = 30,
        power = 8, max_mana = 100, mana_rate = 4, max_targets = 6,
        cooldown = 8, shared_cooldown = "spell",
        damage_type = "magical",
        zone_duration = 6, zone_interval = 1, zone_power = 6,
        zone_modifiers = {speed = -0.4}, zone_effect_name = "static_slow",
        generation_conditions = {{type = "enemies_in_range", operator = ">=", value = 2}},
        visual_effect = "static_field", sound_effect = "crackle"
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
    skirmisher = {"primary_ranged_attack", "poison_dart", "piercing_shot"},
    berserker = {"axe_attack", "battle_fury"},
    crossbowman = {"crossbow_attack", "piercing_shot"},
    field_medic = {"primary_melee_attack", "emergency_heal", "regeneration"},
    storm_caller = {"primary_ranged_attack", "static_field", "weakness_curse"}
}

return AbilityTemplates
-- }}}
