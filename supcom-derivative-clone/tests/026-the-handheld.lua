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

-- 026-the-handheld.lua
--
-- covers: 801, 805
--
-- Phase 8: every system in the tick is a pure function that writes only its
-- slice.
--
-- The handheld's runtime runs boxes: functions that take inputs, return a value,
-- and remember nothing. This program asserts, on the Lua, the two properties a
-- system must already have before it can be transcribed into a box -- so the
-- port is checked before it is begun. 802 through 804 and 806 are looked at on a
-- device and are not claimed here.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local harness = loadfile(ROOT .. "/tests/018-the-harness.lua")()
harness.start({...}, "026-the-handheld")

local SEED = harness.seed()
local FIELD = {size = 32, dune_height = 20, dune_wavelength = 16, roughness = 0.4,
               water_line = 4, hydrocarbon_rate = 0.02}

-- {{{ pure systems
harness.suite("every system in the tick is a pure function of the world", function()
  local the_tick = harness.load("the-tick", "801")
  local the_world = harness.load("the-world", "104")
  local snapshot = harness.load("snapshot", "109")
  local commands = harness.load("commands", "108")
  local units = harness.load("units", "201")
  local function populated()
    local world = the_world.allocate({field = FIELD, units = 64, teams = 2, seed = SEED})
    units.spawn(world, "tank", 1, 3, 3)
    units.spawn(world, "tank", 2, 20, 20)
    units.spawn(world, "helicopter", 1, 5, 5)
    commands.queue(world, {verb = "set-energy-level", tick = 3, team = 1, level = 2})
    for _ = 1, 40 do the_tick.advance(world) end
    return world
  end
  for _, row in ipairs(the_tick.SYSTEMS) do
    local a = populated()
    local b = populated()
    row.run(a)
    row.run(b)
    harness.check("'" .. row.name .. "' run on two equal worlds leaves two equal worlds",
                  snapshot.hash(a) == snapshot.hash(b))
    local c = populated()
    local before = snapshot.hash(c)
    row.run(c)
    local first = snapshot.hash(c)
    local d = populated()
    row.run(d)
    row.run(d)
    harness.check("'" .. row.name .. "' has no memory between calls: a second call on a copy is the same call",
                  snapshot.hash(d) ~= before or first == before)
  end
end)
-- }}}

-- {{{ slices
harness.suite("a sliceable system writes only its own slice", function()
  local the_tick = harness.load("the-tick", "801")
  local the_world = harness.load("the-world", "104")
  local units = harness.load("units", "201")
  local pool = harness.load("thread-pool", "209")
  for _, row in ipairs(the_tick.SYSTEMS) do
    if row.sliceable then
      local world = the_world.allocate({field = FIELD, units = 64, teams = 2, seed = SEED})
      for index = 1, 16 do units.spawn(world, "tank", (index % 2) + 1, index, index) end
      local touched = pool.trace_writes(function() row.run_slice(world, 5, 8) end, world)
      local outside = {}
      for _, write in ipairs(touched) do
        if write.array == "unit" and (write.index < 5 or write.index > 8) then
          outside[#outside + 1] = write.field .. "[" .. write.index .. "]"
        end
      end
      harness.check("'" .. row.name .. "' on slice 5..8 wrote nowhere else", #outside == 0,
                    table.concat(outside, ", "))
    end
  end
end)
-- }}}

-- {{{ the map file
harness.suite("the map file wires the systems in the tick's order", function()
  local the_tick = harness.load("the-tick", "801")
  local boxes = harness.load("box-map", "805")
  local map = boxes.describe(the_tick.SYSTEMS)
  harness.check("one station per system", #map.stations == #the_tick.SYSTEMS)
  local in_order = true
  for index, station in ipairs(map.stations) do
    if station.name ~= the_tick.SYSTEMS[index].name then in_order = false end
  end
  harness.check("in the same order", in_order)
  harness.check("every station names the C file its box lives in",
                map.stations[1].box ~= nil and map.stations[1].box:match("%.c:") ~= nil)
  local text = boxes.write(map)
  harness.check("the map is written as station lines with both ends of every wire",
                type(text) == "string" and text:find("^station ") ~= nil
                and text:find("\n  out 0 %- ") ~= nil and text:find("\n  in 0 %- ") ~= nil)
end)
-- }}}

harness.finish()
