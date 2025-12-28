#!/usr/bin/env lua
--[[
Test Suite for Issue 308e: Player Events

Tests the player event subsystem:
- TriggerRegisterPlayerEvent
- TriggerRegisterPlayerChatEvent
- TriggerRegisterPlayerAllianceChange
- Fire hooks: player_chat, player_left, player_alliance_changed
- Context accessors: GetEventPlayerChatString, GetEventPlayerChatStringMatched
- String utilities: SubString, StringLength

Run from project root: lua src/tests/test_events_308e.lua
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
local function make_player(id, name)
    return {id = id, name = name or ("Player" .. id), _type = "player"}
end
-- }}}

-- ============================================================================
-- TriggerRegisterPlayerEvent Tests
-- ============================================================================

print("\n=== TriggerRegisterPlayerEvent ===")

test("TriggerRegisterPlayerEvent returns listener", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local listener = runtime.TriggerRegisterPlayerEvent(t, player, events.EVENT.PLAYER_LEAVE)
    assert_not_nil(listener, "listener returned")
end)

test("TriggerRegisterPlayerEvent with nil trigger returns nil", function()
    runtime.reset()
    local player = make_player(1)
    assert_nil(runtime.TriggerRegisterPlayerEvent(nil, player, events.EVENT.PLAYER_LEAVE))
end)

test("TriggerRegisterPlayerEvent with nil player returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_nil(runtime.TriggerRegisterPlayerEvent(t, nil, events.EVENT.PLAYER_LEAVE))
end)

test("TriggerRegisterPlayerEvent with nil event_type returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    assert_nil(runtime.TriggerRegisterPlayerEvent(t, player, nil))
end)

test("TriggerRegisterPlayerEvent only fires for specific player", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player1 = make_player(1)
    local player2 = make_player(2)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterPlayerEvent(t, player1, events.EVENT.PLAYER_LEAVE)

    -- Wrong player - should not fire
    events.player_left(player2, "disconnect")
    assert_eq(fire_count, 0, "player2 ignored")

    -- Correct player - should fire
    events.player_left(player1, "disconnect")
    assert_eq(fire_count, 1, "player1 fired")
end)

test("GetTriggerPlayer returns correct player", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1, "TestPlayer")
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetTriggerPlayer()
    end)
    runtime.TriggerRegisterPlayerEvent(t, player, events.EVENT.PLAYER_LEAVE)

    events.player_left(player, "disconnect")
    assert_eq(captured, player, "captured player")
end)

-- ============================================================================
-- TriggerRegisterPlayerChatEvent Tests
-- ============================================================================

print("\n=== TriggerRegisterPlayerChatEvent ===")

test("TriggerRegisterPlayerChatEvent returns listener", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local listener = runtime.TriggerRegisterPlayerChatEvent(t, nil, "", false)
    assert_not_nil(listener, "listener returned")
end)

test("TriggerRegisterPlayerChatEvent with nil trigger returns nil", function()
    runtime.reset()
    assert_nil(runtime.TriggerRegisterPlayerChatEvent(nil, nil, "", false))
end)

test("TriggerRegisterPlayerChatEvent fires for any player when player is nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player1 = make_player(1)
    local player2 = make_player(2)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterPlayerChatEvent(t, nil, "", false)

    events.player_chat(player1, "hello")
    events.player_chat(player2, "world")

    assert_eq(fire_count, 2, "both players fired")
end)

test("TriggerRegisterPlayerChatEvent fires only for specific player", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player1 = make_player(1)
    local player2 = make_player(2)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterPlayerChatEvent(t, player1, "", false)

    events.player_chat(player2, "hello")
    assert_eq(fire_count, 0, "player2 ignored")

    events.player_chat(player1, "hello")
    assert_eq(fire_count, 1, "player1 fired")
end)

test("TriggerRegisterPlayerChatEvent with exact match", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterPlayerChatEvent(t, player, "hello", true)

    -- Exact match - should fire
    events.player_chat(player, "hello")
    assert_eq(fire_count, 1, "exact match fired")

    -- Different message - should not fire
    events.player_chat(player, "hello world")
    assert_eq(fire_count, 1, "partial no match")

    events.player_chat(player, "HELLO")
    assert_eq(fire_count, 1, "case mismatch")
end)

test("TriggerRegisterPlayerChatEvent with substring match", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterPlayerChatEvent(t, player, "-spawn", false)

    -- Contains substring - should fire
    events.player_chat(player, "-spawn orc")
    assert_eq(fire_count, 1, "substring match 1")

    events.player_chat(player, "try -spawn command")
    assert_eq(fire_count, 2, "substring match 2")

    -- Does not contain - should not fire
    events.player_chat(player, "-spwn typo")
    assert_eq(fire_count, 2, "no substring")
end)

test("TriggerRegisterPlayerChatEvent substring is case-sensitive", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterPlayerChatEvent(t, player, "-spawn", false)

    events.player_chat(player, "-SPAWN unit")
    assert_eq(fire_count, 0, "case sensitive")

    events.player_chat(player, "-spawn unit")
    assert_eq(fire_count, 1, "correct case")
end)

test("TriggerRegisterPlayerChatEvent empty message matches everything", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterPlayerChatEvent(t, player, "", false)

    events.player_chat(player, "anything")
    events.player_chat(player, "")
    events.player_chat(player, "another message")

    assert_eq(fire_count, 3, "all messages matched")
end)

-- ============================================================================
-- Chat Context Accessors
-- ============================================================================

print("\n=== Chat Context Accessors ===")

test("GetEventPlayerChatString returns full message", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetEventPlayerChatString()
    end)
    runtime.TriggerRegisterPlayerChatEvent(t, nil, "", false)

    events.player_chat(player, "hello world")
    assert_eq(captured, "hello world", "full message")
end)

test("GetEventPlayerChatStringMatched returns matched portion for exact match", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetEventPlayerChatStringMatched()
    end)
    runtime.TriggerRegisterPlayerChatEvent(t, player, "hello", true)

    events.player_chat(player, "hello")
    assert_eq(captured, "hello", "matched exact")
end)

test("GetEventPlayerChatStringMatched returns matched portion for substring", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetEventPlayerChatStringMatched()
    end)
    runtime.TriggerRegisterPlayerChatEvent(t, player, "-spawn", false)

    events.player_chat(player, "-spawn orc")
    assert_eq(captured, "-spawn", "matched substring")
end)

test("GetEventPlayerChatStringMatched returns full message when no filter", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetEventPlayerChatStringMatched()
    end)
    runtime.TriggerRegisterPlayerChatEvent(t, nil, "", false)

    events.player_chat(player, "full message here")
    assert_eq(captured, "full message here", "matched all")
end)

test("Chat accessors return empty string outside context", function()
    runtime.reset()
    assert_eq(runtime.GetEventPlayerChatString(), "", "empty string")
    assert_eq(runtime.GetEventPlayerChatStringMatched(), "", "empty matched")
end)

-- ============================================================================
-- Player Leave Event Tests
-- ============================================================================

print("\n=== Player Leave Events ===")

test("player_left fires PLAYER_LEAVE", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterPlayerEvent(t, player, events.EVENT.PLAYER_LEAVE)

    events.player_left(player, "disconnect")
    assert_true(fired, "trigger fired")
end)

test("GetPlayerLeaveReason returns reason", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetPlayerLeaveReason()
    end)
    runtime.TriggerRegisterPlayerEvent(t, player, events.EVENT.PLAYER_LEAVE)

    events.player_left(player, "defeat")
    assert_eq(captured, "defeat", "captured reason")
end)

test("GetPlayerLeaveReason defaults to disconnect", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local captured = nil

    runtime.TriggerAddAction(t, function()
        captured = runtime.GetPlayerLeaveReason()
    end)
    runtime.TriggerRegisterPlayerEvent(t, player, events.EVENT.PLAYER_LEAVE)

    events.player_left(player, nil)
    assert_eq(captured, "disconnect", "default reason")
end)

-- ============================================================================
-- Player Alliance Change Event Tests
-- ============================================================================

print("\n=== Player Alliance Change Events ===")

test("player_alliance_changed fires PLAYER_ALLIANCE_CHANGE", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player1 = make_player(1)
    local player2 = make_player(2)
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterPlayerAllianceChange(t, player1)

    events.player_alliance_changed(player1, player2, "enemy", "allied")
    assert_true(fired, "trigger fired")
end)

test("TriggerRegisterPlayerAllianceChange fires for either side", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player1 = make_player(1)
    local player2 = make_player(2)
    local player3 = make_player(3)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)
    runtime.TriggerRegisterPlayerAllianceChange(t, player2)

    -- player1 initiates, player2 involved - should fire
    events.player_alliance_changed(player1, player2, "neutral", "allied")
    assert_eq(fire_count, 1, "as other_player")

    -- player2 initiates - should fire
    events.player_alliance_changed(player2, player3, "neutral", "enemy")
    assert_eq(fire_count, 2, "as initiator")

    -- Neither is player2 - should not fire
    events.player_alliance_changed(player1, player3, "allied", "enemy")
    assert_eq(fire_count, 2, "not involved")
end)

test("TriggerRegisterPlayerAllianceChange with nil player returns nil", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    assert_nil(runtime.TriggerRegisterPlayerAllianceChange(t, nil))
end)

-- ============================================================================
-- Player Defeat/Victory Events
-- ============================================================================

print("\n=== Player Defeat/Victory Events ===")

test("player_defeated fires PLAYER_DEFEAT", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterPlayerEvent(t, player, events.EVENT.PLAYER_DEFEAT)

    events.player_defeated(player)
    assert_true(fired, "trigger fired")
end)

test("player_victorious fires PLAYER_VICTORY", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local fired = false

    runtime.TriggerAddAction(t, function() fired = true end)
    runtime.TriggerRegisterPlayerEvent(t, player, events.EVENT.PLAYER_VICTORY)

    events.player_victorious(player)
    assert_true(fired, "trigger fired")
end)

-- ============================================================================
-- String Utility Functions
-- ============================================================================

print("\n=== String Utilities ===")

test("SubString converts from 0-indexed", function()
    runtime.reset()
    local s = "hello world"
    -- WC3 SubString(s, 0, 4) = "hello" (indices 0-4 inclusive)
    assert_eq(runtime.SubString(s, 0, 4), "hello", "0 to 4")
    -- WC3 SubString(s, 6, 10) = "world"
    assert_eq(runtime.SubString(s, 6, 10), "world", "6 to 10")
end)

test("SubString handles edge cases", function()
    runtime.reset()
    assert_eq(runtime.SubString("abc", 0, 0), "a", "single char")
    assert_eq(runtime.SubString("abc", 1, 1), "b", "middle char")
    assert_eq(runtime.SubString("abc", 0, 2), "abc", "full string")
    assert_eq(runtime.SubString(nil, 0, 5), "", "nil string")
end)

test("StringLength returns correct length", function()
    runtime.reset()
    assert_eq(runtime.StringLength(""), 0, "empty")
    assert_eq(runtime.StringLength("hello"), 5, "hello")
    assert_eq(runtime.StringLength("hello world"), 11, "with space")
    assert_eq(runtime.StringLength(nil), 0, "nil")
end)

-- ============================================================================
-- Multiple Triggers Tests
-- ============================================================================

print("\n=== Multiple Triggers ===")

test("multiple chat triggers with different filters", function()
    runtime.reset()
    local t1 = runtime.CreateTrigger()
    local t2 = runtime.CreateTrigger()
    local player = make_player(1)
    local spawn_count, kill_count = 0, 0

    runtime.TriggerAddAction(t1, function() spawn_count = spawn_count + 1 end)
    runtime.TriggerAddAction(t2, function() kill_count = kill_count + 1 end)

    runtime.TriggerRegisterPlayerChatEvent(t1, player, "-spawn", false)
    runtime.TriggerRegisterPlayerChatEvent(t2, player, "-kill", false)

    events.player_chat(player, "-spawn orc")
    assert_eq(spawn_count, 1, "spawn fired")
    assert_eq(kill_count, 0, "kill not fired")

    events.player_chat(player, "-kill all")
    assert_eq(spawn_count, 1, "spawn still 1")
    assert_eq(kill_count, 1, "kill fired")
end)

test("same trigger multiple chat patterns", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local fire_count = 0

    runtime.TriggerAddAction(t, function() fire_count = fire_count + 1 end)

    runtime.TriggerRegisterPlayerChatEvent(t, player, "-help", false)
    runtime.TriggerRegisterPlayerChatEvent(t, player, "-info", false)

    events.player_chat(player, "-help me")
    assert_eq(fire_count, 1, "help fired")

    events.player_chat(player, "-info")
    assert_eq(fire_count, 2, "info fired")

    events.player_chat(player, "-other")
    assert_eq(fire_count, 2, "other not fired")
end)

-- ============================================================================
-- Typical Use Case: Chat Command Parsing
-- ============================================================================

print("\n=== Chat Command Pattern ===")

test("parse chat command like WC3 maps do", function()
    runtime.reset()
    local t = runtime.CreateTrigger()
    local player = make_player(1)
    local parsed_cmd = nil

    runtime.TriggerAddAction(t, function()
        local msg = runtime.GetEventPlayerChatString()
        -- Parse command after "-spawn "
        local prefix_len = runtime.StringLength("-spawn ")
        local msg_len = runtime.StringLength(msg)
        parsed_cmd = runtime.SubString(msg, prefix_len, msg_len - 1)
    end)

    runtime.TriggerRegisterPlayerChatEvent(t, player, "-spawn ", false)

    events.player_chat(player, "-spawn footman")
    assert_eq(parsed_cmd, "footman", "parsed footman")

    events.player_chat(player, "-spawn orc grunt")
    assert_eq(parsed_cmd, "orc grunt", "parsed orc grunt")
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
    print("\nALL 308e TESTS PASSED!")
    os.exit(0)
end
