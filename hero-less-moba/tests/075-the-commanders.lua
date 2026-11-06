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

-- 075-the-commanders.lua
--
-- covers: 501, 504, 505, 506, 507, 509, 510
--
-- The commanders, their heroes and what the heroes do, asked of a world that has
-- barely ticked.
--
-- **Small worlds on purpose.** Every check here builds a fresh match and then puts
-- bodies exactly where the question needs them, rather than playing a match and
-- hoping the situation turns up. A purchase refused because an enemy stood in a
-- tower's radius is a thing a long match produces eventually and a thing a test can
-- produce in two lines -- and only the second one fails the same way twice.
--
-- What 051 already asks of commanders -- that killing pays the whole team (502), that
-- a hero is a soldier you bought (503) and that sign-posts stand at the corners (508)
-- -- is not asked again here.

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

local tick_module = loadfile(ROOT .. "/src/042-the-tick.lua")()

-- {{{ local function fresh_world()
-- A match with nobody playing it. The bots are switched off so that nothing buys,
-- pings or places anything the test did not ask for.
local function fresh_world()
  local modules = tick_module.load_cast(ROOT)
  local parameters = modules.match_parameters.load()
  local world = tick_module.assemble(modules, parameters)
  world.bot = {}
  world.event = {}
  return world, modules, parameters
end
-- }}}

-- {{{ local function put()
-- One body of the given row, standing still at a point, in no lane.
local function put(world, row, team, x, y)
  local id = world.allocate(world)
  world.give_body(world, id, world.parameters.unit.archetype[row])
  local soldier = world.soldier
  soldier.team[id] = team
  soldier.archetype[id] = row
  soldier.lane[id] = 0
  soldier.x[id], soldier.y[id] = x, y
  return id
end
-- }}}

-- {{{ local function fill_wallet()
-- Enough of every colour to buy anything, so a test about *where* a hero goes is not
-- quietly a test about whether it could be paid for.
local function fill_wallet(world, number)
  local player = world.player[number]
  for colour = 1, world.colour_count do
    player.points[colour] = 12
    player.points_max[colour] = 12
  end
  return player
end
-- }}}

-- {{{ local function wallet_total()
local function wallet_total(player)
  local total = 0
  for _, amount in ipairs(player.points) do
    total = total + amount
  end
  return total
end
-- }}}

-- {{{ local function events_named()
local function events_named(world, name)
  local found = {}
  for _, event in ipairs(world.event) do
    if event.name == name then
      found[#found + 1] = event
    end
  end
  return found
end
-- }}}

-- {{{ local function structure_at()
local function structure_at(world, team, lane, milestone)
  for id, structure in ipairs(world.structure) do
    if structure.team == team and structure.lane == lane and structure.milestone == milestone then
      return id, structure
    end
  end
  error(string.format("no structure for team %d, lane %d, milestone %d", team, lane, milestone))
end
-- }}}

-- {{{ local function test_the_catalogue()
-- 501. A commander is a name and a roster, and the roster is where they differ.
--
-- Also how they are dealt. The deal is checked from both sides because the bug it
-- once had looked fine from one: dealing across all six seats gave one team two
-- paladins and the other two nobles, an asymmetric match before anyone had moved.
local function test_the_catalogue()
  local world, modules, parameters = fresh_world()
  local catalogue = parameters.commander
  local archetype = parameters.unit.archetype

  local problem
  for id, commander in ipairs(catalogue.commander) do
    if type(commander.name) ~= "string" then
      problem = "commander " .. id .. " has no name"
    elseif #commander.roster < 3 then
      problem = commander.name .. " offers fewer than three heroes"
    elseif archetype[commander.captain] == nil or archetype[commander.captain].flavour ~= 1 then
      problem = commander.name .. "'s captain is not a wave row"
    end
    for _, row in ipairs(commander.roster) do
      if archetype[row] == nil or archetype[row].flavour ~= 2 then
        problem = problem or (commander.name .. " offers row " .. row .. ", which is not a hero")
      elseif catalogue.hero_cost[row] == nil then
        problem = problem or (archetype[row].name .. " has no price")
      end
    end
    for colour in pairs(commander.bounty) do
      if catalogue.colour[colour] == nil then
        problem = problem or (commander.name .. " pays a colour that does not exist")
      end
    end
  end
  check("every commander has a name, a wave captain and at least three priced heroes",
        problem == nil, problem)

  -- The deal. Seat n on one team and seat n on the other hold the same commander.
  local per_team = parameters.team_size
  local mirrored = true
  for seat = 1, per_team do
    if world.player[seat].commander ~= world.player[seat + per_team].commander
       or world.player[seat].team ~= 1 or world.player[seat + per_team].team ~= 2 then
      mirrored = false
    end
  end
  check("the two teams are dealt the same hand, seat for seat", mirrored)

  local starts_empty = true
  for _, player in ipairs(world.player) do
    for colour = 1, world.colour_count do
      if player.points[colour] ~= 0 or player.points_max[colour] ~= catalogue.ceiling[1] then
        starts_empty = false
      end
    end
  end
  check("every wallet starts empty, at the first rung's ceiling", starts_empty)

  -- Commanders take turns sending waves: per_team waves in a row are sent by
  -- per_team different players of that team, and the next one comes round again.
  local seen, in_order = {}, true
  for wave_index = 1, per_team do
    local commander_id, number = modules.commanders.commander_for_wave(world, 2, wave_index)
    seen[number] = true
    if world.player[number].team ~= 2 or world.player[number].commander ~= commander_id then
      in_order = false
    end
  end
  local count = 0
  for _ in pairs(seen) do count = count + 1 end
  local _, first = modules.commanders.commander_for_wave(world, 2, 1)
  local _, again = modules.commanders.commander_for_wave(world, 2, per_team + 1)
  check("a team's waves are sent by each of its players in turn",
        in_order and count == per_team and first == again,
        string.format("%d distinct senders in %d waves", count, per_team))

  -- The bounty ratio is walked exactly, not sampled: one lap of the sequence holds
  -- each colour exactly as many times as the ratio says.
  local exact = true
  for id, commander in ipairs(catalogue.commander) do
    local sequence = world.bounty_sequence[id]
    local tally, total = {}, 0
    for _, colour in ipairs(sequence) do
      tally[colour] = (tally[colour] or 0) + 1
    end
    for colour, weight in pairs(commander.bounty) do
      total = total + weight
      if tally[colour] ~= weight then exact = false end
    end
    if #sequence ~= total then exact = false end
  end
  local body = put(world, 1, 1, 0, 0)
  local stamped = {}
  local sequence = world.bounty_sequence[1]
  for index = 1, #sequence * 2 do
    modules.commanders.stamp_bounty(world, body, 1, index)
    stamped[index] = world.soldier.bounty_colour[body]
  end
  for index = 1, #sequence do
    if stamped[index] ~= stamped[index + #sequence] then exact = false end
  end
  check("a body's bounty colour walks the commander's ratio exactly, and repeats", exact)
end
-- }}}

-- {{{ local function test_abilities_are_a_dispatch_table()
-- 504. Every ability any hero names resolves to a condition and an effect, and the
-- one that cannot is an error with its name in it rather than a hero standing idle.
local function test_abilities_are_a_dispatch_table()
  local world, modules, parameters = fresh_world()
  local abilities = modules.abilities
  local table_of = parameters.commander.ability

  local problem
  for _, row in ipairs(parameters.unit.archetype) do
    for _, name in ipairs(row.ability or {}) do
      local ability = table_of[name]
      if ability == nil then
        problem = problem or (row.name .. " names " .. name .. ", which is not in the table")
      elseif abilities.condition[ability.condition] == nil then
        problem = problem or (name .. "'s condition " .. ability.condition .. " does not exist")
      elseif abilities.effect[ability.effect] == nil then
        problem = problem or (name .. "'s effect " .. ability.effect .. " does not exist")
      elseif not (ability.cooldown > 0) then
        problem = problem or (name .. " has no cooldown")
      end
    end
  end
  check("every ability a hero names has a condition, an effect and a cooldown",
        problem == nil, problem)

  -- A priest beside one wounded ally mends it, once, and then waits.
  local soldier = world.soldier
  local priest = put(world, 12, 1, 400, 400)
  local wounded = put(world, 1, 1, 430, 400)
  soldier.health[wounded] = soldier.health_max[wounded] - 200
  modules.targeting.rebuild_grid(world)

  local mend = table_of.mend_deeply
  local before = soldier.health[wounded]
  abilities.run(world)
  local fired = events_named(world, "ability")
  check("a priest beside a wounded ally mends it by the ability's power",
        math.abs(soldier.health[wounded] - (before + mend.power)) < 1e-6,
        string.format("%.1f -> %.1f", before, soldier.health[wounded]))
  check("and raises one ability event that says which ability it was",
        #fired == 1 and fired[1].ability == "mend_deeply" and fired[1].id == priest,
        string.format("%d events, ability %s", #fired, tostring(fired[1] and fired[1].ability)))
  check("and its cooldown is the ability's",
        soldier.ability_cooldown[priest] == mend.cooldown,
        tostring(soldier.ability_cooldown[priest]))

  world.event = {}
  soldier.health[wounded] = soldier.health_max[wounded] - 200
  abilities.run(world)
  check("on the next tick it does not fire again",
        #events_named(world, "ability") == 0
        and soldier.health[wounded] == soldier.health_max[wounded] - 200)

  -- A heal into a body that is nearly full stops at full. The waste is the point:
  -- it is what makes *whose gap does this fit* a different choice from *who is worst off*.
  soldier.ability_cooldown[priest] = 0
  soldier.health[wounded] = soldier.health_max[wounded] - 10
  abilities.run(world)
  check("a heal never lifts a body past its maximum",
        soldier.health[wounded] == soldier.health_max[wounded])

  -- And the table refuses a name it does not hold, out loud.
  parameters.unit.archetype[12].ability = {"an_ability_nobody_wrote"}
  soldier.ability_cooldown[priest] = 0
  local ok, message = pcall(abilities.run, world)
  check("an ability missing from the table is an error that names it",
        not ok and tostring(message):find("an_ability_nobody_wrote", 1, true) ~= nil,
        tostring(message))
end
-- }}}

-- {{{ local function test_spawning_onto_a_wave()
-- 505. Onto one of your living waves, where it is now, at once -- and as a guest:
-- the wave's counters do not move, so a hero cannot keep a wave from being wiped.
local function test_spawning_onto_a_wave()
  local world, modules, parameters = fresh_world()
  local soldier = world.soldier

  -- Long enough for the first waves to have walked out and spread into ranks.
  for _ = 1, parameters.unit.wave.first_at + 120 do
    tick_module.advance(world)
  end
  local wave
  for _, candidate in ipairs(world.wave) do
    if candidate.team == 1 and candidate.living_count > 0 then
      wave = candidate
      break
    end
  end
  check("a living wave of team 1 exists to buy onto", wave ~= nil)
  if wave == nil then return end

  fill_wallet(world, 1)
  local roster = parameters.commander.commander[world.player[1].commander].roster
  local members, living = wave.member_count, wave.living_count
  local verdict = modules.commanders.buy(world, 1, roster[1], "wave", wave.id)
  check("a hero bought onto a living wave is accepted", verdict.accepted, verdict.reason)
  if not verdict.accepted then return end

  -- Behind its rearmost living member, and not far behind: about one body's width.
  -- Checked for both teams, because "behind" is the opposite direction along the
  -- lane for each, and a sign got wrong would put one side's heroes in front.
  local function how_far_behind(hero, team_wave)
    local facing = (team_wave.team == 1) and 1 or -1
    local rear = math.huge
    for other = 1, world.high_water do
      if soldier.alive[other] == 1 and soldier.wave[other] == team_wave.id then
        rear = math.min(rear, soldier.lane_along[other] * facing)
      end
    end
    local mine = soldier.lane_along[hero] * facing
    return soldier.lane[hero] == team_wave.lane and mine < rear and rear - mine < 20,
      string.format("lane %d vs %d, %.1f behind the rearmost", soldier.lane[hero],
        team_wave.lane, rear - mine)
  end

  check("and arrives in that wave's lane, just behind its rearmost living member",
        how_far_behind(verdict.id, wave))

  local far_wave
  for _, candidate in ipairs(world.wave) do
    if candidate.team == 2 and candidate.living_count > 0 then far_wave = candidate break end
  end
  local far_number = parameters.team_size + 1
  fill_wallet(world, far_number)
  local far_roster = parameters.commander.commander[world.player[far_number].commander].roster
  local far = modules.commanders.buy(world, far_number, far_roster[1], "wave", far_wave.id)
  local far_ok, far_detail = false, far.reason
  if far.accepted then
    far_ok, far_detail = how_far_behind(far.id, far_wave)
  end
  check("and the far team's hero lands behind its own wave, from the other end",
        far_ok, far_detail)
  check("without joining the wave's record",
        wave.member_count == members and wave.living_count == living
        and soldier.wave[verdict.id] == 0)

  -- The other team's wave, and a wave with nobody left in it, are both "gone" from
  -- this player's point of view.
  local theirs
  for _, candidate in ipairs(world.wave) do
    if candidate.team == 2 then theirs = candidate break end
  end
  local refused = modules.commanders.buy(world, 1, roster[1], "wave", theirs.id)
  check("the enemy's wave is refused", not refused.accepted and refused.reason == "that wave is gone",
        refused.reason)
  wave.living_count = 0
  refused = modules.commanders.buy(world, 1, roster[1], "wave", wave.id)
  check("a wave with nobody left in it is refused",
        not refused.accepted and refused.reason == "that wave is gone", refused.reason)
end
-- }}}

-- {{{ local function test_spawning_onto_a_tower()
-- 506. Onto your own standing tower, unless an enemy is inside its radius -- and
-- then refused, not redirected, with the refusal naming where would have worked.
local function test_spawning_onto_a_tower()
  local world, modules, parameters = fresh_world()
  local soldier = world.soldier
  local commanders = modules.commanders
  local player = fill_wallet(world, 1)
  local roster = parameters.commander.commander[player.commander].roster
  local hero = roster[1]

  local outer_id, outer = structure_at(world, 1, 1, 3)
  local _, middle = structure_at(world, 1, 1, 2)
  local _, inner = structure_at(world, 1, 1, 1)

  -- Clear ground: accepted, standing at the tower.
  local verdict = commanders.buy(world, 1, hero, "tower", outer_id)
  check("a hero bought at your own clear tower is accepted", verdict.accepted, verdict.reason)
  if verdict.accepted then
    local node = world.map.node[outer.node]
    local dx, dy = soldier.x[verdict.id] - node.x, soldier.y[verdict.id] - node.y
    check("and stands at that tower, in its lane",
          soldier.lane[verdict.id] == 1 and dx * dx + dy * dy < outer.command_radius ^ 2,
          string.format("%.0f away", math.sqrt(dx * dx + dy * dy)))
    world.release(world, verdict.id)
  end

  -- One enemy beside the outer tower. The purchase is refused, nothing is charged,
  -- nothing appears, and the refusal names the nearest tower behind it.
  fill_wallet(world, 1)
  local node = world.map.node[outer.node]
  put(world, 1, 2, node.x + 20, node.y)
  local bought, held = player.heroes_bought, wallet_total(player)
  local high_water = world.high_water
  verdict = commanders.buy(world, 1, hero, "tower", outer_id)
  check("with an enemy inside its radius, the tower is refused",
        not verdict.accepted and verdict.reason:find("inside that tower's radius", 1, true) ~= nil,
        verdict.reason)
  check("and the refusal names the nearest tower behind it, not the furthest",
        verdict.reason:find("milestone " .. middle.milestone, 1, true) ~= nil, verdict.reason)
  check("and nothing was charged and nobody appeared",
        player.heroes_bought == bought and wallet_total(player) == held
        and world.high_water == high_water)

  -- An enemy beside every tower in the lane: the only place left is the library.
  for _, structure in ipairs({middle, inner}) do
    local at = world.map.node[structure.node]
    put(world, 1, 2, at.x + 20, at.y)
  end
  verdict = commanders.buy(world, 1, hero, "tower", outer_id)
  check("with every tower in the lane under attack, the refusal names the library",
        not verdict.accepted and verdict.reason:find("your library", 1, true) ~= nil, verdict.reason)

  -- Somebody else's tower, and a fallen one of your own, are not places at all.
  local theirs = structure_at(world, 2, 1, 3)
  verdict = commanders.buy(world, 1, hero, "tower", theirs)
  check("the enemy's tower is refused", not verdict.accepted
        and verdict.reason == "that is not one of your standing towers", verdict.reason)
  local fallen_id, fallen = structure_at(world, 1, 2, 3)
  fallen.alive = 0
  verdict = commanders.buy(world, 1, hero, "tower", fallen_id)
  check("a fallen tower is refused", not verdict.accepted
        and verdict.reason == "that is not one of your standing towers", verdict.reason)

  verdict = commanders.buy(world, 1, hero, "the moon", 0)
  check("a destination that does not exist is refused by name",
        not verdict.accepted and verdict.reason:find("the moon", 1, true) ~= nil, verdict.reason)
end
-- }}}

-- {{{ local function test_spawning_at_the_library()
-- 507. The lane the enemy has pushed deepest into, by milestone, ties to the lower
-- lane number -- the vision's own example: a lane where they are one pace past your
-- first tower is less urgent than a lane where they are inside your base.
local function test_spawning_at_the_library()
  local world, modules, parameters = fresh_world()
  local soldier = world.soldier
  local commanders = modules.commanders
  local roster = parameters.commander.commander[world.player[1].commander].roster

  local function bought_into(depths, number)
    local team = world.player[number].team
    local enemy = (team == 1) and 2 or 1
    for lane = 1, parameters.lane_count do
      world.team[enemy].push_depth[lane] = depths[lane]
    end
    fill_wallet(world, number)
    local verdict = commanders.buy(world, number, roster[1], "library", 0)
    if not verdict.accepted then
      return 0, verdict.reason
    end
    return soldier.lane[verdict.id], verdict.id
  end

  local lane = bought_into({1, 0, 3}, 1)
  check("a library hero enters the lane the enemy has pushed deepest into", lane == 3,
        "entered lane " .. lane)
  lane = bought_into({0, 2, 2}, 1)
  check("and a tie goes to the lower lane number, every time", lane == 2,
        "entered lane " .. lane)

  -- The far team does the same from the other end of the lane.
  local far_lane, id = bought_into({0, 0, 1}, parameters.team_size + 1)
  local length = world.map.lane[3].length
  check("team 2's library hero enters at its own end of the lane",
        far_lane == 3 and math.abs(soldier.lane_along[id] - length) < 1,
        string.format("lane %d, along %.1f of %.1f", far_lane,
          soldier.lane_along[id], length))
end
-- }}}

-- {{{ local function test_the_rosters()
-- 509. Five heroes each, doing different jobs rather than one job at three prices.
--
-- "Different jobs" is checked the only way it can be from a table: no two heroes on
-- a roster share an ability, and across the rosters there is a hero for each of the
-- three jobs that are visible in the data -- area damage, damage to stone, and mending.
local function test_the_rosters()
  local _, _, parameters = fresh_world()
  local catalogue = parameters.commander
  local archetype = parameters.unit.archetype

  local problem
  for _, commander in ipairs(catalogue.commander) do
    local rows, abilities = {}, {}
    for _, row in ipairs(commander.roster) do
      if rows[row] then problem = problem or (commander.name .. " offers a hero twice") end
      rows[row] = true
      for _, name in ipairs(archetype[row].ability or {}) do
        if abilities[name] then
          problem = problem or (commander.name .. " has two heroes that both " .. name)
        end
        abilities[name] = true
      end
    end
    if #commander.roster ~= 5 then
      problem = problem or (commander.name .. " offers " .. #commander.roster .. " heroes, not five")
    end
  end
  check("every roster is five different heroes with no ability in common", problem == nil, problem)

  local effects = {}
  for _, commander in ipairs(catalogue.commander) do
    for _, row in ipairs(commander.roster) do
      for _, name in ipairs(archetype[row].ability or {}) do
        effects[catalogue.ability[name].effect] = true
      end
    end
  end
  check("somebody can kill a line, somebody can kill stone, and somebody can mend",
        effects.splash and effects.breach and (effects.heal or effects.regenerate))

  -- Heroes are meant to cost about the same in total -- the unit table says so --
  -- and to differ in the *shape* of the bill, because a bill in two colours is what
  -- lets the enemy's choice of commander reach into your purchases. So: every hero
  -- costs something, and no two heroes on one roster send the same bill.
  local problem_with_bills
  for _, commander in ipairs(catalogue.commander) do
    local bills = {}
    for _, row in ipairs(commander.roster) do
      local parts, total = {}, 0
      for colour = 1, #catalogue.colour do
        local amount = catalogue.hero_cost[row][colour] or 0
        parts[colour] = amount
        total = total + amount
      end
      local key = table.concat(parts, ",")
      if total <= 0 then
        problem_with_bills = problem_with_bills or (archetype[row].name .. " is free")
      elseif bills[key] then
        problem_with_bills = problem_with_bills or
          (archetype[row].name .. " sends the same bill as " .. bills[key])
      end
      bills[key] = archetype[row].name
    end
  end
  check("every hero costs something, and no two on a roster send the same bill",
        problem_with_bills == nil, problem_with_bills)
end
-- }}}

-- {{{ local function test_the_healers()
-- 510. Who heals whom.
--
-- The claim rule is tested where it bites and where it relaxes, because the relaxing
-- branch only fires when a team is *winning* -- not enough wounded to go round -- and
-- otherwise nothing would ever run it.
local function test_the_healers()
  local world, modules, parameters = fresh_world()
  local soldier = world.soldier
  local healer = modules.rest_of_brain.healer
  local table_of = parameters.commander.ability
  local mend = table_of.mend_deeply

  -- Two priests side by side, two wounded allies in reach of both.
  local priest_a = put(world, 12, 1, 400, 400)
  local priest_b = put(world, 12, 1, 400, 420)
  local hurt_more = put(world, 1, 1, 440, 400)
  local hurt_less = put(world, 1, 1, 440, 420)
  soldier.health[hurt_more] = soldier.health_max[hurt_more] * 0.2
  soldier.health[hurt_less] = soldier.health_max[hurt_less] * 0.6
  modules.targeting.rebuild_grid(world)

  modules.rest_of_brain.begin_tick(world)
  local first = healer.priest(world, priest_a, mend)
  local second = healer.priest(world, priest_b, mend)
  check("two priests and two wounded: the first takes whoever will die soonest",
        first == hurt_more, "took " .. first)
  check("and the second takes the other, not the same one", second == hurt_less,
        "took " .. second)

  -- One wounded body only. The second priest doubles up rather than standing idle.
  soldier.health[hurt_less] = soldier.health_max[hurt_less]
  modules.rest_of_brain.begin_tick(world)
  first = healer.priest(world, priest_a, mend)
  second = healer.priest(world, priest_b, mend)
  check("with one wounded body, the rule relaxes and both priests heal it",
        first == hurt_more and second == hurt_more,
        string.format("took %d and %d", first, second))

  -- Claims last one tick. A claim that outlived its healer would leave a body
  -- un-healable by anybody else, and nothing would notice.
  modules.rest_of_brain.begin_tick(world)
  check("claims are cleared at the start of every tick", next(world.healing_claim) == nil)

  -- The druid skips anybody already regenerating -- the matching problem spread
  -- over time instead of over bodies.
  local druid = put(world, 13, 1, 400, 440)
  soldier.health[hurt_less] = soldier.health_max[hurt_less] * 0.6
  soldier.regenerating[hurt_more] = 100
  modules.targeting.rebuild_grid(world)
  modules.rest_of_brain.begin_tick(world)
  local chosen = healer.druid(world, druid, table_of.regrowth)
  check("a druid passes over an ally that is already regenerating",
        chosen == hurt_less, "took " .. chosen)

  -- The curse-doctor's choice is an enemy: the one the most of our wounded are
  -- fighting.
  local doctor = put(world, 14, 1, 400, 460)
  local lonely = put(world, 1, 2, 520, 520)
  local mobbed = put(world, 1, 2, 460, 410)
  modules.targeting.rebuild_grid(world)
  modules.rest_of_brain.begin_tick(world)
  chosen = healer.curse_doctor(world, doctor, table_of.affliction)
  check("a curse-doctor curses the enemy the most of its wounded allies are touching",
        chosen == mobbed, string.format("took %d (mobbed %d, lonely %d)", chosen, mobbed, lonely))
end
-- }}}

-- {{{ local function test_the_moon_needs_a_clear_line()
-- 510, step 7. A druid behind an unbroken rank of its own cannot cast the moon
-- spike, and the same druid with the rank gone can. The frontline as a targeting
-- constraint: a druid that is casting it is standing where there is a hole.
local function test_the_moon_needs_a_clear_line()
  local world, modules, parameters = fresh_world()
  local soldier = world.soldier
  local spike = parameters.commander.ability.moon_spike
  local condition = modules.abilities.condition.moon_target

  local druid = put(world, 13, 1, 400, 400)
  local enemy = put(world, 1, 2, 520, 400)
  local rank = {}
  for step = -4, 4 do
    rank[#rank + 1] = put(world, 1, 1, 460, 400 + step * 6)
  end
  modules.targeting.rebuild_grid(world)
  check("a druid behind an unbroken rank of its own cannot cast the moon spike",
        condition(world, druid, spike) == 0)

  for _, id in ipairs(rank) do
    world.release(world, id)
  end
  modules.targeting.rebuild_grid(world)
  check("and with the rank gone, it can", condition(world, druid, spike) == enemy)
end
-- }}}

print("the commanders")
test_the_catalogue()
test_abilities_are_a_dispatch_table()
test_spawning_onto_a_wave()
test_spawning_onto_a_tower()
test_spawning_at_the_library()
test_the_rosters()
test_the_healers()
test_the_moon_needs_a_clear_line()

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
  os.exit(1)
end
