--[[
Unit tests for the Gathering System (Issue 702b)

Tests cover:
- Node creation and management
- Gathering flow (start, cancel, complete)
- Node depletion and respawn
- Integration with professions
- Node type templates
]]

-- {{{ Configuration
local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

local ecs = require("runtime.ecs")
local events = require("runtime.events")
local professions = require("runtime.systems.professions")
local gathering = require("runtime.systems.gathering")

-- ============================================================================
-- Test Harness
-- ============================================================================

-- {{{ Test state
local tests_run = 0
local tests_passed = 0
local current_test = ""
-- }}}

-- {{{ assert_eq
local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected: " .. tostring(expected))
        print("    Actual: " .. tostring(actual))
        return false
    end
    return true
end
-- }}}

-- {{{ assert_true
local function assert_true(value, msg)
    if not value then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected truthy value, got: " .. tostring(value))
        return false
    end
    return true
end
-- }}}

-- {{{ assert_false
local function assert_false(value, msg)
    if value then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected falsy value, got: " .. tostring(value))
        return false
    end
    return true
end
-- }}}

-- {{{ assert_nil
local function assert_nil(value, msg)
    if value ~= nil then
        print("  FAIL: " .. (msg or current_test))
        print("    Expected nil, got: " .. tostring(value))
        return false
    end
    return true
end
-- }}}

-- {{{ Initialize systems once
professions.init()
gathering.init()
-- }}}

-- {{{ run_test
local function run_test(name, fn)
    current_test = name
    tests_run = tests_run + 1

    -- Reset state before each test
    ecs.reset()
    events.reset()
    professions.reset()
    gathering.reset()

    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  PASS: " .. name)
    else
        print("  FAIL: " .. name)
        print("    Error: " .. tostring(err))
    end
end
-- }}}

-- ============================================================================
-- Test Helpers
-- ============================================================================

-- {{{ create_test_entity
local function create_test_entity()
    local entity = ecs.create_entity()
    ecs.add_component(entity, "professions")
    ecs.add_component(entity, "gathering_state")
    return entity
end
-- }}}

-- {{{ create_test_node
local function create_test_node(resource_type, profession, skill_req)
    return gathering.create_node(nil, nil, {
        resource_type = resource_type or "mineral",
        profession_required = profession or "mining",
        skill_required = skill_req or 1,
        resource_id = "test_ore",
        yield_min = 1,
        yield_max = 3,
        remaining_gathers = 3,
        max_gathers = 3,
        respawn_time = 60,
        channel_time = 0,  -- Instant for testing
    })
end
-- }}}

-- ============================================================================
-- Node Management Tests
-- ============================================================================

print("\n=== Node Management Tests ===")

-- {{{ test: create node with template
run_test("create node with template", function()
    local node = gathering.create_node(nil, "copper_vein")
    assert_true(node ~= nil, "Node should be created")

    local info = gathering.get_node_info(node)
    assert_eq(info.resource_type, "mineral")
    assert_eq(info.profession, "mining")
    assert_eq(info.skill_required, 1)
    assert_eq(info.resource_id, "copper_ore")
end)
-- }}}

-- {{{ test: create custom node
run_test("create custom node", function()
    local node = gathering.create_node(nil, nil, {
        resource_type = "plant",
        profession_required = "herbalism",
        skill_required = 50,
        resource_id = "custom_herb",
        yield_min = 2,
        yield_max = 5,
    })

    local info = gathering.get_node_info(node)
    assert_eq(info.resource_type, "plant")
    assert_eq(info.profession, "herbalism")
    assert_eq(info.skill_required, 50)
    assert_eq(info.resource_id, "custom_herb")
end)
-- }}}

-- {{{ test: node is available by default
run_test("node is available by default", function()
    local node = create_test_node()
    local available, err = gathering.is_node_available(node)
    assert_true(available, "Node should be available")
end)
-- }}}

-- {{{ test: depleted node is not available
run_test("depleted node is not available", function()
    local node = create_test_node()
    gathering.deplete_node(node)

    local available, err = gathering.is_node_available(node)
    assert_false(available, "Depleted node should not be available")
    assert_eq(err, "Node depleted")
end)
-- }}}

-- {{{ test: deplete node schedules respawn
run_test("deplete node schedules respawn", function()
    local node = create_test_node()
    local comp = ecs.get_component(node, "gatherable")

    local will_respawn = gathering.deplete_node(node)
    assert_true(will_respawn, "Node should schedule respawn")
    assert_true(comp.respawn_at > os.time(), "Respawn time should be in future")
end)
-- }}}

-- {{{ test: respawn node restores gathers
run_test("respawn node restores gathers", function()
    local node = create_test_node()
    gathering.deplete_node(node)

    local respawned = gathering.respawn_node(node)
    assert_true(respawned, "Node should respawn")

    local info = gathering.get_node_info(node)
    assert_false(info.depleted, "Node should no longer be depleted")
    assert_eq(info.remaining_gathers, info.max_gathers, "Gathers should be restored")
end)
-- }}}

-- {{{ test: get_node_info returns correct data
run_test("get_node_info returns correct data", function()
    local node = gathering.create_node(nil, "iron_deposit")
    local info = gathering.get_node_info(node)

    assert_eq(info.resource_id, "iron_ore")
    assert_eq(info.skill_required, 65)
    assert_eq(info.max_gathers, 3)
    assert_true(info.respawns, "Iron deposits should respawn")
end)
-- }}}

-- ============================================================================
-- Gathering Flow Tests
-- ============================================================================

print("\n=== Gathering Flow Tests ===")

-- {{{ test: can_gather checks profession
run_test("can_gather checks profession", function()
    local entity = create_test_entity()
    local node = create_test_node("mineral", "mining", 1)

    -- Don't have the profession
    local can, err = gathering.can_gather(entity, node)
    assert_false(can, "Should not be able to gather without profession")
    assert_true(err:find("Profession not learned"))

    -- Learn the profession
    professions.learn_profession(entity, "mining")
    can, err = gathering.can_gather(entity, node)
    assert_true(can, "Should be able to gather with profession")
end)
-- }}}

-- {{{ test: can_gather checks skill level
run_test("can_gather checks skill level", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    local node = create_test_node("mineral", "mining", 100)

    -- Skill too low (starts at 1)
    local can, err = gathering.can_gather(entity, node)
    assert_false(can, "Should not be able to gather with low skill")
    assert_eq(err, "Skill too low")

    -- Raise skill
    professions.add_skill(entity, "mining", 100)
    can, err = gathering.can_gather(entity, node)
    assert_true(can, "Should be able to gather with sufficient skill")
end)
-- }}}

-- {{{ test: can_gather checks node availability
run_test("can_gather checks node availability", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    local node = create_test_node()

    -- Node is available
    local can = gathering.can_gather(entity, node)
    assert_true(can)

    -- Deplete the node
    gathering.deplete_node(node)
    can, err = gathering.can_gather(entity, node)
    assert_false(can, "Cannot gather from depleted node")
    assert_eq(err, "Node depleted")
end)
-- }}}

-- {{{ test: start_gather with instant node
run_test("start_gather with instant node", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    local node = create_test_node()

    local ok, result = gathering.start_gather(entity, node)
    assert_true(ok, "Gather should start (and complete instantly)")

    -- For instant gathers, result is returned immediately
    if result then
        assert_eq(result.resource, "test_ore")
        assert_true(result.quantity >= 1 and result.quantity <= 3)
    end
end)
-- }}}

-- {{{ test: gather decrements node gathers
run_test("gather decrements node gathers", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    local node = create_test_node()

    local info = gathering.get_node_info(node)
    local initial_gathers = info.remaining_gathers

    gathering.start_gather(entity, node)

    info = gathering.get_node_info(node)
    assert_eq(info.remaining_gathers, initial_gathers - 1)
end)
-- }}}

-- {{{ test: gather depletes node when exhausted
run_test("gather depletes node when exhausted", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    local node = gathering.create_node(nil, nil, {
        resource_type = "mineral",
        profession_required = "mining",
        skill_required = 1,
        resource_id = "test_ore",
        yield_min = 1,
        yield_max = 1,
        remaining_gathers = 1,
        max_gathers = 1,
        respawn_time = 60,
        channel_time = 0,
    })

    local info = gathering.get_node_info(node)
    assert_false(info.depleted, "Node should not be depleted initially")

    gathering.start_gather(entity, node)

    info = gathering.get_node_info(node)
    assert_true(info.depleted, "Node should be depleted after last gather")
end)
-- }}}

-- {{{ test: cancel_gather works
run_test("cancel_gather works", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")

    -- Create a node with channel time
    local node = gathering.create_node(nil, nil, {
        resource_type = "mineral",
        profession_required = "mining",
        skill_required = 1,
        resource_id = "slow_ore",
        yield_min = 1,
        yield_max = 1,
        remaining_gathers = 3,
        channel_time = 100,  -- Long channel
    })

    gathering.start_gather(entity, node)
    local state = gathering.get_gather_state(entity)
    assert_eq(state.state, gathering.STATE.GATHERING)

    local cancelled = gathering.cancel_gather(entity)
    assert_true(cancelled, "Should be able to cancel")

    state = gathering.get_gather_state(entity)
    assert_eq(state.state, gathering.STATE.IDLE)
    assert_nil(state.node)
end)
-- }}}

-- {{{ test: cannot start gather while already gathering
run_test("cannot start gather while already gathering", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")

    local node = gathering.create_node(nil, nil, {
        resource_type = "mineral",
        profession_required = "mining",
        skill_required = 1,
        resource_id = "slow_ore",
        yield_min = 1,
        yield_max = 1,
        remaining_gathers = 5,
        channel_time = 100,
    })

    gathering.start_gather(entity, node)
    local ok, err = gathering.start_gather(entity, node)
    assert_false(ok, "Should not be able to start another gather")
    assert_eq(err, "Already gathering")
end)
-- }}}

-- {{{ test: gather fires events
run_test("gather fires events", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    local node = create_test_node()

    local started = false
    local succeeded = false

    local start_trigger = {
        events = {},
        fire = function(self, data)
            started = true
            assert_eq(data.entity, entity)
            assert_eq(data.node, node)
        end,
    }

    local success_trigger = {
        events = {},
        fire = function(self, data)
            succeeded = true
            assert_eq(data.entity, entity)
            assert_eq(data.node, node)
            assert_eq(data.resource, "test_ore")
        end,
    }

    events.register(gathering.EVENT.GATHER_START, start_trigger)
    events.register(gathering.EVENT.GATHER_SUCCESS, success_trigger)

    gathering.start_gather(entity, node)
    assert_true(started, "GATHER_START should fire")
    assert_true(succeeded, "GATHER_SUCCESS should fire")
end)
-- }}}

-- {{{ test: get_gather_state returns correct info
run_test("get_gather_state returns correct info", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")

    local state = gathering.get_gather_state(entity)
    assert_eq(state.state, gathering.STATE.IDLE)

    local node = gathering.create_node(nil, nil, {
        resource_type = "mineral",
        profession_required = "mining",
        skill_required = 1,
        resource_id = "slow_ore",
        yield_min = 1,
        yield_max = 1,
        remaining_gathers = 3,
        channel_time = 100,
    })

    gathering.start_gather(entity, node)
    state = gathering.get_gather_state(entity)
    assert_eq(state.state, gathering.STATE.GATHERING)
    assert_eq(state.node, node)
end)
-- }}}

-- ============================================================================
-- Integration Tests
-- ============================================================================

print("\n=== Integration Tests ===")

-- {{{ test: gather attempts skill up
run_test("gather attempts skill up", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")

    local node = gathering.create_node(nil, nil, {
        resource_type = "mineral",
        profession_required = "mining",
        skill_required = 1,
        resource_id = "copper_ore",
        yield_min = 1,
        yield_max = 1,
        remaining_gathers = 20,
        channel_time = 0,
        gives_skillup = true,
        skillup_max = 100,
    })

    local initial_skill = professions.get_skill(entity, "mining")

    -- Gather many times
    for i = 1, 10 do
        local comp = ecs.get_component(node, "gatherable")
        if comp.remaining_gathers > 0 then
            gathering.start_gather(entity, node)
        end
    end

    local final_skill = professions.get_skill(entity, "mining")
    assert_true(final_skill > initial_skill, "Skill should increase from gathering")
end)
-- }}}

-- {{{ test: bonus resource procs
run_test("bonus resource procs", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")

    local node = gathering.create_node(nil, nil, {
        resource_type = "mineral",
        profession_required = "mining",
        skill_required = 1,
        resource_id = "iron_ore",
        yield_min = 1,
        yield_max = 1,
        bonus_chance = 1.0,  -- 100% chance for testing
        bonus_resource = "heavy_stone",
        remaining_gathers = 1,
        channel_time = 0,
    })

    local ok, result = gathering.start_gather(entity, node)
    assert_true(ok)
    assert_eq(result.bonus, "heavy_stone", "Bonus should proc at 100%")
end)
-- }}}

-- {{{ test: no skill up past skillup_max
run_test("no skill up past skillup_max", function()
    local entity = create_test_entity()
    professions.learn_profession(entity, "mining")
    professions.add_skill(entity, "mining", 100)

    local node = gathering.create_node(nil, nil, {
        resource_type = "mineral",
        profession_required = "mining",
        skill_required = 1,
        resource_id = "copper_ore",
        yield_min = 1,
        yield_max = 1,
        remaining_gathers = 10,
        channel_time = 0,
        gives_skillup = true,
        skillup_max = 50,  -- Below current skill
    })

    local initial_skill = professions.get_skill(entity, "mining")

    gathering.start_gather(entity, node)

    local final_skill = professions.get_skill(entity, "mining")
    assert_eq(final_skill, initial_skill, "Should not skill up past skillup_max")
end)
-- }}}

-- {{{ test: node depleted event fires
run_test("node depleted event fires", function()
    local node = create_test_node()
    local depleted_fired = false

    local trigger = {
        events = {},
        fire = function(self, data)
            depleted_fired = true
            assert_eq(data.node, node)
        end,
    }

    events.register(gathering.EVENT.NODE_DEPLETED, trigger)
    gathering.deplete_node(node)
    assert_true(depleted_fired, "NODE_DEPLETED should fire")
end)
-- }}}

-- {{{ test: node respawn event fires
run_test("node respawn event fires", function()
    local node = create_test_node()
    gathering.deplete_node(node)

    local respawned_fired = false
    local trigger = {
        events = {},
        fire = function(self, data)
            respawned_fired = true
            assert_eq(data.node, node)
        end,
    }

    events.register(gathering.EVENT.NODE_RESPAWNED, trigger)
    gathering.respawn_node(node)
    assert_true(respawned_fired, "NODE_RESPAWNED should fire")
end)
-- }}}

-- ============================================================================
-- Node Type Template Tests
-- ============================================================================

print("\n=== Node Type Template Tests ===")

-- {{{ test: copper vein template
run_test("copper vein template", function()
    local node = gathering.create_node(nil, "copper_vein")
    local info = gathering.get_node_info(node)

    assert_eq(info.resource_id, "copper_ore")
    assert_eq(info.profession, "mining")
    assert_eq(info.skill_required, 1)
    assert_eq(info.max_gathers, 3)
end)
-- }}}

-- {{{ test: iron deposit template
run_test("iron deposit template", function()
    local node = gathering.create_node(nil, "iron_deposit")
    local info = gathering.get_node_info(node)

    assert_eq(info.resource_id, "iron_ore")
    assert_eq(info.skill_required, 65)
end)
-- }}}

-- {{{ test: peacebloom template
run_test("peacebloom template", function()
    local node = gathering.create_node(nil, "peacebloom")
    local info = gathering.get_node_info(node)

    assert_eq(info.resource_type, "plant")
    assert_eq(info.profession, "herbalism")
    assert_eq(info.resource_id, "peacebloom")
    assert_eq(info.max_gathers, 1)  -- Herbs are single-gather
end)
-- }}}

-- {{{ test: gold mine template (WC3)
run_test("gold mine template (WC3)", function()
    local node = gathering.create_node(nil, "gold_mine")
    local info = gathering.get_node_info(node)

    assert_eq(info.resource_id, "gold")
    assert_nil(info.profession, "Gold mines don't require profession")
    assert_eq(info.skill_required, 0)
    assert_eq(info.remaining_gathers, 999999)  -- Effectively infinite
end)
-- }}}

-- {{{ test: template with config override
run_test("template with config override", function()
    local node = gathering.create_node(nil, "copper_vein", {
        yield_min = 5,  -- Override template
        yield_max = 10,
    })

    local comp = ecs.get_component(node, "gatherable")
    assert_eq(comp.yield_min, 5, "Config should override template")
    assert_eq(comp.yield_max, 10, "Config should override template")
    assert_eq(comp.resource_id, "copper_ore", "Template values should still apply")
end)
-- }}}

-- ============================================================================
-- Profession Definition Tests
-- ============================================================================

print("\n=== Profession Definition Tests ===")

-- {{{ test: profession definitions exist
run_test("profession definitions exist", function()
    assert_true(gathering.PROFESSION_DEFS.mining ~= nil)
    assert_true(gathering.PROFESSION_DEFS.herbalism ~= nil)
    assert_true(gathering.PROFESSION_DEFS.skinning ~= nil)
    assert_true(gathering.PROFESSION_DEFS.lumber ~= nil)
    assert_true(gathering.PROFESSION_DEFS.fishing ~= nil)
end)
-- }}}

-- {{{ test: get_profession_def returns correct data
run_test("get_profession_def returns correct data", function()
    local mining = gathering.get_profession_def("mining")
    assert_eq(mining.id, "mining")
    assert_eq(mining.name, "Mining")
    assert_eq(mining.type, "gathering")
    assert_eq(mining.tool, "mining_pick")
end)
-- }}}

-- {{{ test: profession has tiers
run_test("profession has tiers", function()
    local mining = gathering.get_profession_def("mining")
    assert_true(#mining.tiers >= 5, "Mining should have multiple tiers")
    assert_eq(mining.tiers[1].skill, 1)
    assert_true(#mining.tiers[1].nodes >= 2)
end)
-- }}}

-- {{{ test: skinning has level formula
run_test("skinning has level formula", function()
    local skinning = gathering.get_profession_def("skinning")
    assert_true(type(skinning.level_formula) == "function")
    assert_eq(skinning.level_formula(10), 50)  -- Level 10 mob = 50 skill
end)
-- }}}

-- ============================================================================
-- Summary
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("Passed: %d / %d", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print("Some tests failed.")
    os.exit(1)
end
