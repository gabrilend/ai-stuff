-- jurassic-maze — a simulation living inside an isometric maze of stacked stone
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

-- 069-the-map.lua
--
-- Reads a hand-authored map of plates and stairs, and flattens it to a height
-- field.
--
-- A map here is data a person typed, not something a generator produced, and
-- that changes what this file is for. A generator's output can be trusted to be
-- self-consistent because the same code made all of it; a hand-authored file has
-- typos in it, and a typo that loads quietly is a map nobody can debug. So
-- almost everything below is a refusal.
--
-- The two shapes are in issue 801. A plate is a flat rectangle at an elevation;
-- a staircase is a run of treads carrying one elevation down to another. That is
-- the whole language, because that is what the reference picture is made of --
-- flat tops and the stairs between them, and not one wall anywhere in it.

local M = {}

-- Which way a staircase descends, as a step in cells. Written as a table rather
-- than as four branches because the direction is data in the map file, and the
-- map file should not be able to name a direction the code has to test for.
local DIRECTIONS = {
  ["+x"] = {  1,  0 },
  ["-x"] = { -1,  0 },
  ["+y"] = {  0,  1 },
  ["-y"] = {  0, -1 },
}

-- {{{ local function refuse(name, fmt, ...)
-- Every complaint carries the map's name and says what was wrong with which
-- entry, because the reader is being used by somebody editing a text file and
-- "invalid map" would send them looking through all of it.
local function refuse(name, fmt, ...)
  error(string.format("map '%s': " .. fmt, name, ...), 0)
end
-- }}}

-- {{{ local function check_plate(name, n, p, width, depth)
local function check_plate(name, n, p, width, depth)
  if type(p.x) ~= "number" or type(p.y) ~= "number" then
    refuse(name, "plate %d has no position", n)
  end
  if type(p.z) ~= "number" then
    refuse(name, "plate %d at (%d, %d) has no elevation", n, p.x, p.y)
  end
  local w = p.w or 1
  local d = p.d or 1
  if w < 1 or d < 1 then
    refuse(name, "plate %d at (%d, %d) is %d by %d, which covers nothing",
           n, p.x, p.y, w, d)
  end
  -- Off the edge is refused rather than clipped. A plate that hangs over the rim
  -- is a number typed wrong, and silently trimming it hides the mistake while
  -- changing the shape of the map.
  if p.x < 0 or p.y < 0 or p.x + w > width or p.y + d > depth then
    refuse(name, "plate %d covers (%d, %d) to (%d, %d), outside a %d by %d map",
           n, p.x, p.y, p.x + w - 1, p.y + d - 1, width, depth)
  end
  if p.z < 0 then
    refuse(name, "plate %d at (%d, %d) has elevation %d, below the ground",
           n, p.x, p.y, p.z)
  end
  return w, d
end
-- }}}

-- {{{ local function check_stair(name, n, s, width, depth)
local function check_stair(name, n, s, width, depth)
  local step = DIRECTIONS[s.dir or ""]
  if not step then
    refuse(name, "stair %d heads '%s', which is not +x, -x, +y or -y",
           n, tostring(s.dir))
  end
  if type(s.from) ~= "number" or type(s.to) ~= "number" then
    refuse(name, "stair %d does not say what it joins", n)
  end
  -- A flight always descends. One that climbs is the two ends typed the wrong
  -- way round, and accepting it would build a staircase running backwards out of
  -- the shelf it was meant to leave.
  if s.from <= s.to then
    refuse(name, "stair %d runs from %d up to %d; a flight descends",
           n, s.from, s.to)
  end

  local treads = s.from - s.to
  local w = s.w or 1
  if w < 1 then refuse(name, "stair %d is %d wide", n, w) end

  -- Both ends have to be on the map. Checking only the head lets a long flight
  -- walk off the edge, which shows up much later as a hole in the skirt.
  local ex = s.x + step[1] * (treads - 1) + ((step[1] == 0) and (w - 1) or 0)
  local ey = s.y + step[2] * (treads - 1) + ((step[2] == 0) and (w - 1) or 0)
  if s.x < 0 or s.y < 0 or s.x >= width or s.y >= depth
     or ex < 0 or ey < 0 or ex >= width or ey >= depth then
    refuse(name, "stair %d runs from (%d, %d) to (%d, %d), off a %d by %d map",
           n, s.x, s.y, ex, ey, width, depth)
  end

  return step, treads, w
end
-- }}}

-- {{{ function M.load(map)
-- A map table in, a height field and a report out.
--
-- The flattening rule is the one thing here worth remembering: **where two
-- plates overlap, the higher wins, and the order they were written in does not
-- matter.** That is what makes the format authorable by hand. A plaza with a
-- block standing in the middle of it is two rectangles -- the plaza, then the
-- block -- rather than the plaza split into four pieces around a hole. Order
-- independence matters because a person adding a plate should not have to work
-- out where in the list it belongs.
function M.load(map)
  local name   = map.name or "unnamed"
  local width  = map.width
  local depth  = map.depth
  if type(width) ~= "number" or type(depth) ~= "number" then
    refuse(name, "does not say how big it is")
  end

  -- Every cell starts at the floor of the world rather than at "nothing". A map
  -- is a solid mountain with a surface, so there is no such thing as a cell with
  -- no ground -- the question is only how high its ground is.
  local base = map.base or 0
  local height, covered = {}, {}
  for i = 0, width * depth - 1 do
    height[i]  = base
    covered[i] = false
  end

  local plates = map.plates or {}
  local extent = {}

  for n, p in ipairs(plates) do
    local w, d = check_plate(name, n, p, width, depth)
    extent[n] = { w = w, d = d }
    for y = p.y, p.y + d - 1 do
      for x = p.x, p.x + w - 1 do
        local i = x + y * width
        -- The first plate to reach a cell sets it whatever its elevation;
        -- afterwards only a higher one replaces it. That is "the higher wins",
        -- and it leaves the result independent of the order the plates were
        -- written in, which is the property that makes the format editable --
        -- a person adding a plate must not have to work out where in the list
        -- it belongs.
        if not covered[i] or p.z > height[i] then height[i] = p.z end
        covered[i] = true
      end
    end
  end

  local stairs = map.stairs or {}
  for n, s in ipairs(stairs) do
    local step, treads, w = check_stair(name, n, s, width, depth)
    -- Across the flight, at right angles to the way it descends. A flight two
    -- wide going down +y occupies two columns of x.
    local across_x = (step[1] == 0) and 1 or 0
    local across_y = (step[2] == 0) and 1 or 0

    for tread = 0, treads - 1 do
      local z = s.from - tread
      for k = 0, w - 1 do
        local x = s.x + step[1] * tread + across_x * k
        local y = s.y + step[2] * tread + across_y * k
        local i = x + y * width
        -- A tread overwrites whatever was there, high or low, rather than taking
        -- the higher of the two. A staircase is a cut through a rim, and a rim is
        -- by definition taller than the flight passing through it -- so "highest
        -- wins" here would fill the cut back in and leave a shelf with a
        -- staircase drawn on it that goes nowhere.
        height[i] = z
        covered[i] = true
      end
    end
  end

  local uncovered, lowest, highest = 0, math.huge, -math.huge
  for i = 0, width * depth - 1 do
    if not covered[i] then uncovered = uncovered + 1 end
    if height[i] < lowest  then lowest  = height[i] end
    if height[i] > highest then highest = height[i] end
  end

  -- How much of the finished surface each plate actually shows, counted against
  -- the field rather than while building it.
  --
  -- Counting during the build would be order-dependent: a plate written first
  -- wins every cell it touches and then loses them again to whatever was written
  -- after it, so it would report a healthy number while being completely buried.
  -- Counting afterwards asks the only question worth asking -- is any of this
  -- plate visible in the finished mountain -- and a zero is nearly always a typo
  -- that no picture would reveal, because the thing burying it looks correct.
  local claimed = {}
  for n, p in ipairs(plates) do
    local e = extent[n]
    local won = 0
    for y = p.y, p.y + e.d - 1 do
      for x = p.x, p.x + e.w - 1 do
        if height[x + y * width] == p.z then won = won + 1 end
      end
    end
    claimed[n] = won
  end

  return {
    name      = name,
    width     = width,
    depth     = depth,
    height    = height,
    lowest    = lowest,
    highest   = highest,
    uncovered = uncovered,
    claimed   = claimed,
    plates    = plates,
    stairs    = stairs,
  }
end
-- }}}

-- {{{ function M.describe(field)
-- What was loaded, as lines of text.
--
-- The two numbers worth watching are the uncovered count and the per-plate
-- claim. A plate that won no cells at all was completely buried by something
-- higher, which is nearly always a typo rather than an intention, and it is
-- invisible in a picture because the thing that buried it looks fine.
function M.describe(field)
  local lines = {}
  local function add(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end

  add("map '%s'   %d by %d cells", field.name, field.width, field.depth)
  add("  elevation          %d to %d layers", field.lowest, field.highest)
  add("  plates             %d", #field.plates)
  add("  staircases         %d", #field.stairs)

  local treads = 0
  for _, s in ipairs(field.stairs) do treads = treads + (s.from - s.to) * (s.w or 1) end
  add("  stair treads       %d", treads)

  if field.uncovered > 0 then
    add("  cells no plate covered %d   (they sit at the base elevation)",
        field.uncovered)
  end

  local buried = {}
  for n, won in pairs(field.claimed) do
    if won == 0 then buried[#buried + 1] = n end
  end
  table.sort(buried)
  if #buried > 0 then
    add("  plates buried by something higher: %s", table.concat(buried, ", "))
  end

  return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.to_store(Stone, field, layers)
-- The height field as a stone store, so that everything already written against
-- one keeps working.
--
-- Scaffolding, and worth saying so plainly. The store is a grid of 32-bit
-- columns with a bit per layer, which exists to express tunnels and overhangs
-- that a hand-authored height field cannot have and does not want. The reason to
-- build one anyway is that the renderer, the sightline survey and the validator
-- all speak store, and a map nobody can look at is a map nobody can check.
--
-- Every cell is walkable. There is no such thing as a wall here -- the whole
-- point of the format is that every surface is the top of something -- so the
-- distinction the store draws between floor and wall has nothing to answer to,
-- and the honest answer is that all of it is floor.
function M.to_store(Stone, field, layers)
  layers = layers or (field.highest + 2)
  if layers > Stone.MAX_LAYERS then
    error(string.format(
      "map '%s' reaches %d layers and a column holds %d. The map format has no " ..
      "such ceiling; the store does.", field.name, field.highest, Stone.MAX_LAYERS), 0)
  end

  -- The off-by-one between a map and a store, stated once so nobody has to
  -- rediscover it. A map's elevation is the **plane of the top surface**: a shelf
  -- at 22 is ground you stand on at height 22. A store's height is the **index of
  -- the topmost solid layer**, and a layer L occupies the space from L to L + 1 --
  -- so the same shelf is layer 21 there. Everything downstream of the map works
  -- in planes, because a ball resting on a shelf at 22 has its centre at 22 plus
  -- its radius, and everything downstream of the store works in layers.
  local store = Stone.new(field.width, field.depth, layers)
  store.height   = {}
  store.walkable = {}
  for i = 0, store.cells - 1 do
    local top_layer = field.height[i] - 1
    Stone.fill_to(store, i, top_layer)
    store.height[i]   = top_layer
    store.walkable[i] = true
  end
  Stone.recompute_surfaces(store, 0, store.cells - 1)
  return store
end
-- }}}

M.DIRECTIONS = DIRECTIONS

return M
