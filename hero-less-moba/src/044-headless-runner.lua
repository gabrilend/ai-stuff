-- hero-less-moba — a lane-pushing game with the heroes subtracted out
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

-- 044-headless-runner.lua
--
-- Runs a match with no window at all, as fast as the machine allows, and prints
-- what happened.
--
-- This is not a debugging convenience that will be thrown away. It is half of the
-- reason the simulation and the viewer are separate programs: balance work is
-- running ten thousand matches overnight and reading a table in the morning, and
-- that is not possible if drawing is welded to simulating.
--
-- It is also the fastest way to find out whether a change broke the game. A
-- window shows one match at one speed; this shows a thousand, and the two most
-- valuable tests in the project run through here -- that the same seed produces
-- the same match tick for tick, and that a match with no commands in it stays
-- exactly symmetric between the two teams.
--
-- Usage, from the project root:
--   luajit src/044-headless-runner.lua               -- one match, report at the end
--   luajit src/044-headless-runner.lua 5000          -- stop after 5000 ticks
--   luajit src/044-headless-runner.lua 5000 trace    -- print a line every 600 ticks

local M = {}

-- {{{ function M.run()
-- Advances a world until it ends or the tick limit is reached. Returns the world
-- so a caller can read whatever it wants off it.
function M.run(world, tick_module, limit, on_tick)
  while world.tick < limit do
    if not tick_module.advance(world) then
      break
    end
    if on_tick ~= nil then
      on_tick(world)
    end
  end
  return world
end
-- }}}

-- {{{ function M.report()
-- The match, as a table. Deliberately made of the numbers a balance question is
-- asked in -- waves lost per lane, upgrades drawn, where the frontlines ended --
-- rather than of prose.
function M.report(world)
  local lines = {}
  local outcome = "still running"
  if world.winner == 1 then outcome = "team 1 wins"
  elseif world.winner == 2 then outcome = "team 2 wins"
  elseif world.winner == 3 then outcome = "a draw -- both libraries fell on one tick"
  end

  lines[#lines + 1] = string.format("tick %d -- %s", world.tick, outcome)
  lines[#lines + 1] = string.format("%d bodies on the field, %d waves spawned",
                                    world.live_count, #world.wave)

  lines[#lines + 1] = ""
  lines[#lines + 1] = "                     lane 1   lane 2   lane 3"
  for team = 1, 2 do
    local depths = {}
    local losses = {}
    for lane = 1, world.parameters.lane_count do
      depths[lane] = world.team[team].push_depth[lane]
      losses[lane] = world.team[team].waves_lost[lane]
    end
    lines[#lines + 1] = string.format("team %d push depth   %6d   %6d   %6d",
                                      team, depths[1], depths[2], depths[3])
    lines[#lines + 1] = string.format("team %d waves lost   %6d   %6d   %6d",
                                      team, losses[1], losses[2], losses[3])
  end

  lines[#lines + 1] = ""
  for team = 1, 2 do
    local in_chest, in_lanes, in_stone = world.chest.total_held(world, team)
    lines[#lines + 1] = string.format(
      "team %d drew %d upgrades -- %d unplaced, %d in lanes, %d in stone",
      team, world.team[team].draws_taken, in_chest, in_lanes, in_stone)
  end

  lines[#lines + 1] = ""
  local standing = {0, 0}
  for _, structure in ipairs(world.structure) do
    if structure.alive == 1 and structure.kind ~= 3 then
      standing[structure.team] = standing[structure.team] + 1
    end
  end
  lines[#lines + 1] = string.format("towers standing -- team 1: %d, team 2: %d",
                                    standing[1], standing[2])
  for team = 1, 2 do
    for _, structure in ipairs(world.structure) do
      if structure.kind == 3 and structure.team == team then
        lines[#lines + 1] = string.format("team %d library at %.0f%% health",
          team, 100 * structure.health / structure.health_max)
      end
    end
  end

  return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.main()
-- The command-line entry. Kept apart from M.run so that a test can drive a match
-- without going through argument parsing.
function M.main(arguments)
  local here = debug.getinfo(1, "S").source:match("^@(.*)/src/[^/]+$") or "."

  local tick_module = loadfile(here .. "/src/042-the-tick.lua")()
  local modules = tick_module.load_cast(here)
  local parameters = modules.match_parameters.load()
  local world = tick_module.assemble(modules, parameters)

  local limit = tonumber(arguments[1]) or 30000
  local trace = (arguments[2] == "trace")

  local ticks_per_second = parameters.unit.ticks_per_second
  local started = os.clock()

  M.run(world, tick_module, limit, trace and function(w)
    if w.tick % 600 == 0 then
      io.write(string.format(
        "t%6d  %5.0fs  bodies %4d  depth %d/%d/%d vs %d/%d/%d  chest %d/%d\n",
        w.tick, w.tick / ticks_per_second, w.live_count,
        w.team[1].push_depth[1], w.team[1].push_depth[2], w.team[1].push_depth[3],
        w.team[2].push_depth[1], w.team[2].push_depth[2], w.team[2].push_depth[3],
        w.team[1].draws_taken, w.team[2].draws_taken))
    end
  end or nil)

  local elapsed = os.clock() - started
  print(M.report(world))
  print("")
  print(string.format("%d ticks in %.2fs -- %.0f ticks per second, %.0fx real time",
        world.tick, elapsed, world.tick / elapsed,
        (world.tick / elapsed) / ticks_per_second))

  return world
end
-- }}}

-- Run when invoked directly, stay quiet when loaded as a module.
--
-- The test is `arg[0]`, which the interpreter sets to the script it was asked to
-- run. Comparing it against this file's own name distinguishes "somebody typed
-- luajit at this file" from "some other program loaded it" -- which the usual
-- trick of checking `...` cannot do here, because a script run with no arguments
-- and a chunk loaded by loadfile both receive nothing.
local invoked_directly = arg ~= nil
  and arg[0] ~= nil
  and arg[0]:match("044%-headless%-runner%.lua$") ~= nil

if invoked_directly then
  M.main(arg)
end

return M
