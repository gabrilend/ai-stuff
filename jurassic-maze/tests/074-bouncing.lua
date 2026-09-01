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

-- 074-bouncing.lua
--
-- Spheres against faces and against each other, with no tolerance for being
-- inside anything.
--
-- The zero is the whole point of this file. `053-bodies-stay-outside-stone.lua`
-- has to allow a rolling body a full layer of penetration, because the row it
-- tests stands on an *interpolated* floor: halfway across a step the blended
-- height is between the two cells' while the ball is still over one of them, so
-- the ball is genuinely inside the step it is crossing. That is the lie the
-- interpolation exists to tell and the test had to be written around it.
--
-- A sphere resolved against real rectangles has no such excuse. If it is inside
-- the stone, something is wrong. The tolerance here is a millionth of a layer,
-- which is floating point and nothing else, and the gap between that number and
-- the other test's 1.05 is the measurable difference between the two approaches.

local M = {}

-- Floating point, not slack. A sphere pushed out to exactly one radius lands
-- within an ulp or two of the surface, and never inside it.
local TOLERANCE = 1e-6

-- {{{ local function reference_closest(m, f, px, py, pz)
-- The nearest point of a rectangle to a point, found by looking at a lot of
-- points on it.
--
-- The real one is three clamps, which is exact and which is also the sort of
-- three lines that is quietly wrong at an edge. This samples the rectangle on a
-- grid and takes the best it finds -- far too slow to run in anger, close enough
-- to check against, and obviously right in a way the clamps are not.
local function reference_closest(m, f, px, py, pz)
  -- Exactly one axis of a face is degenerate, so the rectangle is swept by the
  -- other two. Which two it is has to be decided per face rather than assumed:
  -- a top is flat in z, a riser looking along x is flat in x, and one looking
  -- along y is flat in y.
  local N = 50
  local best = math.huge
  for a = 0, N do
    for b = 0, N do
      local u, v = a / N, b / N
      local qx, qy, qz
      if m.x0[f] == m.x1[f] then
        qx = m.x0[f]
        qy = m.y0[f] + (m.y1[f] - m.y0[f]) * u
        qz = m.z0[f] + (m.z1[f] - m.z0[f]) * v
      elseif m.y0[f] == m.y1[f] then
        qy = m.y0[f]
        qx = m.x0[f] + (m.x1[f] - m.x0[f]) * u
        qz = m.z0[f] + (m.z1[f] - m.z0[f]) * v
      else
        qz = m.z0[f]
        qx = m.x0[f] + (m.x1[f] - m.x0[f]) * u
        qy = m.y0[f] + (m.y1[f] - m.y0[f]) * v
      end
      local d = (px - qx) ^ 2 + (py - qy) ^ 2 + (pz - qz) ^ 2
      if d < best then best = d end
    end
  end
  return math.sqrt(best)
end
-- }}}

-- {{{ local function clamped_closest(m, f, px, py, pz)
local function clamped_closest(m, f, px, py, pz)
  local qx = px; if qx < m.x0[f] then qx = m.x0[f] elseif qx > m.x1[f] then qx = m.x1[f] end
  local qy = py; if qy < m.y0[f] then qy = m.y0[f] elseif qy > m.y1[f] then qy = m.y1[f] end
  local qz = pz; if qz < m.z0[f] then qz = m.z0[f] elseif qz > m.z1[f] then qz = m.z1[f] end
  return math.sqrt((px - qx) ^ 2 + (py - qy) ^ 2 + (pz - qz) ^ 2)
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Params     = dofile(root .. "/src/028-maze-parameters.lua")
  local Stone      = dofile(root .. "/src/030-the-stone.lua")
  local Model      = dofile(root .. "/src/071-the-model.lua")
  local Tick       = dofile(root .. "/src/039-the-tick.lua")
  local Creatures  = dofile(root .. "/assets/035-creature-table.lua")

  -- The clamps against the sampled reference, on a real model, from points all
  -- around it.
  do
    local field = { width = 6, depth = 6, height = {} }
    for y = 0, 5 do
      for x = 0, 5 do field.height[x + y * 6] = 10 - math.floor(x / 2) end
    end
    local m = Model.build(field, 0)

    local worst, checked = 0, 0
    for f = 0, m.count - 1 do
      for _, p in ipairs({ { 2.5, 2.5, 11.0 }, { 0.1, 0.1, 9.4 }, { 5.9, 3.3, 8.2 },
                           { 3.0, 0.0, 10.0 }, { -1, 2, 12 }, { 2, 7, 6 } }) do
        local a = clamped_closest(m, f, p[1], p[2], p[3])
        local b = reference_closest(m, f, p[1], p[2], p[3])
        checked = checked + 1
        -- The sampler can only ever be the further of the two, since it is
        -- picking from a finite set of points on the same rectangle.
        local gap = b - a
        if gap < 0 then gap = -gap * 1000 end
        if gap > worst then worst = gap end
      end
    end
    t.truthy(checked > 40, "there were faces and points enough to be worth it")
    t.truthy(worst < 0.02, "the three clamps agree with sampling the rectangle")
  end

  -- Two spheres head-on. Momentum is conserved and they leave at the restitution
  -- times the speed they arrived at.
  --
  -- A collision that quietly adds energy does not look like a bug. It looks like
  -- an aquarium that never settles, which looks like liveliness.
  do
    local Bouncing = dofile(root .. "/src/073-bouncing.lua")
    local kinds = Creatures.KINDS
    local bouncer
    for i, k in ipairs(kinds) do if k.name == "bouncer" then bouncer = i end end
    t.truthy(bouncer, "there is a bouncer in the creature table")

    -- A world, only so that there is a body store with the right fields in it.
    local world = Tick.new_world(root, Params.with{ map = "070-the-mountainside",
                                                    capacity = 40 },
                                 "empty", {})
    local b = world.bodies
    local BodyStore = dofile(root .. "/src/034-the-body-store.lua")

    local a = BodyStore.spawn(b)
    local c = BodyStore.spawn(b)
    local r = kinds[bouncer].radius
    local e = kinds[bouncer].restitution

    b.alive[a], b.alive[c] = 1, 1
    b.kind[a], b.kind[c] = bouncer, bouncer
    -- Just touching, closing at two cells a second each.
    b.x[a], b.y[a], b.z[a] = 10.0, 10.0, 5.0
    b.x[c], b.y[c], b.z[c] = 10.0 + 2 * r - 0.01, 10.0, 5.0
    b.vx[a], b.vx[c] = 2.0, -2.0

    local before = b.vx[a] + b.vx[c]
    Bouncing.resolve_pair_for_test(b, a, c, r, r, e)
    local after = b.vx[a] + b.vx[c]

    t.truthy(math.abs(after - before) < 1e-9, "a head-on pair conserves momentum")
    t.truthy(b.vx[a] < 0, "the one that was going right is now going left")
    t.truthy(b.vx[c] > 0, "and the other one the other way")
    local approach, separate = 4.0, b.vx[c] - b.vx[a]
    t.truthy(math.abs(separate - approach * e) < 1e-9,
             "they separate at the restitution times the speed they closed at")

    -- And they are no longer inside each other.
    t.truthy(b.x[c] - b.x[a] >= 2 * r - 1e-9, "the pair ends up apart")
  end

  -- Then the real thing: a crowd of them on the mountain for a while.
  do
    local world = Tick.new_world(root, Params.with{ map = "070-the-mountainside",
                                                    capacity = 260 },
                                 "bounce", { bouncer = 240 })
    local store, b = world.store, world.bodies
    local kinds = world.creatures.KINDS
    local model = world.model

    local inside_stone, overlapping, outside, sunk = 0, 0, 0, 0
    local worst_dip, worst_overlap, worst_sink = 0, 0, 0
    local field = store.field

    for tick = 1, 900 do
      Tick.tick(world)

      if tick % 5 == 0 then
        for id = 1, b.capacity do
          if b.alive[id] == 1 then
            local x, y, z = b.x[id], b.y[id], b.z[id]
            if x < 0 or y < 0 or x >= store.width or y >= store.depth then
              outside = outside + 1
            else
              -- Against the faces themselves, and not against the height of the
              -- cell the body happens to be over.
              --
              -- The cell was tried first and it is the wrong question. A sphere
              -- wedged between a step and another sphere sits with its centre a
              -- fraction over the higher cell while resting perfectly on the
              -- lower one -- no part of it inside any stone, and a cell-based
              -- check calls it buried. What "inside the stone" actually means is
              -- that some face the sphere is in front of is nearer to its centre
              -- than its own radius, which is this.
              -- Sinking, which is a different failure from being inside the
              -- stone and is invisible to the check below it. A sphere that gets
              -- under a floor is in open air with nothing near it, so no face
              -- reports an overlap -- it simply falls forever, still simulated,
              -- drawn somewhere off the bottom of the world. The tolerance is a
              -- whole layer because this is about falling through, not about the
              -- fractions a wedged sphere gives up.
              local plane = field.height[math.floor(x) + math.floor(y) * store.width]
              if plane - z > 1.0 then
                sunk = sunk + 1
                if plane - z > worst_sink then worst_sink = plane - z end
              end

              local r = kinds[b.kind[id]].radius
              local pz = z + r
              local cx, cy = math.floor(x), math.floor(y)
              for oy = -1, 1 do
                for ox = -1, 1 do
                  local ax, ay = cx + ox, cy + oy
                  if ax >= 0 and ay >= 0 and ax < model.width and ay < model.depth then
                    local list = model.at[ax + ay * model.width]
                    if list then
                      for k = 1, #list do
                        local f = list[k]
                        local side = (x - model.x0[f]) * model.nx[f]
                                   + (y - model.y0[f]) * model.ny[f]
                                   + (pz - model.z0[f]) * model.nz[f]
                        if side > 0 then
                          local d = clamped_closest(model, f, x, y, pz)
                          local into = r - d
                          if into > TOLERANCE then
                            inside_stone = inside_stone + 1
                            if into > worst_dip then worst_dip = into end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end

        -- No two spheres inside each other. Quadratic in the population, which
        -- is why the population here is small and the sweep is every fifth tick.
        for i = 1, b.capacity do
          if b.alive[i] == 1 then
            local ri = kinds[b.kind[i]].radius
            for j = i + 1, b.capacity do
              if b.alive[j] == 1 then
                local rj = kinds[b.kind[j]].radius
                local dx = b.x[j] - b.x[i]
                local dy = b.y[j] - b.y[i]
                local dz = (b.z[j] + rj) - (b.z[i] + ri)
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                local over = (ri + rj) - d
                if over > TOLERANCE then
                  overlapping = overlapping + 1
                  if over > worst_overlap then worst_overlap = over end
                end
              end
            end
          end
        end
      end
    end

    t.equal(outside, 0, "no sphere left the world")
    t.equal(sunk, 0,
            string.format("no sphere fell through the floor (worst %.2f layers under)",
                          worst_sink))
    t.equal(inside_stone, 0,
            string.format("no sphere is inside the stone (worst dip %.6f)", worst_dip))
    -- Not zero, and the reason is a real limit rather than a slack allowance.
    --
    -- The stone is resolved last and the stone wins, so a sphere wedged into a
    -- gap narrower than its own diameter -- against a step on one side and
    -- another sphere on the other -- stays overlapping the sphere. There is no
    -- legal place for it to be, and the choice is between a body inside another
    -- body and a body inside a wall. A body inside a wall falls through the
    -- world; a body inside a body looks like a tight pile.
    --
    -- What must still hold is that they never pass *through* one another, which
    -- is what this asserts: no sphere's centre is ever inside another sphere.
    local closest_allowed = 0
    for _, k in ipairs(kinds) do
      if k.name == "bouncer" then closest_allowed = k.radius end
    end
    t.truthy(worst_overlap < closest_allowed,
             string.format("no sphere's centre is inside another (worst overlap %.4f " ..
                           "against a radius of %.2f)", worst_overlap, closest_allowed))
    t.truthy(world.counters.spawned > 240,
             "the aquarium topped itself up, so balls were reaching rest")
  end
end
-- }}}

return M
