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

-- 063-the-gate.lua
--
-- Put the world somewhere interesting, look at it, and only then let it move.
--
-- ## The third kind of test
--
-- This is not a unit test over a data structure, and it is not the headless runner
-- playing a whole match at speed. It is a **simulation test**: put the world in a
-- described state, inspect it, step it, and see what happens next.
--
-- Without it, every question about the middle of a match costs the first ten minutes
-- of one -- and the questions worth asking are nearly all about the middle.
--
-- ## The gate is the feature
--
-- **Nothing advances until the scenario is released.** Load, look, then say go.
--
-- That is what separates this from the runner, and it deserves stating plainly: a
-- match that begins running the instant it loads cannot be *inspected before it
-- moves*, and the most useful moment in debugging a simulation is almost always the
-- tick before the thing goes wrong.
--
-- ## A scenario is a file somebody can hand you
--
-- Written by hand, diffable, and made of the same words the documents use. **A
-- scenario that reproduces a bug is a bug report anybody can run** -- which is worth
-- more than any amount of describing what you saw.

local M = {}

-- {{{ local function put_a_wave_at()
-- Places a wave of a team's ordinary composition at a given depth along a lane,
-- measured in milestones so a scenario reads the way the game does.
local function put_a_wave_at(world, team, lane_id, milestone)
  local lane = world.map.lane[lane_id]
  local turn = (world.wave_turn or 0) + 1
  world.wave_turn = turn

  local before = #world.wave
  world.waves.spawn_pass(world)
  -- The spawner puts them at the base; a scenario wants them somewhere else, so the
  -- anchor is moved and every member is moved with it. Moving the anchor alone would
  -- leave the bodies behind and the cohesion budget would spend the next few seconds
  -- dragging them up, which is a thing a scenario should not have to wait through.
  for id = before + 1, #world.wave do
    local wave = world.wave[id]
    if wave.team == team and wave.lane == lane_id then
      wave.anchor = lane.cumulative[lane.milestone_index[milestone]]
      for body = 1, world.high_water do
        if world.soldier.alive[body] == 1 and world.soldier.wave[body] == wave.id then
          local along, across = world.formations.target_of(world, body)
          world.walking.set_lane_position(world, body, along, across)
        end
      end
    end
  end
end
-- }}}

-- {{{ M.verb
-- What a scenario file may say. Each row takes the world and the rest of the line.
--
-- A dispatch table rather than a parser with branches in it, for the same reason
-- everything else here is one: adding a thing a scenario can describe is adding a
-- row.
M.verb = {}

-- {{{ M.verb.tick
-- Start the clock somewhere other than zero.
M.verb.tick = function(world, words)
  world.tick = tonumber(words[1]) or 0

  -- **And every clock that was counting from zero is moved with it.** A scenario that
  -- jumps the tick forward without this leaves the wave timer a whole match behind,
  -- and the spawner then produces every wave it thinks it owes -- one per tick until
  -- it catches up. The first version of this file put a thousand bodies on the field
  -- in four hundred ticks that way.
  world.next_wave_tick = world.tick + world.parameters.unit.wave.interval
  world.next_stream_tick = world.tick
  world.next_rung_tick = world.tick + world.parameters.commander.rung_interval
  world.phase_ends_at = world.tick + world.parameters.boon.timing.normal
end
-- }}}

-- {{{ M.verb.phase
-- Which phase to begin in, by name.
--
-- Named rather than numbered, because a scenario is a thing a person writes and
-- `phase 2` is a worse sentence than `phase surge` in every way that matters.
M.verb.phase = function(world, words)
  local by_name = {normal = 1, surge = 2, challenge = 3, calm = 4}
  local phase = by_name[words[1]]
  if phase == nil then
    error("no phase called '" .. tostring(words[1]) .. "'")
  end
  world.phase = phase
  if phase == 2 then
    world.next_stream_tick = world.tick
    world.phase_ends_at = world.tick + world.parameters.boon.timing.surge
  elseif phase == 4 then
    world.phase_ends_at = world.tick + world.parameters.boon.timing.calm
  else
    world.phase_ends_at = world.tick + world.parameters.boon.timing.normal
  end
end
-- }}}

-- {{{ M.verb.challenge
-- Put a named monster on the field. `challenge 2` is the Field Dragon.
M.verb.challenge = function(world, words)
  world.challenge_index = tonumber(words[1]) or 1
  world.phase = 3
  world.phases.put_monsters_out(world)
end
-- }}}

-- {{{ M.verb.wave
-- `wave <team> <lane> <milestone>` -- a wave of that team's ordinary composition,
-- standing that far along.
M.verb.wave = function(world, words)
  put_a_wave_at(world, tonumber(words[1]), tonumber(words[2]), tonumber(words[3]))
end
-- }}}

-- {{{ M.verb.rubble
-- `rubble <team> <lane> <milestone>` -- a tower that has already fallen.
M.verb.rubble = function(world, words)
  local team = tonumber(words[1])
  local lane = tonumber(words[2])
  local milestone = tonumber(words[3])
  for _, structure in ipairs(world.structure) do
    if structure.team == team and structure.lane == lane
       and structure.milestone == milestone and structure.kind ~= 3 then
      structure.alive = 0
      structure.health = 0
      world.map.node[structure.node].structure = 0
      return
    end
  end
  error(string.format("team %d has no tower at lane %d milestone %d",
                      team, lane, milestone))
end
-- }}}

-- {{{ M.verb.stone
-- `stone <team> <kind> <where> [lane]` -- an upgrade already in somebody's hands or
-- already placed. `where` is chest, lane, towers or library.
M.verb.stone = function(world, words)
  local team = tonumber(words[1])
  local kind = tonumber(words[2])
  local where = {chest = 0, lane = 1, towers = 2, library = 3}
  local slot = where[words[3]]
  if slot == nil then
    error("a stone cannot be in '" .. tostring(words[3]) .. "'")
  end

  world.stones.draw(world, team, 1)
  local stone = world.stone[team][#world.stone[team]]
  stone.kind = kind
  stone.slot_kind = slot
  stone.slot_lane = tonumber(words[4]) or 0
  world.stones.rebuild_counts(world, team)
end
-- }}}

-- {{{ M.verb.points
-- `points <player> <colour> <amount>` -- what somebody is holding.
M.verb.points = function(world, words)
  local player = world.player[tonumber(words[1])]
  player.points[tonumber(words[2])] = tonumber(words[3])
end
-- }}}

-- {{{ M.verb.at
-- `at <tick> <verb> ...` -- a command that fires later.
--
-- The command script, and it is the same dispatch table: anything a scenario can
-- describe at load, it can describe happening at a tick.
M.verb.at = function(world, words)
  local when = tonumber(words[1])
  local verb = words[2]
  local rest = {}
  for index = 3, #words do
    rest[#rest + 1] = words[index]
  end
  world.gate.script[#world.gate.script + 1] = {tick = when, verb = verb, words = rest}
end
-- }}}
-- }}}

-- {{{ function M.load()
-- Reads a scenario file into a world that is already assembled, and holds it.
function M.load(world, path)
  local handle = io.open(path, "r")
  if handle == nil then
    error("no scenario at " .. path)
  end

  world.gate = {held = true, script = {}, source = path}

  for line in handle:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
      local words = {}
      for word in trimmed:gmatch("%S+") do
        words[#words + 1] = word
      end
      local verb = M.verb[words[1]]
      if verb == nil then
        error(string.format("%s: no scenario verb called '%s'", path, tostring(words[1])))
      end
      local rest = {}
      for index = 2, #words do
        rest[#rest + 1] = words[index]
      end
      verb(world, rest)
    end
  end
  handle:close()

  return world
end
-- }}}

-- {{{ function M.step()
-- Advance exactly this many ticks and hold again.
function M.step(world, tick_module, count)
  for _ = 1, count do
    -- Anything the script says fires before the tick it is stamped with.
    for index = #world.gate.script, 1, -1 do
      local entry = world.gate.script[index]
      if world.tick >= entry.tick then
        local verb = M.verb[entry.verb]
        if verb ~= nil then
          verb(world, entry.words)
        end
        table.remove(world.gate.script, index)
      end
    end
    if not tick_module.advance(world) then
      return false
    end
  end
  return true
end
-- }}}

-- {{{ function M.until_event()
-- Advance until something happens, or until a limit is reached.
--
-- The conditions are event names, which means anything the simulation already
-- announces can be waited for and nothing new has to be invented to wait on it.
function M.until_event(world, tick_module, name, limit)
  local started = world.tick
  while world.tick - started < limit do
    if not M.step(world, tick_module, 1) then
      return false, "the match ended"
    end
    for _, event in ipairs(world.event) do
      if event.name == name then
        return true, name
      end
    end
  end
  return false, "nothing happened in " .. limit .. " ticks"
end
-- }}}

-- {{{ function M.describe()
-- What the world looks like right now, as text. The thing you read at the gate.
function M.describe(world)
  local lines = {}
  local names = {"normal", "siege-surge", "challenge", "the calm", "over"}
  lines[#lines + 1] = string.format("tick %d -- %s -- %d bodies",
    world.tick, names[world.phase] or "?", world.live_count)

  for team = 1, 2 do
    local depths = {}
    for lane = 1, world.parameters.lane_count do
      depths[#depths + 1] = tostring(world.team[team].push_depth[lane])
    end
    local chest, lanes, stone = world.chest.total_held(world, team)
    lines[#lines + 1] = string.format(
      "  team %d: depth %s -- %d unplaced, %d in lanes, %d in stone",
      team, table.concat(depths, "/"), chest, lanes, stone)
  end

  local standing = {0, 0}
  for _, structure in ipairs(world.structure) do
    if structure.alive == 1 and structure.kind ~= 3 then
      standing[structure.team] = standing[structure.team] + 1
    end
  end
  lines[#lines + 1] = string.format("  towers standing: %d and %d",
    standing[1], standing[2])

  return table.concat(lines, "\n")
end
-- }}}

return M
