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

-- 050-maze-invariants.lua
--
-- What must be true of every generated maze.
--
-- The validator already checks these on every maze it builds. This runs it over
-- a spread of seeds and parameter sets, which is the part that catches the
-- failure that only happens one time in forty -- and every failure in this
-- generator so far has been one of those.

local M = {}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Params    = dofile(root .. "/src/028-maze-parameters.lua")
  local Streams   = dofile(root .. "/src/029-random-streams.lua")
  local Carve     = dofile(root .. "/src/031-carving.lua")
  local Validator = dofile(root .. "/src/032-the-validator.lua")
  local Stone     = dofile(root .. "/src/030-the-stone.lua")
  local Moving    = dofile(root .. "/src/033-moving.lua")

  -- A spread of shapes, not just the default. A generator that only works at one
  -- size is a generator with a constant hidden in it somewhere.
  local shapes = {
    {},
    { width = 65,  depth = 65 },
    { width = 65,  depth = 129 },
    { layers = 20, terrace_count = 5 },
    { terrace_rise = 2 },              -- no cliffs, so no staircases wanted
    { braid = 0.0 },                   -- a perfect maze, one route everywhere
    { braid = 0.5 },                   -- heavily looped
    { extra_stairs = 0.0 },            -- only the flights connectivity demanded
  }

  for si, overrides in ipairs(shapes) do
    for seed = 1, 5 do
      local o = {}
      for k, v in pairs(overrides) do o[k] = v end
      o.seed = seed * 97 + si

      local p = Params.check(Params.with(o))
      local store, report = Carve.generate(root, p, Streams.make_set(p.seed))
      Validator.validate(root, store, p, report)

      local label = "shape " .. si .. " seed " .. o.seed

      -- The generator produces plain piles and nothing else, today. The day it
      -- produces something else -- which is the day a golem walks through a wall
      -- in phase seven -- this is how anybody finds out.
      for i = 0, store.cells - 1 do
        if not Stone.height_shaped(store.column[i]) then
          t.fail(label .. ": a column has a hole in it")
          break
        end
      end

      -- Every floor cell's own surface is where its height says it is.
      local mismatched = 0
      for i = 0, store.cells - 1 do
        if store.walkable[i] and not Stone.is_surface(store, i, store.height[i]) then
          mismatched = mismatched + 1
        end
      end
      t.equal(mismatched, 0, label .. ": floor cells stand on their own height")

      -- The rim is wall. It is the only thing between a body that has gone wrong
      -- and an array index that is not there.
      local rim = 0
      for x = 0, store.width - 1 do
        if store.walkable[Stone.index(store, x, 0)] then rim = rim + 1 end
        if store.walkable[Stone.index(store, x, store.depth - 1)] then rim = rim + 1 end
      end
      t.equal(rim, 0, label .. ": the rim is wall")

      -- Walls really are unclimbable. A wall cell adjacent to a floor cell must
      -- stand more than the climb limit above it, or it is a step somebody drew
      -- as a wall.
      local climbable_walls = 0
      for y = 1, store.depth - 2 do
        for x = 1, store.width - 2 do
          local i = Stone.index(store, x, y)
          if not store.walkable[i] then
            for di = 1, 4 do
              local d = Moving.DIRECTIONS[di]
              local n = Stone.index(store, x + d[1], y + d[2])
              if store.walkable[n]
                 and store.height[i] - store.height[n] <= Moving.CLIMB_LIMIT
                 and store.height[i] > store.height[n] then
                climbable_walls = climbable_walls + 1
              end
            end
          end
        end
      end
      t.equal(climbable_walls, 0, label .. ": no wall is one step above its floor")

      -- The orphan fill is a real pass with a real job, and it is also the
      -- place a generator that has quietly stopped working would hide: filling
      -- in everything it could not connect leaves a maze that validates
      -- perfectly and is half the size it should be.
      t.truthy((report.orphans_filled or 0) < report.floor_cells * 0.05,
               label .. ": the orphan fill took less than a twentieth of the floor")

      -- The maze is worth walking through. A diameter near zero is a plaza with
      -- a scratch in it, whatever else the numbers say.
      t.truthy(report.diameter > 40, label .. ": the maze has some distance in it")
    end
  end

  -- Parameters that cannot produce a maze are refused before anything is
  -- allocated, rather than producing something strange.
  t.raises(function() Params.check(Params.with{ width = 128 }) end,
           "an even width is refused")
  t.raises(function() Params.check(Params.with{ layers = 40 }) end,
           "more than 32 layers is refused")
  t.raises(function() Params.with{ nonsense = 1 } end,
           "an unknown parameter name is refused rather than ignored")
end
-- }}}

return M
