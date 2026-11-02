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

-- 028-the-dunes.lua
--
-- Raises the field from a seed.
--
-- The field is the whole map: one height per cell, a water line, and a handful of
-- things derived from the heights once so nothing derives them again (where the
-- hydrocarbon is, where each team starts, the tallest cell of each coarse region).
-- Nothing here is stored per tick and nothing here changes after `raise` returns.
--
-- **The noise is a hash of position, not a stream.** Every layer's value at a
-- lattice point is a thirty-two-bit hash of the seed, the layer, and the point's
-- integer coordinates, and a cell's height is the four surrounding lattice values
-- blended. So a cell depends on nothing but the seed and its own coordinates: no
-- draw order, no shared generator, and the handheld's C can raise the same field
-- from the same words. The hash uses only thirty-two-bit operations through the
-- `bit` library for exactly that reason.
--
-- The tool refuses rather than repairs. A field that fails `validate` is never
-- returned; the refusal says what was wrong and where.

local bit = require("bit")

local M = {}

-- {{{ the field record
-- The record `raise` returns. Every list here is a Lua array, one-based and
-- row-major, because the field is read constantly and never written after it is
-- raised; the world's per-tick state is what lives in foreign arrays.
M.RECORD = {
  {name = "size",        type = "integer", holds = "cells per side; the field is square"},
  {name = "height",      type = "double",  per = "cell",   holds = "the ground"},
  {name = "water_line",  type = "double",  holds = "every cell below it is water"},
  {name = "hydrocarbon", type = "integer", per = "cell",   holds = "one where the ground holds bonus energy"},
  {name = "region",      type = "integer", holds = "cells per side of one coarse region"},
  {name = "regions",     type = "integer", holds = "coarse regions per side"},
  {name = "tallest",     type = "double",  per = "region", holds = "the highest cell in each region"},
  {name = "start_x",     type = "integer", per = "team",   holds = "each team's starting cell, x"},
  {name = "start_y",     type = "integer", per = "team",   holds = "each team's starting cell, y"},
}
-- }}}

-- {{{ the shape
-- The parameters a field is raised from, every one required. A missing one is
-- refused by name: a default here would be a field nobody asked for.
M.PARAMETERS = {"size", "dune_height", "dune_wavelength", "roughness", "water_line",
                "hydrocarbon_rate"}

-- How the three layers are put together from those parameters. These are the
-- shape of a dune field, not balance numbers, and they are here rather than in a
-- catalogue because changing one changes what the tool *is*.
--
--   swell   -- the long low shapes: a wavelength this many times the dunes',
--              carrying this share of the dune height
--   ridges  -- the dunes themselves: crests laid across the swell at an angle,
--              stretched along the crest so they read as ridges, not hills
--   rough   -- the fine surface: a wavelength of this many cells, an amplitude
--              of `roughness` times this share of the dune height
--   causeway -- this share of the dune height lifted along the diagonal between
--              the start corners and lowered toward the other two
--   start   -- each start region is a square this share of the field's side
--   region  -- cells per side of the sightline's coarse regions
M.SHAPE = {
  swell_wavelength = 2.5, swell_share = 0.6,
  ridge_share = 0.4, ridge_stretch = 3, ridge_angle_sin = 0.5, ridge_angle_cos = 0.8660254037844386,
  rough_wavelength = 2, rough_share = 0.1, causeway_share = 0.5,
  start_share = 0.25, region = 8,
}

-- The layer numbers folded into the hash, so two layers never share a lattice.
local SWELL, RIDGES, ROUGH, HYDROCARBON = 1, 2, 3, 4

-- The grading the dump uses, low to high. Water is its own mark.
local GRADES = {".", ":", "-", "=", "+", "*", "#", "%", "@"}
local WATER = "~"
-- }}}

-- {{{ function M.index()
-- The one place a cell's index is computed. Cells are counted from zero on each
-- axis, row-major, and arrays are one-based; nothing else in the project does
-- this arithmetic -- every other module asks.
function M.index(field, x, y)
  return y * field.size + x + 1
end
-- }}}

-- {{{ function M.cell_of()
-- The cell a position stands in. A position is in cell units with a cell's centre
-- at its integer coordinates, so position (10, 10) is the middle of cell (10, 10)
-- and the cell spans half a unit either side. Positions off the field are held to
-- its edge, because the edge is the last ground there is.
function M.cell_of(field, x, y)
  local cx = math.floor(x + 0.5)
  local cy = math.floor(y + 0.5)
  if cx < 0 then cx = 0 elseif cx > field.size - 1 then cx = field.size - 1 end
  if cy < 0 then cy = 0 elseif cy > field.size - 1 then cy = field.size - 1 end
  return cx, cy
end
-- }}}

-- {{{ local function mul32()
-- Thirty-two-bit multiplication, wrapping, exactly as C's uint32_t would do it.
-- A double holds a product of up to 2^53 exactly and two thirty-two-bit numbers
-- can make 2^64, so the multiplier is split into sixteen-bit halves and each
-- partial product stays below 2^48.
local function mul32(a, b)
  a = a % 4294967296
  local low = bit.band(b, 0xffff)
  local high = bit.rshift(b, 16)
  return bit.tobit(a * low + bit.lshift(bit.tobit(a * high), 16))
end
-- }}}

-- {{{ local function lattice()
-- The hash at the heart of the field: seed, layer, and lattice point in, a double
-- in [0, 1) out. The coordinates are spread by three odd constants and folded
-- together, then mixed by the finaliser from MurmurHash3, which is small, public,
-- and moves every input bit into every output bit.
local function lattice(seed, layer, x, y)
  local h = bit.bxor(seed, mul32(x, 0x8da6b343), mul32(y, 0xd8163841), mul32(layer, 0xcb1ab31f))
  h = bit.bxor(h, bit.rshift(h, 16))
  h = mul32(h, 0x85ebca6b)
  h = bit.bxor(h, bit.rshift(h, 13))
  h = mul32(h, 0xc2b2ae35)
  h = bit.bxor(h, bit.rshift(h, 16))
  return (h % 4294967296) / 4294967296
end
-- }}}

-- {{{ local function fade()
-- The weight between two lattice points. A plain linear weight leaves a crease at
-- every lattice line, and a crease reads as a grid rather than as sand; this
-- curve has zero slope at both ends, so neighbouring squares meet smoothly.
local function fade(t)
  return t * t * (3 - 2 * t)
end
-- }}}

-- {{{ local function smooth()
-- One layer's value at a point given in lattice units: the four lattice values
-- around it, blended. Lattice coordinates are floored, so negative coordinates
-- (the ridge layer is rotated and can go negative) fall into the right square.
local function smooth(seed, layer, u, v)
  local x0 = math.floor(u)
  local y0 = math.floor(v)
  local tx = fade(u - x0)
  local ty = fade(v - y0)
  local a = lattice(seed, layer, x0, y0)
  local b = lattice(seed, layer, x0 + 1, y0)
  local c = lattice(seed, layer, x0, y0 + 1)
  local d = lattice(seed, layer, x0 + 1, y0 + 1)
  local top = a + (b - a) * tx
  local bottom = c + (d - c) * tx
  return top + (bottom - top) * ty
end
-- }}}

-- {{{ local function ground()
-- One cell's height: the swell, the ridges across it, and the roughness on top.
-- The ridge layer's lattice is turned by the ridge angle and stretched along the
-- crest, so its bumps line up into long ridges; folding it about its middle makes
-- a sharp crest and a rounded trough, which is the profile of a dune.
local function ground(parameters, seed, x, y)
  local shape = M.SHAPE
  local wavelength = parameters.dune_wavelength
  local height = parameters.dune_height

  local swell_scale = wavelength * shape.swell_wavelength
  local swell = smooth(seed, SWELL, x / swell_scale, y / swell_scale)

  local across = x * shape.ridge_angle_cos + y * shape.ridge_angle_sin
  local along = -x * shape.ridge_angle_sin + y * shape.ridge_angle_cos
  local ridge = smooth(seed, RIDGES, across / wavelength, along / (wavelength * shape.ridge_stretch))
  ridge = 1 - math.abs(2 * ridge - 1)

  local rough = smooth(seed, ROUGH, x / shape.rough_wavelength, y / shape.rough_wavelength)

  -- The causeway: ground lifted along the diagonal that joins the two start
  -- corners and lowered toward the other two. It is a pure function of the
  -- cell's place, like everything else here, and it is why a raised field is
  -- nearly always playable -- without it a third of seeds drowned a start corner
  -- or cut the two apart, and the validator refused them.
  local causeway = 0.5 - math.abs(x - y) / parameters.size

  -- The swell multiplies the rest, so its lows are broad and flat -- the places
  -- the water sits -- and the ridges stand tallest where the swell is high.
  return height * (swell * (shape.swell_share * swell + shape.ridge_share * ridge)
                   + shape.causeway_share * causeway)
         + parameters.roughness * height * shape.rough_share * rough
end
-- }}}

-- {{{ local function check_parameters()
-- Every parameter present and a number, the size a whole number of at least two.
local function check_parameters(parameters, seed)
  if type(parameters) ~= "table" then
    error("the dunes: parameters are a " .. type(parameters) .. ", not a table", 2)
  end
  for _, name in ipairs(M.PARAMETERS) do
    if type(parameters[name]) ~= "number" then
      error("the dunes: parameter '" .. name .. "' is " .. tostring(parameters[name])
            .. ", not a number", 3)
    end
  end
  if parameters.size < 2 or parameters.size ~= math.floor(parameters.size) then
    error("the dunes: size " .. parameters.size .. " is not a whole number of at least two", 3)
  end
  if parameters.dune_wavelength <= 0 then
    error("the dunes: dune_wavelength " .. parameters.dune_wavelength .. " is not above zero", 3)
  end
  if type(seed) ~= "number" or seed ~= math.floor(seed) then
    error("the dunes: seed " .. tostring(seed) .. " is not a whole number", 3)
  end
end
-- }}}

-- {{{ local function start_region()
-- The cells of a team's start region: a square in team one's corner, and its
-- mirror through the field's centre for team two. Returns the bounds inclusive.
local function start_region(size, team)
  local side = math.max(1, math.floor(size * M.SHAPE.start_share))
  if team == 1 then
    return 0, 0, side - 1, side - 1
  end
  return size - side, size - side, size - 1, size - 1
end
-- }}}

-- {{{ local function place_start()
-- The highest land cell in a team's start region; on a tie, the first in row
-- order, so the answer never depends on anything but the heights. Zero and zero
-- when the region holds no land -- the validator refuses that by name.
local function place_start(field, team)
  local x0, y0, x1, y1 = start_region(field.size, team)
  local best_x, best_y, best = 0, 0, field.water_line
  local found = false
  for y = y0, y1 do
    for x = x0, x1 do
      local h = field.height[M.index(field, x, y)]
      -- Land, and strictly higher than anything seen: a tie keeps the earlier.
      if h >= field.water_line and (not found or h > best) then
        best_x, best_y, best, found = x, y, h, true
      end
    end
  end
  return best_x, best_y
end
-- }}}

-- {{{ function M.coarse()
-- The tallest cell in each coarse region, row-major over the regions. The
-- sightline's cheap first pass reads this; it is filled once, here.
function M.coarse(field, region)
  local regions = math.ceil(field.size / region)
  local tallest = {}
  for ry = 0, regions - 1 do
    for rx = 0, regions - 1 do
      local top = -math.huge
      for y = ry * region, math.min(field.size, (ry + 1) * region) - 1 do
        for x = rx * region, math.min(field.size, (rx + 1) * region) - 1 do
          local h = field.height[M.index(field, x, y)]
          if h > top then top = h end
        end
      end
      tallest[ry * regions + rx + 1] = top
    end
  end
  return regions, tallest
end
-- }}}

-- {{{ function M.raise()
-- The whole field from a seed and its shape parameters, validated. Two machines
-- given the same two things get the same field to the last bit.
function M.raise(parameters, seed)
  check_parameters(parameters, seed)
  local seed32 = bit.tobit(seed % 4294967296)
  local size = parameters.size
  local field = {size = size, height = {}, hydrocarbon = {}, water_line = parameters.water_line,
                 region = M.SHAPE.region, start_x = {0, 0}, start_y = {0, 0}}
  for y = 0, size - 1 do
    for x = 0, size - 1 do
      local index = M.index(field, x, y)
      local h = ground(parameters, seed32, x, y)
      field.height[index] = h
      -- Hydrocarbon is a fourth layer, unsmoothed, so pockets are single cells
      -- scattered at the given rate; water holds none.
      if h >= field.water_line and lattice(seed32, HYDROCARBON, x, y) < parameters.hydrocarbon_rate then
        field.hydrocarbon[index] = 1
      else
        field.hydrocarbon[index] = 0
      end
    end
  end
  for team = 1, 2 do
    field.start_x[team], field.start_y[team] = place_start(field, team)
  end
  field.regions, field.tallest = M.coarse(field, field.region)
  M.validate(field)
  return field
end
-- }}}

-- {{{ local function joined()
-- Whether two land cells are joined by a path over land, by a flood fill that
-- steps to the four neighbours. Only land is entered; water stops the fill.
local function joined(field, ax, ay, bx, by)
  local size = field.size
  local seen = {}
  local queue = {M.index(field, ax, ay)}
  local goal = M.index(field, bx, by)
  seen[queue[1]] = true
  local head = 1
  while head <= #queue do
    local here = queue[head]
    head = head + 1
    if here == goal then
      return true
    end
    local x = (here - 1) % size
    local y = (here - 1 - x) / size
    local steps = {{x - 1, y}, {x + 1, y}, {x, y - 1}, {x, y + 1}}
    for _, step in ipairs(steps) do
      local sx, sy = step[1], step[2]
      if sx >= 0 and sx < size and sy >= 0 and sy < size then
        local next_index = M.index(field, sx, sy)
        if not seen[next_index] and field.height[next_index] >= field.water_line then
          seen[next_index] = true
          queue[#queue + 1] = next_index
        end
      end
    end
  end
  return false
end
-- }}}

-- {{{ function M.validate()
-- Refuses a field that cannot be played on, naming what and where. Returns
-- nothing; a refusal is an error.
function M.validate(field)
  local size = field.size
  if type(size) ~= "number" or size < 2 then
    error("the field's size is " .. tostring(size) .. ", not a whole number of at least two", 2)
  end
  if type(field.water_line) ~= "number" then
    error("the field's water_line is " .. tostring(field.water_line) .. ", not a number", 2)
  end
  -- Every cell first, so a broken cell is named before anything reads it.
  local land = 0
  for index = 1, size * size do
    local h = field.height[index]
    if type(h) ~= "number" or h ~= h then
      local x = (index - 1) % size
      error(string.format("the field's height at cell %d (x %d, y %d) is %s, not a number",
                          index, x, (index - 1 - x) / size, tostring(h)), 2)
    end
    local pocket = field.hydrocarbon and field.hydrocarbon[index]
    if pocket ~= 0 and pocket ~= 1 then
      error(string.format("the field's hydrocarbon at cell %d is %s, not zero or one",
                          index, tostring(pocket)), 2)
    end
    if h >= field.water_line then
      land = land + 1
    end
  end
  if land == 0 then
    error("water covers the whole field: every cell is below the water line "
          .. field.water_line, 2)
  end
  for team = 1, 2 do
    local x, y = field.start_x[team], field.start_y[team]
    local x0, y0, x1, y1 = start_region(size, team)
    if type(x) ~= "number" or type(y) ~= "number" or x < x0 or x > x1 or y < y0 or y > y1 then
      error(string.format("team %d's start cell (%s, %s) is outside its start region (%d..%d, %d..%d)",
                          team, tostring(x), tostring(y), x0, x1, y0, y1), 2)
    end
    if field.height[M.index(field, x, y)] < field.water_line then
      error(string.format("team %d's start region (%d..%d, %d..%d) holds no land",
                          team, x0, x1, y0, y1), 2)
    end
  end
  if not joined(field, field.start_x[1], field.start_y[1], field.start_x[2], field.start_y[2]) then
    error(string.format("the start cells (%d, %d) and (%d, %d) are not joined by land",
                        field.start_x[1], field.start_y[1], field.start_x[2], field.start_y[2]), 2)
  end
  local regions = math.ceil(size / field.region)
  for index = 1, regions * regions do
    if type(field.tallest[index]) ~= "number" then
      error("the field's tallest at region " .. index .. " is " .. tostring(field.tallest[index])
            .. ", not a number", 2)
    end
  end
end
-- }}}

-- {{{ function M.dump()
-- The field as text: one character per cell graded by height above the water
-- line, `~` for water, and each team's start cell as its number. One line per
-- row, top row first. This is a look at the ground before anything can draw it.
function M.dump(field)
  local top = field.water_line
  for index = 1, field.size * field.size do
    if field.height[index] > top then top = field.height[index] end
  end
  local span = top - field.water_line
  local lines = {}
  for y = 0, field.size - 1 do
    local row = {}
    for x = 0, field.size - 1 do
      local h = field.height[M.index(field, x, y)]
      if h < field.water_line then
        row[#row + 1] = WATER
      else
        -- Land: which ninth of the span above the water it falls in.
        local grade = span > 0 and math.floor((h - field.water_line) / span * #GRADES) + 1 or 1
        if grade > #GRADES then grade = #GRADES end
        row[#row + 1] = GRADES[grade]
      end
    end
    for team = 1, 2 do
      if field.start_y[team] == y then
        row[field.start_x[team] + 1] = tostring(team)
      end
    end
    lines[#lines + 1] = table.concat(row)
  end
  return table.concat(lines, "\n") .. "\n"
end
-- }}}

return M
