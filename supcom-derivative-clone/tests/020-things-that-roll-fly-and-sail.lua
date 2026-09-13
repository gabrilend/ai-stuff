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
