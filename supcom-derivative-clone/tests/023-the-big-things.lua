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
