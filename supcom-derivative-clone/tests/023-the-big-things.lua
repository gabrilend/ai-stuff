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

-- 023-the-big-things.lua
--
-- covers: 501, 502, 503, 504, 505
--
-- Phase 5: experimentals for everyone, artillery without falloff, carriers that
-- build while moving.
--
-- Under-claimed on purpose: 506 (submarines and torpedo planes) has no claim
-- here because the demo does not build it and a claim about a thing the demo
-- refuses would be a claim about nothing.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local harness = loadfile(ROOT .. "/tests/018-the-harness.lua")()
harness.start({...}, "023-the-big-things")

local SEED = harness.seed()
local FIELD = {size = 64, dune_height = 20, dune_wavelength = 16, roughness = 0.4,
               water_line = 4, hydrocarbon_rate = 0.02}

-- {{{ local function fresh()
local function fresh()
  local the_tick = harness.load("the-tick", "105")
  local the_world = harness.load("the-world", "104")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
  for index = 1, #world.field.height do world.field.height[index] = 10 end
  return world, the_tick
end
-- }}}

-- {{{ everyone has the same
harness.suite("everyone has the same experimentals, at a thousand", function()
  local experimentals = harness.load_asset("experimentals", "501")
  local cost = harness.load_asset("cost-table", "306")
  local tank = cost.for_kind("tank")
  for _, name in ipairs({"artillery", "gunship", "land-carrier", "underwater-carrier", "air-factory"}) do
    harness.check("the catalogue has the " .. name, experimentals[name] ~= nil)
    if experimentals[name] ~= nil then
      local price = cost.for_kind(name)
      harness.check(name .. " costs a hundred times a tank on its leaning resource",
                    math.max(price.mass, price.energy) == 100 * math.max(tank.mass, tank.energy))
      harness.check(name .. " is not tied to a team", experimentals[name].team == nil)
    end
  end
end)
-- }}}

-- {{{ artillery
harness.suite("artillery loses nothing to distance", function()
  local targeting = harness.load("targeting", "502")
  harness.check("full damage next door", targeting.falloff("artillery", 1) == 1)
  harness.check("full damage across the field", targeting.falloff("artillery", 100000) == 1)
end)
-- }}}

-- {{{ artillery, closer
harness.suite("falloff is a table of shapes, and the artillery's is flat and slow", function()
  local targeting = harness.load("targeting", "502")
  local units = harness.load("units", "201")
  local viewer = harness.load("terminal-viewer", "111")
  harness.check("the shapes are linear-to-floor, then flat",
                #targeting.FALLOFF == 2 and targeting.FALLOFF[1].name == "linear-to-floor"
                and targeting.FALLOFF[2].name == "flat")
  harness.check("a tank's shell still falls to its floor",
                targeting.falloff("tank", 1000) == units.kind("tank").falloff_floor)
  harness.check("at every distance between, the artillery loses nothing",
                targeting.falloff("artillery", 0) == 1 and targeting.falloff("artillery", 63) == 1)
  local slowest = true
  for _, row in ipairs(units.catalogue().kinds) do
    if row.name ~= "artillery" and row.shell_speed > 0
       and row.shell_speed <= units.kind("artillery").shell_speed then
      slowest = false
    end
  end
  harness.check("its shell is the slowest in the catalogue", slowest)
  local speed = units.kind("artillery").shell_speed
  harness.check("and a shot across the field is many ticks in flight, with no cap",
                targeting.flight_ticks("artillery", 90) == math.ceil(90 / speed)
                and targeting.flight_ticks("artillery", 90) > 100)
  harness.check("the viewer has its letter", viewer.LETTERS[units.index_of("artillery")] == "R")
  local rate = harness.load_asset("the-rules", "105").ticks_per_second
  local raw = {}
  for name, row in pairs(harness.load_asset("unit-catalogue", "202")) do
    raw[name] = {}
    for key, value in pairs(row) do raw[name][key] = value end
  end
  raw.tank.team_sight = 2
  local fine, message = pcall(units.validate_catalogue, raw, rate)
  harness.check("team sight is nought or one",
                not fine and tostring(message):find("tank.team_sight", 1, true) ~= nil, message)
end)

harness.suite("the artillery fires at what its team sees, and holds fire unseen", function()
  local targeting = harness.load("targeting", "502")
  local units = harness.load("units", "201")
  local the_world = harness.load("the-world", "104")
  local world = fresh()
  for y = 0, world.field.size - 1 do world.field.height[y * world.field.size + 20 + 1] = 14 end
  local gun = units.spawn(world, "artillery", 1, 5, 10)
  local enemy = units.spawn(world, "tank", 2, 30, 10)
  harness.check("the ridge hides the enemy from the artillery's own eye",
                not targeting.sees(world, gun, enemy))
  targeting.aim_pass(world)
  harness.check("with no friendly eye on it, the artillery holds fire", world.unit.target[gun] == 0)
  local friend = units.spawn(world, "tank", 1, 25, 10)
  targeting.aim_pass(world)
  harness.check("a friend that chose the enemy marks it seen by the team",
                world.unit.target[friend] == enemy and targeting.seen_by_team(world, gun, enemy))
  harness.check("and the artillery fires at it over the ridge", world.unit.target[gun] == enemy)
  harness.check("each team's sight is its own bit",
                world.unit.seen[enemy] == 1 and world.unit.seen[friend] == 2)
  the_world.release(world, "unit", friend)
  targeting.aim_pass(world)
  harness.check("its own choice keeps nothing seen: with the eye gone, it holds fire",
                world.unit.target[gun] == 0 and world.unit.seen[enemy] == 0)
end)
-- }}}

-- {{{ the gunship
harness.suite("the gunship flies a pattern and ignores the cloud", function()
  local units = harness.load("units", "503")
  local cloud = harness.load("the-cloud", "401")
  local world = fresh()
  local id = units.spawn(world, "gunship", 1, 2, 2)
  harness.check("a gunship has a pattern slot", world.unit.pattern ~= nil)
  harness.check("a gunship is not bound for the cloud", world.unit.mission[id] ~= cloud.MISSIONS["to-cloud"])
end)
-- }}}

-- {{{ the carrier
harness.suite("a moving carrier builds for free and unleashes when it stops", function()
  local experimentals = harness.load("experimentals", "504")
  local units = harness.load("units", "201")
  local world = fresh()
  world.team.mass[1] = 500
  world.team.energy[1] = 500
  local id = experimentals.place_carrier(world, 1, "land-carrier", {{x = 2, y = 2}, {x = 30, y = 2}},
                                         "tanks", {{x = 30, y = 2}, {x = 40, y = 2}}, false)
  local mass_before, energy_before = world.team.mass[1], world.team.energy[1]
  for _ = 1, 50 do
    world.tick = world.tick + 1
    experimentals.carrier_pass(world)
  end
  harness.check("building while moving draws nothing", world.team.mass[1] == mass_before
                and world.team.energy[1] == energy_before)
  harness.check("what it built is inside it", world.carrier.held[id] > 0)
  harness.check("nothing has swarmed out yet", units.alive(world) == 1)
  for _ = 1, 2000 do
    world.tick = world.tick + 1
    experimentals.carrier_pass(world)
    if world.carrier.moving[id] == 0 then break end
  end
  harness.check("the carrier reached the end of its pattern and stopped", world.carrier.moving[id] == 0)
  experimentals.carrier_pass(world)
  harness.check("standing still, its contents swarmed out", units.alive(world) > 1 and world.carrier.held[id] == 0)
end)

harness.suite("a carrier told to keep hold unleashes only when hit", function()
  local experimentals = harness.load("experimentals", "504")
  local units = harness.load("units", "201")
  local combat = harness.load("combat", "206")
  local world = fresh()
  local id = experimentals.place_carrier(world, 1, "land-carrier", {{x = 2, y = 2}, {x = 4, y = 2}},
                                         "tanks", {{x = 4, y = 2}, {x = 10, y = 2}}, true)
  for _ = 1, 2000 do
    world.tick = world.tick + 1
    experimentals.carrier_pass(world)
  end
  harness.check("stopped and holding, nothing swarmed out", units.alive(world) == 1 and world.carrier.held[id] > 0)
  combat.hurt(world, id, 1)
  experimentals.carrier_pass(world)
  harness.check("hit, the contents come out", units.alive(world) > 1)
end)
-- }}}

-- {{{ the air factory
harness.suite("the experimental air factory unleashes bombers on runs", function()
  local experimentals = harness.load("experimentals", "505")
  local cloud = harness.load("the-cloud", "406")
  local units = harness.load("units", "201")
  local world = fresh()
  local id = experimentals.place_carrier(world, 1, "air-factory", {{x = 2, y = 2}, {x = 3, y = 2}},
                                         "bombers", {{x = 50, y = 50}}, false)
  for _ = 1, 3000 do
    world.tick = world.tick + 1
    experimentals.carrier_pass(world)
    if units.alive(world) > 1 then break end
  end
  harness.check("bombers came out", units.alive(world) > 1)
  local bombing = false
  for other = 1, world.unit.count do
    if other ~= id and world.unit.alive[other] == 1 and world.unit.mission[other] == cloud.MISSIONS.bombing then
      bombing = true
    end
  end
  harness.check("and they are on a bombing run, not bound for the cloud", bombing)
end)
-- }}}

harness.finish()
