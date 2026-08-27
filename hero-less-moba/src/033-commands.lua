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

-- {{{ local function place_stone()
-- Marks one stone to move to a slot. It does not arrive for a full wave.
local function place_stone(world, command)
  return world.stones.place(world, command.player, command.stone,
                            command.slot_kind, command.slot_lane or 0)
end
-- }}}

-- {{{ local function cancel_move()
local function cancel_move(world, command)
  return world.stones.cancel(world, command.player, command.stone)
end
-- }}}

-- {{{ local function contribute()
-- *Anyone can use this now.* One-way, permanently.
local function contribute(world, command)
  return world.stones.contribute(world, command.player, command.stone)
end
-- }}}

-- {{{ local function offer()
-- *You specifically should have this.* The only verb that transfers anything, and
-- the only one that cannot be done **to** somebody.
local function offer(world, command)
  return world.stones.offer(world, command.player, command.stone, command.to)
end
-- }}}

-- {{{ local function dismiss()
-- *Not my problem.* The floor closes: when everybody has dismissed the same stone
-- it comes back to all of them.
local function dismiss(world, command)
  return world.stones.dismiss(world, command.player, command.stone)
end
-- }}}

-- {{{ local function request()
-- *I would like that one.* Ignoring one is free and silent -- no notification that
-- you declined, no record, nothing anybody can bring up later.
local function request(world, command)
  return world.stones.request(world, command.player, command.stone)
end
-- }}}

-- {{{ local function move_cursor()
-- Where a player is pointing. Involuntary and continuous.
local function move_cursor(world, command)
  world.stones.move_cursor(world, command.player, command.x, command.y)
  return ACCEPTED
end
-- }}}

-- {{{ local function ping()
local function ping(world, command)
  return world.stones.ping(world, command.player, command.x, command.y)
end
-- }}}

-- {{{ local function reroll()
local function reroll(world, command)
  return world.stones.reroll(world, command.player, command.stone)
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

-- {{{ local function choose_boon()
local function choose_boon(world, command)
  return world.phases.choose_boon(world, command.player, command.boon)
end
-- }}}

-- {{{ M.verb
-- The verb dispatch table. Adding a command is adding a row here, not a branch
-- somewhere in the apply loop.
M.verb = {
  place_stone      = place_stone,
  cancel_move      = cancel_move,
  contribute       = contribute,
  offer            = offer,
  dismiss          = dismiss,
  request          = request,
  ping             = ping,
  move_cursor      = move_cursor,
  reroll           = reroll,
  buy_hero         = buy_hero,
  set_signpost     = set_signpost,
  choose_boon      = choose_boon,
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
