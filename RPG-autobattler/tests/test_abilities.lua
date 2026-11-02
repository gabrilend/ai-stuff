-- {{{ Ability Component Test Suite
-- Checks issue 046 without a window: abilities of each kind inherit the
-- base, conditions gate both charging and firing, abilities price their
-- casts through ManaEfficiency, each kind works out its own effect, and
-- many units with four abilities each stay cheap.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_abilities').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Unit = require("src.entities.unit")
local Ability = require("src.components.ability")
local UnitAbilities = require("src.components.unit_abilities")
local ManaSystem = require("src.systems.mana_system")
local ManaEfficiency = require("src.systems.mana_efficiency")

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function fill
local function fill(mana, index)
    mana.bars[index].current = mana.bars[index].max
end
-- }}}

-- {{{ TestSuite.test_kinds_and_inheritance
function TestSuite.test_kinds_and_inheritance()
    local expected = {damage = "enemy", heal = "ally", buff = "ally", debuff = "enemy", area = "area"}
    for kind, targeting in pairs(expected) do
        local ability = Ability.new({type = kind, name = kind})
        assert(getmetatable(ability) == Ability.KINDS[kind], kind .. " gets its own kind")
        assert(Ability.is_ability(ability), kind .. " is an ability")
        assert(ability.targeting == targeting, kind .. " aims at " .. targeting)
        assert(type(ability.check_condition) == "function", kind .. " inherits the base methods")
    end

    local old_names = Ability.new({type = "damage", base_power = 70, max_mana_cost = 80, mana_generation_rate = 4})
    assert(old_names.power == 70 and old_names.max_mana == 80 and old_names.mana_rate == 4, "The sketch's field names still work")
    assert(Ability.new({type = "damage", line_of_sight = false}).line_of_sight == false, "line_of_sight can be turned off")

    -- A new kind, as a later issue or a mod would add one.
    local Shield = Ability.extend("shield", function(ability, config)
        ability.absorb = config.absorb or 30
    end)
    local shield = Ability.new({type = "shield", targeting = "self"})
    assert(getmetatable(shield) == Shield and shield.absorb == 30, "Kinds can be added")
    Ability.KINDS.shield = nil

    assert(not pcall(Ability.new, {type = "nonsense"}), "Unknown types are refused")
    assert(not pcall(Ability.new, {type = "damage", targeting = "everyone"}), "Unknown targeting is refused")
    assert(not pcall(Ability.new, {type = "damage", max_mana = 0}), "A bar needs a size")
    assert(Ability.new({}).id ~= Ability.new({}).id, "Each ability gets its own id")

    print("✓ Kinds and inheritance test passed")
end
-- }}}

-- {{{ TestSuite.test_conditions
function TestSuite.test_conditions()
    assert(Ability.compare(3, ">=", 3) and Ability.compare(2, "less_than", 3), "Symbols and words compare")
    assert(not Ability.compare(nil, ">", 1), "A missing value never passes")

    local em = EntityManager:new()
    local knight = Unit.create_basic_unit(em, 100, 100, 1, "melee")
    local foe = Unit.create_basic_unit(em, 120, 100, 2, "melee")
    Unit.create_basic_unit(em, 105, 100, 1, "melee")
    local ability = Ability.new({type = "damage", range = 30})

    local state = UnitAbilities.unit_state(em, knight)
    assert(ability:check_condition({type = "unit_type", value = "melee"}, state), "Unit type")
    assert(ability:check_condition({type = "enemies_in_range", operator = ">=", value = 1}, state), "One enemy within the ability's range")
    assert(not ability:check_condition({type = "enemies_in_range", operator = ">=", value = 1, range = 10}, state), "None within 10")
    assert(ability:check_condition({type = "allies_in_range", operator = "==", value = 1}, state), "The unit doesn't count itself")
    assert(ability:check_condition({type = "is_stationary", value = true}, state), "Standing still")
    assert(ability:check_condition({type = "health_percentage", operator = ">", value = 99}, state), "Full health")

    Unit.damage_unit(em, knight, Unit.get_unit_base_health("melee") * 0.6)
    em:get_component(knight, "moveable").velocity_x = 30
    em:get_component(foe, "health").alive = false
    state = UnitAbilities.unit_state(em, knight)
    assert(ability:check_condition({type = "health_percentage", operator = "<", value = 50}, state), "Below half health")
    assert(not ability:check_condition({type = "is_stationary", value = true}, state), "Moving")
    assert(not ability:check_condition({type = "enemies_in_range", value = 1}, state), "Dead enemies don't count")

    state.active_effects = {rally = {}}
    assert(ability:check_condition({type = "has_effect", value = "rally"}, state), "Has an effect")
    assert(ability:check_condition({type = "missing_effect", value = "haste"}, state), "Lacks an effect")
    assert(ability:check_condition({type = "custom", check = function(s, a) return a == ability end}, state), "Custom check")
    assert(not ability:check_condition({type = "typo"}, state), "Unknown condition types fail safe")

    print("✓ Conditions test passed")
end
-- }}}

-- {{{ TestSuite.test_ready_and_priority
function TestSuite.test_ready_and_priority()
    local em = EntityManager:new()
    local unit = Unit.create_basic_unit(em, 0, 0, 1, "support")
    local abilities, mana = UnitAbilities.attach(em, unit, {
        {name = "strike", type = "damage", max_mana = 50},
        {name = "mend", type = "heal", max_mana = 80, priority = 0},
        {name = "aura", type = "buff", category = "passive"},
        {name = "last stand", type = "damage", activation_conditions = {{type = "health_percentage", operator = "<", value = 30}}}
    })
    assert(#mana.bars == 4 and mana.bars[2].max == 80 and mana.bars[2].name == "mend", "One bar per ability, sized by it")

    local state = UnitAbilities.unit_state(em, unit)
    local ready, blocked = UnitAbilities.get_ready(abilities, mana, state)
    assert(#ready == 0 and blocked[1] == "mana_not_full", "Nothing fires on empty bars")

    for i = 1, 4 do fill(mana, i) end
    ready, blocked = UnitAbilities.get_ready(abilities, mana, state)
    assert(#ready == 2, "Two of four are ready")
    assert(ready[1].index == 2 and ready[2].index == 1, "Priority 0 goes before the primary's slot 1")
    assert(blocked[3] == "passive", "Passive abilities never fire on their own")
    assert(blocked[4] == "condition_failed:health_percentage", "Activation conditions are checked")

    abilities.cooldowns[2] = 1.0
    ready, blocked = UnitAbilities.get_ready(abilities, mana, state)
    assert(#ready == 1 and blocked[2] == "on_cooldown", "Cooling down")
    UnitAbilities.update_cooldowns(abilities, 1.0)
    abilities.global_cooldown = 0.5
    ready, blocked = UnitAbilities.get_ready(abilities, mana, state)
    assert(#ready == 0 and blocked[1] == "global_cooldown", "The global cooldown holds every ability")
    UnitAbilities.update_cooldowns(abilities, 0.5)
    assert(#UnitAbilities.get_ready(abilities, mana, state) == 2, "Both ready again")

    print("✓ Ready and priority test passed")
end
-- }}}

-- {{{ TestSuite.test_generation_conditions
function TestSuite.test_generation_conditions()
    local em = EntityManager:new()
    local system = ManaSystem:new(em)
    local unit = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    local _, mana = UnitAbilities.attach(em, unit, {
        {name = "desperation", type = "damage", mana_rate = 10,
         generation_conditions = {{type = "health_percentage", operator = "<", value = 50}}}
    })

    system:update(1.0)
    assert(mana.bars[1].current == 0 and not mana.bars[1].charging, "A healthy unit's desperation bar waits")
    Unit.damage_unit(em, unit, Unit.get_unit_base_health("melee") * 0.6)
    system:update(1.0)
    assert_near(mana.bars[1].current, 10, "It charges once the unit is hurt")

    print("✓ Generation conditions test passed")
end
-- }}}

-- {{{ TestSuite.test_mana_efficiency_integration
function TestSuite.test_mana_efficiency_integration()
    local strike = Ability.new({type = "damage", power = 50, max_mana = 100, damage_type = "true"})
    local target = {current_health = 20, max_health = 100}
    local plan = ManaEfficiency.plan(strike, {target}, 100)
    assert_near(plan.mana_to_use, 40, "An ability is priced as it stands")
    local effect = strike:calculate_effect(target, plan.effect_power)
    assert_near(effect.amount, 20, "Its effect at that share is what the plan said")

    local mend = Ability.new({type = "heal", power = 40, max_mana = 80})
    local hurt = {current_health = 110, max_health = 120}
    plan = ManaEfficiency.plan(mend, {hurt}, 80)
    assert_near(mend:calculate_effect(hurt, plan.effect_power).amount, 10, "A heal priced to top off tops off")

    local blast = Ability.new({type = "area", power = 30, max_mana = 100, max_targets = 2})
    plan = ManaEfficiency.plan(blast, {{current_health = 100, max_health = 100}}, 100)
    assert_near(plan.mana_to_use, 50, "Area abilities use max_targets")

    print("✓ Mana efficiency integration test passed")
end
-- }}}

-- {{{ TestSuite.test_kind_effects
function TestSuite.test_kind_effects()
    local target = {current_health = 100, max_health = 100, stats = {armor = 100, magic_resist = 50}}

    local physical = Ability.new({type = "damage", power = 40})
    assert_near(physical:calculate_effect(target, 1).amount, 20, "100 armor halves physical damage")
    local piercing = Ability.new({type = "damage", power = 40, armor_penetration = 100})
    assert_near(piercing:calculate_effect(target, 1).amount, 40, "Penetration ignores armor")
    local magical = Ability.new({type = "damage", power = 30, damage_type = "magical"})
    assert_near(magical:calculate_effect(target, 1).amount, 20, "50 magic resist takes a third")
    local pure = Ability.new({type = "damage", power = 30, damage_type = "true"})
    assert_near(pure:calculate_effect(target, 1).amount, 30, "True damage ignores defence")

    local crit = Ability.new({type = "damage", power = 10, damage_type = "true", critical_chance = 0.5})
    local hit = crit:calculate_effect(target, 1, {random = function() return 0.1 end, caster_stats = {attack = 1.5}})
    assert(hit.is_critical and math.abs(hit.amount - 30) < 1e-6, "Critical hits double, after attack scaling")
    assert(not crit:calculate_effect(target, 1, {random = function() return 0.9 end}).is_critical, "A miss of the roll is no critical")

    local mend = Ability.new({type = "heal", power = 40, bonus_low_health = 0.5, self_heal_ratio = 0.25})
    local low = mend:calculate_effect({current_health = 10, max_health = 100}, 1)
    assert_near(low.amount, 60, "Low-health targets get the bonus")
    assert_near(low.self_heal, 15, "The caster heals a share")
    local topped = mend:calculate_effect({current_health = 90, max_health = 100}, 1)
    assert_near(topped.amount, 10, "Never heals past full")
    assert_near(topped.overheal, 30, "The rest is reported as overheal")

    local rally = Ability.new({type = "buff", modifiers = {attack = 0.2, speed = 0.1}})
    local buff = rally:calculate_effect(target, 1)
    assert(buff.name == rally.name and buff.duration == 5, "Buffs carry a name and a duration")
    assert_near(buff.modifiers.attack, 0.2, "Modifiers at full strength")
    local slow = Ability.new({type = "debuff", name = "slow"}):calculate_effect(target, 1)
    assert(slow.modifiers.speed < 0, "Debuffs harm by default")

    local blast = Ability.new({type = "area", power = 20, area_radius = 40, falloff = 0.5, damage_type = "true"})
    assert_near(blast:calculate_effect(target, 1, {distance = 0}).amount, 20, "Full at the centre")
    assert_near(blast:calculate_effect(target, 1, {distance = 40}).amount, 10, "Half at the edge")
    assert_near(blast:calculate_effect(target, 1, {distance = 41}).amount, 0, "Nothing outside")
    local wave = Ability.new({type = "area", area_effect = "heal", power = 20})
    assert_near(wave:calculate_effect({current_health = 95, max_health = 100}, 1, {distance = 0}).amount, 5, "Area heals cap at full")

    print("✓ Kind effects test passed")
end
-- }}}

-- {{{ TestSuite.test_debug_info
function TestSuite.test_debug_info()
    local em = EntityManager:new()
    local unit = Unit.create_basic_unit(em, 0, 0, 1, "ranged")
    local abilities, mana = UnitAbilities.attach(em, unit, {{name = "shot", type = "damage", max_mana = 40}})
    mana.bars[1].current = 10
    abilities.abilities[1]:record(true, {amount = 12, mana = 40})
    abilities.abilities[1]:record(false, "no_target")

    local info = UnitAbilities.get_debug_info(abilities, mana)
    local row = info.abilities[1]
    assert(row.name == "shot" and row.mana == "10.0/40.0", "Shows the bar")
    assert_near(row.mana_fraction, 0.25, "And how full it is")
    assert(row.activations == 1 and row.failures == 1, "And how often it fired or failed")
    assert(abilities.abilities[1].stats.failure_reasons.no_target == 1, "Failures by reason")

    print("✓ Debug info test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local em = EntityManager:new()
    local configs = {
        {type = "damage"}, {type = "heal"},
        {type = "buff", activation_conditions = {{type = "allies_in_range", value = 2}}},
        {type = "area", activation_conditions = {{type = "enemies_in_range", value = 3}}}
    }
    local units = {}
    for i = 1, 200 do
        local unit = Unit.create_basic_unit(em, (i % 20) * 10, math.floor(i / 20) * 10, (i % 2) + 1, "melee")
        local _, mana = UnitAbilities.attach(em, unit, configs)
        for b = 1, 4 do fill(mana, b) end
        units[i] = unit
    end

    local mana_system = ManaSystem:new(em)
    local start = os.clock()
    local ready_count = 0
    for _ = 1, 30 do
        local snapshot = mana_system:snapshot_units()
        for _, unit in ipairs(units) do
            local state = UnitAbilities.unit_state(em, unit, snapshot)
            ready_count = ready_count + #UnitAbilities.get_ready(em:get_component(unit, "abilities"), em:get_component(unit, "mana"), state)
        end
    end
    local elapsed = os.clock() - start
    print(string.format("  200 units x 4 abilities, 30 checks: %.3fs", elapsed))
    assert(ready_count > 0, "Some were ready")
    assert(elapsed < 2.0, "Checking abilities stays cheap")

    print("✓ Performance test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Ability Component Tests...")
    print(string.rep("=", 40))

    TestSuite.test_kinds_and_inheritance()
    TestSuite.test_conditions()
    TestSuite.test_ready_and_priority()
    TestSuite.test_generation_conditions()
    TestSuite.test_mana_efficiency_integration()
    TestSuite.test_kind_effects()
    TestSuite.test_debug_info()
    TestSuite.test_performance()

    print(string.rep("=", 40))
    print("✅ All ability component tests passed!")
end
-- }}}

return TestSuite
-- }}}
