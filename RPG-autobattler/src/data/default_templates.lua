-- {{{ Default templates
-- The unit templates that come with the game, in sets, as data for
-- UnitTemplate.new (src/data/unit_template.lua). Abilities are names
-- from src/data/ability_templates.lua. Every template here must pass
-- validation with no errors, fit the 100-point budget, and (outside the
-- experimental set) draw no warnings except where `expected_warnings`
-- names one; tests/test_default_templates.lua holds them to that.
--
-- Sets, in the order a new player would meet them:
--   starter       one per ability set: the plainest way to field each
--   advanced      three abilities working together
--   specialist    one trick done well
--   experimental  stats pushed to an edge on purpose; warnings expected
--   showcase      everything at once: four abilities
--
-- Each template also names its archetype (tank, damage, ranged_damage,
-- support, crowd_control, hybrid, speed, glass_cannon) and a line of
-- strategy for the guide (docs/default-templates.md).
local DefaultTemplates = {}

DefaultTemplates.SET_ORDER = {"starter", "advanced", "specialist", "experimental", "showcase"}

DefaultTemplates.SET_DESCRIPTIONS = {
    starter = "One template per ability set: the plainest way to field each.",
    advanced = "Three abilities that work together.",
    specialist = "One trick, done well.",
    experimental = "Stats pushed to an edge on purpose. These draw warnings by design.",
    showcase = "Everything at once: four abilities on one unit."
}

DefaultTemplates.sets = {
    -- {{{ starter
    starter = {
        {name = "Warrior", unit_type = "melee", archetype = "damage", ability_set = "basic_warrior",
            stats = {armor = 4},
            abilities = {"primary_melee_attack", "power_strike"},
            description = "Sword and power strike; holds the line.",
            strategy = "Put it in front. Power strike charges only with an enemy in reach, so it pays to close in."},
        {name = "Archer", unit_type = "ranged", archetype = "ranged_damage", ability_set = "basic_archer",
            abilities = {"primary_ranged_attack", "piercing_shot"},
            description = "Bow and piercing shot; fights from range while standing still.",
            strategy = "Keep it behind a front line; piercing shot charges only while it stands still."},
        {name = "Cleric", unit_type = "support", archetype = "support", ability_set = "support_cleric",
            stats = {health = 80},
            abilities = {"primary_melee_attack", "minor_heal", "protective_ward"},
            description = "Heals the weakest ally and wards a group.",
            strategy = "Field it with two or more allies nearby, or the ward never charges."},
        {name = "Battle Mage", unit_type = "special", archetype = "damage", ability_set = "battle_mage",
            abilities = {"primary_ranged_attack", "meteor_strike", "battle_fury"},
            description = "Meteors on clumped enemies; stirs allies to fury.",
            strategy = "Best against crowds: meteor strike waits for two enemies in reach."},
        {name = "Brute", unit_type = "tank", archetype = "crowd_control", ability_set = "brute",
            abilities = {"primary_melee_attack", "stunning_bash", "crippling_blow", "sunder_armor"},
            expected_warnings = {"3 debuff abilities"},
            description = "Stuns, cripples and sunders the armor of what it hits.",
            strategy = "A debuff specialist: it softens one target for everyone else to finish."},
        {name = "Druid", unit_type = "support", archetype = "support", ability_set = "druid",
            abilities = {"primary_ranged_attack", "regeneration", "healing_circle", "focus"},
            description = "Regeneration and healing circles from range.",
            strategy = "Heals over time; it shines in long fights, not quick ones."},
        {name = "Skirmisher", unit_type = "ranged", archetype = "ranged_damage", ability_set = "skirmisher",
            stats = {speed = 55},
            abilities = {"primary_ranged_attack", "poison_dart", "piercing_shot"},
            description = "Poison darts and piercing shots.",
            strategy = "Poison ticks through armor: use it against tanks."},
        {name = "Berserker", unit_type = "melee", archetype = "damage", ability_set = "berserker",
            stats = {health = 170, speed = 70, armor = 4},
            abilities = {"axe_attack", "battle_fury"},
            description = "A cleaving axe and battle fury.",
            strategy = "The axe cleaves a second enemy: send it where enemies bunch up."},
        {name = "Crossbowman", unit_type = "ranged", archetype = "ranged_damage", ability_set = "crossbowman",
            abilities = {"crossbow_attack", "piercing_shot"},
            description = "Slow, heavy, accurate bolts.",
            strategy = "Out-ranges the other archers; bolts pierce some armor."},
        {name = "Field Medic", unit_type = "support", archetype = "support", ability_set = "field_medic",
            abilities = {"primary_melee_attack", "emergency_heal", "regeneration"},
            description = "Emergency heals for allies near death.",
            strategy = "Its big heal waits for an ally below 30%; it saves units rather than topping them up."},
        {name = "Storm Caller", unit_type = "special", archetype = "crowd_control", ability_set = "storm_caller",
            abilities = {"primary_ranged_attack", "static_field", "weakness_curse"},
            description = "Static fields that slow and burn; curses that weaken.",
            strategy = "Lay a field where enemies must walk; slowed enemies stay in it longer."}
    },
    -- }}}

    -- {{{ advanced
    advanced = {
        {name = "Heavy Knight", unit_type = "tank", archetype = "tank",
            stats = {health = 240, armor = 10},
            abilities = {"axe_attack", "sunder_armor", "protective_ward"},
            description = "Armored axe-bearer that cracks armor and wards its line.",
            strategy = "Lead with it: it takes the first blows, sunders the toughest enemy and wards those behind."},
        {name = "Sniper", unit_type = "ranged", archetype = "ranged_damage",
            stats = {detection_range = 150},
            abilities = {"crossbow_attack", "piercing_shot", "focus"},
            description = "Long sight and heavy bolts; focus shortens its cooldowns.",
            strategy = "Give it a guard: it is slow, frail and deadly once set."},
        {name = "Battle Cleric", unit_type = "support", archetype = "hybrid",
            stats = {health = 100, armor = 4},
            abilities = {"primary_melee_attack", "emergency_heal", "purifying_touch"},
            description = "Fights in the line, saves those beside it and cleanses their debuffs.",
            strategy = "A healer that can stand at the front: armor and health let it stay near the wounded."}
    },
    -- }}}

    -- {{{ specialist
    specialist = {
        {name = "Assassin", unit_type = "special", archetype = "damage",
            stats = {speed = 85},
            abilities = {"dagger_attack", "poison_dart", "crippling_blow"},
            description = "Quick dagger, poison and a crippling blow.",
            strategy = "Fast enough to reach the back line; crippled targets can't run."},
        {name = "Frost Mage", unit_type = "special", archetype = "crowd_control",
            abilities = {"primary_ranged_attack", "static_field", "crippling_blow"},
            description = "Slows everything: a slowing field, and a crippling blow up close.",
            strategy = "Hold the enemy where your archers can reach them."},
        {name = "Spearman", unit_type = "melee", archetype = "damage",
            stats = {health = 180, armor = 10, magic_resist = 4, speed = 70},
            abilities = {"spear_attack", "crippling_blow"},
            description = "Long reach; the spear runs through to the enemy behind.",
            strategy = "Strikes from second rank: put it just behind another melee unit."}
    },
    -- }}}

    -- {{{ experimental
    experimental = {
        {name = "Glass Cannon", unit_type = "ranged", archetype = "glass_cannon",
            stats = {health = 50},
            abilities = {"javelin_attack", "piercing_shot"},
            expected_warnings = {"health 50 is very low"},
            description = "Heavy javelins and piercing shots, almost no health.",
            strategy = "Hits hard from range while standing still, and dies to anything that reaches it."},
        {name = "Fortress", unit_type = "tank", archetype = "tank",
            stats = {health = 380, armor = 24},
            abilities = {"primary_melee_attack", "protective_ward"},
            expected_warnings = {"health 380 is very high", "armor 24 is very high"},
            description = "Nearly unkillable, nearly harmless.",
            strategy = "Blocks a lane for a long time; something else must do the killing."},
        {name = "Scout", unit_type = "special", archetype = "speed",
            stats = {speed = 120, detection_range = 170},
            abilities = {"sling_attack", "focus"},
            expected_warnings = {"speed 120 is very high", "detection_range 170 is very high"},
            description = "The fastest unit with the longest sight.",
            strategy = "Gets anywhere first; good for harassing, weak in a straight fight."}
    },
    -- }}}

    -- {{{ showcase
    showcase = {
        {name = "Versatile Fighter", unit_type = "melee", archetype = "hybrid",
            abilities = {"primary_melee_attack", "power_strike", "crippling_blow", "battle_fury"},
            description = "A little of everything: a hard hit, a slow and a rallying buff.",
            strategy = "Shows every part of a template at once; a sound pick when unsure."}
    }
    -- }}}
}

-- {{{ DefaultTemplates.set_names
function DefaultTemplates.set_names()
    local names = {}
    for _, name in ipairs(DefaultTemplates.SET_ORDER) do
        table.insert(names, name)
    end
    return names
end
-- }}}

-- {{{ DefaultTemplates.data
-- Template data for the named sets (all when names is nil), in set
-- order, each a fresh copy carrying `set` and the fields UnitTemplate.new
-- reads, plus archetype, strategy and expected_warnings for the guide
-- and tests.
function DefaultTemplates.data(names)
    local wanted = {}
    for _, name in ipairs(names or DefaultTemplates.SET_ORDER) do
        if not DefaultTemplates.sets[name] then
            error("Unknown default template set: " .. tostring(name))
        end
        wanted[name] = true
    end
    local list = {}
    for _, set_name in ipairs(DefaultTemplates.SET_ORDER) do
        if wanted[set_name] then
            for _, entry in ipairs(DefaultTemplates.sets[set_name]) do
                local copy = {set = set_name, created_by = "Default"}
                for key, value in pairs(entry) do
                    if type(value) == "table" then
                        local inner = {}
                        for k, v in pairs(value) do
                            inner[k] = v
                        end
                        copy[key] = inner
                    else
                        copy[key] = value
                    end
                end
                table.insert(list, copy)
            end
        end
    end
    return list
end
-- }}}

-- {{{ DefaultTemplates.by_archetype
-- The first default template data (in set order) of an archetype, or nil.
function DefaultTemplates.by_archetype(archetype)
    for _, data in ipairs(DefaultTemplates.data()) do
        if data.archetype == archetype then
            return data
        end
    end
    return nil
end
-- }}}

return DefaultTemplates
-- }}}
