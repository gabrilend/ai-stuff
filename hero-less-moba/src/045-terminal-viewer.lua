-- hero-less-moba — a lane-pushing game with the heroes subtracted out
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

-- 045-terminal-viewer.lua
--
-- The world as text.
--
-- This is not a stepping stone to be discarded once there is a real window. It is
-- kept, permanently, for four reasons: it is faster to debug in, it works over a
-- connection where nothing graphical does, its output can be piped to a file and
-- diffed against yesterday's, and -- the one that matters most -- it keeps the
-- viewing layer honest by existing as a **second consumer of the same snapshots.**
--
-- Two viewers means neither one can quietly become part of the simulation. The
-- moment somebody moves a decision into the graphical viewer, this one starts
-- disagreeing with it, and the disagreement is the alarm.
--
-- It reads snapshots. It writes nothing. Exactly like the other one.

local M = {}

-- What a body is drawn as. Indexed by flavour, then by team, so that the two
-- sides are distinguishable in a medium with no colour worth relying on.
local BODY = {
  [1] = {"o", "x"},   -- wave unit
  [2] = {"H", "X"},   -- hero
  [3] = {"g", "q"},   -- guard
  [4] = {"M", "M"},   -- challenge monster, on nobody's team
}

-- {{{ local function blank_canvas()
local function blank_canvas(width, height)
  local canvas = {}
  for row = 1, height do
    canvas[row] = {}
    for column = 1, width do
      canvas[row][column] = " "
    end
  end
  return canvas
end
-- }}}

-- {{{ local function plot()
-- Puts a character at a world position, if it lands on the canvas.
--
-- Later plots win. The order the caller draws in is therefore the layering, and
-- the caller draws ground first, then stone, then bodies -- so a soldier standing
-- on a tower is visible as a soldier, which is the thing that is about to change.
local function plot(canvas, bounds, width, height, x, y, character)
  local column = math.floor((x - bounds.min_x) / (bounds.max_x - bounds.min_x) * (width - 1)) + 1
  local row    = math.floor((y - bounds.min_y) / (bounds.max_y - bounds.min_y) * (height - 1)) + 1
  if row >= 1 and row <= height and column >= 1 and column <= width then
    canvas[row][column] = character
  end
end
-- }}}

-- {{{ function M.draw_field()
-- The map and everything standing on it, as a block of text.
function M.draw_field(world, frame, width, height)
  width = width or 78
  height = height or 34
  local bounds = world.map.bounds
  local canvas = blank_canvas(width, height)

  -- The ground. Every node, so the three lanes and the two connectors are
  -- visible as the shape they are.
  for _, node in ipairs(world.map.node) do
    local mark = "."
    if node.lane == 0 and node.kind == 1 then
      -- A connector. Marked differently because it is the only ground in the
      -- game that belongs to no lane, and a reader who cannot tell it apart
      -- cannot see why the middle is a place a body can leave.
      mark = ","
    end
    plot(canvas, bounds, width, height, node.x, node.y, mark)
  end

  -- Stone. A felled tower is drawn as rubble rather than erased, because "there
  -- used to be a tower here" is information.
  for _, structure in ipairs(frame.structure) do
    local mark
    if structure.alive == 0 then
      mark = "_"
    elseif structure.kind == 3 then
      mark = (structure.team == 1) and "L" or "R"
    else
      mark = (structure.team == 1) and "T" or "Y"
    end
    plot(canvas, bounds, width, height, structure.x, structure.y, mark)
  end

  -- Bodies.
  for index = 1, frame.live_count do
    local id = frame.live[index]
    local row = BODY[frame.flavour[id]]
    if row ~= nil then
      local team = frame.team[id]
      plot(canvas, bounds, width, height, frame.x[id], frame.y[id],
           row[team] or row[1])
    end
  end

  local lines = {}
  for row = 1, height do
    lines[row] = table.concat(canvas[row])
  end
  return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.draw_lanes()
-- The lane-pressure read, as three bars.
--
-- This is the terminal's version of the primary question -- which lane am I
-- losing -- and it is drawn from push depth rather than from anything geometric,
-- because push depth is what the simulation actually runs on. A lane where the
-- enemy sits one pace past your first tower is in less trouble than one where
-- they are inside your base, even though the base is physically nearer.
function M.draw_lanes(world, frame)
  local lines = {}
  local lane_count = world.parameters.lane_count
  local names = {"top", "centre", "bottom"}

  for lane = 1, lane_count do
    local mine   = frame.team_view[1].push_depth[lane]
    local theirs = frame.team_view[2].push_depth[lane]

    -- One character per **zone**, read from team 1's end. Team 1's reach is drawn
    -- from the left, team 2's from the right, and the gap in the middle is the
    -- ground neither of them holds.
    --
    -- This was nine characters, one per milestone, and push depth is measured in
    -- zones now — four times finer. The text viewer takes all of them rather than
    -- scaling back the way the panel does: it is the viewer somebody opens when they
    -- want to see exactly what happened, and it has the width to spare.
    local track = {}
    local cells = frame.zone_count
    for m = 0, cells - 1 do
      local held = " "
      if m <= mine then held = "=" end
      if (cells - 1 - m) <= theirs then held = "#" end
      -- Ground both of them claim to have reached. It happens: push depth is the
      -- deepest a team has got, not a line, so two teams can each have a body past
      -- the other's deepest.
      if m <= mine and (cells - 1 - m) <= theirs then held = "*" end
      track[#track + 1] = held
    end

    lines[#lines + 1] = string.format("  %-7s |%s|  %d vs %d",
                                      names[lane] or ("lane " .. lane),
                                      table.concat(track), mine, theirs)
  end
  return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.draw_chest()
-- What one team holds and where it is sitting.
--
-- **One team's.** The enemy's chest is not drawn, ever, and on a networked match
-- it would not be in the frame at all. There is no fog-of-war system here -- only
-- something not to accidentally reveal.
function M.draw_chest(world, frame, team_id)
  local view = frame.team_view[team_id]
  local kinds = world.parameters.upgrade.kind
  local lines = {}

  local chest = {}
  for kind = 1, #kinds do
    if view.chest[kind] > 0 then
      chest[#chest + 1] = string.format("%s x%d", kinds[kind].name, view.chest[kind])
    end
  end
  lines[#lines + 1] = "  chest: " ..
    ((#chest > 0) and table.concat(chest, ", ") or "empty")

  for lane = 1, world.parameters.lane_count do
    local placed, stone = {}, {}
    for kind = 1, #kinds do
      if view.lane_slot[lane][kind] > 0 then
        placed[#placed + 1] = string.format("%s%d", kinds[kind].glyph, view.lane_slot[lane][kind])
      end
      if view.tower_slot[lane][kind] > 0 then
        stone[#stone + 1] = string.format("%s%d", kinds[kind].glyph, view.tower_slot[lane][kind])
      end
    end
    lines[#lines + 1] = string.format("  lane %d: bodies [%s]  stone [%s]",
      lane, table.concat(placed, " "), table.concat(stone, " "))
  end
  return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.draw()
-- The whole text view of one frame.
function M.draw(world, frame, team_id)
  local parts = {}
  parts[#parts + 1] = string.format(
    "tick %d  --  %.0f seconds  --  %d bodies",
    frame.tick, frame.tick / world.parameters.unit.ticks_per_second, frame.live_count)
  parts[#parts + 1] = M.draw_field(world, frame)
  parts[#parts + 1] = M.draw_lanes(world, frame)
  parts[#parts + 1] = string.format("team %d", team_id)
  parts[#parts + 1] = M.draw_chest(world, frame, team_id)
  return table.concat(parts, "\n")
end
-- }}}

return M
