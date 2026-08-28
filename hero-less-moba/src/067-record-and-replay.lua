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

-- 067-record-and-replay.lua
--
-- Runs a match writing a replay, or plays one back and reports.
--
-- The third runner, alongside the headless one and the gate. Those two answer "how
-- did a match go" and "what does this exact moment look like"; this one answers a
-- question neither can: **did the same match happen twice.**
--
-- It is deliberately two verbs in one file rather than two files, because the pair
-- only means anything together -- a recorder nobody plays back is a recorder nobody
-- knows is broken, which is precisely the state the first version of the correction
-- was in.
--
-- Reports, and reports numbers rather than adjectives. The interesting one is the
-- gap: the mean distance, in world units, between where each body is and where the
-- record says it was. On one machine it should be zero. On two it will not be, and
-- knowing whether "not zero" means half a unit or forty is the difference between
-- floating-point noise and a different match.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/src/[^/]+$") or "."

local tick_module = loadfile(ROOT .. "/src/042-the-tick.lua")()
local modules = tick_module.load_cast(ROOT)

-- {{{ local function commas()
-- A big number with separators, because file sizes and tick counts are read by
-- people and 1312989 is not a number a person reads.
local function commas(value)
  local text = tostring(math.floor(value))
  local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end
-- }}}

-- {{{ local function record()
local function record(path, limit)
  local parameters = modules.match_parameters.load()
  local world = tick_module.assemble(modules, parameters)

  modules.replay.record_into(world, path)
  while world.tick < limit do
    if not tick_module.advance(world) then
      break
    end
  end
  local frames = modules.replay.close(world, world.winner)

  local handle = io.open(path, "rb")
  local size = handle:seek("end")
  handle:close()

  print("")
  print("recorded " .. path)
  print("")
  print(string.format("  %s ticks, %.0f seconds of match",
                      commas(world.tick),
                      world.tick / parameters.unit.ticks_per_second))
  print(string.format("  %s keyframes, one every %d ticks",
                      commas(frames), modules.replay.KEYFRAME_EVERY))
  print(string.format("  %s commands", commas(world.replay.commands)))
  print(string.format("  %s bytes, %s per second of play",
                      commas(size),
                      commas(size / (world.tick / parameters.unit.ticks_per_second))))
  local ending = (world.winner == 0) and "unfinished"
              or (world.winner == 3) and "a draw"
              or ("team " .. world.winner)
  print("  ended: " .. ending)
  print("")
end
-- }}}

-- {{{ local function play()
-- `drawing` turns this into the terminal viewer watching a replay instead of a live
-- match, which is issue 109's sixth step and the reason the playback loop takes a
-- per-tick hook. **One loop, two consumers.** A second loop written for the sake of
-- drawing would be a second program that agreed with this one right up until it did
-- not, and the disagreement would be invisible.
local function play(path, drawing)
  local parameters = modules.match_parameters.load()
  local replay = modules.replay.read(path)

  local agreed, stamp = modules.replay.check_rules(replay, parameters)
  if not agreed then
    -- Refused rather than played anyway. A replay recorded under different numbers
    -- diverges within seconds and every symptom points at the replay system rather
    -- than at the catalogue somebody edited.
    print("")
    print("This replay was recorded under different rules.")
    print("  the file says   " .. tostring(replay.rules))
    print("  this build is   " .. tostring(stamp))
    print("")
    print("Some number in a catalogue has changed since it was recorded. A replay is")
    print("only a record of the game it was played in.")
    print("")
    os.exit(1)
  end

  if replay.truncated then
    print("")
    print("This replay has no ending record -- whatever was recording it stopped")
    print("without closing the file. Playing what is there.")
  end

  local world = tick_module.assemble(modules, parameters)
  local options = {}

  if drawing then
    local viewer = loadfile(ROOT .. "/src/045-terminal-viewer.lua")()
    -- Redrawn once a second of match time rather than every tick, for the same
    -- reason the live terminal mode is: thirty frames a second of scrolling text is
    -- a blur, and piping it to a file should produce something a person can diff.
    options.each_tick = function(drawn)
      if drawn.tick % 30 == 0 then
        io.write("\027[H\027[2J")
        io.write(viewer.draw(drawn, modules.snapshot.newest(drawn), 1))
        io.write("\n  watching " .. path .. "\n")
        io.flush()
      end
    end
  end

  local report = modules.replay.play(world, replay, tick_module, options)

  print("")
  print("played back " .. path)
  print("")
  print(string.format("  %s ticks, %s keyframes", commas(report.ticks),
                      commas(report.frames)))
  print(string.format("  %s of them reproduced the record exactly",
                      commas(report.agreed)))
  if report.first_drift == 0 then
    print("  the simulation reproduced the whole match")
  else
    print(string.format("  first disagreement at tick %s",
                        commas(report.first_drift)))
    print(string.format("  worst gap %.3f world units, %s bodies unreconcilable",
                        report.worst_gap, commas(report.missing)))
  end
  print("")
end
-- }}}

local verb = arg[1] or "record"
local path = arg[2] or "/dev/shm/hero-less-moba/match.replay"

-- A dispatch table rather than a pair of branches, so adding a verb is adding a row.
local action = {
  record = function() record(path, tonumber(arg[3]) or 30000) end,
  play   = function() play(path, false) end,
  watch  = function() play(path, true) end,
}

local chosen = action[verb]
if chosen == nil then
  print("record-and-replay: no verb called '" .. tostring(verb) .. "'.")
  print("Verbs are: record <path> [ticks], play <path>, watch <path>.")
  os.exit(1)
end
chosen()
