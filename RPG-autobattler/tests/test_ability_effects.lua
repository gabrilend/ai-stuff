-- {{{ Ability Effects Test Suite
-- Checks issue 049 without a window: damage through armor and magic
-- resist, healing without waste, buffs and debuffs that stack, change
-- stats and expire, area effects, projectiles that travel and pierce,
-- templates, a whole skirmish, and two hundred units with effects.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_ability_effects').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Unit = require("src.entities.unit")
local Ability = require("src.components.ability")
local UnitAbilities = require("src.components.unit_abilities")
local ManaSystem = require("src.systems.mana_system")
local AbilityActivationSystem = require("src.systems.ability_activation_system")
local AbilityEffectSystem = require("src.systems.ability_effect_system")
local AbilityFactory = require("src.factories.ability_factory")
local AbilityTemplates = require("src.data.ability_templates")

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function event_for
-- An activation event as the activation system would send it, at full
-- strength unless share is given.
local function event_for(em, caster, ability, targets, share, center)
    local list = {}
    for _, entity in ipairs(targets) do
        local pos = em:get_component(entity, "position")
        local health = em:get_component(entity, "health")
        local entry = {entity = entity, x = pos.x, y = pos.y, current_health = health.current_hp, max_health = health.max_hp}
        if center then
            entry.distance_from_center = math.sqrt((pos.x - center.x) ^ 2 + (pos.y - center.y) ^ 2)
        end
        table.insert(list, entry)
    end
    return {caster = caster, ability = ability, index = 1, targets = list, center = center,
        plan = {effect_power = share or 1}, time = 0}
end
-- }}}

-- {{{ local function hp
local function hp(em, unit)
    return em:get_component(unit, "health").current_hp
end
-- }}}

-- {{{ TestSuite.test_damage
function TestSuite.test_damage()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em, {random = function() return 0.99 end})
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    local tank = Unit.create_basic_unit(em, 10, 0, 2, "tank")
    em:add_component(tank, "stats", {armor = 100, magic_resist = 50})
    local start = hp(em, tank)

    effects:process_ability_activation(event_for(em, caster, Ability.new({type = "damage", power = 40}), {tank}))
    assert_near(start - hp(em, tank), 20, "100 armor halves physical damage")
    effects:process_ability_activation(event_for(em, caster, Ability.new({type = "damage", power = 30, damage_type = "magical"}), {tank}))
    assert_near(start - hp(em, tank), 40, "50 magic resist takes a third")
    effects:process_ability_activation(event_for(em, caster, Ability.new({type = "damage", power = 40}), {tank}, 0.5))
    assert_near(start - hp(em, tank), 50, "Half the bar, half the damage")

    local victim = Unit.create_basic_unit(em, 20, 0, 2, "ranged")
    em:add_component(victim, "effects", {active = {slow = {kind = "debuff", modifiers = {speed = -0.5}, remaining = 5}}})
    effects:pop_cues()
    effects:process_ability_activation(event_for(em, caster, Ability.new({type = "damage", power = 1000, damage_type = "true"}), {victim}))
    assert(not Unit.is_alive(em, victim), "Lethal damage kills")
    assert(next(em:get_component(victim, "effects").active) == nil, "A dead unit's effects end")
    local kinds = {}
    for _, cue in ipairs(effects:pop_cues()) do kinds[cue.kind] = (kinds[cue.kind] or 0) + 1 end
    assert(kinds.damage == 1 and kinds.death == 1, "Cues for the hit and the death")
    assert(effects.stats.kills == 1, "The kill is counted")

    print("✓ Damage test passed")
end
-- }}}

-- {{{ TestSuite.test_healing
function TestSuite.test_healing()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em)
    local healer = Unit.create_basic_unit(em, 0, 0, 1, "support")
    local ally = Unit.create_basic_unit(em, 10, 0, 1, "melee")
    local max = em:get_component(ally, "health").max_hp
    Unit.damage_unit(em, ally, 10)
    Unit.damage_unit(em, healer, 20)

    effects:process_ability_activation(event_for(em, healer, Ability.new({type = "heal", power = 40, self_heal_ratio = 0.5}), {ally}))
    assert_near(hp(em, ally), max, "Healed to full, no further")
    assert_near(effects.stats.healing_done, 10 + 5, "10 to the ally and half of that to the healer")
    assert_near(effects.stats.overheal, 0, "The ability capped itself, so nothing was wasted")

    local fx = em:add_component(ally, "effects", {active = {
        slow = {kind = "debuff", modifiers = {speed = -0.5}, remaining = 5},
        fury = {kind = "buff", modifiers = {attack = 0.5}, remaining = 5}
    }})
    Unit.damage_unit(em, ally, 5)
    effects:process_ability_activation(event_for(em, healer, Ability.new({type = "heal", power = 10, cleanse = true}), {ally}))
    local active = em:get_component(ally, "effects").active
    assert(active.slow == nil and active.fury ~= nil, "Cleanse removes debuffs and keeps buffs")

    print("✓ Healing test passed")
end
-- }}}

-- {{{ TestSuite.test_buffs_and_debuffs
function TestSuite.test_buffs_and_debuffs()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em)
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "support")
    local ally = Unit.create_basic_unit(em, 10, 0, 1, "melee")
    local enemy = Unit.create_basic_unit(em, 20, 0, 2, "melee")

    local fury = Ability.new({type = "buff", name = "fury", modifiers = {attack = 0.25}, duration = 4, stacking = "stack", max_stacks = 2})
    for _ = 1, 3 do
        effects:process_ability_activation(event_for(em, caster, fury, {ally}))
    end
    local active = em:get_component(ally, "effects").active
    assert(active.fury.stacks == 2, "Stacks up to max_stacks")
    assert_near(effects:get_stat(ally, "attack"), 1.5, "Two stacks of +25% attack")

    local strike = Ability.new({type = "damage", power = 20, damage_type = "true"})
    local before = hp(em, enemy)
    effects:process_ability_activation(event_for(em, ally, strike, {enemy}))
    assert_near(before - hp(em, enemy), 30, "The buffed ally hits 50% harder")

    local ward = Ability.new({type = "buff", name = "ward", modifiers = {}, flat_modifiers = {armor = 100}, duration = 4})
    effects:process_ability_activation(event_for(em, caster, ward, {enemy}))
    before = hp(em, enemy)
    effects:process_ability_activation(event_for(em, caster, Ability.new({type = "damage", power = 20}), {enemy}))
    assert_near(before - hp(em, enemy), 10, "Flat armor from a ward halves physical damage")

    local base_speed = em:get_component(enemy, "moveable").speed
    local slow = Ability.new({type = "debuff", name = "slow", modifiers = {speed = -0.5}, duration = 2})
    effects:process_ability_activation(event_for(em, caster, slow, {enemy}))
    assert_near(em:get_component(enemy, "moveable").speed, base_speed * 0.5, "Slowed to half speed")
    effects:update(1.0)
    effects:process_ability_activation(event_for(em, caster, slow, {enemy}))
    effects:update(1.5)
    assert(em:get_component(enemy, "effects").active.slow ~= nil, "Recasting refreshed the duration")
    effects:update(0.6)
    assert(em:get_component(enemy, "effects").active.slow == nil, "Then it expires")
    assert_near(em:get_component(enemy, "moveable").speed, base_speed, "And the speed comes back")

    effects:update(2.0)
    assert(em:get_component(ally, "effects").active.fury == nil, "Buffs expire too")
    assert_near(effects:get_stat(ally, "attack"), 1, "And their stats go back")

    print("✓ Buffs and debuffs test passed")
end
-- }}}

-- {{{ TestSuite.test_stun_stops_abilities
function TestSuite.test_stun_stops_abilities()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em)
    local activation = AbilityActivationSystem:new(em, {effect_system = effects})
    local bruiser = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    local _, mana = UnitAbilities.attach(em, bruiser, {{type = "damage", range = 15, mana_rate = 0}})
    local enemy = Unit.create_basic_unit(em, 10, 0, 2, "melee")
    mana.bars[1].current = mana.bars[1].max

    local bash = Ability.new({type = "debuff", name = "stunned", modifiers = {}, stun = true, duration = 1})
    effects:process_ability_activation(event_for(em, enemy, bash, {bruiser}))
    activation:update(0.1)
    assert(activation.stats.activations == 0, "A stunned unit doesn't fire")
    effects:update(1.0)
    activation:update(0.1)
    assert(activation.stats.activations == 1, "It fires once the stun wears off")

    print("✓ Stun stops abilities test passed")
end
-- }}}

-- {{{ TestSuite.test_area
function TestSuite.test_area()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em)
    local mage = Unit.create_basic_unit(em, 0, 0, 1, "special")
    local center_unit = Unit.create_basic_unit(em, 50, 0, 2, "tank")
    local edge_unit = Unit.create_basic_unit(em, 70, 0, 2, "tank")
    local a, b = hp(em, center_unit), hp(em, edge_unit)

    local blast = Ability.new({type = "area", power = 20, area_radius = 20, falloff = 0.5, damage_type = "true"})
    local center = {x = 50, y = 0}
    effects:process_ability_activation(event_for(em, mage, blast, {center_unit, edge_unit}, 1, center))
    assert_near(a - hp(em, center_unit), 20, "Full damage at the centre")
    assert_near(b - hp(em, edge_unit), 10, "Half at the edge")
    local area_cues = 0
    for _, cue in ipairs(effects:pop_cues()) do
        if cue.kind == "area" then area_cues = area_cues + 1 end
    end
    assert(area_cues == 1, "One cue for the circle")

    local cleric = Unit.create_basic_unit(em, 200, 0, 1, "support")
    local hurt = Unit.create_basic_unit(em, 205, 0, 1, "melee")
    Unit.damage_unit(em, hurt, 30)
    local wave = Ability.new({type = "area", area_effect = "heal", power = 50, area_radius = 20, falloff = 0})
    effects:process_ability_activation(event_for(em, cleric, wave, {hurt, cleric}, 1, {x = 202, y = 0}))
    assert_near(hp(em, hurt), em:get_component(hurt, "health").max_hp, "Area healing heals")

    print("✓ Area test passed")
end
-- }}}

-- {{{ TestSuite.test_projectiles
function TestSuite.test_projectiles()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em)
    local archer = Unit.create_basic_unit(em, 0, 0, 1, "ranged")
    local first = Unit.create_basic_unit(em, 30, 0, 2, "tank")
    local friend = Unit.create_basic_unit(em, 15, 0, 1, "melee")
    local second = Unit.create_basic_unit(em, 45, 1, 2, "tank")
    local beside = Unit.create_basic_unit(em, 40, 30, 2, "tank")
    local hp1, hp2, hp3, hpf = hp(em, first), hp(em, second), hp(em, beside), hp(em, friend)

    local arrow = Ability.new({type = "damage", delivery = "projectile", projectile_speed = 100, power = 10,
        damage_type = "true", range = 40, pierce = 2})
    effects:process_ability_activation(event_for(em, archer, arrow, {first}))
    assert(hp(em, first) == hp1, "Nothing is hit at launch")
    effects:update(0.2)
    assert(hp(em, first) == hp1, "Not yet: 20 of 30 travelled")
    effects:update(0.1)
    assert_near(hp1 - hp(em, first), 10, "Hits the first enemy when it gets there")
    effects:update(0.2)
    assert_near(hp2 - hp(em, second), 10, "Pierces through to the enemy behind")
    assert(hp(em, friend) == hpf, "Flies past allies")
    assert(hp(em, beside) == hp3, "Misses what isn't on its path")
    assert(#effects.projectiles == 0, "Spent after two hits")

    local miss = Ability.new({type = "damage", delivery = "projectile", projectile_speed = 100, power = 10, range = 40})
    local target = Unit.create_basic_unit(em, 0, 35, 2, "melee")
    effects:process_ability_activation(event_for(em, archer, miss, {target}))
    em:get_component(target, "position").x = 30   -- it steps aside
    for _ = 1, 10 do effects:update(0.1) end
    assert(#effects.projectiles == 0, "A miss flies out of range and is gone")
    assert(effects.stats.projectiles_launched == 2 and effects.stats.projectile_hits == 2, "Counts launches and hits")

    print("✓ Projectiles test passed")
end
-- }}}

-- {{{ TestSuite.test_templates
function TestSuite.test_templates()
    for _, name in ipairs(AbilityFactory.template_names()) do
        local ability = AbilityFactory.create(name)
        assert(Ability.is_ability(ability) and ability.name == name, "Template builds: " .. name)
    end
    local em = EntityManager:new()
    for set_name in pairs(AbilityTemplates.sets) do
        local unit = Unit.create_basic_unit(em, 0, 0, 1, "melee")
        local container, mana = AbilityFactory.attach_set(em, unit, set_name)
        assert(#container.abilities == #mana.bars and #mana.bars >= 2, "Set attaches: " .. set_name)
    end

    local strong = AbilityFactory.create("power_strike", {power = 90})
    assert(strong.power == 90 and strong.critical_chance == 0.3, "Changes lay over the template")
    local a = AbilityFactory.create_config("battle_fury")
    a.modifiers.attack = 99
    assert(AbilityFactory.create_config("battle_fury").modifiers.attack == 0.25, "Each config is a fresh copy")
    assert(not pcall(AbilityFactory.create, "no_such_template"), "Unknown templates are refused")

    print("✓ Templates test passed")
end
-- }}}

-- {{{ TestSuite.test_skirmish
-- Two small teams with template sets fight for thirty seconds with every
-- system running.
function TestSuite.test_skirmish()
    local em = EntityManager:new()
    local mana = ManaSystem:new(em)
    local effects = AbilityEffectSystem:new(em, {random = function() return 0.5 end})
    local activation = AbilityActivationSystem:new(em, {effect_system = effects})
    local sets = {{"melee", "basic_warrior"}, {"ranged", "basic_archer"}, {"support", "support_cleric"}, {"special", "battle_mage"}}
    for team = 1, 2 do
        for i, entry in ipairs(sets) do
            local unit = Unit.create_basic_unit(em, team == 1 and 100 or 110, i * 8, team, entry[1])
            AbilityFactory.attach_set(em, unit, entry[2])
        end
    end
    for _ = 1, 30 * 20 do
        mana:update(0.05)
        activation:update(0.05)
        effects:update(0.05)
    end
    assert(activation.stats.activations > 10, "Abilities fired: " .. activation.stats.activations)
    assert(effects.stats.damage_dealt > 0, "Damage was dealt")
    assert(effects.stats.by_type.damage and effects.stats.by_type.damage.casts > 0, "Counted by type")
    print(string.format("  30 s skirmish: %d activations, %.0f damage, %.0f healing, %d kills",
        activation.stats.activations, effects.stats.damage_dealt, effects.stats.healing_done, effects.stats.kills))

    print("✓ Skirmish test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em)
    local units = {}
    for i = 1, 200 do
        units[i] = Unit.create_basic_unit(em, (i % 20) * 10, math.floor(i / 20) * 10, (i % 2) + 1, "melee")
    end
    local slow = Ability.new({type = "debuff", name = "slow", duration = 100})
    local fury = Ability.new({type = "buff", name = "fury", duration = 100})
    local arrow = Ability.new({type = "damage", delivery = "projectile", power = 1, range = 200})
    for i, unit in ipairs(units) do
        effects:process_ability_activation(event_for(em, units[1], i % 2 == 0 and slow or fury, {unit}))
        if i % 4 == 0 then
            effects:process_ability_activation(event_for(em, unit, arrow, {units[((i + 1) % 200) + 1]}))
        end
    end
    local start = os.clock()
    for _ = 1, 60 do
        effects:update(1 / 60)
    end
    local elapsed = os.clock() - start
    print(string.format("  200 units with effects and 50 projectiles, 60 frames: %.3fs", elapsed))
    assert(elapsed < 3.0, "Effects stay cheap")

    print("✓ Performance test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Ability Effects Tests...")
    print(string.rep("=", 40))

    TestSuite.test_damage()
    TestSuite.test_healing()
    TestSuite.test_buffs_and_debuffs()
    TestSuite.test_stun_stops_abilities()
    TestSuite.test_area()
    TestSuite.test_projectiles()
    TestSuite.test_templates()
    TestSuite.test_skirmish()
    TestSuite.test_performance()

    print(string.rep("=", 40))
    print("✅ All ability effects tests passed!")
end
-- }}}

return TestSuite
-- }}}
