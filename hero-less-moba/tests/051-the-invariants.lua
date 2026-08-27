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

-- 051-the-invariants.lua
--
-- The properties this project refuses to break, checked in one run.
--
-- Tests are cheap and there should be many. These are the ones that earn their
-- place by failing loudly the day somebody introduces a whole *class* of bug
-- rather than one instance of it:
--
--   * **Reproducibility.** Same seed, same commands, same result -- tick for tick.
--     It fails the day somebody adds a call to a global random source, iterates a
--     hash table whose order is not stable, or reads the wall clock.
--
--   * **The camera holds its anchor.** The property from issue 708, checked with
--     random anchors and random scale changes rather than with one hand-picked
--     case, because every later camera feature is a chance to break it silently.
--
--   * **The map is a mirror of itself.** An asymmetric map hands one team a
--     shorter walk and nothing else in the project would ever notice.
--
--   * **A wide query still finds what is next to it.** The regression for a real
--     bug: a body carrying two Longbows reaches further than the spatial grid's
--     cell, and the first version of the query silently searched too few cells.
--
--   * **Placing upgrades changes the game.** If stacking a lane does not move a
--     frontline, the entire premise is not working, however well everything else
--     runs.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
    print(string.format("  ok    %s", name))
  else
    failed = failed + 1
    print(string.format("  FAIL  %s%s", name, detail and ("  --  " .. detail) or ""))
  end
end
-- }}}

-- {{{ local function fresh_world()
local function fresh_world(tick_module)
  local modules = tick_module.load_cast(ROOT)
  local parameters = modules.match_parameters.load()
  return tick_module.assemble(modules, parameters), modules, parameters
end
-- }}}

local tick_module = loadfile(ROOT .. "/src/042-the-tick.lua")()

-- {{{ local function test_reproducibility()
-- The same seed and the same (empty) command list must produce the same match,
-- tick for tick. Compared on a fingerprint of every body's position rather than
-- on a summary, because a summary can agree while the details diverge.
local function test_reproducibility()
  local function fingerprint(ticks)
    local world = fresh_world(tick_module)
    for _ = 1, ticks do
      tick_module.advance(world)
    end
    local parts = {}
    for index = 1, world.frame[world.frame_newest].live_count do
      local id = world.frame[world.frame_newest].live[index]
      parts[#parts + 1] = string.format("%d:%.4f:%.4f:%.2f",
        id, world.soldier.x[id], world.soldier.y[id], world.soldier.health[id])
    end
    return table.concat(parts, "|"), world
  end

  local first,  world_a = fingerprint(3000)
  local second, world_b = fingerprint(3000)
  check("the same seed plays the same match, tick for tick",
        first == second,
        string.format("%d bodies vs %d", world_a.live_count, world_b.live_count))
end
-- }}}

-- {{{ local function test_camera_anchor()
-- Issue 708's property: for a random cursor position and a random scale change,
-- the world point under the cursor must be unchanged.
--
-- Checked against the target rather than the drawn values, because the drawn ones
-- are mid-ease by design -- the animation is allowed to be on its way, it is the
-- destination that must be exact.
local function test_camera_anchor()
  local camera_module = loadfile(ROOT .. "/src/046-the-camera.lua")()
  local bounds = {min_x = 0, min_y = 0, max_x = 1400, max_y = 1400}

  -- A fixed, ugly generator rather than math.random, so a failure is reproducible
  -- and so this test cannot be the thing that introduces global randomness into a
  -- project whose first invariant is that there is none.
  local state = 987654321
  local function next_float()
    state = (1103515245 * state + 12345) % 2147483648
    return state / 2147483648
  end

  local worst = 0
  local worst_case = ""
  for trial = 1, 400 do
    local camera = camera_module.create(bounds, 0, 0, 1260, 900)
    -- Start from a random place in the zoom range so the check is not only ever
    -- run from the rest framing.
    camera_module.zoom_about(camera, 1 + next_float() * 5, 800, 450)
    camera.drawn_scale = camera.target_scale
    camera.drawn_x, camera.drawn_y = camera.target_x, camera.target_y
    camera.anchor_live = false

    local cursor_x = next_float() * 1260
    local cursor_y = next_float() * 900
    local before_x, before_y = camera_module.screen_to_world(camera, cursor_x, cursor_y)

    local factor = 0.5 + next_float() * 3.0
    camera_module.zoom_about(camera, factor, cursor_x, cursor_y)

    -- Settle the ease so the target is what is being measured.
    camera.drawn_scale = camera.target_scale
    camera.drawn_x, camera.drawn_y = camera.target_x, camera.target_y

    local after_x, after_y = camera_module.screen_to_world(camera, cursor_x, cursor_y)

    -- The clamp is allowed to break the anchor: if holding the point would put
    -- the centre outside the map, the map wins. Those trials are skipped rather
    -- than failed, because the clamp is a deliberate rule and not a defect.
    local clamped = camera.target_x <= bounds.min_x or camera.target_x >= bounds.max_x
                 or camera.target_y <= bounds.min_y or camera.target_y >= bounds.max_y
    if not clamped then
      local drift = math.max(math.abs(after_x - before_x), math.abs(after_y - before_y))
      if drift > worst then
        worst = drift
        worst_case = string.format("cursor (%.0f, %.0f) factor %.2f", cursor_x, cursor_y, factor)
      end
    end
  end

  check("the world under the cursor does not move while zooming",
        worst < 0.001,
        string.format("worst drift %.6f paces, at %s", worst, worst_case))
end
-- }}}

-- {{{ local function test_camera_home()
-- Home is instant and total: after it, the drawn framing *is* the rest framing,
-- with nothing left easing and no drag still captured.
local function test_camera_home()
  local camera_module = loadfile(ROOT .. "/src/046-the-camera.lua")()
  local camera = camera_module.create({min_x = 0, min_y = 0, max_x = 1400, max_y = 1400},
                                      0, 0, 1260, 900)
  camera_module.wheel(camera, 6, 300, 200)
  camera_module.begin_drag(camera, 300, 200)
  camera_module.drag_to(camera, 900, 700)
  camera_module.home(camera)

  check("home returns to the whole map instantly and drops the drag",
        camera.drawn_scale == camera.rest_scale
        and camera.drawn_x == camera.rest_x
        and camera.drawn_y == camera.rest_y
        and camera.dragging == false)
end
-- }}}

-- {{{ local function test_camera_floor()
-- You cannot pull back further than the whole map.
local function test_camera_floor()
  local camera_module = loadfile(ROOT .. "/src/046-the-camera.lua")()
  local camera = camera_module.create({min_x = 0, min_y = 0, max_x = 1400, max_y = 1400},
                                      0, 0, 1260, 900)
  for _ = 1, 50 do
    camera_module.wheel(camera, -1, 800, 450)
  end
  check("the camera cannot pull back past the whole map",
        camera.target_scale == camera.rest_scale)

  for _ = 1, 200 do
    camera_module.wheel(camera, 1, 800, 450)
  end
  check("the camera cannot push in past the badge-reading ceiling",
        camera.target_scale == camera_module.PIXELS_PER_PACE_MAX)
end
-- }}}

-- {{{ local function test_map_mirror()
-- The map validator's own checks, run as a test so that a bad shape parameter is
-- caught by the test suite and not only by whoever next starts a match.
local function test_map_mirror()
  local modules = tick_module.load_cast(ROOT)
  local parameters = modules.match_parameters.load()
  local map = modules.map_builder.build(parameters)
  local problems = modules.map_validator.check(map, parameters)
  check("the map validator finds nothing wrong with the map it builds",
        #problems == 0,
        problems[1])

  -- And the property the validator exists for, stated independently here so that
  -- a validator that stopped checking would not also stop this from failing.
  local lane = map.lane[1]
  local near = map.node[lane.milestone_node[1]]
  local far  = map.node[lane.milestone_node[7]]
  check("a lane's milestones mirror across the junction diagonal",
        math.abs(near.x - far.y) < 0.0001 and math.abs(near.y - far.x) < 0.0001)
end
-- }}}

-- {{{ local function test_wide_query()
-- The regression. A body carrying enough Longbows reaches further than the
-- spatial grid's cell size, and the query must still find what is next to it.
--
-- The bug this replaces was not a crash in the field -- it was a refusal, added
-- deliberately, that fired the first time a real match stacked two Longbows. The
-- refusal was right; the ceiling it protected was wrong.
local function test_wide_query()
  local world, modules = fresh_world(tick_module)
  for _ = 1, 400 do
    tick_module.advance(world)
  end

  local cell = world.grid.cell
  local found = 0
  local anchor_x, anchor_y = world.map.node[world.map.library_node[1]].x,
                             world.map.node[world.map.library_node[1]].y
  modules.targeting.for_each_near(world, anchor_x, anchor_y, cell * 2.5, function()
    found = found + 1
  end)

  local by_hand = 0
  local reach = (cell * 2.5) ^ 2
  for id = 1, world.high_water do
    if world.soldier.alive[id] == 1 then
      local dx = world.soldier.x[id] - anchor_x
      local dy = world.soldier.y[id] - anchor_y
      if dx * dx + dy * dy <= reach then
        by_hand = by_hand + 1
      end
    end
  end

  check("a query wider than the grid's cell still finds everything",
        found == by_hand,
        string.format("grid found %d, walking every body found %d", found, by_hand))
end
-- }}}

-- {{{ local function test_placement_moves_a_frontline()
-- The premise. If stacking a lane does not move a frontline, nothing else here
-- matters.
local function test_placement_moves_a_frontline()
  local function play(stack_into, ticks)
    local world, modules, parameters = fresh_world(tick_module)
    while world.tick < ticks do
      if not tick_module.advance(world) then break end
      if stack_into ~= 0 then
        for kind = 1, #parameters.upgrade.kind do
          while world.team[1].chest[kind] > 0 do
            modules.commands.verb.place_in_lane(world, {
              team = 1, kind = kind, lane = stack_into})
          end
        end
      end
    end
    return world
  end

  local untouched = play(0, 12000)
  local stacked   = play(2, 12000)

  check("stacking a lane pushes its frontline further than leaving it alone",
        stacked.team[1].push_depth[2] > untouched.team[1].push_depth[2],
        string.format("untouched reached %d, stacked reached %d",
          untouched.team[1].push_depth[2], stacked.team[1].push_depth[2]))
end
-- }}}

-- {{{ local function test_formation_turns_a_corner()
-- A wave marching round a bend must arrive on the far side still in its ranks.
--
-- This is what holding a formation in lane coordinates buys, and it is worth a
-- test because the alternative fails so quietly: held in world coordinates a
-- turning rank either tears apart or scythes through the inside of the bend, and
-- both look like "the soldiers are a bit scruffy" rather than like a bug.
local function test_formation_turns_a_corner()
  local world, modules = fresh_world(tick_module)
  local soldier = world.soldier

  -- An unopposed march: the far team and every tower removed, so one wave can be
  -- watched the whole way round without a fight breaking its shape for reasons
  -- that are supposed to break its shape.
  for _, structure in ipairs(world.structure) do
    structure.alive = 0
  end

  local watched, worst_lag, saw_bend = 0, 0, false
  local before_box, after_box = 0, 0

  for _ = 1, 2400 do
    tick_module.advance(world)
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.team[id] == 2 then
        world.release(world, id)
      end
    end
    if watched == 0 then
      for _, wave in ipairs(world.wave) do
        if wave.team == 1 and wave.lane == 1 then
          watched = wave.id
          break
        end
      end
    end
    if watched ~= 0 then
      local wave = world.wave[watched]
      local min_x, max_x, min_y, max_y = math.huge, -math.huge, math.huge, -math.huge
      local alive = 0
      for id = 1, world.high_water do
        if soldier.alive[id] == 1 and soldier.wave[id] == watched then
          alive = alive + 1
          local lag = math.abs(wave.lag_of[id] or 0)
          if lag > worst_lag then worst_lag = lag end
          if soldier.x[id] < min_x then min_x = soldier.x[id] end
          if soldier.x[id] > max_x then max_x = soldier.x[id] end
          if soldier.y[id] < min_y then min_y = soldier.y[id] end
          if soldier.y[id] > max_y then max_y = soldier.y[id] end
        end
      end
      if alive > 0 then
        local box = (max_x - min_x) * (max_y - min_y)
        if wave.anchor < 900 then before_box = box end
        if wave.anchor > 1550 then after_box = box ; saw_bend = true end
      end
    end
  end

  check("a wave marching round a bend keeps its ranks",
        worst_lag < 12,
        string.format("worst lag through the turn was %.1f paces", worst_lag))

  -- The formation is a block, and a block turning ninety degrees stays about the
  -- same area while its sides swap. A formation that tore apart would grow.
  check("the formation turns rather than stretching",
        saw_bend and after_box < before_box * 1.8,
        string.format("box area %.0f before the bend, %.0f after", before_box, after_box))
end
-- }}}

-- {{{ local function test_cohesion_is_conserved()
-- The speed a straggler gains is taken from somebody, and the books balance every
-- tick.
--
-- Stated as a property because it is easy to write a cohesion rule that only ever
-- hands speed out -- and a wave whose every member is quietly being hurried is a
-- wave that is faster than its catalogue says, which nothing else in the game
-- would ever report.
local function test_cohesion_is_conserved()
  local world = fresh_world(tick_module)
  local soldier = world.soldier

  local worst_error, worst_where = 0, ""
  for _ = 1, 2500 do
    tick_module.advance(world)
    for _, wave in ipairs(world.wave) do
      -- Read the balance the wave recorded when it shared the budget out, not one
      -- recomputed afterwards. Bodies die between the sharing and the looking, and
      -- a surviving subset of a balanced set is not itself balanced.
      local shared = wave.speed_shared_among
      if shared ~= nil and shared > 1 then
        local error = math.abs(wave.speed_balance) / shared
        if error > worst_error then
          worst_error = error
          worst_where = string.format("wave %d, shared among %d, off by %.3f",
            wave.id, shared, wave.speed_balance)
        end
      end
    end
  end

  -- Not exactly zero: the clamps at either end are allowed to break conservation,
  -- and they are supposed to -- a straggler that could sprint would read as
  -- teleporting. What must not happen is a systematic drift.
  check("the cohesion budget is shared out, not handed out",
        worst_error < 0.16,
        string.format("worst imbalance %.1f%% -- %s", worst_error * 100, worst_where))
end
-- }}}

-- {{{ local function test_no_nil_fields()
-- Nil is not an option. Every per-body array must hold a number in every slot it
-- has ever used, because the simulation has no nil checks in it and is only safe
-- for that reason.
local function test_no_nil_fields()
  local world = fresh_world(tick_module)
  for _ = 1, 900 do
    tick_module.advance(world)
  end

  local offenders = {}
  for name, array in pairs(world.soldier) do
    if name ~= "upgrade_count" then
      for id = 1, world.high_water do
        if type(array[id]) ~= "number" then
          offenders[#offenders + 1] = name .. "[" .. id .. "]"
          break
        end
      end
    end
  end

  check("no per-body field is ever nil",
        #offenders == 0,
        table.concat(offenders, ", "))
end
-- }}}

print("")
print("the invariants")
print("")
test_map_mirror()
test_camera_anchor()
test_camera_home()
test_camera_floor()
test_wide_query()
test_no_nil_fields()
test_formation_turns_a_corner()
test_cohesion_is_conserved()
test_reproducibility()
test_placement_moves_a_frontline()
print("")
print(string.format("%d passed, %d failed", passed, failed))
print("")

if failed > 0 then
  os.exit(1)
end
