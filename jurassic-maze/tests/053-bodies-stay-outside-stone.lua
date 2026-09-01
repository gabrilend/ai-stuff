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

-- 053-bodies-stay-outside-stone.lua
--
-- No body is ever inside stone, and none of them leave the world.
--
-- This is the most important test in the project, and it is worth more than the
-- collision code being carefully written -- careful code can be defeated by a
-- number somebody changed, and this cannot.
--
-- A ball that gets inside a wall is the likeliest bug here and the hardest to
-- see. Once it is in there every rule gives the wrong answer: the floor under it
-- is the top of the block it is inside, so it is standing on nothing, so it falls
-- forever, and what shows on screen is a ball that simply vanished.

local M = {}

-- How far a rolling body is allowed to be below the top of the column it is
-- over, in layers.
--
-- Not zero, and the reason is a design decision rather than a slack allowance. A
-- ball rolls on an *interpolated* floor: heights are sampled at cell centres and
-- blended, so a flight of one-layer steps becomes a smooth ramp and the ball
-- accelerates down it instead of bouncing. Halfway across a step, the blended
-- floor is halfway between the two cells' heights while the ball is still over
-- one of them -- so it is, strictly, a fraction of a layer inside the step it is
-- climbing down. That is the lie the interpolation exists to tell.
--
-- The clamp in the floor sampler means a cell more than one layer from the
-- ball's own never contributes, so the blend can never span more than one layer
-- and the dip can never exceed one. A ball that has tunnelled into a wall is
-- several layers under, which is what this number separates from that.
local MAX_DIP = 1.05

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Params     = dofile(root .. "/src/028-maze-parameters.lua")
  local Stone      = dofile(root .. "/src/030-the-stone.lua")
  local Locomotion = dofile(root .. "/src/036-locomotion.lua")
  local Tick       = dofile(root .. "/src/039-the-tick.lua")

  -- A smaller maze, and the sweep run every few ticks rather than every one.
  --
  -- A body that is inside stone stays inside stone -- it has no way out, that
  -- being the whole problem with it -- so checking on every tick finds the same
  -- violation dozens of times and costs thirty times as much. On the full-size
  -- maze with the full population this test alone took the best part of a
  -- minute, which is how a suite stops being run.
  local EVERY = 3

  local POPULATIONS = {
    balls = { ball = 90 },
    guys  = { guy = 90 },
    both  = { ball = 60, guy = 60 },
  }

  for _, scene in ipairs({ "balls", "guys", "both" }) do
    for _, seed in ipairs({ 3, 19 }) do
      -- The full-size maze with a small population, not a small maze with the
      -- full one. Shrinking the maze was tried first and made this test
      -- slower: the same bodies in a quarter of the floor is four times the
      -- density, and density is what the meet pass costs.
      local world = Tick.new_world(root, Params.with{ seed = seed, capacity = 220 },
                                   scene, POPULATIONS[scene])
      local store, b = world.store, world.bodies
      local creatures = world.creatures

      local buried, outside, sunk, floating = 0, 0, 0, 0
      local worst, worst_dip = nil, 0

      for tick = 1, 1800 do
        Tick.tick(world)

        if tick % EVERY == 0 then
        for id = 1, b.capacity do
          if b.alive[id] == 1 then
            local x, y, z = b.x[id], b.y[id], b.z[id]

            -- Outside the footprint. The rim is supposed to make this
            -- impossible and the locomotion rows raise if it happens, so this is
            -- a second net under a check that already shouts.
            if x < 0 or y < 0 or x >= store.width or y >= store.depth then
              outside = outside + 1
            else
              local cell = Stone.index(store, math.floor(x), math.floor(y))
              local top  = Locomotion.surface_top(store.height[cell])
              local dip  = top - z

              if dip > MAX_DIP then
                buried = buried + 1
                if dip > worst_dip then
                  worst_dip = dip
                  worst = string.format(
                    "%s seed %d tick %d: body %d at (%.2f, %.2f, %.2f) is %.2f " ..
                    "layers inside the column at cell %d, whose top is %d",
                    scene, seed, tick, id, x, y, z, dip, cell, top)
                end
              end

              -- A walker is on an exact surface, never on a blend, so it gets
              -- the strict version of the same check.
              local kind = creatures.KINDS[b.kind[id]]
              if kind.locomotion == creatures.WALKING and b.vz[id] == 0 then
                if math.abs(top - z) > 0.001 and z < top then
                  buried = buried + 1
                end
              end

              if z < -1 then sunk = sunk + 1 end

              -- The other direction: a body a very long way above its floor and
              -- not falling is one the gluing has let go of.
              if z - top > 6 and b.vz[id] == 0 then floating = floating + 1 end
            end
          end
        end
        end
      end

      local label = scene .. " seed " .. seed
      t.equal(buried, 0, label .. ": bodies buried in stone" ..
              (worst and ("\n    worst: " .. worst) or ""))
      t.equal(outside, 0, label .. ": bodies outside the world")
      t.equal(sunk, 0, label .. ": bodies below the floor of the world")
      t.equal(floating, 0, label .. ": bodies hanging in the air, not falling")
    end
  end
end
-- }}}

return M
