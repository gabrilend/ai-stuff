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

-- {{{ local function draw_phase_banner()
-- What kind of match this is, right now, and how long until it stops being that.
--
-- Across the top, always, in the colour of the thing that is happening -- because a
-- surge and a challenge change every rule on the board at once, and a player who
-- has not noticed which one they are in is playing the wrong game. **Zoom reveals
-- detail, never events**, and a phase change is the largest event there is.
local function draw_phase_banner(world, frame, x, y, width)
  local names = {"", "SIEGE-SURGE", "CHALLENGE", "THE CALM", "OVER"}
  local phase = frame.phase

  if phase == 1 then
    -- Ordinary play says so quietly, and counts down to the thing that is not.
    local left = math.max(0, frame.phase_ends_at - frame.tick)
    set_colour(M.renderer.COLOUR.text, 0.35)
    love.graphics.setFont(M.font_small)
    love.graphics.printf(string.format("surge in %d:%02d",
      math.floor(left / 30 / 60), math.floor(left / 30) % 60), x, y, width, "left")
    return y + 16
  end

  local tint = {0.90, 0.55, 0.25}
  if phase == 3 then tint = {0.76, 0.52, 0.90} end
  if phase == 4 then tint = {0.50, 0.72, 0.62} end

  love.graphics.setColor(tint[1], tint[2], tint[3], 0.18)
  love.graphics.rectangle("fill", x - 6, y - 3, width + 12, 26, 3, 3)
  set_colour(tint)
  love.graphics.setFont(M.font)
  love.graphics.print(names[phase] or "", x, y + 2)

  love.graphics.setFont(M.font_small)
  if phase == 3 then
    local row = world.parameters.boon.challenge[frame.challenge_index]
    set_colour(tint, 0.8)
    love.graphics.printf(row and row.name or "", x, y + 4, width, "right")
  else
    local left = math.max(0, frame.phase_ends_at - frame.tick)
    set_colour(tint, 0.7)
    love.graphics.printf(string.format("%d:%02d",
      math.floor(left / 30 / 60), math.floor(left / 30) % 60), x, y + 4, width, "right")
  end
  return y + 30
end
-- }}}

-- {{{ local function draw_boon_offer()
-- Two boons, and a player picks one.
--
-- Drawn over everything else, because during a calm there is nothing else to do and
-- the choice is the whole of the phase. Two rather than three: a choice between two
-- is a decision and a choice between six is a menu.
local function draw_boon_offer(world, frame, x, y, width)
  if #frame.boon_offer == 0 then
    return y
  end
  local catalogue = world.parameters.boon.boon

  set_colour(M.renderer.COLOUR.text, 0.75)
  love.graphics.setFont(M.font)
  love.graphics.print("CHOOSE A BOON", x, y)
  -- It does not expire. Being slow costs you the use of it in the meantime and
  -- costs your team nothing, so there is no clock on this and nothing is taken for
  -- you if you look away.
  set_colour(M.renderer.COLOUR.text, 0.3)
  love.graphics.setFont(M.font_small)
  love.graphics.printf("no hurry", x, y + 2, width, "right")
  y = y + 20

  local height = 34
  for _, boon_id in ipairs(frame.boon_offer) do
    local row = catalogue[boon_id]
    love.graphics.setColor(row.colour[1], row.colour[2], row.colour[3], 0.22)
    love.graphics.rectangle("fill", x, y, width, height, 3, 3)
    set_colour(row.colour, 0.9)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, width, height, 3, 3)

    set_colour(row.colour)
    love.graphics.rectangle("fill", x + 6, y + 9, 16, 16, 2, 2)
    love.graphics.setColor(0.06, 0.07, 0.09, 0.9)
    love.graphics.setFont(M.font_small)
    love.graphics.printf(row.glyph, x + 6, y + 12, 16, "center")

    set_colour(M.renderer.COLOUR.text, 0.9)
    love.graphics.setFont(M.font)
    love.graphics.print(row.name, x + 30, y + 9)

    add_hot("boon", {x, y, width, height}, {boon = boon_id})
    y = y + height + 5
  end
  return y + 4
end
-- }}}

-- {{{ local function draw_colour_mark()
-- One resource colour, drawn as its own **shape** as well as its own hue.
--
-- Written down in the design as an accessibility requirement and worth reading as a
-- principle: **never encode meaning in hue alone.** Somebody who cannot tell the red
-- from the green can still tell pips from a card from a ring.
local function draw_colour_mark(shape, x, y, size, rgb)
  set_colour(rgb)
  if shape == "pips" then
    -- Three dots in a row, like a die's face.
    for index = 0, 2 do
      love.graphics.circle("fill", x + 3 + index * 5, y + size * 0.5, 1.8, 6)
    end
  elseif shape == "bar" then
    love.graphics.rectangle("fill", x + 2, y + size * 0.5 - 2, size - 4, 4, 1, 1)
  elseif shape == "script" then
    -- A stroke with a flick in it. Not a letter; a mark.
    love.graphics.setLineWidth(1.6)
    love.graphics.line(x + 3, y + size - 4, x + size * 0.5, y + 3, x + size - 3, y + size - 4)
  elseif shape == "card" then
    love.graphics.rectangle("line", x + 3, y + 2, size - 6, size - 4, 2, 2)
    love.graphics.circle("fill", x + size * 0.5, y + size * 0.5, 1.8, 6)
  elseif shape == "ring" then
    love.graphics.setLineWidth(1.8)
    love.graphics.circle("line", x + size * 0.5, y + size * 0.5, size * 0.28, 12)
  else
    love.graphics.rectangle("fill", x + 3, y + 3, size - 6, size - 6, 1, 1)
  end
end
-- }}}

-- {{{ local function draw_wallet()
-- What this player holds, per colour, against its ceiling.
--
-- The **waste** is the number that matters and it is drawn where it will nag:
-- income arriving at a full colour is lost, not stored, and a player who is
-- throwing away spirit needs to be told it is spirit. "You are wasting resource" is
-- a shrug; "you are wasting spirit" is an instruction.
local function draw_wallet(world, frame, player_number, x, y, width)
  local catalogue = world.parameters.commander
  local wallet = frame.wallet[player_number]

  love.graphics.setFont(M.font)
  set_colour(M.renderer.COLOUR.text, 0.65)
  love.graphics.print("WALLET", x, y)
  set_colour(M.renderer.COLOUR.text, 0.3)
  love.graphics.setFont(M.font_small)
  love.graphics.printf(catalogue.commander[wallet.commander].name ..
                       "  --  d" .. catalogue.ceiling[wallet.rung],
                       x, y + 2, width, "right")
  y = y + 20

  local size = 22
  local gap = 4
  for colour = 1, #catalogue.colour do
    local row = catalogue.colour[colour]
    local chip_x = x + (colour - 1) * (size + gap + 16)

    love.graphics.setColor(0.10, 0.11, 0.135, 0.9)
    love.graphics.rectangle("fill", chip_x, y, size, size, 3, 3)
    draw_colour_mark(row.shape, chip_x, y, size, row.rgb)

    local held = wallet.points[colour]
    local ceiling = wallet.points_max[colour]
    -- Full is drawn in the colour's own hue and bright, because full means
    -- **bleeding**: the next kill in this colour is thrown away.
    if held >= ceiling then
      set_colour(row.rgb)
    else
      set_colour(M.renderer.COLOUR.text, 0.7)
    end
    love.graphics.setFont(M.font_small)
    love.graphics.print(tostring(held), chip_x + size + 2, y + 5)
  end

  return y + size + 8
end
-- }}}

-- {{{ local function draw_roster()
-- The heroes this commander may buy, with what each costs and whether it is
-- affordable right now.
--
-- Affordability is read off the snapshot rather than worked out here. "Can I buy
-- this" is a question about the world, and the viewer is not allowed to decide
-- anything the simulation could decide.
local function draw_roster(world, frame, player_number, x, y, width, held_hero)
  local catalogue = world.parameters.commander
  local wallet = frame.wallet[player_number]
  local roster = catalogue.commander[wallet.commander].roster

  love.graphics.setFont(M.font)
  set_colour(M.renderer.COLOUR.text, 0.65)
  love.graphics.print("HEROES", x, y)
  if wallet.hero_alive > 0 then
    set_colour(M.renderer.COLOUR.text, 0.4)
    love.graphics.setFont(M.font_small)
    love.graphics.printf(wallet.hero_alive .. " on the field", x, y + 2, width, "right")
  end
  y = y + 20

  local height = 26
  for index, row in ipairs(roster) do
    local affordable = wallet.affordable[index] == 1
    local unit = world.parameters.unit.archetype[row]

    love.graphics.setColor(0.10, 0.11, 0.135, affordable and 0.95 or 0.5)
    love.graphics.rectangle("fill", x, y, width, height, 3, 3)
    if held_hero == row then
      set_colour(M.renderer.COLOUR.team[wallet.team], 0.9)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", x, y, width, height, 3, 3)
    end

    love.graphics.setFont(M.font_small)
    set_colour(M.renderer.COLOUR.text, affordable and 0.9 or 0.35)
    love.graphics.print(unit.name, x + 6, y + 7)

    -- The bill, as marks rather than as numbers, so the shape of what it wants is
    -- readable at a glance next to the wallet directly above it.
    local cost = catalogue.hero_cost[row]
    local mark_x = x + width - 8
    for colour = #catalogue.colour, 1, -1 do
      local amount = cost[colour]
      if amount ~= nil then
        mark_x = mark_x - 16
        local enough = wallet.points[colour] >= amount
        love.graphics.setColor(catalogue.colour[colour].rgb[1],
                               catalogue.colour[colour].rgb[2],
                               catalogue.colour[colour].rgb[3],
                               enough and 1 or 0.3)
        love.graphics.rectangle("fill", mark_x, y + 8, 10, 10, 2, 2)
        set_colour(M.renderer.COLOUR.text, enough and 0.85 or 0.3)
        love.graphics.print(tostring(amount), mark_x + 11, y + 6)
        mark_x = mark_x - 6
      end
    end

    if affordable then
      add_hot("hero", {x, y, width, height}, {hero = row})
    end
    y = y + height + 4
  end

  return y
end
-- }}}

-- {{{ local function draw_signposts()
-- The three standing orders, and who set them.
--
-- Drawn because a teammate changing one **silently redirects every hero you have
-- inbound**, which makes it the only unnegotiated change one player can make to
-- another's plans. It happens without warning, so it had better be visible.
local function draw_signposts(world, frame, x, y, width)
  love.graphics.setFont(M.font)
  set_colour(M.renderer.COLOUR.text, 0.65)
  love.graphics.print("SIGN-POSTS", x, y)
  y = y + 20

  local names = {"top", "centre", "bottom"}
  local size = 26
  for lane = 1, world.parameters.lane_count do
    local post = frame.signpost[lane]
    local post_x = x + (lane - 1) * (size + 62)

    love.graphics.setColor(0.10, 0.11, 0.135, 0.9)
    love.graphics.rectangle("fill", post_x, y, size, size, 3, 3)

    -- Straight on is the default everywhere, so a player who never touches one
    -- gets exactly what they would expect from a game that did not have them.
    if post.branch == 0 then
      set_colour(M.renderer.COLOUR.text, 0.45)
      love.graphics.setLineWidth(2)
      love.graphics.line(post_x + size * 0.5, y + size - 5, post_x + size * 0.5, y + 5)
      love.graphics.line(post_x + size * 0.5 - 4, y + 9, post_x + size * 0.5, y + 5)
      love.graphics.line(post_x + size * 0.5 + 4, y + 9, post_x + size * 0.5, y + 5)
    else
      set_colour(M.renderer.COLOUR.team[1])
      love.graphics.setLineWidth(2)
      love.graphics.line(post_x + 5, y + size * 0.5, post_x + size - 5, y + size * 0.5)
      love.graphics.line(post_x + size - 9, y + size * 0.5 - 4, post_x + size - 5, y + size * 0.5)
      love.graphics.line(post_x + size - 9, y + size * 0.5 + 4, post_x + size - 5, y + size * 0.5)
    end

    love.graphics.setFont(M.font_small)
    set_colour(M.renderer.COLOUR.text, 0.5)
    love.graphics.print(names[lane] or lane, post_x + size + 5, y + 7)

    add_hot("signpost", {post_x, y, size + 56, size}, {lane = lane})
    end

  return y + size + 8
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
function M.draw(world, camera, frame, team_id, held_kind, mouse_x, mouse_y, speed, paused,
                player_number, held_hero)
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

  y = draw_phase_banner(world, frame, inner_x, y, inner_w)
  y = draw_boon_offer(world, frame, inner_x, y, inner_w)

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
  y = y + 4
  set_colour(M.renderer.COLOUR.text, 0.4)
  love.graphics.setFont(M.font_small)
  love.graphics.print(string.format("%d drawn this match", frame.team_view[team_id].draws_taken),
                      inner_x, y)
  y = y + 20

  -- The second economy. Kept below the chest because the chest is the game's centre
  -- and this is the fast layer beside it -- and because a player's eyes travel down
  -- the panel in the order the design says they should.
  y = draw_wallet(world, frame, player_number, inner_x, y, inner_w)
  y = draw_roster(world, frame, player_number, inner_x, y, inner_w, held_hero)
  y = y + 4
  y = draw_signposts(world, frame, inner_x, y, inner_w)

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

  -- A hero riding the cursor, waiting for somewhere to be put down.
  if held_hero ~= nil and held_hero ~= 0 then
    local unit = world.parameters.unit.archetype[held_hero]
    love.graphics.setColor(0.06, 0.07, 0.09, 0.92)
    love.graphics.rectangle("fill", mouse_x - 60, mouse_y - 14, 120, 28, 4, 4)
    set_colour(M.renderer.COLOUR.team[team_id])
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", mouse_x - 60, mouse_y - 14, 120, 28, 4, 4)
    love.graphics.setFont(M.font_small)
    love.graphics.printf(unit.name, mouse_x - 60, mouse_y - 6, 120, "center")
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
