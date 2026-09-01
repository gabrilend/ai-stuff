-- main.lua
--
-- LOVE insists on a file with this exact name at the root of the game directory,
-- so this one file is unnumbered while every other source file in the project
-- carries its index. It is a doorway rather than a room: it works out where the
-- project root is, loads the viewer, and forwards the engine's callbacks to it.
--
-- Nothing else belongs here. The moment this file starts making decisions, the
-- project has a piece of program sitting outside its own reading order.
--
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

local viewer

function love.conf(t)
end

function love.load()
  -- The real filesystem path of the game directory. The simulation reads its
  -- catalogues and its input/ files with plain Lua io rather than through LOVE's
  -- sandbox, so that the very same files run under a bare luajit with no window
  -- -- which is how ten thousand matches get played overnight.
  local root = love.filesystem.getSource()

  -- **Which room this doorway opens onto.** There are two windows in this project and
  -- they are not two versions of one thing: one draws a match, and one draws a single
  -- rule on a small square of ground with nothing else running. Choosing between them
  -- is the last decision that belongs in a doorway, and it is made by reading one
  -- variable rather than by either viewer knowing the other exists.
  local scene = (os.getenv("HLM_START") or ""):match("^arena:(.+)$")
  if scene ~= nil then
    viewer = loadfile(root .. "/src/069-the-proving-ground.lua")()
    viewer.load(root, scene)
    return
  end

  viewer = loadfile(root .. "/src/050-the-viewer.lua")()
  viewer.load(root)
end

function love.update(dt)               viewer.update(dt) end
function love.draw()                   viewer.draw() end
function love.resize(w, h)             viewer.resize(w, h) end
function love.keypressed(key)          viewer.keypressed(key) end
function love.wheelmoved(dx, dy)       viewer.wheelmoved(dx, dy) end
function love.mousepressed(x, y, b)    viewer.mousepressed(x, y, b) end
function love.mousereleased(x, y, b)   viewer.mousereleased(x, y, b) end
function love.mousemoved(x, y)         viewer.mousemoved(x, y) end
