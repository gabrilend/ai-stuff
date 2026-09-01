-- jurassic-maze — a simulation living inside an isometric maze of stacked stone
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

-- 046-the-terminal-viewer.lua
--
-- One layer of the maze as characters, held at a gate.
--
-- Not a lesser window. It exists for the case where a number says something is
-- wrong and you need to see *where*, over ssh, with no graphics -- and the window
-- is worse at that, because in the window you have to find the thing first.
--
-- It holds at a gate and advances only when told. A simulation you can hold still
-- is a simulation you can read.

local M = {}

-- {{{ local function require_local(root, name)
local function require_local(root, name)
  return dofile(root .. "/src/" .. name .. ".lua")
end
-- }}}

-- What a cell looks like at the layer being viewed. A slice through a stack of
-- stone shows three different things and they have to be told apart at a glance.
M.GLYPH = {
  stone   = "#",   -- solid at this layer, and buried
  surface = "-",   -- solid at this layer with air above: somewhere to stand
  air     = " ",   -- nothing here
  above   = ".",   -- air here, but stone somewhere above: you are under an arch
}

-- {{{ function M.slice(Stone, store, layer, x0, y0, w, h)
-- One horizontal slice, as an array of strings.
--
-- A function from a store and a layer to text, with no terminal anywhere in it,
-- so it can be tested against a picture written out by hand in the test file. A
-- rendering test whose expectation is a picture is a test somebody can read.
function M.slice(Stone, store, layer, x0, y0, w, h)
  local bit = require("bit")
  local rows = {}
  for y = y0, math.min(y0 + h - 1, store.depth - 1) do
    local chars = {}
    for x = x0, math.min(x0 + w - 1, store.width - 1) do
      local i = Stone.index(store, x, y)
      local here  = Stone.is_stone(store, i, layer)
      local above = bit.rshift(store.column[i], layer + 1) ~= 0
      if here and not above then
        chars[#chars + 1] = M.GLYPH.surface
      elseif here then
        chars[#chars + 1] = M.GLYPH.stone
      elseif above then
        chars[#chars + 1] = M.GLYPH.above
      else
        chars[#chars + 1] = M.GLYPH.air
      end
    end
    rows[#rows + 1] = table.concat(chars)
  end
  return rows
end
-- }}}

-- {{{ function M.overlay_bodies(rows, Stone, store, bodies, creatures, layer, x0, y0)
-- Bodies as letters, drawn over the slice, one letter per creature kind.
--
-- A second pass over the strings rather than a branch inside the first, so that
-- the slice stays a pure function of the stone and can be tested on its own.
function M.overlay_bodies(rows, Stone, store, bodies, creatures, layer, x0, y0)
  local marks = {}
  for id = 1, bodies.capacity do
    if bodies.alive[id] == 1 and bodies.layer[id] == layer then
      local x, y = Stone.coords(store, bodies.cell[id])
      local col = x - x0 + 1
      local row = y - y0 + 1
      if rows[row] and col >= 1 and col <= #rows[row] then
        marks[row] = marks[row] or {}
        local name = creatures.KINDS[bodies.kind[id]].name
        marks[row][col] = name:sub(1, 1):upper()
      end
    end
  end

  for row, cols in pairs(marks) do
    local chars = {}
    for k = 1, #rows[row] do chars[k] = rows[row]:sub(k, k) end
    for col, ch in pairs(cols) do chars[col] = ch end
    rows[row] = table.concat(chars)
  end
  return rows
end
-- }}}

-- {{{ function M.run(root, argv)
function M.run(root, argv)
  local Params    = require_local(root, "028-maze-parameters")
  local Stone     = require_local(root, "030-the-stone")
  local Tick      = require_local(root, "039-the-tick")
  local Report    = require_local(root, "048-the-report")
  local Runner    = require_local(root, "047-the-headless-runner")

  local opts = Runner.parse(argv)
  local world = Tick.new_world(root, Params.with(opts.overrides), opts.scene)

  local layer = world.highest
  local x0, y0 = 0, 0
  local w, h = 100, 40

  -- The commands, as a table rather than a chain of comparisons. Adding one is a
  -- row, and the help below is printed from the same table so it cannot drift
  -- from what the keys actually do.
  local COMMANDS = {}
  local order = {}
  local function command(key, what, fn)
    COMMANDS[key] = { what = what, fn = fn }
    order[#order + 1] = key
  end

  command("",    "one tick",                  function() Tick.tick(world) end)
  command("10",  "ten ticks",                 function() for _ = 1, 10 do Tick.tick(world) end end)
  command("100", "a hundred ticks",           function() for _ = 1, 100 do Tick.tick(world) end end)
  command("u",   "up one layer",              function() layer = math.min(world.store.layers - 1, layer + 1) end)
  command("d",   "down one layer",            function() layer = math.max(0, layer - 1) end)
  command("w",   "pan north",                 function() y0 = math.max(0, y0 - 10) end)
  command("s",   "pan south",                 function() y0 = math.min(world.store.depth - 1, y0 + 10) end)
  command("a",   "pan west",                  function() x0 = math.max(0, x0 - 10) end)
  command("f",   "pan east",                  function() x0 = math.min(world.store.width - 1, x0 + 10) end)
  command("b",   "follow the lowest body",    function()
    local best, bl = nil, 99
    for id = 1, world.bodies.capacity do
      if world.bodies.alive[id] == 1 and world.bodies.layer[id] < bl then
        bl, best = world.bodies.layer[id], id
      end
    end
    if best then
      local bx, by = Stone.coords(world.store, world.bodies.cell[best])
      layer = world.bodies.layer[best]
      x0 = math.max(0, bx - math.floor(w / 2))
      y0 = math.max(0, by - math.floor(h / 2))
    end
  end)
  command("r",   "the report so far",         function()
    print(Report.describe(Report.gather(world)))
  end)
  command("q",   "leave",                     function() end)

  print("")
  print("jurassic-maze, one layer at a time. Press return for a tick.")
  for _, key in ipairs(order) do
    print(string.format("  %-5s %s", key == "" and "<ret>" or key, COMMANDS[key].what))
  end

  while true do
    local rows = M.slice(Stone, world.store, layer, x0, y0, w, h)
    M.overlay_bodies(rows, Stone, world.store, world.bodies, world.creatures,
                     layer, x0, y0)

    print("")
    print(string.format("layer %d of %d   tick %d   %d bodies   at (%d, %d)   seed %d",
      layer, world.store.layers - 1, world.tick_count, world.bodies.live,
      x0, y0, world.params.seed))
    for _, row in ipairs(rows) do print(row) end
    io.write("> ")
    io.flush()

    local line = io.read()
    if line == nil or line == "q" then break end
    local cmd = COMMANDS[line]
    if cmd then
      cmd.fn()
    else
      print("no command '" .. line .. "'")
    end
  end

  Report.say_goodbye(root, Report.gather(world))
end
-- }}}

-- {{{ if invoked directly
-- Both a module and a program, for the same reason as the headless runner: there
-- is no spelling of `luajit -e` that survives a command line of its own.
if arg and arg[0] and arg[0]:find("046%-the%-terminal%-viewer") then
  local root = arg[1]
  if not root then
    print("046-the-terminal-viewer.lua needs the project root as its first argument")
    os.exit(1)
  end
  local argv = {}
  for i = 2, #arg do argv[#argv + 1] = arg[i] end
  M.run(root, argv)
end
-- }}}

return M
