-- supcom-derivative-clone — a factory war on dunes where nothing is out of range
-- Copyright (C) 2026 gabrilend
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at
-- your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
-- General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

-- 027-an-opponent.lua
--
-- covers: 901, 902, 903
--
-- Phase 9: the bot sees only the snapshot and its commands go through the door.
--
-- A bot that cannot cheat is a bot that was never handed the world. These claims
-- are about what the bot is given and what it hands back, and one about the
-- overnight runner: that it plays many matches and writes one line each.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local harness = loadfile(ROOT .. "/tests/018-the-harness.lua")()
harness.start({...}, "027-an-opponent")

local SEED = harness.seed()
local FIELD = {size = 32, dune_height = 20, dune_wavelength = 16, roughness = 0.4,
               water_line = 4, hydrocarbon_rate = 0.02}

-- {{{ what the bot sees
harness.suite("the bot sees a snapshot and answers with commands", function()
  local bot = harness.load("the-bot", "901")
  local snapshot = harness.load("snapshot", "109")
  local the_world = harness.load("the-world", "104")
  local commands = harness.load("commands", "108")
  local world = the_world.allocate({field = FIELD, units = 64, teams = 2, seed = SEED})
  local copy = snapshot.copy(world)
  local hash_before = snapshot.hash(world)
  local answers = bot.think(copy, 1)
  harness.check("thinking did not touch the live world", snapshot.hash(world) == hash_before)
  harness.check("thinking returns a list", type(answers) == "table")
  local all_valid = true
  for _, command in ipairs(answers) do
    if commands.VERBS[command.verb] == nil or command.team ~= 1 then all_valid = false end
  end
  harness.check("every answer is a command the door knows, for the bot's own team", all_valid)
  local first = bot.think(snapshot.copy(world), 1)
  local second = bot.think(snapshot.copy(world), 1)
  harness.check("the measuring bot is deterministic: same snapshot, same answers",
                #first == #second and (first[1] == nil or first[1].verb == second[1].verb))
end)

harness.suite("the bot lays a line and draws a pattern within the first minute", function()
  local bot = harness.load("the-bot", "901")
  local runner = harness.load("headless-runner", "110")
  local report = runner.run(harness.root, {seed = SEED, ticks = 600, field = FIELD, bots = {1, 2}})
  harness.check("both bots placed at least one factory", report.factories[1] > 0 and report.factories[2] > 0)
  harness.check("every factory has a pattern of at least two points", report.shortest_pattern >= 2)
end)
-- }}}

-- {{{ overnight
harness.suite("the overnight runner plays many matches and writes one line each", function()
  local overnight = harness.load("overnight", "902")
  local written = overnight.run(harness.root, {matches = 4, ticks = 200, field = FIELD, workers = 2,
                                               seed = SEED})
  harness.check("it says where it wrote", type(written) == "string" and written:find("/shared%-memory/") ~= nil)
  local handle = io.open(written, "r")
  harness.check("the file exists", handle ~= nil)
  if handle ~= nil then
    local lines = 0
    for _ in handle:lines() do lines = lines + 1 end
    handle:close()
    harness.check("one line per match", lines == 4, "got " .. lines)
  end
end)
-- }}}

-- {{{ difficulty
harness.suite("difficulty comes from decision quality, not from seeing more", function()
  local bot = harness.load("the-bot", "903")
  harness.check("the difficulties are a table", type(bot.DIFFICULTIES) == "table" and #bot.DIFFICULTIES >= 2)
  harness.check("every difficulty thinks from the same snapshot",
                bot.DIFFICULTIES[1].sees == bot.DIFFICULTIES[#bot.DIFFICULTIES].sees)
end)
-- }}}

harness.finish()
