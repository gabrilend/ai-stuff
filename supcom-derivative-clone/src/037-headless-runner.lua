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

-- 037-headless-runner.lua
--
-- Plays a match with no window and reports.
--
-- The first thing in the project that runs the simulation end to end. It is what
-- the tests drive, what will play ten thousand matches overnight, and what the
-- phase 1 demo is. In order: it reads `input/` (the seed, the field's shape, the
-- players), assembles the world, opens a replay log in the RAM tier, advances the
-- tick until the tick limit or until the match ends, and returns a report; and
-- the last thing it does is write `output/goodbye`.
--
-- Given a replay log instead, it plays the logged commands into a fresh world
-- made the same way and compares the world's fingerprint at every logged tick,
-- and a mismatch names its tick.
--
-- Nothing here draws. If a picture is wanted, the caller hands the final snapshot
-- to a viewer.

local ffi = require("ffi")

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
    error("the headless runner: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local the_tick = world_module.load("the-tick")
local snapshot = world_module.load("snapshot")
local commands = world_module.load("commands")
local sightlines = world_module.load("sightlines")
local dunes = world_module.load("the-dunes")

-- {{{ local function wall_clock()
-- Seconds on the system's monotonic clock, for the report's wall time. Lua's own
-- clocks are whole seconds of the calendar or processor time; the thread pool
-- will make processor time run faster than the wall, so the wall is read here.
-- The declarations are made once per process, and a second declaration of the
-- same struct is an error LuaJIT raises, so they are guarded.
pcall(ffi.cdef, [[
  struct sdc_timespec { long seconds; long nanoseconds; };
  int clock_gettime(int clock, struct sdc_timespec *now);
]])
local now = ffi.new("struct sdc_timespec")
local function wall_clock()
  ffi.C.clock_gettime(1, now)
  return tonumber(now.seconds) + tonumber(now.nanoseconds) / 1e9
end
-- }}}

-- The report's fields in the order `lines` writes them.
M.REPORT = {"seed", "ticks", "hash", "ended", "wall_seconds", "sightline_questions",
            "sightline_seconds", "replay", "replay_checked", "mismatch_tick", "factories",
            "shortest_pattern"}

-- {{{ local function read_lines()
-- A file's lines, each with its number, comments and blank lines left out. A
-- `#` starts a comment anywhere on a line.
local function read_lines(path)
  local handle, problem = io.open(path, "r")
  if handle == nil then
    error("the headless runner: cannot read " .. path .. ": " .. tostring(problem), 3)
  end
  local found = {}
  local number = 0
  for line in handle:lines() do
    number = number + 1
    local text = line:gsub("#.*$", ""):match("^%s*(.-)%s*$")
    if text ~= "" then
      found[#found + 1] = {number = number, text = text}
    end
  end
  handle:close()
  return found
end
-- }}}

-- {{{ local function read_seed()
-- `input/seed`: exactly one line, a whole number or the word `random`.
local function read_seed(root)
  local path = root .. "/input/seed"
  local lines = read_lines(path)
  if #lines ~= 1 then
    error("the headless runner: " .. path .. " should hold one line, and holds " .. #lines, 2)
  end
  local text = lines[1].text
  if text == "random" then
    return "random"
  end
  local seed = tonumber(text)
  if seed == nil or seed ~= math.floor(seed) then
    error(string.format("the headless runner: %s line %d is '%s', not a whole number or 'random'",
                        path, lines[1].number, text), 2)
  end
  return seed
end
-- }}}

-- {{{ local function read_field()
-- `input/field`: `name: number` lines, one per shape parameter the dunes want.
local function read_field(root)
  local path = root .. "/input/field"
  local field = {}
  for _, line in ipairs(read_lines(path)) do
    local name, value = line.text:match("^([%w_]+):%s*(%S+)$")
    if name == nil or tonumber(value) == nil then
      error(string.format("the headless runner: %s line %d is '%s', not 'name: number'",
                          path, line.number, line.text), 2)
    end
    field[name] = tonumber(value)
  end
  for _, name in ipairs(dunes.PARAMETERS) do
    if field[name] == nil then
      error("the headless runner: " .. path .. " has no line for '" .. name .. "'", 2)
    end
  end
  return field
end
-- }}}

-- {{{ local function read_players()
-- `input/players`: three words a line -- a name, a team number, `person` or
-- `bot` -- and the teams numbered from one with no gap.
local function read_players(root)
  local path = root .. "/input/players"
  local players = {}
  local teams = 0
  for _, line in ipairs(read_lines(path)) do
    local name, team, kind = line.text:match("^(%S+)%s+(%d+)%s+(%S+)$")
    if name == nil or (kind ~= "person" and kind ~= "bot") or tonumber(team) < 1 then
      error(string.format("the headless runner: %s line %d is '%s', not 'name team person|bot'",
                          path, line.number, line.text), 2)
    end
    players[#players + 1] = {name = name, team = tonumber(team), bot = kind == "bot"}
    if tonumber(team) > teams then teams = tonumber(team) end
  end
  for team = 1, teams do
    local present = false
    for _, player in ipairs(players) do
      if player.team == team then present = true end
    end
    if not present then
      error("the headless runner: " .. path .. " has no player on team " .. team, 2)
    end
  end
  if teams < 2 then
    error("the headless runner: " .. path .. " names " .. teams .. " team; a match is two sides", 2)
  end
  return players, teams
end
-- }}}

-- {{{ local function project_name()
-- The project's directory name, which names its RAM tier.
local function project_name(root)
  return root:match("([^/]+)/*$")
end
-- }}}

-- {{{ local function ram_tier()
-- The RAM tier's directory for logs and artefacts, made if it is not there.
local function ram_tier(root, inner)
  local directory = "/dev/shm/" .. project_name(root) .. (inner and ("/" .. inner) or "")
  os.execute("mkdir -p '" .. directory .. "'")
  return directory
end
-- }}}

-- {{{ local function fresh_seed()
-- A seed nobody chose, for `random`: four bytes from the operating system's
-- entropy, which is the one random source outside the named streams, used once,
-- before the match exists. It is written to the seed notebook so a match worth
-- keeping can be got back.
local function fresh_seed(root)
  local handle = io.open("/dev/urandom", "rb")
  if handle == nil then
    error("the headless runner: input/seed says 'random' and /dev/urandom cannot be read", 3)
  end
  local bytes = handle:read(4)
  handle:close()
  local seed = 0
  for index = 1, 4 do
    seed = seed * 256 + bytes:byte(index)
  end
  seed = seed % 2147483648
  local notebook = io.open(ram_tier(root) .. "/seeds.log", "a")
  notebook:write(os.date("!%Y-%m-%dT%H:%M:%SZ"), " ", seed, "\n")
  notebook:close()
  return seed
end
-- }}}

-- {{{ local function choose_seed()
-- The seed, by precedence: the environment's SDC_SEED beats an option, which
-- beats input/seed. A seed that is typed is never logged, because whoever typed
-- it already has it.
local function choose_seed(root, options)
  local given = os.getenv("SDC_SEED")
  if given ~= nil and given ~= "" then
    local seed = tonumber(given)
    if seed == nil or seed ~= math.floor(seed) then
      error("the headless runner: SDC_SEED is '" .. given .. "', not a whole number", 3)
    end
    return seed
  end
  if options.seed ~= nil then
    return options.seed
  end
  local seed = read_seed(root)
  if seed == "random" then
    return fresh_seed(root)
  end
  return seed
end
-- }}}

-- {{{ local function play()
-- Advances the world tick by tick up to `ticks` ticks, timing every row, and
-- asks `after` about the world after each tick: it returns nothing to go on, or
-- a sentence saying why the play stops. Returns what ended the play and the
-- per-row seconds.
local function play(world, ticks, after)
  local seconds = {}
  while world.tick < ticks do
    local continues = the_tick.advance_timed(world, seconds)
    local stop = after(world)
    if stop ~= nil then
      return stop, seconds
    end
    if not continues then
      return "the match ended", seconds
    end
  end
  return "the tick limit", seconds
end
-- }}}

-- {{{ function M.run()
-- Plays one match from `root`'s input and the options, and returns the report.
--
-- options:
--   ticks   -- how many ticks to run; required, a whole number
--   seed    -- beats input/seed (the environment's SDC_SEED beats both)
--   field   -- a shape table that beats input/field
--   units   -- the unit capacity, beating the rules' `units`
--   replay  -- a replay log's path: play its commands and compare its hashes,
--              instead of recording a new one
--   bots    -- reserved for the bot (issue 901); nothing reads it yet
function M.run(root, options)
  options = options or {}
  local started = wall_clock()
  local log = nil
  if options.replay ~= nil then
    log = snapshot.replay(options.replay)
  end
  local ticks = options.ticks
  if log ~= nil and ticks == nil and #log.hashes > 0 then
    -- A replay with no limit given runs to just past the last tick it logged.
    ticks = log.hashes[#log.hashes].tick + 1
  end
  if type(ticks) ~= "number" or ticks ~= math.floor(ticks) or ticks < 0 then
    error("the headless runner: options.ticks is " .. tostring(ticks) .. ", not a whole number", 2)
  end

  local seed
  if log ~= nil then
    -- A replay plays its own seed, and a seed asked for besides it is a mistake.
    seed = log.seed
    if options.seed ~= nil and options.seed ~= seed then
      error("the headless runner: asked for seed " .. options.seed .. " and a replay of seed " .. seed, 2)
    end
  else
    seed = choose_seed(root, options)
  end
  local field = options.field or read_field(root)
  local _, teams = read_players(root)
  local rules = world_module.load_asset("the-rules")
  local world = the_tick.assemble({}, {field = field, units = options.units or rules.units,
                                       teams = teams, seed = seed})

  sightlines.reset_questions()
  local report = {seed = seed, ended = "", replay = "", replay_checked = 0, mismatch_tick = 0,
                  -- Counted once factories and patterns exist (issues 307, 308).
                  factories = 0, shortest_pattern = 0}
  local ended, seconds
  if log == nil then
    report.replay = ram_tier(root, "replays") .. "/seed-" .. seed .. ".log"
    snapshot.record(world, report.replay, commands)
    ended, seconds = play(world, ticks, function() end)
  else
    if log.stamp ~= snapshot.stamp(world) then
      error(string.format("the headless runner: %s was recorded from other parameters or rules"
                          .. " (stamp %08x, this match %08x)", options.replay, log.stamp,
                          snapshot.stamp(world)), 2)
    end
    for _, command in ipairs(log.commands) do
      local refusal = commands.queue(world, command)
      if refusal ~= nil then
        error("the headless runner: the replay's command was refused: " .. refusal, 2)
      end
    end
    -- After every tick, any logged hash for the tick just run is compared with
    -- the fingerprint the world took during it; the first that differs ends the
    -- play and is reported.
    local next_hash = 1
    ended, seconds = play(world, ticks, function(after)
      local pair = log.hashes[next_hash]
      -- A logged hash for the tick just run: compared, and the play stops at the
      -- first that differs. No logged hash for this tick: the play goes on.
      if pair ~= nil and pair.tick == after.tick - 1 then
        next_hash = next_hash + 1
        report.replay_checked = report.replay_checked + 1
        if after.fingerprint_tick ~= pair.tick or after.fingerprint ~= pair.hash then
          report.mismatch_tick = pair.tick
          return "a mismatch with the replay at tick " .. pair.tick
        end
      end
    end)
  end

  report.ticks = world.tick
  report.hash = snapshot.hash(world)
  report.ended = ended
  report.sightline_questions = sightlines.questions_asked()
  report.sightline_seconds = seconds["sight-and-aim"] or 0
  report.system_seconds = seconds
  report.wall_seconds = wall_clock() - started
  report.world = world

  local goodbye = io.open(root .. "/output/goodbye", "w")
  goodbye:write("headless runner\n")
  for _, line in ipairs(M.lines(report)) do
    goodbye:write(line, "\n")
  end
  goodbye:write(os.date("!%Y-%m-%dT%H:%M:%SZ"), "\n", "goodbye\n")
  goodbye:close()
  return report
end
-- }}}

-- {{{ function M.lines()
-- The report as lines of "name: value", in the order of REPORT, the hash in hex.
function M.lines(report)
  local lines = {}
  for _, name in ipairs(M.REPORT) do
    local value = report[name]
    if name == "hash" then
      value = string.format("%08x", value)
    elseif type(value) == "number" and value ~= math.floor(value) then
      value = string.format("%.3f", value)
    end
    lines[#lines + 1] = name .. ": " .. tostring(value)
  end
  return lines
end
-- }}}

return M
