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

-- 065-the-way-in.lua
--
-- The screen before the match.
--
-- ## Nothing here is game state
--
-- The menu is a viewer that writes commands, like every other part of the viewing
-- layer. It chooses a match to start and then gets out of the way. It does not hold a
-- partially-built world, it does not keep a "current game" of its own, and the
-- simulation never knows it existed.
--
-- That is the same line the whole viewing layer is drawn on, and it is **easiest to
-- cross here**, because a menu feels like the thing that owns the game. It is not. It
-- is a thing that picks a file.
--
-- ## And it is skippable, always
--
-- Every path this menu offers is reachable without it, by argument or environment.
-- Not a convenience -- a requirement. Development, the batch runner and every
-- automated test start a game thousands of times with nobody present, and **a menu
-- that cannot be bypassed is a menu that gets bypassed by a second code path nobody
-- tests.**

local M = {}

M.MENU = 1
M.PLAYING = 2

-- {{{ local function list_scenarios()
local function list_scenarios(root)
  local names = {}
  local pipe = io.popen("ls -1 '" .. root .. "/scenarios' 2>/dev/null")
  if pipe ~= nil then
    for name in pipe:lines() do
      names[#names + 1] = name
    end
    pipe:close()
  end
  table.sort(names)
  return names
end
-- }}}

-- {{{ function M.begin()
-- Builds the menu's own small state. Note what is **not** here: no world, no
-- parameters, nothing half-constructed. Just a list of things somebody could pick.
function M.begin(root)
  return {
    screen = M.MENU,
    root = root,
    hovering = 0,
    page = "top",
    scenarios = list_scenarios(root),
    -- Which of the six resource colours is being shown in which shape, so somebody
    -- who needs the distinction dialled further can dial it. The one setting that
    -- matters more than the rest here: **never encode meaning in hue alone**, and a
    -- player who cannot use the default shapes needs this screen.
    shape_override = {},
    hot = {},
  }
end
-- }}}

-- {{{ local function add_hot()
local function add_hot(state, kind, rect, detail)
  detail = detail or {}
  detail.kind = kind
  detail.x, detail.y, detail.w, detail.h = rect[1], rect[2], rect[3], rect[4]
  state.hot[#state.hot + 1] = detail
end
-- }}}

-- {{{ local function draw_choice()
local function draw_choice(state, label, note, x, y, width, kind, detail)
  local height = 46
  local over = state.hovering_kind == kind and state.hovering_detail == (detail and detail.name or "")

  love.graphics.setColor(0.075, 0.085, 0.105, 0.95)
  love.graphics.rectangle("fill", x, y, width, height, 4, 4)
  love.graphics.setColor(0.96, 0.66, 0.24, over and 0.9 or 0.28)
  love.graphics.setLineWidth(over and 2 or 1)
  love.graphics.rectangle("line", x, y, width, height, 4, 4)

  love.graphics.setColor(0.96, 0.66, 0.24, over and 1 or 0.82)
  love.graphics.setFont(M.font_item)
  love.graphics.print(label, x + 18, y + 9)

  if note ~= nil then
    love.graphics.setColor(0.49, 0.52, 0.57, 1)
    love.graphics.setFont(M.font_note)
    love.graphics.print(note, x + 18, y + 28)
  end

  add_hot(state, kind, {x, y, width, height}, detail)
  return y + height + 9
end
-- }}}

-- {{{ function M.load()
function M.load()
  M.font_title = love.graphics.newFont(38)
  M.font_line  = love.graphics.newFont(15)
  M.font_item  = love.graphics.newFont(17)
  M.font_note  = love.graphics.newFont(12)
end
-- }}}

-- {{{ function M.draw()
function M.draw(state)
  for index = #state.hot, 1, -1 do
    state.hot[index] = nil
  end

  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  love.graphics.clear(0.055, 0.062, 0.078)

  local column = 430
  local x = math.floor((width - column) * 0.5)
  local y = math.max(60, math.floor(height * 0.16))

  love.graphics.setColor(0.96, 0.66, 0.24)
  love.graphics.setFont(M.font_title)
  love.graphics.print("hero-less-moba", x, y)
  y = y + 52

  love.graphics.setColor(0.49, 0.52, 0.57)
  love.graphics.setFont(M.font_line)
  love.graphics.print("nobody remembers why", x, y)
  y = y + 44

  if state.page == "top" then
    y = draw_choice(state, "Play", "a match against the bots", x, y, column, "play")
    y = draw_choice(state, "Scenarios",
      #state.scenarios .. (#state.scenarios == 1 and " described world" or " described worlds")
        .. ", held at the gate", x, y, column, "page", {name = "scenarios"})
    y = draw_choice(state, "Settings", "how the resource colours are shown",
      x, y, column, "page", {name = "settings"})
    y = draw_choice(state, "Out", nil, x, y, column, "quit")

  elseif state.page == "scenarios" then
    love.graphics.setColor(0.78, 0.80, 0.84)
    love.graphics.setFont(M.font_line)
    love.graphics.print("Loaded and held. Nothing advances until you say so.", x, y)
    y = y + 30
    for _, name in ipairs(state.scenarios) do
      y = draw_choice(state, name, nil, x, y, column, "scenario", {name = name})
    end
    y = draw_choice(state, "Back", nil, x, y, column, "page", {name = "top"})

  elseif state.page == "settings" then
    love.graphics.setColor(0.78, 0.80, 0.84)
    love.graphics.setFont(M.font_line)
    love.graphics.print("Every colour has a shape as well as a hue.", x, y)
    y = y + 22
    love.graphics.setColor(0.49, 0.52, 0.57)
    love.graphics.setFont(M.font_note)
    love.graphics.print("Never encode meaning in hue alone. Click one to cycle its shape.",
      x, y)
    y = y + 32
    for index, colour in ipairs(M.colours or {}) do
      local shape = state.shape_override[index] or colour.shape
      y = draw_choice(state, colour.name, "shown as " .. shape, x, y, column,
                      "shape", {name = colour.name, colour = index})
    end
    y = draw_choice(state, "Back", nil, x, y, column, "page", {name = "top"})
  end

  love.graphics.setColor(0.36, 0.39, 0.44)
  love.graphics.setFont(M.font_note)
  love.graphics.printf(
    "Every path here is reachable without this screen. " ..
    "./run-prototype play, ./run-scenario <name>, ./run-many-matches.",
    0, height - 30, width, "center")
end
-- }}}

-- {{{ function M.mousemoved()
function M.mousemoved(state, x, y)
  state.hovering_kind, state.hovering_detail = nil, nil
  for _, hot in ipairs(state.hot) do
    if x >= hot.x and x <= hot.x + hot.w and y >= hot.y and y <= hot.y + hot.h then
      state.hovering_kind = hot.kind
      state.hovering_detail = hot.name or ""
      return
    end
  end
end
-- }}}

-- {{{ function M.mousepressed()
-- Returns what the caller should do: nothing, or a table naming a match to start.
--
-- **It returns a choice; it does not make one happen.** The menu names a thing and
-- the viewer builds it, which is what keeps this file from quietly becoming the owner
-- of the game.
function M.mousepressed(state, x, y)
  for _, hot in ipairs(state.hot) do
    if x >= hot.x and x <= hot.x + hot.w and y >= hot.y and y <= hot.y + hot.h then
      if hot.kind == "page" then
        state.page = hot.name
        return nil
      elseif hot.kind == "quit" then
        love.event.quit()
        return nil
      elseif hot.kind == "shape" then
        local shapes = {"pips", "bar", "script", "card", "block", "ring"}
        local current = state.shape_override[hot.colour] or M.colours[hot.colour].shape
        local at = 1
        for index, name in ipairs(shapes) do
          if name == current then at = index break end
        end
        state.shape_override[hot.colour] = shapes[(at % #shapes) + 1]
        return nil
      elseif hot.kind == "play" then
        return {start = "match"}
      elseif hot.kind == "scenario" then
        return {start = "scenario", name = hot.name}
      end
    end
  end
  return nil
end
-- }}}

-- {{{ function M.keypressed()
function M.keypressed(state, key)
  if key == "escape" then
    if state.page ~= "top" then
      state.page = "top"
    else
      love.event.quit()
    end
  end
end
-- }}}

return M
