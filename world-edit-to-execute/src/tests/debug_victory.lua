#!/usr/bin/env luajit
-- debug_victory.lua
-- Debug script for testing victory condition behavior.
-- Useful for investigating player initialization and victory detection.
--
-- Run: luajit src/tests/debug_victory.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local player = require("runtime.player")

print("=== Victory Condition Debug ===\n")

player.reset()

-- Note: init_manual uses ipairs, so must pass array format with 'slot' field
-- NOT a map like {[0] = {...}, [1] = {...}}
player.init_manual({
    {slot = 0, type = "human", race = "human", team = 0, name = "Player 1"},
    {slot = 1, type = "computer", race = "orc", team = 1, name = "Computer"},
})

print("Before start_game:")
print("  started:", player.is_game_started())
print("  check_victory_conditions:", player.check_victory_conditions())

local p0 = player.get(0)
local p1 = player.get(1)
print("  Player 0:", p0 and p0.name, "state:", p0 and p0.state)
print("  Player 1:", p1 and p1.name, "state:", p1 and p1.state)

player.start_game()

print("\nAfter start_game:")
print("  started:", player.is_game_started())
print("  ended:", player.is_game_ended())
print("  check_victory_conditions:", player.check_victory_conditions())

p0 = player.get(0)
p1 = player.get(1)
print("  Player 0:", p0 and p0.name, "state:", p0 and p0.state)
print("  Player 1:", p1 and p1.name, "state:", p1 and p1.state)

-- Defeat player 1
print("\nDefeating player 1...")
player.defeat(1)

print("\nAfter defeat:")
print("  ended:", player.is_game_ended())
print("  check_victory_conditions:", player.check_victory_conditions())

p0 = player.get(0)
p1 = player.get(1)
print("  Player 0:", p0 and p0.name, "state:", p0 and p0.state)
print("  Player 1:", p1 and p1.name, "state:", p1 and p1.state)

local result = player.get_game_result()
if result then
    print("\nGame result:")
    print("  ended:", result.ended)
    print("  winning_team:", result.winning_team)
end
