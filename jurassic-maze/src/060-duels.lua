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

-- 060-duels.lua
--
-- A duel is a record with two bodies in it, and it ends.
--
-- A separate record rather than fields on each body, for one reason: a duel has
-- to end, and ending it has to be one action. Two bodies each holding "I am
-- fighting that one" can disagree -- one dies and the other is left swinging at
-- nothing -- and every version of fixing that is a check performed in two places
-- that must stay in step. One record with two references into it cannot get out
-- of step with itself.

local M = {}

local BodyStore, Walking, Creatures

-- {{{ function M.link(body_store, walking, creatures)
function M.link(body_store, walking, creatures)
  BodyStore, Walking, Creatures = body_store, walking, creatures
end
-- }}}

-- Why a duel ended, in the order the endings are checked. The director reads
-- these by name, so a new ending is a row here and a row in its verdict list.
M.KILLED     = "one of them fell"
M.MUTUAL     = "both of them fell"
M.STALEMATE  = "neither could land a blow"
M.DISSOLVED  = "one of them is no longer there"

-- {{{ function M.new_store(capacity)
-- Flat arrays with a free list, exactly like the body store.
--
-- A duel is an object with a lifetime, and making it a second store of the same
-- shape rather than a table of tables keeps the memory story uniform -- and
-- means the generation trick that catches a stale body id works here without
-- being invented twice.
function M.new_store(capacity)
  local store = { capacity = capacity, live = 0, free_top = 0, free = {} }
  for _, field in ipairs({ "alive", "a", "a_generation", "b", "b_generation",
                           "clock", "exchange", "turn", "ending",
                           "hurt_a", "hurt_b" }) do
    local array = {}
    for i = 1, capacity do array[i] = 0 end
    store[field] = array
  end
  for i = capacity, 1, -1 do
    store.free_top = store.free_top + 1
    store.free[store.free_top] = i
  end
  return store
end
-- }}}

-- {{{ function M.begin(world, a, b)
-- Two fencers of opposing sides have met.
function M.begin(world, a, b)
  local duels  = world.duels
  local bodies = world.bodies
  if duels.free_top == 0 then
    world.counters.duels_refused = (world.counters.duels_refused or 0) + 1
    return nil
  end

  local d = duels.free[duels.free_top]
  duels.free_top = duels.free_top - 1
  duels.live = duels.live + 1

  duels.alive[d] = 1
  duels.a[d], duels.a_generation[d] = a, bodies.generation[a]
  duels.b[d], duels.b_generation[d] = b, bodies.generation[b]
  duels.clock[d]    = 0
  duels.exchange[d] = 0
  duels.turn[d]     = 1
  duels.ending[d]   = 0
  duels.hurt_a[d]   = 0
  duels.hurt_b[d]   = 0

  -- Both fencers stand still and face each other. Their locomotion does not
  -- advance; the duel owns them. This is the simplest thing that reads as
  -- fencing from an isometric camera two hundred cells away, and real footwork
  -- would be a great deal of machinery for detail a handful of pixels tall.
  for _, id in ipairs({ a, b }) do
    bodies.duel[id]     = d
    bodies.intent[id]   = 0
    bodies.progress[id] = 0
    bodies.idle_row[id] = 0
  end

  local Stone = world.modules.Stone
  local ax, ay = Stone.coords(world.store, bodies.cell[a])
  local bx, by = Stone.coords(world.store, bodies.cell[b])
  if bx ~= ax then
    bodies.facing[a] = (bx > ax) and 1 or 2
    bodies.facing[b] = (bx > ax) and 2 or 1
  elseif by ~= ay then
    bodies.facing[a] = (by > ay) and 3 or 4
    bodies.facing[b] = (by > ay) and 4 or 3
  end

  world.counters.duels = (world.counters.duels or 0) + 1
  return d
end
-- }}}

-- {{{ local function release(world, d, id, flee)
local function release(world, d, id, flee)
  local bodies = world.bodies
  if id == 0 or bodies.alive[id] == 0 then return end
  if bodies.duel[id] ~= d then return end
  bodies.duel[id]   = 0
  bodies.intent[id] = 0
  bodies.progress[id] = 0
  if flee and flee > 0 then bodies.flee_timer[id] = flee end
end
-- }}}

-- {{{ function M.finish(world, d, ending)
-- One action, which is the whole reason a duel is a record.
function M.finish(world, d, ending)
  local duels = world.duels
  if duels.alive[d] == 0 then return end

  -- Each side keeps away for its own interval, which is zero for a fencer --
  -- they re-engage immediately and the fight rolls on.
  local function interval(id)
    if id == 0 or world.bodies.kind[id] == 0 then return 0 end
    return Creatures.KINDS[world.bodies.kind[id]].disengage_seconds or 0
  end

  duels.ending[d] = ending

  -- Who came off worse, for the camera. On a stalemate both are alive and this
  -- is the one that "stay with the loser" means; on a death the loser is not
  -- there to stay with, and the camera has to move whatever the setting says.
  local worse = (duels.hurt_a[d] > duels.hurt_b[d]) and duels.a[d] or duels.b[d]
  world.duel_loser[worse] = world.tick_count

  release(world, d, duels.a[d], interval(duels.a[d]))
  release(world, d, duels.b[d], interval(duels.b[d]))

  duels.alive[d] = 0
  duels.live = duels.live - 1
  duels.free_top = duels.free_top + 1
  duels.free[duels.free_top] = d

  world.counters["duels_" .. ending:gsub("%s", "_")] =
    (world.counters["duels_" .. ending:gsub("%s", "_")] or 0) + 1

  -- The director polls this. A field it reads rather than an event delivered to
  -- it: a queue of messages delivered at an unspecified time would make the
  -- order of effects depend on the order of subscription, which is the thing the
  -- whole tick design is arranged to avoid.
  world.duel_ended[duels.a[d]] = world.tick_count
  world.duel_ended[duels.b[d]] = world.tick_count
end
-- }}}

-- {{{ function M.pass(world, dt)
-- Every live duel, one tick. Buffers damage; applies none.
function M.pass(world, dt)
  local duels  = world.duels
  local bodies = world.bodies
  local rng    = world.streams.duel

  for d = 1, duels.capacity do
    if duels.alive[d] == 1 then
      local a, b = duels.a[d], duels.b[d]

      -- Either participant gone means the duel is gone. The generation is what
      -- makes this a real check: a plain id would still name a live body --
      -- whichever one moved into the recycled slot -- and the survivor would go
      -- on duelling a stranger who has never heard of it.
      if not BodyStore.is_valid(bodies, a, duels.a_generation[d])
         or not BodyStore.is_valid(bodies, b, duels.b_generation[d]) then
        M.finish(world, d, M.DISSOLVED)
      else
        duels.clock[d]    = duels.clock[d] + dt
        duels.exchange[d] = duels.exchange[d] + dt

        -- Each side's **own** numbers, not the first one's.
        --
        -- A duel between two fencers is symmetric and it did not matter; a duel
        -- between a human with a torch and a stone golem is not, and reading
        -- both sides' stats off whichever body happened to be stored first would
        -- give the golem a human's skill or the human a golem's damage,
        -- depending only on array order.
        local ka = Creatures.KINDS[bodies.kind[a]]
        local kb = Creatures.KINDS[bodies.kind[b]]

        -- The faster of the two sets the pace. A quick opponent does not get to
        -- be slowed down by a slow one.
        local pace = math.min(ka.exchange_seconds or 1, kb.exchange_seconds or 1)

        if duels.exchange[d] >= pace then
          duels.exchange[d] = 0
          duels.turn[d] = 3 - duels.turn[d]

          -- **Both of them strike, in the same exchange.**
          --
          -- Taking turns was written first and it makes the buffering below
          -- decorative: if only one blow is thrown at a time, two fencers can
          -- never kill each other in one tick, and the case the whole
          -- arrangement exists for cannot arise. It also reads worse -- a clash
          -- is two people swinging, not two people politely alternating.
          for _, side in ipairs({ { a, b, ka, kb }, { b, a, kb, ka } }) do
            local attacker, defender = side[1], side[2]
            local ak, dk = side[3], side[4]

            -- A held body cannot swing. Being entangled is the one thing that
            -- stops a fight rather than deciding it.
            if bodies.held[attacker] == 0 and (ak.damage or 0) > 0 then
              local attack = (ak.skill or 0.5) + rng:next_float() * (ak.swing or 0.5)
              local guard  = (dk.parry or 0.4) + rng:next_float() * (dk.swing or 0.5)
              if attack > guard then
                -- The damage-type chart. Fire ruins a vine and does nothing at
                -- all to stone; a stone fist ruins a wooden machine. A monster's
                -- row says what it shrugs off, and the numbers are all in one
                -- table rather than distributed through nine rules that have to
                -- agree with each other.
                local how_much = ak.damage or 0
                local kills = dk.resist and dk.resist[ak.weapon or "blade"]
                if kills then how_much = how_much * kills end

                -- **Buffered, not applied.** Two fighters who strike each other
                -- fatally in the same tick must both die. Applying immediately
                -- means whichever body was stored first kills the other and
                -- survives, and the outcome is decided by an array index --
                -- which changes whenever any unrelated body dies and its slot is
                -- recycled.
                bodies.incoming_damage[defender] =
                  bodies.incoming_damage[defender] + how_much
                if defender == a then duels.hurt_a[d] = duels.hurt_a[d] + how_much
                else duels.hurt_b[d] = duels.hurt_b[d] + how_much end
                world.counters.blows_landed = (world.counters.blows_landed or 0) + 1
              else
                world.counters.blows_parried = (world.counters.blows_parried or 0) + 1
              end
            end
          end
        end

        -- Two evenly matched fencers with a high parry will otherwise stand in a
        -- corridor exchanging misses until the machine is turned off -- and a
        -- camera watching them under "swap on its own" has nothing to swap to,
        -- because the duel never ends and the verdict never fires. A rule about
        -- combat, added for a reason about watching.
        if duels.clock[d] > math.max(ka.stalemate_seconds or 20,
                                     kb.stalemate_seconds or 20) then
          M.finish(world, d, M.STALEMATE)
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.resolve(world, dt)
-- Damage applied, deaths carried out, in one place, for everybody.
--
-- Deaths are detected and carried out in the same pass, before anything reads
-- the bodies again. A body that is dead for part of a tick and alive for the
-- rest is a body two passes disagree about.
function M.resolve(world, dt)
  local bodies = world.bodies
  local duels  = world.duels

  local died = {}
  for id = 1, bodies.capacity do
    if bodies.alive[id] == 1 and bodies.incoming_damage[id] > 0 then
      bodies.health[id] = bodies.health[id] - bodies.incoming_damage[id]
      bodies.incoming_damage[id] = 0
      if bodies.health[id] <= 0 then died[#died + 1] = id end
    end
    if bodies.alive[id] == 1 and bodies.flee_timer[id] > 0 then
      bodies.flee_timer[id] = bodies.flee_timer[id] - dt
    end
  end

  if #died == 0 then return end

  -- Which duels lost somebody, and whether they lost both. Both dying in one
  -- tick is the case buffering exists to make possible.
  local losses = {}
  for _, id in ipairs(died) do
    local d = bodies.duel[id]
    if d ~= 0 and duels.alive[d] == 1 then
      losses[d] = (losses[d] or 0) + 1
    end
  end

  for _, id in ipairs(died) do
    local d = bodies.duel[id]
    if d ~= 0 and duels.alive[d] == 1 then
      -- The loser is recorded before the duel is dissolved, so the camera's
      -- "stay with the loser" has somebody to stay with.
      local survivor = (duels.a[d] == id) and duels.b[d] or duels.a[d]
      world.duel_survivor[d] = survivor
      M.finish(world, d, (losses[d] > 1) and M.MUTUAL or M.KILLED)
    end
    BodyStore.kill(bodies, id)
    world.counters.deaths = (world.counters.deaths or 0) + 1
  end
end
-- }}}

-- {{{ function M.meets(world, bodies, a, b)
-- **Any two bodies of opposing sides that can hurt each other.**
--
-- It was two fencers. Generalising it is what turned the delve from a puzzle
-- into a fight: a human with a torch against a vine, a dinosaur with a hammer
-- against a wooden machine, and a golem against anything -- all of them are two
-- bodies exchanging blows and buffering the damage, which is a thing that
-- already existed and worked.
--
-- The only requirement is that at least one of them can do damage. A body that
-- cannot is not in a fight, it is being attacked, and that is the monsters'
-- pass rather than this one.
function M.meets(world, bodies, a, b)
  if bodies.duel[a] ~= 0 or bodies.duel[b] ~= 0 then return false end
  if bodies.team[a] == 0 or bodies.team[b] == 0 then return false end
  if bodies.team[a] == bodies.team[b] then return false end

  local ka = Creatures.KINDS[bodies.kind[a]]
  local kb = Creatures.KINDS[bodies.kind[b]]
  if (ka.damage or 0) <= 0 and (kb.damage or 0) <= 0 then return false end

  -- Just released from a duel, and told to keep away for a moment.
  --
  -- `disengage_seconds` is written as a knob and not a constant on purpose:
  -- setting it to zero makes a released fencer find another opponent
  -- immediately, which is a melee rather than a series of duels -- and which is
  -- the other reading of open question 1. Both readings are one number apart.
  if bodies.flee_timer[a] > 0 or bodies.flee_timer[b] > 0 then return false end

  M.begin(world, a, b)
  return true
end
-- }}}

return M
