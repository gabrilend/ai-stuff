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

-- 024-watching-it-happen.lua
--
-- covers: 601, 603, 605, 607
--
-- Phase 6: a lens push holds its anchor, the viewer reads snapshots only, a
-- drawn pattern becomes one command.
--
-- Most of this phase is pixels, and pixels are looked at rather than asserted.
-- What can be asserted without a window is the arithmetic under it -- the lens
-- -- and the two rules that keep the viewer honest: it reads a copy, and every
-- input it collects leaves as exactly one command through the door.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local harness = loadfile(ROOT .. "/tests/018-the-harness.lua")()
harness.start({...}, "024-watching-it-happen")

local SEED = harness.seed()
local FIELD = {size = 64, dune_height = 20, dune_wavelength = 16, roughness = 0.4,
               water_line = 4, hydrocarbon_rate = 0.02}

-- {{{ the lens
harness.suite("a lens push keeps the point under the cursor fixed", function()
  local lenses = harness.load("lenses", "603")
  local streams = harness.load("random-streams", "107")
  local stream = streams.open(SEED, "lens-test")
  local held = true
  local worst = 0
  for _ = 1, 200 do
    local lens = lenses.new({layer = "dunes", x = streams.next_double(stream) * 64,
                             y = streams.next_double(stream) * 64,
                             zoom = 0.5 + streams.next_double(stream) * 4,
                             left = 0, top = 0, width = 800, height = 600})
    local sx = streams.next_double(stream) * 800
    local sy = streams.next_double(stream) * 600
    local fx, fy = lenses.to_field(lens, sx, sy)
    lenses.push(lens, sx, sy, 0.5 + streams.next_double(stream) * 3)
    local fx2, fy2 = lenses.to_field(lens, sx, sy)
    local drift = math.max(math.abs(fx - fx2), math.abs(fy - fy2))
    if drift > 0.0001 then held = false end
    if drift > worst then worst = drift end
  end
  harness.check("two hundred random pushes never moved the anchored point", held, "worst drift " .. worst)
  local lens = lenses.new({layer = "dunes", x = 10, y = 10, zoom = 2,
                           left = 0, top = 0, width = 800, height = 600})
  local sx, sy = lenses.to_screen(lens, 10, 10)
  local fx, fy = lenses.to_field(lens, sx, sy)
  harness.check("to_screen and to_field are inverses", math.abs(fx - 10) < 0.0001 and math.abs(fy - 10) < 0.0001)
  local ok = pcall(lenses.new, {layer = "no-such-layer", x = 0, y = 0, zoom = 1,
                                left = 0, top = 0, width = 10, height = 10})
  harness.check("an unknown layer is refused", not ok)
end)
-- }}}

-- {{{ the viewer reads a copy
harness.suite("the viewer reads snapshots and never the live world", function()
  local viewer = harness.load("the-viewer", "601")
  local snapshot = harness.load("snapshot", "109")
  local the_world = harness.load("the-world", "104")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
  local copy = snapshot.copy(world)
  local hash_before = snapshot.hash(world)
  viewer.take(copy)
  viewer.layout(800, 600)
  harness.check("taking a snapshot did not touch the live world", snapshot.hash(world) == hash_before)
  harness.check("the viewer holds the snapshot it was given", viewer.current() == copy)
  harness.check("the viewer has no reference to the live world", viewer.world == nil)
end)
-- }}}

-- {{{ drawing in the sand
harness.suite("a drawn pattern leaves as exactly one placement command", function()
  local drawing = harness.load("the-viewer", "605")
  local queue = {}
  drawing.begin_pattern({team = 1, domain = "land", line = "tanks", cell = 100})
  drawing.add_point(101)
  drawing.add_point(102)
  drawing.add_point(103)
  local issued = drawing.finish_pattern(function(command) queue[#queue + 1] = command end)
  harness.check("one command was issued", #queue == 1)
  harness.check("it is a placement", queue[1].verb == "place-factory")
  harness.check("it carries every point, starting at the factory",
                #queue[1].pattern == 4 and queue[1].pattern[1].cell == 100)
  harness.check("finishing returns the command too", issued == queue[1])
end)
-- }}}

-- {{{ the compass wheel
harness.suite("the compass wheel issues one launch with a heading", function()
  local wheel = harness.load("the-viewer", "607")
  local queue = {}
  wheel.begin_wheel({team = 1, truck = 7})
  wheel.point_wheel(1, 0)
  local issued = wheel.finish_wheel(function(command) queue[#queue + 1] = command end)
  harness.check("one command was issued", #queue == 1)
  harness.check("it is a launch", queue[1].verb == "launch-plane")
  harness.check("east is a heading of zero degrees", queue[1].heading == 0)
  harness.check("the truck is named", queue[1].truck == 7)
end)
-- }}}

harness.finish()
