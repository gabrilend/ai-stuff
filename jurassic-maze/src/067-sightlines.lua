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

-- 067-sightlines.lua
--
-- What the camera can and cannot see, as a raycast and as a count.
--
-- A maze nobody can see into is not a maze, it is a roof. Before this file the
-- project had no way of saying how much of its own floor was hidden, so nobody
-- knew that three quarters of it was, and the answer had to come from squinting
-- at screenshots. It is a measurement first; anything that repairs the geometry
-- steers by these numbers.
--
-- Pure arithmetic on the height field. No engine, no window -- the headless
-- runner and the validator both load it.

local M = {}

-- {{{ function M.climb(Iso)
-- How many layers the line of sight rises for each cell it travels diagonally.
--
-- Where this comes from: the camera sits at infinity, so a direction is "toward
-- the camera" exactly when moving along it does not move anything on screen.
-- The projection puts a world point at
--
--     screen x = (x - y) * HALF_WIDTH
--     screen y = (x + y) * HALF_HEIGHT - z * LAYER_PIXELS
--
-- Screen x is unchanged when dx equals dy, which pins the direction to the
-- diagonal. Screen y is then unchanged when 2 * dx * HALF_HEIGHT equals
-- dz * LAYER_PIXELS. So the view direction is (+1, +1, +2 * HALF_HEIGHT /
-- LAYER_PIXELS), and this function is that last term.
--
-- It is the number the whole file turns on. At the shipped constants it is 1.6,
-- and a wall standing two layers above its corridor is therefore taller than one
-- diagonal step of sight -- which is why the corridor behind every wall in the
-- maze is invisible. Anything that hopes to fix that has to move one of the
-- three constants this is made of.
function M.climb(Iso)
  return 2 * Iso.HALF_HEIGHT / Iso.LAYER_PIXELS
end
-- }}}

-- {{{ function M.blocked(store, climb, px, py, pz)
-- March from a point on a top face toward the camera. Returns the first cell
-- that gets in the way -- its x, its y, and its height -- or nil for a clear
-- line.
--
-- Two properties of the world make this cheap enough to run over every cell.
--
-- Every column is a plain pile, so "is the ray inside stone here" is one
-- comparison against that cell's height rather than a walk down a bitmask. The
-- validator's first hard check is what guarantees that, and this file would
-- quietly give wrong answers the day a golem punches a tunnel -- which is why
-- the height-shaped check takes a flag rather than being deleted.
--
-- The ray only ever climbs, so the lowest it gets while crossing a cell is where
-- it entered. Testing the entry point alone is exact, not an approximation, and
-- it means one comparison per cell crossed instead of a sampled march.
function M.blocked(store, climb, px, py, pz)
  local Stone_index_row = store.width
  local t = 0

  while true do
    -- Step to whichever axis crosses a cell boundary first. The nudge past the
    -- boundary is what stops the march sitting on the seam and reading the cell
    -- it just left forever.
    local to_x = math.floor(px + t) + 1 - (px + t)
    local to_y = math.floor(py + t) + 1 - (py + t)
    t = t + ((to_x < to_y) and to_x or to_y) + 1e-6

    local cx = math.floor(px + t)
    local cy = math.floor(py + t)
    -- Off the near edge of the world: nothing further can be in the way, because
    -- the rim is the last thing there is.
    if cx >= store.width or cy >= store.depth then return nil end

    local z = pz + climb * t
    -- Above everything the world can hold. No column reaches this, so no column
    -- can interrupt, and marching the remaining distance would find nothing.
    if z >= store.layers then return nil end

    local h = store.height[cx + cy * Stone_index_row]
    if z < h then return cx, cy, h end
  end
end
-- }}}

-- Where inside a top face to test, as fractions of a cell.
--
-- Sixteen points rather than the four corners. A corner sits exactly on the seam
-- between four cells, so a corner ray is a coin toss decided by rounding -- it
-- reports whichever neighbour the nudge happened to land in. Points in the
-- interior belong to one cell and cannot be argued with.
local SAMPLES = {}
for a = 1, 4 do
  for b = 1, 4 do
    SAMPLES[#SAMPLES + 1] = { (a - 0.5) / 4, (b - 0.5) / 4 }
  end
end

-- {{{ function M.survey(store, climb)
-- How much of the maze reaches the camera. Fills and returns a table.
--
-- Two numbers per surface, because they answer different questions and the gap
-- between them is itself informative. **Centre visible** is whether the middle
-- of the face gets through, which is roughly whether a body standing there would
-- be seen. **Any part visible** is whether a person can tell the cell is there
-- at all. A corridor whose near half is behind its own wall but whose far half
-- shows is legible; one where neither shows is a roof.
function M.survey(store, climb)
  local out = {
    floor_cells = 0, floor_centre = 0, floor_any = 0,
    column_tops = 0, top_centre = 0,
    hidden_by = {},
  }

  for y = 0, store.depth - 1 do
    for x = 0, store.width - 1 do
      local i = x + y * store.width
      local h = store.height[i]
      if h > 0 then
        out.column_tops = out.column_tops + 1
        local bx = M.blocked(store, climb, x + 0.5, y + 0.5, h)
        if not bx then out.top_centre = out.top_centre + 1 end

        if store.walkable[i] then
          out.floor_cells = out.floor_cells + 1
          if not bx then out.floor_centre = out.floor_centre + 1 end

          local any = false
          local tall_x, tall_y, tall_h
          for _, s in ipairs(SAMPLES) do
            local sx, sy, sh = M.blocked(store, climb, x + s[1], y + s[2], h)
            if not sx then any = true break end
            if not tall_h or sh > tall_h then tall_x, tall_y, tall_h = sx, sy, sh end
          end

          if any then
            out.floor_any = out.floor_any + 1
          else
            -- Nothing of this cell reaches the camera. Blame the tallest of the
            -- things standing in front of it, since that is the one that would
            -- have to move.
            local key = string.format("%+d,%+d  %+d layers",
                                      tall_x - x, tall_y - y, tall_h - h)
            out.hidden_by[key] = (out.hidden_by[key] or 0) + 1
          end
        end
      end
    end
  end

  return out
end
-- }}}

-- {{{ function M.wall_fits_behind_a_step(Iso, wall_rise)
-- Whether an ordinary maze wall is short enough to see past.
--
-- One diagonal step toward the camera moves a cell 2 * HALF_HEIGHT pixels down
-- the screen. A wall is drawn wall_rise * LAYER_PIXELS pixels tall. When the
-- wall is the taller of the two, its top face is drawn above the floor one step
-- behind it and that floor is gone -- and because the room lattice puts a wall
-- post diagonally in front of every single room, that is every room in the maze
-- rather than an unlucky few.
--
-- The generator cannot rescue this and must not try. A wall short enough to see
-- past is a wall a body can climb, and a maze whose walls can be climbed is a
-- plaza. The fix is a projection constant, which is why this returns a verdict
-- rather than repairing anything.
function M.wall_fits_behind_a_step(Iso, wall_rise)
  return wall_rise * Iso.LAYER_PIXELS < 2 * Iso.HALF_HEIGHT
end
-- }}}

return M
