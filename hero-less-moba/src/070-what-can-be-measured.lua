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

-- {{{ local function insist()
-- The named part of a world, or a refusal that says which one is missing.
--
-- A reading about the chest asked of an arena world would otherwise index a nil and
-- blame a line inside this file. The reading knows what it needed; the error should
-- say so, because the fix is one word in the test's `want` list.
local function insist(world, field, wanted_by)
  local part = world[field]
  if part == nil then
    error("the reading '" .. wanted_by .. "' needs the world's " .. field ..
          ", and this world has none -- an arena hangs only the modules a test named")
  end
  return part
end
-- }}}

-- {{{ M.reading.health
-- Every point of health standing on the field, added up.
--
-- One number for "how much army is left", which is a different question from how many
-- bodies are left: fifteen soldiers at a tenth of their health and one at full are the
-- same count and nowhere near the same line.
M.reading.health = {
  label = "health", format = "%.0f",
  of = function(world)
    local soldier, total = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 then total = total + soldier.health[id] end
    end
    return total
  end,
}
-- }}}

-- {{{ M.reading.wounded
-- Living bodies carrying less than the health they were born with.
--
-- The cheapest proof that a blow landed. A test about damage that watched the count of
-- the living would see nothing at all until something finally died, which is dozens of
-- seconds after the thing it was watching for.
M.reading.wounded = {
  label = "wounded", format = "%d",
  of = function(world)
    local soldier, count = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.health[id] < soldier.health_max[id] then
        count = count + 1
      end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.guards
-- Living bodies that belong to a tower.
--
-- A guard is the only body that answers to a structure rather than to a wave, which is
-- why it is counted by what it belongs to rather than by what it is made of.
M.reading.guards = {
  label = "guards", format = "%d",
  of = function(world)
    local soldier, count = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.guard_of[id] ~= 0 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.heroes
-- Living bodies somebody paid for out of a personal wallet.
--
-- Counted by flavour, which is what a body is made of, rather than by asking the
-- players what they bought: a hero that has been bought and has since died is still on
-- somebody's tally and is not on the field.
M.reading.heroes = {
  label = "heroes", format = "%d",
  of = function(world)
    local soldier, count = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.flavour[id] == 2 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.monsters
-- Living bodies of the kind that walks out of the middle during a challenge.
M.reading.monsters = {
  label = "monsters", format = "%d",
  of = function(world)
    local soldier, count = world.soldier, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.flavour[id] == 4 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ local function counting_state()
-- A reading that counts the living bodies in one state of the brain.
--
-- Written once and called five times rather than five near-identical rows, because
-- five copies of a loop over every body is five places to forget the test for alive.
local function counting_state(name, wanted)
  return {
    label = name, format = "%d",
    of = function(world)
      local soldier, count = world.soldier, 0
      for id = 1, world.high_water do
        if soldier.alive[id] == 1 and soldier.state[id] == wanted then
          count = count + 1
        end
      end
      return count
    end,
  }
end
-- }}}

-- {{{ the five states, one reading each
-- **What every body on the field is doing, as five numbers that add up to the living.**
--
-- The brain is a dispatch table with a row per state, and until now the only way to see
-- which row was running was to watch the picture and guess. A test that claims nobody
-- is fighting is a test that can tell marching from a brawl without looking at
-- positions at all.
--
-- The numbers here are the brain's own state numbers, not a second list: 1 walking,
-- 2 closing, 3 fighting, 4 leashing, 5 dying. Two further states exist in the table and
-- are not built, so nothing here counts them and a reading that returned zero forever
-- would be a reading nobody could tell from a broken one.
M.reading.walking  = counting_state("walking", 1)
M.reading.closing  = counting_state("closing", 2)
M.reading.fighting = counting_state("fighting", 3)
M.reading.leashing = counting_state("leashing", 4)
M.reading.dying    = counting_state("dying", 5)
-- }}}

-- {{{ M.reading.hurrying
-- How many bodies asked for the fastest gait on the tick this was read.
--
-- A gait is chosen fresh every tick by whichever movement pattern placed the goal, so
-- this is a reading about **now** and not a tally: a column that charged and then
-- settled back into a march reads zero afterwards, correctly.
M.reading.hurrying = {
  label = "hurrying", format = "%d",
  of = function(world)
    local soldier, count = world.soldier, 0
    local hurry = world.parameters.unit.PACE_HURRY
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and soldier.goal_pace[id] == hurry then
        count = count + 1
      end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.patterns
-- How many different movement patterns placed a goal this tick.
--
-- The point of the pattern table is that every way of moving is a row in it rather than
-- an early return buried in a walking routine, and the way to tell whether that is true
-- of a running match is to count how many rows actually get used. One pattern doing all
-- the work means the others are decoration.
M.reading.patterns = {
  label = "patterns", format = "%d",
  of = function(world)
    local soldier, seen, count = world.soldier, {}, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 then
        local which = soldier.pattern[id]
        if which ~= 0 and seen[which] == nil then
          seen[which] = true
          count = count + 1
        end
      end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.waves
-- Wave records with anybody left alive in them.
--
-- A wave is the unit the upgrade economy is paid in -- wiping one is what draws a card
-- -- so "how many waves are on the field" is a different and more useful question than
-- how many bodies are.
M.reading.waves = {
  label = "waves", format = "%d",
  of = function(world)
    local record = insist(world, "wave", "waves")
    local count = 0
    for id = 1, #record do
      if record[id].living_count > 0 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.wipes
-- How many waves have been wiped out, both teams and every lane, since the match began.
--
-- **A tally rather than a state**, and the only reading here that cannot go down. A
-- wipe is the moment the chest grows, and a claim that it never happened is a claim
-- about the economy rather than about the field.
M.reading.wipes = {
  label = "wipes", format = "%d",
  of = function(world)
    local teams = insist(world, "team", "wipes")
    local count = 0
    for id = 1, #teams do
      for lane = 1, #teams[id].waves_lost do
        count = count + teams[id].waves_lost[lane]
      end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.towers
-- Guard towers still standing, both teams. Libraries are not towers and are counted
-- separately, because the one that matters is the one whose fall ends the match.
M.reading.towers = {
  label = "towers", format = "%d",
  of = function(world)
    local stone = insist(world, "structure", "towers")
    local count = 0
    for id = 1, #stone do
      if stone[id].alive == 1 and stone[id].kind ~= 3 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.rubble
-- Guard towers that have fallen. The complement of the reading above, written down
-- rather than subtracted in a caller, because a test claiming one tower has fallen
-- should not have to know how many there were to begin with.
M.reading.rubble = {
  label = "rubble", format = "%d",
  of = function(world)
    local stone = insist(world, "structure", "rubble")
    local count = 0
    for id = 1, #stone do
      if stone[id].alive == 0 and stone[id].kind ~= 3 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.libraries
-- Libraries still standing. Two at the start of every match and one at the end of
-- every finished one.
M.reading.libraries = {
  label = "libraries", format = "%d",
  of = function(world)
    local stone = insist(world, "structure", "libraries")
    local count = 0
    for id = 1, #stone do
      if stone[id].alive == 1 and stone[id].kind == 3 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.stone_health
-- Every point of health left in every standing structure, added up.
--
-- What a push is actually worth. Bodies arriving at a tower and bodies hurting it are
-- two different events, and the count of the living cannot tell them apart.
M.reading.stone_health = {
  label = "stone health", format = "%.0f",
  of = function(world)
    local stone = insist(world, "structure", "stone_health")
    local total = 0
    for id = 1, #stone do
      if stone[id].alive == 1 then total = total + stone[id].health end
    end
    return total
  end,
}
-- }}}

-- {{{ M.reading.chest
-- Upgrades drawn and not yet placed anywhere, both teams.
--
-- The chest and every slot are counts per kind rather than objects, so placing one is
-- moving a number from one count to another. That makes this reading and the one below
-- halves of a total that only grows when somebody draws.
M.reading.chest = {
  label = "chest", format = "%d",
  of = function(world)
    local teams = insist(world, "team", "chest")
    local count = 0
    for id = 1, #teams do
      for kind = 1, #teams[id].chest do
        count = count + teams[id].chest[kind]
      end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.placed
-- Upgrades sitting in a lane, in a tower's stone, or in a library, both teams.
M.reading.placed = {
  label = "placed", format = "%d",
  of = function(world)
    local teams = insist(world, "team", "placed")
    local count = 0
    for id = 1, #teams do
      local team = teams[id]
      for lane = 1, #team.lane_slot do
        for kind = 1, #team.lane_slot[lane] do
          count = count + team.lane_slot[lane][kind] + team.tower_slot[lane][kind]
        end
      end
      for kind = 1, #team.library_slot do
        count = count + team.library_slot[kind]
      end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.carried
-- Living bodies stamped at birth with at least one upgrade.
--
-- The proof that placing a thing in a lane reaches the soldiers walking down it. A
-- body is stamped once, when it is made, and never reads the team's slots again -- so a
-- lane that was fed after this body was born is a lane whose next wave is different and
-- whose current one is not.
M.reading.carried = {
  label = "carried", format = "%d",
  of = function(world)
    -- **Indexed kind-then-body**, like every other per-body number here: the world
    -- keeps one flat array per upgrade kind rather than one table per body, so a
    -- soldier's upgrades are a column through a dozen arrays and not a row in one.
    local soldier, count = world.soldier, 0
    local kinds = soldier.upgrade_count
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 then
        for kind = 1, #kinds do
          if kinds[kind][id] > 0 then
            count = count + 1
            break
          end
        end
      end
    end
    return count
  end,
}
-- }}}

-- {{{ local function counting_slot()
-- A reading that counts one team's upgrades in one kind of place.
--
-- The three slots are the same shape -- counts per upgrade kind -- because placing one
-- is moving a number between them and nothing else. So is the loop that adds them up,
-- and writing it three times would be three chances to forget a team.
local function counting_slot(name, pick)
  return {
    label = name, format = "%d",
    of = function(world)
      local teams = insist(world, "team", name)
      local count = 0
      for id = 1, #teams do
        count = count + pick(teams[id])
      end
      return count
    end,
  }
end
-- }}}

-- {{{ the three places an upgrade can be standing
-- **`placed` above is these three added together**, and they are here separately
-- because a test about slotting into stone and a test about feeding a lane would
-- otherwise make the same claim and pass for each other's reasons.
M.reading.in_lanes = counting_slot("in lanes", function(team)
  local count = 0
  for lane = 1, #team.lane_slot do
    for kind = 1, #team.lane_slot[lane] do
      count = count + team.lane_slot[lane][kind]
    end
  end
  return count
end)

M.reading.in_stone = counting_slot("in stone", function(team)
  local count = 0
  for lane = 1, #team.tower_slot do
    for kind = 1, #team.tower_slot[lane] do
      count = count + team.tower_slot[lane][kind]
    end
  end
  return count
end)

M.reading.in_library = counting_slot("in library", function(team)
  local count = 0
  for kind = 1, #team.library_slot do
    count = count + team.library_slot[kind]
  end
  return count
end)
-- }}}

-- {{{ M.reading.armed_towers
-- Standing towers shooting with at least one upgrade in them.
--
-- A tower keeps its own copy of what its lane's stone slot holds, rebuilt whenever that
-- slot changes, so that the swing path never reaches into a team record. This reading is
-- the proof the copy happened: a slot that filled while no tower noticed would leave the
-- count above at one and this one at nought.
M.reading.armed_towers = {
  label = "armed towers", format = "%d",
  of = function(world)
    local stone = insist(world, "structure", "armed_towers")
    local count = 0
    for id = 1, #stone do
      local tower = stone[id]
      if tower.alive == 1 and tower.upgrade_count ~= nil then
        for kind = 1, #tower.upgrade_count do
          if tower.upgrade_count[kind] > 0 then
            count = count + 1
            break
          end
        end
      end
    end
    return count
  end,
}
-- }}}


-- {{{ M.reading.aiming_towers
-- Standing towers currently holding a target.
--
-- A tower picks the nearest body in range and **keeps it while it lives**, rather than
-- re-choosing every tick. That commitment is the whole of its personality: a tower that
-- re-picked constantly would spread its damage across a whole wave and kill nobody, and
-- from outside the only visible difference is that the wave walks past.
--
-- Nought here with bodies standing inside a tower's reach is a tower that acquires
-- nothing. A number that matches the towers in contact, held steady while those bodies
-- live, is the commitment working.
M.reading.aiming_towers = {
  label = "aiming towers", format = "%d",
  of = function(world)
    local stone = insist(world, "structure", "aiming_towers")
    local count = 0
    for id = 1, #stone do
      if stone[id].alive == 1 and stone[id].target ~= 0 then count = count + 1 end
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.inside_stone
-- Living bodies standing inside a structure that is still up.
--
-- **Should be nought at every tick of every test**, in the same way and for the same
-- reason nothing stands inside anything else. A tower is nineteen paces of masonry and a
-- library thirty, and until a structure carried that number the only place a tower had a
-- size at all was inside a drawing routine -- so the simulation did not know stone
-- occupied ground, bodies walked through towers, and a tower's own guards were put out
-- inside the square being drawn round them.
--
-- Walks every body against every structure, which is twenty tests a body. Fine for a
-- reading that is only taken when a test names it, and much too expensive to do in the
-- rule itself -- which checks the two nodes at the ends of the edge a body is on instead,
-- because that is the only stone a body can be walking into.
-- Both rows count the same thing over different bodies, so the walk is written once and
-- they differ only by which bodies each is willing to look at.
local function counting_inside_stone(name, wanted)
  return {
  label = name, format = "%d",
  of = function(world)
    local stone = insist(world, "structure", name)
    local soldier, node, count = world.soldier, world.map.node, 0
    for id = 1, world.high_water do
      if soldier.alive[id] == 1 and (wanted == nil or wanted(soldier, id)) then
        for which = 1, #stone do
          local building = stone[which]
          if building.alive == 1 then
            local here = node[building.node]
            local room = soldier.radius[id] + building.radius
            local dx = soldier.x[id] - here.x
            local dy = soldier.y[id] - here.y
            if dx * dx + dy * dy < room * room then
              count = count + 1
              break
            end
          end
        end
      end
    end
    return count
  end,
  }
end

M.reading.inside_stone = counting_inside_stone("inside stone", nil)

-- **Only the bodies a tower put out itself**, which is the half of this that is settled.
-- Guards stand on a ring outside the masonry and are never inside it. Wave bodies walk
-- the lane, a tower sits on the lane, and steering a column round a building is work
-- nobody has done -- so the wider reading above is a live number in a real match and this
-- one is nought.
M.reading.guards_inside_stone =
  counting_inside_stone("guards inside stone",
                        function(soldier, id) return soldier.guard_of[id] ~= 0 end)
-- }}}
-- {{{ M.reading.wallets
-- Every point of personal resource every player is holding, of every colour.
--
-- One number for an economy with six wallets in it, which is enough to tell whether
-- killing pays at all. Whether it pays the right people is a claim about one wallet and
-- is not something a single reading can make.
M.reading.wallets = {
  label = "wallets", format = "%d",
  of = function(world)
    local players = insist(world, "player", "wallets")
    local total = 0
    for number = 1, #players do
      local points = players[number].points
      for colour = 1, #points do
        total = total + points[colour]
      end
    end
    return total
  end,
}
-- }}}

-- {{{ M.reading.bought
-- Heroes paid for since the match began, both teams. A tally, so it never goes down.
M.reading.bought = {
  label = "bought", format = "%d",
  of = function(world)
    local players = insist(world, "player", "bought")
    local count = 0
    for number = 1, #players do
      count = count + players[number].heroes_bought
    end
    return count
  end,
}
-- }}}

-- {{{ M.reading.phase
-- Which of the five phases the match is in: 1 normal, 2 surge, 3 challenge, 4 calm,
-- 5 over.
--
-- A number rather than a name because a claim compares numbers, and the five are
-- already numbered by the world itself. A test that wants to say "and it is still an
-- ordinary match at the end" says the phase equals one.
M.reading.phase = {
  label = "phase", format = "%d",
  of = function(world) return world.phase end,
}
-- }}}

-- {{{ M.reading.winner
-- Nought while the match is running, the winning team's number once it is not, and
-- three for the draw where both libraries fall inside one buffered damage pass.
M.reading.winner = {
  label = "winner", format = "%d",
  of = function(world) return world.winner end,
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

  -- What every living body is doing, and what it has cost. The five states add up to
  -- the living, so a column here that does not is a body in a state nobody built.
  minds    = {"tick", "alive", "walking", "closing", "fighting", "leashing", "dying"},

  -- A fight, from the outside: who is left, how hurt they are, and whether anything
  -- has actually been swung at yet.
  wounds   = {"tick", "alive", "health", "wounded", "fighting", "waves", "wipes"},

  -- The stone. Three counts and a total, which between them say whether a push is
  -- arriving, landing, or already finished.
  stone    = {"tick", "towers", "rubble", "libraries", "stone_health"},

  -- The two economies in one line: what has been drawn and not placed, what has been
  -- placed, how many bodies are carrying any of it, and what the wallets hold.
  economy  = {"tick", "chest", "placed", "carried", "wallets", "bought"},

  -- The match itself, at the altitude a report reads at.
  match    = {"tick", "phase", "alive", "waves", "towers", "libraries", "winner"},
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

-- `ever_at_least` and `ever_at_most` -- **the same two comparisons asked of the other
-- end of the run.**
--
-- `at_least` fails at the lowest a reading ever got, which is what you want for a floor
-- that must hold the whole way. But half of what a test wants to say is "this happened",
-- and a thing that happened is a thing that was true at one tick and false at the others
-- -- a tower acquired a target, a body was pushed out of somebody, three movement
-- patterns were in use at once. Asked with `at_least` every one of those fails on tick
-- nought, correctly and uselessly.
--
-- So these two are the reached-it claims: `ever_at_least` is judged at the **highest**
-- the reading got, `ever_at_most` at the lowest. They say nothing about how long it
-- lasted or when -- that is still missing, and is the open question about durations and
-- orderings on issue 111a.
M.claim.ever_at_least = {
  sides = {"max"},
  test = function(value, wanted)
    return value >= wanted,
           string.format("%.3f is the most it ever reached, not %.3f", value, wanted)
  end,
}

M.claim.ever_at_most = {
  sides = {"min"},
  test = function(value, wanted)
    return value <= wanted,
           string.format("%.3f is the least it ever reached, not %.3f", value, wanted)
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
