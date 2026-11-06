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

-- 042-domains.lua
--
-- Land, air and sea: the one question a domain answers is where a unit may stand.
--
-- There is no ship code, plane code or tank code. A domain is an integer in the
-- unit row, and what it changes for movement is one question -- may this unit
-- stand here? -- answered by reading the heightfield: land at or above the water
-- line, sea below it, air anywhere. The domains are a dispatch table, one row
-- per domain, so adding one (the submerged carrier of issue 506) is adding a
-- row, not a branch. What a domain changes for combat is the catalogue's
-- `reaches`, a bit set over the same domains, whose bits are named here too.

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
    error("domains: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local dunes = world_module.load("the-dunes")

-- The domains as named integers. The integer is what a unit row and a
-- catalogue row hold.
M.LAND = 1
M.AIR = 2
M.SEA = 3
M.DOMAINS = {land = M.LAND, air = M.AIR, sea = M.SEA}
M.NAMES = {"land", "air", "sea"}

-- A weapon's reach is a bit set over the domains: the bit for domain d is
-- 2^(d-1), so land 1, air 2, sea 4.
M.REACH = {land = 1, air = 2, sea = 4}

-- {{{ STAND
-- The dispatch table: for each domain, whether a cell of the given height may
-- hold it, given the field's water line.
M.STAND = {
  [M.LAND] = function(height, water) return height >= water end,
  [M.AIR] = function() return true end,
  [M.SEA] = function(height, water) return height < water end,
}
-- }}}

-- {{{ local function domain_of()
-- A domain given as a name or an integer, as its integer; refused by name.
local function domain_of(domain, level)
  local value = domain
  if type(domain) == "string" then
    value = M.DOMAINS[domain]
  end
  if type(value) ~= "number" or M.STAND[value] == nil then
    error("domains: '" .. tostring(domain) .. "' is not a domain (land, air, sea)", level + 1)
  end
  return value
end
-- }}}

-- {{{ local function cell_at()
-- The cell a position stands in, refusing a position off the field by name. A
-- cell spans half a unit either side of its integer coordinates.
local function cell_at(field, x, y, level)
  local size = field.size
  if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
     or x < -0.5 or y < -0.5 or x >= size - 0.5 or y >= size - 0.5 then
    error(string.format("domains: (%s, %s) is off the field, which runs from -0.5 to %.1f",
                        tostring(x), tostring(y), size - 0.5), level + 1)
  end
  return dunes.cell_of(field, x, y)
end
-- }}}

-- {{{ function M.can_stand()
-- Whether a unit of `domain` (a name or an integer) may stand at the position
-- (x, y): the position's cell is read off the field and the domain's row of the
-- dispatch table answers. A position off the field is refused, not answered.
function M.can_stand(field, domain, x, y)
  local value = domain_of(domain, 2)
  local cx, cy = cell_at(field, x, y, 2)
  return M.STAND[value](field.height[dunes.index(field, cx, cy)], field.water_line)
end
-- }}}

-- {{{ function M.ground_at()
-- The height of the ground under a position, as its cell's height.
function M.ground_at(field, x, y)
  local cx, cy = cell_at(field, x, y, 2)
  return field.height[dunes.index(field, cx, cy)]
end
-- }}}

-- {{{ function M.altitude_at()
-- Where a unit of `kind` (a name or an index) flies over (x, y): the ground
-- beneath plus the kind's flight height, so a plane crossing a dune climbs with
-- it. Over the water the ground is the water line, never the sea floor. Zero
-- for a kind that does not fly.
function M.altitude_at(field, kind, x, y)
  local row = world_module.load("units").kind(kind)
  if row.altitude <= 0 then
    return 0
  end
  local ground = M.ground_at(field, x, y)
  if ground < field.water_line then
    ground = field.water_line
  end
  return ground + row.altitude
end
-- }}}

-- {{{ function M.is_shore()
-- Whether (x, y) is a shore cell: land with sea in one of its four neighbours.
-- A sea factory stands on one and its output appears on the sea beside it.
function M.is_shore(field, x, y)
  local cx, cy = cell_at(field, x, y, 2)
  local height, water, size = field.height, field.water_line, field.size
  if height[dunes.index(field, cx, cy)] < water then
    return false
  end
  for _, step in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
    local nx, ny = cx + step[1], cy + step[2]
    if nx >= 0 and ny >= 0 and nx < size and ny < size
       and height[dunes.index(field, nx, ny)] < water then
      return true
    end
  end
  return false
end
-- }}}

-- {{{ function M.validate()
-- The domain check of the unit rows, called from the units validator: every
-- live, filled row stands where its domain may. A land unit in the sea is a
-- refusal naming the row, never a fallback.
function M.validate(world)
  local unit, field = world.unit, world.field
  for id = 1, unit.top do
    if unit.alive[id] == 1 and unit.kind[id] ~= 0 then
      local ok, fine = pcall(M.can_stand, field, unit.domain[id], unit.x[id], unit.y[id])
      if not ok then
        error("units: row " .. id .. " stands off the field: " .. tostring(fine), 2)
      end
      if not fine then
        error(string.format("units: row %d is a %s unit at (%g, %g), where its domain may not stand",
                            id, M.NAMES[unit.domain[id]] or "?", unit.x[id], unit.y[id]), 2)
      end
    end
  end
end
-- }}}

return M
