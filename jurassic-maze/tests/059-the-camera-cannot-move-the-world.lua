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

-- 059-the-camera-cannot-move-the-world.lua
--
-- Watching must not change what is watched.
--
-- The camera has its own random stream, and the simulation never reads it. That
-- is a rule somebody has to keep, and this is the thing that makes keeping it
-- checkable: a run with the swap key pressed a thousand times at random must
-- produce exactly the same simulation as a run where nobody touched it.
--
-- Without it, a session where somebody was looking around diverges from one
-- where they were not, and every bug report becomes a story about something that
-- happened once.

local M = {}

-- {{{ local function checksum(world)
local function checksum(world)
  local bit = require("bit")
  local b = world.bodies
  local h = 5381
  for id = 1, b.capacity do
    if b.alive[id] == 1 then
      local function fold(v)
        h = bit.band(h * 33 + math.floor(v * 1000 + 0.5), 0x7FFFFFFF)
      end
      fold(id); fold(b.x[id]); fold(b.y[id]); fold(b.z[id])
      fold(b.cell[id]); fold(b.layer[id]); fold(b.intent[id])
      fold(b.partner[id]); fold(b.idle_row[id])
    end
  end
  return h
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Params   = dofile(root .. "/src/028-maze-parameters.lua")
  local Tick     = dofile(root .. "/src/039-the-tick.lua")
  local Director = dofile(root .. "/src/044-the-director.lua")
  local Camera   = dofile(root .. "/src/043-the-camera.lua")
  local Projection = dofile(root .. "/src/040-the-projection.lua")

  local TICKS = 1500

  -- One: nobody is watching at all.
  local SMALL = { seed = 23, capacity = 220 }
  local FEW = { guy = 90 }
  local quiet = Tick.new_world(root, Params.with(SMALL), "guys", FEW)
  for _ = 1, TICKS do Tick.tick(quiet) end
  local quiet_sum = checksum(quiet)

  -- Two: somebody is watching, swapping constantly, and driving every setting
  -- the panel has through its whole range.
  local watched = Tick.new_world(root, Params.with(SMALL), "guys", FEW)
  local director = Director.new()
  local camera = Camera.new()
  Camera.fit(Projection, camera, watched.store, 1600, 900)

  local swaps, moves = 0, 0
  for tick = 1, TICKS do
    Tick.tick(watched)

    Director.update(watched, director, camera, Projection, Camera,
                    watched.modules.Walking, 1 / 60, 1600, 900)

    -- Press the swap key, often.
    if tick % 3 == 0 then
      Director.pick(watched, director)
      swaps = swaps + 1
    end
    if tick % 97 == 0 then Director.free(director) end

    -- And move every control, which is what the panel does.
    for index, control in ipairs(Director.CONTROLS) do
      if control.kind == "toggle" then
        if (tick + index) % 11 == 0 then
          director.settings[control.key] = not director.settings[control.key]
          moves = moves + 1
        end
      else
        local t01 = ((tick * index) % 100) / 100
        director.settings[control.key] =
          control.low + t01 * (control.high - control.low)
        moves = moves + 1
      end
    end

    -- And pan and zoom it about.
    Camera.pan_by(camera, (tick % 7) - 3, (tick % 5) - 2)
    if tick % 13 == 0 then
      Camera.zoom_at(Projection, camera, (tick % 26 == 0) and 1.1 or 0.92,
                     800, 450)
    end
  end

  t.equal(checksum(watched), quiet_sum,
          "a session with somebody watching, swapping " .. swaps ..
          " times and moving " .. moves .. " controls, runs identically to one " ..
          "where nobody looked")

  -- And the check that the check is not vacuous: the camera really did do
  -- something, and its own stream really did advance.
  t.truthy(swaps > 100, "the swap key was actually pressed")
  t.truthy(watched.streams.camera.count > 0, "the camera stream was actually drawn from")
  t.equal(quiet.streams.camera.count, 0,
          "the quiet run never touched the camera stream -- if it did, the " ..
          "simulation is reading it, which is the thing this whole arrangement " ..
          "exists to prevent")

  -- Every control round-trips through its own range.
  for _, control in ipairs(Director.CONTROLS) do
    if control.kind == "slider" then
      for _, v in ipairs({ control.low, (control.low + control.high) / 2,
                           control.high }) do
        director.settings[control.key] = v
        t.equal(director.settings[control.key], v,
                control.key .. " holds the value it was set to")
      end
    end
  end

  -- A subject whose slot has been recycled must be caught being gone rather
  -- than silently becoming whoever moved in.
  local world = Tick.new_world(root, Params.with{ seed = 5, capacity = 220 }, "guys", FEW)
  local d = Director.new()
  Director.pick(world, d)
  local victim, generation = d.subject, d.subject_generation
  t.truthy(victim ~= 0, "the director picked somebody")

  world.modules.BodyStore.kill(world.bodies, victim)
  t.equal(Director.verdict(world, d), "gone",
          "a subject that has been killed reads as gone")

  -- Refill the slot and check it is still gone, which is the case a plain id
  -- comparison would get wrong.
  local reborn = world.modules.BodyStore.spawn(world.bodies)
  t.equal(reborn, victim, "the slot really was recycled")
  t.truthy(world.bodies.generation[reborn] ~= generation,
           "and its generation moved")
  t.equal(Director.verdict(world, d), "gone",
          "the stranger who moved into the slot is not the subject")
end
-- }}}

return M
