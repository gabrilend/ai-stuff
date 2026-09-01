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

-- 080-the-front-desk.lua
--
-- Decides which of the two front ends is being asked for, so that main.lua does
-- not have to.
--
-- There are three now. The **viewer** builds a world and draws it: the generator,
-- the validator, two baked meshes, seven locomotion rows, a director and a panel.
-- The **client** loads a scene -- a picture and a datafile -- and draws only the
-- things that move. The **tracing table** shows a picture somebody else made and
-- lets a person draw the world onto it.
--
-- This file exists because the engine insists on a file called main.lua at the
-- root of the game directory, and that file is a doorway rather than a room. The
-- moment it starts choosing between two things, the project has a piece of
-- program sitting outside its own reading order. So the choosing happens here,
-- where it is numbered and read in sequence like everything else.
--
-- The rule is the argument: `--play` names a scene file and belongs to the
-- client, `--trace` or `--plan` names a picture or a plan and belongs to the
-- tracing table, and anything else is the viewer.
--
-- Not `--scene`, which the viewer has meant "which creatures are in it" since
-- phase four. Two flags of one name in one program is a collision that shows up
-- as the wrong front end starting, with a parse error from a file that was never
-- the file being asked for.

local M = {}

local front

-- {{{ function M.load(root, argv)
function M.load(root, argv)
  local which = "045-the-viewer"
  for _, a in ipairs(argv or {}) do
    if     a == "--play"  then which = "079-the-client"; break
    elseif a == "--trace" or a == "--plan" then
      which = "082-the-tracing-table"; break
    end
  end

  front = loadfile(root .. "/src/" .. which .. ".lua")()
  front.load(root, argv)
end
-- }}}

-- The engine's callbacks, forwarded. A front end that does not want one says so
-- by not having it, rather than by being asked whether it does.
--
-- {{{ the forwarders
function M.update(dt)              if front.update then front.update(dt) end end
function M.draw()                  if front.draw then front.draw() end end
function M.resize(w, h)            if front.resize then front.resize(w, h) end end
function M.keypressed(key)         if front.keypressed then front.keypressed(key) end end
function M.wheelmoved(dx, dy)      if front.wheelmoved then front.wheelmoved(dx, dy) end end
function M.mousepressed(x, y, b)   if front.mousepressed then front.mousepressed(x, y, b) end end
function M.mousereleased(x, y, b)  if front.mousereleased then front.mousereleased(x, y, b) end end
function M.mousemoved(x, y, dx, dy)
  if front.mousemoved then front.mousemoved(x, y, dx, dy) end
end
-- }}}

return M
