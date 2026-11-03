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

-- 051-energy-menu.lua
--
-- The always-open energy menu: four buttons deciding how many of a team's
-- engineers go to energy, and never a fifth.
--
-- The menu is one lever. Each of its four levels is a fraction of a team's
-- engineers put to energy duty -- none, a third, two thirds, all -- written as
-- a whole number of thirds, so the split is exact integer arithmetic and every
-- machine rounds the same way. The rest of the engineers are build power. A
-- team holds one current level, `world.team.energy_level`; zero means no
-- button has been pressed yet, which puts nobody on energy. This file is the
-- one place that decides what the levels are; the command door's
-- `set-energy-level` verb presses one through `set_level`, so a level is
-- queued and applied at its stamped tick like every other command. What the
-- engineers on energy duty do is issue 303's, and D1's.

local M = {}


-- {{{ LEVELS
-- The four buttons, in order: a name, and the share of engineers on energy as
-- a whole number of thirds. There is no fifth row, and nothing may add one.
M.LEVELS = {
  {name = "none", thirds = 0},
  {name = "a third", thirds = 1},
  {name = "two thirds", thirds = 2},
  {name = "all", thirds = 3},
}
-- }}}

-- {{{ function M.refusal()
-- Why `level` cannot be pressed for `team` in `world`, or nil when it can: the
-- team must be one the world has, and the level one of the four.
function M.refusal(world, team, level)
  if type(team) ~= "number" or team ~= math.floor(team) or team < 1 or team > world.team.capacity then
    return "the energy menu belongs to a team, and this match has no team " .. tostring(team)
  end
  if type(level) ~= "number" or level ~= math.floor(level) or M.LEVELS[level] == nil then
    return "the energy menu has four buttons, and there is no button " .. tostring(level)
  end
  return nil
end
-- }}}

-- {{{ function M.set_level()
-- Presses a team's button: writes the level. Refuses, by name, a level that is
-- not one to four and a team the world does not have.
function M.set_level(world, team, level)
  local reason = M.refusal(world, team, level)
  if reason ~= nil then
    error("energy-menu: " .. reason, 2)
  end
  world.team.energy_level[team] = level
end
-- }}}

-- {{{ function M.level()
-- A team's level now: the button last pressed, or the first (nobody on
-- energy) when none has been.
function M.level(world, team)
  local level = world.team.energy_level[team]
  if level == 0 then
    return 1
  end
  return level
end
-- }}}

-- {{{ function M.split()
-- `engineers` of a team divided by its level: how many are on energy duty (the
-- level's thirds of them, rounded down) and how many are on build duty (the
-- rest), as two whole numbers. The roster (issue 304) passes its engineer
-- count here; no other code computes the fraction.
function M.split(world, team, engineers)
  if type(engineers) ~= "number" or engineers ~= math.floor(engineers) or engineers < 0 then
    error("energy-menu: an engineer count is " .. tostring(engineers) .. ", not a whole number from zero", 2)
  end
  local energy = math.floor(engineers * M.LEVELS[M.level(world, team)].thirds / 3)
  return energy, engineers - energy
end
-- }}}

return M
