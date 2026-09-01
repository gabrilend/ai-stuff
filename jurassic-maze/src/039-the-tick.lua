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

-- {{{ local function widen_the_jit()
-- Raises LuaJIT's trace and machine-code limits.
--
-- This is not a micro-optimisation and it is not tuning. With the defaults --
-- a thousand traces and half a megabyte of machine code -- a run with **two**
-- locomotion rows live fills the trace cache and flushes it, over and over:
-- forty-five flushes in three hundred ticks, twenty-two thousand traces
-- compiled, and every flush throws away everything that had been compiled so
-- far.
--
-- What that looks like from outside is bizarre. Balls alone cost 1.8 seconds a
-- minute and walkers alone cost 1.0, and the two of them together cost 12.4 --
-- each row four times slower purely for the other one existing. It reads as a
-- scaling problem in the simulation, and there is nothing in the simulation to
-- find.
--
-- Done once, at world creation, because that is the single path every runner
-- goes through -- the window, the terminal, the headless sweep and the tests.
local function widen_the_jit()
  if not jit then return end
  pcall(function()
    jit.opt.start("maxtrace=4000", "maxmcode=4096", "maxsnap=1000")
  end)
end
-- }}}

-- {{{ function M.new_world(root, params, scene, population)
-- The maze, the streams, the bodies, and the passes, assembled once.
function M.new_world(root, params, scene, population)
  widen_the_jit()

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
  local Meeting    = require_local(root, "058-meeting")
  local Duels      = require_local(root, "060-duels")
  local Sight      = require_local(root, "062-sight")
  local Games      = require_local(root, "063-games")
  local Delve      = require_local(root, "065-the-delve")
  local Creatures  = dofile(root .. "/assets/035-creature-table.lua")

  local p = Params.check(params)
  local streams = Streams.make_set(p.seed)

  -- Two ways a world comes into being, and they share nothing but their result.
  --
  -- The generator makes a maze out of rooms, walls and a room lattice. A map is
  -- a file somebody typed, made of flat plates and the stairs between them, and
  -- it has no walls in it at all -- so the maze validator, whose every check is
  -- about generator invariants, has nothing to say about one. It would in fact
  -- refuse every map outright: it insists the rim of the world is wall, and in a
  -- map every surface is walkable because every surface is the top of something.
  local store, report
  if p.map ~= "" then
    local Map = require_local(root, "069-the-map")
    local field = Map.load(dofile(root .. "/assets/" .. p.map .. ".lua"))
    store = Map.to_store(Stone, field, p.layers)
    store.field = field
    -- The counts a map can honestly answer. Every cell of a map is a surface
    -- and every surface is walkable, so floor and cells are the same number --
    -- which is the whole difference between this world and a carved one, stated
    -- as an equality rather than as a paragraph.
    local stone_layers = 0
    for i = 0, store.cells - 1 do stone_layers = stone_layers + field.height[i] + 1 end
    report = {
      seed = p.seed, width = store.width, depth = store.depth,
      layers = store.layers, map = field.name,
      floor_cells = store.cells, surfaces = store.cells,
      lowest = field.lowest, highest = field.highest,
      plates = #field.plates, staircases = #field.stairs,
      fill_fraction = stone_layers / (store.cells * store.layers),
    }
  else
    store, report = Carve.generate(root, p, streams)
    Validator.validate(root, store, p, report)
  end

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

  -- Floor cells bucketed into coarse blocks, so that "somewhere near here" is a
  -- draw rather than a search.
  --
  -- An errand to a cell drawn from the whole maze is a three-hundred-step
  -- journey costing five milliseconds to plan, and at any real population that
  -- is most of the tick. It is also the wrong journey: a two-minute trek across
  -- the maze is not something anybody watches, and the camera's whole interest
  -- is in a thing that starts and finishes.
  local BLOCK = 16
  local blocks_x = math.ceil(store.width / BLOCK)
  local blocks_y = math.ceil(store.depth / BLOCK)
  local blocks = {}
  for i = 0, store.cells - 1 do
    if store.walkable[i] then
      local x = i % store.width
      local y = (i - x) / store.width
      local b = math.floor(x / BLOCK) + math.floor(y / BLOCK) * blocks_x
      blocks[b] = blocks[b] or {}
      local list = blocks[b]
      list[#list + 1] = i
    end
  end

  -- How wide the widest creature is, in cells. Decides how many bucket
  -- placements the index has to hold, and whether the footprint path is used at
  -- all -- a run with nothing wide in it should not pay for the machinery.
  local widest = 1
  for _, kind in ipairs(Creatures.KINDS) do
    local cells_across = math.floor(kind.radius) * 2 + 1
    if cells_across > widest then widest = cells_across end
  end

  -- Where a body wider than one cell can stand at all.
  --
  -- A three-by-three animal fits in the plazas and essentially nowhere else, so
  -- drawing its destinations from the floor at large means most of them are
  -- unreachable -- and a search that fails leaves the body with nothing decided,
  -- so it asks again next tick, and again. Ninety dinosaurs produced ninety-seven
  -- thousand failed searches a minute doing exactly that.
  --
  -- Computed once, here, from the same footprint rule the movement uses.
  local wide_floor, wide_blocks = {}, {}
  if widest > 1 then
    local reach = math.floor(widest / 2)
    for i = 0, store.cells - 1 do
      if store.walkable[i] then
        local x = i % store.width
        local y = (i - x) / store.width
        local level = store.height[i]
        local fits = true
        for dy = -reach, reach do
          for dx = -reach, reach do
            local nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or nx >= store.width or ny >= store.depth
               or store.height[nx + ny * store.width] ~= level then
              fits = false
            end
          end
        end
        if fits then
          wide_floor[#wide_floor + 1] = i
          local b = math.floor(x / BLOCK) + math.floor(y / BLOCK) * blocks_x
          wide_blocks[b] = wide_blocks[b] or {}
          local list = wide_blocks[b]
          list[#list + 1] = i
        end
      end
    end
  end

  -- And which of those places are reachable from which.
  --
  -- The plazas a three-by-three body can stand in are mostly **not connected to
  -- each other** -- the corridors between them are one cell wide. That is the
  -- right answer, and it is the most interesting thing about a wide body sharing
  -- a maze with a narrow one, but it means a destination drawn from the wide
  -- floor at large is usually in a plaza this animal can never reach. Fifty-eight
  -- thousand failed searches a minute were exactly that.
  --
  -- So the wide floor is labelled into pieces, and a wide body draws only from
  -- its own. The count of pieces is a real statistic about a habitat: it is how
  -- many separate enclosures the maze has, without anybody having drawn one.
  local wide_label, wide_pieces = {}, {}
  if #wide_floor > 0 then
    local in_wide = {}
    for _, cell in ipairs(wide_floor) do in_wide[cell] = true end

    local next_label = 0
    for _, seed_cell in ipairs(wide_floor) do
      if not wide_label[seed_cell] then
        next_label = next_label + 1
        local piece = {}
        wide_pieces[next_label] = piece
        wide_label[seed_cell] = next_label

        local stack, top = { seed_cell }, 1
        while top > 0 do
          local cell = stack[top]
          top = top - 1
          piece[#piece + 1] = cell

          local x = cell % store.width
          local y = (cell - x) / store.width
          for di = 1, 4 do
            local d = Moving.DIRECTIONS[di]
            local nx, ny = x + d[1], y + d[2]
            if nx >= 0 and ny >= 0 and nx < store.width and ny < store.depth then
              local n = nx + ny * store.width
              if in_wide[n] and not wide_label[n]
                 and math.abs(store.height[n] - store.height[cell]) <= Moving.CLIMB_LIMIT then
                wide_label[n] = next_label
                top = top + 1
                stack[top] = n
              end
            end
          end
        end
      end
    end
  end

  Rolling.link(Stone, Locomotion, Moving, Creatures)
  Walking.link(Stone, Locomotion, Moving, Creatures)
  Meeting.link(Stone, BodyStore, Walking, Creatures)
  Duels.link(BodyStore, Walking, Creatures)
  Sight.link(Stone, Moving, Creatures)
  Games.link(Stone, Moving, Sight, Walking, BodyStore, Creatures)
  Delve.link(Stone, Moving, Walking, BodyStore, Locomotion, Creatures, Sight)

  local bodies = BodyStore.new(p.capacity, store.cells, widest)
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
    scene      = scene or "balls",
    widest     = widest,
    -- An override for how many of each kind to keep alive, by creature name.
    --
    -- The tests use it. Shrinking the *maze* instead was tried and made them
    -- slower rather than faster: the same population in a quarter of the floor
    -- is four times the density, and density is what the meet pass costs.
    population = population,
    tick_count = 0,
    floor       = floor,
    by_height   = by_height,
    highest     = highest,
    floor_blocks = blocks,
    wide_floor   = wide_floor,
    wide_blocks  = wide_blocks,
    wide_label   = wide_label,
    wide_pieces  = wide_pieces,
    block_size  = BLOCK,
    blocks_x    = blocks_x,
    blocks_y    = blocks_y,

    meet  = Meeting.new_table(Creatures),
    duels = Duels.new_store(math.max(64, math.floor(p.capacity / 2))),
    games = Games.new_store(math.max(32, math.floor(p.capacity / 4))),
    trail = {},

    -- Polled by the director rather than delivered to it. A queue of messages
    -- arriving at an unspecified time would make the order of effects depend on
    -- the order of subscription, which is what the whole tick design avoids.
    duel_ended    = {},
    duel_survivor = {},
    duel_loser    = {},

    -- One stored path per body, plus where along it the body is and when it last
    -- arrived. Kept beside the store rather than in it because a path is a list
    -- and the store is flat arrays -- and a list per body is the one thing the
    -- store's whole shape is arranged to avoid.
    paths        = {},
    path_length  = {},
    path_at      = {},
    arrived      = {},
    errand_cell  = {},
    errand_layer = {},
    replanned    = {},
    -- Which cells are claimed, and until when. Stamped with an expiry tick rather
    -- than cleared: clearing sixteen thousand entries every tick to record a few
    -- dozen claims is most of the cost of having them, and a stale stamp simply
    -- reads as expired.
    taken        = {},
    claim_ticks  = 30,

    modules = {
      Stone = Stone, Moving = Moving, BodyStore = BodyStore,
      Locomotion = Locomotion, Rolling = Rolling, Walking = Walking,
      Validator = Validator, Meeting = Meeting, Duels = Duels,
      Sight = Sight, Games = Games, Delve = Delve,
    },

    -- Counters the headless report reads. Accumulated by the passes themselves,
    -- so a number that stops moving is a pass that stopped running.
    counters = {
      spawned = 0, removed_at_rest = 0, spawn_skipped = 0,
      left_world = 0, largest_bucket = 0, inside_stone = 0,
    },
  }

  M.populate(world)

  -- Is anything in this run actually wider than a cell? If not, the index takes
  -- the plain path and never calls the footprint function at all.
  world.has_wide = false
  for index in pairs(world.targets) do
    if Creatures.KINDS[index].radius >= 1 then world.has_wide = true end
  end

  local pieces = 0
  for _ in pairs(wide_pieces) do pieces = pieces + 1 end
  report.wide_floor_cells  = #wide_floor
  report.wide_floor_pieces = pieces

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

  -- A body wider than one cell must be put down somewhere its whole footprint
  -- fits. Without the check, most of a herd of dinosaurs spawns into a corridor
  -- and never moves again -- which looks exactly like a broken locomotion row
  -- and is nothing of the kind.
  if kind.radius >= 1 then
    if #world.wide_floor == 0 then
      error("nothing wider than one cell can stand anywhere in this maze -- " ..
            "raise plaza_count, or the creature is too big for the corridors")
    end
    cell = world.wide_floor[rng:next_below(#world.wide_floor)]
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
  bodies.willing[id]     = 1

  -- A side, for the kinds that have one. Drawn rather than alternated, so that a
  -- run does not depend on the order the aquarium happened to top itself up.
  if kind.team_count and kind.team_count > 1 then
    bodies.team[id] = rng:next_below(kind.team_count)
  end

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
  local wanted = world.population or world.creatures.POPULATIONS[world.scene]
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
local function pass_move(world, dt, measure)
  local bodies = world.bodies
  for index, row in ipairs(world.rows) do
    local roster = bodies.rosters[index]
    if roster and roster.n > 0 then
      if measure then
        -- Per row, not just per pass. A move pass that costs five times the sum
        -- of its rows measured separately is a row being made expensive by the
        -- presence of another, and a single total cannot say which.
        local t0 = os.clock()
        row.advance(world, bodies, roster, 1, roster.n, dt)
        local key = "move:" .. row.name
        measure[key] = (measure[key] or 0) + (os.clock() - t0)
      else
        row.advance(world, bodies, roster, 1, roster.n, dt)
      end
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
local FOOTPRINT = {}
local function pass_index(world, dt)
  -- A body wider than one cell goes in every bucket its footprint covers. A
  -- three-cell animal in one bucket is invisible to anything standing beside its
  -- tail, and the meet pass's greater-id rule already handles the duplicate
  -- pairs that follow.
  --
  -- The scratch array is shared and reused: this runs once per body per tick and
  -- a fresh table each time is an allocation for a list of nine integers.
  local Walking = world.modules.Walking
  local store   = world.store
  local bodies  = world.bodies

  world.modules.BodyStore.reindex(world.bodies, world.has_wide and function(_, id)
    if bodies.radius[id] < 1 then
      FOOTPRINT[1] = bodies.cell[id]
      FOOTPRINT.n = 1
      return FOOTPRINT
    end
    return Walking.footprint(store, bodies, id, FOOTPRINT)
  end or nil)
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
  { name = "move",  fn = pass_move,  parallel = true, measures = true },
  -- The one pass that is not independent per body, and therefore the one that
  -- does not get split. It is also one of the cheapest, which is by design
  -- rather than by luck: a pass that has to touch shared state was kept small
  -- precisely so that it could be the one that does not scale.
  { name = "meet",  fn = function(world, dt) world.modules.Meeting.pass(world, dt) end,
    parallel = false },
  -- Duels exchange blows and buffer the damage; nothing is applied until
  -- `resolve`, which is what lets two fencers kill each other in the same tick
  -- instead of the outcome being decided by an array index.
  { name = "duel",    fn = function(world, dt) world.modules.Duels.pass(world, dt) end,
    parallel = false },
  { name = "resolve", fn = function(world, dt) world.modules.Duels.resolve(world, dt) end,
    parallel = false },
  -- Games hold their participants' clocks and swap their roles. Not
  -- parallel-safe for the same reason the meet pass is not: one game touches
  -- several bodies.
  { name = "games",   fn = function(world, dt) world.modules.Games.pass(world, dt) end,
    parallel = false },
  -- The delve's three: fire that spreads, riding, and what the monsters do.
  --
  -- They run **always**, and each early-outs per body on a field that is zero
  -- for anything they do not concern.
  --
  -- They were gated on a flag derived from the scene's population, which is the
  -- obvious reading of "a mode is which tables are loaded" and is wrong in a way
  -- that is entirely silent: a body placed by any route other than the scene's
  -- population -- a test, a scenario, anything later -- gets a world where fire
  -- does not burn and riders do not ride, with no error and no clue. Four
  -- assertions failed on it and every one of them looked like a bug in the thing
  -- being asserted.
  --
  -- The gate was also not worth having. Three sweeps of a body store at the
  -- default capacity is a few tens of microseconds a tick, which is a tenth of a
  -- percent of a frame. The mode is still which creature kinds spawn and which
  -- meet-table entries exist; it is not which passes run.
  { name = "burn",    fn = function(world, dt) world.modules.Delve.burn(world, dt) end,
    parallel = false },
  { name = "riding",  fn = function(world, dt) world.modules.Delve.pass_riding(world, dt) end,
    parallel = false },
  { name = "monsters", fn = function(world, dt) world.modules.Delve.pass_monsters(world, dt) end,
    parallel = false },
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
      pass.fn(world, M.TICK, pass.measures and measure or nil)
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
