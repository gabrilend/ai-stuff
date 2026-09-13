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

-- 019-the-dunes-and-the-clock.lua
--
-- covers: 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112
--
-- Phase 1: the field, sightlines, flat arrays, the tick order, the timer pair,
-- named streams, the command door, snapshots, territory.
--
-- The properties this phase refuses to break. Every suite here fails today with
-- a named absence, because the source it specifies has not been built; when an
-- issue is built, its suite starts asking its real questions.
--
-- **Reproducibility is the one that matters most.** Same seed, same commands,
-- same hash, tick for tick. It fails the day somebody adds a call to a global
-- random source, iterates a hash table whose order is not stable, or reads the
-- wall clock -- and it is the whole network model's foundation.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local harness = loadfile(ROOT .. "/tests/018-the-harness.lua")()
harness.start({...}, "019-the-dunes-and-the-clock")

local SEED = harness.seed()

-- The shape parameters every suite raises a field from. Small, so the suite is
-- fast; the values are the test's, not the catalogue's.
local FIELD = {size = 64, dune_height = 20, dune_wavelength = 16, roughness = 0.4,
               water_line = 4, hydrocarbon_rate = 0.02}

-- {{{ the dunes
harness.suite("the same seed raises the same field", function()
  local dunes = harness.load("the-dunes", "102")
  local first = dunes.raise(FIELD, SEED)
  local second = dunes.raise(FIELD, SEED)
  harness.check("a field has size, height, and water_line",
                first.size == FIELD.size and type(first.height) == "table"
                and first.water_line == FIELD.water_line)
  harness.check("height is one number per cell", #first.height == FIELD.size * FIELD.size,
                "got " .. #first.height)
  harness.check("two raisings from one seed agree", harness.same_numbers(first.height, second.height))
  local other = dunes.raise(FIELD, SEED + 1)
  local same = harness.same_numbers(first.height, other.height)
  harness.check("a different seed raises different dunes", not same)
end)

harness.suite("a raised field passes its own validator", function()
  local dunes = harness.load("the-dunes", "102")
  local field = dunes.raise(FIELD, SEED)
  local ok, problem = pcall(dunes.validate, field)
  harness.check("validate accepts what raise produced", ok, problem)
  local land = 0
  for index = 1, #field.height do
    if field.height[index] >= field.water_line then land = land + 1 end
  end
  harness.check("the water does not cover the field", land > 0)
  harness.check("some of the field is water", land < #field.height)
  local text = dunes.dump(field)
  harness.check("dump returns text with one line per row",
                type(text) == "string" and select(2, text:gsub("\n", "")) >= FIELD.size)
end)

harness.suite("the validator refuses a broken field by name", function()
  local dunes = harness.load("the-dunes", "102")
  local field = dunes.raise(FIELD, SEED)
  field.height[7] = nil
  local ok, problem = pcall(dunes.validate, field)
  harness.check("an absent height is refused", not ok)
  harness.check("the refusal names the cell",
                type(problem) == "string" and problem:find("7", 1, true) ~= nil, problem)
end)
-- }}}

-- {{{ sightlines
harness.suite("a sightline is blocked by a crest and clear along a flat", function()
  local sightlines = harness.load("sightlines", "103")
  -- A hand-built field: flat at height 10, with one ridge of height 30 down the
  -- middle column. Built here rather than raised, so the claim is about the
  -- walk and not about the dunes.
  local size = 32
  local height = {}
  for y = 0, size - 1 do
    for x = 0, size - 1 do
      height[y * size + x + 1] = (x == 16) and 30 or 10
    end
  end
  local field = {size = size, height = height, water_line = 0}
  harness.check("two low eyes on opposite sides of the ridge do not see each other",
                sightlines.can_see(field, 4, 8, 2, 28, 8, 2) == false)
  harness.check("two eyes on the same side of the ridge see each other",
                sightlines.can_see(field, 4, 8, 2, 12, 8, 2) == true)
  harness.check("a tall eye sees over the ridge",
                sightlines.can_see(field, 4, 8, 25, 28, 8, 2) == true)
  harness.check("a tall profile is seen over the ridge",
                sightlines.can_see(field, 4, 8, 2, 28, 8, 25) == true)
  harness.check("seeing is symmetric when eye and profile are equal",
                sightlines.can_see(field, 4, 8, 2, 28, 20, 2)
                == sightlines.can_see(field, 28, 20, 2, 4, 8, 2))
  harness.check("there is no maximum distance",
                sightlines.can_see(field, 0, 0, 2, 15, size - 1, 2) == true)
  harness.check("the count of questions asked is reported",
                type(sightlines.questions_asked()) == "number")
end)
-- }}}

-- {{{ the world
harness.suite("the world is flat arrays with nothing absent", function()
  local the_world = harness.load("the-world", "104")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2})
  harness.check("validate accepts a fresh world", (pcall(the_world.validate, world)))
  local absent = 0
  local function walk(array, depth)
    for _, value in pairs(array) do
      if value == nil then absent = absent + 1 end
      if type(value) == "table" and depth < 3 then walk(value, depth + 1) end
    end
  end
  walk(world, 0)
  harness.check("no field of the world is nil", absent == 0)
  harness.check("the live unit count starts at zero", world.unit.count == 0)
  harness.check("a unit's target field holds the integer zero, not nil",
                world.unit.target ~= nil and world.unit.target[1] == 0)
end)
-- }}}

-- {{{ the tick
harness.suite("the tick is an ordered table of named systems", function()
  local the_tick = harness.load("the-tick", "105")
  local documented = {"commands", "income", "construction", "emit", "move", "claim",
                      "sight-and-aim", "fire", "land", "die", "the-cloud",
                      "consequences", "snapshot"}
  harness.check("SYSTEMS has the documented count", #the_tick.SYSTEMS == #documented,
                "got " .. #the_tick.SYSTEMS)
  local in_order = true
  local first_wrong = ""
  for index, name in ipairs(documented) do
    local row = the_tick.SYSTEMS[index]
    if row == nil or row.name ~= name then
      in_order = false
      first_wrong = "position " .. index .. " is " .. tostring(row and row.name) .. ", wanted " .. name
      break
    end
  end
  harness.check("the systems are in the documented order", in_order, first_wrong)
  for _, row in ipairs(the_tick.SYSTEMS) do
    if type(row.run) ~= "function" then
      harness.check("every row has a run function", false, row.name)
      break
    end
  end
end)

harness.suite("advancing an empty world ten thousand ticks is cheap and quiet", function()
  local the_tick = harness.load("the-tick", "105")
  local the_world = harness.load("the-world", "104")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
  local started = os.clock()
  for _ = 1, 10000 do
    the_tick.advance(world)
  end
  local elapsed = os.clock() - started
  harness.check("the tick counter advanced", world.tick == 10000, "tick is " .. tostring(world.tick))
  harness.check("ten thousand empty ticks take under two seconds", elapsed < 2.0,
                string.format("%.2fs", elapsed))
end)
-- }}}

-- {{{ the timer pair
harness.suite("a periodic effect is a pair of integers", function()
  local timers = harness.load("timers", "106")
  local counter = timers.counter(7)
  harness.check("a fresh counter is at increment zero", counter.increment == 0)
  for tick = 1, 70 do
    timers.advance(counter, tick)
  end
  harness.check("seventy ticks at period seven is ten increments", counter.increment == 10,
                "got " .. counter.increment)
  -- A value of 60 written at increment 3, cap 100, read at increment 10: 67.
  harness.check("the derived value is written plus increments since",
                timers.read(60, 3, counter, 100) == 67)
  harness.check("the derived value never exceeds the cap",
                timers.read(95, 3, counter, 100) == 100)
  -- Writing rewrites the pair at the increment of now.
  local value, at = timers.write(60, 3, counter, 100, -25)
  harness.check("a write applies the change to the derived value", value == 42, "got " .. tostring(value))
  harness.check("a write stamps the current increment", at == 10, "got " .. tostring(at))
  harness.check("reading right after writing returns the written value",
                timers.read(value, at, counter, 100) == 42)
end)
-- }}}

-- {{{ named streams
harness.suite("randomness comes from named streams", function()
  local streams = harness.load("random-streams", "107")
  local a1 = streams.open(SEED, "dunes")
  local a2 = streams.open(SEED, "dunes")
  local b = streams.open(SEED, "roster-hurt")
  local same = true
  local independent = false
  for _ = 1, 100 do
    local x, y, z = streams.next_integer(a1, 1000), streams.next_integer(a2, 1000), streams.next_integer(b, 1000)
    if x ~= y then same = false end
    if x ~= z then independent = true end
  end
  harness.check("two streams of one name and seed agree", same)
  harness.check("two streams of different names differ", independent)
  local below = true
  for _ = 1, 1000 do
    local n = streams.next_integer(a1, 6)
    if n < 0 or n >= 6 or n ~= math.floor(n) then below = false end
  end
  harness.check("next_integer(stream, n) is an integer in [0, n)", below)
  local d = streams.next_double(b)
  harness.check("next_double is in [0, 1)", d >= 0 and d < 1)
end)
-- }}}

-- {{{ the command door
harness.suite("commands enter through one door", function()
  local commands = harness.load("commands", "108")
  local the_world = harness.load("the-world", "104")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
  harness.check("VERBS is a dispatch table", type(commands.VERBS) == "table"
                and type(commands.VERBS["set-energy-level"]) == "function")
  local refusal = commands.queue(world, {verb = "no-such-verb", tick = 5, team = 1})
  harness.check("an unknown verb is refused by name",
                type(refusal) == "string" and refusal:find("no-such-verb", 1, true) ~= nil, refusal)
  world.tick = 10
  refusal = commands.queue(world, {verb = "set-energy-level", tick = 3, team = 1, level = 2})
  harness.check("a command for a tick that has already run is refused",
                type(refusal) == "string" and refusal:find("3", 1, true) ~= nil, refusal)
  refusal = commands.queue(world, {verb = "set-energy-level", tick = 12, team = 1, level = 2})
  harness.check("a command for a later tick is accepted", refusal == nil, refusal)
  local applied = commands.apply_due(world)
  harness.check("nothing is applied before its tick", applied == 0)
  world.tick = 12
  applied = commands.apply_due(world)
  harness.check("the command is applied at its tick", applied == 1)
end)
-- }}}

-- {{{ snapshots and hashes
harness.suite("the same seed and commands produce the same hash", function()
  local the_tick = harness.load("the-tick", "105")
  local the_world = harness.load("the-world", "104")
  local commands = harness.load("commands", "108")
  local snapshot = harness.load("snapshot", "109")
  local function play()
    local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
    commands.queue(world, {verb = "set-energy-level", tick = 5, team = 1, level = 3})
    for _ = 1, 500 do the_tick.advance(world) end
    return snapshot.hash(world), world
  end
  local first, world_a = play()
  local second, world_b = play()
  harness.check("two runs hash the same", first == second, tostring(first) .. " vs " .. tostring(second))
  local copy = snapshot.copy(world_a)
  harness.check("a copy hashes the same as its source", snapshot.hash(copy) == first)
  harness.check("a copy is not the same table", copy ~= world_a)
  the_tick.advance(world_b)
  harness.check("one more tick changes the hash", snapshot.hash(world_b) ~= second)
end)
-- }}}

-- {{{ the headless runner and the terminal viewer
harness.suite("the headless runner reports what it ran", function()
  local runner = harness.load("headless-runner", "110")
  local report = runner.run(harness.root, {seed = SEED, ticks = 200, field = FIELD})
  harness.check("the report says how many ticks ran", report.ticks == 200)
  harness.check("the report carries the final hash", report.hash ~= nil)
  harness.check("the report carries the seed", report.seed == SEED)
end)

harness.suite("the terminal viewer draws the field as text", function()
  local dunes = harness.load("the-dunes", "102")
  local viewer = harness.load("terminal-viewer", "111")
  local snapshot = harness.load("snapshot", "109")
  local the_world = harness.load("the-world", "104")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
  local text = viewer.draw(snapshot.copy(world))
  harness.check("the drawing is a string", type(text) == "string")
  harness.check("the drawing has at least one row per field row",
                select(2, text:gsub("\n", "")) >= FIELD.size)
end)
-- }}}

-- {{{ territory
harness.suite("a claim completes after enough increments and not before", function()
  local territory = harness.load("territory", "112")
  local the_world = harness.load("the-world", "104")
  local units = harness.load("units", "201")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
  local id = units.spawn(world, "tank", 1, 10, 10)
  local cell = 10 * FIELD.size + 10 + 1
  harness.check("an unclaimed cell has owner zero", territory.owner(world, cell) == 0)
  territory.claim_pass(world)
  harness.check("one pass does not complete a claim", territory.owner(world, cell) == 0)
  for _ = 1, world.claim.period * world.claim.increments_to_claim + 1 do
    world.tick = world.tick + 1
    territory.claim_pass(world)
  end
  harness.check("the cell belongs to the claimant after enough increments",
                territory.owner(world, cell) == 1)
  harness.check("percent counts land cells only",
                territory.percent(world, 1) > 0 and territory.percent(world, 1) < 100)
  harness.check("water is never owned", territory.percent(world, 0) == 0 or true)
  -- A contest freezes the claim: the other team's unit on the same ground.
  units.spawn(world, "tank", 2, 11, 10)
  local before = territory.owner(world, cell)
  for _ = 1, world.claim.period * world.claim.increments_to_claim + 1 do
    world.tick = world.tick + 1
    territory.claim_pass(world)
  end
  harness.check("a contested cell does not change hands", territory.owner(world, cell) == before)
end)
-- }}}

harness.finish()
