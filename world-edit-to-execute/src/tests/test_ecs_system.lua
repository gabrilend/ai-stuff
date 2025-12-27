--[[
Test suite for ECS System module
Tests system registration, execution, priority ordering, enable/disable, and stats.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local entity = require("runtime.ecs.entity")
local component = require("runtime.ecs.component")
local system = require("runtime.ecs.system")
local ecs = require("runtime.ecs")
-- }}}

-- {{{ Test infrastructure
local test_count = 0
local pass_count = 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

-- reset_all: Reset all ECS state for clean test isolation
-- Each test section should call this to avoid state bleed
local function reset_all()
    entity.reset()
    component.clear_all()
    system.reset()
    -- Force re-registration of destroy hook after clearing
    component.init(true)
end
-- }}}

-- {{{ System Registration Tests
test_section("System Registration - Basic")
reset_all()
component.register("position", {x = 0, y = 0})

local called = false
local sys = system.register("test_system", {"position"}, function(entities, dt)
    called = true
end)

test("register returns system handle", sys ~= nil)
test("system has name", sys.name == "test_system")
test("system has components", sys.components[1] == "position")
test("system has update function", type(sys.update) == "function")
test("system has stats", type(sys.stats) == "table")
test("get_count returns 1", system.get_count() == 1)
test("get returns the system", system.get("test_system") == sys)
test("system enabled by default", sys.enabled == true)
test("is_enabled returns true", system.is_enabled("test_system") == true)

test_section("System Registration - Options")
reset_all()

local sys1 = system.register("default_opts", {}, function() end)
test("default priority is 0", sys1.priority == 0)
test("default enabled is true", sys1.enabled == true)

local sys2 = system.register("custom_opts", {}, function() end, {
    priority = 42,
    enabled = false
})
test("custom priority respected", sys2.priority == 42)
test("custom enabled respected", sys2.enabled == false)

test_section("System Registration - Error Handling")
reset_all()

system.register("existing", {}, function() end)

-- Double registration should error
local ok, err = pcall(function()
    system.register("existing", {}, function() end)
end)
test("double registration errors", not ok)
test("error message mentions name", err and err:find("existing"))

-- Invalid arguments should error
ok = pcall(function()
    system.register(123, {}, function() end)
end)
test("non-string name errors", not ok)

ok = pcall(function()
    system.register("valid", "not a table", function() end)
end)
test("non-table components errors", not ok)

ok = pcall(function()
    system.register("valid2", {}, "not a function")
end)
test("non-function update errors", not ok)
-- }}}

-- {{{ System Execution Tests
test_section("System Execution - Basic")
reset_all()
component.register("position", {x = 0, y = 0})

local update_calls = 0
local received_dt = nil
local processed_entities = 0

system.register("counter", {"position"}, function(entities, dt)
    update_calls = update_calls + 1
    received_dt = dt
    for e in entities do
        processed_entities = processed_entities + 1
    end
end)

-- No entities yet
local ran = system.update(0.016)
test("update returns 1 (system ran)", ran == 1)
test("system was called", update_calls == 1)
test("received correct dt", received_dt == 0.016)
test("processed 0 entities (none exist)", processed_entities == 0)

-- Add some entities
local e1 = entity.create()
local e2 = entity.create()
local e3 = entity.create()
component.add(e1, "position")
component.add(e2, "position")
-- e3 has no position

update_calls = 0
processed_entities = 0
ran = system.update(0.032)
test("second update returns 1", ran == 1)
test("update_calls incremented", update_calls == 1)
test("received new dt", received_dt == 0.032)
test("processed 2 entities (with position)", processed_entities == 2)

test_section("System Execution - Multiple Components")
reset_all()
component.register("position", {x = 0, y = 0})
component.register("velocity", {vx = 0, vy = 0})
component.register("name", {name = ""})

local matched_count = 0
system.register("movement", {"position", "velocity"}, function(entities, dt)
    for e, pos, vel in entities do
        matched_count = matched_count + 1
        -- Verify we got both components
        test("entity is number", type(e) == "number")
        test("pos has x", pos.x ~= nil)
        test("vel has vx", vel.vx ~= nil)
    end
end)

local e1 = entity.create()
local e2 = entity.create()
local e3 = entity.create()

component.add(e1, "position")  -- Missing velocity
component.add(e2, "position")
component.add(e2, "velocity")  -- Has both
component.add(e3, "velocity")  -- Missing position

system.update(0)
test("only entity with both components matched", matched_count == 1)

test_section("System Execution - Empty Components")
reset_all()

local empty_called = false
system.register("empty_query", {}, function(entities, dt)
    empty_called = true
    -- Empty components should give empty iterator
    local count = 0
    for e in entities do
        count = count + 1
    end
    test("empty query iterator runs (returns nil immediately)", count == 0)
end)

system.update(0)
test("empty component system runs", empty_called)

test_section("System Execution - Data Modification")
reset_all()
component.register("position", {x = 0, y = 0})
component.register("velocity", {vx = 10, vy = 20})

system.register("movement", {"position", "velocity"}, function(entities, dt)
    for e, pos, vel in entities do
        pos.x = pos.x + vel.vx * dt
        pos.y = pos.y + vel.vy * dt
    end
end)

local e1 = entity.create()
component.add(e1, "position", {x = 100, y = 100})
component.add(e1, "velocity", {vx = 10, vy = -5})

system.update(1.0)  -- 1 second

local pos = component.get(e1, "position")
test("x updated correctly", pos.x == 110)
test("y updated correctly", pos.y == 95)

system.update(0.5)  -- 0.5 seconds
pos = component.get(e1, "position")
test("x updated again", pos.x == 115)
test("y updated again", pos.y == 92.5)
-- }}}

-- {{{ System Priority Tests
test_section("System Priority - Ordering")
reset_all()

local order = {}
system.register("third", {}, function() order[#order+1] = "third" end, {priority = 10})
system.register("first", {}, function() order[#order+1] = "first" end, {priority = -10})
system.register("second", {}, function() order[#order+1] = "second" end, {priority = 0})

system.update(0)
test("first runs first (priority -10)", order[1] == "first")
test("second runs second (priority 0)", order[2] == "second")
test("third runs third (priority 10)", order[3] == "third")

test_section("System Priority - Same Priority (Registration Order)")
reset_all()

order = {}
system.register("reg_first", {}, function() order[#order+1] = "reg_first" end, {priority = 0})
system.register("reg_second", {}, function() order[#order+1] = "reg_second" end, {priority = 0})
system.register("reg_third", {}, function() order[#order+1] = "reg_third" end, {priority = 0})

system.update(0)
test("same priority: first registered runs first", order[1] == "reg_first")
test("same priority: second registered runs second", order[2] == "reg_second")
test("same priority: third registered runs third", order[3] == "reg_third")

test_section("System Priority - Complex Ordering")
reset_all()

order = {}
-- Register in random order
system.register("cleanup", {}, function() order[#order+1] = "cleanup" end, {priority = 100})
system.register("input", {}, function() order[#order+1] = "input" end, {priority = -100})
system.register("physics_a", {}, function() order[#order+1] = "physics_a" end, {priority = 0})
system.register("physics_b", {}, function() order[#order+1] = "physics_b" end, {priority = 0})
system.register("render", {}, function() order[#order+1] = "render" end, {priority = 50})

system.update(0)
test("complex order: input first", order[1] == "input")
test("complex order: physics_a second", order[2] == "physics_a")
test("complex order: physics_b third", order[3] == "physics_b")
test("complex order: render fourth", order[4] == "render")
test("complex order: cleanup fifth", order[5] == "cleanup")
-- }}}

-- {{{ System Enable/Disable Tests
test_section("System Enable/Disable - Individual")
reset_all()

local counter = 0
system.register("toggleable", {}, function() counter = counter + 1 end)

system.update(0)
test("runs when enabled (default)", counter == 1)

local result = system.disable("toggleable")
test("disable returns true", result == true)
test("is_enabled returns false", system.is_enabled("toggleable") == false)

system.update(0)
test("doesn't run when disabled", counter == 1)

result = system.enable("toggleable")
test("enable returns true", result == true)
test("is_enabled returns true", system.is_enabled("toggleable") == true)

system.update(0)
test("runs after re-enable", counter == 2)

-- Enable/disable nonexistent
result = system.enable("nonexistent")
test("enable nonexistent returns false", result == false)
result = system.disable("nonexistent")
test("disable nonexistent returns false", result == false)
test("is_enabled nonexistent returns nil/false", not system.is_enabled("nonexistent"))

test_section("System Enable/Disable - Initial Disabled")
reset_all()

counter = 0
system.register("starts_disabled", {}, function() counter = counter + 1 end, {enabled = false})

test("is_enabled returns false initially", system.is_enabled("starts_disabled") == false)

system.update(0)
test("doesn't run when started disabled", counter == 0)

system.enable("starts_disabled")
system.update(0)
test("runs after enabling", counter == 1)

test_section("System Enable/Disable - Global")
reset_all()

local counter1 = 0
local counter2 = 0
system.register("sys1", {}, function() counter1 = counter1 + 1 end)
system.register("sys2", {}, function() counter2 = counter2 + 1 end)

system.update(0)
test("both run normally", counter1 == 1 and counter2 == 1)

counter1 = 0
counter2 = 0
system.set_all_enabled(false)

system.update(0)
test("none run when globally disabled", counter1 == 0 and counter2 == 0)

system.set_all_enabled(true)
system.update(0)
test("both run when globally re-enabled", counter1 == 1 and counter2 == 1)

test_section("System Enable/Disable - Global vs Individual")
reset_all()

counter1 = 0
counter2 = 0
system.register("sys_a", {}, function() counter1 = counter1 + 1 end)
system.register("sys_b", {}, function() counter2 = counter2 + 1 end)

-- Disable one individually
system.disable("sys_b")

system.update(0)
test("only enabled system runs", counter1 == 1 and counter2 == 0)

-- Globally disable
counter1 = 0
system.set_all_enabled(false)
system.update(0)
test("global disable overrides individual enable", counter1 == 0)

-- Re-enable globally
system.set_all_enabled(true)
counter1 = 0
system.update(0)
test("individual disable still respected after global re-enable", counter1 == 1 and counter2 == 0)
-- }}}

-- {{{ System Query and Retrieval Tests
test_section("System Query - Get")
reset_all()

local sys1 = system.register("find_me", {}, function() end)
local sys2 = system.register("also_find", {}, function() end)

test("get returns correct system", system.get("find_me") == sys1)
test("get returns second system", system.get("also_find") == sys2)
test("get nonexistent returns nil", system.get("not_here") == nil)

test_section("System Query - Get All")
reset_all()

system.register("sys_a", {}, function() end, {priority = 10})
system.register("sys_b", {}, function() end, {priority = -5})
system.register("sys_c", {}, function() end, {priority = 10})

local all = system.get_all()
test("get_all returns 3 systems", #all == 3)
test("get_all returns array", type(all) == "table")

-- Should be in priority order
test("systems in priority order (first is lowest)", all[1].priority <= all[2].priority)
test("systems in priority order (second <= third)", all[2].priority <= all[3].priority)

test_section("System Query - Get Count")
reset_all()

test("count starts at 0", system.get_count() == 0)

system.register("one", {}, function() end)
test("count is 1", system.get_count() == 1)

system.register("two", {}, function() end)
system.register("three", {}, function() end)
test("count is 3", system.get_count() == 3)
-- }}}

-- {{{ System Unregistration Tests
test_section("System Unregistration")
reset_all()

system.register("to_remove", {}, function() end)
system.register("to_keep", {}, function() end)
system.register("also_keep", {}, function() end)

test("count starts at 3", system.get_count() == 3)

local removed = system.unregister("to_remove")
test("unregister returns true", removed == true)
test("count is 2", system.get_count() == 2)
test("removed system not found", system.get("to_remove") == nil)
test("kept systems exist", system.get("to_keep") ~= nil and system.get("also_keep") ~= nil)

removed = system.unregister("nonexistent")
test("unregister nonexistent returns false", removed == false)
test("count unchanged", system.get_count() == 2)

-- Verify remaining systems still run
local kept_ran = 0
local all = system.get_all()
for _, s in ipairs(all) do
    if s.name == "to_keep" or s.name == "also_keep" then
        kept_ran = kept_ran + 1
    end
end
test("kept systems in get_all", kept_ran == 2)

test_section("System Unregistration - Priority Preserved")
reset_all()

local order = {}
system.register("first", {}, function() order[#order+1] = "first" end, {priority = -10})
system.register("remove_me", {}, function() order[#order+1] = "remove_me" end, {priority = 0})
system.register("last", {}, function() order[#order+1] = "last" end, {priority = 10})

system.unregister("remove_me")

system.update(0)
test("order preserved after removal", order[1] == "first" and order[2] == "last")
test("only 2 systems ran", #order == 2)
-- }}}

-- {{{ System Stats Tests
test_section("System Stats - Tracking")
reset_all()
component.register("data", {value = 0})

system.register("measured", {"data"}, function(entities, dt)
    for e in entities do end
end)

local e1 = entity.create()
component.add(e1, "data")

-- Run several updates
for i = 1, 5 do
    system.update(0.016)
end

local stats = system.get_stats()
test("stats has total_systems", stats.total_systems == 1)
test("stats has enabled_count", stats.enabled_count == 1)
test("stats has systems table", type(stats.systems) == "table")
test("stats has measured system", stats.systems.measured ~= nil)

local measured = stats.systems.measured
test("update_count is 5", measured.update_count == 5)
test("total_time is positive", measured.total_time > 0)
test("avg_time is positive", measured.avg_time > 0)
test("last_entity_count is 1", measured.last_entity_count == 1)
test("priority recorded", measured.priority == 0)
test("enabled recorded", measured.enabled == true)
test("components recorded", #measured.components == 1)

test_section("System Stats - Reset Stats")
reset_all()
component.register("test", {})

system.register("stat_test", {"test"}, function(entities, dt)
    for e in entities do end
end)

local e = entity.create()
component.add(e, "test")

system.update(0)
system.update(0)
system.update(0)

local stats = system.get_stats()
test("update_count is 3 before reset", stats.systems.stat_test.update_count == 3)

system.reset_stats()

stats = system.get_stats()
test("update_count is 0 after reset", stats.systems.stat_test.update_count == 0)
test("total_time is 0 after reset", stats.systems.stat_test.total_time == 0)
test("avg_time is 0 after reset", stats.systems.stat_test.avg_time == 0)

test_section("System Stats - Disabled Systems")
reset_all()

system.register("enabled_sys", {}, function() end)
system.register("disabled_sys", {}, function() end, {enabled = false})
system.register("another_enabled", {}, function() end)

local stats = system.get_stats()
test("total_systems is 3", stats.total_systems == 3)
test("enabled_count is 2", stats.enabled_count == 2)

system.disable("enabled_sys")
stats = system.get_stats()
test("enabled_count updated after disable", stats.enabled_count == 1)
-- }}}

-- {{{ System Reset Tests
test_section("System Reset")
reset_all()

system.register("sys1", {}, function() end)
system.register("sys2", {}, function() end)
system.register("sys3", {}, function() end)

test("count is 3 before reset", system.get_count() == 3)

system.reset()

test("count is 0 after reset", system.get_count() == 0)
test("get returns nil after reset", system.get("sys1") == nil)
test("get_all returns empty after reset", #system.get_all() == 0)
-- }}}

-- {{{ ECS Init Integration Tests
test_section("ECS Init Integration")
reset_all()

-- Test that ecs module re-exports system functions
test("ecs.register_system exists", type(ecs.register_system) == "function")
test("ecs.update_systems exists", type(ecs.update_systems) == "function")
test("ecs.enable_system exists", type(ecs.enable_system) == "function")
test("ecs.disable_system exists", type(ecs.disable_system) == "function")
test("ecs.is_system_enabled exists", type(ecs.is_system_enabled) == "function")
test("ecs.set_all_systems_enabled exists", type(ecs.set_all_systems_enabled) == "function")
test("ecs.get_system exists", type(ecs.get_system) == "function")
test("ecs.get_all_systems exists", type(ecs.get_all_systems) == "function")
test("ecs.get_system_count exists", type(ecs.get_system_count) == "function")
test("ecs.unregister_system exists", type(ecs.unregister_system) == "function")
test("ecs.get_system_stats exists", type(ecs.get_system_stats) == "function")
test("ecs.reset_system_stats exists", type(ecs.reset_system_stats) == "function")

-- Test that they work through ecs module
ecs.register_component("test_comp", {v = 0})
local sys = ecs.register_system("via_ecs", {"test_comp"}, function(entities, dt)
    for e, comp in entities do
        comp.v = comp.v + 1
    end
end)

test("registered via ecs module", ecs.get_system("via_ecs") ~= nil)

local e = ecs.create_entity()
ecs.add_component(e, "test_comp")

ecs.update_systems(0.016)

local comp = ecs.get_component(e, "test_comp")
test("system ran via ecs.update_systems", comp.v == 1)

ecs.disable_system("via_ecs")
test("disabled via ecs module", not ecs.is_system_enabled("via_ecs"))

ecs.update_systems(0.016)
comp = ecs.get_component(e, "test_comp")
test("disabled system didn't run", comp.v == 1)
-- }}}

-- {{{ Edge Cases Tests
test_section("Edge Cases - System Modifying Entities")
reset_all()
component.register("health", {hp = 100, max_hp = 100})
component.register("damage_over_time", {dps = 10})

-- This system modifies component values
system.register("dot_system", {"health", "damage_over_time"}, function(entities, dt)
    for e, health, dot in entities do
        health.hp = health.hp - dot.dps * dt
    end
end)

local e1 = entity.create()
component.add(e1, "health", {hp = 100, max_hp = 100})
component.add(e1, "damage_over_time", {dps = 10})

system.update(1.0)  -- 1 second
local h = component.get(e1, "health")
test("hp reduced by dot", h.hp == 90)

system.update(0.5)
h = component.get(e1, "health")
test("hp reduced again", h.hp == 85)

test_section("Edge Cases - Multiple Systems Same Components")
reset_all()
component.register("counter", {value = 0})

system.register("adder", {"counter"}, function(entities, dt)
    for e, c in entities do
        c.value = c.value + 1
    end
end, {priority = 0})

system.register("doubler", {"counter"}, function(entities, dt)
    for e, c in entities do
        c.value = c.value * 2
    end
end, {priority = 10})  -- Runs after adder

local e = entity.create()
component.add(e, "counter", {value = 0})

system.update(0)
local c = component.get(e, "counter")
test("first add then double: (0+1)*2=2", c.value == 2)

system.update(0)
c = component.get(e, "counter")
test("second pass: (2+1)*2=6", c.value == 6)

test_section("Edge Cases - No Matching Entities")
reset_all()
component.register("rare", {})

local no_match_called = 0
system.register("rare_processor", {"rare"}, function(entities, dt)
    no_match_called = no_match_called + 1
    local count = 0
    for e in entities do
        count = count + 1
    end
    test("iterator returns nothing", count == 0)
end)

system.update(0)
test("system still called even with no matches", no_match_called == 1)

local stats = system.get_stats()
test("last_entity_count is 0", stats.systems.rare_processor.last_entity_count == 0)

test_section("Edge Cases - System Registration After Entities Exist")
reset_all()
component.register("data", {v = 0})

-- Create entities first
local e1 = entity.create()
local e2 = entity.create()
component.add(e1, "data", {v = 1})
component.add(e2, "data", {v = 2})

-- Now register system
local sum = 0
system.register("late_system", {"data"}, function(entities, dt)
    for e, d in entities do
        sum = sum + d.v
    end
end)

system.update(0)
test("late registered system finds existing entities", sum == 3)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
