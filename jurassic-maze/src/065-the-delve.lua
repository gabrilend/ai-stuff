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

-- 065-the-delve.lua
--
-- Fire that spreads, riding, and three monsters that undo each other.
--
-- A mode rather than a phase of the aquarium. The word it turns on is **solve**:
-- a monster here is a lock rather than a health bar, and a party carrying no
-- answer to a stone golem does not lose the fight -- it has no fight to have.
--
-- That reading is an interpretation of one word. See open question 3.

local M = {}

local Stone, Moving, Walking, BodyStore, Locomotion, Creatures, Sight

-- {{{ function M.link(stone, moving, walking, body_store, locomotion, creatures, sight)
function M.link(stone, moving, walking, body_store, locomotion, creatures, sight)
  Stone, Moving, Walking, BodyStore, Locomotion, Creatures, Sight =
    stone, moving, walking, body_store, locomotion, creatures, sight
end
-- }}}

-- ======================================================================
-- Fire
-- ======================================================================

-- {{{ function M.ignite(world, id, why)
-- Sets a body alight. The only way anything catches fire.
--
-- A body, not a place and not a moment. **Ignite is a state**, and the whole
-- point of it being one is that it persists after whatever caused it has stopped
-- paying attention.
function M.ignite(world, id, why)
  local bodies = world.bodies
  if bodies.alive[id] == 0 then return false end
  if bodies.burning[id] > 0 then return false end

  local kind = Creatures.KINDS[bodies.kind[id]]
  if (kind.flammable or 0) <= 0 then return false end

  bodies.burning[id] = kind.fuel or 4.0
  world.counters["ignited_" .. (why or "somehow")] =
    (world.counters["ignited_" .. (why or "somehow")] or 0) + 1
  world.counters.ignitions = (world.counters.ignitions or 0) + 1
  return true
end
-- }}}

-- {{{ function M.burn(world, dt)
-- One tick of everything that is alight.
--
-- Sweeps the burning, takes their fuel, buffers their damage, and rolls to
-- spread to whatever flammable thing is beside them.
--
-- Three things fall out of this that nobody wrote, and the third is the test of
-- whether the model was built at the right level:
--
--   1. The automaton burns. A machine made of wood whose power is to set things
--      alight, standing in the vines it has just ignited, has solved itself.
--   2. A burning corridor is a corridor nobody wants to use, which is terrain.
--   3. A party can carry fire: something flammable carried past a burning thing
--      catches, and can be carried elsewhere. That is an ability nobody wrote.
function M.burn(world, dt)
  local bodies = world.bodies
  local burns  = Creatures.BURNS
  local rng    = world.streams.burn
  local width  = world.store.width

  for id = 1, bodies.capacity do
    if bodies.alive[id] == 1 and bodies.burning[id] > 0 then
      bodies.burning[id] = bodies.burning[id] - dt
      bodies.incoming_damage[id] =
        bodies.incoming_damage[id] + burns.damage_per_second * dt

      if bodies.burning[id] <= 0 then
        bodies.burning[id] = 0
        world.counters.burnt_out = (world.counters.burnt_out or 0) + 1
      elseif rng:chance(burns.spread_chance * dt) then
        -- To a neighbour, if there is a flammable one. Fire does not jump gaps:
        -- the spread range is one cell, so a firebreak is a firebreak.
        local x = bodies.cell[id] % width
        local y = math.floor(bodies.cell[id] / width)
        BodyStore.for_each_near(bodies, width, x, y, function(other)
          if other ~= id and bodies.alive[other] == 1
             and bodies.burning[other] == 0 then
            local kind = Creatures.KINDS[bodies.kind[other]]
            if (kind.flammable or 0) > 0 and rng:chance(kind.flammable) then
              M.ignite(world, other, "spreading")
            end
          end
        end)
      end
    end
  end
end
-- }}}

-- ======================================================================
-- Riding
-- ======================================================================

-- {{{ function M.mount(world, bodies, rider, mount)
-- A human climbs a willing dinosaur.
--
-- Neither body is destroyed and neither is absorbed. The rider's locomotion
-- becomes `carried`, which does nothing at all -- the correct amount of work for
-- a body not moving under its own power -- and being a row rather than a flag
-- means the move pass never learns that riding exists.
function M.mount(world, bodies, rider, mount)
  if bodies.partner[rider] ~= 0 or bodies.partner[mount] ~= 0 then return false end
  if bodies.duel[rider] ~= 0 or bodies.game[mount] ~= 0 then return false end
  if bodies.willing[mount] == 0 then return false end

  bodies.partner[rider] = mount
  bodies.partner_generation[rider] = bodies.generation[mount]
  bodies.partner[mount] = rider
  bodies.partner_generation[mount] = bodies.generation[rider]

  BodyStore.set_locomotion(bodies, rider, Creatures.CARRIED)
  bodies.intent[rider]   = 0
  bodies.progress[rider] = 0

  world.counters.mounted = (world.counters.mounted or 0) + 1
  return true
end
-- }}}

-- {{{ function M.dismount(world, bodies, rider, why)
function M.dismount(world, bodies, rider, why)
  local mount = bodies.partner[rider]
  bodies.partner[rider] = 0
  bodies.partner_generation[rider] = 0

  if mount ~= 0 and bodies.alive[mount] == 1 and bodies.partner[mount] == rider then
    bodies.partner[mount] = 0
    bodies.partner_generation[mount] = 0
    -- Put the rider down where the mount is. If there is nothing under it, the
    -- shared falling takes over -- which is the same falling a ball uses, and
    -- writing a second one is how they start disagreeing about what a fall is.
    bodies.cell[rider]  = bodies.cell[mount]
    bodies.layer[rider] = bodies.layer[mount]
    bodies.x[rider]     = bodies.x[mount]
    bodies.y[rider]     = bodies.y[mount]
    bodies.z[rider]     = bodies.z[mount]
  end

  local kind = Creatures.KINDS[bodies.kind[rider]]
  BodyStore.set_locomotion(bodies, rider, kind.locomotion)
  bodies.intent[rider] = 0
  world.counters["dismounted_" .. (why or "somehow")] =
    (world.counters["dismounted_" .. (why or "somehow")] or 0) + 1
  return true
end
-- }}}

-- {{{ function M.rider_position(world, bodies, rider)
-- Where a carried body is: **derived**, never stored.
--
-- The mount's position, one layer up, offset along its facing. Deriving rather
-- than storing means the two can never drift apart, which is the failure mode of
-- every version of this that keeps two positions in step by updating both.
function M.rider_position(world, bodies, rider)
  local mount = bodies.partner[rider]
  if mount == 0 or bodies.alive[mount] == 0 then
    return bodies.x[rider], bodies.y[rider], bodies.z[rider]
  end

  local x, y, z = bodies.x[mount], bodies.y[mount], bodies.z[mount]
  local kind = Creatures.KINDS[bodies.kind[mount]]
  if kind.locomotion == Creatures.WALKING or kind.locomotion == Creatures.STRIDING then
    x, y, z = Walking.drawn_position(world.store, bodies, mount)
  end

  local d = Moving.DIRECTIONS[math.max(1, bodies.facing[mount])]
  return x - d[1] * 0.18, y - d[2] * 0.18, z + kind.body_height * 0.8
end
-- }}}

-- {{{ function M.pass_riding(world, dt)
-- Keeps a mounted pair a pair, and separates it when it must be separated.
--
-- The four ways down, and the last two are why riding is worth building at all:
-- the pair's height is the mount's plus one and its footprint is the mount's, so
-- there are places a dinosaur fits and a *ridden* dinosaur does not. Mounted, a
-- party is fast and strong and confined to the open places; dismounted it is
-- slow and fragile and can go anywhere. The maze already had both kinds of space
-- in it before anybody thought about riding.
function M.pass_riding(world, dt)
  local bodies = world.bodies

  for id = 1, bodies.capacity do
    if bodies.alive[id] == 1
       and bodies.locomotion[id] == Creatures.CARRIED then
      local mount = bodies.partner[id]

      if not BodyStore.is_valid(bodies, mount, bodies.partner_generation[id]) then
        -- The mount died, or its slot was recycled under it. The generation is
        -- what tells those apart from "the mount is fine".
        M.dismount(world, bodies, id, "the_mount_was_gone")
      else
        -- Ride along. The position is derived at draw time, so nothing is
        -- copied here -- only the stance, which the buckets and the meet pass
        -- read.
        bodies.cell[id]  = bodies.cell[mount]
        bodies.layer[id] = bodies.layer[mount]
        bodies.facing[id] = bodies.facing[mount]
        bodies.timer[id] = bodies.timer[id] + dt

        -- Down again after a while, so a party is not mounted for the whole run.
        if bodies.timer[id] > 22 then
          M.dismount(world, bodies, id, "on_purpose")
          bodies.timer[id] = 0
        end
      end
    end
  end

  -- Willingness recovers. A dinosaur that has just been hurt is not a mount, and
  -- "any human may climb any dinosaur at any time" produces a party that spends
  -- its time mounting and dismounting whenever two of them brush past.
  for id = 1, bodies.capacity do
    if bodies.alive[id] == 1 and bodies.willing[id] ~= nil then
      local kind = Creatures.KINDS[bodies.kind[id]]
      if kind.name == "dino" then
        if bodies.incoming_damage[id] > 0 then
          bodies.willing[id] = 0
          bodies.timer[id] = 0
        elseif bodies.willing[id] == 0 then
          bodies.timer[id] = bodies.timer[id] + dt
          if bodies.timer[id] > 8 then bodies.willing[id] = 1 end
        end
      end
    end
  end
end
-- }}}

-- ======================================================================
-- The monsters
-- ======================================================================

-- {{{ function M.pass_monsters(world, dt)
-- What the three of them do, and what undoes them.
function M.pass_monsters(world, dt)
  local bodies = world.bodies
  local width  = world.store.width

  for id = 1, bodies.capacity do
    if bodies.alive[id] == 1 then
      local kind = Creatures.KINDS[bodies.kind[id]]

      -- {{{ held still
      if bodies.held[id] > 0 then
        bodies.held[id] = bodies.held[id] - dt
        if bodies.held[id] <= 0 then
          bodies.held[id] = 0
          world.counters.releases = (world.counters.releases or 0) + 1
        end
      end
      -- }}}

      -- {{{ the golem breaks what is in its way
      if kind.breaks_stone and bodies.held[id] == 0 then
        -- Its own field, not the shared `timer`.
        --
        -- `timer` is the idle clock, and the riding pass uses it too. A golem
        -- counting its work on the same field as its idle counts nothing: the
        -- idle resets it before it ever reaches the threshold, and what shows up
        -- is a golem that never breaks a wall, with no error and nothing in any
        -- counter.
        bodies.work[id] = bodies.work[id] + dt
        if bodies.work[id] > kind.break_seconds then
          bodies.work[id] = 0
          M.break_a_wall(world, bodies, id, kind)
        end
      end
      -- }}}

      -- {{{ the automaton sets things alight
      if kind.ignites and bodies.held[id] == 0 then
        bodies.grace[id] = bodies.grace[id] + dt
        if bodies.grace[id] > kind.ignite_seconds then
          bodies.grace[id] = 0
          -- **Anything flammable near it, whatever side it is on.**
          --
          -- It is a machine. It does not check. Restricting it to the other side
          -- was the tidy thing to write and it quietly deleted the best
          -- behaviour in the mode: the automatons and the vines are both
          -- monsters, so nothing ever set a vine alight, and a wooden machine
          -- standing in a thicket it had ignited was no longer possible.
          --
          -- Not itself, though -- only what is beside it. It catches from the
          -- fire it started rather than from its own hand, which is both funnier
          -- and what actually happens.
          local x = bodies.cell[id] % width
          local y = math.floor(bodies.cell[id] / width)
          BodyStore.for_each_near(bodies, width, x, y, function(other)
            if other ~= id and bodies.alive[other] == 1 then
              if M.ignite(world, other, "an_automaton") then
                if Creatures.KINDS[bodies.kind[other]].name == "vine" then
                  world.counters.vines_lit = (world.counters.vines_lit or 0) + 1
                end
              end
            end
          end)
        end
      end
      -- }}}
    end
  end
end
-- }}}

-- {{{ function M.break_a_wall(world, bodies, id, kind)
-- A golem walks through what it cannot climb.
--
-- **The only thing in the project that changes the stone after generation**, and
-- the reason for two decisions made in phase one that cost nothing at the time:
-- the surface array is recomputed from the columns rather than assumed constant,
-- and nothing anywhere caches the surface graph as an adjacency list. A cached
-- graph would be a second copy of the maze to invalidate right here, and there is
-- no version of that which does not eventually disagree with the stone.
function M.break_a_wall(world, bodies, id, kind)
  local store = world.store
  local x = bodies.cell[id] % store.width
  local y = math.floor(bodies.cell[id] / store.width)
  local here = store.height[bodies.cell[id]]

  -- Whichever side of it is actually wall, preferring the way it is facing --
  -- and reaching **past its own footprint** to find one.
  --
  -- A three-by-three golem can never be adjacent to a wall: its footprint needs
  -- three by three of level floor, so its four neighbours are floor by
  -- construction and the nearest wall is always two cells away. Looking only at
  -- the neighbours meant every golem in the run was busy and the count of walls
  -- broken was zero, with nothing raised and nothing to see.
  --
  -- Reaching one cell past the footprint is also what lets it make its own
  -- space: it takes the wall down, its footprint then fits a cell further, and
  -- it advances into the notch it just made.
  local reach = math.floor(kind.radius) + 1
  local n, nx, ny = nil, nil, nil
  local order = { math.max(1, bodies.facing[id]), 1, 2, 3, 4 }
  for _, di in ipairs(order) do
    local d = Moving.DIRECTIONS[di]
    local cx, cy = x + d[1] * reach, y + d[2] * reach
    if Stone.in_bounds(store, cx, cy) then
      local c = Stone.index(store, cx, cy)
      -- Never the rim: it is the only thing between a body that has gone wrong
      -- and an array index that is not there, and a golem is exactly the body
      -- most likely to go wrong.
      if cx > 0 and cy > 0 and cx < store.width - 1 and cy < store.depth - 1
         and store.height[c] > here + Moving.CLIMB_LIMIT then
        n, nx, ny = c, cx, cy
        bodies.facing[id] = di
        break
      end
    end
  end

  if not n then return false end

  -- Take one layer off the top. A golem is not a demolition; it wears a notch
  -- through, one block at a time, which is what makes watching one worth doing.
  Stone.clear_stone(store, n, store.height[n])
  store.height[n] = store.height[n] - 1
  if store.height[n] <= here + Moving.CLIMB_LIMIT then
    store.walkable[n] = true
  end

  -- Surfaces for this column and its four neighbours, and nothing else. Five
  -- cells rather than a hundred thousand, because the surface expression is per
  -- column and the recompute takes a range.
  Stone.recompute_surfaces(store, n, n)
  for di = 1, 4 do
    local e = Moving.DIRECTIONS[di]
    local ex, ey = nx + e[1], ny + e[2]
    if Stone.in_bounds(store, ex, ey) then
      local c = Stone.index(store, ex, ey)
      Stone.recompute_surfaces(store, c, c)
    end
  end

  -- The version counter, which has existed since phase one and has never been
  -- bumped. Anything caching something derived from the stone compares it; the
  -- renderer's baked mesh is the first thing that will.
  store.version = store.version + 1
  world.counters.stone_broken = (world.counters.stone_broken or 0) + 1
  return true
end
-- }}}

-- {{{ function M.meets(world, bodies, a, b)
-- What happens when two of the delve's creatures meet.
--
-- **The damage is not here.** Two bodies of opposing sides that can hurt each
-- other start a duel, and the duel machinery -- which already existed, already
-- buffers, and already ends four ways -- does the exchanging. This function is
-- for the things that are *not* an exchange of blows: climbing onto a dinosaur,
-- being held by a vine, and being set alight.
--
-- That split is what the loose reading of "solve" turned out to mean. The
-- monsters are enemies with health, the cycle between them is a damage-type
-- chart in the creature table rather than a set of rules here, and what is left
-- in this function is three abilities rather than nine pairings.
function M.meets(world, bodies, a, b)
  local ka = Creatures.KINDS[bodies.kind[a]]
  local kb = Creatures.KINDS[bodies.kind[b]]

  -- A human and a willing dinosaur, before anything else -- a party that is
  -- busy fighting is a party that never gets mounted.
  if ka.mounts and kb.name == "dino" then
    if M.mount(world, bodies, a, b) then return true end
  elseif kb.mounts and ka.name == "dino" then
    if M.mount(world, bodies, b, a) then return true end
  end

  local opposed = ka.team ~= kb.team and ka.team ~= 0 and kb.team ~= 0

  if opposed then
    -- {{{ the abilities
    -- A vine holds what it reaches. Being held is the one thing that stops a
    -- fight rather than deciding it: a held body cannot swing, so a golem in the
    -- vines is a golem anybody can hit.
    local function hold(grabber, victim, gk)
      if gk.entangles and bodies.held[victim] == 0 then
        bodies.held[victim] = gk.hold_seconds
        world.counters.entangled = (world.counters.entangled or 0) + 1
        if Creatures.KINDS[bodies.kind[victim]].breaks_stone then
          world.counters.golems_held = (world.counters.golems_held or 0) + 1
        end
      end
    end
    hold(a, b, ka)
    hold(b, a, kb)

    -- Igniting is not here. An automaton sets alight whatever flammable thing
    -- is beside it, on any side, on its own cooldown -- see the monsters' pass.
    -- Putting it here as well would make it fire twice as often against the
    -- party and never at all against the vines, which are on its own side.
    -- }}}

    -- And then the fight, which is the ordinary duel.
    return world.modules.Duels.meets(world, bodies, a, b)
  end

  return false
end
-- }}}

return M
