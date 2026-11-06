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

-- 073-the-door-and-the-chest.lua
--
-- covers: 106, 401, 402, 411
--
-- The rules a player's hands are held to: the one door every command comes through,
-- and the chest it reaches into.
--
-- ## Why this is not part of the invariants
--
-- Every check here is a rule about a verb, and a verb's answer does not need a match
-- to have been played. Asked through a whole match, a refusal that stopped being raised
-- or a stamp that started compounding would arrive as a wobble in some number at tick
-- forty thousand, and the change that caused it could be anywhere. Asked here, against a
-- world that has not ticked, a failure names the verb.
--
-- **Nothing here advances the clock.** A world is assembled, put into the state a check
-- needs by the same calls the game makes, and asked. The one exception is the door
-- itself, which is driven exactly the way the tick drives it -- queue, then apply.
--
-- ## What it does not claim
--
-- 413, staking a die, is not claimed. What is built under that number is `offer`, and
-- the invariants already test offering; the stake that gives the issue its name is not
-- built, and a test of offering wearing 413's number would be a census that rewards a
-- relabelling.

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
-- A whole world, assembled and never ticked, with nobody behind either team.
local function fresh_world()
  local modules = tick_module.load_cast(ROOT)
  local parameters = modules.match_parameters.load()
  local world = tick_module.assemble(modules, parameters)
  world.bot = {}
  world.event = {}
  return world, modules, parameters
end
-- }}}

-- {{{ local function events_named()
local function events_named(world, name)
  local found = {}
  for _, event in ipairs(world.event) do
    if event.name == name then found[#found + 1] = event end
  end
  return found
end
-- }}}

-- {{{ local function a_teammate_below()
-- A stone of team one held by somebody who is not the lowest-numbered player, and that
-- lower-numbered teammate. Draws go round the team, so two draws are always enough.
local function a_teammate_below(world, modules)
  modules.stones.draw(world, 1, 2)
  local players = world.team_players[1]
  local lowest = players[1]
  for _, number in ipairs(players) do
    if number < lowest then lowest = number end
  end
  for _, stone in ipairs(world.stone[1]) do
    if stone.held_by ~= lowest then
      return stone, stone.held_by, lowest
    end
  end
  return nil, 0, 0
end
-- }}}

-- {{{ local function test_commands_wait_at_the_door()
-- 106. A command does nothing until the tick applies it, and the tick applies every
-- command **by player, then by arrival** -- not in the order they turned up.
--
-- Arrival order is exactly what two machines disagree about when two people click in
-- the same tick, so it cannot decide anything. This is set up so that the two orders
-- give different answers: the owner offers a stone to a lower-numbered teammate, and
-- *then* that teammate tries to place it. In arrival order the offer lands first and the
-- placement succeeds. In player order the teammate goes first, is refused because the
-- stone is not yet theirs, and the offer lands after.
local function test_commands_wait_at_the_door()
  local world, modules = fresh_world()
  local stone, owner, lower = a_teammate_below(world, modules)
  if stone == nil then
    check("a team of more than one player has a stone to argue over", false)
    return
  end

  modules.commands.queue(world, {verb = "offer", player = owner,
                                 stone = stone.id, to = lower})
  modules.commands.queue(world, {verb = "place_stone", player = lower, stone = stone.id,
                                 slot_kind = modules.stones.IN_LANE, slot_lane = 1})
  check("a queued command changes nothing until it is applied",
        stone.held_by == owner and stone.moving_to_kind == 0)

  modules.commands.apply_all(world)
  check("commands are applied by player, then by arrival, not as they came",
        stone.held_by == lower and stone.moving_to_kind == 0,
        string.format("the stone is held by %d and moving to slot kind %d",
                      stone.held_by, stone.moving_to_kind))
  check("and the queue is empty afterwards", #world.command_queue == 0)

  -- The issue's own test: the same two commands turning up the other way round land
  -- exactly the same way, because arrival never got a vote.
  local other = fresh_world()
  local other_stone = a_teammate_below(other, modules)
  modules.commands.queue(other, {verb = "place_stone", player = lower,
                                 stone = other_stone.id,
                                 slot_kind = modules.stones.IN_LANE, slot_lane = 1})
  modules.commands.queue(other, {verb = "offer", player = owner,
                                 stone = other_stone.id, to = lower})
  modules.commands.apply_all(other)
  check("and the other arrival order lands exactly the same",
        other_stone.held_by == stone.held_by
          and other_stone.moving_to_kind == stone.moving_to_kind,
        string.format("held by %d moving to %d, against %d moving to %d",
                      other_stone.held_by, other_stone.moving_to_kind,
                      stone.held_by, stone.moving_to_kind))
end
-- }}}

-- {{{ local function test_a_refusal_is_loud()
-- 106. Every refusal comes back as an event naming who, which verb and why. A command
-- that silently does nothing is the worst outcome there is: the player believes the game
-- has their instruction and it does not.
local function test_a_refusal_is_loud()
  local world, modules = fresh_world()
  local stone, owner, lower = a_teammate_below(world, modules)
  if stone == nil then
    check("a team of more than one player has a stone to argue over", false)
    return
  end

  -- Somebody placing a stone that is not theirs.
  modules.commands.queue(world, {verb = "place_stone", player = lower, stone = stone.id,
                                 slot_kind = modules.stones.IN_LANE, slot_lane = 1})
  modules.commands.apply_all(world)
  local refused = events_named(world, "refused")
  check("a refused command raises one refusal",
        #refused == 1, #refused .. " refusals raised")
  if #refused == 1 then
    local event = refused[1]
    check("naming the player, the verb, and a reason in words",
          event.player == lower and event.verb == "place_stone"
            and type(event.reason) == "string" and #event.reason > 0,
          string.format("player %s, verb %s, reason %s", tostring(event.player),
                        tostring(event.verb), tostring(event.reason)))
  end

  -- And one the door does not know at all. That is not a player's mistake -- a player
  -- can only send what the interface offers -- so it stops the program and says what.
  modules.commands.queue(world, {verb = "teleport", player = owner})
  local ok, message = pcall(modules.commands.apply_all, world)
  check("an unknown verb stops the program, by name",
        not ok and tostring(message):find("teleport", 1, true) ~= nil,
        ok and "it was accepted" or tostring(message))
end
-- }}}

-- {{{ local function test_every_kind_does_something()
-- 401. The catalogue's own promises, asked of the table the game actually loads: every
-- row changes at least one number, says which half of a wave it reaches, and says what
-- it gives stone -- with exactly one row, Boots, giving stone nothing on purpose.
--
-- The issue asks for a validator that refuses a row modifying nothing, because such a
-- row is a typo rather than an upgrade. None is built; this is that check, standing
-- where it is run.
local function test_every_kind_does_something()
  local _, _, parameters = fresh_world()
  local kinds = parameters.upgrade.kind

  local idle, bad_reach, no_stone_entry, empty_for_stone = {}, {}, {}, {}
  for index, row in ipairs(kinds) do
    if next(row.add) == nil and next(row.mul) == nil then idle[#idle + 1] = row.name end
    if row.reaches ~= 1 and row.reaches ~= 2 and row.reaches ~= 3 then
      bad_reach[#bad_reach + 1] = row.name
    end
    if row.tower == nil then
      no_stone_entry[#no_stone_entry + 1] = row.name
    elseif next(row.tower) == nil then
      empty_for_stone[#empty_for_stone + 1] = row.name
    end
  end

  check("every kind in the catalogue changes at least one number on a body",
        #idle == 0, "changes nothing: " .. table.concat(idle, ", "))
  check("and says whether it reaches melee, ranged, or both",
        #bad_reach == 0, "no such reach: " .. table.concat(bad_reach, ", "))
  check("and says what it gives stone, even when that is nothing",
        #no_stone_entry == 0, "no tower entry: " .. table.concat(no_stone_entry, ", "))
  check("and only Boots gives stone nothing, because stone does not walk",
        #empty_for_stone == 1 and empty_for_stone[1] == "Boots",
        "empty in stone: " .. table.concat(empty_for_stone, ", "))
end
-- }}}

-- {{{ local function kind_named()
local function kind_named(parameters, name)
  for index, row in ipairs(parameters.upgrade.kind) do
    if row.name == name then return index, row end
  end
  error("the catalogue has no kind called " .. name)
end
-- }}}

-- {{{ local function a_fresh_body()
-- A body reset to an archetype's own row, the state the stamp is always applied to.
local function a_fresh_body(world, archetype)
  local id = world.allocate(world)
  world.give_body(world, id, world.parameters.unit.archetype[archetype])
  return id
end
-- }}}

-- {{{ local function counts_of()
local function counts_of(parameters, held)
  local counts = {}
  for kind = 1, #parameters.upgrade.kind do counts[kind] = held[kind] or 0 end
  return counts
end
-- }}}

-- {{{ local function test_a_stamp_adds_then_multiplies()
-- 401. Additions first, then multipliers, fixed for the whole game -- so that two teams
-- holding the same upgrades arrive at the same numbers whatever order they drew them in.
-- And a body only takes the kinds that reach it, and duplicates stack.
local function test_a_stamp_adds_then_multiplies()
  local world, modules, parameters = fresh_world()
  local soldier = world.soldier
  local whetstone, whetstone_row = kind_named(parameters, "Whetstone")
  local banner, banner_row = kind_named(parameters, "Banner")
  local plate, plate_row = kind_named(parameters, "Plate")

  local melee = parameters.unit.archetype[1]
  local id = a_fresh_body(world, 1)
  modules.chest.apply_counts(world, id, counts_of(parameters, {[whetstone] = 2, [banner] = 1}))
  local want = (melee.damage + whetstone_row.add.damage * 2) * banner_row.mul.damage
  check("two Whetstones and a Banner: both Whetstones added, then the Banner multiplied",
        math.abs(soldier.damage[id] - want) < 0.000001,
        string.format("damage %.4f, expected %.4f", soldier.damage[id], want))

  -- The same stamp twice over, from a clean body, is the same body. Applying it on top
  -- of a stamp would compound, which is why the project only ever stamps a fresh one.
  local again = a_fresh_body(world, 1)
  modules.chest.apply_counts(world, again,
                             counts_of(parameters, {[banner] = 1, [whetstone] = 2}))
  check("and the same holding stamped again gives the same body",
        soldier.damage[again] == soldier.damage[id])

  -- Plate reaches melee only. A ranged body handed one is exactly the body it was.
  local ranged = parameters.unit.archetype[2]
  local archer = a_fresh_body(world, 2)
  modules.chest.apply_counts(world, archer, counts_of(parameters, {[plate] = 3}))
  check("a kind that reaches melee only does nothing for a ranged body",
        soldier.armour[archer] == ranged.armour
          and soldier.upgrade_count[plate][archer] == 0,
        string.format("armour %s against %s", tostring(soldier.armour[archer]),
                      tostring(ranged.armour)))
  local footman = a_fresh_body(world, 1)
  modules.chest.apply_counts(world, footman, counts_of(parameters, {[plate] = 3}))
  check("and three of it on a melee body is three of it",
        soldier.armour[footman] == melee.armour + plate_row.add.armour * 3
          and soldier.upgrade_count[plate][footman] == 3)
end
-- }}}

-- {{{ local function test_the_instances_are_the_truth()
-- 402. An upgrade is a stone: a specific thing, on a specific team, in a specific place,
-- held by a specific person. The per-slot counts everything stamps from are a cache over
-- the stones, rebuilt whole -- so after any sequence of moves the cache is exactly what
-- counting the stones gives.
local function test_the_instances_are_the_truth()
  local world, modules, parameters = fresh_world()
  local stones = modules.stones
  local players = world.team_players[1]

  stones.draw(world, 1, #players * 2)
  local held = {}
  for _, stone in ipairs(world.stone[1]) do
    held[stone.held_by] = (held[stone.held_by] or 0) + 1
  end
  local even = true
  for _, number in ipairs(players) do
    if held[number] ~= 2 then even = false end
  end
  check("draws go round the team, so everybody holds something",
        even, "after two rounds of draws somebody holds a different number")

  local mixed = true
  for _, stone in ipairs(world.stone[1]) do
    if stone.team ~= 1 then mixed = false end
  end
  check("and every stone a team draws is that team's", mixed)

  -- Move some of them: one into a lane, and land it; one on its way and not yet there.
  local first, second = world.stone[1][1], world.stone[1][2]
  stones.place(world, first.held_by, first.id, stones.IN_LANE, 2)
  stones.land_transits(world, first.arrives_turn)
  stones.place(world, second.held_by, second.id, stones.IN_STONE, 3)

  -- Count the stones by hand and compare with the cache, for every kind and every slot.
  local team = world.team[1]
  local disagree = 0
  for kind = 1, #parameters.upgrade.kind do
    local in_chest, in_lane, in_stone = 0, {}, {}
    for _, stone in ipairs(world.stone[1]) do
      if stone.kind == kind then
        if stone.slot_kind == stones.IN_CHEST then in_chest = in_chest + 1 end
        if stone.slot_kind == stones.IN_LANE then
          in_lane[stone.slot_lane] = (in_lane[stone.slot_lane] or 0) + 1
        end
        if stone.slot_kind == stones.IN_STONE then
          in_stone[stone.slot_lane] = (in_stone[stone.slot_lane] or 0) + 1
        end
      end
    end
    if team.chest[kind] ~= in_chest then disagree = disagree + 1 end
    for lane = 1, parameters.lane_count do
      if team.lane_slot[lane][kind] ~= (in_lane[lane] or 0) then disagree = disagree + 1 end
      if team.tower_slot[lane][kind] ~= (in_stone[lane] or 0) then disagree = disagree + 1 end
    end
  end
  check("the per-slot counts are exactly what counting the stones gives",
        disagree == 0, disagree .. " slots disagree with the stones in them")
  check("and a stone on its way still counts where it is, not where it is going",
        second.slot_kind == stones.IN_CHEST and second.moving_to_kind == stones.IN_STONE
          and team.tower_slot[3][second.kind] == 0)
end
-- }}}

-- {{{ local function test_a_reroll_trades_and_never_adds()
-- 411. A reroll sends one of your stones away and takes the next card in its place,
-- paid for in personal resource. It is the only thing resource can do to the chest, and
-- it **trades** -- nothing is ever added -- which is why resource can never buy an
-- upgrade outright. The other team's place in the deck is not touched: both read one
-- sequence at their own pace, and the divergence afterwards is the record of who paid.
local function test_a_reroll_trades_and_never_adds()
  local world, modules, parameters = fresh_world()
  local stones = modules.stones
  local price = parameters.upgrade.deck.reroll_cost

  stones.draw(world, 1, 1)
  local stone = world.stone[1][1]
  local owner = stone.held_by
  local player = world.player[owner]

  -- Too poor, first. Refused, by name, and nothing spent.
  for colour = 1, world.colour_count do player.points[colour] = 0 end
  local refused = stones.reroll(world, owner, stone.id)
  check("a reroll nobody can afford is refused, and says what is missing",
        not refused.accepted and refused.reason:find("more", 1, true) ~= nil,
        refused.reason)

  -- Then with exactly the price in hand.
  for colour, amount in pairs(price) do player.points[colour] = amount end
  local count_before = #world.stone[1]
  local index_before = world.team[1].deck_index
  local other_before = world.team[2].deck_index
  local expected = world.deck[(index_before % #world.deck) + 1]

  local verdict = stones.reroll(world, owner, stone.id)
  check("a reroll with the price in hand is accepted", verdict.accepted, verdict.reason)

  local spent = true
  for colour = 1, world.colour_count do
    if player.points[colour] ~= 0 then spent = false end
  end
  check("and costs exactly its price", spent)
  check("and the stone becomes the next card on its team's deck",
        stone.kind == expected and world.team[1].deck_index == index_before + 1,
        string.format("kind %d, expected %d", stone.kind, expected))
  check("and nothing is added: the team holds as many stones as before",
        #world.stone[1] == count_before)
  check("and the other team's place in the deck has not moved",
        world.team[2].deck_index == other_before)

  -- Only an unplaced stone of your own.
  for colour, amount in pairs(price) do player.points[colour] = amount end
  stones.place(world, owner, stone.id, stones.IN_LANE, 1)
  stones.land_transits(world, stone.arrives_turn)
  local placed = stones.reroll(world, owner, stone.id)
  check("a stone already placed cannot be rerolled", not placed.accepted, placed.reason)

  local someone_else = 0
  for _, number in ipairs(world.team_players[1]) do
    if number ~= owner then someone_else = number break end
  end
  stones.draw(world, 1, #world.team_players[1])
  local theirs = 0
  for _, other in ipairs(world.stone[1]) do
    if other.held_by == owner and other.slot_kind == stones.IN_CHEST then theirs = other.id end
  end
  for colour, amount in pairs(price) do
    world.player[someone_else].points[colour] = amount
  end
  local taken = stones.reroll(world, someone_else, theirs)
  check("and nobody can reroll a stone that is not theirs",
        theirs ~= 0 and not taken.accepted, taken.reason)
end
-- }}}

print("")
print("the door and the chest")
print("")
test_commands_wait_at_the_door()
test_a_refusal_is_loud()
test_every_kind_does_something()
test_a_stamp_adds_then_multiplies()
test_the_instances_are_the_truth()
test_a_reroll_trades_and_never_adds()
print("")
print(string.format("%d passed, %d failed", passed, failed))
print("")

if failed > 0 then
  os.exit(1)
end
