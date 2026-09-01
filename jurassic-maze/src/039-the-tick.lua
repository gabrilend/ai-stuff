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

-- 039-the-tick.lua
--
-- A fixed sixtieth of a second, and the table of passes it walks.
--
-- Also where a world is assembled: the maze, the streams, the body store and the
-- locomotion table, put together in one place so that the window, the terminal
-- and the headless runner all get the same thing.

local M = {}

-- One tick is one sixtieth of a second of simulated time, always, regardless of
-- how fast the machine is or whether anybody is watching.
--
-- A simulation stepped by a variable timestep produces different results on a
-- fast machine than on a slow one, and for a rolling ball that is not a subtlety
-- -- the integration error in its velocity depends directly on the step size, so
-- a ball that clears a gap at sixty frames a second falls into it at thirty.
-- Every seed in every bug report would then mean something different on every
-- machine.
M.TICK = 1 / 60

-- The accumulator's ceiling, in seconds. If the window was dragged for two
-- seconds the loop does not try to catch up on a hundred and twenty ticks in one
-- frame -- it discards the excess and the simulation is simply behind. Trying to
-- catch up is the spiral of death: the catch-up takes longer than real time,
-- which produces more to catch up on.
M.MAX_CATCHUP = 0.25

-- {{{ local function require_local(root, name)
local function require_local(root, name)
  return dofile(root .. "/src/" .. name .. ".lua")
end
-- }}}

-- {{{ function M.new_world(root, params, scene)
-- The maze, the streams, the bodies, and the passes, assembled once.
function M.new_world(root, params, scene)
  local Params     = require_local(root, "028-maze-parameters")
  local Streams    = require_local(root, "029-random-streams")
  local Stone      = require_local(root, "030-the-stone")
  local Carve      = require_local(root, "031-carving")
  local Validator  = require_local(root, "032-the-validator")
  local Moving     = require_local(root, "033-moving")
  local BodyStore  = require_local(root, "034-the-body-store")
  local Locomotion = require_local(root, "036-locomotion")
  local Rolling    = require_local(root, "037-rolling")
  local Walking    = require_local(root, "038-walking")
  local Creatures  = dofile(root .. "/assets/035-creature-table.lua")

  local p = Params.check(params)
  local streams = Streams.make_set(p.seed)

  local store, report = Carve.generate(root, p, streams)
  Validator.validate(root, store, p, report)

  -- Where a body may be put down. Collected once: the spawn pass draws from this
  -- rather than picking random cells and rejecting the ones that are wall, which
  -- on a maze that is sixty percent stone means rejecting most of them.
  local floor = {}
  local by_height = {}
  for i = 0, store.cells - 1 do
    if store.walkable[i] then
      floor[#floor + 1] = i
      local h = store.height[i]
      by_height[h] = by_height[h] or {}
      local bucket = by_height[h]
      bucket[#bucket + 1] = i
    end
  end

  local highest = 0
  for h in pairs(by_height) do if h > highest then highest = h end end

  Rolling.link(Stone, Locomotion, Moving, Creatures)
  Walking.link(Stone, Locomotion, Moving, Creatures)

  local bodies = BodyStore.new(p.capacity, store.cells)
  bodies.CARRIED_ROW = Creatures.CARRIED

  local rows = Locomotion.new_table(Rolling, Walking)
  Locomotion.check_needs(rows, bodies)

  local world = {
    root      = root,
    params    = p,
    streams   = streams,
    store     = store,
    report    = report,
    bodies    = bodies,
    rows      = rows,
    creatures = Creatures,
    scene     = scene or "balls",
    tick_count = 0,
    floor     = floor,
    by_height = by_height,
    highest   = highest,

    modules = {
      Stone = Stone, Moving = Moving, BodyStore = BodyStore,
      Locomotion = Locomotion, Rolling = Rolling, Walking = Walking,
      Validator = Validator,
    },

    -- Counters the headless report reads. Accumulated by the passes themselves,
    -- so a number that stops moving is a pass that stopped running.
    counters = {
      spawned = 0, removed_at_rest = 0, spawn_skipped = 0,
      left_world = 0, largest_bucket = 0, inside_stone = 0,
    },
  }

  M.populate(world)
  return world
end
-- }}}

-- {{{ function M.spawn_one(world, kind_index)
-- Puts one body of a kind somewhere it can stand.
--
-- Balls are drawn toward the top of the maze, because a ball that begins at the
-- bottom has nowhere to roll and the whole point of it is the descent. Walkers
-- are drawn from anywhere, so a crowd is spread rather than all arriving in one
-- corner.
function M.spawn_one(world, kind_index)
  local Stone     = world.modules.Stone
  local BodyStore = world.modules.BodyStore
  local Locomotion = world.modules.Locomotion
  local kind  = world.creatures.KINDS[kind_index]
  local rng   = world.streams.spawn
  local store = world.store
  local bodies = world.bodies

  local cell
  if kind.locomotion == world.creatures.ROLLING then
    -- Somewhere in the upper third of the pile. Sampling a height first and a
    -- cell within it second, rather than sampling cells and rejecting the low
    -- ones, means the draw costs the same whatever shape the maze is.
    local floor_h = math.floor(world.highest * 0.62)
    local tries = 0
    repeat
      local h = rng:next_between(floor_h, world.highest)
      local bucket = world.by_height[h]
      if bucket and #bucket > 0 then cell = bucket[rng:next_below(#bucket)] end
      tries = tries + 1
    until cell or tries > 40
  end
  if not cell then
    cell = world.floor[rng:next_below(#world.floor)]
  end

  -- A spawn must not land on top of somebody. A cell that already holds a body
  -- is rejected and another drawn; running out of tries skips the spawn for this
  -- tick and counts it, because the population recovers next tick and a maze
  -- whose spawn points are all blocked should show up as a number rather than as
  -- an aquarium that slowly empties.
  if bodies.bucket_count[cell] and bodies.bucket_count[cell] > 0 then
    local retry = 0
    repeat
      cell = world.floor[rng:next_below(#world.floor)]
      retry = retry + 1
    until bodies.bucket_count[cell] == 0 or retry > 8
    if bodies.bucket_count[cell] > 0 then
      world.counters.spawn_skipped = world.counters.spawn_skipped + 1
      return nil
    end
  end

  local id = BodyStore.spawn(bodies)
  local x, y = Stone.coords(store, cell)
  local layer = store.height[cell]

  bodies.kind[id]        = kind_index
  bodies.cell[id]        = cell
  bodies.layer[id]       = layer
  bodies.x[id]           = x + 0.5
  bodies.y[id]           = y + 0.5
  bodies.z[id]           = Locomotion.surface_top(layer)
  bodies.radius[id]      = kind.radius
  bodies.body_height[id] = kind.body_height
  bodies.health[id]      = kind.health
  bodies.team[id]        = kind.team
  bodies.facing[id]      = rng:next_below(4)

  -- A ball starts with a nudge, drawn from the spawn stream. Dropping it exactly
  -- still means it sits in the middle of a flat corridor doing nothing until the
  -- rest timer takes it away, which is a very dull aquarium.
  if kind.locomotion == world.creatures.ROLLING then
    bodies.vx[id] = (rng:next_float() - 0.5) * 2.0
    bodies.vy[id] = (rng:next_float() - 0.5) * 2.0
  end

  BodyStore.set_locomotion(bodies, id, kind.locomotion)
  world.counters.spawned = world.counters.spawned + 1
  return id
end
-- }}}

-- {{{ function M.populate(world)
-- Brings the aquarium up to its target population.
function M.populate(world)
  local wanted = world.creatures.POPULATIONS[world.scene]
  if not wanted then
    error("no scene called '" .. tostring(world.scene) .. "' in the creature table")
  end

  world.targets = {}
  for name, count in pairs(wanted) do
    local index = world.creatures.by_name(name)
    world.targets[index] = count
  end

  for index, count in pairs(world.targets) do
    for _ = 1, count do M.spawn_one(world, index) end
  end
  world.modules.BodyStore.reindex(world.bodies)
end
-- }}}

-- {{{ local function pass_move(world, dt)
-- Every locomotion row advances its own roster.
--
-- The tick does not know how many kinds of motion there are, and no row can
-- affect another. That is the whole benefit of the table: a new creature that
-- moves in a new way is a new row and a new function, and there is nowhere to
-- put a change that would alter how anything else moves.
local function pass_move(world, dt)
  local bodies = world.bodies
  for index, row in ipairs(world.rows) do
    local roster = bodies.rosters[index]
    if roster and roster.n > 0 then
      row.advance(world, bodies, roster, 1, roster.n, dt)
    end
  end
end
-- }}}

-- {{{ local function pass_spawn(world, dt)
-- The aquarium tops itself up. There is no run that finishes.
local function pass_spawn(world, dt)
  local bodies = world.bodies
  local kinds  = world.creatures.KINDS
  local live_by_kind = {}

  for id = 1, bodies.capacity do
    if bodies.alive[id] == 1 then
      local k = bodies.kind[id]
      live_by_kind[k] = (live_by_kind[k] or 0) + 1

      local kind = kinds[k]
      if kind.rest_seconds and bodies.rest_timer[id] > kind.rest_seconds then
        world.modules.BodyStore.kill(bodies, id)
        live_by_kind[k] = live_by_kind[k] - 1
        world.counters.removed_at_rest = world.counters.removed_at_rest + 1
      end
    end
  end

  for index, target in pairs(world.targets) do
    local have = live_by_kind[index] or 0
    -- A few per tick rather than all at once, so that a mass removal does not
    -- produce a mass arrival in the same frame -- which looks like the maze
    -- blinking.
    local room = target - have
    if room > 6 then room = 6 end
    for _ = 1, room do M.spawn_one(world, index) end
  end
end
-- }}}

-- {{{ local function pass_index(world, dt)
local function pass_index(world, dt)
  world.modules.BodyStore.reindex(world.bodies)
  if world.bodies.largest_bucket > world.counters.largest_bucket then
    world.counters.largest_bucket = world.bodies.largest_bucket
  end
end
-- }}}

-- The passes, in order, as an array of rows rather than a function with a list
-- of calls in it.
--
-- Three things fall out of that, and the third is the reason: adding a pass is
-- adding a row; timing every pass is a loop around the walk rather than seven
-- pieces of timing code; and a pass can be removed without editing the tick --
-- the ball phase does not need `meet` or `resolve`, and leaving them out is
-- removing rows rather than threading a flag through a function.
--
-- `parallel` says whether two bodies processed at the same time could touch the
-- same memory. It is stated rather than inferred, because inferring it means
-- being silently wrong about it once, at which point the simulation stops being
-- deterministic and nobody knows when it started.
-- {{{ M.PASSES
M.PASSES = {
  { name = "move",  fn = pass_move,  parallel = true  },
  { name = "spawn", fn = pass_spawn, parallel = false },
  { name = "index", fn = pass_index, parallel = false },
}
-- }}}

-- {{{ function M.tick(world, measure)
-- One whole step. Takes no time argument: the step is always M.TICK.
function M.tick(world, measure)
  for _, pass in ipairs(M.PASSES) do
    if measure then
      local t0 = os.clock()
      pass.fn(world, M.TICK)
      measure[pass.name] = (measure[pass.name] or 0) + (os.clock() - t0)
    else
      pass.fn(world, M.TICK)
    end
  end
  world.tick_count = world.tick_count + 1
end
-- }}}

-- {{{ function M.advance(world, elapsed, measure)
-- Spends real elapsed time in whole ticks, and returns how many it ran.
--
-- The engine's variable frame time never reaches the simulation. This is the
-- only place the two meet.
function M.advance(world, elapsed, measure)
  world.leftover = (world.leftover or 0) + elapsed
  if world.leftover > M.MAX_CATCHUP then world.leftover = M.MAX_CATCHUP end

  local ran = 0
  while world.leftover >= M.TICK do
    M.tick(world, measure)
    world.leftover = world.leftover - M.TICK
    ran = ran + 1
  end
  return ran
end
-- }}}

return M
