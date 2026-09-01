-- hero-less-moba — a lane-pushing game with the heroes subtracted out
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

-- 068-the-arena.lua
--
-- A small straight square of ground, and a world with only the machinery a test asked for.

-- A small straight square of ground, and a world with only the machinery a test asked
-- for.
--
-- ## Why there is a second map builder
--
-- The real map is a square field with two libraries on opposite corners, three lanes
-- that bend, eighteen towers and a junction where a body has a choice to make. Every
-- one of those is load-bearing and every one of them is *also* present when you are
-- trying to find out why one soldier will not walk round another.
--
-- A question about one rule should be asked somewhere that contains one rule. So this
-- builds the smallest thing the rest of the simulation will accept as a map: one
-- straight lane running left to right, no bend, no stone, no junction, nothing to
-- capture and nowhere else to go.
--
-- **Straight on purpose.** A lane's curve is a real part of how a formation works and
-- has its own instrument in the formation sandbox. A test about stepping round an
-- obstacle that also happens to be cornering has two candidates when it fails, and
-- the whole point of a small arena is to have one.
--
-- ## And a second assembly
--
-- The tick's own assembly hangs all twenty-five modules on the world and starts the
-- wave clock, the phase clock, the chest deck and both bots. A test that wants
-- walking gets all of that too, and then has to hope none of it moved while it was
-- looking elsewhere.
--
-- Here a test names what it needs and gets exactly that. **What it did not ask for is
-- absent rather than idle** -- so a test that reaches for the wave spawner fails at
-- the reach, loudly, instead of quietly being influenced by a spawner it forgot was
-- running. That is the difference between an instrument and a smaller version of the
-- game.

local M = {}

-- How far apart the arena's path nodes sit, in paces. Closer together than the real
-- map's, because the arena is short and a body's position along a lane is interpolated
-- between two nodes -- a coarse path on a short lane is a visibly polygonal walk.
local NODE_SPACING = 20

-- The kinds a node can be, matching the real map builder's numbering so that anything
-- reading a node cannot tell which builder made it.
local NODE_PLAIN = 1
local NODE_JUNCTION = 3

-- {{{ local function add_node()
-- One node, with every field present. Same shape as the real builder's, and for the
-- same reason: the movement loop skips nil checks entirely, so a node that came into
-- being missing a field is a crash a long way from here.
local function add_node(map, x, y, kind, lane, milestone)
  local id = #map.node + 1
  map.node[id] = {
    id        = id,
    x         = x,
    y         = y,
    kind      = kind,
    lane      = lane,
    milestone = milestone,
    -- Which half of the arena this is in. Left is team 1's, right is team 2's, which
    -- is the only sense in which the arena has sides at all.
    team      = (x < map.bounds.min_x + (map.bounds.max_x - map.bounds.min_x) * 0.5)
                and 1 or 2,
    neighbour = {},
    structure = 0,
  }
  return id
end
-- }}}

-- {{{ function M.build()
-- The arena's map: one straight lane, left to right.
--
-- `options` may carry `length` and `width` in paces and `files` -- how many bodies
-- walk abreast. Everything else is taken from the ordinary match parameters, so that
-- a body walking here is walking under the same numbers it walks under in a match.
function M.build(parameters, options)
  options = options or {}
  local length = options.length or 900
  local width  = options.width or 132
  local files  = options.files or 3

  -- A margin around the ground so the camera has somewhere to sit and a body stepping
  -- aside has somewhere to step. Generous: the whole question this arena exists for is
  -- what a body does when it runs out of room in front of it, and an arena that runs
  -- out of room at the edges would be answering a different one.
  local margin = width

  local map = {
    node = {}, lane = {}, site = {}, connector = {},
    bounds = {
      min_x = 0, min_y = 0,
      max_x = length + margin * 2,
      max_y = width + margin * 2,
    },
  }

  local mid_y = map.bounds.max_y * 0.5
  local left_x = margin
  local right_x = margin + length

  local lane = {
    id             = 1,
    path           = {},
    milestone_node = {},
    junction       = {},
    length         = 0,
    width          = width,
    files          = files,
  }

  -- The milestone count is the real one, because everything downstream -- push depth,
  -- waypoints, zones, a wave knowing which zone it is in -- counts in milestones and
  -- would need a special case for an arena that had a different number of them. The
  -- arena is short, so its milestones are simply close together.
  local milestones = parameters.shape.milestone_count
  local last = milestones - 1

  -- Every milestone's position, evenly spaced along the straight. Milestone 0 is the
  -- left end and stands in for team 1's library; the last is the right end and stands
  -- in for team 2's.
  local milestone_x = {}
  for m = 0, last do
    milestone_x[m] = left_x + (right_x - left_x) * (m / last)
  end

  -- The path, walked from the left end to the right, filling plain nodes between each
  -- pair of milestones. Ordered left to right, which is the direction every "which way
  -- am I facing" question in the game is asked in.
  for m = 0, last do
    -- Milestone 4 is the junction on a real lane -- the one node where a body has a
    -- choice. There is nowhere else to go here, and it is still marked as one so that
    -- anything looking for the middle of a lane finds it where it expects to.
    local kind = (m == 4) and NODE_JUNCTION or NODE_PLAIN
    local node = add_node(map, milestone_x[m], mid_y, kind, 1, m)
    lane.milestone_node[m] = node

    if m == 0 then
      lane.path[1] = node
    else
      -- Fill between the previous milestone and this one. The plain nodes are placed
      -- first and the milestone last, so the milestone lands exactly on its own
      -- position rather than wherever the spacing happened to reach.
      local from = milestone_x[m - 1]
      local gap = milestone_x[m] - from
      local steps = math.max(1, math.floor(gap / NODE_SPACING + 0.5))
      for step = 1, steps - 1 do
        lane.path[#lane.path + 1] =
          add_node(map, from + gap * (step / steps), mid_y, NODE_PLAIN, 1, 0)
      end
      lane.path[#lane.path + 1] = node
    end
  end

  lane.junction[1] = lane.milestone_node[4]

  lane.path_index = {}
  for index, node_id in ipairs(lane.path) do
    if lane.path_index[node_id] == nil then
      lane.path_index[node_id] = index
    end
  end

  -- How long each step is, and how far along the lane each node sits. Precomputed
  -- exactly as the real builder does it, because the move pass divides speed by edge
  -- length once per body per tick and a body's position is one number: how far down
  -- the lane it is.
  lane.step_length = {}
  lane.cumulative = {}
  local total = 0
  lane.cumulative[1] = 0
  for index = 1, #lane.path - 1 do
    local a = map.node[lane.path[index]]
    local b = map.node[lane.path[index + 1]]
    local step = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
    lane.step_length[index] = step
    total = total + step
    lane.cumulative[index + 1] = total
  end
  lane.length = total

  lane.milestone_index = {}
  for m = 0, last do
    lane.milestone_index[m] = lane.path_index[lane.milestone_node[m]]
  end

  -- The zones: the same lane measured more finely, so that push and waypoints have
  -- somewhere to sit. Two arrays holding the same numbers, kept separate here for the
  -- same reason they are separate on a real lane.
  local divisions = parameters.shape.zone_divisions
  lane.zone_count = last * divisions
  lane.zone = {}
  lane.waypoint_zone = {}
  for m = 0, last - 1 do
    local from = lane.cumulative[lane.milestone_index[m]]
    local to   = lane.cumulative[lane.milestone_index[m + 1]]
    for d = 0, divisions - 1 do
      local at = from + (to - from) * (d / divisions)
      lane.zone[m * divisions + d] = at
      lane.waypoint_zone[m * divisions + d] = at
    end
  end
  lane.zone[lane.zone_count] = lane.length
  lane.waypoint_zone[lane.zone_count] = lane.length

  -- Neighbours, so that anything walking the graph rather than the lane can.
  for index = 1, #lane.path - 1 do
    local a = map.node[lane.path[index]]
    local b = map.node[lane.path[index + 1]]
    a.neighbour[#a.neighbour + 1] = b.id
    b.neighbour[#b.neighbour + 1] = a.id
  end

  map.lane[1] = lane
  return map
end
-- }}}

-- {{{ function M.parameters()
-- The ordinary match parameters with the arena's shape laid over them.
--
-- Layered with a metatable rather than copied, so that a number nobody thought about
-- is the same number the game uses. A test arena whose catalogue had drifted from the
-- real one would be an instrument that measures a different game.
function M.parameters(base, options)
  options = options or {}
  local shape = setmetatable({
    lane_count  = 1,
    lane_width  = {[1] = options.width or 132},
    lane_files  = {[1] = options.files or 3},
  }, {__index = base.shape})
  return setmetatable({shape = shape, lane_count = 1}, {__index = base})
end
-- }}}

-- {{{ function M.assemble()
-- A world with the arena under it and only the named modules hung on it.
--
-- `want` is a list of module names as they appear in the tick's cast -- "walking",
-- "formations", and so on. Everything named is hung on the world and started; nothing
-- else is, and reaching for it later is an error rather than a surprise.
--
-- A handful are not optional and are hung whichever list is passed: the world's own
-- allocate and release, the event channel, and the spatial grid -- because a body
-- cannot come into being without them and no test is about their absence.
function M.assemble(modules, base_parameters, want, options)
  local parameters = M.parameters(base_parameters, options)
  local map = M.build(parameters, options)
  local stream = modules.random_streams.make_set(parameters.seed)
  local world = modules.world.create(parameters, map, stream)

  world.allocate    = modules.world.allocate
  world.release     = modules.world.release
  world.begin_decay = modules.world.begin_decay
  world.revive      = modules.world.revive
  world.raise       = modules.world.raise
  world.give_body   = modules.world.give_body
  world.random_streams = modules.random_streams
  -- The map builder is hung whatever a test asked for, because it is not a system --
  -- it is the geometry, and "where on the lane is this distance" is a question the
  -- movement code asks of it on every single step. A test that had to name it would be
  -- naming arithmetic.
  world.map_builder = modules.map_builder

  -- Who is swinging at me. An array the world always has, whether or not anything
  -- present is going to write to it.
  world.attacker_of = {}
  for id = 1, modules.world.SOLDIER_CAPACITY do
    world.attacker_of[id] = 0
  end

  world.command_queue = {}

  -- **Nobody in the arena has won anything.** The boons a team has collected are a
  -- world-level list that the phase clock fills in and that every body reads on the
  -- way into existence, so an arena without a phase clock still has to say what a
  -- team holds. It says: nothing. Two empty lists.
  --
  -- Written here rather than borrowed by hanging the phase module, because hanging the
  -- phase module would also start the phase clock, and a movement test that ran long
  -- enough would silently turn into a surge halfway through.
  world.boons = {{}, {}}

  -- The named modules, and nothing else. The name a test uses is the name the tick's
  -- own cast uses, so that a test reads like the game and a module renamed in one
  -- place breaks in the other rather than diverging quietly.
  local hung = {}
  for _, name in ipairs(want) do
    local module = modules[name]
    if module == nil then
      error("the arena was asked for a module called '" .. tostring(name) ..
            "', and the cast has no such thing")
    end
    world[name] = module
    hung[name] = true
  end

  -- The grid is the one piece of machinery that is built rather than hung, and every
  -- question about who is near whom goes through it. A test that wants targeting or
  -- the frontline queue needs it; one that only walks a single body does not, and
  -- building it anyway costs one allocation at setup.
  if hung.targeting then
    world.grid = modules.targeting.make_grid(world)
  end

  -- Starting each module that has something to start, in the order the tick starts
  -- them. Only the ones that were asked for.
  local order = {"formations", "rest_of_brain", "waves", "structures", "snapshot"}
  for _, name in ipairs(order) do
    if hung[name] and modules[name].begin ~= nil then
      modules[name].begin(world)
    end
  end

  if hung.snapshot then
    modules.snapshot.stamp(world)
  end

  world.arena = {length = map.bounds.max_x, width = map.lane[1].width}
  return world
end
-- }}}

-- {{{ function M.put_a_formation()
-- A formation of ordinary wave bodies, standing on the arena at a given distance
-- along it, facing the way its team walks.
--
-- Built out of the same pieces a real wave is built out of -- the wave record from the
-- waves module, the slots from the formations module, the bodies from the world -- so
-- that what is being watched is the real thing and not a test's imitation of it. What
-- is left out is everything about *ownership*: no commander, no bounty, no share of
-- the chest, because none of those move a body.
-- `heading` is +1 for walking right and -1 for walking left, and it is **separate from
-- the team on purpose.** The real game derives one from the other, because there are
-- two armies and they come from opposite ends. An arena often wants the opposite: two
-- formations of the *same* side walking into each other, so that what is being watched
-- is two bodies of troops sharing a road and nothing else. Give them different teams to
-- get that picture and you have also switched on every rule about enemies, and then
-- what you are watching is a fight.
function M.put_a_formation(world, team, along, melee_count, ranged_count, heading)
  local melee_archetype, ranged_archetype = 1, 2
  local total = melee_count + ranged_count
  local wave_id = world.waves.new_wave(world, team, 1, total)
  local wave = world.wave[wave_id]
  wave.anchor = along

  heading = heading or ((team == 1) and 1 or -1)
  local lane = world.map.lane[1]
  wave.facing = heading
  -- Where the wave starts looking along the path array. Walking left means starting
  -- from the far end, because one path array is read in two directions and everything
  -- that asks "how far along" multiplies by facing.
  wave.hint = (heading == 1) and 1 or #lane.path

  local front, behind = 0, 0
  for _ = 1, melee_count do
    world.waves.spawn_body(world, team, 1, melee_archetype, wave_id, "front", front,
                           melee_count)
    front = front + 1
  end
  for _ = 1, ranged_count do
    world.waves.spawn_body(world, team, 1, ranged_archetype, wave_id, "back", behind,
                           melee_count)
    behind = behind + 1
  end

  -- The bearings, once the whole group has a place. A circle has a centre and no
  -- front, so a bearing has to be measured from the middle -- and where the middle is
  -- depends on how deep the formation turned out to be, which is not known until the
  -- last body has somewhere to stand.
  world.formations.settle_the_disc(world, wave_id)

  -- Put every body on its place immediately. A formation that has to walk from
  -- wherever it was born to where the test wanted it spends the first seconds of the
  -- test dressing its line, which is a different thing to watch.
  for id = 1, world.high_water do
    if world.soldier.alive[id] == 1 and world.soldier.wave[id] == wave_id then
      -- The heading, onto every body, before its place is worked out -- because where
      -- a body's place *is* depends on which way its formation is pointing.
      world.soldier.facing[id] = heading
      world.soldier.path_index[id] = (heading == 1) and 1 or #lane.path
      world.soldier.milestone[id] = (heading == 1) and 0
                                    or (world.parameters.shape.milestone_count - 1)
      local at, across = world.formations.target_of(world, id)
      world.walking.set_lane_position(world, id, at, across)
    end
  end

  return wave_id
end
-- }}}

-- {{{ function M.put_a_body()
-- One body, standing on its own at a stated place, belonging to no formation.
--
-- This is the stray -- the thing an army has to get past. It has no wave, so nothing
-- is keeping it in line and nothing will come to collect it; it stands where it is put
-- until something in the simulation moves it.
function M.put_a_body(world, team, along, across, archetype)
  local id = world.allocate(world)
  world.give_body(world, id, world.parameters.unit.archetype[archetype or 1])
  local soldier = world.soldier
  soldier.team[id] = team
  soldier.flavour[id] = 1
  soldier.archetype[id] = archetype or 1
  soldier.lane[id] = 1
  soldier.wave[id] = 0
  soldier.facing[id] = (team == 1) and 1 or -1
  -- State 1 is standing. Whatever else the brain would do with it, a stray in this
  -- arena is a thing that is not going anywhere.
  soldier.state[id] = 1
  world.walking.set_lane_position(world, id, along, across)
  return id
end
-- }}}

-- {{{ function M.march_tick()
-- One tick of **marching and nothing else**.
--
-- Three calls, in the order the real brain makes them: put every body back in the
-- spatial grid, let each formation advance its anchor and share out its cohesion
-- budget, then move each body toward its place unless the queue says it must stop.
--
-- This is deliberately **not** the brain. The brain is a five-state machine that also
-- acquires targets, stands off, orbits, falls back, heals, flees and decays, and every
-- one of those is a way for a movement test to be about something else. A test that
-- says "march" and gets marching can attribute what it sees.
--
-- The cost of writing it out here is that this is a second place that knows marching
-- is grid-then-plan-then-step. That is a real cost and it is the trade the arena makes
-- everywhere: a test that assembled the whole brain would not have it, and would not
-- be able to tell you anything either.
function M.march_tick(world)
  world.tick = world.tick + 1
  world.targeting.rebuild_grid(world)
  world.formations.plan(world)

  local soldier = world.soldier
  for id = 1, world.high_water do
    -- A body with no wave is a stray: nothing is keeping it in a line and nothing
    -- comes to collect it. It stands exactly where it was put, which is the whole of
    -- its job in the scene where an army has to get past it.
    if soldier.alive[id] == 1 and soldier.wave[id] ~= 0 then
      if not world.frontline.blocked(world, id) then
        world.walking.step_in_formation(world, id)
      end
    end
  end
end
-- }}}

return M
