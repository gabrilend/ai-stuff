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

-- 050-economy.lua
--
-- Ground a team holds pays mass while it is held: the tick's income pass.
--
-- There is no extractor and nothing to place. Every tick the income pass walks
-- the cells once, counts the land cells each team owns, and adds that count
-- times the rules' `mass_per_cell` to the team's mass; the tick's income is
-- kept beside it, in `mass_income_last_tick`, for a viewer to show. Lose a cell
-- and its pay leaves on the tick it is lost; take one and it pays the same way.
-- Water is never owned and never pays. Construction (issue 305) is what spends
-- the mass; energy (issue 303), consequences (issue 309) and improvement (issue
-- 311) join this file later.

local M = {}

-- {{{ local function the_world()
-- The world module, which holds the loader every module uses to find another by
-- its stem. It is found here by that same rule -- exactly one NNN-the-world.lua
-- beside this file -- because a file cannot use the loader to find the loader.
local function the_world()
  local path = debug.getinfo(1, "S").source:sub(2)
  if path:sub(1, 1) ~= "/" then
    path = os.getenv("PWD") .. "/" .. path
  end
  local here = path:match("^(.*)/[^/]+$")
  local found = {}
  local handle = io.popen("ls -1 '" .. here .. "' 2>/dev/null")
  for name in handle:lines() do
    if name:match("^%d%d%d%-the%-world%.lua$") then
      found[#found + 1] = here .. "/" .. name
    end
  end
  handle:close()
  if #found ~= 1 then
    error("economy: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()

-- The per-team counts the income pass fills, reused every tick so the pass
-- allocates nothing once a match is under way.
local held = {}

-- {{{ function M.cell_pays()
-- The mass one cell pays its owner each tick: the rules' `mass_per_cell` for an
-- owned land cell, nothing for a cell nobody holds or for water. Improvement
-- (issue 311) raises it.
function M.cell_pays(world, cell)
  local field = world.field
  if world.cell.owner[cell] == 0 or field.height[cell] < field.water_line then
    return 0
  end
  return world.rule.mass_per_cell
end
-- }}}

-- {{{ function M.held_cells()
-- How many land cells a team owns now.
function M.held_cells(world, team)
  local field, owner = world.field, world.cell.owner
  local height, water = field.height, field.water_line
  local count = 0
  for cell = 1, field.size * field.size do
    if owner[cell] == team and height[cell] >= water then
      count = count + 1
    end
  end
  return count
end
-- }}}

-- {{{ function M.income_pass()
-- The tick's income row, on one worker: the owned land cells counted per team in
-- one walk of the cells, in cell order, and each team's mass raised by its count
-- times the pay per cell. Integers throughout, so every machine reaches the
-- same total. Writes `mass` and `mass_income_last_tick` for every team.
function M.income_pass(world)
  local field, owner, team = world.field, world.cell.owner, world.team
  local height, water = field.height, field.water_line
  local teams = team.capacity
  for index = 1, teams do
    held[index] = 0
  end
  for cell = 1, field.size * field.size do
    local who = owner[cell]
    if who ~= 0 and height[cell] >= water then
      held[who] = held[who] + 1
    end
  end
  local pay = world.rule.mass_per_cell
  for index = 1, teams do
    local income = held[index] * pay
    team.mass_income_last_tick[index] = income
    team.mass[index] = team.mass[index] + income
  end
end
-- }}}

return M
