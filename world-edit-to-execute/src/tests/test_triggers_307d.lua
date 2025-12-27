#!/usr/bin/env lua
--[[
Test Suite for Issue 307d: Trigger Context System

Tests the context stack and accessor functions:
- context.push/pop/get
- GetTriggeringTrigger, GetTriggerUnit, GetTriggerPlayer
- Event-specific accessors
- Nested trigger execution context

Run from project root: lua src/tests/test_triggers_307d.lua
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
local context = runtime._context
local triggers = runtime._triggers
-- }}}

-- ============================================================================
-- Context Module Tests
-- ============================================================================

print("\n=== Context Module ===")

test("context.is_active returns false initially", function()
    runtime.reset()
    assert_false(context.is_active(), "no active context")
end)

test("context.push makes context active", function()
    runtime.reset()
    context.push({unit = "test_unit"}, nil)
    assert_true(context.is_active(), "context active after push")
    context.pop()
end)

test("context.pop removes context", function()
    runtime.reset()
    context.push({unit = "test_unit"}, nil)
    context.pop()
    assert_false(context.is_active(), "context inactive after pop")
end)

test("context.get retrieves pushed data", function()
    runtime.reset()
    context.push({unit = "my_unit", player = "my_player"}, nil)
    assert_eq(context.get("unit"), "my_unit", "get unit")
    assert_eq(context.get("player"), "my_player", "get player")
    context.pop()
end)

test("context.get returns nil for missing field", function()
    runtime.reset()
    context.push({unit = "test"}, nil)
    assert_nil(context.get("nonexistent"), "missing field is nil")
    context.pop()
end)

test("context.get returns nil when no context", function()
    runtime.reset()
    assert_nil(context.get("unit"), "nil when no context")
end)

test("context.get_depth tracks nesting", function()
    runtime.reset()
    assert_eq(context.get_depth(), 0, "depth 0 initially")
    context.push({}, nil)
    assert_eq(context.get_depth(), 1, "depth 1 after push")
    context.push({}, nil)
    assert_eq(context.get_depth(), 2, "depth 2 after second push")
    context.pop()
    assert_eq(context.get_depth(), 1, "depth 1 after pop")
    context.pop()
    assert_eq(context.get_depth(), 0, "depth 0 after all pops")
end)

test("nested contexts preserve data", function()
    runtime.reset()
    context.push({unit = "outer_unit"}, nil)
    assert_eq(context.get("unit"), "outer_unit", "outer unit")

    context.push({unit = "inner_unit"}, nil)
    assert_eq(context.get("unit"), "inner_unit", "inner unit")

    context.pop()
    assert_eq(context.get("unit"), "outer_unit", "outer unit restored")

    context.pop()
end)

test("context.get_current returns full context", function()
    runtime.reset()
    context.push({unit = "u", player = "p"}, nil)
    local ctx = context.get_current()
    assert_not_nil(ctx, "context exists")
    assert_eq(ctx.unit, "u", "unit in context")
    assert_eq(ctx.player, "p", "player in context")
    context.pop()
end)

test("context stores trigger reference", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    context.push({}, t)
    assert_eq(context.get("trigger"), t, "trigger stored")
    context.pop()
end)

test("context.reset clears everything", function()
    runtime.reset()
    context.push({unit = "a"}, nil)
    context.push({unit = "b"}, nil)
    context.reset()
    assert_false(context.is_active(), "not active after reset")
    assert_eq(context.get_depth(), 0, "depth 0 after reset")
end)

-- ============================================================================
-- Context Accessor Tests
-- ============================================================================

print("\n=== Context Accessors ===")

test("GetTriggeringTrigger returns current trigger", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    context.push({}, t)
    assert_eq(runtime.GetTriggeringTrigger(), t, "correct trigger")
    context.pop()
end)

test("GetTriggeringTrigger returns nil outside context", function()
    runtime.reset()
    assert_nil(runtime.GetTriggeringTrigger(), "nil outside context")
end)

test("GetTriggerEventId returns event id", function()
    runtime.reset()
    context.push({event_id = 42}, nil)
    assert_eq(runtime.GetTriggerEventId(), 42, "event id")
    context.pop()
end)

test("GetTriggerUnit returns unit", function()
    runtime.reset()
    local unit = {name = "test_unit"}
    context.push({unit = unit}, nil)
    assert_eq(runtime.GetTriggerUnit(), unit, "unit")
    context.pop()
end)

test("GetTriggerPlayer returns player", function()
    runtime.reset()
    local player = {name = "test_player"}
    context.push({player = player}, nil)
    assert_eq(runtime.GetTriggerPlayer(), player, "player")
    context.pop()
end)

test("GetSpellAbilityId returns spell id", function()
    runtime.reset()
    context.push({spell_ability_id = 12345}, nil)
    assert_eq(runtime.GetSpellAbilityId(), 12345, "spell id")
    context.pop()
end)

test("GetSpellTargetX returns 0.0 when not set", function()
    runtime.reset()
    context.push({}, nil)
    assert_eq(runtime.GetSpellTargetX(), 0.0, "default 0.0")
    context.pop()
end)

test("GetSpellTargetX returns value when set", function()
    runtime.reset()
    context.push({spell_target_x = 100.5}, nil)
    assert_eq(runtime.GetSpellTargetX(), 100.5, "spell target x")
    context.pop()
end)

test("GetDyingUnit returns dying_unit or unit", function()
    runtime.reset()
    local unit = {name = "unit"}
    local dying = {name = "dying"}

    -- With dying_unit
    context.push({dying_unit = dying, unit = unit}, nil)
    assert_eq(runtime.GetDyingUnit(), dying, "dying_unit when set")
    context.pop()

    -- Without dying_unit, falls back to unit
    context.push({unit = unit}, nil)
    assert_eq(runtime.GetDyingUnit(), unit, "falls back to unit")
    context.pop()
end)

test("GetKillingUnit returns killing_unit", function()
    runtime.reset()
    local killer = {name = "killer"}
    context.push({killing_unit = killer}, nil)
    assert_eq(runtime.GetKillingUnit(), killer, "killing unit")
    context.pop()
end)

test("GetOrderedUnit returns ordered_unit or unit", function()
    runtime.reset()
    local unit = {name = "unit"}
    local ordered = {name = "ordered"}

    context.push({ordered_unit = ordered, unit = unit}, nil)
    assert_eq(runtime.GetOrderedUnit(), ordered, "ordered_unit when set")
    context.pop()

    context.push({unit = unit}, nil)
    assert_eq(runtime.GetOrderedUnit(), unit, "falls back to unit")
    context.pop()
end)

test("GetEventDamage returns 0.0 when not set", function()
    runtime.reset()
    context.push({}, nil)
    assert_eq(runtime.GetEventDamage(), 0.0, "default 0.0")
    context.pop()
end)

test("GetEventDamage returns value when set", function()
    runtime.reset()
    context.push({event_damage = 150.5}, nil)
    assert_eq(runtime.GetEventDamage(), 150.5, "damage value")
    context.pop()
end)

test("GetExpiredTimer returns timer", function()
    runtime.reset()
    local timer = {id = "timer1"}
    context.push({expired_timer = timer}, nil)
    assert_eq(runtime.GetExpiredTimer(), timer, "expired timer")
    context.pop()
end)

-- ============================================================================
-- Trigger:fire Context Tests
-- ============================================================================

print("\n=== Trigger:fire Context ===")

test("fire sets context accessible to actions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local captured_unit = nil
    local captured_trigger = nil

    runtime.TriggerAddAction(t, function()
        captured_unit = runtime.GetTriggerUnit()
        captured_trigger = runtime.GetTriggeringTrigger()
    end)

    local unit = {name = "test_unit"}
    t:fire({unit = unit})

    assert_eq(captured_unit, unit, "action received unit")
    assert_eq(captured_trigger, t, "action received trigger")
end)

test("fire sets context accessible to conditions", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local captured_player = nil

    runtime.TriggerAddCondition(t, runtime.Condition(function()
        captured_player = runtime.GetTriggerPlayer()
        return true
    end))

    local player = {name = "player1"}
    t:fire({player = player})

    assert_eq(captured_player, player, "condition received player")
end)

test("fire clears context after execution", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddAction(t, function() end)

    t:fire({unit = "test"})

    assert_nil(runtime.GetTriggerUnit(), "context cleared after fire")
    assert_false(context.is_active(), "no active context")
end)

test("fire clears context even on condition failure", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddCondition(t, runtime.Condition(function() return false end))

    t:fire({unit = "test"})

    assert_false(context.is_active(), "context cleared on failure")
end)

test("fire clears context even on error", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    runtime.TriggerAddAction(t, function() error("oops") end)

    t:fire({unit = "test"})

    assert_false(context.is_active(), "context cleared after error")
end)

-- ============================================================================
-- Nested Trigger Tests
-- ============================================================================

print("\n=== Nested Triggers ===")

test("nested trigger has own context", function()
    runtime.reset()
    local outer = runtime.CreateTrigger()
    local inner = runtime.CreateTrigger()

    local outer_unit = {name = "outer"}
    local inner_unit = {name = "inner"}
    local captured_in_inner = nil
    local captured_in_outer_after = nil

    runtime.TriggerAddAction(inner, function()
        captured_in_inner = runtime.GetTriggerUnit()
    end)

    runtime.TriggerAddAction(outer, function()
        -- Fire inner trigger with different context
        inner:fire({unit = inner_unit})
        -- Check outer context is restored
        captured_in_outer_after = runtime.GetTriggerUnit()
    end)

    outer:fire({unit = outer_unit})

    assert_eq(captured_in_inner, inner_unit, "inner saw inner unit")
    assert_eq(captured_in_outer_after, outer_unit, "outer context restored")
end)

test("deeply nested contexts work", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    local t3 = runtime.CreateTrigger()

    local depths = {}

    runtime.TriggerAddAction(t3, function()
        depths[3] = context.get_depth()
    end)

    runtime.TriggerAddAction(t2, function()
        depths[2] = context.get_depth()
        t3:fire({})
    end)

    runtime.TriggerAddAction(t1, function()
        depths[1] = context.get_depth()
        t2:fire({})
    end)

    t1:fire({})

    assert_eq(depths[1], 1, "depth 1 in t1")
    assert_eq(depths[2], 2, "depth 2 in t2")
    assert_eq(depths[3], 3, "depth 3 in t3")
    assert_eq(context.get_depth(), 0, "depth 0 after all done")
end)

test("GetTriggeringTrigger returns correct trigger in nested", function()
    runtime.reset()
    local outer = runtime.CreateTrigger()
    local inner = runtime.CreateTrigger()

    local outer_trigger_in_outer = nil
    local inner_trigger_in_inner = nil
    local outer_trigger_after_inner = nil

    runtime.TriggerAddAction(inner, function()
        inner_trigger_in_inner = runtime.GetTriggeringTrigger()
    end)

    runtime.TriggerAddAction(outer, function()
        outer_trigger_in_outer = runtime.GetTriggeringTrigger()
        inner:fire({})
        outer_trigger_after_inner = runtime.GetTriggeringTrigger()
    end)

    outer:fire({})

    assert_eq(outer_trigger_in_outer, outer, "outer in outer")
    assert_eq(inner_trigger_in_inner, inner, "inner in inner")
    assert_eq(outer_trigger_after_inner, outer, "outer restored after inner")
end)

-- ============================================================================
-- Self-Destruction Tests
-- ============================================================================

print("\n=== Self-Destruction ===")

test("destroying trigger during action clears context properly", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local ran_second = false

    runtime.TriggerAddAction(t, function()
        runtime.DestroyTrigger(runtime.GetTriggeringTrigger())
    end)
    runtime.TriggerAddAction(t, function()
        ran_second = true
    end)

    t:fire({unit = "test"})

    assert_false(ran_second, "second action didn't run")
    assert_false(context.is_active(), "context cleared")
end)

-- ============================================================================
-- Integration Tests
-- ============================================================================

print("\n=== Integration ===")

test("full spell event flow", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local results = {}

    runtime.TriggerAddCondition(t, runtime.Condition(function()
        return runtime.GetSpellAbilityId() == 12345
    end))

    runtime.TriggerAddAction(t, function()
        results.unit = runtime.GetTriggerUnit()
        results.ability = runtime.GetSpellAbilityId()
        results.target_x = runtime.GetSpellTargetX()
        results.target_y = runtime.GetSpellTargetY()
    end)

    local caster = {name = "caster"}
    t:fire({
        unit = caster,
        spell_ability_id = 12345,
        spell_target_x = 100.0,
        spell_target_y = 200.0,
    })

    assert_eq(results.unit, caster, "got caster")
    assert_eq(results.ability, 12345, "got ability")
    assert_eq(results.target_x, 100.0, "got target x")
    assert_eq(results.target_y, 200.0, "got target y")
end)

test("full death event flow", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local results = {}

    runtime.TriggerAddAction(t, function()
        results.dying = runtime.GetDyingUnit()
        results.killer = runtime.GetKillingUnit()
    end)

    local dying = {name = "dying_unit"}
    local killer = {name = "killing_unit"}
    t:fire({
        unit = dying,
        dying_unit = dying,
        killing_unit = killer,
    })

    assert_eq(results.dying, dying, "got dying unit")
    assert_eq(results.killer, killer, "got killing unit")
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
    print("\nALL 307d TESTS PASSED!")
    os.exit(0)
end
