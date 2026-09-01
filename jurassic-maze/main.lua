-- main.lua
--
-- The engine insists on a file with this exact name at the root of the game
-- directory, so this one file is unnumbered while every other source file in the
-- project carries its index. It is a doorway rather than a room: it works out
-- where the project is, loads the viewer, and forwards the engine's callbacks.
--
-- Nothing else belongs here. The moment this file starts making decisions, the
-- project has a piece of program sitting outside its own reading order.
--
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

local viewer

function love.load(argv)
  -- The real filesystem path of the game directory. The simulation reads its
  -- catalogues with plain Lua io rather than through the engine's sandbox, so
  -- that the very same files run under a bare luajit with no window -- which is
  -- how ten thousand mazes get built overnight.
  local root = love.filesystem.getSource()
  viewer = loadfile(root .. "/src/045-the-viewer.lua")()
  viewer.load(root, argv)
end

function love.update(dt)            viewer.update(dt) end
function love.draw()                viewer.draw() end
function love.resize(w, h)          viewer.resize(w, h) end
function love.keypressed(key)       viewer.keypressed(key) end
function love.wheelmoved(dx, dy)    viewer.wheelmoved(dx, dy) end
function love.mousepressed(x, y, b) viewer.mousepressed(x, y, b) end
function love.mousereleased(x, y, b) viewer.mousereleased(x, y, b) end
function love.mousemoved(x, y, dx, dy) viewer.mousemoved(x, y, dx, dy) end
