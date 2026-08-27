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

-- 059-a-bot-that-plays.lua
--
-- Somebody to make the decisions, when nobody is at the keyboard.
--
-- **This is the measuring bot, not the opponent.** The distinction is in the
-- roadmap and it matters: a bot built to produce balance numbers wants to be cheap,
-- deterministic and dull, and a bot built to be played against wants to be varied,
-- surprising, and occasionally wrong in the way a person is wrong. This is the
-- first. Everything here is a rule of thumb applied the same way every time.
--
-- It exists for two reasons and the second is the surprising one.
--
-- The obvious one: ten thousand matches overnight need somebody to play them.
--
-- The other one: **without it, a match does not demonstrate its own premise.** Left
-- alone the chest fills up and nothing happens, because nothing is placing it — so
-- the one thing the whole design is about is the one thing an unattended match
-- never shows. That is not a stalemate the design predicted; it is an empty chair.
--
-- ## What it is allowed to see
--
-- Only what a player could: its own chest and slots, both teams' bodies on the
-- ground, both teams' push depths, and the command radii. It reaches into the world
-- table to read them rather than through a snapshot, which is a shortcut a
-- networked bot could not take — but **it takes no decision a player could not
-- take**, and every action it performs goes through the ordinary command queue.

local M = {}

-- How often a bot looks at the board, in ticks. Deliberately slow: a bot that acts
-- every tick is not cheap, is not human-paced, and would place upgrades faster than
-- the wave that reads them could spawn.
local THINK_INTERVAL = 90

-- {{{ local function worst_lane()
-- Which of this team's lanes is in the most trouble, measured the way the game
-- measures everything: the enemy's push depth, which is a small integer.
local function worst_lane(world, team_id)
  local enemy = (team_id == 1) and 2 or 1
  local worst, depth = 1, -1
  for lane = 1, world.parameters.lane_count do
    if world.team[enemy].push_depth[lane] > depth then
      worst, depth = lane, world.team[enemy].push_depth[lane]
    end
  end
  return worst, depth
end
-- }}}

-- {{{ local function best_lane()
-- Where this team is doing best. The other half of the only question the bot asks.
local function best_lane(world, team_id)
  local best, depth = 1, -1
  for lane = 1, world.parameters.lane_count do
    if world.team[team_id].push_depth[lane] > depth then
      best, depth = lane, world.team[team_id].push_depth[lane]
    end
  end
  return best, depth
end
-- }}}

-- {{{ local function place_something()
-- Puts one of a player's own stones somewhere, if they are holding one.
--
-- The whole policy, and it is two lines of judgement: **reinforce where you are
-- losing, unless you are losing nowhere, in which case press where you are
-- winning.** A person would do more. A measuring bot should not, because every extra
-- rule is another thing that has to be held constant while something else is being
-- measured.
--
-- Stone gets a share on a fixed rotation rather than a judgement, so that both
-- halves of the placement decision appear in the numbers instead of only the one the
-- bot happened to prefer.
--
-- **Placed per player, not per team.** A stone belongs to whoever drew it, and one
-- brain acting as a single seat would leave the other two players' stones sitting in
-- the drawer for the whole match -- which would make every balance number a
-- measurement of one third of an economy.
local function place_something(world, team_id, player_number, brain)
  local stones = world.stone[team_id]

  local mine = 0
  for _, stone in ipairs(stones) do
    if stone.slot_kind == world.stones.IN_CHEST
       and stone.arrives_turn == 0
       and world.stones.may_touch(stone, player_number) then
      mine = stone.id
      break
    end
  end
  if mine == 0 then
    return
  end

  local losing, losing_depth = worst_lane(world, team_id)
  local lane = losing
  -- Nobody is inside our first tower anywhere: nothing is in trouble, so push.
  if losing_depth <= 2 then
    lane = (best_lane(world, team_id))
  end

  brain.placements = brain.placements + 1
  local into_stone = (brain.placements % 4 == 0)

  world.commands.queue(world, {
    verb       = "place_stone",
    team       = team_id,
    player     = player_number,
    stone      = mine,
    slot_kind  = into_stone and world.stones.IN_STONE or world.stones.IN_LANE,
    slot_lane  = lane,
  })
end
-- }}}

-- {{{ local function buy_something()
-- Buys a hero if one is affordable, and puts it where the trouble is.
--
-- Prefers the library, which is the slow, safe destination, and only reaches for a
-- tower when the lane is already lost enough that the walk would waste the
-- purchase. It never picks the wave, because arriving at the frontline is the
-- aggressive read and a measuring bot should not be making aggressive reads.
local function buy_something(world, player_number, brain)
  local player = world.player[player_number]
  local roster = world.parameters.commander.commander[player.commander].roster

  for _, row in ipairs(roster) do
    if world.commanders.can_afford(world, player, row) then
      local losing, depth = worst_lane(world, player.team)
      local where, target = "library", 0

      if depth >= 4 then
        -- They are past the midpoint of that lane. Put the body closer to the
        -- fight, at whichever of our towers in it will still accept one.
        for _, structure in ipairs(world.structure) do
          if structure.alive == 1 and structure.team == player.team
             and structure.lane == losing and structure.kind ~= 3
             and world.commanders.clear_ground(world, structure) then
            where, target = "tower", structure.id
            break
          end
        end
      end

      world.commands.queue(world, {
        verb = "buy_hero", team = player.team, player = player_number,
        hero = row, where = where, target = target,
      })
      return
    end
  end
end
-- }}}

-- {{{ local function take_a_boon()
-- Takes the first of the two offered.
--
-- **Deliberately not a choice.** Which boon is better is exactly the sort of
-- judgement a measuring bot must not make, because whatever it picked would become
-- an invisible constant in every number the balance run produced.
local function take_a_boon(world, player_number)
  local offer = world.boon_offer[player_number]
  if offer == nil or #offer == 0 then
    return
  end
  world.commands.queue(world, {
    verb = "choose_boon", team = world.player[player_number].team,
    player = player_number, boon = offer[1],
  })
end
-- }}}

-- {{{ function M.begin()
-- Puts a bot behind whichever teams were asked for.
function M.begin(world, teams)
  world.bot = {}
  for _, team_id in ipairs(teams) do
    -- One brain per team rather than one per player. Three bots sharing a chest is
    -- phase nine's problem and a genuinely hard one -- a teammate that tramples a
    -- person's arrangement every wave, or is so passive the shared chest becomes
    -- single-player. This one plays a whole side, which sidesteps it entirely and
    -- is honest about doing so.
    world.bot[team_id] = {
      team = team_id,
      player = world.team_players[team_id][1],
      placements = 0,
      next_think = 0,
    }
  end
end
-- }}}

-- {{{ function M.run()
-- Every bot looks at the board, on its own slow clock.
function M.run(world)
  if world.bot == nil then
    return
  end
  for team_id, brain in pairs(world.bot) do
    if world.tick >= brain.next_think then
      brain.next_think = world.tick + THINK_INTERVAL

      -- Placing during a surge is allowed and does nothing until it ends, which is
      -- exactly the right thing for a bot to keep doing -- the board it is building
      -- is the one the challenge will be fought with.
      for _, number in ipairs(world.team_players[team_id]) do
        place_something(world, team_id, number, brain)
        take_a_boon(world, number)
        buy_something(world, number, brain)
      end
    end
  end
end
-- }}}

return M
