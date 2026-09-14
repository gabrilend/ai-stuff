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

-- 070-what-can-be-measured.lua
--
-- Every reading a test may take of a world, and every claim it may make about one.

-- Every reading a test may take of a world, and every claim it may make about one.
--
-- ## Why this is a catalogue rather than arithmetic in the caller
--
-- Before this file, "how far has the leading body come" was written out in three
-- places: in the window's readout, in a Lua string inside a shell script, and in
-- whichever test happened to want it. All three said front-minus-back and all three
-- were free to stop agreeing, silently, on the day one of them learned to skip the
-- dead and the others did not.
--
-- Worse than the duplication: a test that computes its own numbers **cannot be
-- contradicted by the world**. It measures whatever it decided to measure, and if that
-- is subtly the wrong thing, nothing in the project is in a position to say so. A
-- reading that lives here is one thing, used by the picture and the report and the
-- assertion alike, so a number seen in the window and a number seen in a terminal are
-- the same number rather than two measurements that ought to agree.
--
-- ## Adding one
--
-- A row. It takes the world and returns a number. That is the whole contract, and it
-- is deliberately narrow: a reading that returned a table would be a reading that
-- needed a caller who knew its shape, and then the knowledge is back out in the
-- callers where it started.

local M = {}

-- {{{ M.reading
-- The readings, by name. Each takes a world and returns one number.
--
-- `label` is what a person sees; `format` is how the number is written. Both live
-- beside the arithmetic so that a reading changed from a count to a distance does not
-- leave a caller printing it as an integer.
M.reading = {}

-- {{{ M.reading.tick
M.reading.tick = {
  label = "tick", format = "%d",
  of = function(world) return world.tick end,
}
-- }}}

-- {{{ M.reading.bodies
-- Living bodies that belong to a formation. **Not everything alive** -- a stray has no
-- wave, stands still by design, and would drag every distance reading backwards to
-- wherever it happens to be standing.
M.reading.bodies = {
  label = "bodies", format = "%d",
  of = function(world)
    local soldier, count = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.wave[id] ~= 0 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.alive
-- Every living body, whatever it is: wave bodies, strays, tower guards, monsters.
--
-- Here because the other two counts are both narrower than they sound, and a report
-- showing no bodies while also showing two pairs of bodies standing inside each other
-- reads as a broken instrument until you know that "bodies" means "in a formation".
M.reading.alive = {
  label = "alive", format = "%d",
  of = function(world)
    local soldier, count = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.strays
-- Living bodies in no formation: the things an army has to get past.
M.reading.strays = {
  label = "strays", format = "%d",
  of = function(world)
    local soldier, count = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.wave[id] == 0 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.front
-- How far along its lane the leading formed body has come, in paces.
M.reading.front = {
  label = "front", format = "%.0f",
  of = function(world)
    local soldier, front, seen = world.soldier, -math.huge, false
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.wave[id] ~= 0 then
        seen = true
        if soldier.lane_along[id] > front then front = soldier.lane_along[id] end
      end
    end
    -- An empty field reads zero rather than minus infinity. A field with nobody on it
    -- is a real state -- everything died, or nothing was placed -- and a report that
    -- printed `-inf` for it would be reporting a bug in the reading rather than the
    -- state of the world.
    if not seen then return 0 end
    return front
  end,
}
-- }}}

-- {{{ M.reading.back
M.reading.back = {
  label = "back", format = "%.0f",
  of = function(world)
    local soldier, back, seen = world.soldier, math.huge, false
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.wave[id] ~= 0 then
        seen = true
        if soldier.lane_along[id] < back then back = soldier.lane_along[id] end
      end
    end
    if not seen then return 0 end
    return back
  end,
}
-- }}}

-- {{{ M.reading.depth
-- How much road the formed bodies are spread over: the leader's distance less the
-- straggler's. A column that is dressing its line has a depth that settles; a column
-- that is coming apart has one that grows.
M.reading.depth = {
  label = "depth", format = "%.0f",
  of = function(world)
    return M.reading.front.of(world) - M.reading.back.of(world)
  end,
}
-- }}}

-- {{{ M.reading.going_round
-- How many bodies had this tick's step moved out of somebody else.
--
-- **Not how many gave up.** Nothing gives up any more: the rule is one circle test on
-- the ground a body's next step lands on, so a body that cannot go forward is a body
-- whose step was pushed somewhere else, which may be sideways and may be straight
-- back the way it came.
M.reading.going_round = {
  label = "going round", format = "%d",
  of = function(world)
    local soldier, count = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.wave[id] ~= 0
         and soldier.gave_way[id] == 1 then
        count = count + 1
      end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.straight_through
-- How many walked where they meant to.
M.reading.straight_through = {
  label = "straight through", format = "%d",
  of = function(world)
    return M.reading.bodies.of(world) - M.reading.going_round.of(world)
  end,
}
-- }}}

-- {{{ M.reading.widest_offset
-- How far off the centre line of its lane the most sideways body has got, in paces.
--
-- A column dressing its ranks sits at fixed offsets; a column squeezing past something
-- swells. This is the reading that says by how much.
M.reading.widest_offset = {
  label = "widest offset", format = "%.1f",
  of = function(world)
    local soldier, widest = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 then
        local off = math.abs(soldier.lane_across[id])
        if off > widest then widest = off end
      end
    end
    return widest
  end,
}
-- }}}

-- {{{ M.reading.off_the_road
-- How many living bodies are standing outside their own lane, measured against that
-- lane's own width rather than against a number written here.
--
-- **Ground-independent on purpose.** An arena lane and each of a match's three lanes
-- have different widths, so a test that claimed "nobody is more than sixty-six paces
-- off the line" would be a test that only meant anything on one of them.
M.reading.off_the_road = {
  label = "off the road", format = "%d",
  of = function(world)
    local soldier, count = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 then
        local lane = world.map.lane[soldier.lane[id]]
        -- A body with no lane -- a guard at its tower, a monster in the middle -- is
        -- not on a road and cannot be off one.
        if lane ~= nil and math.abs(soldier.lane_across[id]) > lane.width * 0.5 then
          count = count + 1
        end
      end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.closest_approach
-- The narrowest gap between any two living bodies, measured **skin to skin**: the
-- distance between their centres less the room the two of them need between them.
--
-- Zero means two bodies are touching exactly, which is what a column halted against
-- another column looks like when the rule about standing inside somebody is working.
-- A negative number means somebody is inside somebody, which is the rule failing.
--
-- Every pair against every pair, which is fine for the dozen bodies an arena holds and
-- is not fine for a match. That is the caller's choice to make: a reading is only taken
-- when a test names it.
M.reading.closest_approach = {
  label = "closest approach", format = "%.3f",
  of = function(world)
    local soldier = world.soldier
    local living = {}
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 then living[#living + 1] = id end
    end

    local narrowest = math.huge
    for i = 1, #living - 1 do
      local a = living[i]
      for j = i + 1, #living do
        local b = living[j]
        local dx = soldier.x[a] - soldier.x[b]
        local dy = soldier.y[a] - soldier.y[b]
        local gap = math.sqrt(dx * dx + dy * dy) - soldier.radius[a] - soldier.radius[b]
        if gap < narrowest then narrowest = gap end
      end
    end

    -- Fewer than two bodies means there is no pair, and no pair means no gap. Zero
    -- would be a lie in the dangerous direction -- it reads as "touching exactly".
    if narrowest == math.huge then return 0 end
    return narrowest
  end,
}
-- }}}

-- {{{ M.reading.overlaps
-- How many pairs of living bodies are standing inside each other. **This should be
-- zero at every tick of every test**, and the day it is not, the reading that says so
-- is worth more than any picture.
M.reading.overlaps = {
  label = "overlaps", format = "%d",
  of = function(world)
    local soldier = world.soldier
    local living = {}
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 then living[#living + 1] = id end
    end

    local count = 0
    for i = 1, #living - 1 do
      local a = living[i]
      for j = i + 1, #living do
        local b = living[j]
        local dx = soldier.x[a] - soldier.x[b]
        local dy = soldier.y[a] - soldier.y[b]
        local room = soldier.radius[a] + soldier.radius[b]
        -- **The same hair the separation pass uses**, taken from that module rather than
        -- written again here, because a reading that was stricter than the rule would
        -- report a failure every time the rule succeeded, and one that was looser would
        -- quietly pass bodies the rule had given up on.
        local slack = world.frontline ~= nil and world.frontline.SEPARATION_SLACK or 0
        local room_less = room - slack
        if dx * dx + dy * dy < room_less * room_less then
          count = count + 1
        end
      end
    end
    return count
  end,
}
-- }}}
-- }}}

-- {{{ M.readout
-- The named groups of readings a test is likely to want printed together.
--
-- Named here for the same reason the tick's stage selections are named there: a test
-- that recited its own list would be a test with an opinion about what is worth looking
-- at while a column marches, and every test would hold a slightly different one.
M.readout = {
  marching = {"tick", "alive", "front", "back", "depth", "straight_through",
              "going_round"},
  crowding = {"tick", "alive", "bodies", "strays", "closest_approach", "overlaps",
              "widest_offset", "off_the_road"},
}
-- }}}

-- {{{ function M.take()
-- Take the named readings, in order, and return them as rows.
--
-- Rows rather than a keyed table, because the order a report prints its numbers in is
-- part of what the report says and a keyed table would throw it away.
function M.take(world, names)
  if type(names) == "string" then
    local group = M.readout[names]
    if group == nil then
      error("no readout called '" .. names .. "'")
    end
    names = group
  end

  local taken = {}
  for index = 1, #names do
    local reading = M.reading[names[index]]
    if reading == nil then
      error("nothing measurable is called '" .. tostring(names[index]) .. "'")
    end
    -- Taken **once**. Two of these readings walk every pair of bodies on the field,
    -- and a version of this that read the value for the number and again for the text
    -- did that walk twice for one printed column.
    local value = reading.of(world)
    taken[index] = {
      name  = names[index],
      label = reading.label,
      value = value,
      text  = string.format(reading.format, value),
    }
  end
  return taken
end
-- }}}

-- {{{ function M.line()
-- The readings as one line of text, for a terminal report or a caption under a
-- picture. The same line in both, which is the point of it living here.
function M.line(world, names)
  local taken = M.take(world, names)
  local parts = {}
  for index = 1, #taken do
    parts[index] = taken[index].label .. " " .. taken[index].text
  end
  return table.concat(parts, "   ")
end
-- }}}

-- {{{ M.claim
-- What a test may assert, as a dispatch table.
--
-- A test that could write an arbitrary predicate could write one that passes for the
-- wrong reason, and nothing outside the test would be able to tell. A claim is a row --
-- a reading, a comparison, and a number -- so the comparison is the engine's and the
-- test only chooses which one.
--
-- Each row has two parts. `test` is the comparison itself, taking the measured value
-- and whatever the row carried after it. `sides` says which end of a run's history the
-- comparison has to be applied to, and it is the more interesting of the two:
--
--   * `at_least` fails at the **lowest** the reading ever got.
--   * `at_most` fails at the **highest**.
--   * `equals`, `within` and `between` are two-sided and have to be asked about both.
--
-- **This is here because judging only the last tick missed everything.** Two columns of
-- allied troops walked into each other, briefly stood inside one another, squeezed past
-- and arrived at opposite ends of the road, and a check taken at the end of the run
-- reported a field with nobody overlapping anybody -- which was true, and told the
-- reader the opposite of what had happened.
M.claim = {}

M.claim.at_least = {
  sides = {"min"},
  test = function(value, wanted)
    return value >= wanted, string.format("%.3f is not at least %.3f", value, wanted)
  end,
}

M.claim.at_most = {
  sides = {"max"},
  test = function(value, wanted)
    return value <= wanted, string.format("%.3f is not at most %.3f", value, wanted)
  end,
}

M.claim.equals = {
  sides = {"min", "max"},
  test = function(value, wanted)
    return value == wanted, string.format("%.3f is not %.3f", value, wanted)
  end,
}

-- `within <wanted> <tolerance>` -- for anything that came out of arithmetic on
-- positions, where insisting on an exact number is insisting on a floating-point
-- accident.
M.claim.within = {
  sides = {"min", "max"},
  test = function(value, wanted, tolerance)
    local off = math.abs(value - wanted)
    return off <= tolerance,
           string.format("%.3f is %.3f away from %.3f, further than %.3f",
                         value, off, wanted, tolerance)
  end,
}

M.claim.between = {
  sides = {"min", "max"},
  test = function(value, low, high)
    return value >= low and value <= high,
           string.format("%.3f is not between %.3f and %.3f", value, low, high)
  end,
}
-- }}}

-- {{{ function M.fold()
-- Fold one tick's readings into a running summary: the lowest, the highest and the
-- latest each reading has been.
--
-- Given a summary table it adds to it, so a caller keeps one table for a whole run and
-- a reading is taken once per tick rather than once per claim.
function M.fold(world, names, summary)
  summary = summary or {}
  for index = 1, #names do
    local reading = M.reading[names[index]]
    if reading == nil then
      error("nothing measurable is called '" .. tostring(names[index]) .. "'")
    end
    local value = reading.of(world)
    local seen = summary[names[index]]
    if seen == nil then
      summary[names[index]] = {min = value, max = value, last = value, ticks = 1}
    else
      if value < seen.min then seen.min = value end
      if value > seen.max then seen.max = value end
      seen.last = value
      seen.ticks = seen.ticks + 1
    end
  end
  return summary
end
-- }}}

-- {{{ function M.readings_named()
-- Which readings a list of claim rows is about. What a run has to fold each tick.
function M.readings_named(rows)
  local names, seen = {}, {}
  for index = 1, #(rows or {}) do
    local name = rows[index][1]
    if not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  return names
end
-- }}}

-- {{{ function M.judge()
-- Test one row of the shape `{reading, comparison, numbers...}` against a world as it
-- stands right now. What a claim about the final state is asked.
function M.judge(world, row)
  local reading = M.reading[row[1]]
  if reading == nil then
    error("nothing measurable is called '" .. tostring(row[1]) .. "'")
  end
  local claim = M.claim[row[2]]
  if claim == nil then
    error("no claim called '" .. tostring(row[2]) .. "'")
  end

  local held, complaint = claim.test(reading.of(world), row[3], row[4])
  if held then
    return true
  end
  return false, reading.label .. ": " .. complaint
end
-- }}}

-- {{{ function M.judge_over()
-- Test one row against everything a run ever saw, rather than against where it stopped.
--
-- Names the tick count in the complaint, because "at some point during nine hundred
-- ticks" is a different statement from "at the end" and a reader who cannot tell which
-- one failed has to run it again to find out.
function M.judge_over(summary, row)
  local reading = M.reading[row[1]]
  if reading == nil then
    error("nothing measurable is called '" .. tostring(row[1]) .. "'")
  end
  local claim = M.claim[row[2]]
  if claim == nil then
    error("no claim called '" .. tostring(row[2]) .. "'")
  end

  local seen = summary[row[1]]
  if seen == nil then
    error("nothing was ever measured for '" .. row[1] .. "'")
  end

  for _, side in ipairs(claim.sides) do
    local held, complaint = claim.test(seen[side], row[3], row[4])
    if not held then
      return false, string.format("%s, at some tick out of %d: %s",
                                  reading.label, seen.ticks, complaint)
    end
  end
  return true
end
-- }}}

return M
