-- {{{ Targeting Test Suite
-- Checks issue 047 without a window: each targeting type finds the right
-- units, line of sight blocks targets behind obstacles, priorities order
-- targets, area abilities find the best centre, results are cached within
-- a frame, and three hundred units stay cheap.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_targeting').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Unit = require("src.entities.unit")
local Ability = require("src.components.ability")
local TargetingSystem = require("src.systems.targeting_system")
local ManaEfficiency = require("src.systems.mana_efficiency")

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function setup
local function setup(options)
    local em = EntityManager:new()
    local targeting = TargetingSystem:new(em, options)
    return em, targeting
end
-- }}}

-- {{{ local function hurt
local function hurt(em, unit, fraction_left)
    local health = em:get_component(unit, "health")
    health.current_hp = health.max_hp * fraction_left
end
-- }}}

-- {{{ TestSuite.test_enemy_targeting
function TestSuite.test_enemy_targeting()
    local em, targeting = setup()
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "ranged")
    local near = Unit.create_basic_unit(em, 20, 0, 2, "melee")
    local far = Unit.create_basic_unit(em, 40, 0, 2, "melee")
    Unit.create_basic_unit(em, 80, 0, 2, "melee")            -- out of range
    Unit.create_basic_unit(em, 5, 0, 1, "melee")             -- an ally
    local dead = Unit.create_basic_unit(em, 10, 0, 2, "melee")
    Unit.damage_unit(em, dead, 10000)

    local shot = Ability.new({type = "damage", range = 50, max_targets = 3})
    targeting:update(0)
    local targets = targeting:find_targets(caster, shot)
    assert(#targets == 2, "Two living enemies in range, got " .. #targets)
    assert(targets[1].entity == near and targets[2].entity == far, "Closest first")
    assert_near(targets[1].distance, 20, "Distance from the caster")
    assert(targets[1].current_health and targets[1].max_health, "Carries health for ManaEfficiency")

    local single = Ability.new({type = "damage", range = 50})
    targets = targeting:find_targets(caster, single)
    assert(#targets == 1 and targets[1].entity == near, "max_targets 1 keeps the best")

    local _, info = targeting:find_targets(caster, Ability.new({type = "damage", range = 10}))
    assert(info.reason == "no_targets", "Nothing in range says why")

    print("✓ Enemy targeting test passed")
end
-- }}}

-- {{{ TestSuite.test_ally_and_self_targeting
function TestSuite.test_ally_and_self_targeting()
    local em, targeting = setup()
    local healer = Unit.create_basic_unit(em, 0, 0, 1, "support")
    local scratched = Unit.create_basic_unit(em, 10, 0, 1, "melee")
    local dying = Unit.create_basic_unit(em, 30, 0, 1, "tank")
    Unit.create_basic_unit(em, 15, 0, 2, "melee")             -- an enemy
    hurt(em, scratched, 0.9)
    hurt(em, dying, 0.2)
    hurt(em, healer, 0.5)

    targeting:update(0)
    local mend = Ability.new({type = "heal", range = 40, max_targets = 3})
    local targets = targeting:find_targets(healer, mend)
    assert(#targets == 3, "Two allies and the healer")
    assert(targets[1].entity == dying and targets[2].entity == healer, "Heals go to the lowest health share first")

    local selfless = Ability.new({type = "heal", range = 40, max_targets = 3, exclude_self = true})
    targets = targeting:find_targets(healer, selfless)
    assert(#targets == 2, "exclude_self leaves the caster out")

    local guard = Ability.new({type = "buff", targeting = "self"})
    targets = targeting:find_targets(healer, guard)
    assert(#targets == 1 and targets[1].entity == healer and targets[1].distance == 0, "Self targeting")

    print("✓ Ally and self targeting test passed")
end
-- }}}

-- {{{ TestSuite.test_line_of_sight
function TestSuite.test_line_of_sight()
    local em, targeting = setup({obstacles = {{x = 10, y = 0, radius = 3}}})
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "ranged")
    local hidden = Unit.create_basic_unit(em, 20, 0, 2, "melee")
    local visible = Unit.create_basic_unit(em, 0, 30, 2, "melee")

    targeting:update(0)
    local targets = targeting:find_targets(caster, Ability.new({type = "damage", range = 50}))
    assert(targets[1].entity == visible, "The nearer enemy behind the rock is skipped")
    assert(targeting.stats.blocked == 1, "One line was blocked")

    targets = targeting:find_targets(caster, Ability.new({type = "damage", range = 50, line_of_sight = false}))
    assert(targets[1].entity == hidden, "An ability that needs no sight ignores the rock")

    local em2, custom = setup({blocked = function(x1, y1, x2, y2) return y2 > 10 end})
    local caster2 = Unit.create_basic_unit(em2, 0, 0, 1, "ranged")
    Unit.create_basic_unit(em2, 0, 30, 2, "melee")
    custom:update(0)
    assert(#custom:find_targets(caster2, Ability.new({type = "damage", range = 50})) == 0, "A custom blocked() is used")

    print("✓ Line of sight test passed")
end
-- }}}

-- {{{ TestSuite.test_priorities
function TestSuite.test_priorities()
    local em, targeting = setup()
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "ranged")
    local tank = Unit.create_basic_unit(em, 10, 0, 2, "tank")
    local support = Unit.create_basic_unit(em, 30, 0, 2, "support")
    local melee = Unit.create_basic_unit(em, 20, 0, 2, "melee")
    hurt(em, melee, 0.1)

    targeting:update(0)
    local function first(priority)
        local ability = Ability.new({type = "damage", range = 50, target_priority = priority})
        return targeting:find_targets(caster, ability)[1].entity
    end
    assert(first("closest") == tank, "closest")
    assert(first("farthest") == support, "farthest")
    assert(first("weakest") == melee, "weakest")
    assert(first("strongest") == tank, "strongest")
    assert(first("lowest_health_percentage") == melee, "lowest_health_percentage")
    local value = Ability.new({type = "damage", range = 50, max_targets = 3, target_priority = "highest_value"})
    local ordered = targeting:find_targets(caster, value)
    assert(TargetingSystem.target_value(ordered[1]) >= TargetingSystem.target_value(ordered[2]), "highest_value")

    -- A debuff skips to targets that don't have it yet.
    em:add_component(tank, "effects", {active = {slow = {remaining = 3}}})
    targeting:update(0)
    local slow = Ability.new({type = "debuff", name = "slow", range = 50, target_priority = "closest"})
    local targets = targeting:find_targets(caster, slow)
    assert(targets[1].entity ~= tank, "The already-slowed tank goes last")

    print("✓ Priorities test passed")
end
-- }}}

-- {{{ TestSuite.test_area_targeting
function TestSuite.test_area_targeting()
    local em, targeting = setup()
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "special")
    Unit.create_basic_unit(em, 30, 0, 2, "melee")                 -- alone
    local middle = Unit.create_basic_unit(em, 0, 60, 2, "melee")  -- a cluster of three
    Unit.create_basic_unit(em, 8, 60, 2, "melee")
    Unit.create_basic_unit(em, -8, 60, 2, "melee")
    Unit.create_basic_unit(em, 0, 62, 1, "melee")                  -- an ally in the cluster

    targeting:update(0)
    local blast = Ability.new({type = "area", range = 80, area_radius = 15, power = 20})
    local targets, info = targeting:find_targets(caster, blast)
    assert(info.center and info.center.x == 0 and info.center.y == 60, "Centre on the cluster")
    assert(#targets == 3, "Three enemies hit, not the ally")
    assert(targets[1].entity == middle and targets[1].distance_from_center == 0, "Nearest the centre first")

    local ground = Ability.new({type = "area", targeting = "ground", range = 80, area_radius = 15})
    local _, ground_info = targeting:find_targets(caster, ground)
    assert(ground_info.center.y == 60, "Ground targeting picks the same point")

    local short = Ability.new({type = "area", range = 40, area_radius = 15})
    _, info = targeting:find_targets(caster, short)
    assert(info.center.x == 30, "Out of reach of the cluster, it takes what it can reach")

    -- Area healing scores missing health, so it centres on the wounded.
    local healer = Unit.create_basic_unit(em, 200, 0, 1, "support")
    local wounded = Unit.create_basic_unit(em, 200, 40, 1, "melee")
    Unit.create_basic_unit(em, 230, 0, 1, "melee")
    hurt(em, wounded, 0.3)
    targeting:update(0)
    local wave = Ability.new({type = "area", area_effect = "heal", range = 50, area_radius = 10})
    targets, info = targeting:find_targets(healer, wave)
    assert(info.center.y == 40 and targets[1].entity == wounded, "Healing centres on the wounded")

    local plan = ManaEfficiency.plan(blast, targeting:find_targets(caster, blast), blast.max_mana)
    assert(plan.can_execute and plan.targets_hit == 3, "Targets go straight into a mana plan")

    print("✓ Area targeting test passed")
end
-- }}}

-- {{{ TestSuite.test_caching
function TestSuite.test_caching()
    local em, targeting = setup()
    local caster = Unit.create_basic_unit(em, 0, 0, 1, "ranged")
    local enemy = Unit.create_basic_unit(em, 20, 0, 2, "melee")
    local shot = Ability.new({type = "damage", range = 30})

    targeting:update(1 / 60)
    targeting:find_targets(caster, shot)
    targeting:find_targets(caster, shot)
    assert(targeting.stats.cache_hits == 1, "The second ask in a frame is cached")

    em:get_component(enemy, "position").x = 100
    targeting:update(1 / 60)
    assert(#targeting:find_targets(caster, shot) == 0, "A new frame sees the enemy left")

    local em2, slow = setup({cache_duration = 0.5})
    local caster2 = Unit.create_basic_unit(em2, 0, 0, 1, "ranged")
    local enemy2 = Unit.create_basic_unit(em2, 20, 0, 2, "melee")
    slow:update(0.1)
    slow:find_targets(caster2, shot)
    em2:get_component(enemy2, "position").x = 100
    slow:update(0.1)
    assert(#slow:find_targets(caster2, shot) == 1, "With cache_duration the result is reused")
    slow:update(0.4)
    assert(#slow:find_targets(caster2, shot) == 0, "Until it runs out")

    print("✓ Caching test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local em, targeting = setup()
    local casters = {}
    for i = 1, 300 do
        local unit = Unit.create_basic_unit(em, (i % 30) * 15, math.floor(i / 30) * 15, (i % 2) + 1, "ranged")
        casters[i] = unit
    end
    local shot = Ability.new({type = "damage", range = 60, max_targets = 3})
    local blast = Ability.new({type = "area", range = 60, area_radius = 20})

    local start = os.clock()
    for _ = 1, 10 do
        targeting:update(1 / 60)
        for i, caster in ipairs(casters) do
            targeting:find_targets(caster, i % 4 == 0 and blast or shot)
        end
    end
    local elapsed = os.clock() - start
    print(string.format("  300 casters, 10 frames: %.3fs", elapsed))
    assert(elapsed < 3.0, "Targeting for 300 units stays cheap")

    print("✓ Performance test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Targeting Tests...")
    print(string.rep("=", 40))

    TestSuite.test_enemy_targeting()
    TestSuite.test_ally_and_self_targeting()
    TestSuite.test_line_of_sight()
    TestSuite.test_priorities()
    TestSuite.test_area_targeting()
    TestSuite.test_caching()
    TestSuite.test_performance()

    print(string.rep("=", 40))
    print("✅ All targeting tests passed!")
end
-- }}}

return TestSuite
-- }}}
