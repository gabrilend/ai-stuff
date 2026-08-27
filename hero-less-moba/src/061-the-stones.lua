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

-- 061-the-stones.lua
--
-- An upgrade stops being a number and becomes **a specific thing sitting in a
-- specific place, belonging to somebody**.
--
-- The chest counted. A team held three Whetstones and that was the whole of what
-- could be said about them. Counting is enough to stamp a body and not nearly
-- enough for the thing this game is actually about, which is three people sharing
-- one drawer and having to get along.
--
-- ## A stone belongs to the player who drew it
--
-- Nobody can take it, nobody can move what you placed with it, and **there is no
-- lock, because there is nothing to lock it against.**
--
-- That is the design's second answer to the same problem, and the first one is worth
-- knowing about because this one is shaped by its failure. The original had a shared
-- chest with locks: claim a stone so a teammate cannot move it, and a two-objection
-- rule to break a lock somebody left on. It needed a timeout to tune, an interface
-- that reminded you what you were holding hostage, and a mechanism whose whole
-- purpose was doing something to somebody against their wishes.
--
-- **A lock says *I am doing something here*** -- a statement about intent, which a
-- teammate has to take on trust and cannot check. Ownership says nothing at all,
-- because there is nothing to say.
--
-- ## And two verbs let a team be a team anyway
--
-- **Contribute** puts a stone in a communal pool where anybody may use it, forever,
-- and it appears to each of them as simply one of the stones they have. No owner
-- shown, no *this one is Sam's*. The point is not to hide who gave what -- it is
-- that **a shared thing you have to remember is shared is not shared.**
--
-- **Dismiss** is the opposite and is the one that makes a pool safe. The failure of
-- a communal pool is not theft, it is **neglect**: three people each quietly
-- assuming somebody else has it in hand. So a player may mark a communal stone *not
-- my problem* and it vanishes from their view -- and **when everybody has dismissed
-- the same stone, it comes back to all of them.**
--
-- A stone cannot fall through the floor, because the floor closes. The moment
-- nobody is looking at it, everybody is.

local bit = require("bit")

local M = {}

-- Where a stone can sit.
M.IN_CHEST  = 0
M.IN_LANE   = 1
M.IN_STONE  = 2
M.IN_LIBRARY = 3

-- Nobody owns it. Communal.
M.COMMUNAL = 0

-- {{{ function M.begin()
function M.begin(world)
  world.stone = {{}, {}}
  -- Whose turn it is to be handed the next draw, per team.
  world.next_drawer = {1, 1}
  -- What each player is pointing at and what they have asked for. Both are read by
  -- the viewer and by nothing in the simulation -- they are things people say, not
  -- things that happen.
  world.cursor = {}
  world.request = {}
  world.ping = {}
  for number = 1, world.parameters.team_size * 2 do
    world.cursor[number] = {x = 0, y = 0, tick = 0}
    world.request[number] = 0
    world.ping[number] = {x = 0, y = 0, tick = 0}
  end
end
-- }}}

-- {{{ function M.rebuild_counts()
-- Rebuilds the per-slot count arrays from the instances.
--
-- The instances are the truth and the counts are a cache. Everything that stamps a
-- body reads the cache, because a stamp is a walk over one small array per kind and
-- turning it into a walk over every stone a team owns would put the chest in the
-- hot path of every spawn.
--
-- Rebuilt whole rather than adjusted, on the same principle as every other sweep in
-- this project: a rebuild from the current truth cannot drift.
function M.rebuild_counts(world, team_id)
  local team = world.team[team_id]
  local kind_count = #world.parameters.upgrade.kind

  for kind = 1, kind_count do
    team.chest[kind] = 0
    team.library_slot[kind] = 0
    for lane = 1, world.parameters.lane_count do
      team.lane_slot[lane][kind] = 0
      team.tower_slot[lane][kind] = 0
    end
  end

  for _, stone in ipairs(world.stone[team_id]) do
    -- **A stone in transit still counts where it is**, not where it is going. It
    -- keeps applying at its old slot for the whole wave it spends moving, which is
    -- what makes a placement a bet placed two waves ahead rather than a switch.
    if stone.slot_kind == M.IN_CHEST then
      team.chest[stone.kind] = team.chest[stone.kind] + 1
    elseif stone.slot_kind == M.IN_LANE then
      team.lane_slot[stone.slot_lane][stone.kind] =
        team.lane_slot[stone.slot_lane][stone.kind] + 1
    elseif stone.slot_kind == M.IN_STONE then
      team.tower_slot[stone.slot_lane][stone.kind] =
        team.tower_slot[stone.slot_lane][stone.kind] + 1
    elseif stone.slot_kind == M.IN_LIBRARY then
      team.library_slot[stone.kind] = team.library_slot[stone.kind] + 1
    end
  end
end
-- }}}

-- {{{ function M.draw()
-- Takes stones off the deck and hands them to somebody.
--
-- **Round-robin among the team's players.** A wave wipe pays the team, but a stone
-- has to belong to a person, so the team's players take turns receiving. That keeps
-- everybody holding something to place, which is the precondition for there being a
-- conversation at all -- a player with an empty hand has nothing to contribute,
-- nothing to offer, and nothing anybody would ask them for.
function M.draw(world, team_id, count)
  local team = world.team[team_id]
  local deck = world.deck

  for _ = 1, count do
    team.deck_index = team.deck_index + 1
    local position = ((team.deck_index - 1) % #deck) + 1
    local kind = deck[position]

    local players = world.team_players[team_id]
    local holder = players[world.next_drawer[team_id]]
    world.next_drawer[team_id] = (world.next_drawer[team_id] % #players) + 1

    local stones = world.stone[team_id]
    stones[#stones + 1] = {
      id = #stones + 1,
      kind = kind,
      team = team_id,
      slot_kind = M.IN_CHEST,
      slot_lane = 0,
      held_by = holder,
      dismissed_mask = 0,
      placed_tick = world.tick,
      is_boon = 0,
      owner = 0,
      moving_to_kind = 0,
      moving_to_lane = 0,
      arrives_turn = 0,
    }
    team.draws_taken = team.draws_taken + 1
    world.raise(world, "drew", {team = team_id, kind = kind, player = holder})
  end

  M.rebuild_counts(world, team_id)
end
-- }}}

-- {{{ function M.may_touch()
-- Whether a player may move this stone: theirs, or communal.
function M.may_touch(stone, player_number)
  return stone.held_by == player_number or stone.held_by == M.COMMUNAL
end
-- }}}

-- {{{ function M.place()
-- Marks a stone to move. It does not arrive yet.
--
-- **An upgrade does not arrive the instant you place it.** It is marked to move and
-- it takes one full wave to get there, applying at its old slot the whole time, so a
-- placement lands two waves after the command with one wave of unchanged behaviour
-- in between.
--
-- That delay is the entire negotiation layer. A team that could move every stone
-- every tick would simply keep all of them wherever the fighting currently is, and
-- there would be nothing to argue about.
--
-- It is also a **message, and not an opt-in one.** Every teammate can see that a
-- stone is in transit and where it is going, for a full wave, before it lands. You
-- cannot move an upgrade quietly; your teammates get a wave's notice, which is
-- exactly enough time to say something about it.
function M.place(world, player_number, stone_id, slot_kind, slot_lane)
  local player = world.player[player_number]
  local stone = world.stone[player.team][stone_id]

  if stone == nil then
    return {accepted = false, reason = "there is no such stone"}
  end
  if not M.may_touch(stone, player_number) then
    return {accepted = false, reason = "that stone belongs to somebody else"}
  end
  if stone.arrives_turn ~= 0 then
    return {accepted = false, reason = "that stone is already on its way -- call it back first"}
  end
  if slot_kind == stone.slot_kind and slot_lane == stone.slot_lane then
    return {accepted = false, reason = "it is already there"}
  end
  if slot_kind == M.IN_LANE or slot_kind == M.IN_STONE then
    if slot_lane < 1 or slot_lane > world.parameters.lane_count then
      return {accepted = false, reason = "there is no lane " .. tostring(slot_lane)}
    end
  end

  stone.moving_to_kind = slot_kind
  stone.moving_to_lane = slot_lane
  -- Two wave turns out: the wave spawning next is stamped from the old slot, and
  -- the one after that is the first born with it in its new home.
  stone.arrives_turn = (world.wave_turn or 0) + 2

  world.raise(world, "stone_moving", {
    team = player.team, player = player_number, stone = stone_id,
    kind = stone.kind, to_kind = slot_kind, to_lane = slot_lane,
  })
  return {accepted = true, reason = "accepted"}
end
-- }}}

-- {{{ function M.cancel()
-- Calls a move back. Free, and available any time before it lands.
--
-- Nothing was spent, nothing was consumed, and the stone has been applying at its
-- old slot the entire time -- so refusing a cancel would punish a player for a
-- misclick with a full wave of watching their mistake crawl toward them, for
-- nobody's benefit.
--
-- It does cost something honest: **the message your teammates were reading can
-- evaporate.** A teammate who saw the mark, decided it was fine, and moved on will
-- not be told it never happened. So a transit is a statement of intent rather than a
-- promise.
function M.cancel(world, player_number, stone_id)
  local player = world.player[player_number]
  local stone = world.stone[player.team][stone_id]

  if stone == nil then
    return {accepted = false, reason = "there is no such stone"}
  end
  if not M.may_touch(stone, player_number) then
    return {accepted = false, reason = "that stone belongs to somebody else"}
  end
  if stone.arrives_turn == 0 then
    return {accepted = false, reason = "that stone is not going anywhere"}
  end

  stone.moving_to_kind = 0
  stone.moving_to_lane = 0
  stone.arrives_turn = 0
  world.raise(world, "stone_stayed", {
    team = player.team, player = player_number, stone = stone_id,
  })
  return {accepted = true, reason = "accepted"}
end
-- }}}

-- {{{ function M.land_transits()
-- Moves everything whose wave has come. Called once per wave turn, before the wave
-- is spawned, so the bodies leaving are stamped from the board as it now is.
function M.land_transits(world, turn)
  for team_id = 1, 2 do
    local moved = false
    for _, stone in ipairs(world.stone[team_id]) do
      if stone.arrives_turn ~= 0 and turn >= stone.arrives_turn then
        stone.slot_kind = stone.moving_to_kind
        stone.slot_lane = stone.moving_to_lane
        stone.placed_tick = world.tick
        stone.moving_to_kind = 0
        stone.moving_to_lane = 0
        stone.arrives_turn = 0
        moved = true
        world.raise(world, "stone_landed", {
          team = team_id, stone = stone.id, kind = stone.kind,
          slot_kind = stone.slot_kind, slot_lane = stone.slot_lane,
        })
      end
    end
    if moved then
      M.rebuild_counts(world, team_id)
      -- Stone that gained or lost something re-stamps the bodies standing under it.
      for lane = 1, world.parameters.lane_count do
        world.chest.restamp_stone(world, team_id, lane)
      end
    end
  end
end
-- }}}

-- {{{ function M.contribute()
-- Lets go of a stone completely. One-way.
--
-- A stone in the pool does not come back to you, because *whose is it really* is
-- exactly the question the pool exists to delete.
function M.contribute(world, player_number, stone_id)
  local player = world.player[player_number]
  local stone = world.stone[player.team][stone_id]

  if stone == nil then
    return {accepted = false, reason = "there is no such stone"}
  end
  if stone.held_by ~= player_number then
    return {accepted = false, reason = "that is not yours to give"}
  end

  stone.held_by = M.COMMUNAL
  stone.dismissed_mask = 0
  world.raise(world, "stone_contributed", {
    team = player.team, player = player_number, stone = stone_id, kind = stone.kind,
  })
  return {accepted = true, reason = "accepted"}
end
-- }}}

-- {{{ function M.offer()
-- Puts a stone in one person's hands, because you think they specifically should
-- have it.
--
-- The only verb in the game that transfers anything. It costs the giver something
-- real and visible, cannot be done by accident, and **cannot be done *to*
-- somebody** -- which is what makes it a strictly kinder instrument than a lock
-- ever was.
function M.offer(world, player_number, stone_id, to_player)
  local player = world.player[player_number]
  local stone = world.stone[player.team][stone_id]
  local receiver = world.player[to_player]

  if stone == nil then
    return {accepted = false, reason = "there is no such stone"}
  end
  if stone.held_by ~= player_number then
    return {accepted = false, reason = "that is not yours to give"}
  end
  if receiver == nil or receiver.team ~= player.team then
    return {accepted = false, reason = "they are not on your team"}
  end

  stone.held_by = to_player
  stone.dismissed_mask = 0
  -- A request that has been answered stops standing.
  if world.request[to_player] == stone_id then
    world.request[to_player] = 0
  end
  world.raise(world, "stone_offered", {
    team = player.team, player = player_number, to = to_player,
    stone = stone_id, kind = stone.kind,
  })
  return {accepted = true, reason = "accepted"}
end
-- }}}

-- {{{ function M.dismiss()
-- *Not my problem.* Removes a communal stone from one player's view.
--
-- **And when every player has dismissed the same stone, it comes back to all of
-- them.** That single rule is what makes the pool safe: a stone cannot fall through
-- the floor, because the floor closes. The moment nobody is looking at it,
-- everybody is.
--
-- It turns *I assumed you had it* -- which is silent, permanent, and only discovered
-- when a lane collapses -- into something that resurfaces on its own.
function M.dismiss(world, player_number, stone_id)
  local player = world.player[player_number]
  local stone = world.stone[player.team][stone_id]

  if stone == nil then
    return {accepted = false, reason = "there is no such stone"}
  end
  if stone.held_by ~= M.COMMUNAL then
    return {accepted = false, reason = "only a stone in the pool can be set aside"}
  end

  local seat = 0
  for index, number in ipairs(world.team_players[player.team]) do
    if number == player_number then seat = index break end
  end
  stone.dismissed_mask = bit.bor(stone.dismissed_mask, bit.lshift(1, seat - 1))

  local everybody = bit.lshift(1, #world.team_players[player.team]) - 1
  if bit.band(stone.dismissed_mask, everybody) == everybody then
    stone.dismissed_mask = 0
    world.raise(world, "stone_resurfaced", {
      team = player.team, stone = stone_id, kind = stone.kind,
    })
  else
    world.raise(world, "stone_dismissed", {
      team = player.team, player = player_number, stone = stone_id,
    })
  end
  return {accepted = true, reason = "accepted"}
end
-- }}}

-- {{{ function M.visible_to()
-- Whether a stone appears in a player's own view of the chest.
--
-- A dismissed stone is gone from **theirs**, not from the pool. Everybody else can
-- still see it and place it.
function M.visible_to(world, stone, player_number)
  if stone.held_by == player_number then
    return true
  end
  if stone.held_by ~= M.COMMUNAL then
    return false
  end
  local team = world.player[player_number].team
  local seat = 0
  for index, number in ipairs(world.team_players[team]) do
    if number == player_number then seat = index break end
  end
  return bit.band(stone.dismissed_mask, bit.lshift(1, seat - 1)) == 0
end
-- }}}

-- {{{ function M.request()
-- *I would like that one.*
--
-- The weakest verb here, deliberately, and it exists for a reason worth remembering:
-- **refusing to build it does not prevent it.** Players will ask over voice, where
-- the design cannot rate-limit it, cannot make it ignorable without awkwardness, and
-- cannot stop it becoming a running commentary on what a teammate is holding.
--
-- So: one outstanding at a time, it names one specific stone, and **ignoring one is
-- free and silent** -- no notification that you declined, no record, nothing anybody
-- can bring up later. A request that can be held against you is a demand, and this
-- game is about building each other up rather than managing each other's pockets.
--
-- Giving must stay easier than asking.
function M.request(world, player_number, stone_id)
  local player = world.player[player_number]
  local stone = world.stone[player.team][stone_id]
  if stone == nil then
    return {accepted = false, reason = "there is no such stone"}
  end
  if stone.held_by == player_number then
    return {accepted = false, reason = "you already have it"}
  end
  world.request[player_number] = stone_id
  world.raise(world, "stone_requested", {
    team = player.team, player = player_number, stone = stone_id, kind = stone.kind,
  })
  return {accepted = true, reason = "accepted"}
end
-- }}}

-- {{{ function M.ping()
-- *Look at this place.* The only one of the verbs that is not about the stones.
function M.ping(world, player_number, x, y)
  world.ping[player_number] = {x = x, y = y, tick = world.tick}
  world.raise(world, "pinged", {
    team = world.player[player_number].team, player = player_number, x = x, y = y,
  })
  return {accepted = true, reason = "accepted"}
end
-- }}}

-- {{{ function M.move_cursor()
-- *I am about to touch this.* Never opt-in, always on.
--
-- One of only two involuntary verbs, and the two of them are the load-bearing ones:
-- a cursor is synced continuously and a placement announces itself for a whole wave,
-- which together mean you can see a teammate reaching for something before they
-- touch it, and see what they did for a wave afterwards.
function M.move_cursor(world, player_number, x, y)
  local cursor = world.cursor[player_number]
  cursor.x, cursor.y, cursor.tick = x, y, world.tick
end
-- }}}

-- {{{ function M.reroll()
-- Sends a stone to the bottom of the deck and draws the next card in its place.
--
-- The one narrow exchange between the two economies: resource buys bodies, and this.
-- It does not *add* an upgrade -- it trades one -- which is why it is the only thing
-- personal resource can do to the chest and why it can never buy one outright.
function M.reroll(world, player_number, stone_id)
  local player = world.player[player_number]
  local stone = world.stone[player.team][stone_id]

  if stone == nil then
    return {accepted = false, reason = "there is no such stone"}
  end
  if not M.may_touch(stone, player_number) then
    return {accepted = false, reason = "that stone belongs to somebody else"}
  end
  if stone.slot_kind ~= M.IN_CHEST then
    return {accepted = false, reason = "only an unplaced stone can be rerolled"}
  end
  if stone.arrives_turn ~= 0 then
    return {accepted = false, reason = "that stone is already on its way"}
  end

  local price = world.parameters.upgrade.deck.reroll_cost
  local short = {}
  for colour, amount in pairs(price) do
    if player.points[colour] < amount then
      short[#short + 1] = string.format("%d more %s", amount - player.points[colour],
        world.parameters.commander.colour[colour].name)
    end
  end
  if #short > 0 then
    return {accepted = false, reason = "a reroll needs " .. table.concat(short, " and ")}
  end
  for colour, amount in pairs(price) do
    player.points[colour] = player.points[colour] - amount
  end

  local was = stone.kind
  world.team[player.team].deck_index = world.team[player.team].deck_index + 1
  local position = ((world.team[player.team].deck_index - 1) % #world.deck) + 1
  stone.kind = world.deck[position]

  M.rebuild_counts(world, player.team)
  world.raise(world, "rerolled", {
    team = player.team, player = player_number, was = was, now = stone.kind,
  })
  return {accepted = true, reason = "accepted"}
end
-- }}}

return M
