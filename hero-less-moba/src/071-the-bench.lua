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

-- 071-the-bench.lua
--
-- Reads a test, builds the world it named, arranges it, runs it, and reports.

-- Reads a test, builds the world it named, arranges it, runs it, and reports.
--
-- ## The rule this file exists to enforce
--
-- **A test is an arrangement of functionality, and the engine is what runs it.** A test
-- file holds no functions. Every value in it is a number, a string, or a row whose
-- first word is something the engine can look up: a module in the tick's cast, a verb
-- in a ground's vocabulary, a stage in the tick's order, a reading in the measurement
-- catalogue, a comparison in the claim table.
--
-- This is not tidiness. A test that defines its own tick is testing its own tick, and
-- both of the mistakes that made [the proving ground](../docs/024-the-proving-ground.md)
-- necessary had that shape: a number read off an instrument that had quietly become a
-- different instrument. Before this file the arena had a tick of its own, the window
-- and the shell script each had their own arithmetic for how far a column had come, and
-- a scene had a Lua closure in it. All four are gone.
--
-- ## The two grounds
--
-- **Arena** -- a short straight road and only the machinery the test named. Anything
-- that moves is something the test asked for.
--
-- **Match** -- the real map, the whole cast, put into a described state by the gate's
-- verbs. For the questions that are genuinely about a whole game.
--
-- They differ in three things and no more: what builds the world, what vocabulary
-- arranges it, and what has to happen before each tick. Those are the three fields of a
-- row in the ground table below, which is why adding a third ground would be adding a
-- row rather than a branch.

local M = {}

-- The directories a test may live in. The name of the directory says which ground its
-- tests stand on, which is a convenience for a person reading a listing rather than a
-- rule -- the file says its own ground, and the file is what is believed.
M.where = {
  {directory = "scenes",    ground = "arena"},
  {directory = "scenarios", ground = "match"},
  {directory = "by-hand",   ground = "person"},
}

-- Every field a test may have. **Anything else is refused by name at load.** A field
-- nobody reads is a field that silently does nothing, and a misspelt `measure` that
-- quietly measured nothing would be exactly the class of mistake this whole file exists
-- to stop.
local KNOWN_FIELD = {
  file = true, covers = true, name = true, caption = true, note = true,
  ground = true, shape = true, want = true, stages = true, ticks = true,
  arrange = true, measure = true, always = true, finally = true,
  -- The two a test standing on a person has instead of stages and claims.
  run = true, ask = true,
}

-- The fields that only mean something when there is a world. A hand test that carried
-- one would be a hand test somebody had started to automate and stopped, and it would sit
-- there looking like it measured something.
local NEEDS_A_WORLD = {
  "shape", "want", "stages", "ticks", "arrange", "measure", "always", "finally",
}

-- {{{ M.ground
-- What a ground is: something that builds a world, a vocabulary that arranges it, and
-- whatever has to happen before each of its ticks.
M.ground = {}

-- {{{ M.ground.arena
M.ground.arena = {
  label = "a short straight road, and only the machinery the test named",

  -- The default when a test does not say. Marching and nothing else -- no target is
  -- acquired, nothing swings, nothing dies, no wave is due and no phase turns over.
  stages = "marching",
  measure = "marching",
  -- How long it runs when it is reported rather than watched. Nine hundred ticks is
  -- fifteen seconds of game time, which is long enough for a column to cross this road.
  ticks = 900,

  raise = function(context, test)
    local arena = context.arena
    return arena.assemble(context.modules, context.modules.match_parameters.load(),
                          test.want or {}, test.shape or {})
  end,

  vocabulary = function(context)
    return context.arena.verb
  end,

  -- Nothing happens before an arena tick. There is no script and no clock but the
  -- world's own.
  before = function() end,
}
-- }}}

-- {{{ M.ground.match
M.ground.match = {
  label = "the real map and the whole cast, put where the test asked for",

  stages = "whole_match",
  measure = "marching",
  ticks = 600,

  raise = function(context, test)
    local world = context.tick.assemble(context.modules,
                                        context.modules.match_parameters.load())
    -- The gate before the arrangement, because the `at` verb writes into the gate's
    -- script while the arrangement is being performed and would have nowhere to write.
    context.modules.gate.begin(world, test.file)
    return world
  end,

  vocabulary = function(context)
    return context.modules.gate.verb
  end,

  -- Anything the test said would happen at a later tick, happening when it said.
  before = function(context, world)
    context.modules.gate.fire_due(world)
  end,
}
-- }}}

-- {{{ M.ground.person
-- **A test whose instrument is somebody's eyes.**
--
-- A third of what the census counts is not a mechanic a world can be measured for. The
-- headless runner and the terminal viewer are tools; the proving ground is the ground the
-- other tests stand on; the whole of the drawing phase is a window that has to be looked
-- at. Those rows were never going to come off the list under a bench that reads numbers,
-- which meant a check that failed the build forever for a reason nobody could act on --
-- and a check that always fails is a check people learn to read past.
--
-- So this ground asks. A test standing on it names a command to run and a short list of
-- things to look for, and the front door walks a person through them one at a time and
-- writes down what they said. It raises no world, runs no stages and makes no claims,
-- because the person is the instrument and a number here would be a second opinion about
-- something nobody measured.
--
-- **It is still a table of nouns.** What a person is asked is a sentence somebody wrote
-- down in advance, which is the same discipline as a claim: a question invented while
-- looking at the screen is a question that agrees with whatever is on it.
M.ground.person = {
  label = "a person, looking at it",
  by_hand = true,
}
-- }}}
-- }}}

-- {{{ function M.list()
-- Every test in the project, by name, with where it lives and which ground it stands
-- on. What the front door prints when nobody named one.
--
-- Found by listing directories rather than by a kept index, because a kept index is a
-- second thing to update and the first symptom of forgetting is a test nobody runs.
function M.list(root)
  local found = {}
  for _, place in ipairs(M.where) do
    local handle = io.popen("ls -1 " .. root .. "/" .. place.directory .. "/*.lua 2>/dev/null")
    if handle ~= nil then
      for path in handle:lines() do
        local name = path:match("([^/]+)%.lua$")
        if name ~= nil then
          found[#found + 1] = {
            name = name, path = path,
            directory = place.directory, ground = place.ground,
          }
        end
      end
      handle:close()
    end
  end
  return found
end
-- }}}

-- {{{ function M.find()
-- Where the test of this name lives, whichever directory that turns out to be.
--
-- A test is named by what it shows, not by where it is filed. Making somebody know
-- which of two directories a test sits in before they can run it is making them know
-- something the computer already knows.
function M.find(root, name)
  for _, entry in ipairs(M.list(root)) do
    if entry.name == name then
      return entry
    end
  end
  return nil
end
-- }}}

-- {{{ function M.read()
-- Load a test file and refuse anything about it the engine cannot look up.
--
-- Every refusal here names the offending word. A test that is wrong should say which
-- word is wrong, because the whole file is words and the reader cannot see which one
-- the loader disliked.
function M.read(root, name)
  local entry = M.find(root, name)
  if entry == nil then
    error("no test called '" .. tostring(name) .. "'")
  end

  local chunk = loadfile(entry.path)
  if chunk == nil then
    error("could not read " .. entry.path)
  end
  local test = chunk()
  if type(test) ~= "table" then
    error(entry.path .. " did not return a table")
  end

  for field in pairs(test) do
    if KNOWN_FIELD[field] == nil then
      error(entry.path .. ": a test has no field called '" .. tostring(field) .. "'")
    end
    -- **No functions, anywhere in a test.** This is the rule, checked rather than
    -- trusted, because it is the kind of rule that decays one convenient closure at a
    -- time and each one looks reasonable on the day it is added.
    if type(test[field]) == "function" then
      error(entry.path .. ": '" .. field .. "' is a function. A test arranges what the "
            .. "engine already does; it does not define behavior of its own.")
    end
  end

  if test.name == nil or test.caption == nil then
    error(entry.path .. ": a test needs a name and a caption")
  end
  if test.covers == nil or #test.covers == 0 then
    error(entry.path .. ": a test must say which mechanics it covers")
  end

  test.file = entry.name
  test.ground = test.ground or entry.ground
  local ground = M.ground[test.ground]
  if ground == nil then
    error(entry.path .. ": there is no ground called '" .. tostring(test.ground) .. "'")
  end

  if ground.by_hand then
    if test.run == nil then
      error(entry.path .. ": a test somebody performs has to say what to run")
    end
    if test.ask == nil or #test.ask == 0 then
      error(entry.path .. ": a test somebody performs has to say what to look for")
    end

    -- **One question, one mechanic, and the mechanic has to be one this test claims.**
    --
    -- A question that is evidence for nothing in particular produces an answer nobody
    -- can act on: "it looked a bit odd" against a file covering three mechanics leaves
    -- somebody guessing which of the three to go and read. Naming the mechanic on the
    -- question is what makes an answer pickable up months later -- it lands in the
    -- record beside an issue number, and that is the whole of how a person's eyes get
    -- to be an instrument rather than an anecdote.
    local claimed = {}
    for index = 1, #test.covers do
      claimed[test.covers[index]] = true
    end
    for index = 1, #test.ask do
      local row = test.ask[index]
      if type(row) ~= "table" or row[1] == nil or row[2] == nil then
        error(entry.path .. ": question " .. index .. " is not a mechanic and a " ..
              "question. Every row of `ask` is {\"<issue>\", \"<question>\"}.")
      end
      if not claimed[row[1]] then
        error(entry.path .. ": question " .. index .. " is about mechanic " .. row[1] ..
              ", which this test does not say it covers.")
      end
    end
    for mechanic in pairs(claimed) do
      local asked = false
      for index = 1, #test.ask do
        if test.ask[index][1] == mechanic then asked = true end
      end
      if not asked then
        error(entry.path .. ": says it covers " .. mechanic .. " and asks nothing " ..
              "about it. A mechanic nobody is asked about is a mechanic nobody checked.")
      end
    end
    for index = 1, #NEEDS_A_WORLD do
      local field = NEEDS_A_WORLD[index]
      if test[field] ~= nil then
        error(entry.path .. ": '" .. field .. "' needs a world, and this test is " ..
              "performed by a person. A half-automated test looks like it measures " ..
              "something and does not.")
      end
    end
  elseif test.ask ~= nil or test.run ~= nil then
    error(entry.path .. ": 'ask' and 'run' belong to a test a person performs. This one " ..
          "stands on " .. test.ground .. ", where the instrument is a reading.")
  end

  return test, entry
end
-- }}}

-- {{{ function M.raise()
-- Build the world a test named, put it in the state the test described, and hand back
-- everything needed to run it.
--
-- The returned bench is a plain record: the test, the world, the ground's row, the
-- chosen stages, and the names of the readings to take. Nothing in it is a closure over
-- anything, so a caller can look at all of it.
function M.raise(root, test)
  if M.ground[test.ground].by_hand then
    error(test.file .. " is performed by a person and has no world to raise. " ..
          "Run it with the front door, which will walk you through it.")
  end

  local tick = loadfile(root .. "/src/042-the-tick.lua")()
  local context = {
    root    = root,
    tick    = tick,
    modules = tick.load_cast(root),
    arena   = loadfile(root .. "/src/068-the-arena.lua")(),
    measure = loadfile(root .. "/src/070-what-can-be-measured.lua")(),
  }

  local ground = M.ground[test.ground]
  local world = ground.raise(context, test)

  local verbs = ground.vocabulary(context)
  local rows = test.arrange or {}
  for index = 1, #rows do
    local row = rows[index]
    local verb = verbs[row[1]]
    if verb == nil then
      error(string.format("%s, row %d: nothing on this ground is called '%s'",
                          test.file, index, tostring(row[1])))
    end
    local rest = {}
    for at = 2, #row do
      rest[#rest + 1] = row[at]
    end
    verb(world, rest)
  end

  return {
    test    = test,
    world   = world,
    context = context,
    ground  = ground,
    stages  = tick.select(test.stages or ground.stages),
    reading = test.measure or ground.measure,
    ticks   = test.ticks or ground.ticks,
    -- The running summary of everything the standing claims are about: the lowest,
    -- highest and latest each of those readings has been. Filled in by advancing.
    seen    = {},
  }
end
-- }}}

-- {{{ function M.advance()
-- Run the bench this many ticks, through the stages the test named and no others,
-- **folding every reading the test's standing claims are about as it goes.**
--
-- The folding is the point. A run that only looked at the world when it stopped would
-- have nothing to say about the middle of it, and the middle is where a test's subject
-- usually happens -- two columns meeting, a rank piling up, a monster arriving. The
-- first version of this judged the last tick only, and reported a clean field for a run
-- in which seven pairs of bodies had stood inside each other on the way past.
--
-- Returns false the moment the world says it is finished, so a caller asking for five
-- thousand ticks of a match that ends at three hundred does not go on stepping a
-- finished world.
function M.advance(bench, count)
  local watched = bench.context.measure.readings_named(bench.test.always)
  for _ = 1, count do
    bench.ground.before(bench.context, bench.world)
    if not bench.context.tick.advance_through(bench.world, bench.stages) then
      return false
    end
    if #watched > 0 then
      bench.context.measure.fold(bench.world, watched, bench.seen)
    end
  end
  return true
end
-- }}}

-- {{{ function M.line()
-- The bench's readings as one line. The same line the window prints under the picture,
-- because it is the same function reading the same world.
function M.line(bench)
  return bench.context.measure.line(bench.world, bench.reading)
end
-- }}}

-- {{{ function M.judge()
-- Every claim the test makes, tested.
--
-- Two kinds, and the difference between them is the difference between two questions a
-- person actually asks:
--
--   * `always` -- true at **every tick of the run**. "Nobody is ever inside anybody."
--     Tested against the lowest and highest each reading reached, whichever end the
--     comparison cares about.
--   * `finally` -- true **when it stopped**. "The column reached the far end." Tested
--     against the world as it now stands.
--
-- Returns whether all of them held and a list of sentences for the ones that did not.
-- A test with no claims passes, and **says so as "watched only" rather than as
-- "passed"** at the front door -- a test that asserts nothing has not been checked, and
-- a report that counted it among the passes would be overstating what is known.
function M.judge(bench)
  local measure = bench.context.measure
  local complaints = {}
  local counted = 0

  local standing = bench.test.always or {}
  for index = 1, #standing do
    counted = counted + 1
    local held, complaint = measure.judge_over(bench.seen, standing[index])
    if not held then
      complaints[#complaints + 1] = complaint
    end
  end

  local ending = bench.test["finally"] or {}
  for index = 1, #ending do
    counted = counted + 1
    local held, complaint = measure.judge(bench.world, ending[index])
    if not held then
      complaints[#complaints + 1] = "at the end, " .. complaint
    end
  end

  return #complaints == 0, complaints, counted
end
-- }}}

-- {{{ function M.run()
-- Raise a test, run it for as long as it asked, and report.
--
-- Returns a record rather than printing one, because the same run is read three ways --
-- at a terminal, by the build, and by whatever eventually plays a phase's tests one
-- after another -- and a function that printed would force the other two to parse it
-- back out again.
function M.run(root, name)
  local test = M.read(root, name)
  local bench = M.raise(root, test)

  local before = M.line(bench)
  local finished = not M.advance(bench, bench.ticks)
  local after = M.line(bench)
  local held, complaints, claims = M.judge(bench)

  return {
    test = test, bench = bench,
    before = before, after = after,
    ticks = bench.ticks, finished = finished,
    held = held, complaints = complaints, claims = claims,
  }
end
-- }}}

-- {{{ function M.script()
-- What a person is to do and what they are to look for, as the lines they read.
--
-- Returned rather than printed for the same reason a run is: the same script is read at a
-- terminal and written into the record of what was seen, and a function that printed
-- would force the second reader to parse the first one's output back out.
function M.script(test)
  local lines = {
    "",
    test.name,
    "  " .. test.file .. "   " .. M.ground[test.ground].label,
    "",
    "  " .. test.caption,
    "",
  }
  for index = 1, #test.ask do
    lines[#lines + 1] = string.format("  %d. [%s] %s",
                                      index, test.ask[index][1], test.ask[index][2])
  end
  lines[#lines + 1] = ""
  return lines
end
-- }}}

-- {{{ function M.what_was_seen()
-- The latest verdict on every mechanic a person has been asked about.
--
-- **The record is append-only**, so a mechanic answered three times has three rows and
-- the last one is the standing answer. Reading it back rather than keeping a tidy summary
-- beside it is deliberate: a summary is a second file to update, and the first symptom of
-- forgetting to is a report that says a thing was fixed.
--
-- Parsed out of the table it is written as, which is a markdown table because the same
-- file has two readers -- somebody scrolling it, and this. A separate machine format
-- would mean the two could disagree about what was said.
--
-- Returns rows of `{test, mechanic, verdict, note, when}`, newest answer per mechanic,
-- in the order the mechanics were first asked about.
function M.what_was_seen(root)
  local handle = io.open(root .. "/by-hand/what-was-seen.md", "r")
  if handle == nil then
    return {}
  end

  local rows, seen = {}, {}
  for line in handle:lines() do
    local when, test, mechanic, verdict, note =
      line:match("^|%s*([^|]-)%s*|%s*([^|]-)%s*|%s*([^|]-)%s*|%s*([^|]-)%s*|%s*([^|]-)%s*|$")
    -- The header and the divider match the shape of a row, so they are skipped by what
    -- they say rather than by counting lines -- a file somebody has added a paragraph to
    -- still reads correctly.
    if when ~= nil and when ~= "when" and when:sub(1, 1) ~= "-" then
      local key = test .. "/" .. mechanic
      local row = {test = test, mechanic = mechanic, verdict = verdict,
                   note = note, when = when}
      if seen[key] == nil then
        rows[#rows + 1] = row
        seen[key] = #rows
      else
        rows[seen[key]] = row
      end
    end
  end
  handle:close()

  return rows
end
-- }}}

-- {{{ function M.outstanding()
-- Everything a person has looked at and not been able to say yes to.
--
-- These are the rows to pick up. A `no` is behaviour that is not what the design says; a
-- `not built` is a question nobody could answer because the run never got into the state
-- it is about, which is a fault in the simulation sitting where a test failure would be
-- if a bench could reach it.
function M.outstanding(root)
  local left = {}
  for _, row in ipairs(M.what_was_seen(root)) do
    if row.verdict ~= "yes" then
      left[#left + 1] = row
    end
  end
  return left
end
-- }}}

-- {{{ function M.tell()
-- A run, as the lines a person reads.
--
-- **A test with no claims is reported as watched, not as passed.** A test that asserts
-- nothing has not been checked by running it, and counting it among the passes would
-- overstate what the project knows about itself -- which is the exact failure the
-- census exists to stop, arriving by a different door.
function M.tell(report)
  local lines = {
    "",
    report.test.name,
    "  " .. report.test.file .. "   " .. report.bench.ground.label,
    "  covers " .. table.concat(report.test.covers, ", "),
  }
  if report.test.want ~= nil then
    lines[#lines + 1] = "  mechanics " .. table.concat(report.test.want, ", ")
  end
  if report.test.note ~= nil then
    lines[#lines + 1] = "  note: " .. report.test.note
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "  at rest    " .. report.before
  lines[#lines + 1] = "  after " .. string.format("%-4d", report.ticks) ..
                      " " .. report.after
  if report.finished then
    lines[#lines + 1] = "  (the match ended before the count was reached)"
  end

  lines[#lines + 1] = ""
  if report.claims == 0 then
    lines[#lines + 1] = "  watched only -- this test makes no claims"
  elseif report.held then
    lines[#lines + 1] = "  " .. report.claims .. " of " .. report.claims .. " claims hold"
  else
    lines[#lines + 1] = "  FAILED " .. #report.complaints .. " of " ..
                        report.claims .. " claims"
    for index = 1, #report.complaints do
      lines[#lines + 1] = "    " .. report.complaints[index]
    end
  end
  lines[#lines + 1] = ""

  return table.concat(lines, "\n")
end
-- }}}

return M
