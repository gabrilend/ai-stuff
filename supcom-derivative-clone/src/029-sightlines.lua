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

-- 029-sightlines.lua
--
-- Answers whether one point sees another over the dunes.
--
-- The most-asked question in the simulation, and the one the game is built on:
-- nothing is out of range, so the only thing between a gun and its target is the
-- ground. A sightline is the straight segment from the viewer's eye to the top of
-- the target, and it is clear if no cell it crosses holds ground above it. There
-- is no maximum distance. Units never block it (open question C2's working
-- ruling): this file reads the field and its arguments and nothing else.
--
-- Positions are in cell units with each cell's centre at its integer
-- coordinates, the convention `the-dunes` sets in `cell_of`. The arithmetic is
-- the same doubles in the same order on every machine, so every machine gets the
-- same booleans.

local M = {}

-- The one piece of state, kept on purpose: how many questions have been asked,
-- because whether the coarse pass is enough is a measurement the headless runner
-- reports, not an argument.
local asked = 0

-- {{{ local function cell_of()
-- The cell a position stands in, held to the field. This is the dunes' rule,
-- restated because this file is handed bare fields -- the tests build one by hand
-- -- and must not reach for a module to read a position.
local function cell_of(size, p)
  local c = math.floor(p + 0.5)
  if c < 0 then return 0 end
  if c > size - 1 then return size - 1 end
  return c
end
-- }}}

-- {{{ local function traverse()
-- Every cell of a grid the segment from (x1, y1) to (x2, y2) passes through, in
-- order from the first end, handed to `visit(cx, cy)`; the walk stops early when
-- `visit` returns false, and `traverse` returns false then. `scale` is the cell
-- size, so the same walk serves the field (scale one) and its coarse regions.
--
-- Positions are cell centres, so the corner-based coordinates the walk steps in
-- are the position plus half a cell. Where the segment passes exactly through a
-- corner, the x neighbour is visited before the y one: both are touched, which
-- is the cautious answer -- a sightline that grazes two crests at their shared
-- corner is blocked by either.
local function traverse(x1, y1, x2, y2, scale, visit)
  local ax, ay = (x1 + 0.5) / scale, (y1 + 0.5) / scale
  local bx, by = (x2 + 0.5) / scale, (y2 + 0.5) / scale
  local cx, cy = math.floor(ax), math.floor(ay)
  local ex, ey = math.floor(bx), math.floor(by)
  local dx, dy = bx - ax, by - ay
  local step_x = dx > 0 and 1 or -1
  local step_y = dy > 0 and 1 or -1
  -- How far along the segment, as a fraction, the next x and y lines are, and
  -- how far one whole cell is. A segment that never moves on an axis never
  -- crosses one of its lines.
  local next_x, each_x = math.huge, math.huge
  if dx ~= 0 then
    local line = step_x > 0 and (cx + 1) or cx
    next_x = (line - ax) / dx
    each_x = step_x / dx
  end
  local next_y, each_y = math.huge, math.huge
  if dy ~= 0 then
    local line = step_y > 0 and (cy + 1) or cy
    next_y = (line - ay) / dy
    each_y = step_y / dy
  end
  if visit(cx, cy) == false then return false end
  while cx ~= ex or cy ~= ey do
    -- Cross whichever line comes first; on a tie, x first, as above.
    if next_x <= next_y then
      cx = cx + step_x
      next_x = next_x + each_x
    else
      cy = cy + step_y
      next_y = next_y + each_y
    end
    if visit(cx, cy) == false then return false end
  end
  return true
end
-- }}}

-- {{{ function M.can_see()
-- Whether a viewer at (x1, y1) with its eye `eye` above the ground sees a target
-- at (x2, y2) whose top is `profile` above the ground. The two end cells are
-- never tested -- a unit always sees out of its own cell and is always seen on
-- its own -- so only the cells strictly between are asked.
--
-- To make the answer the same whichever way round it is asked when eye and
-- profile are equal, the walk always runs from the end that comes first in row
-- order; swapping the ends swaps their heights with them.
function M.can_see(field, x1, y1, eye, x2, y2, profile)
  asked = asked + 1
  local size = field.size
  local height = field.height
  local ax, ay = cell_of(size, x1), cell_of(size, y1)
  local bx, by = cell_of(size, x2), cell_of(size, y2)
  if ax == bx and ay == by then
    return true
  end
  local top1 = height[ay * size + ax + 1] + eye
  local top2 = height[by * size + bx + 1] + profile
  if by < ay or (by == ay and bx < ax) then
    x1, y1, x2, y2 = x2, y2, x1, y1
    ax, ay, bx, by = bx, by, ax, ay
    top1, top2 = top2, top1
  end

  -- The coarse pass. If the segment's lowest point is above the tallest cell of
  -- every region it crosses, nothing between can block it. A field built by hand
  -- -- the tests' ridge -- has no coarse grid and goes straight to the walk; the
  -- coarse pass is a short cut to the walk's own answer, never a different one.
  local tallest = field.tallest
  if tallest ~= nil then
    local lowest = math.min(top1, top2)
    local regions = field.regions
    local clear = traverse(ax, ay, bx, by, field.region, function(rx, ry)
      return tallest[ry * regions + rx + 1] < lowest
    end)
    if clear then
      return true
    end
  end

  -- The walk. Each crossed cell's centre is projected onto the segment, and the
  -- segment's height there is interpolated between the two tops.
  local dx, dy = bx - ax, by - ay
  local length2 = dx * dx + dy * dy
  local rise = top2 - top1
  return traverse(ax, ay, bx, by, 1, function(cx, cy)
    if (cx == ax and cy == ay) or (cx == bx and cy == by) then
      return true
    end
    local t = ((cx - ax) * dx + (cy - ay) * dy) / length2
    return height[cy * size + cx + 1] <= top1 + rise * t
  end)
end
-- }}}

-- {{{ function M.questions_asked()
-- How many sightline questions have been asked since the last reset.
function M.questions_asked()
  return asked
end
-- }}}

-- {{{ function M.reset_questions()
-- Clears the count, so a runner can measure one match or one tick.
function M.reset_questions()
  asked = 0
end
-- }}}

return M
