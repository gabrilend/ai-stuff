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

-- 061-duels.lua
--
-- A duel is one record, damage is buffered, and every duel ends.
--
-- The interesting cases here do not arise on their own often enough to be waited
-- for -- a mutual kill is one duel in eight, a stalemate essentially never -- so
-- they are set up deliberately. A rule that only runs in a situation nobody
-- arranges is a rule nobody has ever seen run.

local M = {}

-- {{{ local function two_fencers(root, seed)
-- A world with exactly two fencers in it, standing next to each other on
-- opposing sides, so that a duel is about to happen and nothing else is.
local function two_fencers(root, Params, Tick)
  local world = Tick.new_world(root, Params.with{ seed = seed or 4, capacity = 40 },
                               "fencers", {})
  local Creatures = world.creatures
  local index = Creatures.by_name("fencer")

  -- Put them on two surfaces that are genuinely adjacent, so the meet pass finds
  -- them. Walking the maze for a pair is more reliable than picking a cell and
  -- hoping.
  local Moving = world.modules.Moving
  local Stone  = world.modules.Stone
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

  local ids = {}
  for k, place in ipairs({ { a_cell, a_layer }, { b_cell, b_layer } }) do
    local id = world.modules.BodyStore.spawn(world.bodies)
    local b = world.bodies
    b.kind[id]        = index
    b.cell[id]        = place[1]
    b.layer[id]       = place[2]
    local x, y = Stone.coords(world.store, place[1])
    b.x[id] = x + 0.5
    b.y[id] = y + 0.5
    b.z[id] = place[2] + 1
    b.radius[id]      = Creatures.KINDS[index].radius
    b.body_height[id] = Creatures.KINDS[index].body_height
    b.health[id]      = Creatures.KINDS[index].health
    b.team[id]        = k
    world.modules.BodyStore.set_locomotion(b, id, Creatures.KINDS[index].locomotion)
    ids[k] = id
  end
  world.modules.BodyStore.reindex(world.bodies)
  return world, ids[1], ids[2]
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Params = dofile(root .. "/src/028-maze-parameters.lua")
  local Tick   = dofile(root .. "/src/039-the-tick.lua")

  -- A duel starts between opposing sides, and does not between the same side.
  do
    local world, a, b = two_fencers(root, Params, Tick)
    for _ = 1, 4 do Tick.tick(world) end
    t.truthy(world.bodies.duel[a] ~= 0, "two opposing fencers begin a duel")
    t.equal(world.bodies.duel[a], world.bodies.duel[b],
            "and it is the same duel, which is the point of it being a record")

    local same, c, d = two_fencers(root, Params, Tick)
    same.bodies.team[d] = same.bodies.team[c]
    for _ = 1, 8 do Tick.tick(same) end
    t.equal(same.bodies.duel[c], 0, "two fencers of one side do not duel")
  end

  -- **The mutual kill**, which is the case buffering exists for.
  --
  -- Both fencers are set to die to a single blow and both are made certain to
  -- land one. If damage applied as it was dealt, whichever body the resolve pass
  -- reached first would kill the other and survive -- so the same situation is
  -- run with the ids in both orders, and the outcome must be the same.
  for _, swap in ipairs({ false, true }) do
    local world, a, b = two_fencers(root, Params, Tick)
    local kind = world.creatures.KINDS[world.bodies.kind[a]]
    kind.skill, kind.parry, kind.swing = 10, 0, 0     -- every blow lands
    kind.damage = 999
    if swap then a, b = b, a end

    local ticks = 0
    while world.bodies.alive[a] == 1 and world.bodies.alive[b] == 1
          and ticks < 400 do
      Tick.tick(world)
      ticks = ticks + 1
    end

    t.equal(world.bodies.alive[a], 0,
            "mutual kill (" .. (swap and "reversed" or "in order") ..
            "): the first fencer died")
    t.equal(world.bodies.alive[b], 0,
            "mutual kill (" .. (swap and "reversed" or "in order") ..
            "): so did the second -- damage was buffered, not applied as dealt")
    t.equal(world.counters.duels_both_of_them_fell or 0, 1,
            "and the duel recorded that both of them fell")
  end

  -- **The stalemate.** Two fencers who cannot hurt each other must not stand
  -- there until the machine is turned off -- and a camera watching them under
  -- "swap on its own" would have nothing to swap to, because the verdict never
  -- fires.
  do
    local world, a, b = two_fencers(root, Params, Tick)
    local kind = world.creatures.KINDS[world.bodies.kind[a]]
    kind.skill, kind.parry, kind.swing = 0, 10, 0     -- nothing ever lands
    kind.stalemate_seconds = 3
    -- Set explicitly, because the default is now zero: a released fencer
    -- re-engages immediately, so a stalemate is followed instantly by the same
    -- two of them starting again. That is the wanted default and it makes this
    -- particular assertion untestable without saying otherwise.
    kind.disengage_seconds = 5

    for _ = 1, 400 do Tick.tick(world) end
    t.equal(world.counters.duels_neither_could_land_a_blow or 0, 1,
            "a duel nobody can win ends at the stalemate clock")
    t.equal(world.bodies.alive[a], 1, "and both fencers walk away from it")
    t.equal(world.bodies.alive[b], 1, "both of them")
    t.equal(world.bodies.duel[a], 0, "released from the duel")
    t.truthy(world.bodies.flee_timer[a] > 0,
             "and told to keep away for a moment, so they do not re-engage instantly")
  end

  -- **The default, which is the answer to open question 1.** A released fencer
  -- re-engages immediately and the fight rolls on: a melee rather than a series
  -- of duels, and the camera never has to move to keep watching one.
  do
    local world, a, b = two_fencers(root, Params, Tick)
    local kind = world.creatures.KINDS[world.bodies.kind[a]]
    kind.skill, kind.parry, kind.swing = 0, 10, 0
    kind.stalemate_seconds = 1

    t.equal(kind.disengage_seconds, 0,
            "a fencer's disengage interval is zero by default -- the sentence " ..
            "was about the fencers swapping opponents, not about the camera")

    for _ = 1, 400 do Tick.tick(world) end
    t.truthy((world.counters.duels or 0) > 3,
             "so released fencers re-engage -- " .. (world.counters.duels or 0) ..
             " fights rather than one")
    t.equal(world.bodies.flee_timer[a], 0, "and nobody is keeping away")
  end

  -- A participant killed from outside dissolves the duel, and the generation is
  -- what catches it. A plain id would still name a live body -- whichever one
  -- moved into the recycled slot.
  do
    local world, a, b = two_fencers(root, Params, Tick)
    for _ = 1, 4 do Tick.tick(world) end
    t.truthy(world.bodies.duel[a] ~= 0, "a duel is under way")

    world.modules.BodyStore.kill(world.bodies, b)
    Tick.tick(world)
    t.equal(world.bodies.duel[a], 0, "killing one of them dissolves the duel")
    t.equal(world.counters.duels_one_of_them_is_no_longer_there or 0, 1,
            "and it is recorded as that ending, not as a death in the duel")
  end

  -- Nothing is ever left buffered between ticks.
  do
    local world = Tick.new_world(root, Params.with{ seed = 9, capacity = 300 },
                                 "fencers", { fencer = 120 })
    for _ = 1, 900 do
      Tick.tick(world)
      local left = 0
      for id = 1, world.bodies.capacity do
        if world.bodies.alive[id] == 1 and world.bodies.incoming_damage[id] ~= 0 then
          left = left + 1
        end
      end
      if left ~= 0 then
        t.fail("damage was still buffered at the end of a tick: " .. left .. " bodies")
        break
      end
    end
    t.truthy(true, "no damage is ever left buffered between ticks")

    -- And every duel that started, finished or is still running -- none leaked.
    local running = 0
    for d = 1, world.duels.capacity do
      if world.duels.alive[d] == 1 then running = running + 1 end
    end
    local ended = 0
    for name, n in pairs(world.counters) do
      if name:match("^duels_") then ended = ended + n end
    end
    t.equal(running + ended, world.counters.duels,
            "every duel that began is either running or has ended -- none leaked")
  end
end
-- }}}

return M
