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

-- 058-phases.lua
--
-- The shape of a match.
--
-- Four phases, and each one changes what spawns, where it goes, and what it
-- carries. The grid lives in one document and is built here as one table, because
-- a table copied into three places is a table that will disagree with itself --
-- and this one already had.
--
--                normal          surge             challenge        calm
--   spawn        waves per lane  a stream, threes  waves per lane   nothing
--   goes to      its own lane    its own lane      **the centre**   home
--   carries      lane slots      **a deal**        spawning lane    --
--   towers       normal          bare, unkillable  normal           normal
--   chest grows  yes             **no**            yes              --
--
-- ## The surge, in one idea
--
-- **Arrangement stops mattering, without anything being taken away.**
--
-- Nothing is confiscated, moved, emptied, or held back. Whatever a team slotted
-- into the top lane stays slotted into the top lane for the whole surge, and
-- placement stays open the entire time -- it simply has no effect until the surge
-- ends, which is exactly when the challenge starts and a completely different kind
-- of fight needs a completely different board.
--
-- What the surge does instead is **stop reading slots**. Every spawn, the team's
-- whole holding is dealt across the three bodies leaving that instant, from
-- scratch, one upgrade at a time.
--
-- An earlier draft had the surge confiscate the board and hand it back afterwards.
-- Watching your arrangement come apart without touching it was frustrating in a way
-- nothing bought back. **Upgrades are never moved except by a player's own hand.**
--
-- ## The challenge, in one idea
--
-- The whole match compresses into one corridor. Waves come back -- not the stream --
-- and every lane's production goes into the middle.
--
-- The lull between waves is the point. A stream would pin a monster in place
-- forever, because there would always be another body arriving. Waves give it room
-- to **lurch**: it walks while the lane is empty and slows when the next wave lands
-- on it, and a challenge you can watch advancing in stages is readable in a way a
-- continuous grind is not.

local M = {}

M.NORMAL    = 1
M.SURGE     = 2
M.CHALLENGE = 3
M.CALM      = 4
M.OVER      = 5

-- {{{ function M.begin()
function M.begin(world)
  local timing = world.parameters.boon.timing
  world.phase = M.NORMAL
  world.challenge_index = 0
  world.phase_ends_at = timing.first_normal
  world.next_stream_tick = 0
  world.monster = {}
  world.boon_offer = {}
  -- What each team has been granted. Boons reach everything a team fields, so this
  -- is read by the stamp at every birth.
  world.boons = {{}, {}}
end
-- }}}

-- {{{ function M.total_holding()
-- Everything a team owns, wherever it is sitting, as a flat list of kinds.
--
-- Placed, slotted and unplaced all count and are indistinguishable here. That is
-- the whole of what "a share of everything the team owns" means, and it is why a
-- team cannot hold upgrades back before a surge to protect them -- there is nothing
-- to protect them from.
function M.total_holding(world, team_id, into)
  local team = world.team[team_id]
  local count = 0
  for kind = 1, #world.parameters.upgrade.kind do
    local held = team.chest[kind] + team.library_slot[kind]
    for lane = 1, world.parameters.lane_count do
      held = held + team.lane_slot[lane][kind] + team.tower_slot[lane][kind]
    end
    for _ = 1, held do
      count = count + 1
      into[count] = kind
    end
  end
  for index = count + 1, #into do
    into[index] = nil
  end
  return count
end
-- }}}

-- {{{ local function deal_across()
-- Splits a team's whole holding across the bodies spawning this instant.
--
-- Starts at a random one of them and goes round in rotation, one upgrade at a time,
-- until every upgrade the team owns has been assigned. Half a second later it
-- happens again, from scratch, over the whole holding.
local function deal_across(world, team_id, bodies, count)
  if count == 0 then
    return
  end
  local holding = world.surge_scratch
  local total = M.total_holding(world, team_id, holding)
  if total == 0 then
    return
  end

  local kind_count = #world.parameters.upgrade.kind
  local dealt = world.surge_deal
  for index = 1, count do
    local slot = dealt[index]
    if slot == nil then
      slot = {}
      dealt[index] = slot
    end
    for kind = 1, kind_count do
      slot[kind] = 0
    end
  end

  -- Random start, from the surge stream, which advances several times a second
  -- while a surge runs -- far more often than any other stream, which is exactly
  -- why it is its own.
  local at = world.stream.surge[team_id]:next_below(count) - 1
  for index = 1, total do
    at = (at % count) + 1
    local kind = holding[index]
    dealt[at][kind] = dealt[at][kind] + 1
  end

  for index = 1, count do
    world.chest.apply_counts(world, bodies[index], dealt[index])
    world.soldier.health[bodies[index]] = world.soldier.health_max[bodies[index]]
  end
end
-- }}}

-- {{{ function M.stream_pass()
-- The surge's spawner. One body per lane per team, all lanes on one shared timer.
function M.stream_pass(world)
  if world.tick < world.next_stream_tick then
    return
  end
  world.next_stream_tick = world.tick + world.parameters.boon.stream.interval

  local bodies = world.surge_bodies
  for team = 1, 2 do
    local count = 0
    for lane = 1, world.parameters.lane_count do
      -- A stream body belongs to **no wave**, which is what makes a wipe
      -- undetectable during a surge and therefore why the chest cannot grow.
      local archetype = (lane % 2 == 1) and 1 or 2
      local id = world.waves.spawn_stream_body(world, team, lane, archetype)
      count = count + 1
      bodies[count] = id
    end
    deal_across(world, team, bodies, count)
  end
end
-- }}}

-- {{{ local function put_monsters_out()
-- Two monsters, at the midpoint of the centre lane, each walking at one team's
-- base. They do not fight each other and never meet.
local function put_monsters_out(world)
  local index = world.challenge_index
  local row = world.parameters.boon.challenge[index]
  local lane = world.map.lane[2]
  local midpoint = lane.cumulative[lane.milestone_index[4]]

  world.monster = {}
  for team = 1, 2 do
    local id = world.allocate(world)
    local soldier = world.soldier
    world.give_body(world, id, world.parameters.unit.archetype[row.archetype])
    -- **Team 3.** Allied with nobody and hostile to everything, including the other
    -- monster. Anything less makes a monster aimed at one base into a free ally of
    -- the other side for the whole phase.
    soldier.team[id] = 3
    soldier.archetype[id] = row.archetype
    soldier.owner[id] = 0
    soldier.wave[id] = 0
    -- Whose test it is. Bookkeeping rather than allegiance, and it decides exactly
    -- one thing: **the assigned team is paid the boon when it dies, whoever landed
    -- the blow.** A team cannot reach into the middle, finish the enemy's monster,
    -- and take their reward.
    soldier.assigned_team[id] = team
    soldier.speed_scale[id] = 1
    soldier.lane[id] = 2
    -- Walking at that team's base, which is down the path array for team 1 and up
    -- it for team 2 -- the opposite of the direction that team's own bodies walk.
    soldier.facing[id] = (team == 1) and -1 or 1
    soldier.path_index[id] = lane.milestone_index[4]
    world.walking.set_lane_position(world, id, midpoint, (team == 1) and -18 or 18)
    world.monster[#world.monster + 1] = id
  end

  world.raise(world, "challenge_began", {index = index, name = row.name})
end
-- }}}

-- {{{ local function send_everyone_home()
-- The calm. Every body on the field turns around and walks back.
--
-- Leaving the map is a thing the brain already knows how to do -- it is the leashing
-- state, with the leash set to the team's own library -- so this is a flip of two
-- fields rather than a new behaviour.
local function send_everyone_home(world)
  local soldier = world.soldier
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.flavour[id] ~= 3 then
      if soldier.team[id] == 3 then
        -- A monster left standing when the other one died. It goes; the phase it
        -- belonged to is over.
        soldier.health[id] = 0
        soldier.state[id] = 5
      else
        soldier.facing[id] = -soldier.facing[id]
        soldier.going_home[id] = 1
        soldier.target[id] = 0
        soldier.target_structure[id] = 0
        soldier.state[id] = 1
      end
    end
  end
end
-- }}}

-- {{{ local function offer_boons()
-- Each player is offered two, from the boon stream.
--
-- Two rather than three: a choice between two is a decision and a choice between
-- six is a menu.
local function offer_boons(world, team_id)
  local catalogue = world.parameters.boon
  for _, number in ipairs(world.team_players[team_id]) do
    local offer = {}
    while #offer < catalogue.boon_offer do
      local pick = world.stream.boon:next_below(#catalogue.boon)
      local already = false
      for _, held in ipairs(offer) do
        if held == pick then already = true break end
      end
      if not already then
        offer[#offer + 1] = pick
      end
    end
    world.boon_offer[number] = offer
  end
  world.raise(world, "boons_offered", {team = team_id})
end
-- }}}

-- {{{ function M.choose_boon()
-- A player takes one of the two they were offered.
--
-- Granted to the **team**, not the player, and then every living body that team
-- owns is re-stamped -- which during a calm means the heroes waiting at the library
-- and nothing else, because everything else has walked off the map.
function M.choose_boon(world, player_number, boon_id)
  local offer = world.boon_offer[player_number]
  if offer == nil then
    return {accepted = false, reason = "you have not been offered a boon"}
  end
  local valid = false
  for _, id in ipairs(offer) do
    if id == boon_id then valid = true break end
  end
  if not valid then
    return {accepted = false, reason = "that boon was not one of the two offered"}
  end

  local team = world.player[player_number].team
  world.boons[team][#world.boons[team] + 1] = boon_id
  world.boon_offer[player_number] = nil

  world.chest.restamp_team(world, team)
  world.raise(world, "boon_taken", {
    player = player_number, team = team,
    name = world.parameters.boon.boon[boon_id].name,
  })
  return {accepted = true, reason = "accepted"}
end
-- }}}

-- {{{ local function close_the_calm()
-- Nothing. An offer outlives the calm it was made in.
--
-- This used to take the first boon for anybody who had not chosen, which was the
-- only place in the whole project where something decided for a player. It is gone,
-- and the reasoning against every alternative is worth keeping because each one
-- looked reasonable:
--
--   **Take it for them.** Breaks the rule the rest of the design keeps absolutely --
--   every refusal is named and handed back, no spawn is redirected, no upgrade
--   moves except by somebody's own hand.
--
--   **Take it, but let them swap it later.** Worse, and worse in an instructive
--   way: it makes never choosing the correct play. Let the timer run out, see how
--   the match develops, then swap into whatever turned out to matter. A rule that
--   rewards not answering is a rule that teaches an awkward, bent way of playing.
--
--   **Let it lapse.** Punishes a team for one player looking away.
--
-- So the calm is simply long enough to choose in, and **the offer stays open
-- afterwards.** A player who is slow gets their boon late, which costs them the use
-- of it in the meantime and costs their team nothing. You are only ever hurting
-- yourself by being slow, and no amount of slowness curses anybody else.
local function close_the_calm(world)
end
-- }}}

-- {{{ function M.monster_died()
-- One monster is gone. Its assigned team is paid, and if both are gone the calm
-- begins.
function M.monster_died(world, assigned_team, archetype)
  local catalogue = world.parameters.boon
  local row = catalogue.challenge[world.challenge_index]
  if row ~= nil and row.pays_a_boon then
    offer_boons(world, assigned_team)
  end
  world.raise(world, "monster_slain", {team = assigned_team})
end
-- }}}

-- {{{ function M.advance()
-- The match clock. Called once a tick, last but one.
function M.advance(world)
  if world.phase == M.OVER then
    return
  end
  local timing = world.parameters.boon.timing

  if world.phase == M.NORMAL then
    if world.tick >= world.phase_ends_at then
      world.phase = M.SURGE
      world.phase_ends_at = world.tick + timing.surge
      world.next_stream_tick = world.tick
      world.raise(world, "surge_began", {})
    end
    return
  end

  if world.phase == M.SURGE then
    if world.tick >= world.phase_ends_at then
      -- A challenge begins on the tick a surge ends.
      world.phase = M.CHALLENGE
      world.challenge_index = world.challenge_index + 1
      put_monsters_out(world)
    end
    return
  end

  if world.phase == M.CHALLENGE then
    local standing = 0
    for _, id in ipairs(world.monster) do
      if world.soldier.alive[id] == 1 then
        standing = standing + 1
      end
    end
    -- The Golem never dies, so this never fires on the third challenge. The match
    -- ends when it arrives somewhere instead.
    if standing == 0 then
      world.phase = M.CALM
      world.phase_ends_at = world.tick + timing.calm
      send_everyone_home(world)
      world.raise(world, "calm_began", {})
    end
    return
  end

  if world.phase == M.CALM then
    if world.tick >= world.phase_ends_at then
      close_the_calm(world)
      world.phase = M.NORMAL
      world.phase_ends_at = world.tick + timing.normal
      -- Push depth collapsed completely when everybody walked home, and it is
      -- recomputed from the living every tick anyway -- so there is nothing to
      -- reset here, which is worth a note because it looks like an omission.
      world.raise(world, "normal_resumed", {})
    end
    return
  end
end
-- }}}

-- {{{ function M.spawn_lane_for()
-- Where a wave spawned for a given lane actually walks.
--
-- During a challenge, all three lanes' production goes into the middle -- but **a
-- funnelled body carries the upgrades of the lane it was spawned for**, not the
-- centre's. So placing into the top lane during a challenge still means something:
-- you are strengthening one of three groups converging on the middle.
--
-- The cost is legibility. Three bodies walking side by side can have wildly
-- different strength, and there is no obvious way to draw it -- which is why the
-- snapshot carries each body's spawning lane separately from the lane it is in.
function M.spawn_lane_for(world, lane)
  if world.phase == M.CHALLENGE then
    return 2
  end
  return lane
end
-- }}}

return M
