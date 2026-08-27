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

-- 033-commands.lua
--
-- Player intent enters the simulation here and nowhere else.
--
-- One door, for one reason: the tick is a pure function of (state, commands), and
-- that is only true if there is no second path by which a click can reach a world
-- array. The viewer holds a mouse and the simulation holds the world, and this
-- file is the whole of the border between them. A viewer that could write into
-- the world directly would make every desync and every "it worked on my machine"
-- unfindable, because the search space would be the entire program instead of
-- one queue.
--
-- Commands are queued as they arrive and applied at the top of a tick, in a fixed
-- order -- by player number, then by arrival index. Fixed rather than
-- arrival-ordered because two players clicking in the same tick must resolve the
-- same way on every machine, and "who got there first" is exactly the thing two
-- machines disagree about.
--
-- **Every refusal is returned, named, and raised as an event.** A command that
-- silently does nothing is the worst outcome available here: the player believes
-- the game has their instruction and it does not.

local M = {}

-- {{{ local function refuse()
-- The shape of a refusal. Built through a function so that every refusal in the
-- file carries the same fields and the viewer only has to know one shape.
local function refuse(reason)
  return {accepted = false, reason = reason}
end
-- }}}

local ACCEPTED = {accepted = true, reason = "accepted"}

-- {{{ local function check_kind()
-- Shared by every placement verb: the kind exists and the team actually holds an
-- unplaced one.
local function check_kind(world, team, kind)
  local kind_count = #world.parameters.upgrade.kind
  if type(kind) ~= "number" or kind < 1 or kind > kind_count then
    return refuse("there is no upgrade kind " .. tostring(kind))
  end
  if team.chest[kind] < 1 then
    return refuse("the chest holds no " .. world.parameters.upgrade.kind[kind].name)
  end
  return ACCEPTED
end
-- }}}

-- {{{ local function check_lane()
local function check_lane(world, lane)
  if type(lane) ~= "number" or lane < 1 or lane > world.parameters.lane_count then
    return refuse("there is no lane " .. tostring(lane))
  end
  return ACCEPTED
end
-- }}}

-- {{{ local function place_in_lane()
-- Moves one upgrade from the chest into a lane, where it will be stamped onto
-- every body that lane spawns from now on.
--
-- It does not touch the bodies already walking in that lane, and it never will.
-- They keep what they were born with until they die -- which is the rule that
-- makes a placement a bet rather than a switch, and turns every reassignment
-- into a decision with a delay.
local function place_in_lane(world, command)
  local team = world.team[command.team]
  local verdict = check_kind(world, team, command.kind)
  if not verdict.accepted then return verdict end
  verdict = check_lane(world, command.lane)
  if not verdict.accepted then return verdict end

  team.chest[command.kind] = team.chest[command.kind] - 1
  team.lane_slot[command.lane][command.kind] =
    team.lane_slot[command.lane][command.kind] + 1
  return ACCEPTED
end
-- }}}

-- {{{ local function place_in_stone()
-- Slots one upgrade into a lane's towers. Not into one tower -- into the lane's
-- stone as a whole, which is why felling a tower never returns anything: there
-- is nothing in a felled tower to give back, and the lane's other tower keeps
-- the upgrade.
--
-- The base towers inherit every lane's stone, so this is also, quietly, an
-- investment in the base.
local function place_in_stone(world, command)
  local team = world.team[command.team]
  local verdict = check_kind(world, team, command.kind)
  if not verdict.accepted then return verdict end
  verdict = check_lane(world, command.lane)
  if not verdict.accepted then return verdict end

  team.chest[command.kind] = team.chest[command.kind] - 1
  team.tower_slot[command.lane][command.kind] =
    team.tower_slot[command.lane][command.kind] + 1
  -- The stone's copies are corrected now rather than lazily. A guard stands at
  -- the thing it copied from for its whole life, so a guard whose tower has
  -- changed and whose numbers have not is a visible lie -- the player can see the
  -- upgrade in the slot and the body standing under it, not benefiting.
  world.restamp_stone(world, command.team, command.lane)
  return ACCEPTED
end
-- }}}

-- {{{ local function place_in_library()
-- The last stand. Upgrades cannot be slotted into base guard towers directly;
-- they go into the library, which applies them to all three base towers at once.
-- Usually only reached when the lane towers are already gone.
local function place_in_library(world, command)
  local team = world.team[command.team]
  local verdict = check_kind(world, team, command.kind)
  if not verdict.accepted then return verdict end

  team.chest[command.kind] = team.chest[command.kind] - 1
  team.library_slot[command.kind] = team.library_slot[command.kind] + 1
  for lane = 1, world.parameters.lane_count do
    world.restamp_stone(world, command.team, lane)
  end
  return ACCEPTED
end
-- }}}

-- {{{ local function recall()
-- Takes an upgrade back out of a slot and returns it to the chest, so it can be
-- put somewhere else.
--
-- Recalling from a lane does not weaken anything already walking in it, for the
-- same reason placing into one does not strengthen it. The bodies out there were
-- stamped at birth and are nobody's to change.
local function recall(world, command)
  local team = world.team[command.team]
  local kind_count = #world.parameters.upgrade.kind
  if type(command.kind) ~= "number" or command.kind < 1 or command.kind > kind_count then
    return refuse("there is no upgrade kind " .. tostring(command.kind))
  end

  local source
  if command.from == "lane" then
    local verdict = check_lane(world, command.lane)
    if not verdict.accepted then return verdict end
    source = team.lane_slot[command.lane]
  elseif command.from == "stone" then
    local verdict = check_lane(world, command.lane)
    if not verdict.accepted then return verdict end
    source = team.tower_slot[command.lane]
  elseif command.from == "library" then
    source = team.library_slot
  else
    return refuse("there is nowhere called '" .. tostring(command.from) .. "'")
  end

  if source[command.kind] < 1 then
    return refuse("there is no " .. world.parameters.upgrade.kind[command.kind].name ..
                  " there to take back")
  end

  source[command.kind] = source[command.kind] - 1
  team.chest[command.kind] = team.chest[command.kind] + 1
  if command.from ~= "lane" then
    -- Stone changed, so the bodies standing under it are rebuilt from what the
    -- tower currently holds. Cleared and rebuilt, never patched -- a rebuild from
    -- the current truth cannot drift, and an incremental adjustment will.
    if command.from == "library" then
      for lane = 1, world.parameters.lane_count do
        world.restamp_stone(world, command.team, lane)
      end
    else
      world.restamp_stone(world, command.team, command.lane)
    end
  end
  return ACCEPTED
end
-- }}}

-- {{{ local function buy_hero()
-- Spends a player's own resource on a body that fights until it dies.
--
-- The whole purchase lives in the commanders module; this is the door it comes
-- through, so that a hero bought by a person, by a bot, and by a replay all arrive
-- by the same route.
local function buy_hero(world, command)
  return world.commanders.buy(world, command.player, command.hero,
                              command.where, command.target)
end
-- }}}

-- {{{ local function set_signpost()
-- Turns one of a team's three posts.
--
-- **No lock and no objection.** Any player on a team may set any of their three at
-- any time: sign-posts are cheap, instant and reversible, and a negotiation layer
-- over something undoable in one click would be ceremony with no stakes underneath
-- it. What it costs is that a teammate can silently redirect every hero you have
-- inbound -- which is why the change raises an event rather than happening quietly.
local function set_signpost(world, command)
  if type(command.lane) ~= "number"
     or command.lane < 1 or command.lane > world.parameters.lane_count then
    return refuse("there is no lane " .. tostring(command.lane))
  end
  world.signposts.cycle(world, command.team, command.lane, command.player)
  return ACCEPTED
end
-- }}}

-- {{{ M.verb
-- The verb dispatch table. Adding a command is adding a row here, not a branch
-- somewhere in the apply loop.
M.verb = {
  place_in_lane    = place_in_lane,
  place_in_stone   = place_in_stone,
  place_in_library = place_in_library,
  recall           = recall,
  buy_hero         = buy_hero,
  set_signpost     = set_signpost,
}
-- }}}

-- {{{ function M.queue()
-- Puts a command in line. Called by the viewer, by a bot, or by a replay -- all
-- three arrive by the same route on purpose, so that a recorded match and a
-- played one are the same program.
function M.queue(world, command)
  if world.command_queue == nil then
    world.command_queue = {}
  end
  command.arrival = #world.command_queue + 1
  world.command_queue[command.arrival] = command
  return command
end
-- }}}

-- {{{ function M.apply_all()
-- The tick's first system. Drains the queue in a fixed order and raises an event
-- for every refusal.
function M.apply_all(world)
  local queue = world.command_queue
  if queue == nil or #queue == 0 then
    return
  end

  -- By player, then by arrival. Sorting rather than taking them as they came is
  -- what makes two machines agree about a tick in which two people clicked.
  table.sort(queue, function(a, b)
    if a.player ~= b.player then
      return a.player < b.player
    end
    return a.arrival < b.arrival
  end)

  for _, command in ipairs(queue) do
    local handler = M.verb[command.verb]
    if handler == nil then
      -- An unknown verb is a programming error, not a player error, and it stops
      -- the program. A player can only send verbs the interface offers.
      error("no such command verb: " .. tostring(command.verb))
    end
    local verdict = handler(world, command)
    if not verdict.accepted then
      world.raise(world, "refused", {
        player = command.player,
        verb   = command.verb,
        reason = verdict.reason,
      })
    end
  end

  world.command_queue = {}
end
-- }}}

return M
