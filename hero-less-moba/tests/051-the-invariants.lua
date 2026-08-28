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

-- {{{ local function test_a_match_ends()
-- Left entirely alone, a match must finish.
--
-- This is the phase table's whole reason for existing. Without it two even teams
-- grind for as long as anybody is willing to watch -- which is not a stalemate the
-- design is trying to produce, it is the absence of an ending. **The deadline is
-- the walk**: the third monster cannot be killed, and it arrives.
--
-- The test asserts the arc as well as the ending, because a match that ended for
-- some other reason -- a lucky push, an arithmetic overflow -- would pass a bare
-- "did it stop" check while proving nothing.
local function test_a_match_ends()
  local world = fresh_world(tick_module)
  local seen = {surge = 0, challenge = 0, calm = 0, slain = 0}

  -- Nobody playing. The arc below is a statement about the **phase clock**, and a
  -- bot that wins in the second challenge would end the match before the third one
  -- arrives -- which is correct behaviour and would still fail an assertion about
  -- three of everything.
  --
  -- That is not a hypothetical. It is what happened the first time something was
  -- put behind both teams, and the test was wrong rather than the game.
  world.bot = {}

  local limit = 60000
  while world.tick < limit do
    if not tick_module.advance(world) then
      break
    end
    for _, event in ipairs(world.event) do
      if event.name == "surge_began" then seen.surge = seen.surge + 1 end
      if event.name == "challenge_began" then seen.challenge = seen.challenge + 1 end
      if event.name == "calm_began" then seen.calm = seen.calm + 1 end
      if event.name == "monster_slain" then seen.slain = seen.slain + 1 end
    end
  end

  check("a match left alone reaches an ending",
        world.winner ~= 0,
        string.format("still running at tick %d", world.tick))

  check("and gets there through three surges and three challenges",
        seen.surge == 3 and seen.challenge == 3,
        string.format("%d surges, %d challenges, %d calms, %d monsters slain",
          seen.surge, seen.challenge, seen.calm, seen.slain))

  check("the first two monsters die and the third does not",
        seen.slain == 4,
        string.format("%d monsters slain -- two per challenge for the first two, " ..
                      "and none for the Golem", seen.slain))
end
-- }}}

-- {{{ local function test_a_played_match_is_decisive()
-- With something making decisions, a match should be **won**, not drawn.
--
-- Two passive sides are exact mirrors and both Golems arrive at both libraries on
-- the same tick, which is a draw and is the right answer to a match nobody played.
-- The moment anybody places anything, that symmetry is gone -- and if it were not,
-- the chest would not be doing anything.
local function test_a_played_match_is_decisive()
  local world = fresh_world(tick_module)

  local limit = 60000
  while world.tick < limit do
    if not tick_module.advance(world) then
      break
    end
  end

  local placed = 0
  for team = 1, 2 do
    local _, in_lanes, in_stone = world.chest.total_held(world, team)
    placed = placed + in_lanes + in_stone
  end

  check("a match somebody plays is won rather than drawn",
        world.winner == 1 or world.winner == 2,
        world.winner == 3 and "it was a draw -- nothing broke the symmetry"
                          or string.format("still running at tick %d", world.tick))

  check("and the chest was actually used to do it",
        placed > 60,
        string.format("only %d upgrades ever left a chest", placed))
end
-- }}}

-- {{{ local function test_the_surge_deals_everything()
-- During a surge a body carries **a share of everything the team owns**, not the
-- contents of the lane it is walking down.
--
-- And nothing is taken to do it. The slots still hold exactly what they held --
-- upgrades are never moved except by a player's own hand, and an earlier draft of
-- this design confiscated the board for the duration and handed it back, which was
-- frustrating in a way nothing bought back.
local function test_the_surge_deals_everything()
  local world, modules, parameters = fresh_world(tick_module)

  -- Give one team something to be dealt, all of it in a lane nobody will spawn a
  -- surge body into by accident.
  --
  -- Placed by hand rather than through the command queue, because a placement takes
  -- a full wave to land and this test is about the surge rather than about transit.
  modules.stones.draw(world, 1, 8)
  for _, stone in ipairs(world.stone[1]) do
    stone.slot_kind = modules.stones.IN_LANE
    stone.slot_lane = 3
  end
  modules.stones.rebuild_counts(world, 1)
  local placed_before = 0
  for kind = 1, #parameters.upgrade.kind do
    placed_before = placed_before + world.team[1].lane_slot[3][kind]
  end

  -- Run to the first surge.
  while world.phase ~= 2 and world.tick < 20000 do
    tick_module.advance(world)
  end
  for _ = 1, 60 do
    tick_module.advance(world)
  end

  local soldier = world.soldier
  local carried_outside_lane_three = 0
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.team[id] == 1
       and soldier.lane[id] ~= 3 and soldier.wave[id] == 0 then
      for kind = 1, #parameters.upgrade.kind do
        carried_outside_lane_three = carried_outside_lane_three + soldier.upgrade_count[kind][id]
      end
    end
  end

  local placed_after = 0
  for kind = 1, #parameters.upgrade.kind do
    placed_after = placed_after + world.team[1].lane_slot[3][kind]
  end

  check("a surge deals the whole holding to bodies in every lane",
        carried_outside_lane_three > 0,
        "bodies outside the stacked lane carried nothing")

  -- Never **fewer**, rather than exactly the same. The first version of this
  -- asserted equality and was right until something started playing: **placement
  -- stays open during a surge**, and a bot placing into that lane while the test
  -- watched made the count go up. Going up is the phase working. What must never
  -- happen is going down, because that would be the surge taking something.
  check("and takes nothing out of the slots to do it",
        placed_after >= placed_before,
        string.format("lane 3 held %d before the surge and %d during it",
          placed_before, placed_after))
end
-- }}}

-- {{{ local function test_the_opening_is_symmetric()
-- The match is **set up** as a mirror. It is not kept that way.
--
-- This used to be written as "the two teams' states are exact mirrors at every
-- tick", which is a much stronger claim and the wrong one. Two even sides diverge
-- almost immediately and are supposed to: a tie broken one way in one lane is
-- broken the other way in another, and by the second exchange the two halves of the
-- field are different games. Holding the mirror past the opening would cost a
-- canonical ordering on every tie in the hottest loop in the simulation, bought to
-- preserve something with no gameplay meaning after the first ten seconds.
--
-- So: set it up symmetrically, and let it go.
local function test_the_opening_is_symmetric()
  local world, modules = fresh_world(tick_module)
  local soldier = world.soldier
  local problems = {}

  -- Stone. Both teams, same kinds, same milestones, same health.
  local mine, theirs = {}, {}
  for _, structure in ipairs(world.structure) do
    local key = structure.kind .. ":" .. structure.lane .. ":" .. structure.milestone
    local into = (structure.team == 1) and mine or theirs
    into[key] = (into[key] or 0) + structure.health_max
  end
  for key, value in pairs(mine) do
    if math.abs((theirs[key] or 0) - value) > 0.0001 then
      problems[#problems + 1] = "stone differs at " .. key
    end
  end
  for key in pairs(theirs) do
    if mine[key] == nil then
      problems[#problems + 1] = "team 2 has stone at " .. key .. " and team 1 does not"
    end
  end

  -- Wallets, chests and slots all start empty and equal.
  for colour = 1, world.colour_count do
    if world.player[1].points[colour] ~= world.player[world.parameters.team_size + 1].points[colour] then
      problems[#problems + 1] = "wallets do not start equal"
    end
  end

  -- Run to just after the first wave and check that the same bodies left both
  -- bases, in the same shape, the same distance from their own end.
  local settings = world.parameters.unit.wave
  for _ = 1, settings.first_at + 40 do
    tick_module.advance(world)
  end

  local shape = {{}, {}}
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.flavour[id] == 1 and soldier.lane[id] ~= 0 then
      local lane = world.map.lane[soldier.lane[id]]
      -- Distance from its **own** library, so the two teams are described in the
      -- same terms rather than in the path array's.
      local from_home = (soldier.team[id] == 1) and soldier.lane_along[id]
                                                 or (lane.length - soldier.lane_along[id])
      local key = string.format("%d:%d:%.2f:%.2f", soldier.lane[id], soldier.archetype[id],
                                from_home, soldier.lane_across[id])
      local into = shape[soldier.team[id]]
      into[key] = (into[key] or 0) + 1
    end
  end

  for key, count in pairs(shape[1]) do
    if shape[2][key] ~= count then
      problems[#problems + 1] = "the first waves differ at " .. key
    end
  end
  for key in pairs(shape[2]) do
    if shape[1][key] == nil then
      problems[#problems + 1] = "team 2's first wave has " .. key .. " and team 1's does not"
    end
  end

  check("the opening is a mirror -- same stone, same wallets, same first wave",
        #problems == 0, problems[1])
end
-- }}}

-- {{{ local function test_an_unchosen_boon_waits()
-- A boon nobody picked stays on offer. Nothing takes it for them.
--
-- The rule this replaces was the only place in the project where something decided
-- for a player, and the alternative that looked best was worse: taking it but
-- allowing a swap makes *never choosing* the correct play -- let the timer run out,
-- see how the match develops, then swap into whatever turned out to matter.
--
-- Being slow costs you the use of it in the meantime and costs your team nothing.
local function test_an_unchosen_boon_waits()
  local world = fresh_world(tick_module)
  -- Nobody playing, so nobody picks.
  world.bot = {}

  local offered_at, still_open_at = 0, 0
  local watched = 1

  for _ = 1, 20000 do
    if not tick_module.advance(world) then break end
    if offered_at == 0 and world.boon_offer[watched] ~= nil then
      offered_at = world.tick
    end
    -- Well past the end of the calm it was offered in.
    if offered_at > 0 and world.tick > offered_at + world.parameters.boon.timing.calm + 600 then
      if world.boon_offer[watched] ~= nil then
        still_open_at = world.tick
      end
      break
    end
  end

  check("a boon nobody chose is still on offer long after the calm ends",
        offered_at > 0 and still_open_at > 0,
        offered_at == 0 and "no boon was ever offered"
          or "the offer was taken away or taken for them")

  check("and no team was granted a boon it did not choose",
        #world.boons[1] == 0 and #world.boons[2] == 0,
        string.format("team 1 holds %d boons and team 2 holds %d, with nobody playing",
          #world.boons[1], #world.boons[2]))
end
-- }}}

-- {{{ local function test_a_move_takes_a_wave()
-- **An upgrade does not arrive the instant you place it.**
--
-- It is marked to move and takes one full wave to get there, applying at its **old**
-- slot the whole time, so a placement lands two waves after the command with one
-- wave of unchanged behaviour in between.
--
-- That delay is the entire negotiation layer. A team that could move every stone
-- every tick would simply keep all of them wherever the fighting currently is, and
-- there would be nothing to lock, object to, or argue about -- which is why the delay
-- gets a test rather than being left as a number somebody might tune to zero.
local function test_a_move_takes_a_wave()
  local world, modules = fresh_world(tick_module)
  world.bot = {}

  modules.stones.draw(world, 1, 1)
  local stone = world.stone[1][1]
  local kind = stone.kind
  local holder = stone.held_by

  local verdict = modules.stones.place(world, holder, stone.id,
                                       modules.stones.IN_LANE, 2)
  check("a stone can be marked to move", verdict.accepted, verdict.reason)

  check("and it is still in the chest the instant after",
        stone.slot_kind == modules.stones.IN_CHEST
          and world.team[1].chest[kind] == 1,
        "it moved immediately")

  -- Run until the wave after next.
  local started = world.wave_turn
  while world.wave_turn < started + 1 do
    tick_module.advance(world)
  end
  check("and still in the chest after one wave",
        stone.slot_kind == modules.stones.IN_CHEST,
        "it arrived a wave early")

  while world.wave_turn < started + 2 do
    tick_module.advance(world)
  end
  check("and lands on the second",
        stone.slot_kind == modules.stones.IN_LANE and stone.slot_lane == 2
          and world.team[1].lane_slot[2][kind] == 1,
        string.format("it is in slot kind %d lane %d", stone.slot_kind, stone.slot_lane))
end
-- }}}

-- {{{ local function test_a_move_can_be_called_back()
-- Cancelling costs nothing and can be done any time before it lands.
--
-- Nothing was spent and the stone has been applying at its old slot the whole time,
-- so refusing would punish a misclick with a full wave of watching a mistake crawl
-- toward you, for nobody's benefit.
local function test_a_move_can_be_called_back()
  local world, modules = fresh_world(tick_module)
  world.bot = {}

  modules.stones.draw(world, 1, 1)
  local stone = world.stone[1][1]
  local holder = stone.held_by

  modules.stones.place(world, holder, stone.id, modules.stones.IN_LANE, 2)
  local verdict = modules.stones.cancel(world, holder, stone.id)
  check("a move can be called back", verdict.accepted, verdict.reason)

  local started = world.wave_turn
  while world.wave_turn < started + 3 do
    tick_module.advance(world)
  end
  check("and then it simply stays where it was",
        stone.slot_kind == modules.stones.IN_CHEST and stone.arrives_turn == 0,
        "it went anyway")
end
-- }}}

-- {{{ local function test_the_floor_closes()
-- The failure of a communal pool is not theft, it is **neglect** -- three people each
-- quietly assuming somebody else has it in hand.
--
-- So a dismissed stone vanishes from that player's view, and **when everybody has
-- dismissed the same stone it comes back to all of them.** A stone cannot fall
-- through the floor, because the floor closes: the moment nobody is looking at it,
-- everybody is.
local function test_the_floor_closes()
  local world, modules = fresh_world(tick_module)
  world.bot = {}

  modules.stones.draw(world, 1, 1)
  local stone = world.stone[1][1]
  local team_players = world.team_players[1]
  local owner = stone.held_by

  -- A stone somebody owns cannot be set aside by anybody -- there is nothing to
  -- neglect, because exactly one person is responsible for it.
  local verdict = modules.stones.dismiss(world, team_players[1], stone.id)
  check("a stone somebody owns cannot be set aside",
        not verdict.accepted, "it was dismissed while still owned")

  modules.stones.contribute(world, owner, stone.id)
  check("but it can be given to the pool",
        stone.held_by == modules.stones.COMMUNAL, "it stayed owned")

  -- Everybody but the last one sets it aside.
  for index = 1, #team_players - 1 do
    modules.stones.dismiss(world, team_players[index], stone.id)
  end
  local still_seen = 0
  for _, number in ipairs(team_players) do
    if modules.stones.visible_to(world, stone, number) then
      still_seen = still_seen + 1
    end
  end
  check("each dismissal removes it from one player's view and nobody else's",
        still_seen == 1,
        string.format("%d of %d players can still see it", still_seen, #team_players))

  -- And the last one.
  modules.stones.dismiss(world, team_players[#team_players], stone.id)
  local seen_again = 0
  for _, number in ipairs(team_players) do
    if modules.stones.visible_to(world, stone, number) then
      seen_again = seen_again + 1
    end
  end
  check("and when everybody has set it aside, it comes back to all of them",
        seen_again == #team_players and stone.dismissed_mask == 0,
        string.format("%d of %d can see it", seen_again, #team_players))
end
-- }}}

-- {{{ local function test_giving_is_easier_than_asking()
-- Offering transfers a stone. Requesting changes nothing at all.
--
-- Requesting is deliberately the weakest verb here, and it exists for a reason worth
-- keeping: **refusing to build it does not prevent it.** Players will ask over voice,
-- where the design cannot rate-limit it and cannot make it ignorable without
-- awkwardness. So it exists, one at a time, and ignoring one is free and silent --
-- there is nothing anybody can bring up later.
local function test_giving_is_easier_than_asking()
  local world, modules = fresh_world(tick_module)
  world.bot = {}

  modules.stones.draw(world, 1, 2)
  local stone = world.stone[1][1]
  local players = world.team_players[1]
  local owner = stone.held_by
  local other = 0
  for _, number in ipairs(players) do
    if number ~= owner then other = number break end
  end

  local asked = modules.stones.request(world, other, stone.id)
  check("a request can be made", asked.accepted, asked.reason)
  check("and changes nothing by itself",
        stone.held_by == owner, "asking moved it")

  -- Nobody may take it, including the person who asked.
  local taken = modules.stones.place(world, other, stone.id, modules.stones.IN_LANE, 1)
  check("and nobody can take a stone that is not theirs",
        not taken.accepted, "somebody else moved it")

  local given = modules.stones.offer(world, owner, stone.id, other)
  check("but the owner can give it", given.accepted, given.reason)
  check("and then it is theirs to place",
        stone.held_by == other
          and modules.stones.place(world, other, stone.id, modules.stones.IN_LANE, 1).accepted,
        "the transfer did not take")
end
-- }}}

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
--
-- Measured **within one run**, comparing the stacked lane against the two beside it,
-- rather than between two runs. Two runs of a game with a fight in it diverge for
-- their own reasons, and the earlier version of this test spent its time measuring
-- that divergence instead of the chest.
--
-- Stopped before the first surge, for the same reason. During a challenge every
-- lane's waves are recorded as the centre's and push depth is ignored outright, so a
-- comparison that runs past one is comparing two different things.
local function test_placement_moves_a_frontline()
  local world, modules, parameters = fresh_world(tick_module)
  world.bot = {}

  local stack_into = 2
  local before_the_surge = parameters.boon.timing.first_normal - 200

  while world.tick < before_the_surge do
    tick_module.advance(world)
    -- Everything team 1 draws goes into one lane, at once. The transit delay is a
    -- real rule tested elsewhere; here it would only mean the lane lags two waves
    -- behind the thing being measured.
    local moved = false
    for _, stone in ipairs(world.stone[1]) do
      if stone.slot_kind ~= modules.stones.IN_LANE or stone.slot_lane ~= stack_into then
        stone.slot_kind = modules.stones.IN_LANE
        stone.slot_lane = stack_into
        stone.arrives_turn = 0
        moved = true
      end
    end
    if moved then
      modules.stones.rebuild_counts(world, 1)
    end
  end

  local stacked = world.team[1].push_depth[stack_into]
  local others = 0
  local lanes = 0
  for lane = 1, parameters.lane_count do
    if lane ~= stack_into then
      others = others + world.team[1].push_depth[lane]
      lanes = lanes + 1
    end
  end
  local average_elsewhere = others / lanes

  local held = 0
  for kind = 1, #parameters.upgrade.kind do
    held = held + world.team[1].lane_slot[stack_into][kind]
  end

  check("the stacked lane actually holds the upgrades",
        held > 4, string.format("only %d upgrades ended up in it", held))

  check("and its frontline is further forward than the lanes beside it",
        stacked > average_elsewhere,
        string.format("stacked lane reached %d, the others averaged %.1f",
          stacked, average_elsewhere))
end
-- }}}

-- {{{ local function test_every_hero_is_buyable()
-- The colours in circulation must be able to pay for the heroes on offer.
--
-- The bug this exists for was silent in the worst way. Both commanders paid might
-- and neither paid wit, so two of the five heroes on one of their own rosters could
-- not be bought in any match ever -- not rarely, not expensively: never, with no
-- refusal to read, because nobody could get far enough to be refused. Nothing in
-- the game would have reported it and nothing in a playtest would have looked like
-- anything except those heroes being unpopular.
local function test_every_hero_is_buyable()
  local modules = tick_module.load_cast(ROOT)
  local parameters = modules.match_parameters.load()
  local catalogue = parameters.commander

  -- Every colour any commander pays out, since a match fields all of them.
  local in_circulation = {}
  for _, commander in ipairs(catalogue.commander) do
    for colour in pairs(commander.bounty) do
      in_circulation[colour] = true
    end
  end

  local unpayable = {}
  for _, commander in ipairs(catalogue.commander) do
    for _, row in ipairs(commander.roster) do
      local cost = catalogue.hero_cost[row]
      if cost == nil then
        unpayable[#unpayable + 1] = parameters.unit.archetype[row].name .. " has no price"
      else
        for colour in pairs(cost) do
          if not in_circulation[colour] then
            unpayable[#unpayable + 1] = string.format("%s wants %s, which nobody pays",
              parameters.unit.archetype[row].name, catalogue.colour[colour].name)
          end
        end
      end
    end
  end

  check("every hero on every roster can be paid for",
        #unpayable == 0, unpayable[1])
end
-- }}}

-- {{{ local function test_a_hero_obeys_one_signpost()
-- A hero takes the branch a sign points at, and then goes straight on at every
-- junction for the rest of its life.
--
-- That one rule is the whole reason this is not a routing system, so it is worth a
-- test of its own: without it there would be nothing stopping a player chaining
-- posts to walk a body round the anti-diagonal.
local function test_a_hero_obeys_one_signpost()
  local world, modules = fresh_world(tick_module)
  local soldier = world.soldier

  -- Nobody playing, and no stone. What is being tested is whether a hero reads the
  -- sign at its junction -- not whether one can fight its way there alone. The
  -- junction sits at the midpoint of the lane, which is exactly where a live match
  -- puts its frontline, so a hero walking up on its own dies just short of the thing
  -- under test and the failure says "it never turned" rather than "it never arrived".
  world.bot = {}
  for _, structure in ipairs(world.structure) do
    structure.alive = 0
  end

  -- Point team 1's top-lane post at its connector, then buy a hero into that lane
  -- with a full wallet.
  modules.signposts.cycle(world, 1, 1, 1)
  for colour = 1, world.colour_count do
    world.player[1].points[colour] = 12
  end
  local roster = world.parameters.commander.commander[world.player[1].commander].roster
  local verdict = modules.commanders.buy(world, 1, roster[1], "library", 0)

  -- The library sends a hero to the worst-pressed lane, which need not be the top
  -- one. Put it in the top lane explicitly so the sign is the thing being tested.
  local id = verdict.id
  local lane = world.map.lane[1]
  soldier.lane[id] = 1
  soldier.path_index[id] = 1
  modules.walking.set_lane_position(world, id, 0, 0)

  local crossed, rejoined_lane = false, 0
  for _ = 1, 4000 do
    tick_module.advance(world)
    -- Keep the far side off the board, so the walk is about the sign and nothing
    -- else. Waves keep spawning; they simply do not survive to interfere.
    for other = 1, world.high_water do
      if soldier.alive[other] == 1 and soldier.team[other] == 2 then
        world.release(world, other)
      end
    end
    if soldier.alive[id] ~= 1 then
      break
    end
    if soldier.crossing[id] ~= 0 then
      crossed = true
    elseif crossed and rejoined_lane == 0 then
      rejoined_lane = soldier.lane[id]
    end
  end

  check("a hero obeys the sign at its junction and crosses to the next lane",
        crossed, "it never left the top lane")
  check("and comes out on the centre lane, with its one turn spent",
        rejoined_lane == 2 and soldier.turns_left[id] == 0,
        string.format("rejoined lane %d, turns left %d",
          rejoined_lane, soldier.turns_left[id] or -1))
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

-- {{{ local function test_the_menu_can_be_bypassed()
-- Every path the menu offers must be reachable without it.
--
-- The requirement is issue 707's, and it is a requirement rather than a
-- convenience: the batch runner and every automated test start a game with nobody
-- present, thousands of times, and **a menu that cannot be bypassed is a menu that
-- gets bypassed by a second code path nobody tests**. Two start-up paths drift.
--
-- The bug this is the regression for: asking for a screenshot of a scenario opened
-- an ordinary match instead, because the capture question was asked before the
-- named-start question. Nothing about the picture said so -- it looked like a game.
-- A wrong answer here is invisible by construction, so it has to be asserted.
--
-- Note what this loads: the viewer, with no window anywhere. That is the point of
-- the decision being a pure function separate from acting on it.
local function test_the_menu_can_be_bypassed()
  local viewer = loadfile(ROOT .. "/src/050-the-viewer.lua")()

  local opening = viewer.choose_opening(nil, false, false)
  check("with nobody saying anything, the way in is the menu", opening == "menu",
        tostring(opening))

  opening = viewer.choose_opening("match", false, false)
  check("and a named match skips it", opening == "match", tostring(opening))

  local name
  opening, name = viewer.choose_opening("scenario:the-dragon-at-the-midpoint",
                                        false, false)
  check("and a named scenario skips it, carrying its name",
        opening == "scenario" and name == "the-dragon-at-the-midpoint",
        tostring(opening) .. " / " .. tostring(name))

  opening, name = viewer.choose_opening("scenario:the-dragon-at-the-midpoint",
                                        true, false)
  check("and a camera pointed at a scenario still gets the scenario",
        opening == "scenario" and name == "the-dragon-at-the-midpoint",
        tostring(opening) .. " / " .. tostring(name))

  opening = viewer.choose_opening(nil, true, false)
  check("a camera with nothing named gets an ordinary match to photograph",
        opening == "match", tostring(opening))

  opening = viewer.choose_opening(nil, true, true)
  check("and a camera pointed at the menu gets the menu", opening == "menu",
        tostring(opening))

  -- A malformed start leaves the menu up rather than guessing, because the menu is
  -- where a person can see what happened. "scenario:" with nothing after it is the
  -- shape a shell produces from an empty variable.
  opening = viewer.choose_opening("scenario:", false, false)
  check("and a start naming no scenario leaves the menu up", opening == "menu",
        tostring(opening))
end
-- }}}

-- {{{ local function test_the_bypass_reaches_the_gate()
-- And the far end of it: a named scenario, loaded, actually arrives somewhere.
--
-- The chooser test above proves the right door is opened. This proves there is a
-- room behind it -- the described world is applied, the clock has jumped, and what
-- the scenario asked for is standing in the world. Held, and not yet advanced.
local function test_the_bypass_reaches_the_gate()
  local world, modules = fresh_world(tick_module)
  local path = ROOT .. "/scenarios/the-dragon-at-the-midpoint"

  modules.gate.load(world, path)

  -- The scenario names tick 14000 and challenge 2. Both have to have landed, and
  -- the clock is the one that catches a gate that silently did nothing: a fresh
  -- world is at tick 0, so any number here at all means the file was read.
  check("a scenario loaded at the gate moves the clock to where it says",
        world.tick == 14000, "tick " .. tostring(world.tick))
  check("and the described phase is the one standing when it opens",
        world.phase == 3 and world.challenge_index == 2,
        "phase " .. tostring(world.phase) ..
        ", challenge " .. tostring(world.challenge_index))

  -- The monster the scenario is named after. Its team is the monsters' own, which
  -- is the third team and not either player's.
  local monsters = 0
  for id = 1, world.high_water do
    if world.soldier.alive[id] == 1 and world.soldier.team[id] == 3 then
      monsters = monsters + 1
    end
  end
  check("and the monster it is named after is standing in it", monsters > 0,
        tostring(monsters) .. " on the monsters' team")

  -- Held. The gate's whole reason for existing is that the most useful moment is
  -- almost always the tick before something goes wrong, and a world that starts
  -- running when it loads cannot be looked at then.
  local before = world.tick
  modules.gate.step(world, tick_module, 1)
  check("and it was standing still until something asked it to move",
        world.tick == before + 1,
        tostring(before) .. " then " .. tostring(world.tick))
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
test_every_hero_is_buyable()
test_a_hero_obeys_one_signpost()
test_no_nil_fields()
test_formation_turns_a_corner()
test_cohesion_is_conserved()
test_the_opening_is_symmetric()
test_an_unchosen_boon_waits()
test_a_move_takes_a_wave()
test_a_move_can_be_called_back()
test_the_floor_closes()
test_giving_is_easier_than_asking()
test_reproducibility()
test_placement_moves_a_frontline()
test_the_surge_deals_everything()
test_a_match_ends()
test_a_played_match_is_decisive()
test_the_menu_can_be_bypassed()
test_the_bypass_reaches_the_gate()
print("")
print(string.format("%d passed, %d failed", passed, failed))
print("")

if failed > 0 then
  os.exit(1)
end
