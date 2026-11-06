-- {{{ Unit Teams Test Suite
-- Checks Unit.are_enemies and the combat detection that calls it. The
-- second parameter used to be named entity2 while the body read unit2, an
-- undefined global, so every call raised an error inside the entity
-- manager. These tests fail on that code.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_unit_teams').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Unit = require("src.entities.unit")

-- {{{ local function with_love_timer
-- Combat detection stamps targets with love.timer.getTime(); give it a
-- stand-in clock when LÖVE is not running, and put things back afterwards.
local function with_love_timer(fn)
    local had_love = rawget(_G, "love")
    if not had_love then
        _G.love = {timer = {getTime = function() return 0 end}}
    end
    local ok, err = pcall(fn)
    if not had_love then
        _G.love = nil
    end
    if not ok then
        error(err, 0)
    end
end
-- }}}

-- {{{ TestSuite.test_are_enemies
function TestSuite.test_are_enemies()
    local em = EntityManager:new()
    local blue_a = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    local blue_b = Unit.create_basic_unit(em, 5, 0, 1, "ranged")
    local red = Unit.create_basic_unit(em, 10, 0, 2, "melee")
    local no_team = em:create_entity("rock")

    assert(Unit.are_enemies(em, blue_a, red) == true, "Different teams are enemies")
    assert(Unit.are_enemies(em, red, blue_a) == true, "Enmity runs both ways")
    assert(Unit.are_enemies(em, blue_a, blue_b) == false, "Teammates are not enemies")
    assert(Unit.are_enemies(em, blue_a, no_team) == false, "Something without a team is nobody's enemy")
    assert(Unit.are_enemies(em, blue_a, nil) == false, "A missing unit is nobody's enemy")

    print("✓ are_enemies test passed")
end
-- }}}

-- {{{ TestSuite.test_combat_detection_finds_enemies
function TestSuite.test_combat_detection_finds_enemies()
    local CombatDetectionSystem = require("src.systems.combat_detection_system")
    local em = EntityManager:new()
    local blue = Unit.create_basic_unit(em, 100, 100, 1, "melee")
    Unit.create_basic_unit(em, 105, 100, 1, "melee")        -- a teammate beside it
    local red = Unit.create_basic_unit(em, 112, 100, 2, "melee")

    with_love_timer(function()
        local detection = CombatDetectionSystem:new(em)
        detection:update_spatial_grid()
        local position = em:get_component(blue, "position")
        local targets = detection:find_potential_targets(blue, position, 20)
        assert(#targets == 1, "Only the enemy is a potential target, got " .. #targets)
        assert(targets[1].unit == red, "The potential target is the red unit")
    end)

    print("✓ Combat detection finds enemies test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Unit Teams Tests...")
    print(string.rep("=", 40))

    TestSuite.test_are_enemies()
    TestSuite.test_combat_detection_finds_enemies()

    print(string.rep("=", 40))
    print("✅ All unit teams tests passed!")
end
-- }}}

return TestSuite
-- }}}
