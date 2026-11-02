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

-- 038-terminal-viewer.lua
--
-- Draws a snapshot as text.
--
-- The first viewer, so from the first tick nobody works blind and a failing test
-- can print what it saw. It runs where a window cannot -- over a wire, in a log,
-- in a failure message -- and stays useful after the window exists.
--
-- **The viewer rule starts here.** This file reads a snapshot and nothing else:
-- it holds no reference to the live world, loads no simulation module, calls no
-- simulation function, and issues no commands. Everything it shows it works out
-- from the snapshot's own arrays.

local M = {}

-- {{{ the grading
-- Land is graded by how far above the water line it stands, as a share of the
-- way from the water line to the field's highest cell: a cell takes the
-- character of the last row whose `from` it reaches. Water is its own mark.
M.GRADES = {
  {from = 0.00, mark = "."},
  {from = 0.12, mark = ":"},
  {from = 0.25, mark = "-"},
  {from = 0.37, mark = "="},
  {from = 0.50, mark = "+"},
  {from = 0.62, mark = "*"},
  {from = 0.75, mark = "#"},
  {from = 0.87, mark = "@"},
}
M.WATER = "~"
-- }}}

-- {{{ the unit letters
-- One letter per kind of unit, indexed by the kind's `index` in the unit
-- catalogue (issue 202): tank, anti-air gun, helicopter, frigate, command truck,
-- enforcer. The viewer loads no simulation module, so the order is written here
-- and phase 2's tests hold it to the catalogue's. A unit of a kind with no letter
-- -- a row nobody filled, a kind added without one -- is drawn as UNKNOWN, so it
-- shows up loudly rather than as ground.
M.LETTERS = {"T", "A", "H", "F", "C", "E"}
M.UNKNOWN = "?"
-- }}}

-- {{{ the team colours
-- The terminal colour codes a team's owned cells are tinted with when the
-- caller asks for colour, by team number; the reset code ends every tint.
M.COLOURS = {"\27[34m", "\27[31m"}
M.RESET = "\27[0m"
-- }}}

-- {{{ local function grade()
-- The mark for a land cell, from its share of the height above the water.
local function grade(share)
  local mark = M.GRADES[1].mark
  for _, row in ipairs(M.GRADES) do
    if share >= row.from then
      mark = row.mark
    end
  end
  return mark
end
-- }}}

-- {{{ local function units_by_cell()
-- Which cell each live unit stands in, as a table from cell index to the letter
-- drawn there. Units are walked in array order and a later unit in the same cell
-- draws over an earlier one, so the picture is the same every time.
local function units_by_cell(snapshot)
  local field = snapshot.field
  local unit = snapshot.unit
  local marks = {}
  for id = 1, unit.top do
    if unit.alive[id] == 1 then
      local cx = math.floor(unit.x[id] + 0.5)
      local cy = math.floor(unit.y[id] + 0.5)
      if cx < 0 then cx = 0 elseif cx > field.size - 1 then cx = field.size - 1 end
      if cy < 0 then cy = 0 elseif cy > field.size - 1 then cy = field.size - 1 end
      marks[cy * field.size + cx + 1] = M.LETTERS[unit.kind[id]] or M.UNKNOWN
    end
  end
  return marks
end
-- }}}

-- {{{ function M.draw()
-- The snapshot as one string: one line per row of the field, top row first, one
-- character per cell -- a unit's letter where a live unit stands, the water mark
-- below the water line, the land's grade otherwise -- then the legend. With
-- `options.colour` set, an owned cell is tinted in its team's colour.
function M.draw(snapshot, options)
  local colour = options ~= nil and options.colour == true
  local field = snapshot.field
  local size = field.size
  local height = field.height
  local water = field.water_line
  local owner = snapshot.cell.owner

  local top = water
  for index = 1, size * size do
    if height[index] > top then top = height[index] end
  end
  local span = top - water
  local marks = units_by_cell(snapshot)

  local land, owned = 0, {}
  local lines = {}
  for y = 0, size - 1 do
    local row = {}
    for x = 0, size - 1 do
      local index = y * size + x + 1
      local h = height[index]
      local mark
      if marks[index] ~= nil then
        mark = marks[index]
      elseif h < water then
        mark = M.WATER
      else
        mark = grade(span > 0 and (h - water) / span or 0)
      end
      if h >= water then
        land = land + 1
        local team = owner[index]
        -- An owned land cell counts toward its team, and is tinted if asked.
        if team ~= 0 then
          owned[team] = (owned[team] or 0) + 1
          if colour and M.COLOURS[team] ~= nil then
            mark = M.COLOURS[team] .. mark .. M.RESET
          end
        end
      end
      row[#row + 1] = mark
    end
    lines[#lines + 1] = table.concat(row)
  end

  lines[#lines + 1] = string.format("tick %d", snapshot.tick)
  local shares = {}
  for team = 1, snapshot.team.capacity do
    shares[#shares + 1] = string.format("team %d holds %.1f%% of the land", team,
                                        land > 0 and 100 * (owned[team] or 0) / land or 0)
  end
  lines[#lines + 1] = table.concat(shares, ", ")
  lines[#lines + 1] = string.format("%d units alive, %d commands waiting, %d refusals kept",
                                    snapshot.unit.count, snapshot.command.count,
                                    snapshot.refusal.count)
  return table.concat(lines, "\n") .. "\n"
end
-- }}}

return M
