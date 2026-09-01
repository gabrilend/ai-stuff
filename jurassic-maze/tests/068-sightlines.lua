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

-- 068-sightlines.lua
--
-- The line of sight really is the direction the camera looks along.
--
-- Everything in 067-sightlines.lua rests on one derived number, and a derived
-- number is exactly the kind of thing that is right when it is written and wrong
-- after somebody adjusts a constant three files away. So the number is never
-- taken on trust here: it is checked against the renderer's own projection, by
-- asking whether two points a step apart along the supposed line of sight really
-- do land on the same pixel. If they ever stop doing so, the constant moved and
-- every visibility figure in the report became fiction.
--
-- The march itself is then checked against the obvious version with a loop in
-- it, in the same spirit as 049-stone-invariants.lua: the clever one steps from
-- one cell boundary to the next, the obvious one asks every cell in the world
-- whether the ray passes under it, and the obvious one is what the definition
-- says.

local M = {}

-- {{{ local function reference_blocked(Stone, store, climb, px, py, pz)
-- The line of sight, worked out by considering every cell in the world.
--
-- Straight from the definition and making no use of the fact that the ray
-- travels in a straight line through neighbouring cells. For each cell, the ray
-- is over it while both x and y are inside it, which is an interval in t; the
-- ray only climbs, so the lowest it gets over that cell is at the interval's
-- start; and the cell blocks when that low point is under the cell's height. The
-- blocker is whichever of those has the earliest entry.
--
-- Slow -- it looks at every cell for every ray -- and impossible to get wrong,
-- which is the entire point. An earlier version of this crept along the ray in
-- fortieths of a cell and disagreed with the real march on seven cells out of a
-- thousand, every one of them a ray that entered a cell a hundredth of a layer
-- below its top and climbed clear before the next sample. The creeping version
-- was the wrong one, and this is why a reference implementation has to be
-- exactly the definition rather than merely a slower guess at it.
local function reference_blocked(Stone, store, climb, px, py, pz)
  local best_t, best_x, best_y
  for cy = 0, store.depth - 1 do
    for cx = 0, store.width - 1 do
      local enter_x, enter_y = cx - px, cy - py
      local enter = (enter_x > enter_y) and enter_x or enter_y
      local leave_x, leave_y = cx + 1 - px, cy + 1 - py
      local leave = (leave_x < leave_y) and leave_x or leave_y
      if enter > 0 and enter < leave then
        local z = pz + climb * enter
        if z < store.layers and z < store.height[Stone.index(store, cx, cy)] then
          if not best_t or enter < best_t then
            best_t, best_x, best_y = enter, cx, cy
          end
        end
      end
    end
  end
  return best_x, best_y
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Params     = dofile(root .. "/src/028-maze-parameters.lua")
  local Stone      = dofile(root .. "/src/030-the-stone.lua")
  local Carving    = dofile(root .. "/src/031-carving.lua")
  local Streams    = dofile(root .. "/src/029-random-streams.lua")
  local Iso        = dofile(root .. "/src/040-the-projection.lua")
  local Sightlines = dofile(root .. "/src/067-sightlines.lua")

  local climb = Sightlines.climb(Iso)

  -- The line of sight is the direction that does not move on screen.
  --
  -- This is the check that keeps the rest of the file honest. Take a camera,
  -- take a point, step along the claimed view direction, and project both ends.
  -- A camera at infinity means the two must land on exactly the same pixel; if
  -- they do not, what 067 calls the line of sight is some other line and every
  -- number it reports is about a view nobody is looking from.
  local camera = { pan_x = 0, pan_y = 0, scale = 1 }
  for _, step in ipairs({ 1, 2, 7, 30 }) do
    local ax, ay = Iso.to_screen(camera, 3, 5, 4)
    local bx, by = Iso.to_screen(camera, 3 + step, 5 + step, 4 + climb * step)
    t.equal(ax, bx, "a step along the line of sight does not move the screen x")
    t.truthy(math.abs(ay - by) < 1e-9,
             "a step along the line of sight does not move the screen y")
  end

  -- And the direction is toward the camera rather than away from it. Nearer
  -- things are drawn lower down, so the far end of the ray must sit higher on
  -- screen than a point at the same place on the ground.
  local _, near_y = Iso.to_screen(camera, 10, 10, 0)
  local _, far_y  = Iso.to_screen(camera, 4, 4, 0)
  t.truthy(far_y < near_y, "increasing x and y is toward the camera, not away")

  -- The verdict about walls is the arithmetic and nothing else.
  t.equal(Sightlines.wall_fits_behind_a_step(Iso, 1),
          1 * Iso.LAYER_PIXELS < 2 * Iso.HALF_HEIGHT,
          "a one-layer wall's verdict is the pixel comparison")
  t.equal(Sightlines.wall_fits_behind_a_step(Iso, 2),
          2 * Iso.LAYER_PIXELS < 2 * Iso.HALF_HEIGHT,
          "a two-layer wall's verdict is the pixel comparison")

  -- A world with one tall block in it, so that the answers are known without
  -- generating anything. The block sits diagonally in front of the origin cell.
  do
    -- Stone.new allocates the columns; the height and walkable arrays are the
    -- generator's additions to the store, so a hand-built world has to lay them
    -- in itself. Sightlines reads only those two, which is what lets it be
    -- tested against a world nobody generated.
    local store = Stone.new(9, 9, 32)
    store.height, store.walkable = {}, {}
    for i = 0, store.cells - 1 do
      Stone.fill_to(store, i, 1)
      store.height[i] = 1
      store.walkable[i] = true
    end
    local blocker = Stone.index(store, 3, 3)
    store.height[blocker] = 1 + math.ceil(climb) + 1
    Stone.fill_to(store, blocker, store.height[blocker])

    -- Something that tall, one diagonal cell in front, is over the ray.
    local bx, by = Sightlines.blocked(store, climb, 2.5, 2.5, 1)
    t.equal(bx, 3, "the tall block is what stands in the way, x")
    t.equal(by, 3, "the tall block is what stands in the way, y")

    -- The cell diagonally *behind* it looks the other way and sees nothing.
    t.equal(Sightlines.blocked(store, climb, 4.5, 4.5, 1), nil,
            "a cell in front of the block has a clear line out")

    -- Lower the block to just under one step of sight and the line clears. This
    -- is the whole design in two assertions: the same geometry, one layer apart,
    -- decides whether a maze is visible.
    store.height[blocker] = 1
    t.equal(Sightlines.blocked(store, climb, 2.5, 2.5, 1), nil,
            "a block no taller than the ground does not block")
  end

  -- The march against the slow version, on real generated stone. Every floor
  -- cell of a small maze, sampled at its centre.
  do
    local p = Params.check(Params.with({ seed = 5, width = 41, depth = 41 }))
    local store = Carving.generate(root, p, Streams.make_set(5))

    local checked, disagreed = 0, 0
    for y = 0, store.depth - 1 do
      for x = 0, store.width - 1 do
        local i = Stone.index(store, x, y)
        if store.walkable[i] then
          local h = store.height[i]
          local fx, fy = Sightlines.blocked(store, climb, x + 0.5, y + 0.5, h)
          local rx, ry = reference_blocked(Stone, store, climb, x + 0.5, y + 0.5, h)
          checked = checked + 1
          if fx ~= rx or fy ~= ry then disagreed = disagreed + 1 end
        end
      end
    end
    t.truthy(checked > 500, "the small maze had enough floor to be worth checking")
    t.equal(disagreed, 0, "the boundary march and the creeping march agree everywhere")
  end

  -- The survey's own bookkeeping. Nothing here is about how much is visible --
  -- that number is the generator's problem and it moves -- only that the counts
  -- are counts of the right things and cannot exceed their own totals.
  do
    local p = Params.check(Params.with({ seed = 7, width = 41, depth = 41 }))
    local store = Carving.generate(root, p, Streams.make_set(7))
    local seen = Sightlines.survey(store, climb)

    t.truthy(seen.floor_cells > 0, "the survey found floor to look at")
    t.truthy(seen.floor_centre <= seen.floor_any,
             "a visible centre implies a visible face, so centre never exceeds any")
    t.truthy(seen.floor_any <= seen.floor_cells,
             "no more faces are visible than there are faces")
    t.truthy(seen.top_centre <= seen.column_tops,
             "no more column tops are visible than there are column tops")
    t.truthy(seen.column_tops >= seen.floor_cells,
             "every floor cell is also a column top")
  end
end
-- }}}

return M
