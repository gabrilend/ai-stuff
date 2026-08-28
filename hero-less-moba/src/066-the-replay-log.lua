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

-- 066-the-replay-log.lua
--
-- Records a match as it is played, and plays one back.
--
-- ## Why a replay is not a seed and a command list
--
-- Under lockstep it would be. Nothing outside the simulation ever writes into it,
-- so the seed plus every command is the whole match and the file is a few hundred
-- bytes.
--
-- This project is not lockstep. Machines reconcile continuous state on a cycle,
-- with the authority rotating between players, so the world is periodically
-- overwritten from outside. Replaying commands against a seed then reproduces *a*
-- match rather than *the* match -- the same opening, diverging quietly, ending
-- somewhere else. So a replay records three streams:
--
--   the header      once     the seed, the rules stamp, who was playing
--   commands        a few per second across six players
--   keyframes       about one per second, and this is what makes the file heavy
--
-- The keyframes are the expensive stream and the honest one. Everything else is
-- an argument that the match *could* have gone this way; the keyframes are the
-- record that it *did*.
--
-- ## The format is text, on purpose
--
-- One record per line, first word says which kind. It is three to four times the
-- size of a packed binary encoding of the same numbers, and that is the price paid
-- for a file that greps, diffs, and can be read by a person looking for the tick
-- where something went wrong. This project already has two viewers for the same
-- reason -- a second consumer keeps the first one honest -- and a replay you cannot
-- read is a replay you have to trust.
--
-- If the size ever actually hurts, the thing to compress is the body lines inside a
-- keyframe, not the format. They are already delta-encoded against the previous
-- keyframe; the next move would be to quantise harder, which costs precision in the
-- drift measurement below.
--
-- ## The hash, and what it is not
--
-- Every keyframe carries one integer summarising the whole world. It exists so a
-- failure can say *which tick* diverged rather than merely that one did.
--
-- It is taken over **quantised** positions -- sixty-fourths of a world unit, far
-- finer than a body's own radius -- because two machines running the same match
-- will differ in the last bit of a double and a hash of raw doubles would disagree
-- everywhere and mean nothing. Quantising makes it agree unless the machines
-- genuinely disagree about where something is.
--
-- The cost is a cliff: two positions either side of a sixty-fourth hash
-- differently even though they are a hair apart. So this number answers "are we
-- the same" with a usable no and an approximate yes, and **nothing is ever halted
-- because of it**. It is a measurement, not a referee.

local M = {}

local bit = require("bit")

-- How finely a position is measured before it goes into the hash and into a
-- keyframe. Sixty-fourths of a world unit: a body's radius is several units, so
-- this is far below the resolution at which any decision is made.
local QUANTUM = 64

-- And how finely the one number that is not a distance is measured. A body's
-- progress along an edge runs from 0 to 1, so sixty-fourths of it would be a step of
-- about half a body -- coarse enough that a correction would visibly snap.
local FINE = 4096

-- How often the accepted state is written down. Once a second at thirty ticks a
-- second, which is the rate the network layer reconciles at -- a replay keyframe
-- and an accepted authority snapshot are the same thing seen from two sides.
M.KEYFRAME_EVERY = 30

M.FORMAT = 1

-- {{{ local function mix()
-- One step of an FNV-style hash. Integer in, integer out, and it stays inside the
-- 32 bits `bit` operates on so that the answer does not depend on how wide this
-- machine's numbers happen to be.
local function mix(hash, value)
  hash = bit.bxor(hash, value)
  -- The FNV prime, applied as shifts and adds rather than a multiply, because a
  -- multiply of two large integers loses the low bits into a double's mantissa and
  -- the whole point of this number is that it is exact.
  hash = hash + bit.lshift(hash, 1) + bit.lshift(hash, 4) + bit.lshift(hash, 7)
              + bit.lshift(hash, 8) + bit.lshift(hash, 24)
  return bit.band(hash, 0xffffffff)
end
-- }}}

-- {{{ local function quantise()
-- A double, measured in sixty-fourths and turned into an integer. Negative
-- positions are possible on this map, so this floors rather than truncating --
-- truncation folds -0.5 and 0.5 onto the same value and the hash would be blind to
-- a body crossing the origin.
local function quantise(value)
  return math.floor(value * QUANTUM + 0.5)
end
-- }}}

-- {{{ function M.hash_world()
-- One integer summarising the whole world.
--
-- Walked in id order rather than in the frame's live order, because the live list
-- is built by a sweep whose order is an implementation detail and the hash must not
-- change when that sweep is rewritten.
function M.hash_world(world)
  local soldier = world.soldier
  local hash = 2166136261

  hash = mix(hash, world.tick)
  hash = mix(hash, world.phase)
  hash = mix(hash, world.challenge_index)

  for id = 1, world.high_water do
    if soldier.alive[id] == 1 then
      hash = mix(hash, id)
      hash = mix(hash, quantise(soldier.x[id]))
      hash = mix(hash, quantise(soldier.y[id]))
      hash = mix(hash, quantise(soldier.health[id]))
    end
  end

  for index = 1, #world.structure do
    local structure = world.structure[index]
    hash = mix(hash, structure.alive)
    hash = mix(hash, quantise(structure.health))
  end

  return hash
end
-- }}}

-- {{{ local function stamp_of()
-- The rules stamp: one integer over every number that shapes a match.
--
-- Computed from the parameter tree rather than written down by a person, because a
-- version number a person maintains is a version number that is wrong the first
-- time somebody edits a catalogue without thinking about replays. Change a
-- soldier's health and this changes; change a comment and it does not.
--
-- Keys are visited in sorted order so that the answer does not depend on the hash
-- table's iteration order, which is the same discipline the simulation itself is
-- held to.
local function stamp_of(value, hash)
  hash = hash or 2166136261
  local kind = type(value)

  if kind == "number" then
    return mix(hash, quantise(value))
  elseif kind == "string" then
    for index = 1, #value do
      hash = mix(hash, value:byte(index))
    end
    return hash
  elseif kind == "boolean" then
    return mix(hash, value and 1 or 0)
  elseif kind ~= "table" then
    -- A function or a userdata in the parameters would mean the tree has stopped
    -- being data, which is a design change worth stopping for.
    error("the parameters hold a " .. kind .. ", which cannot be stamped")
  end

  -- Keys are kept in their own types and ordered numbers-before-names, rather than
  -- all turned into strings and sorted -- turning them into strings makes "10" sort
  -- before "9", which is stable but reads as a bug the first time somebody prints
  -- the walk to find out why two stamps differ.
  local numbers, names = {}, {}
  for key in pairs(value) do
    if type(key) == "number" then
      numbers[#numbers + 1] = key
    else
      -- The root of the tree carries the project's own path, which is different on
      -- every machine and has nothing to do with the rules.
      if key ~= "root" then
        names[#names + 1] = key
      end
    end
  end
  table.sort(numbers)
  table.sort(names)

  for _, key in ipairs(numbers) do
    hash = stamp_of(key, hash)
    hash = stamp_of(value[key], hash)
  end
  for _, key in ipairs(names) do
    hash = stamp_of(key, hash)
    hash = stamp_of(value[key], hash)
  end
  return hash
end
-- }}}

-- {{{ function M.rules_stamp()
function M.rules_stamp(parameters)
  return stamp_of(parameters)
end
-- }}}

-- {{{ function M.begin()
-- Hung on every world, recording or not.
--
-- **Not recording is a state, not an absence.** The sink is the integer 0 rather
-- than nil, so the tick's logging rows ask "is the sink zero" instead of asking
-- whether a field exists -- and a world that is missing the field entirely is a
-- bug that stops the program rather than one that silently records nothing.
function M.begin(world)
  world.replay = {
    sink = 0,
    every = M.KEYFRAME_EVERY,
    -- The previous keyframe's quantised state, so a keyframe can be written as
    -- what changed. Indexed by body id, and **allocated for every id the world can
    -- ever hold** rather than filled in as bodies appear -- a sparse table would make
    -- every lookup here a question about whether a key exists, and this project does
    -- not ask that question anywhere else.
    --
    -- The integer 0 means "not currently written down". Anything else is a table of
    -- the three quantised numbers last recorded for that body.
    previous = {},
    previous_stone = {},
    written = 0,
    commands = 0,
  }
  for id = 1, world.capacity do
    world.replay.previous[id] = 0
  end
  for index = 1, #world.structure do
    world.replay.previous_stone[index] = 0
  end
end
-- }}}

-- {{{ local function write_header()
local function write_header(world, sink)
  local parameters = world.parameters
  sink:write("replay ", M.FORMAT, "\n")
  sink:write("seed ", parameters.seed, "\n")
  sink:write("rules ", M.rules_stamp(parameters), "\n")
  sink:write("keyframe_every ", world.replay.every, "\n")
  sink:write("team_size ", parameters.team_size, "\n")
  sink:write("opening_tick ", world.tick, "\n")

  -- Who was playing. A commander decides which colours a player can spend, which
  -- decides what they could buy, so a replay without them is a replay of a match
  -- whose refusals cannot be explained.
  for number = 1, #world.player do
    local player = world.player[number]
    sink:write("player ", number, " ", player.commander, " ", player.team, "\n")
  end
  sink:write("header_end\n")
end
-- }}}

-- {{{ function M.record_into()
-- Opens a file and starts recording. Called once, before the first tick.
--
-- Recording is deliberately not something a match can be switched into halfway:
-- a replay that begins at tick four thousand has no header describing the world
-- it began in, and would replay as a different match that happens to agree for a
-- while.
function M.record_into(world, path)
  if world.replay.sink ~= 0 then
    error("this match is already being recorded into " .. tostring(world.replay.path))
  end
  local sink, message = io.open(path, "w")
  if sink == nil then
    error("cannot record a replay into " .. path .. ": " .. tostring(message))
  end
  world.replay.sink = sink
  world.replay.path = path
  write_header(world, sink)
  M.log_keyframe(world, true)
  return path
end
-- }}}

-- {{{ function M.record_commands()
-- A tick's commands, written down before they are applied.
--
-- Before, because applying them empties the queue -- and because a command that is
-- refused still belongs in the record. A replay that held only the accepted
-- commands would be a replay in which nobody ever made a mistake, and the refusals
-- are half of what anybody would watch a replay to understand.
function M.record_commands(world)
  local log = world.replay
  if log.sink == 0 then
    return
  end
  local queue = world.command_queue
  for index = 1, #queue do
    local command = queue[index]
    log.sink:write("command ", world.tick, " ", command.player, " ", command.verb)
    -- The arguments, by name, sorted -- so that two recordings of the same command
    -- are the same bytes and a replay file diffs cleanly against another.
    local keys = {}
    for key, value in pairs(command) do
      if key ~= "player" and key ~= "verb" and key ~= "arrival"
         and type(value) ~= "table" then
        keys[#keys + 1] = key
      end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
      log.sink:write(" ", key, "=", tostring(command[key]))
    end
    log.sink:write("\n")
    log.commands = log.commands + 1
  end
end
-- }}}

-- {{{ function M.log_keyframe()
-- The accepted state, written as what changed since the last one.
--
-- Delta-encoded because most of a keyframe is unchanged from the one a second
-- earlier -- bodies standing in a fight move not at all, and the ones walking move
-- along one axis. A body that has left the field is written once as `gone` and then
-- forgotten, which is what keeps the deltas from growing as a match goes on.
function M.log_keyframe(world, forced)
  local log = world.replay
  if log.sink == 0 then
    return
  end
  if not forced and world.tick % log.every ~= 0 then
    return
  end

  local soldier = world.soldier
  local lines, count = {}, 0

  for id = 1, world.high_water do
    local was = log.previous[id]
    if soldier.alive[id] == 1 then
      -- **What is written down is what the simulation reads, not what it draws.**
      --
      -- A body's x and y are derived from its lane coordinates on every move pass.
      -- Writing them into a keyframe and correcting them at playback was the first
      -- version of this, and it did precisely nothing: the next move pass recomputed
      -- them from the lane coordinates a moment later and the correction was gone,
      -- while every count in the report said it had been applied.
      --
      -- So the authoritative set goes in: which lane, how far along it, how far
      -- across it, which edge of the path and how far into that edge, and which way
      -- the body is facing. Those are what the walk actually consults.
      --
      -- x and y go in as well, and they are the one piece of redundancy in this
      -- format. They are there for the reader: "along 812.5, across -18" is not a
      -- place a person can picture, and this file is meant to be opened by somebody
      -- looking for the moment something went wrong.
      local x, y = quantise(soldier.x[id]), quantise(soldier.y[id])
      local health = quantise(soldier.health[id])
      local along  = quantise(soldier.lane_along[id])
      local across = quantise(soldier.lane_across[id])
      local progress = math.floor(soldier.progress[id] * FINE + 0.5)
      if was == 0 or was[1] ~= x or was[2] ~= y or was[3] ~= health
         or was[4] ~= along or was[5] ~= across or was[6] ~= progress then
        count = count + 1
        -- The unchanging half of a body -- team, flavour, archetype -- is repeated on
        -- every line it appears on rather than sent once when it is born. It costs a
        -- few bytes and it buys a file where one line describes one body completely,
        -- so a person reading a keyframe does not have to scroll backwards through the
        -- match to find out what they are looking at.
        lines[count] = string.format("body %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
          id, x, y, health, soldier.team[id], soldier.flavour[id],
          soldier.archetype[id],
          soldier.lane[id], along, across, soldier.path_index[id],
          soldier.node_from[id], soldier.node_to[id], progress)
        log.previous[id] = {x, y, health, along, across, progress}
      end
    elseif was ~= 0 then
      count = count + 1
      lines[count] = "gone " .. id
      log.previous[id] = 0
    end
  end

  for index = 1, #world.structure do
    local structure = world.structure[index]
    local health = quantise(structure.health)
    local was = log.previous_stone[index]
    if was == 0 or was[1] ~= health or was[2] ~= structure.alive then
      count = count + 1
      lines[count] = string.format("stone %d %d %d", index, health, structure.alive)
      log.previous_stone[index] = {health, structure.alive}
    end
  end

  log.sink:write("frame ", world.tick, " ", M.hash_world(world), " ",
                 world.phase, " ", world.challenge_index, " ", count, "\n")
  for index = 1, count do
    log.sink:write(lines[index], "\n")
  end
  log.written = log.written + 1
end
-- }}}

-- {{{ function M.close()
-- Ends the file with what the match came to.
--
-- The ending is written here rather than by whoever was running the match, so that
-- a replay cut short by a crash is missing its last line and says so by being
-- missing it, rather than looking complete and being wrong about the winner.
function M.close(world, winner)
  local log = world.replay
  if log.sink == 0 then
    return 0
  end
  log.sink:write("end ", world.tick, " ", winner or 0, "\n")
  log.sink:close()
  log.sink = 0
  return log.written
end
-- }}}

-- {{{ local function split()
local function split(line)
  local parts = {}
  for word in line:gmatch("%S+") do
    parts[#parts + 1] = word
  end
  return parts
end
-- }}}

-- {{{ local function read_value()
-- A command argument comes back off the line as a string. Numbers are turned back
-- into numbers and everything else is left alone, because a verb that took a string
-- must receive a string -- a lane called "top" is not the number 0.
local function read_value(text)
  local number = tonumber(text)
  if number ~= nil then
    return number
  end
  if text == "true" then return true end
  if text == "false" then return false end
  return text
end
-- }}}

-- {{{ function M.read()
-- Reads a replay file into a record. Reads it whole: a replay is played back from
-- the beginning and there is no seeking, so streaming it would buy nothing and cost
-- the ability to say "this file is broken" before anything starts running.
function M.read(path)
  local source, message = io.open(path, "r")
  if source == nil then
    error("cannot read a replay from " .. path .. ": " .. tostring(message))
  end

  local replay = {
    path = path,
    player = {},
    -- Commands, indexed by the tick they were queued on. A tick with no commands
    -- has no entry, which is most of them.
    command_at = {},
    -- Keyframes in the order they were written, each with the tick it belongs to.
    keyframe = {},
    keyframe_at = {},
  }
  local frame = 0

  for line in source:lines() do
    local part = split(line)
    local kind = part[1]

    if kind == "replay" then
      replay.format = tonumber(part[2])
      if replay.format ~= M.FORMAT then
        error("this replay is format " .. tostring(replay.format) ..
              " and this program reads format " .. M.FORMAT)
      end
    elseif kind == "seed" then
      replay.seed = tonumber(part[2])
    elseif kind == "rules" then
      replay.rules = tonumber(part[2])
    elseif kind == "keyframe_every" then
      replay.every = tonumber(part[2])
    elseif kind == "team_size" then
      replay.team_size = tonumber(part[2])
    elseif kind == "opening_tick" then
      replay.opening_tick = tonumber(part[2])
    elseif kind == "player" then
      replay.player[tonumber(part[2])] = {
        commander = tonumber(part[3]),
        team = tonumber(part[4]),
      }
    elseif kind == "command" then
      local tick = tonumber(part[2])
      local command = {player = tonumber(part[3]), verb = part[4]}
      for index = 5, #part do
        local key, value = part[index]:match("^([^=]+)=(.*)$")
        if key == nil then
          error("a replay command argument does not read name=value: " .. part[index])
        end
        command[key] = read_value(value)
      end
      local at = replay.command_at[tick]
      if at == nil then
        at = {}
        replay.command_at[tick] = at
      end
      at[#at + 1] = command
    elseif kind == "frame" then
      frame = frame + 1
      replay.keyframe[frame] = {
        tick = tonumber(part[2]),
        hash = tonumber(part[3]),
        phase = tonumber(part[4]),
        challenge_index = tonumber(part[5]),
        change = {},
      }
      replay.keyframe_at[tonumber(part[2])] = frame
    elseif kind == "body" then
      local change = replay.keyframe[frame].change
      change[#change + 1] = {
        what = "body",
        id = tonumber(part[2]),
        x = tonumber(part[3]) / QUANTUM,
        y = tonumber(part[4]) / QUANTUM,
        health = tonumber(part[5]) / QUANTUM,
        team = tonumber(part[6]),
        flavour = tonumber(part[7]),
        archetype = tonumber(part[8]),
        lane = tonumber(part[9]),
        lane_along = tonumber(part[10]) / QUANTUM,
        lane_across = tonumber(part[11]) / QUANTUM,
        path_index = tonumber(part[12]),
        node_from = tonumber(part[13]),
        node_to = tonumber(part[14]),
        progress = tonumber(part[15]) / FINE,
      }
    elseif kind == "gone" then
      local change = replay.keyframe[frame].change
      change[#change + 1] = {what = "gone", id = tonumber(part[2])}
    elseif kind == "stone" then
      local change = replay.keyframe[frame].change
      change[#change + 1] = {
        what = "stone",
        index = tonumber(part[2]),
        health = tonumber(part[3]) / QUANTUM,
        alive = tonumber(part[4]),
      }
    elseif kind == "end" then
      replay.ended_at = tonumber(part[2])
      replay.winner = tonumber(part[3])
    elseif kind ~= "header_end" then
      error("a replay holds a record this program does not know: " .. tostring(kind))
    end
  end

  source:close()

  if replay.ended_at == nil then
    -- Loud, because the alternative is playing back most of a match and stopping
    -- somewhere arbitrary while looking like it finished.
    replay.truncated = true
  end
  return replay
end
-- }}}

-- {{{ function M.check_rules()
-- Whether a replay was recorded under the rules this program is running.
--
-- Refused loudly rather than migrated. A replay recorded before a balance change
-- is a recording of a different game; playing it under the new numbers produces a
-- match that diverges within seconds and blames the replay system for it.
function M.check_rules(replay, parameters)
  local stamp = M.rules_stamp(parameters)
  if replay.rules == stamp then
    return true, stamp
  end
  return false, stamp
end
-- }}}

-- {{{ function M.compare_keyframe()
-- Measures how far a world is from a recorded keyframe, and optionally puts it
-- back.
--
-- The measurement is the useful half. The hash answers "are we the same" with a
-- cliff -- two positions a hair apart on either side of a sixty-fourth hash
-- differently -- so it can say *that* two runs disagree and never *how much*. This
-- returns the mean distance, in world units, between where each body is and where
-- the record says it was, which is the number a person actually wants: half a unit
-- is two machines rounding differently, and forty units is a different match.
--
-- Correcting is what a live match does under a rotating authority: the world is
-- told where things are rather than working it out. Only position and health are
-- overwritten, because only position and health are what the authority sends --
-- who is targeting whom, cooldowns, and what each body is carrying are left to the
-- simulation on both machines.
--
-- Returns: how many bodies were compared, how many the record had that this run
-- could not be reconciled with -- dead here, or standing in a different lane -- and
-- the mean distance across the ones it could compare.
function M.compare_keyframe(world, keyframe, correcting)
  local soldier = world.soldier
  local compared, missing, total_distance = 0, 0, 0

  for index = 1, #keyframe.change do
    local change = keyframe.change[index]
    if change.what == "body" then
      -- **Only a body that agrees with the record about where it structurally is can
      -- be corrected.** Same slot, and the same lane.
      --
      -- The authority sends continuous state -- how far along, how much health. It
      -- does not send *decisions*, and which lane a body is walking is a decision,
      -- taken once at a junction. Two runs that disagree about that have diverged in
      -- a way no amount of position can repair, and writing the record's lane number
      -- onto the body does not repair it either: it produces a body standing in a
      -- lane it never entered, with a path index into a path it is not on, which the
      -- walk then crashes on. Which is how this was found.
      --
      -- So a structural disagreement is counted and left alone. That count is the
      -- honest report of how far apart two runs have got.
      local same_place = soldier.alive[change.id] == 1
                         and soldier.lane[change.id] == change.lane
      if same_place then
        local dx = soldier.x[change.id] - change.x
        local dy = soldier.y[change.id] - change.y
        compared = compared + 1
        total_distance = total_distance + math.sqrt(dx * dx + dy * dy)
        if correcting then
          -- The authoritative set first, then the derived pair. The derived pair is
          -- written too so that a frame drawn between this correction and the next
          -- move pass shows the corrected place rather than the old one -- one frame,
          -- but it is the frame somebody is looking at.
          soldier.lane_along[change.id] = change.lane_along
          soldier.lane_across[change.id] = change.lane_across
          soldier.path_index[change.id] = change.path_index
          soldier.node_from[change.id] = change.node_from
          soldier.node_to[change.id] = change.node_to
          soldier.progress[change.id] = change.progress
          soldier.health[change.id] = change.health
          soldier.x[change.id] = change.x
          soldier.y[change.id] = change.y
        end
      else
        missing = missing + 1
      end
    elseif change.what == "stone" and correcting then
      local structure = world.structure[change.index]
      structure.health = change.health
      structure.alive = change.alive
    end
  end

  local mean = 0
  if compared > 0 then
    mean = total_distance / compared
  end
  return compared, missing, mean
end
-- }}}

-- {{{ function M.play()
-- Plays a replay back through a real world and reports how closely it agreed.
--
-- The world is a normal one, ticked normally. The replay only ever does two things
-- to it: queue the commands that were queued, and, at each keyframe, measure the
-- distance and optionally correct it. Commands arrive through the same queue the
-- viewer and the bots use, so a recorded match and a played one are the same
-- program.
--
-- The options, all of them optional:
--
--   correcting  put the world back on the record at each keyframe. What a live
--               match does; leaving it off is how the same-machine determinism
--               claim gets tested.
--   until_tick  stop early. This is how a test puts a disturbance into the middle
--               of a playback without this function having to know that tests
--               exist, and it is how a person watches half a match.
--   each_tick   called with the world after every tick. The hook the terminal
--               viewer draws through -- **there is one playback loop**, and a
--               second one written for the sake of drawing would be a second
--               program that agreed with this one until it did not.
--
-- Returns a report:
--
--   ticks        how far it got
--   frames       how many keyframes were checked
--   agreed       how many matched the recorded hash exactly
--   first_drift  the tick of the first disagreement, or 0
--   missing      bodies the record had that this run did not
--   worst_gap    the largest mean distance from the record at any keyframe
--   last_gap     the mean distance at the final keyframe
function M.play(world, replay, tick_module, options)
  options = options or {}
  local correcting = options.correcting
  local report = {
    ticks = 0, frames = 0, agreed = 0, first_drift = 0, missing = 0,
    corrected = 0, worst_gap = 0, last_gap = 0,
  }
  local last = replay.ended_at or 0
  local until_tick = options.until_tick or 0
  if until_tick > 0 and until_tick < last then
    last = until_tick
  end

  -- **The bots do not think during a playback.** Their decisions are already in the
  -- record; letting them decide again would apply every one of them twice -- once
  -- from the file and once from the brain -- and the match would diverge within a
  -- couple of minutes while every part of the machinery looked correct.
  --
  -- This is the general shape of the rule and not a special case for bots: during a
  -- playback the command stream is the only thing allowed to want anything.
  world.bot_module.begin(world, {})

  while world.tick < last do
    local next_tick = world.tick + 1
    local queued = replay.command_at[next_tick]
    if queued ~= nil then
      for index = 1, #queued do
        -- A fresh table per command rather than the one the reader built, because
        -- queueing stamps an arrival index onto it and a replay played twice would
        -- otherwise carry the first run's numbering into the second.
        local copy = {}
        for key, value in pairs(queued[index]) do
          copy[key] = value
        end
        world.commands.queue(world, copy)
      end
    end

    if not tick_module.advance(world) then
      break
    end
    report.ticks = report.ticks + 1
    if options.each_tick ~= nil then
      options.each_tick(world, report)
    end

    local frame = replay.keyframe_at[world.tick]
    if frame ~= nil then
      local keyframe = replay.keyframe[frame]
      report.frames = report.frames + 1
      if M.hash_world(world) == keyframe.hash then
        report.agreed = report.agreed + 1
      elseif report.first_drift == 0 then
        report.first_drift = world.tick
      end

      -- Measured always, corrected only when asked. Correcting is what a live match
      -- does; not correcting is how the same-machine determinism claim gets tested.
      local corrected, missing, gap = M.compare_keyframe(world, keyframe, correcting)
      report.corrected = report.corrected + corrected
      report.missing = report.missing + missing
      report.last_gap = gap
      if gap > report.worst_gap then
        report.worst_gap = gap
      end
    end
  end

  return report
end
-- }}}

return M
