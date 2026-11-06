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

-- 020-things-that-roll-fly-and-sail.lua
--
-- covers: 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211
--
-- Phase 2: the unit record, the catalogue's relations, falloff, buffered damage,
-- shared healing, bones, the truck, the enforcer.
--
-- The claims here are about relations, not magnitudes. A truck dies in one tank
-- shell and an enforcer in six plus four *whatever a shell is worth*; the
-- catalogue may move every number and every claim below still holds.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local harness = loadfile(ROOT .. "/tests/018-the-harness.lua")()
harness.start({...}, "020-things-that-roll-fly-and-sail")

local SEED = harness.seed()
local FIELD = {size = 64, dune_height = 20, dune_wavelength = 16, roughness = 0.4,
               water_line = 4, hydrocarbon_rate = 0.02}

-- {{{ local function fresh()
-- A world with the whole cast assembled, so a suite can spawn and shoot.
local function fresh()
  local the_tick = harness.load("the-tick", "105")
  local the_world = harness.load("the-world", "104")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
  return world, the_tick
end
-- }}}

-- {{{ local function shells_to_kill()
-- How many tank shells a kind takes, read as a relation between catalogue rows.
local function shells_to_kill(catalogue, kind)
  return math.ceil(catalogue[kind].health / catalogue.tank.damage)
end
-- }}}

-- {{{ one record
harness.suite("a spawned unit is one row of the flat arrays", function()
  local units = harness.load("units", "201")
  local world = fresh()
  local before = units.alive(world)
  local id = units.spawn(world, "tank", 1, 5, 5)
  harness.check("spawn returns an integer id", type(id) == "number" and id == math.floor(id))
  harness.check("the live count rose by one", units.alive(world) == before + 1)
  harness.check("the row holds its team", world.unit.team[id] == 1)
  harness.check("the row holds its position", world.unit.x[id] == 5 and world.unit.y[id] == 5)
  harness.check("the row's target is the integer zero", world.unit.target[id] == 0)
  harness.check("the row's shield is the integer zero for a tank", world.unit.shield[id] == 0)
  local ok, problem = pcall(units.spawn, world, "no-such-kind", 1, 5, 5)
  harness.check("an unknown kind is refused by name",
                not ok and tostring(problem):find("no-such-kind", 1, true) ~= nil, problem)
end)
-- }}}

-- {{{ the catalogue
harness.suite("the catalogue's relations hold", function()
  local catalogue = harness.load_asset("unit-catalogue", "202")
  for _, kind in ipairs({"tank", "anti-air", "helicopter", "frigate", "command-truck", "enforcer"}) do
    harness.check("the catalogue has a row for the " .. kind, catalogue[kind] ~= nil)
  end
  local every_field_numeric = true
  for kind, row in pairs(catalogue) do
    for name, value in pairs(row) do
      if type(value) ~= "number" and type(value) ~= "string" then
        every_field_numeric = false
      end
    end
  end
  harness.check("every catalogue field is a number or a name", every_field_numeric)
  harness.check("a truck dies in one tank shell", shells_to_kill(catalogue, "command-truck") == 1)
  harness.check("a tank dies in four tank shells", shells_to_kill(catalogue, "tank") == 4)
  harness.check("an anti-air gun dies in three tank shells", shells_to_kill(catalogue, "anti-air") == 3)
  harness.check("an enforcer dies in six tank shells", shells_to_kill(catalogue, "enforcer") == 6)
  harness.check("an enforcer's shield takes four tank shells",
                math.ceil(catalogue.enforcer.shield / catalogue.tank.damage) == 4)
  harness.check("the enforcer is taller than the tank",
                catalogue.enforcer.profile > catalogue.tank.profile
                and catalogue.enforcer.eye > catalogue.tank.eye)
  harness.check("the enforcer's head is above its eye",
                catalogue.enforcer.profile > catalogue.enforcer.eye)
  harness.check("every kind heals on its own counter",
                catalogue.tank.heal_period ~= catalogue["anti-air"].heal_period
                and catalogue.tank.heal_period ~= catalogue.helicopter.heal_period)
end)
-- }}}

-- {{{ the row and the catalogue, closer
-- {{{ local function raw_catalogue()
-- A deep copy of the catalogue as the asset gives it, for a suite to break.
local function raw_catalogue()
  local copy = {}
  for name, row in pairs(harness.load_asset("unit-catalogue", "202")) do
    copy[name] = {}
    for key, value in pairs(row) do copy[name][key] = value end
  end
  return copy
end
-- }}}

harness.suite("a unit carries copies of its kind's numbers from birth", function()
  local units = harness.load("units", "201")
  local catalogue = harness.load_asset("unit-catalogue", "202")
  local timers = harness.load("timers", "106")
  local world = fresh()
  for _ = 1, 25 do
    world.tick = world.tick + 1
  end
  local id = units.spawn(world, "enforcer", 2, 7.5, 3)
  local row = catalogue.enforcer
  harness.check("the row holds its kind's index", world.unit.kind[id] == row.index)
  harness.check("domain, eye, profile and damage are copied",
                world.unit.domain[id] == row.domain and world.unit.eye[id] == row.eye
                and world.unit.profile[id] == row.profile and world.unit.damage[id] == row.damage)
  harness.check("the claim radius is the kind's", world.unit.claim_radius[id] == row.claim_radius)
  harness.check("health is the cap, written at the increment of now on the kind's counter",
                world.unit.health[id] == row.health
                and world.unit.health_at[id] == world.heal.enforcer.increment
                and world.heal.enforcer.increment > 0)
  harness.check("the shield is full, on its own recharge counter",
                timers.read(world.unit.shield[id], world.unit.shield_at[id], world.recharge.enforcer,
                            row.shield) == row.shield)
  local plane = units.spawn(world, "helicopter", 1, 1, 1)
  local ground = math.max(world.field.height[1 * FIELD.size + 1 + 1], world.field.water_line)
  harness.check("a plane flies its height above the ground and claims nothing",
                world.unit.altitude[plane] == ground + catalogue.helicopter.altitude
                and world.unit.claim_radius[plane] == 0, world.unit.altitude[plane])
  local ok, problem = pcall(units.spawn, world, "tank", 3, 1, 1)
  harness.check("a team the world does not have is refused",
                not ok and tostring(problem):find("team 3", 1, true) ~= nil, problem)
  local small = harness.load("the-world", "104").allocate({field = FIELD, units = 1, teams = 2, seed = SEED})
  units.spawn(small, "tank", 1, 1, 1)
  ok, problem = pcall(units.spawn, small, "tank", 1, 2, 2)
  harness.check("a full world is refused, naming the kind and the group",
                not ok and tostring(problem):find("tank", 1, true) ~= nil
                and tostring(problem):find("unit group is full", 1, true) ~= nil, problem)
  harness.check("a row dumps as one line naming its kind",
                units.dump(world, id):find("(enforcer)", 1, true) ~= nil
                and units.dump(world, id):find("team=2", 1, true) ~= nil, units.dump(world, id))
end)

harness.suite("the catalogue refuses a bad row by its name and field", function()
  local units = harness.load("units", "201")
  local rate = harness.load_asset("the-rules", "105").ticks_per_second
  local ok, problem = pcall(units.validate_catalogue, raw_catalogue(), rate)
  harness.check("the catalogue as it stands loads", ok, problem)
  local function refused(what, change, expect)
    local raw = raw_catalogue()
    change(raw)
    local fine, message = pcall(units.validate_catalogue, raw, rate)
    harness.check(what, not fine and tostring(message):find(expect, 1, true) ~= nil, message)
  end
  refused("a missing field", function(raw) raw.tank.speed = nil end, "tank.speed")
  refused("a field the catalogue does not know", function(raw) raw.frigate.colour = 3 end,
          "frigate.colour")
  refused("a name where a number goes", function(raw) raw.tank.health = "lots" end, "tank.health")
  refused("a domain past sea", function(raw) raw.frigate.domain = 4 end, "frigate.domain")
  refused("a floor above one", function(raw) raw.tank.falloff_floor = 1.5 end, "tank.falloff_floor")
  refused("a weapon with nowhere to reach", function(raw) raw.tank.reaches = 0 end, "tank.reaches")
  refused("a period shorter than a tick", function(raw) raw.tank.heal_period = 0.01 end,
          "tank.heal_period")
  refused("two kinds with one index", function(raw) raw.frigate.index = 1 end, "index")
  refused("a gap in the indices", function(raw) raw.enforcer.index = 9 end, "index")
  refused("a shield with no recharge", function(raw) raw.tank.shield = 10 end, "tank.shield_seconds")
  refused("a ship that flies", function(raw) raw.frigate.altitude = 3 end, "frigate.altitude")
  local catalogue = units.catalogue()
  harness.check("seconds become ticks at the rules' rate",
                catalogue.tank.heal_ticks == math.floor(catalogue.tank.heal_period * rate + 0.5)
                and catalogue.tank.reload_ticks >= 1)
  harness.check("kinds are found by name and by index",
                units.index_of("frigate") == catalogue.frigate.index
                and units.name_of(catalogue.frigate.index) == "frigate"
                and units.kind(catalogue.frigate.index) == catalogue.frigate)
  harness.check("the report gives hits to kill in tank shells",
                units.report():find("command%-truck%s+1\n") ~= nil
                and units.report():find("enforcer%s+6, and 4 more for its shield") ~= nil)
end)

harness.suite("every kind heals on a counter of its own, in the world", function()
  local units = harness.load("units", "201")
  local snapshot = harness.load("snapshot", "109")
  local world = fresh()
  local catalogue = units.catalogue()
  local all = true
  for index, row in ipairs(catalogue.kinds) do
    local counter = world.heal[row.name]
    if counter == nil or counter.period ~= row.heal_ticks then all = false end
  end
  harness.check("one heal counter per kind, at the kind's period", all)
  harness.check("the enforcer's shield has a recharge counter, and nothing else does",
                world.recharge.enforcer ~= nil and world.recharge.tank == nil)
  local before = snapshot.hash(world)
  world.heal.frigate.increment = world.heal.frigate.increment + 1
  harness.check("the counters are part of the fingerprint", snapshot.hash(world) ~= before)
  world.heal.frigate.increment = world.heal.frigate.increment - 1
  local copy = snapshot.copy(world)
  harness.check("and of a snapshot", copy.heal.frigate.period == world.heal.frigate.period
                and copy.heal.frigate ~= world.heal.frigate)
end)

harness.suite("the world's validator holds a unit to its kind", function()
  local units = harness.load("units", "201")
  local the_world = harness.load("the-world", "104")
  local world = fresh()
  local water
  for index = 1, FIELD.size * FIELD.size do
    if world.field.height[index] < world.field.water_line then water = water or index end
  end
  local id = units.spawn(world, "frigate", 1, (water - 1) % FIELD.size, math.floor((water - 1) / FIELD.size))
  harness.check("a spawned world validates", (pcall(the_world.validate, world)))
  world.unit.domain[id] = units.DOMAINS.land
  local ok, problem = pcall(the_world.validate, world)
  harness.check("a frigate on land by its row is refused, naming the row",
                not ok and tostring(problem):find("row " .. id, 1, true) ~= nil, problem)
  world.unit.domain[id] = units.DOMAINS.sea
  world.unit.kind[id] = 99
  ok, problem = pcall(the_world.validate, world)
  harness.check("a kind the catalogue does not have is refused",
                not ok and tostring(problem):find("kind 99", 1, true) ~= nil, problem)
end)

harness.suite("a kind claims territory with its own radius", function()
  local units = harness.load("units", "201")
  local territory = harness.load("territory", "112")
  local world = fresh()
  for index = 1, #world.field.height do world.field.height[index] = 10 end
  units.spawn(world, "enforcer", 1, 10, 10)
  units.spawn(world, "tank", 2, 40, 10)
  units.spawn(world, "helicopter", 2, 40, 40)
  local length = world.claim.period * world.claim.increments_to_claim
  for _ = 0, length do
    territory.claim_pass(world)
    world.tick = world.tick + 1
  end
  local size = FIELD.size
  local function cell(x, y) return y * size + x + 1 end
  harness.check("the enforcer holds ground four cells out", territory.owner(world, cell(14, 10)) == 1)
  harness.check("a tank holds two cells out and not three",
                territory.owner(world, cell(42, 10)) == 2 and territory.owner(world, cell(43, 10)) == 0)
  harness.check("a plane holds nothing beneath it", territory.owner(world, cell(40, 40)) == 0)
end)

harness.suite("the viewer has a letter for every kind", function()
  local units = harness.load("units", "201")
  local viewer = harness.load("terminal-viewer", "111")
  local seen, every = {}, true
  for index, row in ipairs(units.catalogue().kinds) do
    local letter = viewer.LETTERS[index]
    if letter == nil or seen[letter] or letter == viewer.UNKNOWN then every = false end
    seen[letter or ""] = true
  end
  harness.check("one letter per kind, none shared, none the unknown mark", every)
  harness.check("the tank is T and the enforcer E",
                viewer.LETTERS[units.index_of("tank")] == "T"
                and viewer.LETTERS[units.index_of("enforcer")] == "E")
end)
-- }}}

-- {{{ three domains
harness.suite("three domains on one field", function()
  local domains = harness.load("domains", "203")
  local dunes = harness.load("the-dunes", "102")
  local field = dunes.raise(FIELD, SEED)
  local water_x, water_y, land_x, land_y
  for y = 0, field.size - 1 do
    for x = 0, field.size - 1 do
      local h = field.height[y * field.size + x + 1]
      if h < field.water_line and water_x == nil then water_x, water_y = x, y end
      if h >= field.water_line and land_x == nil then land_x, land_y = x, y end
    end
  end
  harness.check("a frigate can stand on water", domains.can_stand(field, "sea", water_x, water_y) == true)
  harness.check("a frigate cannot stand on land", domains.can_stand(field, "sea", land_x, land_y) == false)
  harness.check("a tank can stand on land", domains.can_stand(field, "land", land_x, land_y) == true)
  harness.check("a tank cannot stand on water", domains.can_stand(field, "land", water_x, water_y) == false)
  harness.check("a plane can be anywhere", domains.can_stand(field, "air", water_x, water_y) == true
                and domains.can_stand(field, "air", land_x, land_y) == true)
end)
-- }}}

-- {{{ movement
harness.suite("movement follows a pattern and holds at its end", function()
  local units = harness.load("units", "201")
  local movement = harness.load("movement", "204")
  local world = fresh()
  local id = units.spawn(world, "tank", 1, 2, 2)
  world.unit.pattern[id] = 1
  world.pattern.count = 1
  world.pattern.points[1] = {{x = 2, y = 2}, {x = 2, y = 20}, {x = 20, y = 20}}
  world.unit.leg[id] = 1
  for _ = 1, 400 do
    movement.move_pass(world)
  end
  harness.check("the unit reached the last point", world.unit.x[id] == 20 and world.unit.y[id] == 20,
                world.unit.x[id] .. "," .. world.unit.y[id])
  local x, y = world.unit.x[id], world.unit.y[id]
  movement.move_pass(world)
  harness.check("a unit at the end of its pattern holds", world.unit.x[id] == x and world.unit.y[id] == y)
end)
-- }}}

-- {{{ domains and movement, closer
-- {{{ local function flat()
-- A world whose field is flat land at height 10, with a strip of sea along the
-- column x = 30 from the top edge to y = 40, so a suite knows exactly where the
-- water and the shore are, and the start regions stay joined by land below it.
local function flat()
  local world = fresh()
  local field = world.field
  for index = 1, #field.height do field.height[index] = 10 end
  for y = 0, 40 do field.height[y * field.size + 30 + 1] = 1 end
  return world
end
-- }}}

harness.suite("a domain is one row of a dispatch table, answered off the heights", function()
  local domains = harness.load("domains", "203")
  local units = harness.load("units", "201")
  local world = flat()
  local field = world.field
  harness.check("domains are named integers", domains.LAND == 1 and domains.AIR == 2 and domains.SEA == 3)
  harness.check("an integer domain is answered as its name is",
                domains.can_stand(field, domains.SEA, 30, 5) == domains.can_stand(field, "sea", 30, 5))
  harness.check("one row per domain in the dispatch table",
                type(domains.STAND[1]) == "function" and type(domains.STAND[3]) == "function")
  local ok, problem = pcall(domains.can_stand, field, "land", -3, 5)
  harness.check("a position off the field is refused, not answered", not ok, problem)
  ok, problem = pcall(domains.can_stand, field, "underground", 3, 5)
  harness.check("a domain nobody has is refused by name",
                not ok and tostring(problem):find("underground", 1, true) ~= nil, problem)
  harness.check("land beside the sea is shore, and land away from it is not",
                domains.is_shore(field, 29, 5) and domains.is_shore(field, 31, 5)
                and not domains.is_shore(field, 20, 5) and not domains.is_shore(field, 30, 5))
  field.height[5 * field.size + 10 + 1] = 15
  harness.check("a plane's altitude is the ground beneath plus its flight height",
                domains.altitude_at(field, "helicopter", 10, 5) == 15 + units.kind("helicopter").altitude
                and domains.altitude_at(field, "helicopter", 30, 5)
                    == field.water_line + units.kind("helicopter").altitude
                and domains.altitude_at(field, "tank", 10, 5) == 0)
  ok, problem = pcall(units.spawn, world, "tank", 1, 30, 5)
  harness.check("a tank is not spawned on the water",
                not ok and tostring(problem):find("land unit may not stand", 1, true) ~= nil, problem)
  local id = units.spawn(world, "tank", 1, 29, 5)
  world.unit.x[id] = 30
  ok, problem = pcall(harness.load("the-world", "104").validate, world)
  harness.check("a tank found in the sea is a refusal naming its row",
                not ok and tostring(problem):find("row " .. id, 1, true) ~= nil, problem)
end)

harness.suite("the water is a wall, and a ridge is slow", function()
  local units = harness.load("units", "201")
  local movement = harness.load("movement", "204")
  local world = flat()
  local field = world.field
  local id = units.spawn(world, "tank", 1, 25, 5)
  world.pattern.count = 1
  world.pattern.points[1] = {{x = 35, y = 5}}
  world.unit.pattern[id], world.unit.leg[id] = 1, 1
  for _ = 1, 200 do movement.move_pass(world) end
  harness.check("a tank walking into the sea stops at the shore",
                world.unit.x[id] < 29.5 and world.unit.x[id] > 29 and world.unit.y[id] == 5,
                world.unit.x[id])
  harness.check("and keeps its leg rather than turning round", world.unit.leg[id] == 1)
  local flat_step = movement.step_length(field, "tank", 10, 10, 20, 10)
  field.height[10 * field.size + 11 + 1] = 12
  local up = movement.step_length(field, "tank", 10, 10, 20, 10)
  local down = movement.step_length(field, "tank", 11, 10, 0, 10)
  harness.check("flat ground is the catalogue's speed", flat_step == units.kind("tank").speed)
  harness.check("uphill is slower than flat", up < flat_step)
  harness.check("downhill is never faster than flat", down == flat_step)
  harness.check("a ship's water is flat", movement.step_length(field, "frigate", 30, 1, 30, 9)
                == units.kind("frigate").speed)
end)

harness.suite("two land units do not share a cell", function()
  local units = harness.load("units", "201")
  local movement = harness.load("movement", "204")
  local world = flat()
  local blocker = units.spawn(world, "tank", 2, 12, 10)
  local walker = units.spawn(world, "tank", 1, 11, 10)
  world.pattern.count = 1
  world.pattern.points[1] = {{x = 11, y = 10}, {x = 20, y = 10}}
  world.unit.pattern[walker], world.unit.leg[walker] = 1, 1
  local cells = {}
  local waited = false
  for _ = 1, 120 do
    movement.move_pass(world)
    if world.unit.waited[walker] == 1 then waited = true end
    cells[#cells + 1] = math.floor(world.unit.x[walker] + 0.5) .. "," .. math.floor(world.unit.y[walker] + 0.5)
  end
  local entered = false
  for _, cell in ipairs(cells) do
    if cell == "12,10" then entered = true end
  end
  harness.check("the walker waited a pass at the occupied cell", waited)
  harness.check("and never stepped into it", not entered, table.concat(cells, " "))
  harness.check("it went round and reached the end",
                world.unit.x[walker] == 20 and world.unit.y[walker] == 10 and movement.held(world, walker),
                world.unit.x[walker] .. "," .. world.unit.y[walker])
  harness.check("the occupancy names the blocker's cell",
                world.cell.occupant[10 * FIELD.size + 12 + 1] == blocker)
end)

harness.suite("planes do not walk patterns, and the move row runs", function()
  local units = harness.load("units", "201")
  local movement = harness.load("movement", "204")
  local the_tick = harness.load("the-tick", "105")
  local snapshot = harness.load("snapshot", "109")
  local world = flat()
  local plane = units.spawn(world, "helicopter", 1, 5, 5)
  world.pattern.count = 1
  world.pattern.points[1] = {{x = 9, y = 5}}
  world.unit.pattern[plane], world.unit.leg[plane] = 1, 1
  movement.move_pass(world)
  harness.check("a plane with a pattern stays where it is", world.unit.x[plane] == 5)
  local row = the_tick.SYSTEMS[5]
  harness.check("the tick's fifth row is the move pass, and it slices",
                row.name == "move" and row.waiting_for == nil and row.sliceable
                and type(row.run_slice) == "function")
  local before = snapshot.hash(world)
  world.pattern.points[1][1].x = 9.5
  harness.check("the patterns are part of the fingerprint", snapshot.hash(world) ~= before)
  local copy = snapshot.copy(world)
  world.pattern.points[1][1].x = 8
  harness.check("and a snapshot's patterns stand alone", copy.pattern.points[1][1].x == 9.5)
  world.unit.pattern[plane] = 4
  local ok, problem = pcall(harness.load("the-world", "104").validate, world)
  harness.check("a unit following a pattern the world lacks is refused",
                not ok and tostring(problem):find("pattern 4", 1, true) ~= nil, problem)
end)
-- }}}

-- {{{ nothing is out of range
harness.suite("damage falls off with distance and never below its floor", function()
  local targeting = harness.load("targeting", "205")
  local near = targeting.falloff("tank", 1)
  local far = targeting.falloff("tank", 1000)
  local farther = targeting.falloff("tank", 100000)
  harness.check("falloff at no distance is full", near == 1)
  harness.check("falloff far away is less than full", far < near)
  harness.check("falloff has a floor", farther == far or farther > 0)
  harness.check("falloff never goes negative", farther >= 0)
end)

harness.suite("a unit fires at what it can see, at any distance", function()
  local units = harness.load("units", "201")
  local targeting = harness.load("targeting", "205")
  local world = fresh()
  -- Flatten the field so that sight is never the question here.
  for index = 1, #world.field.height do world.field.height[index] = 10 end
  local shooter = units.spawn(world, "tank", 1, 1, 1)
  local far_target = units.spawn(world, "tank", 2, 60, 60)
  targeting.aim_pass(world)
  harness.check("a tank targets an enemy across the whole field", world.unit.target[shooter] == far_target)
  local gun = units.spawn(world, "anti-air", 1, 3, 3)
  targeting.aim_pass(world)
  harness.check("an anti-air gun does not target a tank", world.unit.target[gun] == 0)
  local plane = units.spawn(world, "helicopter", 2, 30, 30)
  targeting.aim_pass(world)
  harness.check("an anti-air gun targets a plane", world.unit.target[gun] == plane)
  local truck = units.spawn(world, "command-truck", 2, 40, 40)
  targeting.aim_pass(world)
  harness.check("an enemy truck is preferred over anything else", world.unit.target[shooter] == truck)
end)
-- }}}

-- {{{ nothing is out of range, closer
-- {{{ local function level()
-- A world on flat ground at height 10 everywhere, with an optional ridge of
-- height 14 along the column x = ridge, from the top edge to y = 40: tall
-- enough to hide a tank from a tank, low enough that a plane shows over it.
local function level(ridge)
  local world = fresh()
  local field = world.field
  for index = 1, #field.height do field.height[index] = 10 end
  if ridge ~= nil then
    for y = 0, 40 do field.height[y * field.size + ridge + 1] = 14 end
  end
  return world
end
-- }}}

harness.suite("falloff is a straight line to a floor, and a shell takes whole ticks", function()
  local targeting = harness.load("targeting", "205")
  local units = harness.load("units", "201")
  local tank = units.kind("tank")
  harness.check("full out to falloff_full", targeting.falloff("tank", tank.falloff_full) == 1)
  local middle = (tank.falloff_full + tank.falloff_end) / 2
  harness.check("halfway down the line, halfway to the floor",
                math.abs(targeting.falloff("tank", middle) - (1 + tank.falloff_floor) / 2) < 1e-12,
                targeting.falloff("tank", middle))
  harness.check("the floor from falloff_end on", targeting.falloff("tank", tank.falloff_end) == tank.falloff_floor
                and targeting.falloff("tank", tank.falloff_end * 10) == tank.falloff_floor)
  local ok, problem = pcall(targeting.falloff, "catapult", 3)
  harness.check("a kind the catalogue lacks is refused by name",
                not ok and tostring(problem):find("catapult", 1, true) ~= nil, problem)
  harness.check("a shell's flight is the distance over its speed, rounded up",
                targeting.flight_ticks("tank", 5 * tank.shell_speed + 0.1) == 6
                and targeting.flight_ticks("tank", 5 * tank.shell_speed) == 5)
  harness.check("and never less than one tick", targeting.flight_ticks("tank", 0) == 1)
  harness.check("a kind with no weapon has no flight",
                not pcall(targeting.flight_ticks, "command-truck", 3))
end)

harness.suite("a unit chooses only what it sees, and keeps what it chose", function()
  local targeting = harness.load("targeting", "205")
  local units = harness.load("units", "201")
  local world = level(20)
  local shooter = units.spawn(world, "tank", 1, 10, 10)
  local hidden = units.spawn(world, "tank", 2, 25, 10)
  targeting.aim_pass(world)
  harness.check("an enemy behind a ridge is not chosen", world.unit.target[shooter] == 0)
  local left = units.spawn(world, "tank", 2, 10, 50)
  local right = units.spawn(world, "tank", 2, 10, 50)
  targeting.aim_pass(world)
  harness.check("of two at one distance, the lower row is chosen", world.unit.target[shooter] == left)
  local closer = units.spawn(world, "tank", 2, 10, 45)
  targeting.aim_pass(world)
  harness.check("a closer enemy of the same class does not take the target away",
                world.unit.target[shooter] == left)
  world.unit.x[left] = 25
  world.unit.y[left] = 20
  targeting.aim_pass(world)
  harness.check("a target that goes out of sight is dropped for the best in sight",
                world.unit.target[shooter] == closer, world.unit.target[shooter])
  local gun = units.spawn(world, "anti-air", 1, 15, 10)
  local plane = units.spawn(world, "helicopter", 2, 25, 10)
  targeting.aim_pass(world)
  harness.check("a gun behind the ridge sees a plane flying over the far side",
                world.unit.target[gun] == plane)
  local seen = targeting.visible(world, shooter)
  harness.check("visible lists every enemy in sight, whatever the weapon reaches",
                #seen == 3 and seen[1] == right and seen[2] == closer and seen[3] == plane,
                table.concat(seen, ","))
  harness.check("the hidden tank is not among them", hidden ~= seen[1] and hidden ~= seen[2])
end)

harness.suite("only a reloaded weapon aims, and aiming writes only the target", function()
  local targeting = harness.load("targeting", "205")
  local units = harness.load("units", "201")
  local snapshot = harness.load("snapshot", "109")
  local the_tick = harness.load("the-tick", "105")
  local world = level()
  local shooter = units.spawn(world, "tank", 1, 10, 10)
  local enemy = units.spawn(world, "tank", 2, 20, 10)
  local truck = units.spawn(world, "command-truck", 2, 30, 30)
  harness.check("every weapon has a reload counter, and the truck has none",
                world.reload.tank ~= nil and world.reload.tank.period == units.kind("tank").reload_ticks
                and world.reload["command-truck"] == nil)
  world.unit.reload_at[shooter] = world.reload.tank.increment + 1
  targeting.aim_pass(world)
  harness.check("a weapon still reloading does not choose", world.unit.target[shooter] == 0)
  world.unit.reload_at[shooter] = 0
  local before = snapshot.hash(world)
  local was = world.unit.target[enemy]
  targeting.aim_pass(world)
  harness.check("a reloaded one does", world.unit.target[shooter] == truck)
  harness.check("the truck, with no weapon, chooses nothing", world.unit.target[truck] == 0)
  world.unit.target[shooter] = 0
  world.unit.target[enemy] = was
  harness.check("nothing but the targets changed", snapshot.hash(world) == before)
  local row = the_tick.SYSTEMS[7]
  harness.check("the tick's seventh row is the aim pass, and it slices",
                row.name == "sight-and-aim" and row.waiting_for == nil and row.sliceable)
end)

harness.suite("the viewer's sightline layer marks what a unit sees", function()
  local targeting = harness.load("targeting", "205")
  local units = harness.load("units", "201")
  local viewer = harness.load("terminal-viewer", "111")
  local snapshot = harness.load("snapshot", "109")
  local world = level(20)
  local shooter = units.spawn(world, "tank", 1, 10, 10)
  units.spawn(world, "tank", 2, 25, 10)
  units.spawn(world, "tank", 2, 10, 50)
  local picture = viewer.draw(snapshot.copy(world), {seen = targeting.visible(world, shooter)})
  local rows = {}
  for line in picture:gmatch("[^\n]+") do rows[#rows + 1] = line end
  harness.check("the enemy in sight is marked", rows[51]:sub(11, 11) == viewer.SEEN, rows[51])
  harness.check("the one behind the ridge keeps its letter", rows[11]:sub(26, 26) == "T", rows[11])
end)
-- }}}

-- {{{ buffered damage
harness.suite("a shot lands at the tick its distance says, and not before", function()
  local units = harness.load("units", "201")
  local combat = harness.load("combat", "206")
  local targeting = harness.load("targeting", "205")
  local timers = harness.load("timers", "106")
  local catalogue = harness.load_asset("unit-catalogue", "202")
  local world = fresh()
  for index = 1, #world.field.height do world.field.height[index] = 10 end
  local shooter = units.spawn(world, "tank", 1, 0, 0)
  local target = units.spawn(world, "tank", 2, 30, 0)
  targeting.aim_pass(world)
  -- Two enemy tanks in plain sight of each other both fire; the target holds
  -- its fire here so that the one shot in the queue is the shooter's.
  world.unit.target[target] = 0
  combat.fire_pass(world)
  harness.check("firing appends a shot", world.shot.count == 1)
  local arrival = world.shot.arrives[1]
  harness.check("the shot arrives later than now", arrival > world.tick)
  harness.check("the arrival is the distance over the shell's speed",
                arrival == world.tick + math.ceil(30 / catalogue.tank.shell_speed))
  local before = timers.read(world.unit.health[target], world.unit.health_at[target],
                             world.heal[catalogue.tank.name or "tank"], catalogue.tank.health)
  combat.land_pass(world)
  harness.check("nothing lands before its tick", world.shot.count == 1)
  world.tick = arrival
  combat.land_pass(world)
  harness.check("the shot lands at its tick", world.shot.count == 0)
  local after = timers.read(world.unit.health[target], world.unit.health_at[target],
                            world.heal["tank"], catalogue.tank.health)
  harness.check("the target lost health", after < before, before .. " -> " .. after)
end)
-- }}}

-- {{{ shared healing
harness.suite("health comes back on a shared timer", function()
  local units = harness.load("units", "201")
  local combat = harness.load("combat", "206")
  local timers = harness.load("timers", "106")
  local catalogue = harness.load_asset("unit-catalogue", "202")
  local world = fresh()
  local a = units.spawn(world, "tank", 1, 0, 0)
  local b = units.spawn(world, "tank", 1, 5, 5)
  combat.hurt(world, a, catalogue.tank.damage)
  combat.hurt(world, b, catalogue.tank.damage)
  local cap = catalogue.tank.health
  local counter = world.heal.tank
  local function health(id)
    return timers.read(world.unit.health[id], world.unit.health_at[id], counter, cap)
  end
  local hurt = health(a)
  harness.check("a hurt tank is below its cap", hurt < cap)
  for _ = 1, counter.period do
    world.tick = world.tick + 1
    timers.advance(counter, world.tick)
  end
  harness.check("one increment heals every tank by one, without a walk",
                health(a) == hurt + 1 and health(b) == hurt + 1)
  for _ = 1, counter.period * cap do
    world.tick = world.tick + 1
    timers.advance(counter, world.tick)
  end
  harness.check("health never exceeds the cap", health(a) == cap)
  combat.hurt(world, a, 1)
  combat.hurt(world, a, 1)
  harness.check("two hurts on one increment both apply", health(a) == cap - 2)
end)
-- }}}

-- {{{ buffered damage, closer
harness.suite("firing writes the shooter's row and the queue, and nothing else", function()
  local units = harness.load("units", "201")
  local combat = harness.load("combat", "206")
  local targeting = harness.load("targeting", "205")
  local world = level()
  local shooter = units.spawn(world, "tank", 1, 10, 10)
  local enemy = units.spawn(world, "tank", 2, 40, 10)
  local cap = units.kind("tank").health
  targeting.aim_pass(world)
  combat.fire_pass(world)
  local shot = world.shot
  harness.check("both tanks fire, in row order", shot.count == 2
                and shot.shooter[1] == shooter and shot.target[1] == enemy
                and shot.shooter[2] == enemy and shot.target[2] == shooter, combat.describe(world, 1))
  harness.check("the damage is the falloff at the distance, rounded down",
                shot.damage[1] == math.floor(25 * targeting.falloff("tank", 30))
                and shot.damage[1] == combat.damage_at(world, shooter, 30), shot.damage[1])
  harness.check("firing rewrites reload_at to the next reload increment",
                world.unit.reload_at[shooter] == world.reload.tank.increment + 1
                and not targeting.ready(world, shooter))
  harness.check("firing hurts nobody", combat.health(world, shooter) == cap
                and combat.health(world, enemy) == cap)
  combat.fire_pass(world)
  harness.check("a weapon reloading does not fire twice", shot.count == 2)
  harness.check("a shot describes itself for a failing test",
                combat.describe(world, 1):find("arrives at tick " .. shot.arrives[1], 1, true) ~= nil
                and combat.describe(world, 3):find("no shot 3", 1, true) ~= nil)
end)

harness.suite("shots land in queue order, and a shot at the dead is dropped", function()
  local units = harness.load("units", "201")
  local combat = harness.load("combat", "206")
  local the_world = harness.load("the-world", "104")
  local world = flat()
  local shooter = units.spawn(world, "tank", 1, 10, 10)
  local target = units.spawn(world, "frigate", 2, 30, 2)
  local other = units.spawn(world, "tank", 2, 40, 40)
  local function queue(arrives, at, damage)
    local index = the_world.push(world, "shot")
    world.shot.shooter[index], world.shot.target[index] = shooter, at
    world.shot.damage[index], world.shot.arrives[index] = damage, arrives
  end
  queue(3, target, 10)
  queue(9, target, 1)
  queue(3, target, 7)
  queue(7, other, 1)
  world.tick = 3
  combat.land_pass(world)
  local shot = world.shot
  harness.check("the shots due landed, the rest kept their order",
                shot.count == 2 and shot.arrives[1] == 9 and shot.arrives[2] == 7,
                combat.describe(world, 1) .. "; " .. combat.describe(world, 2))
  harness.check("the slots left over are zeroed", shot.arrives[3] == 0 and shot.target[4] == 0)
  harness.check("both landed shots were taken off", combat.health(world, target)
                == units.kind("frigate").health - 17, combat.health(world, target))
  the_world.release(world, "unit", other)
  world.tick = 9
  combat.land_pass(world)
  harness.check("a shot at a released row is dropped, not applied", shot.count == 0)
end)

harness.suite("the die pass takes out the dead and the shells flying at them", function()
  local units = harness.load("units", "201")
  local combat = harness.load("combat", "206")
  local the_world = harness.load("the-world", "104")
  local world = level()
  local a = units.spawn(world, "tank", 1, 10, 10)
  local b = units.spawn(world, "tank", 2, 20, 10)
  local c = units.spawn(world, "tank", 2, 30, 10)
  local raw = the_world.claim(world, "unit")
  local live = world.unit.count
  for _, at in ipairs({b, c, b}) do
    local index = the_world.push(world, "shot")
    world.shot.shooter[index], world.shot.target[index], world.shot.arrives[index] = a, at, 50
  end
  combat.hurt(world, b, units.kind("tank").health)
  harness.check("a unit at zero is still a row until the die pass", world.unit.alive[b] == 1)
  harness.check("one died", combat.die_pass(world) == 1)
  harness.check("its row is released and the live count lowered",
                world.unit.alive[b] == 0 and world.unit.count == live - 1)
  harness.check("the shells flying at it are dropped, the others kept",
                world.shot.count == 1 and world.shot.target[1] == c)
  harness.check("a raw row of no kind is not killed", world.unit.alive[raw] == 1)
  harness.check("nothing more dies on the next pass", combat.die_pass(world) == 0)
  harness.check("a released row has no health to read", not pcall(combat.health, world, b))
  local tank = units.kind("tank")
  harness.check("the report gives each kind's heal rhythm in ticks and seconds",
                units.report():find(string.format("tank%s every %d ticks (%g s)",
                                                  string.rep(" ", 10), tank.heal_ticks, tank.heal_period),
                                    1, true) ~= nil)
  harness.check("a hurt is a whole number from zero",
                not pcall(combat.hurt, world, a, -1) and not pcall(combat.hurt, world, a, 0.5))
end)

harness.suite("a full shot queue is refused by name, and the tick lands and buries", function()
  local units = harness.load("units", "201")
  local combat = harness.load("combat", "206")
  local targeting = harness.load("targeting", "205")
  local the_world = harness.load("the-world", "104")
  local the_tick = harness.load("the-tick", "105")
  local snapshot = harness.load("snapshot", "109")
  local small = the_world.allocate({field = FIELD, units = 2, teams = 2, seed = SEED})
  for index = 1, #small.field.height do small.field.height[index] = 10 end
  units.spawn(small, "tank", 1, 10, 10)
  units.spawn(small, "tank", 2, 20, 10)
  targeting.aim_pass(small)
  while small.shot.count < small.shot.capacity do the_world.push(small, "shot") end
  local ok, problem = pcall(combat.fire_pass, small)
  harness.check("a full queue refuses, naming the shot queue",
                not ok and tostring(problem):find("shot queue is full", 1, true) ~= nil, problem)
  local names = {}
  for index = 8, 10 do
    local row = the_tick.SYSTEMS[index]
    names[#names + 1] = row.name .. (row.waiting_for == nil and "" or "?") .. (row.sliceable and "*" or "")
  end
  harness.check("the tick's eighth to tenth rows are fire, land and die, and fire slices",
                table.concat(names, " ") == "fire* land die", table.concat(names, " "))
  local function duel()
    local world = flat()
    units.spawn(world, "tank", 1, 10, 10)
    units.spawn(world, "tank", 2, 20, 10)
    units.spawn(world, "frigate", 2, 30, 2)
    targeting.aim_pass(world)
    return world
  end
  local whole, sliced = duel(), duel()
  combat.fire_pass(whole)
  combat.fire_pass_slice(sliced, 1, 1)
  combat.fire_pass_slice(sliced, 2, sliced.unit.top)
  harness.check("slices in ascending order fire exactly what the whole pass does",
                snapshot.hash(whole) == snapshot.hash(sliced) and whole.shot.count >= 2,
                whole.shot.count .. " shots")
  local before = snapshot.hash(whole)
  whole.shot.damage[1] = whole.shot.damage[1] + 1
  harness.check("the shots in flight are part of the fingerprint", snapshot.hash(whole) ~= before)
  local world = level()
  units.spawn(world, "tank", 1, 10, 10)
  units.spawn(world, "tank", 2, 20, 10)
  while world.unit.count == 2 and world.tick < 2000 do the_tick.advance(world) end
  harness.check("two tanks in sight of each other fight until one dies", world.unit.count < 2,
                "tick " .. world.tick)
  harness.check("and nothing is left flying at the dead", world.shot.count == 0,
                combat.describe(world, 1))
end)
-- }}}

-- {{{ bones
harness.suite("death leaves bones that carry mass", function()
  local units = harness.load("units", "201")
  local combat = harness.load("combat", "206")
  local bones = harness.load("bones", "208")
  local catalogue = harness.load_asset("unit-catalogue", "202")
  local world = fresh()
  local id = units.spawn(world, "tank", 2, 8, 8)
  combat.hurt(world, id, catalogue.tank.health * 2)
  combat.die_pass(world)
  harness.check("the unit is no longer alive", units.alive(world) == 0)
  harness.check("one set of bones was left", world.bone.count == 1)
  harness.check("the bones lie where the unit died", world.bone.x[1] == 8 and world.bone.y[1] == 8)
  harness.check("the bones carry mass", world.bone.mass[1] > 0)
  harness.check("bones belong to nobody", world.bone.team == nil or world.bone.team[1] == 0)
end)
-- }}}

-- {{{ bones, closer
harness.suite("bones carry a share of what the unit cost, and only a death leaves them", function()
  local units = harness.load("units", "201")
  local combat = harness.load("combat", "206")
  local bones = harness.load("bones", "208")
  local rate = harness.load_asset("the-rules", "105").ticks_per_second
  local tank = units.kind("tank")
  harness.check("a tank's bones are its share of its mass cost, rounded down",
                bones.mass_of("tank") == math.floor(tank.cost_mass * tank.bone_share)
                and bones.mass_of("tank") > 0)
  local raw = raw_catalogue()
  raw.tank.bone_share = 1.5
  local fine, message = pcall(units.validate_catalogue, raw, rate)
  harness.check("a death never puts back more than the unit cost",
                not fine and tostring(message):find("tank.bone_share", 1, true) ~= nil, message)
  local world = level()
  local truck = units.spawn(world, "command-truck", 1, 20, 20)
  local heli = units.spawn(world, "helicopter", 2, 30, 30)
  combat.hurt(world, truck, units.kind("command-truck").health)
  combat.hurt(world, heli, units.kind("helicopter").health)
  harness.check("both died", combat.die_pass(world) == 2)
  harness.check("a kind that cost no mass leaves no bones; a plane leaves its share",
                world.bone.count == 1 and world.bone.x[1] == 30 and world.bone.y[1] == 30
                and world.bone.mass[1] == bones.mass_of("helicopter"), world.bone.count)
  harness.check("the bones' total is what lies on the field", bones.total(world) == world.bone.mass[1])
  harness.check("bones are left only where the field is",
                not pcall(bones.leave_at, world, -3, 5, 10) and not pcall(bones.leave_at, world, 5, 64, 10))
  harness.check("and only with a whole mass of at least one",
                not pcall(bones.leave_at, world, 5, 5, 0) and not pcall(bones.leave_at, world, 5, 5, 2.5))
  harness.check("a released row leaves no bones a second time",
                not pcall(bones.leave, world, heli))
end)

harness.suite("bones are found near a point, eaten in order, and refused when full", function()
  local units = harness.load("units", "201")
  local bones = harness.load("bones", "208")
  local the_world = harness.load("the-world", "104")
  local snapshot = harness.load("snapshot", "109")
  local viewer = harness.load("terminal-viewer", "111")
  local world = level()
  local eater = units.spawn(world, "enforcer", 1, 10, 10)
  bones.leave_at(world, 10, 12, 30)
  bones.leave_at(world, 40, 40, 20)
  bones.leave_at(world, 11, 9, 10)
  local near = bones.near(world, 10, 10, 2)
  harness.check("near finds the bones within the radius, in queue order",
                #near == 2 and near[1] == 1 and near[2] == 3, table.concat(near, ","))
  local before = snapshot.hash(world)
  harness.check("eating hands back the mass", bones.eat(world, eater, near[2]) == 10
                and bones.eat(world, eater, near[1]) == 30)
  harness.check("the queue closes up in order", world.bone.count == 1 and world.bone.mass[1] == 20
                and world.bone.mass[2] == 0 and world.bone.x[3] == 0)
  harness.check("the bones are part of the fingerprint", snapshot.hash(world) ~= before)
  harness.check("there is nothing to eat past the queue", not pcall(bones.eat, world, eater, 2))
  harness.check("a copy carries the bones", snapshot.copy(world).bone.mass[1] == 20)
  local tank = units.spawn(world, "tank", 2, 40, 40)
  bones.leave_at(world, 20, 30, 5)
  local rows = {}
  for line in viewer.draw(snapshot.copy(world)):gmatch("[^\n]+") do rows[#rows + 1] = line end
  harness.check("the viewer draws bones where no unit stands",
                rows[31]:sub(21, 21) == viewer.BONE, rows[31])
  harness.check("and a unit over the bones it stands on",
                rows[41]:sub(41, 41) == viewer.LETTERS[units.index_of("tank")], rows[41])
  the_world.release(world, "unit", tank)
  harness.check("a released row eats nothing", not pcall(bones.eat, world, tank, 1))
  local small = the_world.allocate({field = FIELD, units = 1, teams = 2, seed = SEED})
  for _ = 1, small.bone.capacity do bones.leave_at(small, 3, 3, 1) end
  local ok, problem = pcall(bones.leave_at, small, 3, 3, 1)
  harness.check("a full bone queue refuses, naming it",
                not ok and tostring(problem):find("bone queue is full", 1, true) ~= nil, problem)
end)
-- }}}

-- {{{ the thread pool
harness.suite("the thread pool slices a range without gaps or overlaps", function()
  local pool = harness.load("thread-pool", "209")
  local ranges = pool.slice(1000, 4)
  harness.check("four workers get four ranges", #ranges == 4)
  local covered = 0
  local last_end = 0
  local contiguous = true
  for _, range in ipairs(ranges) do
    if range[1] ~= last_end + 1 then contiguous = false end
    covered = covered + (range[2] - range[1] + 1)
    last_end = range[2]
  end
  harness.check("the ranges are contiguous", contiguous)
  harness.check("the ranges cover every index once", covered == 1000 and last_end == 1000)
  local empty = pool.slice(0, 4)
  harness.check("nothing to slice yields no work", #empty == 0)
end)
-- }}}

-- {{{ the command truck
harness.suite("the command truck moves and dies in one hit", function()
  local units = harness.load("units", "201")
  local truck = harness.load("command-truck", "210")
  local combat = harness.load("combat", "206")
  local catalogue = harness.load_asset("unit-catalogue", "202")
  local world = fresh()
  local id = units.spawn(world, "command-truck", 1, 4, 4)
  truck.move(world, id, 9, 4)
  local movement = harness.load("movement", "204")
  for _ = 1, 100 do movement.move_pass(world) end
  harness.check("the truck reached where it was pointed", world.unit.x[id] == 9 and world.unit.y[id] == 4)
  local refusal = truck.launch(world, id, 90)
  harness.check("a launch is accepted", refusal == nil, refusal)
  harness.check("a plane now exists", units.alive(world) == 2)
  refusal = truck.launch(world, id, 90)
  harness.check("a second launch before the counter allows it is refused", type(refusal) == "string")
  combat.hurt(world, id, catalogue.tank.damage)
  combat.die_pass(world)
  harness.check("one tank shell kills the truck", world.unit.alive[id] == 0)
end)
-- }}}

-- {{{ the enforcer
harness.suite("the enforcer eats bones and its sphere absorbs", function()
  local units = harness.load("units", "201")
  local enforcer = harness.load("enforcer", "211")
  local combat = harness.load("combat", "206")
  local bones = harness.load("bones", "208")
  local timers = harness.load("timers", "106")
  local catalogue = harness.load_asset("unit-catalogue", "202")
  local world = fresh()
  local big = units.spawn(world, "enforcer", 1, 10, 10)
  local friend = units.spawn(world, "tank", 1, 11, 10)
  world.unit.eat_share[big] = 0.5
  bones.leave_at(world, 10, 11, 100)
  enforcer.eat_pass(world)
  harness.check("the bones were eaten", world.bone.count == 0)
  harness.check("half went to the treasury", world.team.mass[1] == 50)
  harness.check("half went to the enforcer", world.unit.eaten[big] == 50)
  local shield_before = timers.read(world.unit.shield[big], world.unit.shield_at[big],
                                    world.recharge.enforcer, catalogue.enforcer.shield)
  combat.hurt(world, friend, catalogue.tank.damage)
  local shield_after = timers.read(world.unit.shield[big], world.unit.shield_at[big],
                                   world.recharge.enforcer, catalogue.enforcer.shield)
  harness.check("a hit on a friend inside the sphere is taken by the shield", shield_after < shield_before)
  local tank_health = timers.read(world.unit.health[friend], world.unit.health_at[friend],
                                  world.heal.tank, catalogue.tank.health)
  harness.check("the friend was not hurt", tank_health == catalogue.tank.health)
end)
-- }}}

harness.finish()
