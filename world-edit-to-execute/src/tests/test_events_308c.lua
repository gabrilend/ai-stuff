#!/usr/bin/env lua
--[[
Test Suite for Issue 308c: Region Events

Tests the region event subsystem:
- TriggerRegisterEnterRegion
- TriggerRegisterLeaveRegion
- events.unit_entered_region
- events.unit_left_region
- GetEnteringUnit, GetLeavingUnit, GetTriggerRegion

Run from project root: lua src/tests/test_events_308c.lua
]]

-- {{{ Configuration
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
-- }}}

-- {{{ Test framework
local passed = 0
local failed = 0
local current_test = ""

local function test(name, fn)
    current_test = name
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print(string.format("  [PASS] %s", name))
    else
        failed = failed + 1
        print(string.format("  [FAIL] %s", name))
        print(string.format("         %s", err))
    end
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "assertion", tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "expected true, got false")
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "expected false, got true")
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s", msg or "assertion", tostring(value)))
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "expected non-nil value")
    end
end
-- }}}

-- {{{ Load modules
local runtime = require("runtime")
local events = runtime._events
-- }}}

-- {{{ Mock region/unit factories
local function make_region(name)
    return {name = name, _type = "region"}
end

local function make_unit(name, is_hero)
    return {name = name, is_hero = is_hero or false, _type = "unit"}
end
-- }}}

-- ============================================================================
-- TriggerRegisterEnterRegion Tests
-- ============================================================================

print("\n=== TriggerRegisterEnterRegion ===")

test("TriggerRegisterEnterRegion returns listener", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test_region")
    local listener = runtime.TriggerRegisterEnterRegion(t, region)
    assert_not_nil(listener, "listener returned")
end)

test("TriggerRegisterEnterRegion with nil trigger returns nil", function()
    runtime.reset()
    local region = make_region("test")
    assert_nil(runtime.TriggerRegisterEnterRegion(nil, region), "nil for nil trigger")
end)

test("TriggerRegisterEnterRegion with nil region returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_nil(runtime.TriggerRegisterEnterRegion(t, nil), "nil for nil region")
end)

test("TriggerRegisterEnterRegion registers for correct event", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test")
    runtime.TriggerRegisterEnterRegion(t, region)
    assert_eq(events.get_listener_count(events.EVENT.UNIT_ENTER_REGION), 1, "registered")
    assert_eq(events.get_listener_count(events.EVENT.UNIT_LEAVE_REGION), 0, "not for leave")
end)

test("TriggerRegisterEnterRegion only fires for matching region", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region1 = make_region("region1")
    local region2 = make_region("region2")
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterEnterRegion(t, region1)

    local unit = make_unit("test_unit")

    -- Wrong region - should not fire
    events.unit_entered_region(unit, region2)
    assert_eq(fire_count, 0, "wrong region")

    -- Correct region - should fire
    events.unit_entered_region(unit, region1)
    assert_eq(fire_count, 1, "correct region")
end)

test("TriggerRegisterEnterRegion with filter", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test")
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)

    -- Only fire for heroes
    runtime.TriggerRegisterEnterRegion(t, region, function(unit)
        return unit.is_hero
    end)

    local hero = make_unit("hero", true)
    local peon = make_unit("peon", false)

    events.unit_entered_region(peon, region)
    assert_eq(fire_count, 0, "filtered out non-hero")

    events.unit_entered_region(hero, region)
    assert_eq(fire_count, 1, "hero passed filter")
end)

-- ============================================================================
-- TriggerRegisterLeaveRegion Tests
-- ============================================================================

print("\n=== TriggerRegisterLeaveRegion ===")

test("TriggerRegisterLeaveRegion returns listener", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test_region")
    local listener = runtime.TriggerRegisterLeaveRegion(t, region)
    assert_not_nil(listener, "listener returned")
end)

test("TriggerRegisterLeaveRegion with nil trigger returns nil", function()
    runtime.reset()
    local region = make_region("test")
    assert_nil(runtime.TriggerRegisterLeaveRegion(nil, region), "nil for nil trigger")
end)

test("TriggerRegisterLeaveRegion with nil region returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_nil(runtime.TriggerRegisterLeaveRegion(t, nil), "nil for nil region")
end)

test("TriggerRegisterLeaveRegion registers for correct event", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test")
    runtime.TriggerRegisterLeaveRegion(t, region)
    assert_eq(events.get_listener_count(events.EVENT.UNIT_LEAVE_REGION), 1, "registered")
    assert_eq(events.get_listener_count(events.EVENT.UNIT_ENTER_REGION), 0, "not for enter")
end)

test("TriggerRegisterLeaveRegion only fires for matching region", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region1 = make_region("region1")
    local region2 = make_region("region2")
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterLeaveRegion(t, region1)

    local unit = make_unit("test_unit")

    -- Wrong region - should not fire
    events.unit_left_region(unit, region2)
    assert_eq(fire_count, 0, "wrong region")

    -- Correct region - should fire
    events.unit_left_region(unit, region1)
    assert_eq(fire_count, 1, "correct region")
end)

test("TriggerRegisterLeaveRegion with filter", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test")
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)

    -- Only fire for heroes
    runtime.TriggerRegisterLeaveRegion(t, region, function(unit)
        return unit.is_hero
    end)

    local hero = make_unit("hero", true)
    local peon = make_unit("peon", false)

    events.unit_left_region(peon, region)
    assert_eq(fire_count, 0, "filtered out non-hero")

    events.unit_left_region(hero, region)
    assert_eq(fire_count, 1, "hero passed filter")
end)

-- ============================================================================
-- Fire Hook Tests
-- ============================================================================

print("\n=== Fire Hooks ===")

test("unit_entered_region fires UNIT_ENTER_REGION", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test")
    local unit = make_unit("test_unit")
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterEnterRegion(t, region)

    events.unit_entered_region(unit, region)
    assert_true(fired, "trigger fired")
end)

test("unit_left_region fires UNIT_LEAVE_REGION", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test")
    local unit = make_unit("test_unit")
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterLeaveRegion(t, region)

    events.unit_left_region(unit, region)
    assert_true(fired, "trigger fired")
end)

test("enter and leave events are distinct", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    local region = make_region("test")
    local unit = make_unit("test_unit")
    local enter_count, leave_count = 0, 0

    runtime.TriggerAddAction(t1, function() enter_count = enter_count + 1 end)
    runtime.TriggerAddAction(t2, function() leave_count = leave_count + 1 end)
    runtime.TriggerRegisterEnterRegion(t1, region)
    runtime.TriggerRegisterLeaveRegion(t2, region)

    events.unit_entered_region(unit, region)
    assert_eq(enter_count, 1, "enter fired")
    assert_eq(leave_count, 0, "leave not fired")

    events.unit_left_region(unit, region)
    assert_eq(enter_count, 1, "enter still 1")
    assert_eq(leave_count, 1, "leave fired")
end)

-- ============================================================================
-- Context Accessor Tests
-- ============================================================================

print("\n=== Context Accessors ===")

test("GetEnteringUnit returns unit from enter event", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test")
    local unit = make_unit("entering_unit")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetEnteringUnit()
    end)
    runtime.TriggerRegisterEnterRegion(t, region)

    events.unit_entered_region(unit, region)
    assert_eq(captured, unit, "captured entering unit")
end)

test("GetLeavingUnit returns unit from leave event", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test")
    local unit = make_unit("leaving_unit")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetLeavingUnit()
    end)
    runtime.TriggerRegisterLeaveRegion(t, region)

    events.unit_left_region(unit, region)
    assert_eq(captured, unit, "captured leaving unit")
end)

test("GetTriggerRegion returns region from enter event", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test_region")
    local unit = make_unit("test_unit")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetTriggerRegion()
    end)
    runtime.TriggerRegisterEnterRegion(t, region)

    events.unit_entered_region(unit, region)
    assert_eq(captured, region, "captured region")
end)

test("GetTriggerRegion returns region from leave event", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test_region")
    local unit = make_unit("test_unit")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetTriggerRegion()
    end)
    runtime.TriggerRegisterLeaveRegion(t, region)

    events.unit_left_region(unit, region)
    assert_eq(captured, region, "captured region")
end)

test("GetTriggerUnit works for region events", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test")
    local unit = make_unit("test_unit")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetTriggerUnit()
    end)
    runtime.TriggerRegisterEnterRegion(t, region)

    events.unit_entered_region(unit, region)
    assert_eq(captured, unit, "GetTriggerUnit works")
end)

test("accessors return nil outside event context", function()
    runtime.reset()
    assert_nil(runtime.GetEnteringUnit(), "entering nil outside")
    assert_nil(runtime.GetLeavingUnit(), "leaving nil outside")
    assert_nil(runtime.GetTriggerRegion(), "region nil outside")
end)

-- ============================================================================
-- Multiple Triggers Tests
-- ============================================================================

print("\n=== Multiple Triggers ===")

test("multiple triggers on same region", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    local region = make_region("shared_region")
    local unit = make_unit("test_unit")
    local fire1, fire2 = 0, 0

    runtime.TriggerAddAction(t1, function() fire1 = fire1 + 1 end)
    runtime.TriggerAddAction(t2, function() fire2 = fire2 + 1 end)
    runtime.TriggerRegisterEnterRegion(t1, region)
    runtime.TriggerRegisterEnterRegion(t2, region)

    events.unit_entered_region(unit, region)
    assert_eq(fire1, 1, "t1 fired")
    assert_eq(fire2, 1, "t2 fired")
end)

test("same trigger on multiple regions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region1 = make_region("region1")
    local region2 = make_region("region2")
    local unit = make_unit("test_unit")
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterEnterRegion(t, region1)
    runtime.TriggerRegisterEnterRegion(t, region2)

    events.unit_entered_region(unit, region1)
    assert_eq(fire_count, 1, "fired for region1")

    events.unit_entered_region(unit, region2)
    assert_eq(fire_count, 2, "fired for region2")
end)

test("trigger for both enter and leave on same region", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local region = make_region("test")
    local unit = make_unit("test_unit")
    local enter_count, leave_count = 0, 0

    runtime.TriggerAddAction(t, function()
        -- Use event ID to distinguish enter vs leave
        local event_id = runtime.GetTriggerEventId()
        if event_id == events.EVENT.UNIT_ENTER_REGION then
            enter_count = enter_count + 1
        elseif event_id == events.EVENT.UNIT_LEAVE_REGION then
            leave_count = leave_count + 1
        end
    end)

    runtime.TriggerRegisterEnterRegion(t, region)
    runtime.TriggerRegisterLeaveRegion(t, region)

    events.unit_entered_region(unit, region)
    events.unit_left_region(unit, region)

    -- The trigger fires twice, but with different context
    assert_eq(enter_count, 1, "enter counted")
    assert_eq(leave_count, 1, "leave counted")
end)

-- ============================================================================
-- Results
-- ============================================================================

print("")
print(string.rep("=", 60))
print(string.format("=== Results: %d/%d tests passed ===", passed, passed + failed))
print(string.rep("=", 60))

if failed > 0 then
    os.exit(1)
else
    print("\nALL 308c TESTS PASSED!")
    os.exit(0)
end
