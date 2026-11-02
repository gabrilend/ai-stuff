-- {{{ Cooldowns and Persistent Effects Test Suite
-- Checks issue 050 without a window: ability, global and shared
-- cooldowns, cooldown reduction and its cap, damage and healing over
-- time ticking on time, cleansing, projectiles that poison on hit, the
-- whole loop through the activation system, and three hundred effects.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_cooldowns_effects').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Unit = require("src.entities.unit")
local Ability = require("src.components.ability")
local UnitAbilities = require("src.components.unit_abilities")
local ManaSystem = require("src.systems.mana_system")
local AbilityActivationSystem = require("src.systems.ability_activation_system")
local AbilityEffectSystem = require("src.systems.ability_effect_system")
local CooldownSystem = require("src.systems.cooldown_system")
local PersistentEffectsSystem = require("src.systems.persistent_effects_system")
local AbilityFactory = require("src.factories.ability_factory")

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function hp
local function hp(em, unit)
    return em:get_component(unit, "health").current_hp
end
-- }}}

-- {{{ local function world
local function world()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em)
    local persistent = PersistentEffectsSystem:new(em, effects)
    return em, effects, persistent
end
-- }}}

-- {{{ local function cast
local function cast(effects, em, caster, ability, target, share)
    local health = em:get_component(target, "health")
    local pos = em:get_component(target, "position")
    return effects:process_ability_activation({
        caster = caster, ability = ability, index = 1,
        targets = {{entity = target, x = pos.x, y = pos.y, current_health = health.current_hp, max_health = health.max_hp}},
        plan = {effect_power = share or 1}, time = 0
    })
end
-- }}}

-- {{{ TestSuite.test_ability_and_global_cooldowns
function TestSuite.test_ability_and_global_cooldowns()
    local em = EntityManager:new()
    local cooldowns = CooldownSystem:new(em)
    local unit = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    local container = UnitAbilities.attach(em, unit, {{type = "damage", cooldown = 3}, {type = "heal"}})

    cooldowns:start(unit, container, 1, 0.25)
    local waiting, kind = cooldowns:is_on_cooldown(container, 2)
    assert(waiting and kind == "global", "The global cooldown holds the other ability")
    cooldowns:update(0.25)
    assert(not cooldowns:is_on_cooldown(container, 2), "Then it's free")
    local _, kind1, left = cooldowns:is_on_cooldown(container, 1)
    assert(kind1 == "ability", "The ability's own cooldown runs on")
    assert_near(left, 2.75, "3 s less the quarter second")

    local status = cooldowns:get_status(container)
    assert_near(status[1].fraction, 2.75 / 3, "Status gives the share left, for drawing")
    assert(status[2].ready and not status[1].ready, "And which are ready")

    cooldowns:update(3)
    assert(not cooldowns:is_on_cooldown(container, 1), "Done after its time")
    cooldowns:start(unit, container, 1, 1)
    cooldowns:reset_all(container)
    assert(not cooldowns:is_on_cooldown(container, 1) and container.global_cooldown == 0, "reset_all clears everything")

    print("✓ Ability and global cooldowns test passed")
end
-- }}}

-- {{{ TestSuite.test_shared_cooldowns
function TestSuite.test_shared_cooldowns()
    local em = EntityManager:new()
    local cooldowns = CooldownSystem:new(em)
    local mage = Unit.create_basic_unit(em, 0, 0, 1, "special")
    local container = UnitAbilities.attach(em, mage, {
        {type = "area", cooldown = 6, shared_cooldown = "spell"},
        {type = "heal", cooldown = 2, shared_cooldown = "spell"},
        {type = "damage", cooldown = 1}
    })
    container.cooldowns[2] = 4   -- already longer than the shared wait

    cooldowns:start(mage, container, 1)
    assert_near(container.cooldowns[1], 6, "Its own cooldown")
    assert_near(container.cooldowns[2], 4, "A shared wait never shortens a longer one")
    assert(container.cooldowns[3] == 0, "Abilities outside the group are free")
    container.cooldowns[2] = 0
    cooldowns:start(mage, container, 1)
    assert_near(container.cooldowns[2], 3, "The group waits half as long")

    print("✓ Shared cooldowns test passed")
end
-- }}}

-- {{{ TestSuite.test_cooldown_reduction
function TestSuite.test_cooldown_reduction()
    local em, effects = world()
    local cooldowns = CooldownSystem:new(em, {stats = effects})
    local unit = Unit.create_basic_unit(em, 0, 0, 1, "special")
    local container = UnitAbilities.attach(em, unit, {{type = "damage", cooldown = 4}, {type = "damage", cooldown = 4, cooldown_reduction_bonus = 0.6}})

    local focus = AbilityFactory.create("focus")
    cast(effects, em, unit, focus, unit)
    assert_near(effects:get_stat(unit, "cooldown_reduction"), 0.3, "Focus gives 30% cooldown reduction")
    assert_near(cooldowns:start(unit, container, 1), 2.8, "4 s less 30%")
    assert_near(cooldowns:start(unit, container, 2), 1.0, "30% + 60% is capped at 75%")
    assert(cooldowns.stats.time_saved > 0, "Time saved is counted")

    effects:update(10)
    assert_near(cooldowns:start(unit, container, 1), 4, "Without the buff, the full cooldown")

    print("✓ Cooldown reduction test passed")
end
-- }}}

-- {{{ TestSuite.test_damage_over_time
function TestSuite.test_damage_over_time()
    local em, effects, persistent = world()
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "ranged")
    local target = Unit.create_basic_unit(em, 10, 0, 2, "tank")
    local start = hp(em, target)

    persistent:add_damage_over_time(caster, target, 4, 5, 1, "true", "burn")
    local ticks_at = {}
    for i = 1, 60 do
        local before = hp(em, target)
        persistent:update(0.1)
        if hp(em, target) < before then table.insert(ticks_at, i / 10) end
    end
    assert(#ticks_at == 5, "Five ticks in five seconds, got " .. #ticks_at)
    assert_near(ticks_at[1], 1.0, "The first a second after it lands")
    assert_near(ticks_at[5], 5.0, "The last at five seconds")
    assert_near(start - hp(em, target), 20, "4 a tick")
    assert(#persistent.effects == 0, "Cleaned up when it ends")

    em:add_component(target, "stats", {armor = 100})
    persistent:add_damage_over_time(caster, target, 4, 2, 1, "physical", "bleed")
    persistent:add_damage_over_time(caster, target, 2, 3, 1, "physical", "bleed")
    assert(#persistent.effects == 1 and persistent.effects[1].per_tick == 4, "Recasting refreshes and keeps the stronger tick")
    persistent:add_damage_over_time(caster, target, 2, 3, 1, "true", "burn")
    assert(#persistent.effects == 2, "Different effects stack")
    local before = hp(em, target)
    persistent:update(1.0)
    assert_near(before - hp(em, target), 2 + 2, "Armor halves the bleed's tick; the burn ignores it")

    local victim = Unit.create_basic_unit(em, 20, 0, 2, "ranged")
    persistent:add_damage_over_time(caster, victim, 1000, 5, 1, "true", "doom")
    persistent:update(1.0)
    assert(not Unit.is_alive(em, victim), "Lethal ticks kill")
    persistent:update(0.1)
    for _, effect in ipairs(persistent.effects) do
        assert(effect.target ~= victim, "A dead unit's effects end")
    end
    assert(effects.stats.kills == 1, "Kills are counted by the effect system")

    print("✓ Damage over time test passed")
end
-- }}}

-- {{{ TestSuite.test_heal_over_time
function TestSuite.test_heal_over_time()
    local em, effects, persistent = world()
    local druid = Unit.create_basic_unit(em, 0, 0, 1, "support")
    local ally = Unit.create_basic_unit(em, 10, 0, 1, "melee")
    Unit.damage_unit(em, ally, 15)
    local max = em:get_component(ally, "health").max_hp

    local regen = AbilityFactory.create("regeneration")
    cast(effects, em, druid, regen, ally)
    assert_near(hp(em, ally), max - 5, "The instant part heals 10")
    persistent:update(1.0)
    assert_near(hp(em, ally), max, "The first tick of 6 tops off")
    persistent:update(1.0)
    assert_near(hp(em, ally), max, "And never past full")
    assert_near(persistent.stats.healing_done, 5, "Only real healing is counted")
    assert(#persistent:get_effects_on(ally) == 1, "It keeps running for later damage")

    print("✓ Heal over time test passed")
end
-- }}}

-- {{{ TestSuite.test_cleanse
function TestSuite.test_cleanse()
    local em, effects, persistent = world()
    local healer = Unit.create_basic_unit(em, 0, 0, 1, "support")
    local ally = Unit.create_basic_unit(em, 10, 0, 1, "melee")
    persistent:add_damage_over_time(healer, ally, 3, 5, 1, "true", "poison")
    persistent:add_heal_over_time(healer, ally, 3, 5, 1, "renew")
    cast(effects, em, healer, Ability.new({type = "debuff", name = "slow", duration = 5}), ally)
    cast(effects, em, healer, Ability.new({type = "buff", name = "fury", duration = 5}), ally)
    Unit.damage_unit(em, ally, 20)

    cast(effects, em, healer, AbilityFactory.create("purifying_touch"), ally)
    local over_time = persistent:get_effects_on(ally)
    assert(#over_time == 1 and over_time[1].name == "renew", "The poison is gone, the renew stays")
    local active = em:get_component(ally, "effects").active
    assert(active.slow == nil and active.fury ~= nil, "The slow is gone, the fury stays")

    print("✓ Cleanse test passed")
end
-- }}}

-- {{{ TestSuite.test_projectile_poison
function TestSuite.test_projectile_poison()
    local em, effects, persistent = world()
    local archer = Unit.create_basic_unit(em, 0, 0, 1, "ranged")
    local target = Unit.create_basic_unit(em, 20, 0, 2, "tank")
    cast(effects, em, archer, AbilityFactory.create("poison_dart"), target)
    assert(#persistent.effects == 0, "No poison before the dart lands")
    effects:update(0.2)
    assert(#persistent:get_effects_on(target) == 1, "Poisoned on the hit")

    print("✓ Projectile poison test passed")
end
-- }}}

-- {{{ TestSuite.test_full_loop
-- The activation system starts cooldowns (with reduction) and the effect
-- system hands over-time effects on.
function TestSuite.test_full_loop()
    local em, effects, persistent = world()
    local mana = ManaSystem:new(em)
    local activation = AbilityActivationSystem:new(em, {effect_system = effects})
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    local container = UnitAbilities.attach(em, caster, {
        {name = "venom", type = "damage", power = 5, damage_type = "true", range = 15,
         max_mana = 10, mana_rate = 100, cooldown = 2, damage_over_time = 3, over_time_duration = 3}
    })
    local enemy = Unit.create_basic_unit(em, 10, 0, 2, "tank")
    cast(effects, em, caster, Ability.new({type = "buff", name = "haste", modifiers = {}, flat_modifiers = {cooldown_reduction = 0.5}, duration = 100}), caster)

    local casts = {}
    for i = 1, 40 do
        mana:update(0.1)
        activation:update(0.1)
        effects:update(0.1)
        persistent:update(0.1)
        for _ = 1, #activation:pop_events() do table.insert(casts, i / 10) end
    end
    assert(#casts >= 3, "Cast several times")
    assert_near(casts[2] - casts[1], 1.0, "A 2 s cooldown halved by the buff", 0.11)
    assert(persistent.stats.ticks > 0, "Its poison ticked")
    assert(container.cooldown_durations[1] > 0, "The activation system started the cooldown")
    assert(hp(em, enemy) < em:get_component(enemy, "health").max_hp, "The enemy was hurt")

    print("✓ Full loop test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local em, effects, persistent = world()
    local units = {}
    for i = 1, 300 do
        units[i] = Unit.create_basic_unit(em, (i % 30) * 10, math.floor(i / 30) * 10, (i % 2) + 1, "tank")
    end
    for i, unit in ipairs(units) do
        persistent:add_damage_over_time(units[1], unit, 0.1, 100, 0.5, "true", "burn")
        persistent:add_heal_over_time(units[1], unit, 0.1, 100, 0.5, "renew")
    end
    local cooldowns = CooldownSystem:new(em)
    local start = os.clock()
    for _ = 1, 60 do
        persistent:update(1 / 60)
        cooldowns:update(1 / 60)
    end
    local elapsed = os.clock() - start
    print(string.format("  600 over-time effects, 60 frames: %.3fs", elapsed))
    assert(#persistent.effects == 600, "All still running")
    assert(elapsed < 2.0, "Over-time effects stay cheap")

    print("✓ Performance test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Cooldowns and Persistent Effects Tests...")
    print(string.rep("=", 40))

    TestSuite.test_ability_and_global_cooldowns()
    TestSuite.test_shared_cooldowns()
    TestSuite.test_cooldown_reduction()
    TestSuite.test_damage_over_time()
    TestSuite.test_heal_over_time()
    TestSuite.test_cleanse()
    TestSuite.test_projectile_poison()
    TestSuite.test_full_loop()
    TestSuite.test_performance()

    print(string.rep("=", 40))
    print("✅ All cooldowns and persistent effects tests passed!")
end
-- }}}

return TestSuite
-- }}}
