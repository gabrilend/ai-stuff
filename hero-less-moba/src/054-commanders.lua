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

-- 054-commanders.lua
--
-- The one thing in this game that belongs to a single player and cannot be touched
-- by their teammates.
--
-- ## Every kill pays everybody
--
-- **Every kill your team lands pays every player on your team, in full.** Not a
-- pot to be divided -- the catalogue figure is per player -- and nothing asks what
-- did the killing. The reap pass reads the dead body's own team and credits the
-- other one.
--
-- Two consequences shape how the whole second economy feels. **Teammates have
-- identical incomes**, so the only thing distinguishing two players on a team is
-- what they do with the same money -- when to bank, when to spend, which hero,
-- which of the three destinations. That is a far better axis than who was better at
-- landing final blows. And **there is no death spiral**: a player who buys a hero,
-- puts it somewhere stupid and watches it die has lost the purchase and nothing
-- else. "Personal" means a private wallet, not a private income.
--
-- ## You farm what the enemy fields
--
-- Resource is not one number. Every body carries **one colour**, decided by the
-- commander that fielded it, and killing it pays that colour. So the enemy's
-- commander selection decides what you can afford -- a loop this design did not
-- previously have, and the reason a hero's cost is a vector rather than a price.
--
-- ## The ceiling, and why there is none on heroes
--
-- There is no limit on how many of your heroes may be alive. There is a limit on
-- how much you may hold, per colour, and **income arriving at a full colour is
-- lost** -- not stored, not carried, not converted. The ladder is dice and it climbs
-- on the match clock, so both sides climb together and nobody can out-bank anybody.

local M = {}

M.WHERE_WAVE    = "wave"
M.WHERE_TOWER   = "tower"
M.WHERE_LIBRARY = "library"

-- {{{ local function bounty_sequence()
-- Expands a commander's colour ratio into a repeating sequence.
--
-- *"three blue die for every one green die and every five red die"* is a ratio, and
-- a body needs one colour rather than a distribution. Walking a fixed sequence
-- gives every wave exactly the advertised proportions instead of approximately
-- them, and does it without touching a random stream -- which matters, because a
-- commander's bounty is a thing an opponent is supposed to be able to learn by
-- watching, and a bounty that varied run to run could not be learned.
local function bounty_sequence(commander)
  local sequence = {}
  for colour, weight in pairs(commander.bounty) do
    for _ = 1, weight do
      sequence[#sequence + 1] = colour
    end
  end
  -- pairs() has no defined order, so the sequence is sorted into one. Without
  -- this the same catalogue would produce a different sequence between runs, and
  -- the reproducibility test would fail for a reason nobody would guess.
  table.sort(sequence)
  return sequence
end
-- }}}

-- {{{ function M.begin()
-- Builds the player records and hands out commanders.
function M.begin(world)
  local catalogue = world.parameters.commander
  local colours = #catalogue.colour
  local per_team = world.parameters.team_size

  world.player = {}
  world.colour_count = colours

  for number = 1, per_team * 2 do
    local team = (number <= per_team) and 1 or 2
    -- Commanders are dealt round-robin from the catalogue. A lobby would let
    -- people choose; the prototype deals, so that a match has more than one
    -- mixture on each side without anybody having to pick.
    local commander_id = ((number - 1) % #catalogue.commander) + 1

    local player = {
      number = number,
      team = team,
      commander = commander_id,
      points = {}, points_max = {}, points_wasted = {}, points_earned = {},
      rung = 1,
      hero_alive = 0,
      heroes_bought = 0,
    }
    for colour = 1, colours do
      player.points[colour] = 0
      player.points_max[colour] = catalogue.ceiling[1]
      player.points_wasted[colour] = 0
      player.points_earned[colour] = 0
    end
    world.player[number] = player
  end

  -- Each team's players, in order, so waves can take turns.
  world.team_players = {{}, {}}
  for number = 1, per_team * 2 do
    local team = world.player[number].team
    world.team_players[team][#world.team_players[team] + 1] = number
  end

  -- The bounty sequences, expanded once.
  world.bounty_sequence = {}
  for id, commander in ipairs(catalogue.commander) do
    world.bounty_sequence[id] = bounty_sequence(commander)
  end

  world.next_rung_tick = catalogue.rung_interval
end
-- }}}

-- {{{ function M.commander_for_wave()
-- Whose mixture walks out this time.
--
-- **The commanders take turns sending waves**, so a third of what leaves your base
-- is somebody else's captain and somebody else's proportions. That is what makes
-- commander selection a team conversation rather than three private preferences.
function M.commander_for_wave(world, team, wave_index)
  local players = world.team_players[team]
  local player = players[((wave_index - 1) % #players) + 1]
  return world.player[player].commander, player
end
-- }}}

-- {{{ function M.stamp_bounty()
-- Gives a body the colour it will pay out when it dies.
function M.stamp_bounty(world, id, commander_id, index)
  local sequence = world.bounty_sequence[commander_id]
  world.soldier.bounty_colour[id] = sequence[((index - 1) % #sequence) + 1]
end
-- }}}

-- {{{ function M.credit()
-- Adds points to one player, capped, recording what overflowed.
--
-- The overflow is counted rather than silently dropped, per colour, because a
-- player who is wasting income needs to be made uncomfortable about **which**
-- colour -- "you are wasting spirit" is an instruction and "you are wasting
-- resource" is a shrug.
function M.credit(world, player, colour, amount)
  local ceiling = player.points_max[colour]
  local room = ceiling - player.points[colour]
  player.points_earned[colour] = player.points_earned[colour] + amount

  if amount <= room then
    player.points[colour] = player.points[colour] + amount
  else
    player.points[colour] = ceiling
    player.points_wasted[colour] = player.points_wasted[colour] + (amount - room)
  end
end
-- }}}

-- {{{ function M.pay_for_kill()
-- One body died. Every player on the other team is paid, in full, in that body's
-- colour.
function M.pay_for_kill(world, dead_team, flavour, archetype, colour)
  if colour == 0 then
    return
  end
  local bounty = world.parameters.unit.bounty
  local amount = bounty.wave

  if flavour == 2 then
    amount = bounty.hero
  elseif flavour == 3 then
    amount = bounty.guard
  elseif flavour == 4 then
    amount = bounty.monster
  else
    local row = world.parameters.unit.archetype[archetype]
    if row ~= nil and row.name:find("captain") then
      amount = bounty.captain
    end
  end

  local paid_team = (dead_team == 1) and 2 or 1
  for _, number in ipairs(world.team_players[paid_team]) do
    M.credit(world, world.player[number], colour, amount)
  end
end
-- }}}

-- {{{ function M.climb_ladder()
-- The wallets grow, on the match clock, for everybody at once.
function M.climb_ladder(world)
  local catalogue = world.parameters.commander
  if world.tick < world.next_rung_tick then
    return
  end
  world.next_rung_tick = world.next_rung_tick + catalogue.rung_interval

  for _, player in ipairs(world.player) do
    if player.rung < #catalogue.ceiling then
      player.rung = player.rung + 1
      for colour = 1, world.colour_count do
        player.points_max[colour] = catalogue.ceiling[player.rung]
      end
    end
  end
  world.raise(world, "wallets_grew", {rung = world.player[1].rung})
end
-- }}}

-- {{{ function M.can_afford()
-- Whether a player holds every colour a hero's bill names.
--
-- A vector, not a price: somebody paid only in might cannot buy a hero that wants
-- spirit, however much might they are sitting on.
function M.can_afford(world, player, hero_row)
  local cost = world.parameters.commander.hero_cost[hero_row]
  if cost == nil then
    return false
  end
  for colour, amount in pairs(cost) do
    if player.points[colour] < amount then
      return false
    end
  end
  return true
end
-- }}}

-- {{{ function M.charge()
local function charge(world, player, hero_row)
  for colour, amount in pairs(world.parameters.commander.hero_cost[hero_row]) do
    player.points[colour] = player.points[colour] - amount
  end
end
-- }}}

-- {{{ function M.clear_ground()
-- Whether a tower's command radius holds no enemy, which is what gates putting a
-- hero down at it.
--
-- One circle, two jobs -- the same radius decides whether the tower may replace its
-- guards -- and drawn for both teams, so a refusal is one a player could have seen
-- coming. A refusal out of nowhere is a bug as far as they are concerned.
function M.clear_ground(world, structure)
  local node = world.map.node[structure.node]
  local soldier = world.soldier
  for id = 1, world.high_water do
    if soldier.alive[id] == 1
       and world.targeting.hostile(structure.team, soldier.team[id]) then
      local dx = soldier.x[id] - node.x
      local dy = soldier.y[id] - node.y
      if dx * dx + dy * dy <= structure.command_radius * structure.command_radius then
        return false
      end
    end
  end
  return true
end
-- }}}

-- {{{ local function tower_behind()
-- The nearest tower further back than this one whose ground is clear, or the
-- library if there is none.
--
-- Named in the refusal so the player knows where they *can* put it. **The spawn is
-- refused, not redirected** -- nothing puts a body somewhere the player did not ask
-- for it to go, because a silent redirect is a fallback and a fallback in a game
-- where a hero costs a minute of income is a purchase you did not make.
local function tower_behind(world, structure)
  local best, best_milestone = nil, 99
  for _, other in ipairs(world.structure) do
    if other.alive == 1 and other.team == structure.team and other.lane == structure.lane
       and other.kind ~= 3 and other.milestone < structure.milestone then
      if other.milestone < best_milestone and M.clear_ground(world, other) then
        best, best_milestone = other, other.milestone
      end
    end
  end
  if best ~= nil then
    return "the tower at milestone " .. best.milestone
  end
  return "your library"
end
-- }}}

-- {{{ function M.place_hero()
-- Puts a bought hero on the ground at one of the three destinations.
function M.place_hero(world, id, player, where, target)
  local soldier = world.soldier
  local team = player.team

  if where == M.WHERE_WAVE then
    local wave = world.wave[target]
    local lane = world.map.lane[wave.lane]
    soldier.lane[id] = wave.lane
    soldier.facing[id] = (team == 1) and 1 or -1
    soldier.path_index[id] = (team == 1) and 1 or #lane.path
    -- Arrives with the wave, wherever the wave currently is, immediately. The
    -- aggressive option, and the fragile one: the frontline is where the enemy's
    -- damage already is.
    world.walking.set_lane_position(world, id, wave.anchor, 0)
    return

  elseif where == M.WHERE_TOWER then
    local structure = world.structure[target]
    local lane = world.map.lane[structure.lane]
    local node = world.map.node[structure.node]
    soldier.lane[id] = structure.lane
    soldier.facing[id] = (team == 1) and 1 or -1
    soldier.path_index[id] = lane.path_index[structure.node] or 1
    local along = world.walking.project_onto_lane(world, structure.lane,
      node.x, node.y, soldier.path_index[id])
    world.walking.set_lane_position(world, id, along, 0)
    return
  end

  -- The library. Always available, because if enemies are next to your library the
  -- game is nearly over anyway.
  --
  -- It enters the lane where the **enemy has pushed deepest, measured in
  -- milestones** rather than in distance. A lane where they sit one pace past your
  -- first tower is in less trouble than one where they are inside your base, even
  -- though the base is physically nearer -- and a straight-line check picks the
  -- wrong lane in exactly the case where picking wrong matters most.
  local enemy = (team == 1) and 2 or 1
  local worst_lane, worst_depth = 1, -1
  for lane_id = 1, world.parameters.lane_count do
    local depth = world.team[enemy].push_depth[lane_id]
    if depth > worst_depth then
      worst_lane, worst_depth = lane_id, depth
    end
  end

  local lane = world.map.lane[worst_lane]
  soldier.lane[id] = worst_lane
  soldier.facing[id] = (team == 1) and 1 or -1
  soldier.path_index[id] = (team == 1) and 1 or #lane.path
  world.walking.set_lane_position(world, id, (team == 1) and 0 or lane.length, 0)
end
-- }}}

-- {{{ function M.buy()
-- The whole purchase. Returns a verdict in the same shape a command refusal uses.
function M.buy(world, player_number, hero_row, where, target)
  local player = world.player[player_number]
  if player == nil then
    return {accepted = false, reason = "there is no player " .. tostring(player_number)}
  end

  local catalogue = world.parameters.commander
  local roster = catalogue.commander[player.commander].roster
  local on_roster = false
  for _, row in ipairs(roster) do
    if row == hero_row then on_roster = true break end
  end
  if not on_roster then
    return {accepted = false,
            reason = catalogue.commander[player.commander].name .. " has no such hero"}
  end

  if not M.can_afford(world, player, hero_row) then
    local wants = {}
    for colour, amount in pairs(catalogue.hero_cost[hero_row]) do
      if player.points[colour] < amount then
        wants[#wants + 1] = string.format("%d more %s",
          amount - player.points[colour], catalogue.colour[colour].name)
      end
    end
    return {accepted = false, reason = "needs " .. table.concat(wants, " and ")}
  end

  if where == M.WHERE_TOWER then
    local structure = world.structure[target]
    if structure == nil or structure.team ~= player.team or structure.alive == 0 then
      return {accepted = false, reason = "that is not one of your standing towers"}
    end
    if not M.clear_ground(world, structure) then
      -- This rule is the whole texture of hero spawning: you cannot reinforce the
      -- tower that is actually under attack, you reinforce the one behind it and
      -- walk the hero up. A tower under pressure is one whose reinforcements arrive
      -- late, by design -- which is what makes the outer towers worth defending
      -- before they are in trouble rather than after.
      return {accepted = false,
              reason = "enemies are inside that tower's radius -- try " ..
                       tower_behind(world, structure)}
    end
  elseif where == M.WHERE_WAVE then
    local wave = world.wave[target]
    if wave == nil or wave.team ~= player.team or wave.living_count <= 0 then
      return {accepted = false, reason = "that wave is gone"}
    end
  elseif where ~= M.WHERE_LIBRARY then
    return {accepted = false, reason = "there is nowhere called '" .. tostring(where) .. "'"}
  end

  charge(world, player, hero_row)

  local id = world.allocate(world)
  local soldier = world.soldier
  world.give_body(world, id, world.parameters.unit.archetype[hero_row])
  soldier.team[id] = player.team
  soldier.archetype[id] = hero_row
  soldier.owner[id] = player_number
  soldier.wave[id] = 0
  soldier.leash_node[id] = 0
  soldier.speed_scale[id] = 1
  -- A hero obeys exactly one sign-post in its life and then goes straight on
  -- forever after.
  soldier.turns_left[id] = 1
  soldier.bounty_colour[id] = world.soldier.bounty_colour[id]

  -- **Lane upgrades never touch a hero, at any strength.** If a lane's upgrades
  -- also pumped the heroes standing in it, a team could stack one lane, buy every
  -- hero into it, and compound a decision it only had to make once. What a hero
  -- brings instead is abilities and timing.
  soldier.milestone[id] = (player.team == 1) and 0 or 8
  M.place_hero(world, id, player, where, target)

  player.hero_alive = player.hero_alive + 1
  player.heroes_bought = player.heroes_bought + 1

  world.raise(world, "hero_bought", {
    player = player_number, team = player.team,
    hero = hero_row, where = where,
  })

  return {accepted = true, reason = "accepted", id = id}
end
-- }}}

-- {{{ function M.refund_hero()
-- A hero that survived a challenge hands back what it cost.
--
-- The one exception to heroes being spent permanently, and it is narrow on purpose:
-- it applies to nothing else, and a hero lost in ordinary play is lost the ordinary
-- way. What it buys is that **throwing everything you have at a monster is the
-- correct move rather than a gamble against your own next three minutes** -- the one
-- fight in the game designed to be fought all-in is the one fight you are allowed to
-- go all-in on.
function M.refund_hero(world, id)
  local soldier = world.soldier
  local player = world.player[soldier.owner[id]]
  if player == nil then
    return
  end
  local cost = world.parameters.commander.hero_cost[soldier.archetype[id]]
  if cost ~= nil then
    for colour, amount in pairs(cost) do
      M.credit(world, player, colour, amount)
    end
  end
  world.raise(world, "hero_refunded", {player = player.number, hero = soldier.archetype[id]})
end
-- }}}

-- {{{ function M.hero_died()
function M.hero_died(world, owner)
  local player = world.player[owner]
  if player ~= nil and player.hero_alive > 0 then
    player.hero_alive = player.hero_alive - 1
  end
end
-- }}}

return M
