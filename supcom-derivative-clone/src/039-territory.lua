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

-- 039-territory.lua
--
-- Paints ownership on cells by presence.
--
-- Every land cell has an owner: zero, or a team. A claim in progress is the pair
-- of integers on the claim counter -- which team is claiming, and the increment
-- the claim counts from -- and it completes once enough increments have passed
-- with that team alone near the cell. Water is never marked, so it is never
-- claimed and never owned.
--
-- A pass has two halves. Marking walks the live units in array order and sets
-- each team's bit on every land cell within its radius, remembering each cell
-- the first time it is marked. Resolving then walks only those cells, reading
-- the bits and never which unit marked first, so the outcome is the same
-- whatever order the marks arrived in. Once every claim increment, a sweep
-- clears the claims nobody has stood near for a whole claim length.
--
-- The claim writes shared cell state, so its row in the tick is not sliced.

local M = {}

local bit = require("bit")

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
    error("territory: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local timers = world_module.load("timers")
local dunes = world_module.load("the-dunes")

-- The most teams a mark can hold: one bit each in a signed 32-bit integer,
-- keeping clear of the sign bit.
M.TEAMS = 30

-- The land-cell count of each field, counted the first time it is asked for.
-- Keyed weakly by the field, which is never written during a match, so a field
-- nobody holds any more takes its count with it.
local land_of = setmetatable({}, {__mode = "k"})

-- {{{ local function land_cells()
-- How many cells of a field stand at or above its water line.
local function land_cells(field)
  local count = land_of[field]
  if count == nil then
    count = 0
    local height, water = field.height, field.water_line
    for index = 1, field.size * field.size do
      if height[index] >= water then
        count = count + 1
      end
    end
    land_of[field] = count
  end
  return count
end
-- }}}

-- {{{ local function team_of_bit()
-- The team a mark holding exactly one bit names: bit zero is team one.
local function team_of_bit(mark)
  local team = 1
  while mark > 1 do
    mark = bit.rshift(mark, 1)
    team = team + 1
  end
  return team
end
-- }}}

-- {{{ local function check_team()
-- A team is a whole number from one to the world's teams, and within what a
-- mark can hold. Anything else is a refusal naming it.
local function check_team(world, team, level)
  if type(team) ~= "number" or team ~= math.floor(team) or team < 1
     or team > world.team.capacity or team > M.TEAMS then
    error("territory: team " .. tostring(team) .. " is not a team of this world (1 to "
          .. math.min(world.team.capacity, M.TEAMS) .. ")", level + 1)
  end
end
-- }}}

-- {{{ local function check_cell()
-- A cell is an index from one to the field's area.
local function check_cell(world, cell, level)
  local area = world.field.size * world.field.size
  if type(cell) ~= "number" or cell ~= math.floor(cell) or cell < 1 or cell > area then
    error("territory: cell " .. tostring(cell) .. " is not a cell of this field (1 to "
          .. area .. ")", level + 1)
  end
end
-- }}}

-- {{{ function M.claim()
-- What one unit does: marks every land cell within `radius` cells of the cell
-- the position (x, y) stands in as claimed by `team` this tick. Within means
-- the centres are no further apart than the radius. Nothing is decided here;
-- the resolution reads the marks once every unit has made its own.
function M.claim(world, team, x, y, radius)
  check_team(world, team, 2)
  if type(radius) ~= "number" or radius ~= radius or radius < 0 then
    error("territory: a claim radius is " .. tostring(radius) .. ", and must be a number from zero", 2)
  end
  local field = world.field
  local size, height, water = field.size, field.height, field.water_line
  local cx, cy = dunes.cell_of(field, x, y)
  local reach = math.floor(radius)
  local reach_squared = radius * radius
  local bit_of_team = bit.lshift(1, team - 1)
  local mark = world.cell.mark
  local marked = world.marked
  for dy = -reach, reach do
    local cell_y = cy + dy
    if cell_y >= 0 and cell_y < size then
      for dx = -reach, reach do
        local cell_x = cx + dx
        if cell_x >= 0 and cell_x < size and dx * dx + dy * dy <= reach_squared then
          local index = dunes.index(field, cell_x, cell_y)
          if height[index] >= water then
            local was = mark[index]
            if was == 0 then
              local slot = world_module.push(world, "marked")
              marked.cell[slot] = index
            end
            mark[index] = bit.bor(was, bit_of_team)
          end
        end
      end
    end
  end
end
-- }}}

-- {{{ local function clear_claim()
-- No claim in progress on a cell.
local function clear_claim(cell, index)
  cell.claim_by[index] = 0
  cell.claim_began[index] = 0
  cell.claim_seen[index] = 0
end
-- }}}

-- {{{ local function alone()
-- One team is near the cell. If it already owns it, any other team's claim
-- there ends. If the claim in progress is its own, the claim goes on -- less
-- any whole increments it spent away, which do not count -- and completes when
-- enough increments have passed. Otherwise a claim starts for it now.
local function alone(cell, index, team, now, length)
  if cell.owner[index] == team then
    clear_claim(cell, index)
    return
  end
  if cell.claim_by[index] == team then
    local away = now - cell.claim_seen[index] - 1
    if away > 0 then
      cell.claim_began[index] = cell.claim_began[index] + away
    end
  else
    cell.claim_by[index] = team
    cell.claim_began[index] = now
  end
  cell.claim_seen[index] = now
  if now - cell.claim_began[index] >= length then
    cell.owner[index] = team
    clear_claim(cell, index)
  end
end
-- }}}

-- {{{ local function contested()
-- More than one team is near the cell. Nothing changes hands and no claim
-- starts. A claim in progress whose claimant is among them is paused, not
-- reset: its beginning moves on by the increments since its claimant was last
-- counted, so it resumes where it was when the other side leaves.
local function contested(cell, index, mark, now)
  local by = cell.claim_by[index]
  if by ~= 0 and bit.band(mark, bit.lshift(1, by - 1)) ~= 0 then
    cell.claim_began[index] = cell.claim_began[index] + (now - cell.claim_seen[index])
    cell.claim_seen[index] = now
  end
end
-- }}}

-- {{{ local function resolve()
-- Every cell marked this pass, in the order first marked, by the three cases a
-- mark can hold: no bits never reach here, one bit is one team alone, more than
-- one is a contest. Each mark is cleared as it is read and the marked queue is
-- emptied, so nothing of this pass is left for the next or for a fingerprint.
local function resolve(world)
  local cell, marked = world.cell, world.marked
  local now = world.claim.increment
  local length = world.claim.increments_to_claim
  local mark = cell.mark
  for slot = 1, marked.count do
    local index = marked.cell[slot]
    local value = mark[index]
    if bit.band(value, value - 1) == 0 then
      alone(cell, index, team_of_bit(value), now, length)
    else
      contested(cell, index, value, now)
    end
    mark[index] = 0
    marked.cell[slot] = 0
  end
  marked.count = 0
end
-- }}}

-- {{{ local function sweep()
-- Clears every claim whose claimant has not been near its cell for a whole
-- claim length, so a cell somebody walked past does not flip a minute later.
-- Walks every cell, so it runs once a claim increment, not once a tick.
local function sweep(world)
  local cell = world.cell
  local now = world.claim.increment
  local length = world.claim.increments_to_claim
  local claim_by, claim_seen = cell.claim_by, cell.claim_seen
  for index = 1, cell.capacity do
    if claim_by[index] ~= 0 and now - claim_seen[index] >= length then
      clear_claim(cell, index)
    end
  end
end
-- }}}

-- {{{ function M.claim_pass()
-- The tick's claim row. Brings the claim counter up to this tick (asking twice
-- changes nothing), marks around every live unit in array order with the claim
-- radius it was born with, resolves the marks, and on the tick the counter
-- fires sweeps the abandoned claims. A unit whose radius is zero -- a plane --
-- claims nothing.
function M.claim_pass(world)
  local counter = world.claim
  timers.advance(counter, world.tick)
  local unit = world.unit
  local alive, radius = unit.alive, unit.claim_radius
  for id = 1, unit.top do
    if alive[id] == 1 and radius[id] > 0 then
      M.claim(world, unit.team[id], unit.x[id], unit.y[id], radius[id])
    end
  end
  resolve(world)
  if world.tick == counter.next - counter.period then
    sweep(world)
  end
end
-- }}}

-- {{{ function M.owner()
-- Who holds a cell, by its index: zero, or a team.
function M.owner(world, cell)
  check_cell(world, cell, 2)
  return world.cell.owner[cell]
end
-- }}}

-- {{{ function M.percent()
-- A team's owned land cells over all land cells, from zero to one hundred, as a
-- double -- the number every economy rule reads. Team zero is nobody: the land
-- nobody holds. Water is in neither count.
function M.percent(world, team)
  if team ~= 0 then
    check_team(world, team, 2)
  end
  local land = land_cells(world.field)
  if land == 0 then
    return 0
  end
  local owner, height, water = world.cell.owner, world.field.height, world.field.water_line
  local owned = 0
  for index = 1, world.cell.capacity do
    if owner[index] == team and height[index] >= water then
      owned = owned + 1
    end
  end
  return 100 * owned / land
end
-- }}}

-- {{{ function M.land()
-- How many land cells the world's field has, counted once per field.
function M.land(world)
  return land_cells(world.field)
end
-- }}}

return M
