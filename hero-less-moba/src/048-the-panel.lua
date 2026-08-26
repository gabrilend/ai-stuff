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

-- 048-the-panel.lua
--
-- The board down the side of the screen: what the team holds, where it is
-- sitting, and everything the game has refused to do.
--
-- ## What the panel is for, in order
--
-- The screen's job, roughly in order of how much a player looks at it, is: the
-- three lanes and where the frontlines are; the chest; the slots; the phase; and
-- the refusals. The lanes are the map's job. Everything else is this file's.
--
-- **An upgrade doing nothing should be visually annoying.** Unplaced upgrades are
-- drawn large, bright, and at the top, because an upgrade in the chest is a
-- decision nobody has made yet and the interface should say so. The moment it is
-- placed it becomes a small mark in a lane row -- quieter, because now it is
-- working.
--
-- ## One team's board and never the other's
--
-- The panel draws the viewing player's team. On a networked match the enemy's
-- chest is not on the machine at all: you know roughly *what* they hold, because
-- the deck is shared, and you learn *where they put it* by looking at what walks
-- at you. There is no fog-of-war system to build here -- only something not to
-- accidentally reveal.
--
-- The prototype lets you switch which team you are watching, which is a thing a
-- real match would never offer. It is a development affordance and it is marked
-- as one on screen, so that nobody mistakes it for a feature.
--
-- ## Every refusal is loud
--
-- A command that silently does nothing is the worst outcome available: the player
-- believes the game has their instruction and it does not. Refusals arrive at the
-- bottom of the panel, in the colour of a warning, and stay long enough to read.

local M = {}

local WIDTH = 340
local PAD = 14

-- How long a refusal stays on screen, in seconds. Long enough to read a sentence
-- without looking away from the lane you were watching.
local REFUSAL_LIFETIME = 6.0

-- {{{ function M.load()
function M.load(renderer)
  M.renderer = renderer
  M.font       = love.graphics.newFont(13)
  M.font_small = love.graphics.newFont(11)
  M.font_big   = love.graphics.newFont(17)
  -- Where everything was drawn last frame, so that input can ask what is under
  -- the cursor without recomputing a layout that the drawing already worked out.
  -- One layout, two readers, no chance of them disagreeing about where a chip is.
  M.hot = {}
  M.refusal = {}
end
-- }}}

-- {{{ function M.note_refusal()
function M.note_refusal(text)
  table.insert(M.refusal, 1, {text = text, born = love.timer.getTime()})
  -- Only the last handful are kept. A refusal older than the ones below it has
  -- already been read or already been missed.
  while #M.refusal > 5 do
    table.remove(M.refusal)
  end
end
-- }}}

-- {{{ local function set_colour()
local function set_colour(rgb, alpha)
  love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha or 1)
end
-- }}}

-- {{{ local function add_hot()
-- Records a rectangle and what it means, for input to hit-test against.
local function add_hot(kind, rect, detail)
  detail = detail or {}
  detail.kind = kind
  detail.x, detail.y, detail.w, detail.h = rect[1], rect[2], rect[3], rect[4]
  M.hot[#M.hot + 1] = detail
end
-- }}}

-- {{{ function M.hit_test()
-- What is under a screen point. Walked backwards so that whatever was drawn last
-- -- and is therefore on top -- is what answers.
function M.hit_test(x, y)
  for index = #M.hot, 1, -1 do
    local hot = M.hot[index]
    if x >= hot.x and x <= hot.x + hot.w and y >= hot.y and y <= hot.y + hot.h then
      return hot
    end
  end
  return nil
end
-- }}}

-- {{{ local function draw_chip()
-- One upgrade, as a coloured block with its glyph and a count.
local function draw_chip(kinds, kind, count, x, y, size, bright)
  local row = kinds[kind]
  set_colour(row.colour, bright and 1 or 0.42)
  love.graphics.rectangle("fill", x, y, size, size, 3, 3)
  love.graphics.setColor(0.06, 0.07, 0.09, bright and 0.92 or 0.6)
  love.graphics.setFont(M.font)
  love.graphics.printf(row.glyph, x, y + size * 0.5 - 9, size, "center")

  if count > 1 then
    love.graphics.setColor(0.06, 0.07, 0.09, 0.85)
    love.graphics.rectangle("fill", x + size - 15, y + size - 13, 15, 13, 2, 2)
    love.graphics.setColor(0.95, 0.95, 0.97, 1)
    love.graphics.setFont(M.font_small)
    love.graphics.printf(tostring(count), x + size - 15, y + size - 12, 15, "center")
  end
end
-- }}}

-- {{{ local function draw_chest()
-- The unplaced upgrades. Loud on purpose.
local function draw_chest(world, frame, team_id, x, y, width)
  local kinds = world.parameters.upgrade.kind
  local view = frame.team_view[team_id]

  local total = 0
  for kind = 1, #kinds do
    total = total + view.chest[kind]
  end

  love.graphics.setFont(M.font)
  set_colour(M.renderer.COLOUR.text, 0.65)
  love.graphics.print("CHEST", x, y)
  if total > 0 then
    -- The count is drawn in the team's own colour and grows in weight with the
    -- pile, because a chest nobody is emptying is the single most common way a
    -- team throws a match it was winning.
    set_colour(M.renderer.COLOUR.team[team_id])
    love.graphics.setFont(M.font_big)
    love.graphics.printf(tostring(total) .. " unplaced", x, y - 3, width, "right")
  else
    set_colour(M.renderer.COLOUR.text, 0.3)
    love.graphics.setFont(M.font_small)
    love.graphics.printf("empty", x, y + 2, width, "right")
  end

  y = y + 24
  local size = 40
  local gap = 6
  local column = 0
  local per_row = math.floor((width + gap) / (size + gap))

  for kind = 1, #kinds do
    local held = view.chest[kind]
    if held > 0 then
      local chip_x = x + column * (size + gap)
      draw_chip(kinds, kind, held, chip_x, y, size, true)
      add_hot("chest_chip", {chip_x, y, size, size}, {kind = kind, upgrade = kind})
      column = column + 1
      if column >= per_row then
        column = 0
        y = y + size + gap
      end
    end
  end
  if column > 0 then
    y = y + size + gap
  end

  return y
end
-- }}}

-- {{{ local function draw_lane_row()
-- One lane: its pressure, what is stamped into its bodies, and what is slotted
-- into its stone. The two slots are separate drop targets, because they are
-- genuinely different purchases.
--
-- Stone and soldiers are not symmetric investments and the panel should not
-- pretend they are. A lane upgrade makes every body you spawn into that lane
-- stronger, and the enemy reduces its value by killing those bodies faster than
-- you make them. A stone upgrade makes your towers stronger and there is no play
-- the enemy can make that reduces its value at all -- the only thing in the whole
-- game that can dislodge it is a siege-surge.
local function draw_lane_row(world, frame, team_id, lane, x, y, width)
  local kinds = world.parameters.upgrade.kind
  local view = frame.team_view[team_id]
  local other = (team_id == 1) and 2 or 1
  local names = {"TOP", "CENTRE", "BOTTOM"}
  local height = 62

  love.graphics.setColor(0.10, 0.11, 0.135, 0.9)
  love.graphics.rectangle("fill", x, y, width, height, 4, 4)

  love.graphics.setFont(M.font_small)
  set_colour(M.renderer.COLOUR.text, 0.75)
  love.graphics.print(names[lane] or ("LANE " .. lane), x + 8, y + 6)
  if lane == 2 then
    set_colour(M.renderer.COLOUR.text, 0.35)
    love.graphics.print("wide", x + 62, y + 6)
  end

  -- The pressure read, as nine cells from this team's end to the enemy's.
  local mine   = view.push_depth[lane]
  local theirs = frame.team_view[other].push_depth[lane]
  local cell = 15
  local track_x = x + width - 8 - cell * 9
  for m = 0, 8 do
    local cx = track_x + m * cell
    love.graphics.setColor(0.16, 0.17, 0.20, 1)
    love.graphics.rectangle("fill", cx, y + 5, cell - 2, 11, 2, 2)
    if m <= mine then
      set_colour(M.renderer.COLOUR.team[team_id], 0.9)
      love.graphics.rectangle("fill", cx, y + 5, cell - 2, 11, 2, 2)
    end
    if (8 - m) <= theirs then
      set_colour(M.renderer.COLOUR.team[other], 0.9)
      love.graphics.rectangle("fill", cx, y + 5, cell - 2, 11, 2, 2)
    end
  end

  -- The two slots.
  local slot_y = y + 24
  local slot_w = (width - 24) * 0.5
  local labels = {"bodies", "stone"}
  local sources = {view.lane_slot[lane], view.tower_slot[lane]}
  local drops   = {"place_in_lane", "place_in_stone"}

  for half = 1, 2 do
    local slot_x = x + 8 + (half - 1) * (slot_w + 8)
    love.graphics.setColor(0.07, 0.08, 0.10, 0.85)
    love.graphics.rectangle("fill", slot_x, slot_y, slot_w, 30, 3, 3)

    set_colour(M.renderer.COLOUR.text, 0.35)
    love.graphics.setFont(M.font_small)
    love.graphics.print(labels[half], slot_x + 4, slot_y + 17)

    local pip_x = slot_x + 4
    for kind = 1, #kinds do
      local held = sources[half][kind]
      if held > 0 then
        set_colour(kinds[kind].colour)
        love.graphics.rectangle("fill", pip_x, slot_y + 4, 9, 9, 2, 2)
        if held > 1 then
          set_colour(M.renderer.COLOUR.text, 0.8)
          love.graphics.print(tostring(held), pip_x + 10, slot_y + 2)
          pip_x = pip_x + 9
        end
        pip_x = pip_x + 11
        add_hot("slot_pip", {pip_x - 11, slot_y + 4, 9, 9},
                {upgrade = kind, lane = lane,
                 from = (half == 1) and "lane" or "stone"})
      end
    end

    add_hot("drop", {slot_x, slot_y, slot_w, 30},
            {verb = drops[half], lane = lane})
  end

  return y + height + 6
end
-- }}}

-- {{{ local function draw_refusals()
local function draw_refusals(x, y, width)
  local now = love.timer.getTime()
  for index = #M.refusal, 1, -1 do
    if now - M.refusal[index].born > REFUSAL_LIFETIME then
      table.remove(M.refusal, index)
    end
  end

  love.graphics.setFont(M.font_small)
  for index, refusal in ipairs(M.refusal) do
    local age = (now - refusal.born) / REFUSAL_LIFETIME
    love.graphics.setColor(0.92, 0.45, 0.35, 1 - age * 0.75)
    love.graphics.printf(refusal.text, x, y + (index - 1) * 15, width, "left")
  end
end
-- }}}

-- {{{ function M.draw()
-- The whole panel. Rebuilds the hot-region list as it goes.
function M.draw(world, camera, frame, team_id, held_kind, mouse_x, mouse_y, speed, paused)
  for index = #M.hot, 1, -1 do
    M.hot[index] = nil
  end

  local screen_w = love.graphics.getWidth()
  local screen_h = love.graphics.getHeight()
  local x = screen_w - WIDTH

  love.graphics.setColor(0.045, 0.050, 0.062, 0.96)
  love.graphics.rectangle("fill", x, 0, WIDTH, screen_h)
  love.graphics.setColor(0.16, 0.17, 0.20, 1)
  love.graphics.setLineWidth(1)
  love.graphics.line(x, 0, x, screen_h)

  local inner_x = x + PAD
  local inner_w = WIDTH - PAD * 2
  local y = PAD

  -- The clock and the phase.
  local seconds = frame.tick / world.parameters.unit.ticks_per_second
  love.graphics.setFont(M.font_big)
  set_colour(M.renderer.COLOUR.text)
  love.graphics.print(string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60)),
                      inner_x, y)
  love.graphics.setFont(M.font_small)
  set_colour(M.renderer.COLOUR.text, 0.45)
  love.graphics.printf(paused and "PAUSED" or string.format("x%d", speed),
                       inner_x, y + 5, inner_w, "right")
  y = y + 30

  -- Which team's board this is. Marked as a prototype affordance rather than
  -- offered as a feature -- a real match cannot show you the other side's chest,
  -- because it is not on this machine.
  set_colour(M.renderer.COLOUR.team[team_id])
  love.graphics.setFont(M.font)
  love.graphics.print("TEAM " .. team_id, inner_x, y)
  set_colour(M.renderer.COLOUR.text, 0.3)
  love.graphics.setFont(M.font_small)
  love.graphics.printf("tab switches -- prototype only", inner_x, y + 2, inner_w, "right")
  y = y + 24

  y = draw_chest(world, frame, team_id, inner_x, y, inner_w)
  y = y + 8

  for lane = 1, world.parameters.lane_count do
    y = draw_lane_row(world, frame, team_id, lane, inner_x, y, inner_w)
  end

  -- What the deck has paid out, which is the number that says whether the upgrade
  -- economy is doing anything at all.
  y = y + 6
  set_colour(M.renderer.COLOUR.text, 0.4)
  love.graphics.setFont(M.font_small)
  love.graphics.print(string.format("%d drawn this match", frame.team_view[team_id].draws_taken),
                      inner_x, y)
  y = y + 22

  draw_refusals(inner_x, screen_h - 96, inner_w)

  -- The help line, bottom left of the whole screen rather than in the panel,
  -- because it is about the map and not about the board.
  set_colour(M.renderer.COLOUR.text, 0.30)
  love.graphics.setFont(M.font_small)
  love.graphics.print(
    "wheel zooms to cursor  --  right-drag pans  --  HOME or SPACE frames the map  --  " ..
    "drag an upgrade onto a lane or a tower  --  P pauses  --  1/2/3 speed",
    PAD, screen_h - 22)

  -- The zoom indicator. Small, and only interesting while it is not at rest.
  local fraction = M.renderer.camera_module.zoom_fraction(camera)
  if fraction > 0.01 then
    local bar_w = 120
    love.graphics.setColor(0.16, 0.17, 0.20, 0.9)
    love.graphics.rectangle("fill", PAD, screen_h - 44, bar_w, 5, 2, 2)
    set_colour(M.renderer.COLOUR.text, 0.6)
    love.graphics.rectangle("fill", PAD, screen_h - 44, bar_w * fraction, 5, 2, 2)
    love.graphics.setFont(M.font_small)
    set_colour(M.renderer.COLOUR.text, 0.4)
    love.graphics.print(string.format("%.1fx", camera.drawn_scale / camera.rest_scale),
                        PAD + bar_w + 8, screen_h - 49)
  end

  -- The upgrade being dragged, riding the cursor. Drawn last so it is over
  -- everything, including the panel it came from.
  if held_kind ~= 0 then
    draw_chip(world.parameters.upgrade.kind, held_kind, 1,
              mouse_x - 20, mouse_y - 20, 40, true)
  end
end
-- }}}

-- {{{ function M.panel_left()
-- Where the panel starts, so that the viewer knows which clicks belong to the
-- map and which to the board.
function M.panel_left()
  return love.graphics.getWidth() - WIDTH
end
-- }}}

return M
