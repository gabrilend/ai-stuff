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

-- 054-simulation-invariants.lua
--
-- The simulation runs the same twice, and the aquarium holds its level.

local M = {}

-- {{{ local function checksum(world)
-- A number that changes if anything about where the bodies are changes.
--
-- Positions are quantised before folding in. Comparing doubles bit for bit would
-- make this a test of the floating point unit; quantising to a thousandth of a
-- cell is far finer than anything anybody can see and coarse enough that the
-- comparison is about the simulation.
local function checksum(world)
  local bit = require("bit")
  local b = world.bodies
  local h = 5381
  for id = 1, b.capacity do
    if b.alive[id] == 1 then
      local function fold(v)
        h = bit.band(h * 33 + math.floor(v * 1000 + 0.5), 0x7FFFFFFF)
      end
      fold(id)
      fold(b.x[id]); fold(b.y[id]); fold(b.z[id])
      fold(b.cell[id]); fold(b.layer[id])
    end
  end
  return h
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Params = dofile(root .. "/src/028-maze-parameters.lua")
  local Tick   = dofile(root .. "/src/039-the-tick.lua")
  local Store  = dofile(root .. "/src/034-the-body-store.lua")

  -- The same seed, twice, for a good long while.
  for _, scene in ipairs({ "balls", "guys" }) do
    local a = Tick.new_world(root, Params.with{ seed = 11 }, scene)
    for _ = 1, 1200 do Tick.tick(a) end
    local b = Tick.new_world(root, Params.with{ seed = 11 }, scene)
    for _ = 1, 1200 do Tick.tick(b) end
    t.equal(checksum(a), checksum(b), scene .. ": one seed runs the same twice")
  end

  -- Different seeds must not agree, or the check above is vacuous.
  local one = Tick.new_world(root, Params.with{ seed = 11 }, "balls")
  local two = Tick.new_world(root, Params.with{ seed = 12 }, "balls")
  for _ = 1, 400 do Tick.tick(one); Tick.tick(two) end
  t.truthy(checksum(one) ~= checksum(two), "two seeds run differently")

  -- The aquarium holds its level. There is no run that finishes: a resting ball
  -- is taken away and a new one dropped in at the top, so the population is a
  -- number that is maintained rather than an event that happened at the start.
  local world = Tick.new_world(root, Params.with{ seed = 5 }, "balls")
  local target = 0
  for _, n in pairs(world.targets) do target = target + n end

  local lowest, highest = world.bodies.live, world.bodies.live
  for _ = 1, 2400 do
    Tick.tick(world)
    if world.bodies.live < lowest  then lowest  = world.bodies.live end
    if world.bodies.live > highest then highest = world.bodies.live end
  end

  t.truthy(highest <= target, "the population never exceeds its target")
  t.truthy(lowest > target * 0.85,
           "the population never sags far below its target -- lowest was " ..
           lowest .. " of " .. target)
  t.truthy(world.counters.removed_at_rest > 0,
           "balls do come to rest and get recycled -- otherwise this is not an aquarium")
  t.equal(world.counters.spawn_skipped, 0,
          "no spawn was skipped for want of an empty cell")

  -- Bodies actually go somewhere. A simulation where everything is motionless
  -- passes every safety check in the project.
  local moved, total = 0, 0
  for id = 1, world.bodies.capacity do
    if world.bodies.alive[id] == 1 then
      total = total + 1
      if world.bodies.distance[id] > 1.0 then moved = moved + 1 end
    end
  end
  t.truthy(moved > total * 0.6,
           "most bodies have travelled more than a cell -- " .. moved .. " of " .. total)

  -- The free list and the generation counter, which are what stop a stored id
  -- silently becoming whoever moved into the slot.
  local small = Store.new(8, 4)
  local ids, gens = {}, {}
  for k = 1, 8 do ids[k], gens[k] = Store.spawn(small) end
  t.raises(function() Store.spawn(small) end,
           "a full store refuses rather than growing")
  for k = 1, 8, 2 do Store.kill(small, ids[k]) end
  for k = 1, 4 do
    local id, gen = Store.spawn(small)
    -- Whatever slot came back, the old generation for it must no longer validate.
    for j = 1, 8 do
      if ids[j] == id then
        t.falsy(Store.is_valid(small, id, gens[j]),
                "a recycled id does not validate against its old generation")
      end
    end
    t.truthy(Store.is_valid(small, id, gen), "the new generation does validate")
  end
end
-- }}}

return M
