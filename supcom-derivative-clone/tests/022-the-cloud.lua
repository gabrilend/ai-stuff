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

-- 022-the-cloud.lua
--
-- covers: 401, 402, 403, 404, 405, 406, 407
--
-- Phase 4: the swarm, rounds, fight or avoid, defensive flight over the guns,
-- reports and bombing runs, the upgrade table.
--
-- The air war is somewhere else, and these claims are about where planes are and
-- what mission they hold rather than about positions on the field -- except the
-- one that matters: an interceptor over enemy ground is a plane a gun can see.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local harness = loadfile(ROOT .. "/tests/018-the-harness.lua")()
harness.start({...}, "022-the-cloud")

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

-- {{{ local function fly_until()
local function fly_until(world, cloud, id, mission, limit)
  for _ = 1, limit do
    if world.unit.mission[id] == cloud.MISSIONS[mission] then return true end
    world.tick = world.tick + 1
    cloud.fly_pass(world)
  end
  return world.unit.mission[id] == cloud.MISSIONS[mission]
end
-- }}}

-- {{{ the cloud is a place
harness.suite("the cloud is one place over the field's centre", function()
  local cloud = harness.load("the-cloud", "401")
  local world = fresh()
  harness.check("the cloud has a position", type(world.cloud.x) == "number" and type(world.cloud.y) == "number")
  harness.check("it is over the centre", math.abs(world.cloud.x - FIELD.size / 2) <= 1
                and math.abs(world.cloud.y - FIELD.size / 2) <= 1)
  harness.check("the missions are a dispatch table", type(cloud.MISSIONS) == "table"
                and cloud.MISSIONS["to-cloud"] ~= nil and cloud.MISSIONS["in-cloud"] ~= nil
                and cloud.MISSIONS.defensive ~= nil and cloud.MISSIONS.intercepting ~= nil
                and cloud.MISSIONS.bombing ~= nil and cloud.MISSIONS.returning ~= nil)
end)
-- }}}

-- {{{ from the factory to the cloud
harness.suite("a plane with no orders goes to the cloud", function()
  local cloud = harness.load("the-cloud", "402")
  local units = harness.load("units", "201")
  local world = fresh()
  local plane = units.spawn(world, "helicopter", 1, 2, 2)
  harness.check("a fresh plane is flying to the cloud", world.unit.mission[plane] == cloud.MISSIONS["to-cloud"])
  harness.check("a plane has no pattern", world.unit.pattern[plane] == 0)
  harness.check("it arrives", fly_until(world, cloud, plane, "in-cloud", 2000))
end)
-- }}}

-- {{{ fight or avoid
harness.suite("a weaker side goes defensive and a stronger side intercepts", function()
  local cloud = harness.load("the-cloud", "403")
  local upgrades = harness.load("plane-upgrades", "407")
  local units = harness.load("units", "201")
  local world = fresh()
  upgrades.buy(world, 1, "engines")
  upgrades.buy(world, 1, "guns")
  harness.check("a team's strength is the sum of its upgrades", upgrades.strength(world, 1) > upgrades.strength(world, 2))
  local strong = units.spawn(world, "helicopter", 1, world.cloud.x, world.cloud.y)
  local weak = units.spawn(world, "helicopter", 2, world.cloud.x, world.cloud.y)
  harness.check("a plane copies its team's strength at birth",
                world.unit.strength[strong] == upgrades.strength(world, 1))
  upgrades.buy(world, 1, "armour")
  harness.check("a later upgrade does not reach a plane already built",
                world.unit.strength[strong] < upgrades.strength(world, 1))
  world.unit.mission[strong] = cloud.MISSIONS["in-cloud"]
  world.unit.mission[weak] = cloud.MISSIONS["in-cloud"]
  cloud.round_pass(world)
  harness.check("the weaker plane goes defensive", world.unit.mission[weak] == cloud.MISSIONS.defensive)
  harness.check("the stronger plane intercepts", world.unit.mission[strong] == cloud.MISSIONS.intercepting
                and world.unit.target[strong] == weak)
end)

harness.suite("rounds fire on a counter and resolve pairs on a named stream", function()
  local cloud = harness.load("the-cloud", "403")
  local units = harness.load("units", "201")
  local timers = harness.load("timers", "106")
  local catalogue = harness.load_asset("unit-catalogue", "202")
  local world = fresh()
  local a = units.spawn(world, "helicopter", 1, world.cloud.x, world.cloud.y)
  local b = units.spawn(world, "helicopter", 2, world.cloud.x, world.cloud.y)
  world.unit.mission[a] = cloud.MISSIONS["in-cloud"]
  world.unit.mission[b] = cloud.MISSIONS["in-cloud"]
  local function health(id)
    return timers.read(world.unit.health[id], world.unit.health_at[id],
                       world.heal.helicopter, catalogue.helicopter.health)
  end
  local before = health(a) + health(b)
  cloud.round_pass(world)
  harness.check("nothing happens between round increments", health(a) + health(b) == before)
  for _ = 1, world.cloud_round.period do
    world.tick = world.tick + 1
    timers.advance(world.cloud_round, world.tick)
  end
  cloud.round_pass(world)
  harness.check("a round hurts one of an even pair", health(a) + health(b) < before)
end)
-- }}}

-- {{{ over the guns
harness.suite("an interceptor over enemy ground is shot by a gun that sees it", function()
  local cloud = harness.load("the-cloud", "404")
  local units = harness.load("units", "201")
  local targeting = harness.load("targeting", "405")
  local territory = harness.load("territory", "112")
  local world = fresh()
  for index = 1, #world.cell.owner do
    world.cell.owner[index] = (index <= #world.cell.owner / 2) and 1 or 2
  end
  local weak = units.spawn(world, "helicopter", 2, world.cloud.x, world.cloud.y)
  world.unit.mission[weak] = cloud.MISSIONS.defensive
  cloud.fly_pass(world)
  for _ = 1, 500 do
    world.tick = world.tick + 1
    cloud.fly_pass(world)
  end
  local cell = math.floor(world.unit.y[weak]) * FIELD.size + math.floor(world.unit.x[weak]) + 1
  harness.check("a defensive plane flies over its own ground", territory.owner(world, cell) == 2)
  local gun = units.spawn(world, "anti-air", 2, world.unit.x[weak], world.unit.y[weak] + 1)
  local strong = units.spawn(world, "helicopter", 1, world.unit.x[weak], world.unit.y[weak])
  world.unit.mission[strong] = cloud.MISSIONS.intercepting
  world.unit.target[strong] = weak
  targeting.aim_pass(world)
  harness.check("the gun targets the interceptor over its ground", world.unit.target[gun] == strong)
  world.unit.x[strong] = world.cloud.x
  world.unit.y[strong] = world.cloud.y
  world.unit.mission[strong] = cloud.MISSIONS["in-cloud"]
  world.unit.target[gun] = 0
  targeting.aim_pass(world)
  harness.check("the gun does not reach into the cloud", world.unit.target[gun] ~= strong)
end)
-- }}}

-- {{{ reports
harness.suite("a report sends exactly the unbothered, equipped planes", function()
  local cloud = harness.load("the-cloud", "406")
  local units = harness.load("units", "201")
  local world = fresh()
  local idle = units.spawn(world, "helicopter", 1, world.cloud.x, world.cloud.y)
  local busy = units.spawn(world, "helicopter", 1, world.cloud.x, world.cloud.y)
  local shy = units.spawn(world, "helicopter", 1, world.cloud.x, world.cloud.y)
  local enemy = units.spawn(world, "helicopter", 2, world.cloud.x, world.cloud.y)
  world.unit.mission[idle] = cloud.MISSIONS["in-cloud"]
  world.unit.mission[busy] = cloud.MISSIONS["in-cloud"]
  world.unit.in_round[busy] = 1
  world.unit.mission[shy] = cloud.MISSIONS.defensive
  world.unit.mission[enemy] = cloud.MISSIONS["in-cloud"]
  cloud.report(world, 1, 50, 50)
  harness.check("the idle plane leaves on a bombing run", world.unit.mission[idle] == cloud.MISSIONS.bombing)
  harness.check("a plane in a round stays", world.unit.mission[busy] == cloud.MISSIONS["in-cloud"])
  harness.check("a defensive plane stays", world.unit.mission[shy] == cloud.MISSIONS.defensive)
  harness.check("the enemy's plane is not sent by our report", world.unit.mission[enemy] == cloud.MISSIONS["in-cloud"])
  harness.check("the run knows where it is going", world.unit.goal_x[idle] == 50 and world.unit.goal_y[idle] == 50)
  local landed = fly_until(world, cloud, idle, "returning", 3000)
  harness.check("the run ends and the plane returns", landed)
  local cell = 50 * FIELD.size + 50 + 1
  harness.check("the bombed cell was claimed", world.cell.owner[cell] == 1 or world.cell.claim_by[cell] == 1)
end)
-- }}}

-- {{{ the upgrade table
harness.suite("the plane upgrade table is data", function()
  local upgrades = harness.load("plane-upgrades", "407")
  local table_of = harness.load_asset("plane-upgrades", "407")
  local world = fresh()
  harness.check("every upgrade has an energy cost and a strength",
                table_of.engines ~= nil and table_of.engines.energy > 0 and table_of.engines.strength > 0)
  local ok = pcall(upgrades.buy, world, 1, "no-such-upgrade")
  harness.check("an unknown upgrade is refused", not ok)
end)
-- }}}

harness.finish()
