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

-- 066-the-delve.lua
--
-- Fire spreads and stops, riders derive, and the three monsters undo each other.

local M = {}

-- {{{ local function delve_world(root, Params, Tick, population)
local function delve_world(root, Params, Tick, population)
  return Tick.new_world(root, Params.with{ seed = 12, capacity = 400 },
                        "delve", population)
end
-- }}}

-- {{{ local function place(world, name, cell, layer)
-- One body of a named kind, put exactly where the test wants it.
local function place(world, name, cell, layer)
  local index, kind = world.creatures.by_name(name)
  local id = world.modules.BodyStore.spawn(world.bodies)
  local b, store = world.bodies, world.store

  b.kind[id]        = index
  b.cell[id]        = cell
  b.layer[id]       = layer
  local x, y = world.modules.Stone.coords(store, cell)
  b.x[id], b.y[id], b.z[id] = x + 0.5, y + 0.5, layer + 1
  b.radius[id]      = kind.radius
  b.body_height[id] = kind.body_height
  b.health[id]      = kind.health
  b.team[id]        = kind.team
  b.willing[id]     = 1
  world.modules.BodyStore.set_locomotion(b, id, kind.locomotion)
  return id
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Params = dofile(root .. "/src/028-maze-parameters.lua")
  local Tick   = dofile(root .. "/src/039-the-tick.lua")

  -- {{{ ignite is a state, not an event
  do
    local world = delve_world(root, Params, Tick, {})
    local Delve = world.modules.Delve
    local cell = world.floor[100]
    local vine = place(world, "vine", cell, world.store.height[cell])

    t.truthy(Delve.ignite(world, vine, "a_test"), "a vine can be set alight")
    t.truthy(world.bodies.burning[vine] > 0, "and it is alight afterwards")
    t.falsy(Delve.ignite(world, vine, "a_test"),
            "setting an already-burning thing alight does nothing")

    -- It keeps burning without anybody doing anything else, which is the whole
    -- difference between ignite and a fireball. A fireball happens at a place
    -- and is over.
    local health_before = world.bodies.health[vine]
    for _ = 1, 30 do Tick.tick(world) end
    t.truthy(world.bodies.burning[vine] > 0, "it is still burning half a second later")
    t.truthy(world.bodies.health[vine] < health_before,
             "and it has been losing health the whole time, with nobody attacking it")

    -- And it stops. Without fuel running out, the aquarium fills with things
    -- that have been on fire since the run began.
    local ticks = 0
    while world.bodies.alive[vine] == 1 and world.bodies.burning[vine] > 0
          and ticks < 3000 do
      Tick.tick(world)
      ticks = ticks + 1
    end
    t.truthy(ticks < 3000, "fire runs out of fuel, or the body it is on runs out of health")
  end
  -- }}}

  -- {{{ stone does not burn, and fire does not jump a gap
  do
    local world = delve_world(root, Params, Tick, {})
    local Delve = world.modules.Delve
    local cell = world.floor[200]
    local golem = place(world, "golem", cell, world.store.height[cell])
    t.falsy(Delve.ignite(world, golem, "a_test"),
            "a stone golem cannot be set alight -- stone does not burn")

    -- Two flammable things far apart: the fire must not reach.
    local a_cell = world.floor[300]
    local b_cell = world.floor[#world.floor - 300]
    local a = place(world, "vine", a_cell, world.store.height[a_cell])
    local b = place(world, "vine", b_cell, world.store.height[b_cell])
    world.modules.BodyStore.reindex(world.bodies)
    Delve.ignite(world, a, "a_test")

    for _ = 1, 600 do Tick.tick(world) end
    t.equal(world.bodies.burning[b], 0,
            "fire does not jump across the maze to something out of reach")
  end
  -- }}}

  -- {{{ the automaton solves itself
  --
  -- Nothing in the code arranges this. It falls out of fire spreading to
  -- flammable neighbours and the automaton being one of them -- and if this test
  -- needed a code path called "self", the fire model was built at the wrong
  -- level.
  do
    local world = delve_world(root, Params, Tick, {})
    local Delve = world.modules.Delve
    local Moving, Stone = world.modules.Moving, world.modules.Stone

    -- Two adjacent floor cells.
    local a_cell, a_layer, b_cell, b_layer
    for _, cell in ipairs(world.floor) do
      local layer = world.store.height[cell]
      for di = 1, 4 do
        local answer, nc, nl = Moving.step(Stone, world.store, cell, layer, di, 1, 1)
        if answer ~= Moving.BLOCKED then
          a_cell, a_layer, b_cell, b_layer = cell, layer, nc, nl
          break
        end
      end
      if a_cell then break end
    end

    local vine      = place(world, "vine", a_cell, a_layer)
    local automaton = place(world, "automaton", b_cell, b_layer)
    world.modules.BodyStore.reindex(world.bodies)

    Delve.ignite(world, vine, "a_test")

    local caught = false
    for _ = 1, 2400 do
      Tick.tick(world)
      if world.bodies.burning[automaton] > 0 then caught = true; break end
      if world.bodies.alive[automaton] == 0 then break end
    end
    t.truthy(caught,
             "a machine made of wood, standing in the vines it sets alight, " ..
             "catches fire -- and nothing in the code says so")
  end
  -- }}}

  -- {{{ a rider's position is derived, never stored
  do
    local world = delve_world(root, Params, Tick, {})
    local Delve = world.modules.Delve
    -- A dinosaur needs somewhere its footprint fits.
    local wide = world.wide_floor[1]
    t.truthy(wide ~= nil, "the maze has somewhere a dinosaur can stand")

    local dino  = place(world, "dino", wide, world.store.height[wide])
    local human = place(world, "human", wide, world.store.height[wide])
    world.modules.BodyStore.reindex(world.bodies)

    t.truthy(Delve.mount(world, world.bodies, human, dino), "a human mounts a dinosaur")
    t.equal(world.bodies.locomotion[human], world.creatures.CARRIED,
            "and its locomotion becomes carried, which does nothing at all")

    -- Move the mount by hand and the rider must follow without anything copying
    -- a position.
    for _ = 1, 60 do Tick.tick(world) end
    t.equal(world.bodies.cell[human], world.bodies.cell[dino],
            "the rider's stance is the mount's")

    local rx, ry = Delve.rider_position(world, world.bodies, human)
    local dx = math.abs(rx - world.bodies.x[dino])
    local dy = math.abs(ry - world.bodies.y[dino])
    t.truthy(dx < 1 and dy < 1,
             "and its drawn position is derived from the mount's, so they cannot drift")

    -- The mount dies; the rider is put down rather than left riding a corpse.
    world.modules.BodyStore.kill(world.bodies, dino)
    Tick.tick(world)
    t.equal(world.bodies.partner[human], 0, "a dead mount drops its rider")
    t.equal(world.bodies.locomotion[human],
            world.creatures.KINDS[world.bodies.kind[human]].locomotion,
            "and the rider walks again")
  end
  -- }}}

  -- {{{ the cycle: each of the three undoes one of the others
  do
    local world = delve_world(root, Params, Tick,
                             { golem = 12, vine = 60, automaton = 40, human = 60 })
    for _ = 1, 3600 do Tick.tick(world) end
    local c = world.counters

    t.truthy((c.vines_lit or 0) > 0,
             "automatons set vines alight -- " .. (c.vines_lit or 0))
    t.truthy((c.golems_held or 0) > 0,
             "vines hold golems still -- " .. (c.golems_held or 0))
    t.truthy((c.smashed or 0) > 0,
             "golems smash automatons -- " .. (c.smashed or 0))
    t.truthy((c.stone_broken or 0) > 0,
             "and a golem walks through walls -- " .. (c.stone_broken or 0) ..
             " blocks. It is the only thing in the project that changes the " ..
             "stone after generation.")
  end
  -- }}}

  -- {{{ the stone really changed, and said so
  do
    local world = delve_world(root, Params, Tick, { golem = 14, human = 20 })
    local before = 0
    for i = 0, world.store.cells - 1 do
      if world.store.walkable[i] then before = before + 1 end
    end
    t.equal(world.store.version, 0, "the stone starts unchanged")

    for _ = 1, 3600 do Tick.tick(world) end

    local after = 0
    for i = 0, world.store.cells - 1 do
      if world.store.walkable[i] then after = after + 1 end
    end
    t.truthy(after > before,
             "golems opened the maze up -- " .. before .. " floor cells became " .. after)
    t.equal(world.store.version, world.counters.stone_broken,
            "and the version counter counted every one of them. It has existed " ..
            "since phase one and nothing bumped it until now, which is what it " ..
            "was for: the renderer's baked mesh is the first thing to cache " ..
            "something derived from the stone.")

    -- The columns a golem has been through are no longer plain piles, which is
    -- the day the validator's height-shaped check was written for.
    local Stone = world.modules.Stone
    local holed = 0
    for i = 0, world.store.cells - 1 do
      if not Stone.height_shaped(world.store.column[i]) then holed = holed + 1 end
    end
    t.equal(holed, 0,
            "taking the top layer off a pile leaves a shorter pile, not a hole -- " ..
            "so the columns are still height-shaped, and a golem that bored a " ..
            "tunnel through the middle of a wall would not be")
  end
  -- }}}
end
-- }}}

return M
