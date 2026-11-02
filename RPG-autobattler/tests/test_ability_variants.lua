-- {{{ Ability Variants Test Suite
-- Checks what issues 051-054 asked for beyond the ability stack, without
-- a window: weapon templates that differ, melee cleave inside an attack
-- arc, projectiles that miss and weaken with distance, emergency healing
-- that waits for a badly hurt ally, the weakness curse, lasting area
-- zones that damage and slow whoever stands in them, and walls that
-- shield units from an area's blast.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_ability_variants').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Unit = require("src.entities.unit")
local Ability = require("src.components.ability")
local UnitAbilities = require("src.components.unit_abilities")
local AbilityEffectSystem = require("src.systems.ability_effect_system")
local PersistentEffectsSystem = require("src.systems.persistent_effects_system")
local TargetingSystem = require("src.systems.targeting_system")
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

-- {{{ local function hp
local function hp(em, unit)
    return em:get_component(unit, "health").current_hp
end
-- }}}

-- {{{ local function event_for
local function event_for(em, caster, ability, targets, center)
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
        plan = {effect_power = 1}, time = 0}
end
-- }}}

-- {{{ local function sequence
-- A random source that hands out the given numbers in turn, then 0.5.
local function sequence(...)
    local values, index = {...}, 0
    return function()
        index = index + 1
        return values[index] or 0.5
    end
end
-- }}}

-- {{{ TestSuite.test_weapon_templates_differ
function TestSuite.test_weapon_templates_differ()
    local melee = {"primary_melee_attack", "axe_attack", "dagger_attack", "spear_attack"}
    local ranged = {"primary_ranged_attack", "crossbow_attack", "sling_attack", "javelin_attack"}
    local seen = {}
    for _, name in ipairs(melee) do
        local ability = AbilityFactory.create(name)
        assert(ability.type == "damage" and ability.delivery ~= "projectile", name .. " strikes in melee")
        assert(ability.range <= 20, name .. " has melee reach")
        assert(ability.weapon_type and not seen[ability.weapon_type], name .. " names its own weapon")
        seen[ability.weapon_type] = true
    end
    for _, name in ipairs(ranged) do
        local ability = AbilityFactory.create(name)
        assert(ability.delivery == "projectile", name .. " fires a projectile")
        assert(ability.target_priority == "weakest" and ability.line_of_sight, name .. " picks the weakest enemy in sight")
        assert(ability.accuracy > 0 and ability.accuracy <= 1, name .. " has an accuracy")
        assert(ability.drop_off_distance and ability.drop_off_distance < ability.range, name .. " weakens far out")
        assert(not seen[ability.weapon_type], name .. " names its own weapon")
        seen[ability.weapon_type] = true
    end

    -- Each weapon trades something: no weapon beats the sword on reach,
    -- speed and power all at once.
    local sword = AbilityFactory.create("primary_melee_attack")
    for _, name in ipairs({"axe_attack", "dagger_attack", "spear_attack"}) do
        local weapon = AbilityFactory.create(name)
        local better = 0
        if weapon.range > sword.range then better = better + 1 end
        if weapon.mana_rate > sword.mana_rate then better = better + 1 end
        if weapon.power > sword.power then better = better + 1 end
        assert(better >= 1 and better <= 2, name .. " is better at some things, worse at others")
    end
    print("✓ Weapon templates test passed")
end
-- }}}

-- {{{ TestSuite.test_cleave
function TestSuite.test_cleave()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em, {random = function() return 0.99 end})
    local axe = AbilityFactory.create("axe_attack")           -- cleave 1, 120 degree arc
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    local main = Unit.create_basic_unit(em, 10, 0, 2, "tank")
    local beside = Unit.create_basic_unit(em, 8, 6, 2, "tank")     -- ~37 degrees off, in the arc
    local behind = Unit.create_basic_unit(em, -8, 0, 2, "tank")    -- behind the caster
    local further = Unit.create_basic_unit(em, 9, -8, 2, "tank")   -- in the arc, but further than beside
    local friend = Unit.create_basic_unit(em, 9, 2, 1, "tank")     -- an ally in the arc
    local start = hp(em, main)

    effects:process_ability_activation(event_for(em, caster, axe, {main}))
    assert_near(start - hp(em, main), 32, "The main target takes the full blow")
    assert_near(start - hp(em, beside), 32 * 0.7, "The nearest enemy in the arc takes the cleave share")
    assert(hp(em, behind) == start, "An enemy outside the arc is spared")
    assert(hp(em, further) == start, "Only one extra target for cleave_targets 1")
    assert(hp(em, friend) == start, "Cleave never hits allies")
    assert(effects.stats.cleave_hits == 1, "The cleave hit is counted")

    -- The narrow spear only reaches straight through.
    local spear = AbilityFactory.create("spear_attack")
    local em2 = EntityManager:new()
    local effects2 = AbilityEffectSystem:new(em2, {random = function() return 0.99 end})
    local c2 = Unit.create_basic_unit(em2, 0, 0, 1, "melee")
    local front = Unit.create_basic_unit(em2, 8, 0, 2, "tank")
    local in_line = Unit.create_basic_unit(em2, 16, 1, 2, "tank")
    local wide = Unit.create_basic_unit(em2, 8, 8, 2, "tank")
    local full = hp(em2, front)
    effects2:process_ability_activation(event_for(em2, c2, spear, {front}))
    assert_near(full - hp(em2, in_line), 22 * 0.5, "The spear runs through to the enemy behind")
    assert(hp(em2, wide) == full, "But not to one beside")

    -- A plain sword strikes one enemy.
    local em3 = EntityManager:new()
    local effects3 = AbilityEffectSystem:new(em3, {random = function() return 0.99 end})
    local c3 = Unit.create_basic_unit(em3, 0, 0, 1, "melee")
    local a = Unit.create_basic_unit(em3, 8, 0, 2, "tank")
    local b = Unit.create_basic_unit(em3, 8, 2, 2, "tank")
    effects3:process_ability_activation(event_for(em3, c3, AbilityFactory.create("primary_melee_attack"), {a}))
    assert(hp(em3, a) < em3:get_component(a, "health").max_hp, "The sword hits its target")
    assert(hp(em3, b) == em3:get_component(b, "health").max_hp, "No cleave without cleave_targets")
    print("✓ Cleave test passed")
end
-- }}}

-- {{{ TestSuite.test_drop_off_factor
function TestSuite.test_drop_off_factor()
    local bow = Ability.new({type = "damage", range = 30, power = 20, drop_off_distance = 20})
    assert_near(bow:drop_off_factor(10), 1, "Full damage up close")
    assert_near(bow:drop_off_factor(20), 1, "Full damage at the drop-off distance")
    assert_near(bow:drop_off_factor(25), 0.85, "Halfway out, halfway down")
    assert_near(bow:drop_off_factor(30), 0.7, "70% at full range")
    assert_near(bow:drop_off_factor(40), 0.7, "Never below the floor")
    local plain = Ability.new({type = "damage", range = 30})
    assert_near(plain:drop_off_factor(30), 1, "No drop-off unless asked for")
    assert_near(bow:calculate_effect(nil, 1, {distance = 30}).amount, 14, "Damage uses the factor")
    print("✓ Drop-off factor test passed")
end
-- }}}

-- {{{ TestSuite.test_projectile_accuracy_and_drop_off
function TestSuite.test_projectile_accuracy_and_drop_off()
    -- The first roll misses the near enemy; the arrow flies on and hits
    -- the far one, weakened by the distance.
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em, {random = sequence(0.99, 0.0)})
    local bow = Ability.new({type = "damage", delivery = "projectile", projectile_speed = 100, range = 30,
        power = 20, accuracy = 0.9, drop_off_distance = 20})
    local archer = Unit.create_basic_unit(em, 0, 0, 1, "ranged")
    local near = Unit.create_basic_unit(em, 10, 0, 2, "tank")
    local far = Unit.create_basic_unit(em, 30, 0, 2, "tank")
    local start = hp(em, near)
    effects:process_ability_activation(event_for(em, archer, bow, {near}))
    for _ = 1, 40 do
        effects:update(1 / 20)
    end
    assert(hp(em, near) == start, "The missed enemy is untouched")
    -- The arrow reaches it some 24-30 out, past the drop-off at 20.
    local taken = start - hp(em, far)
    assert(taken >= 14 - 1e-6 and taken <= 20 * 0.9, "The far enemy takes weakened damage")
    assert(effects.stats.projectile_misses == 1 and effects.stats.projectile_hits == 1, "One miss, one hit")
    local kinds = {}
    for _, cue in ipairs(effects:pop_cues()) do kinds[cue.kind] = true end
    assert(kinds.projectile_miss, "A miss leaves a cue")

    -- A perfectly accurate shot never rolls for a miss.
    local rolls = 0
    local em2 = EntityManager:new()
    local effects2 = AbilityEffectSystem:new(em2, {random = function() rolls = rolls + 1 return 0.99 end})
    local sure = Ability.new({type = "damage", delivery = "projectile", projectile_speed = 100, range = 30, power = 20})
    local a2 = Unit.create_basic_unit(em2, 0, 0, 1, "ranged")
    local t2 = Unit.create_basic_unit(em2, 10, 0, 2, "tank")
    effects2:process_ability_activation(event_for(em2, a2, sure, {t2}))
    for _ = 1, 10 do effects2:update(1 / 20) end
    assert(rolls == 0, "No accuracy roll at accuracy 1")
    assert(effects2.stats.projectile_hits == 1, "And it hits")

    -- Over many shots, the miss rate follows the accuracy.
    local em3 = EntityManager:new()
    local seed = 12345
    local function lcg()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end
    local effects3 = AbilityEffectSystem:new(em3, {random = lcg})
    local sling = AbilityFactory.create("sling_attack")      -- accuracy 0.9
    local slinger = Unit.create_basic_unit(em3, 0, 0, 1, "ranged")
    local target = Unit.create_basic_unit(em3, 10, 0, 2, "tank")
    em3:get_component(target, "health").max_hp = 1e9
    em3:get_component(target, "health").current_hp = 1e9
    for _ = 1, 400 do
        effects3:process_ability_activation(event_for(em3, slinger, sling, {target}))
        for _ = 1, 5 do effects3:update(1 / 20) end
    end
    local rate = effects3.stats.projectile_misses / 400
    print(string.format("  sling miss rate over 400 shots: %.3f", rate))
    assert(rate > 0.05 and rate < 0.16, "About one sling stone in ten misses")
    print("✓ Projectile accuracy and drop-off test passed")
end
-- }}}

-- {{{ TestSuite.test_emergency_heal
function TestSuite.test_emergency_heal()
    local em = EntityManager:new()
    local healer = Unit.create_basic_unit(em, 0, 0, 1, "support")
    local ally = Unit.create_basic_unit(em, 10, 0, 1, "melee")
    local far_ally = Unit.create_basic_unit(em, 100, 0, 1, "melee")
    local enemy = Unit.create_basic_unit(em, 5, 0, 2, "melee")
    local heal = AbilityFactory.create("emergency_heal")
    local ally_health = em:get_component(ally, "health")
    local far_health = em:get_component(far_ally, "health")
    local enemy_health = em:get_component(enemy, "health")
    local bar = {current = heal.max_mana, max = heal.max_mana}

    ally_health.current_hp = ally_health.max_hp * 0.5
    far_health.current_hp = far_health.max_hp * 0.1
    enemy_health.current_hp = enemy_health.max_hp * 0.1
    local state = UnitAbilities.unit_state(em, healer)
    assert_near(state.lowest_ally_health(30), 0.5, "The weakest ally in reach is at half")
    assert(not heal:can_activate(bar, state), "Half health is no emergency; far allies and enemies don't count")

    ally_health.current_hp = ally_health.max_hp * 0.2
    state = UnitAbilities.unit_state(em, healer)
    assert(heal:can_activate(bar, state), "An ally under 30% sets it off")
    local emergency = heal:calculate_effect({current_health = 20, max_health = 100}, 1, {})
    local plain = AbilityFactory.create("minor_heal"):calculate_effect({current_health = 20, max_health = 100}, 1, {})
    assert(emergency.amount > plain.amount, "It heals a badly hurt unit harder than a minor heal")

    local alone = Unit.create_basic_unit(em, 500, 500, 3, "support")
    assert(UnitAbilities.unit_state(em, alone).lowest_ally_health(30) == nil, "No allies, no reading")
    print("✓ Emergency heal test passed")
end
-- }}}

-- {{{ TestSuite.test_weakness_curse
function TestSuite.test_weakness_curse()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em)
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "support")
    local enemy = Unit.create_basic_unit(em, 10, 0, 2, "melee")
    local curse = AbilityFactory.create("weakness_curse")
    effects:process_ability_activation(event_for(em, caster, curse, {enemy}))
    assert_near(effects:get_stat(enemy, "attack"), 0.7, "The curse takes 30% of attack")
    assert_near(effects:get_stat(enemy, "healing_power"), 0.7, "And 30% of healing")
    effects:update(8.1)
    assert_near(effects:get_stat(enemy, "attack"), 1, "It wears off")
    print("✓ Weakness curse test passed")
end
-- }}}

-- {{{ TestSuite.test_static_field_zone
function TestSuite.test_static_field_zone()
    local em = EntityManager:new()
    local effects = AbilityEffectSystem:new(em, {random = function() return 0.99 end})
    local persistent = PersistentEffectsSystem:new(em, effects)
    local mage = Unit.create_basic_unit(em, 0, 0, 1, "special")
    local inside = Unit.create_basic_unit(em, 30, 0, 2, "tank")
    local walker = Unit.create_basic_unit(em, 40, 0, 2, "tank")
    local outside = Unit.create_basic_unit(em, 80, 0, 2, "tank")
    local friend = Unit.create_basic_unit(em, 32, 0, 1, "tank")
    local field = AbilityFactory.create("static_field")
    local center = {x = 30, y = 0}
    local start = hp(em, inside)
    local base_speed = em:get_component(inside, "moveable").speed

    effects:process_ability_activation(event_for(em, mage, field, {inside, walker}, center))
    assert(#persistent:get_zones() == 1, "The field stays on the ground")
    local after_cast = hp(em, inside)
    assert(after_cast < start, "The cast itself does its instant damage")

    -- One second in: a pulse damages and slows those inside.
    effects:update(1.0)
    persistent:update(1.0)
    assert_near(after_cast - hp(em, inside), 6, "A pulse deals zone_power", 1e-6)
    assert_near(em:get_component(inside, "moveable").speed, base_speed * 0.6, "And slows by 40%")
    assert(hp(em, friend) == em:get_component(friend, "health").max_hp, "Allies stand in it unharmed")
    assert(hp(em, outside) == start, "Units outside are untouched")

    -- The walker leaves; its slow fades within a pulse and a half.
    em:get_component(walker, "position").x = 90
    local walker_hp = hp(em, walker)
    for _ = 1, 2 do
        effects:update(1.0)
        persistent:update(1.0)
    end
    assert(hp(em, walker) == walker_hp, "No pulses reach a unit that walked out")
    assert_near(em:get_component(walker, "moveable").speed, base_speed, "Its slow has worn off")
    assert_near(em:get_component(inside, "moveable").speed, base_speed * 0.6, "The one inside stays slowed")

    for _ = 1, 4 do
        effects:update(1.0)
        persistent:update(1.0)
    end
    assert(#persistent:get_zones() == 0, "The field ends after six seconds")
    assert(persistent.stats.zone_pulses == 6, "Six pulses, one a second")
    assert_near(after_cast - hp(em, inside), 36, "Six pulses of six damage", 1e-6)
    effects:update(2.0)
    assert_near(em:get_component(inside, "moveable").speed, base_speed, "Its slow fades once the field is gone")
    print("✓ Static field zone test passed")
end
-- }}}

-- {{{ TestSuite.test_area_line_of_sight
function TestSuite.test_area_line_of_sight()
    local em = EntityManager:new()
    -- A wall along x = 50 between y = 5 and y = 100.
    local function blocked(x1, y1, x2, y2)
        if (x1 - 50) * (x2 - 50) >= 0 then
            return false
        end
        local t = (50 - x1) / (x2 - x1)
        local y = y1 + (y2 - y1) * t
        return y >= 5 and y <= 100
    end
    local targeting = TargetingSystem:new(em, {blocked = blocked})
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "special")
    Unit.create_basic_unit(em, 40, 10, 2, "melee")
    Unit.create_basic_unit(em, 42, 14, 2, "melee")
    local hidden = Unit.create_basic_unit(em, 58, 12, 2, "melee")
    local meteor = AbilityFactory.create("meteor_strike", {max_targets = 10})
    local targets = targeting:find_targets(caster, meteor)
    assert(#targets == 2, "The wall shields the unit behind it")
    for _, target in ipairs(targets) do
        assert(target.entity ~= hidden, "The hidden unit isn't hit")
    end

    meteor.line_of_sight = false
    targeting:invalidate()
    local all = targeting:find_targets(caster, meteor)
    assert(#all == 3, "Without line of sight the blast reaches all three")
    print("✓ Area line of sight test passed")
end
-- }}}

-- {{{ TestSuite.test_templates_build
function TestSuite.test_templates_build()
    for _, name in ipairs(AbilityFactory.template_names()) do
        local ability = AbilityFactory.create(name)
        assert(Ability.is_ability(ability), name .. " builds")
    end
    for set_name in pairs(AbilityTemplates.sets) do
        assert(#AbilityFactory.create_set(set_name) > 0, set_name .. " builds")
    end
    print("✓ Template build test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running ability variant tests...")
    TestSuite.test_weapon_templates_differ()
    TestSuite.test_cleave()
    TestSuite.test_drop_off_factor()
    TestSuite.test_projectile_accuracy_and_drop_off()
    TestSuite.test_emergency_heal()
    TestSuite.test_weakness_curse()
    TestSuite.test_static_field_zone()
    TestSuite.test_area_line_of_sight()
    TestSuite.test_templates_build()
    print("✅ All ability variant tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
