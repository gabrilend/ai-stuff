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

-- 071-the-model.lua
--
-- Turns a height field into flat quadrilaterals in three dimensions.
--
-- Nothing in the project had ever built geometry. The renderer drew a diamond
-- and two parallelograms straight from the height field, and the ball sampled an
-- interpolated height field rather than touching anything solid -- both of them
-- working by knowing the world is a grid, and neither able to answer "what is the
-- surface here" without that assumption.
--
-- That was affordable while the world was a grid of columns. It stops being
-- affordable the moment a ball has to bounce down a staircase, because a
-- staircase is a sequence of small flat faces and small vertical ones, and the
-- interpolated-height-field trick exists precisely to smooth those away.
--
-- Every face here is an axis-aligned rectangle, so a face is fully described by
-- two corners with exactly one axis degenerate. That is not a simplification of
-- a general mesh; it is exact for this world, it halves the face count against
-- triangles, and it makes a sphere-against-face test three clamps and a
-- subtraction instead of a barycentric solve.

local M = {}

-- What a face is. Kept as numbers rather than strings so the physics can switch
-- on them without hashing, and so a face array stays all numbers.
M.TOP   = 0
M.RISER = 1

-- The four horizontal neighbours, and the normal a riser facing that way carries.
-- A table rather than four branches: the merge loop below runs once per
-- direction rather than four times with the axis names swapped.
local SIDES = {
  { dx =  1, dy =  0, nx =  1, ny = 0 },
  { dx = -1, dy =  0, nx = -1, ny = 0 },
  { dx =  0, dy =  1, nx =  0, ny = 1 },
  { dx =  0, dy = -1, nx =  0, ny = -1 },
}

-- {{{ local function new_model(width, depth)
local function new_model(width, depth)
  return {
    width = width, depth = depth,
    count = 0,
    -- Flat parallel arrays, one entry per face. Not an array of tables: a
    -- fifty-thousand-face model is fifty thousand allocations that way, and the
    -- physics walks these in its innermost loop.
    kind = {}, x0 = {}, y0 = {}, z0 = {}, x1 = {}, y1 = {}, z1 = {},
    nx = {}, ny = {}, nz = {},
    -- cell index -> the faces standing on or beside it, so that "what is near
    -- this ball" is a lookup rather than a scan over the whole model.
    at = {},
  }
end
-- }}}

-- {{{ local function add(m, kind, x0, y0, z0, x1, y1, z1, nx, ny, nz)
local function add(m, kind, x0, y0, z0, x1, y1, z1, nx, ny, nz)
  local i = m.count
  m.kind[i] = kind
  m.x0[i], m.y0[i], m.z0[i] = x0, y0, z0
  m.x1[i], m.y1[i], m.z1[i] = x1, y1, z1
  m.nx[i], m.ny[i], m.nz[i] = nx, ny, nz
  m.count = i + 1
  return i
end
-- }}}

-- {{{ local function index_face(m, id, cx0, cy0, cx1, cy1)
-- Files a face under every cell it touches. A face merged across twenty cells is
-- listed under all twenty, because a ball standing on any of them has to know
-- about it.
local function index_face(m, id, cx0, cy0, cx1, cy1)
  for y = cy0, cy1 do
    for x = cx0, cx1 do
      local c = x + y * m.width
      local list = m.at[c]
      if not list then list = {}; m.at[c] = list end
      list[#list + 1] = id
    end
  end
end
-- }}}

-- {{{ local function build_tops(m, height, width, depth)
-- One horizontal face per flat area, greedily merged.
--
-- The merge matters more than it looks. A shelf twelve cells across is one face
-- rather than a hundred and forty-four, and both the physics and any renderer
-- are linear in faces -- but more importantly a ball rolling across an unmerged
-- shelf crosses a face boundary every cell, and every boundary is an opportunity
-- for a floating-point comparison to put it briefly between two faces and
-- therefore on neither. Fewer seams is fewer chances to fall through the floor.
--
-- Greedy in the usual way: take the longest run of equal height along x, then
-- push that run down in y for as long as every cell of it still agrees.
local function build_tops(m, height, width, depth)
  local used = {}
  for y = 0, depth - 1 do
    local x = 0
    while x < width do
      local i = x + y * width
      if used[i] then
        x = x + 1
      else
        local h = height[i]

        local run = 1
        while x + run < width
          and not used[i + run]
          and height[i + run] == h do run = run + 1 end

        local span = 1
        while y + span < depth do
          local row = i + span * width
          local ok = true
          for k = 0, run - 1 do
            if used[row + k] or height[row + k] ~= h then ok = false break end
          end
          if not ok then break end
          span = span + 1
        end

        for b = 0, span - 1 do
          for a = 0, run - 1 do used[i + b * width + a] = true end
        end

        -- Cell (x, y) covers the square from (x, y) to (x + 1, y + 1) in world
        -- units, so a run of `run` cells reaches x + run.
        local id = add(m, M.TOP, x, y, h, x + run, y + span, h, 0, 0, 1)
        index_face(m, id, x, y, x + run - 1, y + span - 1)

        x = x + run
      end
    end
  end
end
-- }}}

-- {{{ local function build_risers(m, height, width, depth, floor_z)
-- One vertical face per exposed side of every step, cliff, rim and tread.
--
-- All four sides are emitted, not the two that face the camera. A renderer can
-- afford to know that two thirds of the geometry is turned away; the physics
-- cannot, because a ball arrives from whichever direction it likes.
--
-- Outside the map the ground is `floor_z`, and that is what closes the model
-- along the rim. Without it a ball leaving the world falls past an open edge
-- rather than off a solid object.
local function build_risers(m, height, width, depth, floor_z)
  local function at(x, y)
    if x < 0 or y < 0 or x >= width or y >= depth then return floor_z end
    return height[x + y * width]
  end

  for _, s in ipairs(SIDES) do
    -- A face's plane is perpendicular to its normal, so its length runs along
    -- the *other* horizontal axis. A face looking along y lies in a plane of
    -- constant y and stretches in x; one looking along x stretches in y. Getting
    -- these two the wrong way round builds a model that looks plausible in a
    -- face count and is wrong in every coordinate.
    local runs_in_x = (s.dy ~= 0)
    local lanes  = runs_in_x and depth or width   -- how many planes there are
    local length = runs_in_x and width or depth   -- how far a face can stretch

    for lane = 0, lanes - 1 do
      local n = 0
      while n < length do
        local x = runs_in_x and n or lane
        local y = runs_in_x and lane or n
        local here  = at(x, y)
        local there = at(x + s.dx, y + s.dy)

        if here <= there then
          n = n + 1
        else
          -- Extend while both sides hold. A run where either steps has to be
          -- broken: the face's top or bottom edge would move partway along it,
          -- and a rectangle cannot express that.
          local run = 1
          while n + run < length do
            local ax = runs_in_x and (n + run) or lane
            local ay = runs_in_x and lane or (n + run)
            if at(ax, ay) ~= here then break end
            if at(ax + s.dx, ay + s.dy) ~= there then break end
            run = run + 1
          end

          -- Which side of the cell the plane sits on: the far side when looking
          -- toward increasing x or y, the near side when looking back.
          if runs_in_x then
            local py = (s.dy > 0) and (y + 1) or y
            local id = add(m, M.RISER, x, py, there, x + run, py, here, 0, s.ny, 0)
            index_face(m, id, x, lane, x + run - 1, lane)
          else
            local px = (s.dx > 0) and (x + 1) or x
            local id = add(m, M.RISER, px, y, there, px, y + run, here, s.nx, 0, 0)
            index_face(m, id, lane, y, lane, y + run - 1)
          end

          n = n + run
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.build(field, floor_z)
-- A height field in, a model out.
--
-- `field` is anything with `width`, `depth` and a zero-based `height` array in
-- **planes** -- a cell of height 22 is ground you stand on at 22. That is the
-- map's convention rather than the stone store's, and the two differ by one; see
-- the note in 069-the-map.lua.
function M.build(field, floor_z)
  floor_z = floor_z or 0
  local m = new_model(field.width, field.depth)
  build_tops(m, field.height, field.width, field.depth)
  build_risers(m, field.height, field.width, field.depth, floor_z)
  return m
end
-- }}}

-- {{{ function M.describe(m)
function M.describe(m)
  local tops, risers, area = 0, 0, 0
  for i = 0, m.count - 1 do
    if m.kind[i] == M.TOP then
      tops = tops + 1
      area = area + (m.x1[i] - m.x0[i]) * (m.y1[i] - m.y0[i])
    else
      risers = risers + 1
    end
  end

  local lines = {}
  local function add_line(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end
  add_line("model   %d faces", m.count)
  add_line("  tops               %d covering %d cells", tops, area)
  add_line("  risers             %d", risers)
  add_line("  merge saved        %.1fx on tops", (m.width * m.depth) / math.max(1, tops))
  return table.concat(lines, "\n")
end
-- }}}

return M
