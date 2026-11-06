-- supcom-derivative-clone — a factory war on dunes where nothing is out of range
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

-- 035-commands.lua
--
-- The one door every player action comes through.
--
-- Every player action is a command: a verb, the tick it takes effect at, a team,
-- a player, and the few arguments the verb names. There is one way in, `queue`,
-- and one way a command takes effect, `apply_due`, which is the first row of the
-- tick. Nothing takes effect on the instant it is issued, which is what lets a
-- command arrive from another machine before its tick and be indistinguishable
-- from one issued here -- "everything can be queued" is the vision's invariant,
-- and the network gets its whole design from it.
--
-- A command the door will not take is a named refusal: returned to the caller
-- as a sentence, and written into the world's refusal ring so a viewer can show
-- it, loudly, where it happened. Refusals are the viewer's business to show and
-- never the simulation's business to repair.

local M = {}

-- {{{ local function the_world()
-- The world module, which holds the loader every module uses to find another by
-- its stem. It is found here by that same rule -- exactly one NNN-the-world.lua
-- beside this file -- because a file cannot use the loader to find the loader.
local function the_world()
  local path = debug.getinfo(1, "S").source:sub(2)
  if path:sub(1, 1) ~= "/" then
    path = os.getenv("PWD") .. "/" .. path
  end
  local here = path:match("^(.*)/[^/]+$")
  local found = {}
  local handle = io.popen("ls -1 '" .. here .. "' 2>/dev/null")
  for name in handle:lines() do
    if name:match("^%d%d%d%-the%-world%.lua$") then
      found[#found + 1] = here .. "/" .. name
    end
  end
  handle:close()
  if #found ~= 1 then
    error("commands: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local snapshot = world_module.load("snapshot")
local menu = world_module.load("energy-menu")
local truck = world_module.load("command-truck")

-- The most arguments a verb may name: the command record has this many slots.
local SLOTS = 4

-- {{{ VERBS
-- The dispatch table: a verb's name to the function that applies it. An apply
-- takes the world and the command as a table and returns nothing, or a refusal
-- naming why it cannot be done -- a pattern with a point in the water, a cell
-- already taken. Adding a verb is adding a row here and its arguments below.
M.VERBS = {}

-- {{{ M.VERBS["noop"]
-- Does nothing. It exists because a machine in lockstep must be able to send a
-- batch with nothing in it.
M.VERBS["noop"] = function()
end
-- }}}

-- {{{ M.VERBS["set-energy-level"]
-- Presses one of the energy menu's four buttons for a team, through the menu
-- (issue 302), which alone decides what the buttons are and that there is
-- never a fifth. A level it will not take is a refused command.
M.VERBS["set-energy-level"] = function(world, command)
  local reason = menu.refusal(world, command.team, command.level)
  if reason ~= nil then
    return reason
  end
  menu.set_level(world, command.team, command.level)
end
-- }}}

-- {{{ M.VERBS["move"]
-- Points a team's command truck at a cell: the one unit a command moves
-- (issue 210). Refused when the row is not the team's truck or the cell is not
-- land.
M.VERBS["move"] = function(world, command)
  local reason = truck.owned_by(world, command.truck, command.team)
  if reason ~= nil then
    return reason
  end
  return truck.move(world, command.truck, command.x, command.y)
end
-- }}}

-- {{{ M.VERBS["launch"]
-- Launches a team's truck's plane on a compass heading, in degrees from north
-- (issue 210). Refused when the row is not the team's truck or its plane is
-- still reloading.
M.VERBS["launch"] = function(world, command)
  local reason = truck.owned_by(world, command.truck, command.team)
  if reason ~= nil then
    return reason
  end
  return truck.launch(world, command.truck, command.heading)
end
-- }}}
-- }}}

-- {{{ ARGUMENTS
-- The arguments each verb takes, by name, in the order they sit in the record's
-- argument slots. Every one is a number.
M.ARGUMENTS = {
  ["noop"] = {},
  ["set-energy-level"] = {"level"},
  ["move"] = {"truck", "x", "y"},
  ["launch"] = {"truck", "heading"},
}
-- }}}

-- {{{ the verb numbers
-- Each verb's number in the world's arrays: its place in the sorted list of
-- names, so the numbering depends on nothing but which verbs exist. Logs and
-- refusals carry names, never numbers.
M.NAMES = {}
for name in pairs(M.VERBS) do
  M.NAMES[#M.NAMES + 1] = name
end
table.sort(M.NAMES)
M.NUMBER = {}
for number, name in ipairs(M.NAMES) do
  M.NUMBER[name] = number
  if M.ARGUMENTS[name] == nil or #M.ARGUMENTS[name] > SLOTS then
    error("commands: verb '" .. name .. "' needs a list of at most " .. SLOTS .. " arguments", 1)
  end
end
-- }}}

-- {{{ local function refuse()
-- Writes a refusal into the world's ring and hands its reason back.
local function refuse(world, command, reason)
  local slot = world_module.ring_next(world, "refusal")
  local ring = world.refusal
  ring.tick[slot] = world.tick
  ring.team[slot] = type(command.team) == "number" and command.team or 0
  ring.verb[slot] = M.NUMBER[command.verb] or 0
  ring.reason[slot] = reason
  return reason
end
-- }}}

-- {{{ local function whole()
-- Whether a value is a whole number.
local function whole(value)
  return type(value) == "number" and value == math.floor(value)
end
-- }}}

-- {{{ local function judge()
-- Why the door will not take a command, or nil when it will. The order of the
-- questions is the order a person would want them answered in.
local function judge(world, command)
  local verb = command.verb
  if M.VERBS[verb] == nil then
    return "no verb is named '" .. tostring(verb) .. "'"
  end
  if not whole(command.tick) then
    return verb .. " is stamped for tick " .. tostring(command.tick)
           .. ", which is not a whole number"
  end
  if command.tick < world.tick then
    return verb .. " is stamped for tick " .. command.tick .. ", which has already run;"
           .. " the world is at tick " .. world.tick
  end
  if not whole(command.team) or command.team < 1 or command.team > world.team.capacity then
    return verb .. " is for team " .. tostring(command.team) .. ", and this match has teams 1 to "
           .. world.team.capacity
  end
  if command.player ~= nil and not whole(command.player) then
    return verb .. " names player " .. tostring(command.player) .. ", which is not a whole number"
  end
  for _, name in ipairs(M.ARGUMENTS[verb]) do
    if type(command[name]) ~= "number" or command[name] ~= command[name] then
      return verb .. " wants a number for '" .. name .. "', and was given "
             .. tostring(command[name])
    end
  end
  if world.command.count >= world.command.capacity then
    return "the command queue is full at its capacity of " .. world.command.capacity
  end
  return nil
end
-- }}}

-- {{{ function M.queue()
-- The door. A command the door takes goes to the back of the world's queue,
-- and into the replay log if one is being written; nothing is returned. A
-- command it will not take is refused by name: the reason is returned, and kept
-- in the refusal ring.
function M.queue(world, command)
  local reason = judge(world, command)
  if reason ~= nil then
    return refuse(world, command, reason)
  end
  local row = world_module.push(world, "command")
  local queue = world.command
  queue.tick[row] = command.tick
  queue.verb[row] = M.NUMBER[command.verb]
  queue.team[row] = command.team
  queue.player[row] = command.player or 0
  for slot, name in ipairs(M.ARGUMENTS[command.verb]) do
    queue["argument" .. slot][row] = command[name]
  end
  if world.record_path ~= "" then
    snapshot.note_command(world, M.unpack(world, row))
  end
end
-- }}}

-- {{{ function M.unpack()
-- A queued row as the command table it was queued from: the verb's name, the
-- tick, the team, the player, and each argument under its own name.
function M.unpack(world, row)
  local queue = world.command
  local name = M.NAMES[queue.verb[row]]
  local command = {verb = name, tick = queue.tick[row], team = queue.team[row],
                   player = queue.player[row]}
  for slot, argument in ipairs(M.ARGUMENTS[name]) do
    command[argument] = queue["argument" .. slot][row]
  end
  return command
end
-- }}}

-- {{{ function M.apply_due()
-- The tick's first row. Every queued command stamped for this tick is applied,
-- in the order it was queued, and leaves the queue. A verb that refuses at apply
-- time is recorded in the ring and does not count. Returns how many applied.
--
-- A queued command for a tick before this one can only mean the tick count was
-- moved past it without the door running, and it is refused loudly rather than
-- dropped: a command that silently never happens is the worst desync there is.
function M.apply_due(world)
  local queue = world.command
  local now = world.tick
  local applied = 0
  local row = 1
  while row <= queue.count do
    local tick = queue.tick[row]
    if tick == now then
      -- Due: applied, then removed, so the next row slides into this index.
      local command = M.unpack(world, row)
      world_module.remove(world, "command", row)
      local reason = M.VERBS[command.verb](world, command)
      if reason ~= nil then
        refuse(world, command, reason)
      else
        applied = applied + 1
      end
    elseif tick < now then
      -- Stale: a tick ran without the door. Never repaired.
      error(string.format("commands: %s for tick %d is still queued at tick %d; a tick ran without the door",
                          M.NAMES[queue.verb[row]], tick, now), 2)
    else
      -- Not yet due: it stays where it is.
      row = row + 1
    end
  end
  return applied
end
-- }}}

-- {{{ function M.refusals()
-- The refusals the ring holds, oldest first, as tables of tick, team, verb name
-- (empty for a verb nobody knows) and reason. For a viewer, which shows them.
function M.refusals(world)
  local ring = world.refusal
  local found = {}
  for back = ring.count - 1, 0, -1 do
    local slot = (ring.last - 1 - back) % ring.capacity + 1
    found[#found + 1] = {tick = ring.tick[slot], team = ring.team[slot],
                         verb = M.NAMES[ring.verb[slot]] or "", reason = ring.reason[slot]}
  end
  return found
end
-- }}}

return M
