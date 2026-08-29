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

-- 060-the-formation-sandbox.lua
--
-- A field with nothing on it but two formations.
--
-- ## Why this is not part of the invariants
--
-- Asking "does a rank stay a rank round a bend" through a whole match means the
-- answer arrives buried in everything else -- two teams, three lanes, a spawn
-- cadence, a chest, an economy, a phase clock, towers shooting -- and it means a
-- change to any of those can turn this red for reasons that have nothing to do with
-- formations. A test whose failure does not tell you where to look is a test that
-- gets ignored.
--
-- So this brings in **only the things it measures**: a lane built from a list of
-- points, the world's arrays, the spatial grid, the formation, and the movement.
-- It does not run the tick. It runs the four passes under test, in order, by hand:
--
--     index -> plan -> think -> (engage)
--
-- Everything the sandbox cannot avoid touching is listed at the bottom of the log
-- as a coupling, because a thing this test needs and should not is a thing worth
-- knowing about.
--
-- ## What it measures
--
-- 1. **Where each body sits relative to the formation's circle** -- the one whose
--    edges touch the left and right of the line as it walks.
-- 2. **What a turn does to the two ends of the line.** Turning left, the left of
--    the line has less ground to cover and the right has more, so the left must
--    give way and the right must hurry, out of one budget, or the line bends.
-- 3. **The same, along a lane shaped like a sine wave** -- turning one way and then
--    the other, over and over, with no straight to recover in.
-- 4. **That two formations walking at each other meet and engage.**
--
-- Run it directly. It writes a full trace to tmp/shared-memory/.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."

local passed, failed = 0, 0
local log_lines = {}

-- {{{ local function note()
local function note(text)
  log_lines[#log_lines + 1] = text
end
-- }}}

-- {{{ local function check()
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
    print(string.format("  ok    %s", name))
    note(string.format("PASS  %s", name))
  else
    failed = failed + 1
    print(string.format("  FAIL  %s%s", name, detail and ("  --  " .. detail) or ""))
    note(string.format("FAIL  %s  --  %s", name, detail or ""))
  end
end
-- }}}

-- The pieces under test, and nothing else.
local map_builder = loadfile(ROOT .. "/src/030-map-builder.lua")()
local parameters_module = loadfile(ROOT .. "/src/028-match-parameters.lua")()
local world_module = loadfile(ROOT .. "/src/032-the-world.lua")()
local walking = loadfile(ROOT .. "/src/034-walking.lua")()
local targeting = loadfile(ROOT .. "/src/035-targeting.lua")()
local frontline = loadfile(ROOT .. "/src/036-the-frontline.lua")()
local brain = loadfile(ROOT .. "/src/037-the-brain.lua")()
local combat = loadfile(ROOT .. "/src/038-combat.lua")()
local formations = loadfile(ROOT .. "/src/052-formations.lua")()
local random_streams = loadfile(ROOT .. "/src/029-random-streams.lua")()
-- The brain reaches for this the moment anything stands off, orbits or falls back,
-- which is the sandbox discovering a dependency rather than assuming one. It is
-- listed at the bottom of the log with the others.
local rest_of_brain = loadfile(ROOT .. "/src/062-the-rest-of-the-brain.lua")()

-- How wide the sandbox builds its lanes: **the real side lane's width**, read from
-- the shape parameters rather than written down here.
--
-- It was a literal 62, which was the side lane's width when this was written and
-- stopped being it the day the bodies were spread out. The sandbox went on measuring
-- a two-abreast formation the game no longer builds, and passed, which is the worst
-- way for a test to be wrong: it agrees with itself about the wrong thing.
local A_SIDE_LANE = parameters_module.load().shape.lane_width[1]

-- How far along a lane a test formation is put down.
--
-- Derived from the rank spacing rather than chosen, because it exists to clear the
-- formation's own depth: eight ranks' worth is comfortably more than any formation
-- this sandbox builds, and it moves on its own if the spacing changes.
local CLEAR_OF_THE_WALL = formations.RANK_SPACING * 8

-- {{{ local function sandbox()
-- A world containing one lane and whatever bodies the caller asks for.
local function sandbox(polyline, width)
  local parameters = parameters_module.load()
  -- One lane. Everything that counts lanes reads this, so nothing has to be told
  -- that the map is unusual.
  parameters = setmetatable({lane_count = 1}, {__index = parameters})

  local map = map_builder.lane_from_polyline(polyline, width, 20,
                                             parameters.shape.lane_files[1],
                                             parameters.shape.zone_divisions)
  local world = world_module.create(parameters, map, random_streams.make_set(1))

  world.walking = walking
  world.targeting = targeting
  world.frontline = frontline
  world.brain = brain
  world.combat = combat
  world.formations = formations
  world.rest_of_brain = rest_of_brain
  world.map_builder = map_builder
  -- A wave makes its own waypoint stream from the match seed and its own number, so
  -- the sandbox has to be able to hand it the thing that makes streams.
  world.random_streams = random_streams
  world.allocate = world_module.allocate
  world.release = world_module.release
  world.raise = world_module.raise
  world.give_body = world_module.give_body

  world.attacker_of = {}
  for id = 1, world_module.SOLDIER_CAPACITY do
    world.attacker_of[id] = 0
  end
  world.grid = targeting.make_grid(world)
  formations.begin(world)
  rest_of_brain.begin(world)

  return world, parameters, map
end
-- }}}

-- {{{ local function put_a_wave_down()
-- One formation, at a distance along the lane, facing a direction.
--
-- Built by hand rather than through the spawner, because the spawner reaches for a
-- commander, a chest, a bounty and a wave cadence -- none of which this is testing,
-- and all of which would have to be standing for it to run.
--
-- **Put it down further along than the formation is deep.** A body's place is a
-- fixed distance behind the anchor, and a place behind the start of the lane is not
-- a place -- the position is clamped to the lane's beginning and the body reads as
-- badly out of position until the anchor has walked far enough forward. That is
-- correct behaviour and it is measured on its own further down; a test about a curve
-- that starts the wave against the wall is measuring the wall.
local function put_a_wave_down(world, parameters, team, at, facing, melee, ranged)
  local lane = world.map.lane[1]
  local wave_id = #world.wave + 1
  world.wave[wave_id] = {
    id = wave_id, team = team, lane = 1, spawn_tick = 0,
    member_count = melee + ranged, living_count = melee + ranged,
    killed_any = 0, settled = 0, upgrade_count = {},
    anchor = at, pace = 1.05, facing = facing, engaged = 0,
    hint = 1, lag_of = {}, across_offset = 0,
  }

  local soldier = world.soldier
  local ids = {}
  for index = 0, melee + ranged - 1 do
    local archetype = (index < melee) and 1 or 2
    local id = world.allocate(world)
    world.give_body(world, id, parameters.unit.archetype[archetype])
    soldier.team[id] = team
    soldier.archetype[id] = archetype
    soldier.wave[id] = wave_id
    soldier.lane[id] = 1
    soldier.facing[id] = facing
    soldier.path_index[id] = 1
    soldier.speed_scale[id] = 1
    soldier.turns_left[id] = 0
    soldier.going_home[id] = 0

    if index < melee then
      formations.assign_wave_slots(world, id, lane, index, "front", melee)
    else
      formations.assign_wave_slots(world, id, lane, index - melee, "back", melee)
    end
    walking.set_lane_position(world, id,
      at + soldier.slot_along[id] * facing, soldier.slot_across[id])
    ids[#ids + 1] = id

    -- A place behind the start of the lane is not a place. Setting a position
    -- outside the lane clamps it to the end, and the body then reads as badly out of
    -- formation when it is standing as far back as the ground allows -- so a test
    -- that starts a wave against the wall measures the wall.
    --
    -- Loud rather than nudged, because the number that decides how deep a formation
    -- is lives in the formation module and can be changed there without anybody
    -- thinking about this file. The failure it produces is a lag that looks exactly
    -- like a turning fault.
    local place = at + soldier.slot_along[id] * facing
    if place < 0 or place > lane.length then
      error(string.format(
        "a wave put down at %.0f has a place at %.0f, which is off the lane -- " ..
        "start it at least %.0f along", at, place, math.abs(soldier.slot_along[id])))
    end
  end
  return wave_id, ids
end
-- }}}

-- {{{ local function step()
-- One tick of exactly the passes under test, and nothing else.
--
-- Not the tick's dispatch table. If this called that, the sandbox would be running
-- the spawner, the chest, the economy and the phase clock, and would stop being a
-- test of the formation.
local function step(world, with_fighting)
  targeting.rebuild_grid(world)
  formations.plan(world)
  if with_fighting then
    combat.clear_buffers(world)
    for id = 1, world.high_water do
      if world.soldier.alive[id] == 1 and not targeting.target_is_alive(world, id) then
        targeting.choose(world, id)
      end
    end
    targeting.sweep_attackers(world)
  end
  brain.run(world)
  if with_fighting then
    combat.attack_pass(world)
    combat.resolve_pass(world)
    -- Deaths are cleared here rather than by the reap pass, which reaches for
    -- bounties, guards, monsters and a chest -- none of which exist in a sandbox.
    --
    -- The one thing the reap does that this **must** copy is decrementing the wave's
    -- living count, because that is what stops a wave advancing. Without it a
    -- formation whose every member is dead keeps marching down the lane, which is
    -- not a thing the game does and is exactly the sort of artefact that makes a
    -- sandbox lie about the system it is standing in for.
    for id = 1, world.high_water do
      if world.soldier.alive[id] == 1 and world.soldier.state[id] == 5 then
        local wave = world.wave[world.soldier.wave[id]]
        if wave ~= nil then
          wave.living_count = wave.living_count - 1
        end
        world.soldier.alive[id] = 0
        world.live_count = world.live_count - 1
      end
    end
  end
  world.tick = world.tick + 1
end
-- }}}

-- {{{ local function measure_formation()
-- Where every body sits relative to its formation's centre, in the formation's own
-- frame: how far along, and how far across.
local function measure_formation(world, wave_id)
  local soldier = world.soldier
  local wave = world.wave[wave_id]
  local out = {members = {}, worst_across = 0, worst_lag = 0, scale_sum = 0, count = 0}

  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.wave[id] == wave_id then
      local target_along, target_across = formations.target_of(world, id)
      local lag = (target_along - soldier.lane_along[id]) * soldier.facing[id]
      -- **Measured from the formation's own centre, not the lane's.**
      --
      -- The circle a formation makes is a circle about the formation. A wave sits
      -- off the centre line of its road for two reasons -- it has been shifted to
      -- stand abreast of two others during a challenge, and it is wandering toward a
      -- waypoint -- and neither of those is the line coming apart. Measured against
      -- the road, a wave that has drifted six paces looks like a wave whose flank has
      -- been pushed six paces out of the rank, and those are opposite events.
      local middle = (wave.across_offset or 0) + (wave.wander or 0)
      local across = soldier.lane_across[id] - middle
      -- Both sides of the comparison move to the formation's frame, or the departure
      -- from file below would be measuring the distance between two different
      -- origins rather than between a body and its place.
      target_across = target_across - middle

      out.count = out.count + 1
      out.scale_sum = out.scale_sum + soldier.speed_scale[id]
      out.members[out.count] = {
        id = id, across = across, want_across = target_across, lag = lag,
        scale = soldier.speed_scale[id],
        x = soldier.x[id], y = soldier.y[id],
      }
      if math.abs(across) > out.worst_across then out.worst_across = math.abs(across) end
      if math.abs(lag) > out.worst_lag then out.worst_lag = math.abs(lag) end
    end
  end
  return out
end
-- }}}

-- {{{ local function test_the_circle()
-- Every body stands inside the circle whose edges touch the sides of the line.
local function test_the_circle()
  note("")
  note("== the formation's circle ==")
  local world, parameters, map = sandbox({0, 0, 2000, 0}, A_SIDE_LANE)
  local wave_id = put_a_wave_down(world, parameters, 1, CLEAR_OF_THE_WALL, 1, 5, 2)
  local radius = formations.radius_of(map.lane[1])

  for _ = 1, 200 do
    step(world, false)
  end

  local shape = measure_formation(world, wave_id)
  note(string.format("lane width %.0f, %d files, radius %.1f",
    map.lane[1].width, formations.files_for(map.lane[1]), radius))
  for _, member in ipairs(shape.members) do
    note(string.format("  body %2d  across %+7.2f (wants %+6.2f)  lag %+6.2f  at (%7.1f, %7.1f)",
      member.id, member.across, member.want_across, member.lag, member.x, member.y))
  end

  check("every body stands inside the formation's circle",
        shape.worst_across <= radius + 0.001,
        string.format("furthest across was %.2f against a radius of %.2f",
          shape.worst_across, radius))

  local off_slot = 0
  for _, member in ipairs(shape.members) do
    if math.abs(member.across - member.want_across) > 0.01 then
      off_slot = off_slot + 1
    end
  end
  check("and on a straight, every body is exactly in its place",
        off_slot == 0 and shape.worst_lag < 1.5,
        string.format("%d bodies off their file, worst lag %.2f", off_slot, shape.worst_lag))
end
-- }}}

-- {{{ local function test_a_turn()
-- Turning left, the left of the line has less ground to cover and the right has
-- more. The right must hurry and the left must give way, out of one budget.
--
-- **This is the test that found the bug it was written for.** Holding a formation in
-- lane coordinates made a turn free -- every body in a rank shares one
-- distance-along, so the outer one simply covered more world ground for nothing,
-- moving faster than its own speed with nothing to notice. Capping the step by the
-- distance actually travelled is what makes the outer body fall behind, which is
-- what gives the cohesion budget something to correct.
local function test_a_turn()
  note("")
  note("== a left turn ==")
  -- Straight, then a quarter turn to the left, then straight again. Heading +x with
  -- y downward, turning toward -y is a left turn, so the inside of it is the
  -- negative-across side.
  local corner = {0, 600, 700, 600}
  for step_index = 1, 24 do
    local angle = (step_index / 24) * (math.pi * 0.5)
    corner[#corner + 1] = 700 + math.sin(angle) * 300
    corner[#corner + 1] = 600 - (1 - math.cos(angle)) * 300
  end
  corner[#corner + 1] = 1000
  corner[#corner + 1] = -400

  local world, parameters, map = sandbox(corner, A_SIDE_LANE)
  local wave_id = put_a_wave_down(world, parameters, 1, CLEAR_OF_THE_WALL, 1, 5, 2)

  local inner_scale, outer_scale, samples = 0, 0, 0
  local inner_distance, outer_distance = 0, 0
  local inner_id, outer_id = 0, 0
  local last_x, last_y = {}, {}
  local worst_lag = 0

  for tick = 1, 900 do
    step(world, false)
    local shape = measure_formation(world, wave_id)

    -- Pick the two ends of the front rank once, by their intended file.
    if inner_id == 0 then
      local most_negative, most_positive = 1e9, -1e9
      for _, member in ipairs(shape.members) do
        if member.want_across < most_negative then
          most_negative, inner_id = member.want_across, member.id
        end
        if member.want_across > most_positive then
          most_positive, outer_id = member.want_across, member.id
        end
      end
      for _, member in ipairs(shape.members) do
        last_x[member.id], last_y[member.id] = member.x, member.y
      end
    end

    -- Only sample while actually in the bend, which is where the claim applies.
    local anchor = world.wave[wave_id].anchor
    local in_the_turn = anchor > 700 and anchor < 1150
    for _, member in ipairs(shape.members) do
      if member.id == inner_id or member.id == outer_id then
        local dx = member.x - (last_x[member.id] or member.x)
        local dy = member.y - (last_y[member.id] or member.y)
        local moved = math.sqrt(dx * dx + dy * dy)
        if in_the_turn then
          if member.id == inner_id then
            inner_scale = inner_scale + member.scale
            inner_distance = inner_distance + moved
          else
            outer_scale = outer_scale + member.scale
            outer_distance = outer_distance + moved
          end
        end
      end
      last_x[member.id], last_y[member.id] = member.x, member.y
    end
    if in_the_turn then
      samples = samples + 1
      if shape.worst_lag > worst_lag then worst_lag = shape.worst_lag end
    end
  end

  inner_scale = inner_scale / math.max(1, samples)
  outer_scale = outer_scale / math.max(1, samples)

  note(string.format("sampled %d ticks inside the bend", samples))
  note(string.format("  inner (left)  mean speed multiplier %.4f, ground covered %.1f",
    inner_scale, inner_distance))
  note(string.format("  outer (right) mean speed multiplier %.4f, ground covered %.1f",
    outer_scale, outer_distance))
  note(string.format("  worst lag anywhere in the line during the turn: %.2f paces", worst_lag))

  check("turning left, the outer body covers more ground than the inner",
        outer_distance > inner_distance * 1.02,
        string.format("outer covered %.1f, inner %.1f", outer_distance, inner_distance))

  -- **The inner one gives way, and nobody is hurried.**
  --
  -- This asked for the opposite -- that the outer body be given extra speed out of a
  -- budget taken from the inner one. That was true while a body's speed was a dial.
  -- With gears, nothing exceeds marching pace: a body is either marching or walking,
  -- and a formation dresses itself by the inside of a turn **slowing** rather than by
  -- the outside sprinting. Which is what a real body of troops does; asking the outer
  -- rank to run is how a line becomes a crowd.
  --
  -- What keeps the outer body from falling behind for ever is not its own speed, it
  -- is that the front of the formation stops and waits when the line is stretched.
  check("so the inner body gives way, and the outer is not asked to hurry",
        inner_scale <= outer_scale and outer_scale <= 1.0 + 0.0001,
        string.format("inner multiplier %.4f, outer %.4f -- and nothing may exceed " ..
                      "marching pace", inner_scale, outer_scale))

  check("and the line holds together through the bend",
        worst_lag < 26,
        string.format("the line bent by %.2f paces, against a rank of %d",
                      worst_lag, formations.RANK_SPACING))
end
-- }}}

-- {{{ local function test_a_sine_wave()
-- A lane that turns one way and then the other, over and over, with no straight to
-- recover in. Whichever end of the line is being helped changes every few seconds,
-- so a cohesion rule that only worked in one direction shows up here.
local function test_a_sine_wave()
  note("")
  note("== a sine wave ==")
  local points = {}
  for index = 0, 80 do
    points[#points + 1] = index * 24
    points[#points + 1] = 400 + math.sin(index * 0.22) * 180
  end

  local world, parameters, map = sandbox(points, A_SIDE_LANE)
  local wave_id = put_a_wave_down(world, parameters, 1, CLEAR_OF_THE_WALL, 1, 5, 2)

  local worst_lag, worst_off_file, worst_scale = 0, 0, 0
  local was_in_gear, gear_changes, gear_body_ticks = {}, 0, 0
  local balance_error = 0

  for tick = 1, 1400 do
    step(world, false)
    local shape = measure_formation(world, wave_id)
    -- **The spread of lag, not the worst lag.** A wave whose every body is equally
    -- behind is a wave whose anchor got ahead of it, which is intact; a wave whose
    -- bodies are behind by different amounts is a line that has bent. A formation
    -- moving sideways -- following a curve, or heading for a waypoint -- spends one
    -- speed budget on two things and every body in it falls behind together, which
    -- against an absolute measure reads identically to the line coming apart.
    local behind_least, behind_most = math.huge, -math.huge
    for _, member in ipairs(shape.members) do
      if member.lag < behind_least then behind_least = member.lag end
      if member.lag > behind_most then behind_most = member.lag end
    end
    if behind_most > behind_least and (behind_most - behind_least) > worst_lag then
      worst_lag = behind_most - behind_least
    end
    for _, member in ipairs(shape.members) do
      local off = math.abs(member.across - member.want_across)
      if off > worst_off_file then worst_off_file = off end
      if member.scale > worst_scale then worst_scale = member.scale end
      if was_in_gear[member.id] ~= nil and was_in_gear[member.id] ~= member.scale then
        gear_changes = gear_changes + 1
      end
      was_in_gear[member.id] = member.scale
      gear_body_ticks = gear_body_ticks + 1
    end
    -- The budget must still balance while the curve keeps changing sign.
    local wave = world.wave[wave_id]
    if wave.speed_shared_among ~= nil and wave.speed_shared_among > 1 then
      local error = math.abs(wave.speed_balance) / wave.speed_shared_among
      if error > balance_error then balance_error = error end
    end
    if tick % 200 == 0 then
      note(string.format("  t%4d  anchor %7.1f  worst lag %6.2f  worst off-file %5.2f",
        tick, wave.anchor, shape.worst_lag, worst_off_file))
    end
  end

  -- Bounded by a whole rank, derived rather than chosen: at a rank's worth of bend
  -- the second rank has caught the first and ranks have stopped being ranks.
  check("a formation holds its ranks along a lane that keeps changing direction",
        worst_lag < formations.RANK_SPACING,
        string.format("the line bent by %.2f paces, against a rank of %d",
                      worst_lag, formations.RANK_SPACING))

  check("and nobody is pushed out of their file by the curve",
        worst_off_file < 3,
        string.format("worst departure from file %.2f paces", worst_off_file))

  -- **How often a body changes gear**, which is the measurement the speeds get tuned
  -- with and the one that decides whether a line reads as marching or as fidgeting.
  --
  -- It trades against how well the line holds and pulls the opposite way: a narrower
  -- dead band keeps the shape tighter and makes bodies switch more often. Printed
  -- every run so the equilibrium is a thing somebody can look at.
  note(string.format("  gear changed %.2f times per hundred body-ticks -- about once every %.0f ticks",
    gear_changes / math.max(1, gear_body_ticks) * 100,
    gear_body_ticks / math.max(1, gear_changes)))

  check("and a body does not change gear more than about once a second",
        gear_changes / math.max(1, gear_body_ticks) < 0.10,
        string.format("%.2f changes per hundred body-ticks", 
                      gear_changes / math.max(1, gear_body_ticks) * 100))

  -- **Nothing was ever hurried**, however hard the curve worked. The old form of this
  -- check asked whether a budget balanced; there is no budget now, and the property
  -- that replaced it is absolute rather than statistical: no body, at any tick, moves
  -- faster than its own marching pace.
  check("and nothing was ever asked to move faster than marching",
        worst_scale <= 1.0 + 0.0001,
        string.format("the fastest anything went was %.4f of its pace", worst_scale))
end
-- }}}

-- {{{ local function test_the_wander()
-- A wave on a **straight** road does not walk a straight line.
--
-- This is the whole of what waypoints are for, and it is the one property that can
-- only be measured on ground with no curve in it: on a bend, a formation moving
-- sideways is indistinguishable from a formation following the road.
--
-- Two failures are being watched for and they are opposite. A wander of nothing
-- means the waypoints are not being read at all, and the feature is decoration. A
-- wander past the shoulder means the clamp is wrong and part of a rank is in the
-- ditch -- which is the reason the offset is bounded by the road's half-width less
-- the formation's radius rather than by the road's half-width.
local function test_the_wander()
  note("")
  note("== the wander ==")
  local world, parameters, map = sandbox({0, 0, 4000, 0}, A_SIDE_LANE)
  local lane = map.lane[1]
  local wave_id = put_a_wave_down(world, parameters, 1, CLEAR_OF_THE_WALL, 1, 5, 2)

  local radius = formations.radius_of(lane)
  local shoulder = lane.width * 0.5 - radius

  local low, high, worst_body = math.huge, -math.huge, 0
  local zones_visited = {}
  for tick = 1, 2600 do
    step(world, false)
    local wave = world.wave[wave_id]
    local wander = wave.wander or 0
    if wander < low then low = wander end
    if wander > high then high = wander end
    if wave.zone ~= nil then zones_visited[wave.zone] = true end

    -- The edge of the formation, which is what must stay on the road.
    for _, member in ipairs(measure_formation(world, wave_id).members) do
      local edge = math.abs(member.across + wander)
      if edge > worst_body then worst_body = edge end
    end

    if tick % 400 == 0 then
      note(string.format("  t%4d  anchor %7.1f  zone %2s  wandering %+6.2f toward %+6.2f",
        tick, wave.anchor, tostring(wave.zone), wander, wave.wander_to or 0))
    end
  end

  local how_many_zones = 0
  for _ in pairs(zones_visited) do how_many_zones = how_many_zones + 1 end

  note(string.format("  road is %.0f across, formation %.0f, so %.0f paces of shoulder",
    lane.width, radius * 2, shoulder))
  note(string.format("  wandered %+.2f to %+.2f over %d zones; furthest any body got from the middle was %.2f",
    low, high, how_many_zones, worst_body))

  check("a wave walking a straight road does not walk a straight line",
        (high - low) > 1,
        string.format("wandered across %.1f paces", high - low))

  check("and it takes its aim from more than one waypoint on the way",
        how_many_zones > 4, how_many_zones .. " zones crossed")

  check("and no part of it leaves the road",
        worst_body <= lane.width * 0.5 + 0.001,
        string.format("a body reached %.2f paces out and the road's half-width is %.2f",
                      worst_body, lane.width * 0.5))

  -- **It picked a column and stayed in it.** The road divides into three lengthways
  -- and a wave commits to one on its way out: a wave that started on the left tends
  -- to stay on the left.
  --
  -- Without the commitment a wave draws an independent offset in every stretch and
  -- crosses the road repeatedly on the way down it, which is not an army with an
  -- approach -- it is an army that cannot make up its mind. So the thing to assert is
  -- not that it wanders, it is that it wanders **inside one third of the road**.
  local wave = world.wave[wave_id]
  local room = lane.width * 0.5 - (wave.radius or 0)
  local band = room * 2 / 3
  local mine_from = wave.column * band - band * 0.5
  local mine_to   = wave.column * band + band * 0.5
  local names = {[-1] = "left", [0] = "centre", [1] = "right"}
  note(string.format("  took the %s column, which runs %+.1f to %+.1f",
    names[wave.column] or "?", mine_from, mine_to))

  check("and it stayed in the column it chose",
        low >= mine_from - 0.001 and high <= mine_to + 0.001,
        string.format("wandered %+.2f to %+.2f, and its column is %+.2f to %+.2f",
                      low, high, mine_from, mine_to))

  -- And the circle is the formation's own. A wave that has been fought down is
  -- narrower than a full one and has more road to move about in; measuring the room
  -- with one number for the whole lane would put a wide formation's edge in the ditch
  -- and hold a narrow one further from the verge than it needs to be.
  local was = wave.radius
  local members = {}
  local kept = 0
  for id = 1, world.high_water do
    if world.soldier.alive[id] == 1 and world.soldier.wave[id] == wave_id then
      kept = kept + 1
      members[kept] = id
    end
  end
  -- Take the **outer file** away and ask again -- every body standing at the edge, on
  -- both sides and in every rank, which is what a formation losing its flanks looks
  -- like. Removing one body proves nothing: the others at the same offset are still
  -- there and the circle is unchanged, which is correct and is why the first version
  -- of this check could not fail.
  local widest = 0
  for index = 1, kept do
    local across = math.abs(world.soldier.slot_across[members[index]])
    if across > widest then widest = across end
  end
  local inner, inner_count = {}, 0
  for index = 1, kept do
    if math.abs(world.soldier.slot_across[members[index]]) < widest - 0.001 then
      inner_count = inner_count + 1
      inner[inner_count] = members[index]
    end
  end
  local narrower = formations.live_radius(world, inner, inner_count)
  note(string.format("  full it is %.1f across with %d bodies; without its outer file, %.1f with %d",
    was * 2, kept, narrower * 2, inner_count))

  check("and the formation's circle is its own size, not the road's",
        narrower < was,
        string.format("%.2f against %.2f", narrower, was))
end
-- }}}

-- {{{ local function test_two_formations_meet()
-- The whole point of walking anywhere. Two lines, facing each other, and they have
-- to meet and stop rather than pass through.
local function test_two_formations_meet()
  note("")
  note("== two formations meeting ==")
  local world, parameters, map = sandbox({0, 0, 2400, 0}, A_SIDE_LANE)
  local length = map.lane[1].length

  local mine = put_a_wave_down(world, parameters, 1, CLEAR_OF_THE_WALL, 1, 5, 2)
  local theirs = put_a_wave_down(world, parameters, 2, length - CLEAR_OF_THE_WALL, -1, 5, 2)

  local met_at, mine_met, theirs_met = 0, 0, 0
  for tick = 1, 2000 do
    step(world, true)
    if met_at == 0 and world.wave[mine].engaged == 1 then
      -- Where they were **when they met**, which is the thing being asserted.
      -- Afterwards one of them wins and walks on, and where the winner ends up is a
      -- different and much less interesting question.
      met_at = tick
      mine_met = world.wave[mine].anchor
      theirs_met = world.wave[theirs].anchor
    end
    if tick % 300 == 0 then
      note(string.format("  t%4d  mine at %7.1f  theirs at %7.1f  alive %d",
        tick, world.wave[mine].anchor, world.wave[theirs].anchor, world.live_count))
    end
  end

  local survivors = {0, 0}
  for id = 1, world.high_water do
    if world.soldier.alive[id] == 1 then
      survivors[world.soldier.team[id]] = survivors[world.soldier.team[id]] + 1
    end
  end
  note(string.format("  met at tick %d, mine at %.1f and theirs at %.1f of %.1f",
    met_at, mine_met, theirs_met, length))
  note(string.format("  %d and %d left standing", survivors[1], survivors[2]))

  check("two formations walking at each other meet",
        met_at > 0, "neither ever reported contact")

  -- They start the same distance from either end and walk at the same pace, so
  -- they must meet in the middle. Measured as how far apart their two fronts were
  -- at the moment of contact, which should be about the reach that detected it.
  check("and they meet in the middle, front to front",
        met_at > 0 and math.abs((theirs_met - mine_met) - 0) < 140
          and math.abs(mine_met - (length - theirs_met)) < 40,
        string.format("mine at %.1f, theirs at %.1f, %.1f apart",
          mine_met, theirs_met, theirs_met - mine_met))

  check("and one of them is left standing",
        survivors[1] + survivors[2] < 14 and survivors[1] + survivors[2] > 0,
        string.format("%d and %d survivors", survivors[1], survivors[2]))
end
-- }}}

print("")
print("the formation sandbox")
print("")
note("the formation sandbox -- a field with nothing on it but two formations")
note("")

test_the_circle()
test_a_turn()
test_a_sine_wave()
test_the_wander()
test_two_formations_meet()

note("")
note("== couplings this sandbox could not avoid ==")
note("The formation reaches the spatial grid, because a wave stops when something")
note("hostile is near its front, and 'near' is a query. That is a real dependency.")
note("")
note("And the brain reaches the rest of itself -- standing off, orbiting, falling")
note("back -- the moment two lines are close enough to do any of those. Also real:")
note("what a body does when it is being shot at is not separable from what it does")
note("while it walks.")
note("")
note("Everything else it touches -- the world's arrays, the lane, the movement -- is")
note("what it is measuring. It does not run the tick, so no spawner, no chest, no")
note("economy and no phase clock are standing while these numbers are taken.")

-- The log goes to the RAM tier rather than into the repository, and the directory
-- is made rather than assumed: /dev/shm does not survive a reboot.
os.execute("mkdir -p " .. ROOT .. "/tmp/shared-memory")
local log_path = ROOT .. "/tmp/shared-memory/formation-sandbox.log"
local handle = io.open(log_path, "w")
if handle == nil then
  error("cannot write the sandbox log to " .. log_path)
end
handle:write(table.concat(log_lines, "\n"))
handle:write("\n")
handle:close()

print("")
print(string.format("%d passed, %d failed", passed, failed))
print("full trace: " .. log_path)
print("")

if failed > 0 then
  os.exit(1)
end
