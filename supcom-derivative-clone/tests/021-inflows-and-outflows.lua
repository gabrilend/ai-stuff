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

-- 021-inflows-and-outflows.lua
--
-- covers: 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311
--
-- Phase 3: mass from cells, four levels, energy lost with ground, the roster,
-- streaming construction, the cost ratios, lines and patterns, losing ground
-- costs bodies, thorns.
--
-- The economy is inflows and outflows and nothing else, and every claim here is
-- about a flow: what a held cell pays, what a lost cell takes, what a line draws
-- per tick and what it stops drawing when the treasury is dry.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local harness = loadfile(ROOT .. "/tests/018-the-harness.lua")()
harness.start({...}, "021-inflows-and-outflows")

local SEED = harness.seed()
local FIELD = {size = 64, dune_height = 20, dune_wavelength = 16, roughness = 0.4,
               water_line = 4, hydrocarbon_rate = 0.02}

-- {{{ local function fresh()
local function fresh()
  local the_tick = harness.load("the-tick", "105")
  local the_world = harness.load("the-world", "104")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
  return world, the_tick
end
-- }}}

-- {{{ local function own_cells()
-- Paints a run of land cells for a team directly, so an economy suite does not
-- have to walk claims to get ground.
local function own_cells(world, team, count)
  local painted = 0
  for index = 1, #world.field.height do
    if painted < count and world.field.height[index] >= world.field.water_line then
      world.cell.owner[index] = team
      painted = painted + 1
    end
  end
  return painted
end
-- }}}

-- {{{ mass
harness.suite("territory implies mass", function()
  local economy = harness.load("economy", "301")
  local world = fresh()
  local held = own_cells(world, 1, 40)
  local before = world.team.mass[1]
  economy.income_pass(world)
  harness.check("a tick of income is held cells times the pay per cell",
                world.team.mass[1] - before == held * world.rule.mass_per_cell,
                (world.team.mass[1] - before) .. " for " .. held .. " cells")
  harness.check("a team with no ground earns nothing", world.team.mass[2] == 0)
end)
-- }}}

-- {{{ the four levels
harness.suite("the energy menu is four levels and never a fifth", function()
  local menu = harness.load("energy-menu", "302")
  local roster = harness.load("roster", "304")
  local world = fresh()
  harness.check("there are exactly four levels", #menu.LEVELS == 4)
  roster.add(world, 1, "engineer", 12)
  menu.set_level(world, 1, 1)
  harness.check("level one puts no engineers on energy", roster.on_energy(world, 1) == 0)
  menu.set_level(world, 1, 2)
  harness.check("level two puts a third on energy", roster.on_energy(world, 1) == 4)
  menu.set_level(world, 1, 3)
  harness.check("level three puts two thirds on energy", roster.on_energy(world, 1) == 8)
  menu.set_level(world, 1, 4)
  harness.check("level four puts all of them on energy", roster.on_energy(world, 1) == 12)
  local ok = pcall(menu.set_level, world, 1, 5)
  harness.check("a fifth level is refused", not ok)
end)
-- }}}

-- {{{ energy on the ground
harness.suite("energy is built on the ground and lost with it", function()
  local economy = harness.load("economy", "303")
  local world = fresh()
  own_cells(world, 1, 20)
  local cell
  for index = 1, #world.cell.owner do
    if world.cell.owner[index] == 1 then cell = index break end
  end
  economy.place_energy(world, 1, cell)
  local before = world.team.energy[1]
  economy.income_pass(world)
  local one_tick = world.team.energy[1] - before
  harness.check("a standing energy building pays energy", one_tick > 0)
  world.cell.owner[cell] = 2
  economy.consequences_pass(world)
  before = world.team.energy[1]
  economy.income_pass(world)
  harness.check("a building on a lost cell pays nothing", world.team.energy[1] - before == 0)
  harness.check("the building is gone", world.building.alive[1] == 0)
  -- A hydrocarbon cell buffs the next building.
  local other
  for index = 1, #world.cell.owner do
    if world.cell.owner[index] == 1 and index ~= cell then other = index break end
  end
  world.cell.hydrocarbon[other] = 1
  economy.find_hydrocarbon(world, 1, other)
  economy.place_energy(world, 1, other)
  before = world.team.energy[1]
  economy.income_pass(world)
  harness.check("a building raised after a find pays more", world.team.energy[1] - before > one_tick)
end)
-- }}}

-- {{{ the roster
harness.suite("builders are cheap and engineers are not", function()
  local roster = harness.load("roster", "304")
  local cost = harness.load_asset("cost-table", "306")
  local world = fresh()
  local builder = cost.for_kind("builder")
  local engineer = cost.for_kind("engineer")
  harness.check("an engineer costs more than a builder in every resource",
                engineer.mass > builder.mass and engineer.energy > builder.energy)
  harness.check("an engineer takes longer to make", engineer.build_ticks > builder.build_ticks)
  roster.add(world, 1, "builder", 10)
  roster.add(world, 1, "engineer", 3)
  harness.check("the roster counts what was added",
                roster.count(world, 1, "builder") == 10 and roster.count(world, 1, "engineer") == 3)
  harness.check("every roster member starts at full health", roster.hurt_count(world, 1) == 0)
end)
-- }}}

-- {{{ streaming construction
harness.suite("construction is a stream, and stalls when dry", function()
  local economy = harness.load("economy", "305")
  local factories = harness.load("factories", "307")
  local roster = harness.load("roster", "304")
  local cost = harness.load_asset("cost-table", "306")
  local world = fresh()
  own_cells(world, 1, 20)
  roster.add(world, 1, "builder", 10)
  world.team.mass[1] = 100000
  world.team.energy[1] = 100000
  local cell
  for index = 1, #world.cell.owner do
    if world.cell.owner[index] == 1 then cell = index break end
  end
  local id = factories.place(world, 1, cell, "land", "tanks", {{cell = cell}})
  harness.check("a factory was placed", type(id) == "number")
  local mass_before = world.team.mass[1]
  economy.construction_pass(world)
  local drawn = mass_before - world.team.mass[1]
  local tank = cost.for_kind("tank")
  harness.check("one tick draws a share of the cost, not the whole", drawn > 0 and drawn < tank.mass)
  world.team.mass[1] = 0
  local energy_before = world.team.energy[1]
  economy.construction_pass(world)
  harness.check("a dry treasury stalls the build: nothing is drawn from the other resource either",
                world.team.energy[1] == energy_before)
  harness.check("build power is the builders plus engineers off energy",
                economy.build_power(world, 1) == 10)
end)
-- }}}

-- {{{ the cost table
harness.suite("the cost table is a shape", function()
  local cost = harness.load_asset("cost-table", "306")
  local tank = cost.for_kind("tank")
  local heli = cost.for_kind("helicopter")
  local frigate = cost.for_kind("frigate")
  local gun = cost.for_kind("anti-air")
  local enforcer = cost.for_kind("enforcer")
  harness.check("a land unit's mass is ten times its energy", tank.mass == 10 * tank.energy)
  harness.check("an air unit's energy is ten times its mass", heli.energy == 10 * heli.mass)
  harness.check("a sea unit pays both equally", frigate.mass == frigate.energy)
  harness.check("land that shoots air pays both equally", gun.mass == gun.energy)
  harness.check("tier two costs ten times tier one on the leaning resource",
                enforcer.mass == 10 * tank.mass)
  harness.check("the alignment ratio is exposed as data", type(cost.RATIO) == "table"
                and cost.RATIO.land ~= nil and cost.RATIO.air ~= nil and cost.RATIO.sea ~= nil)
end)
-- }}}

-- {{{ lines and patterns
harness.suite("a factory is a line you did not design, and its pattern is drawn once", function()
  local factories = harness.load("factories", "307")
  local commands = harness.load("commands", "108")
  local world = fresh()
  own_cells(world, 1, 30)
  local cell
  for index = 1, #world.cell.owner do
    if world.cell.owner[index] == 1 then cell = index break end
  end
  local water
  for index = 1, #world.field.height do
    if world.field.height[index] < world.field.water_line then water = index break end
  end
  harness.check("the lines are a catalogue, not a composition", type(factories.LINES) == "table"
                and factories.LINES.tanks ~= nil)
  local refusal = commands.queue(world, {verb = "place-factory", tick = 1, team = 1, cell = cell,
                                         domain = "land", line = "tanks",
                                         pattern = {{cell = cell}, {cell = water}}})
  harness.check("a land pattern through water is refused, naming the point",
                type(refusal) == "string" and refusal:find("2", 1, true) ~= nil, refusal)
  refusal = commands.queue(world, {verb = "place-factory", tick = 1, team = 1, cell = cell,
                                   domain = "land", line = "tanks",
                                   pattern = {{cell = cell + 1}, {cell = cell + 2}}})
  harness.check("a pattern not starting at the factory is refused", type(refusal) == "string", refusal)
  local id = factories.place(world, 1, cell, "land", "tanks", {{cell = cell}, {cell = cell + 2}})
  harness.check("a factory holds its line's queue", world.factory.line[id] == "tanks")
  local ok = pcall(factories.redraw, world, id, {{cell = cell}})
  harness.check("there is no way to redraw a pattern", not ok)
  factories.stop(world, id)
  harness.check("a stopped line does not produce", world.factory.running[id] == 0)
  harness.check("a stopped line keeps its pattern", world.factory.pattern[id] ~= 0)
end)
-- }}}

-- {{{ losing ground
harness.suite("losing a fraction of ground hurts the same fraction of the roster", function()
  local roster = harness.load("roster", "309")
  local world = fresh()
  roster.add(world, 1, "builder", 100)
  roster.add(world, 1, "engineer", 25)
  roster.hurt(world, 1, 0.04)
  harness.check("four percent lost is four builders hurt", roster.hurt_count(world, 1, "builder") == 4)
  harness.check("and one engineer", roster.hurt_count(world, 1, "engineer") == 1)
  local first = roster.hurt_ids(world, 1)
  local other = fresh()
  roster.add(other, 1, "builder", 100)
  roster.add(other, 1, "engineer", 25)
  roster.hurt(other, 1, 0.04)
  harness.check("which ones are hurt is decided by the named stream, so it repeats",
                harness.same_numbers(first, roster.hurt_ids(other, 1)))
end)
-- }}}

-- {{{ thorns
harness.suite("thorns hurt the taker per percent and are spent by it", function()
  local thorns = harness.load("thorns", "310")
  local units = harness.load("units", "201")
  local timers = harness.load("timers", "106")
  local catalogue = harness.load_asset("unit-catalogue", "202")
  local world = fresh()
  own_cells(world, 1, 100)
  thorns.build(world, 1, 100)
  harness.check("the capacity is held by the team", world.team.thorns[1] == 100)
  local taker = units.spawn(world, "tank", 2, 0, 0)
  local health_before = timers.read(world.unit.health[taker], world.unit.health_at[taker],
                                    world.heal.tank, catalogue.tank.health)
  world.flip.count = 1
  world.flip.cell[1] = 1
  world.flip.from[1] = 1
  world.flip.to[1] = 2
  world.flip.by[1] = taker
  thorns.spend_pass(world)
  local health_after = timers.read(world.unit.health[taker], world.unit.health_at[taker],
                                   world.heal.tank, catalogue.tank.health)
  harness.check("the taker was hurt", health_after < health_before)
  harness.check("the capacity was spent", world.team.thorns[1] < 100)
end)
-- }}}

-- {{{ improving territory
harness.suite("improving territory raises what a cell pays", function()
  local economy = harness.load("economy", "311")
  local world = fresh()
  own_cells(world, 1, 10)
  local cell
  for index = 1, #world.cell.owner do
    if world.cell.owner[index] == 1 then cell = index break end
  end
  world.team.mass[1] = 1000
  world.team.energy[1] = 1000
  local pay_before = economy.cell_pays(world, cell)
  economy.improve(world, 1, cell)
  harness.check("an improvement costs both resources", world.team.mass[1] < 1000 and world.team.energy[1] < 1000)
  harness.check("an improved cell pays more", economy.cell_pays(world, cell) > pay_before)
  world.cell.owner[cell] = 2
  economy.consequences_pass(world)
  harness.check("the improvement is lost with the cell", world.cell.improvement[cell] == 0)
end)
-- }}}

harness.finish()
