#!/usr/bin/env lua
--[[
Test Suite for Issue 308d: Unit Events

Tests the unit event subsystem:
- TriggerRegisterUnitEvent
- TriggerRegisterAnyUnitEventBJ
- TriggerRegisterPlayerUnitEvent
- Fire hooks: unit_died, unit_damaged, unit_attacked, etc.
- Context accessors: GetDyingUnit, GetKillingUnit, GetEventDamage, etc.
- Spell events: channel, cast, effect, finish, endcast

Run from project root: lua src/tests/test_events_308d.lua
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

-- {{{ Mock factories
local function make_unit(name, owner, is_hero)
    return {
        name = name,
        owner = owner,
        is_hero = is_hero or false,
        _type = "unit"
    }
end

local function make_player(id, name)
    return {id = id, name = name or ("Player" .. id), _type = "player"}
end
-- }}}

-- ============================================================================
-- TriggerRegisterUnitEvent Tests
-- ============================================================================

print("\n=== TriggerRegisterUnitEvent ===")

test("TriggerRegisterUnitEvent returns listener", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("hero")
    local listener = runtime.TriggerRegisterUnitEvent(t, unit, events.EVENT.UNIT_DEATH)
    assert_not_nil(listener, "listener returned")
end)

test("TriggerRegisterUnitEvent with nil trigger returns nil", function()
    runtime.reset()
    local unit = make_unit("hero")
    assert_nil(runtime.TriggerRegisterUnitEvent(nil, unit, events.EVENT.UNIT_DEATH))
end)

test("TriggerRegisterUnitEvent with nil unit returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_nil(runtime.TriggerRegisterUnitEvent(t, nil, events.EVENT.UNIT_DEATH))
end)

test("TriggerRegisterUnitEvent with nil event_type returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("hero")
    assert_nil(runtime.TriggerRegisterUnitEvent(t, unit, nil))
end)

test("TriggerRegisterUnitEvent only fires for specific unit", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local hero = make_unit("hero")
    local peon = make_unit("peon")
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterUnitEvent(t, hero, events.EVENT.UNIT_DEATH)

    -- Wrong unit - should not fire
    events.unit_died(peon, nil)
    assert_eq(fire_count, 0, "peon death ignored")

    -- Correct unit - should fire
    events.unit_died(hero, nil)
    assert_eq(fire_count, 1, "hero death fired")
end)

test("TriggerRegisterUnitEvent works for multiple event types", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("unit")
    local death_count, damage_count = 0, 0

    runtime.TriggerAddAction(t, function()
        local event_id = runtime.GetTriggerEventId()
        if event_id == events.EVENT.UNIT_DEATH then
            death_count = death_count + 1
        elseif event_id == events.EVENT.UNIT_DAMAGED then
            damage_count = damage_count + 1
        end
    end)

    runtime.TriggerRegisterUnitEvent(t, unit, events.EVENT.UNIT_DEATH)
    runtime.TriggerRegisterUnitEvent(t, unit, events.EVENT.UNIT_DAMAGED)

    events.unit_damaged(unit, nil, 50)
    events.unit_died(unit, nil)

    assert_eq(death_count, 1, "death event")
    assert_eq(damage_count, 1, "damage event")
end)

-- ============================================================================
-- TriggerRegisterAnyUnitEventBJ Tests
-- ============================================================================

print("\n=== TriggerRegisterAnyUnitEventBJ ===")

test("TriggerRegisterAnyUnitEventBJ returns listener", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local listener = runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DEATH)
    assert_not_nil(listener, "listener returned")
end)

test("TriggerRegisterAnyUnitEventBJ with nil trigger returns nil", function()
    runtime.reset()
    assert_nil(runtime.TriggerRegisterAnyUnitEventBJ(nil, events.EVENT.UNIT_DEATH))
end)

test("TriggerRegisterAnyUnitEventBJ with nil event_type returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_nil(runtime.TriggerRegisterAnyUnitEventBJ(t, nil))
end)

test("TriggerRegisterAnyUnitEventBJ fires for any unit", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local hero = make_unit("hero")
    local peon = make_unit("peon")
    local grunt = make_unit("grunt")
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DEATH)

    events.unit_died(hero, nil)
    events.unit_died(peon, nil)
    events.unit_died(grunt, nil)

    assert_eq(fire_count, 3, "all unit deaths fired")
end)

-- ============================================================================
-- TriggerRegisterPlayerUnitEvent Tests
-- ============================================================================

print("\n=== TriggerRegisterPlayerUnitEvent ===")

test("TriggerRegisterPlayerUnitEvent returns listener", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local listener = runtime.TriggerRegisterPlayerUnitEvent(t, player, events.EVENT.UNIT_DEATH)
    assert_not_nil(listener, "listener returned")
end)

test("TriggerRegisterPlayerUnitEvent with nil trigger returns nil", function()
    runtime.reset()
    local player = make_player(1)
    assert_nil(runtime.TriggerRegisterPlayerUnitEvent(nil, player, events.EVENT.UNIT_DEATH))
end)

test("TriggerRegisterPlayerUnitEvent with nil player returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_nil(runtime.TriggerRegisterPlayerUnitEvent(t, nil, events.EVENT.UNIT_DEATH))
end)

test("TriggerRegisterPlayerUnitEvent only fires for player's units", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player1 = make_player(1)
    local player2 = make_player(2)
    local unit1 = make_unit("unit1", player1)
    local unit2 = make_unit("unit2", player2)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterPlayerUnitEvent(t, player1, events.EVENT.UNIT_DEATH)

    -- Player 2's unit - should not fire
    events.unit_died(unit2, nil)
    assert_eq(fire_count, 0, "player2 unit ignored")

    -- Player 1's unit - should fire
    events.unit_died(unit1, nil)
    assert_eq(fire_count, 1, "player1 unit fired")
end)

test("TriggerRegisterPlayerUnitEvent with additional filter", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local hero = make_unit("hero", player, true)
    local peon = make_unit("peon", player, false)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)

    -- Only fire for hero units owned by player
    runtime.TriggerRegisterPlayerUnitEvent(t, player, events.EVENT.UNIT_DEATH, function(unit)
        return unit.is_hero
    end)

    -- Non-hero owned by player - should not fire
    events.unit_died(peon, nil)
    assert_eq(fire_count, 0, "non-hero filtered")

    -- Hero owned by player - should fire
    events.unit_died(hero, nil)
    assert_eq(fire_count, 1, "hero passed filter")
end)

-- ============================================================================
-- Unit Death Event Tests
-- ============================================================================

print("\n=== Unit Death Events ===")

test("unit_died fires UNIT_DEATH", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("victim")
    local killer = make_unit("killer")
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DEATH)

    events.unit_died(unit, killer)
    assert_true(fired, "trigger fired")
end)

test("GetDyingUnit returns dying unit", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local victim = make_unit("victim")
    local killer = make_unit("killer")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetDyingUnit()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DEATH)

    events.unit_died(victim, killer)
    assert_eq(captured, victim, "captured dying unit")
end)

test("GetKillingUnit returns killer", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local victim = make_unit("victim")
    local killer = make_unit("killer")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetKillingUnit()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DEATH)

    events.unit_died(victim, killer)
    assert_eq(captured, killer, "captured killing unit")
end)

test("GetKillingUnit returns nil when no killer", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local victim = make_unit("victim")
    local captured = "not_nil"

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetKillingUnit()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DEATH)

    events.unit_died(victim, nil)
    assert_nil(captured, "nil when no killer")
end)

-- ============================================================================
-- Unit Damaged Event Tests
-- ============================================================================

print("\n=== Unit Damaged Events ===")

test("unit_damaged fires UNIT_DAMAGED", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("victim")
    local source = make_unit("attacker")
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DAMAGED)

    events.unit_damaged(unit, source, 100)
    assert_true(fired, "trigger fired")
end)

test("GetEventDamage returns damage amount", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("victim")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetEventDamage()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DAMAGED)

    events.unit_damaged(unit, nil, 75.5)
    assert_eq(captured, 75.5, "captured damage amount")
end)

test("GetEventDamageSource returns source unit", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("victim")
    local source = make_unit("attacker")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetEventDamageSource()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DAMAGED)

    events.unit_damaged(unit, source, 50)
    assert_eq(captured, source, "captured source unit")
end)

test("GetEventDamage returns 0 outside context", function()
    runtime.reset()
    local result = runtime.GetEventDamage()
    assert_eq(result, 0, "0 outside context")
end)

-- ============================================================================
-- Unit Attacked Event Tests
-- ============================================================================

print("\n=== Unit Attacked Events ===")

test("unit_attacked fires UNIT_ATTACKED", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local target = make_unit("target")
    local attacker = make_unit("attacker")
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_ATTACKED)

    events.unit_attacked(target, attacker)
    assert_true(fired, "trigger fired")
end)

test("GetAttacker returns attacking unit", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local target = make_unit("target")
    local attacker = make_unit("attacker")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetAttacker()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_ATTACKED)

    events.unit_attacked(target, attacker)
    assert_eq(captured, attacker, "captured attacker")
end)

test("GetAttackedUnitBJ returns attacked unit", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local target = make_unit("target")
    local attacker = make_unit("attacker")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetAttackedUnitBJ()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_ATTACKED)

    events.unit_attacked(target, attacker)
    assert_eq(captured, target, "captured attacked unit")
end)

-- ============================================================================
-- Unit Spawn Event Tests
-- ============================================================================

print("\n=== Unit Spawn Events ===")

test("unit_spawned fires UNIT_SPAWN", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("newunit")
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPAWN)

    events.unit_spawned(unit)
    assert_true(fired, "trigger fired")
end)

test("GetTriggerUnit returns spawned unit", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("newunit")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetTriggerUnit()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPAWN)

    events.unit_spawned(unit)
    assert_eq(captured, unit, "captured spawned unit")
end)

-- ============================================================================
-- Unit Order Event Tests
-- ============================================================================

print("\n=== Unit Order Events ===")

test("unit_issued_order fires UNIT_ISSUED_ORDER", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("unit")
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_ISSUED_ORDER)

    events.unit_issued_order(unit, 851971, nil, 100, 200)  -- order "move"
    assert_true(fired, "trigger fired")
end)

test("GetOrderedUnit returns ordered unit", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("ordered_unit")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetOrderedUnit()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_ISSUED_ORDER)

    events.unit_issued_order(unit, 12345, nil, 0, 0)
    assert_eq(captured, unit, "captured ordered unit")
end)

test("GetIssuedOrderId returns order ID", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("unit")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetIssuedOrderId()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_ISSUED_ORDER)

    events.unit_issued_order(unit, 851971, nil, 0, 0)
    assert_eq(captured, 851971, "captured order ID")
end)

test("GetOrderTargetUnit returns target unit for unit orders", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("unit")
    local target = make_unit("target")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetOrderTargetUnit()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_ISSUED_ORDER)

    events.unit_issued_order(unit, 851983, target, 0, 0)  -- order "attack"
    assert_eq(captured, target, "captured order target")
end)

test("GetOrderPointX/Y returns coordinates for point orders", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("unit")
    local captured_x, captured_y = nil, nil

    runtime.TriggerAddAction(t, function()
        captured_x = runtime.GetOrderPointX()
        captured_y = runtime.GetOrderPointY()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_ISSUED_ORDER)

    events.unit_issued_order(unit, 851971, nil, 150.5, 250.5)  -- order "move"
    assert_eq(captured_x, 150.5, "captured X")
    assert_eq(captured_y, 250.5, "captured Y")
end)

-- ============================================================================
-- Spell Event Tests
-- ============================================================================

print("\n=== Spell Events ===")

test("unit_spell_channel fires UNIT_SPELL_CHANNEL", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local caster = make_unit("caster")
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPELL_CHANNEL)

    events.unit_spell_channel(caster, 1234, nil, 100, 200)
    assert_true(fired, "trigger fired")
end)

test("GetSpellAbilityId returns ability ID", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local caster = make_unit("caster")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetSpellAbilityId()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPELL_CHANNEL)

    events.unit_spell_channel(caster, 1234, nil, 0, 0)
    assert_eq(captured, 1234, "captured ability ID")
end)

test("GetSpellTargetUnit returns spell target", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local caster = make_unit("caster")
    local target = make_unit("target")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetSpellTargetUnit()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPELL_EFFECT)

    events.unit_spell_effect(caster, 1234, target, 0, 0)
    assert_eq(captured, target, "captured spell target")
end)

test("GetSpellTargetX/Y returns spell coordinates", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local caster = make_unit("caster")
    local captured_x, captured_y = nil, nil

    runtime.TriggerAddAction(t, function()
        captured_x = runtime.GetSpellTargetX()
        captured_y = runtime.GetSpellTargetY()
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPELL_CAST)

    events.unit_spell_cast(caster, 1234, nil, 300.5, 400.5)
    assert_eq(captured_x, 300.5, "captured X")
    assert_eq(captured_y, 400.5, "captured Y")
end)

test("spell events fire in sequence", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local caster = make_unit("caster")
    local sequence = {}

    runtime.TriggerAddAction(t, function()
        local event_id = runtime.GetTriggerEventId()
        table.insert(sequence, event_id)
    end)

    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPELL_CHANNEL)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPELL_CAST)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPELL_EFFECT)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPELL_FINISH)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPELL_ENDCAST)

    -- Simulate spell cast sequence
    events.unit_spell_channel(caster, 1234, nil, 0, 0)
    events.unit_spell_cast(caster, 1234, nil, 0, 0)
    events.unit_spell_effect(caster, 1234, nil, 0, 0)
    events.unit_spell_finish(caster, 1234)
    events.unit_spell_endcast(caster, 1234)

    assert_eq(#sequence, 5, "5 events fired")
    assert_eq(sequence[1], events.EVENT.UNIT_SPELL_CHANNEL, "channel first")
    assert_eq(sequence[2], events.EVENT.UNIT_SPELL_CAST, "cast second")
    assert_eq(sequence[3], events.EVENT.UNIT_SPELL_EFFECT, "effect third")
    assert_eq(sequence[4], events.EVENT.UNIT_SPELL_FINISH, "finish fourth")
    assert_eq(sequence[5], events.EVENT.UNIT_SPELL_ENDCAST, "endcast fifth")
end)

-- ============================================================================
-- Other Unit Event Tests
-- ============================================================================

print("\n=== Other Unit Events ===")

test("unit_acquired_target fires UNIT_ACQUIRED_TARGET", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("unit")
    local target = make_unit("target")
    local fired = false
    local captured_target = nil

    runtime.TriggerAddAction(t, function()
        fired = true
        -- Access via context
        local ctx = runtime._context.get("target")
        captured_target = ctx
    end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_ACQUIRED_TARGET)

    events.unit_acquired_target(unit, target)
    assert_true(fired, "trigger fired")
    assert_eq(captured_target, target, "target captured")
end)

test("unit_selected fires UNIT_SELECTED", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("unit")
    local player = make_player(1)
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SELECTED)

    events.unit_selected(unit, player)
    assert_true(fired, "trigger fired")
end)

test("unit_deselected fires UNIT_DESELECTED", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("unit")
    local player = make_player(1)
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DESELECTED)

    events.unit_deselected(unit, player)
    assert_true(fired, "trigger fired")
end)

-- ============================================================================
-- Context Accessor Edge Cases
-- ============================================================================

print("\n=== Context Accessor Edge Cases ===")

test("accessors return nil/0 outside event context", function()
    runtime.reset()
    assert_nil(runtime.GetDyingUnit(), "GetDyingUnit nil")
    assert_nil(runtime.GetKillingUnit(), "GetKillingUnit nil")
    assert_eq(runtime.GetEventDamage(), 0, "GetEventDamage 0")
    assert_nil(runtime.GetEventDamageSource(), "GetEventDamageSource nil")
    assert_nil(runtime.GetAttacker(), "GetAttacker nil")
    assert_nil(runtime.GetSpellAbilityId(), "GetSpellAbilityId nil")
    assert_nil(runtime.GetSpellTargetUnit(), "GetSpellTargetUnit nil")
    assert_eq(runtime.GetSpellTargetX(), 0, "GetSpellTargetX 0")
    assert_eq(runtime.GetSpellTargetY(), 0, "GetSpellTargetY 0")
    assert_eq(runtime.GetOrderPointX(), 0, "GetOrderPointX 0")
    assert_eq(runtime.GetOrderPointY(), 0, "GetOrderPointY 0")
end)

test("GetTriggerUnit works for all unit events", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local unit = make_unit("testunit")
    local units = {}

    runtime.TriggerAddAction(t, function()
        table.insert(units, runtime.GetTriggerUnit())
    end)

    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DEATH)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_DAMAGED)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_ATTACKED)
    runtime.TriggerRegisterAnyUnitEventBJ(t, events.EVENT.UNIT_SPAWN)

    events.unit_died(unit, nil)
    events.unit_damaged(unit, nil, 10)
    events.unit_attacked(unit, nil)
    events.unit_spawned(unit)

    assert_eq(#units, 4, "4 events")
    for i, u in ipairs(units) do
        assert_eq(u, unit, "unit " .. i)
    end
end)

-- ============================================================================
-- Multiple Triggers Tests
-- ============================================================================

print("\n=== Multiple Triggers ===")

test("multiple triggers on same event type", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    local unit = make_unit("unit")
    local fire1, fire2 = 0, 0

    runtime.TriggerAddAction(t1, function() fire1 = fire1 + 1 end)
    runtime.TriggerAddAction(t2, function() fire2 = fire2 + 1 end)
    runtime.TriggerRegisterAnyUnitEventBJ(t1, events.EVENT.UNIT_DEATH)
    runtime.TriggerRegisterAnyUnitEventBJ(t2, events.EVENT.UNIT_DEATH)

    events.unit_died(unit, nil)
    assert_eq(fire1, 1, "t1 fired")
    assert_eq(fire2, 1, "t2 fired")
end)

test("specific unit registration vs any unit", function()
    runtime.reset()
    local t_specific = runtime.CreateTrigger()
    local t_any = runtime.CreateTrigger()
    local hero = make_unit("hero")
    local peon = make_unit("peon")
    local specific_count, any_count = 0, 0

    runtime.TriggerAddAction(t_specific, function() specific_count = specific_count + 1 end)
    runtime.TriggerAddAction(t_any, function() any_count = any_count + 1 end)

    runtime.TriggerRegisterUnitEvent(t_specific, hero, events.EVENT.UNIT_DEATH)
    runtime.TriggerRegisterAnyUnitEventBJ(t_any, events.EVENT.UNIT_DEATH)

    events.unit_died(peon, nil)
    assert_eq(specific_count, 0, "specific not fired for peon")
    assert_eq(any_count, 1, "any fired for peon")

    events.unit_died(hero, nil)
    assert_eq(specific_count, 1, "specific fired for hero")
    assert_eq(any_count, 2, "any fired for hero")
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
    print("\nALL 308d TESTS PASSED!")
    os.exit(0)
end
