-- main.lua
--
-- The engine insists on a file of exactly this name at the root of the game
-- folder, so this one file is unnumbered. It is a doorway, not a room: it
-- finds the project folder, points the module path at src/, and forwards
-- every engine callback to the front desk (src/029-the-front-desk.lua).
--
-- sword-fighting-game - first-person sword fighting in battalions, with a
-- commander's seat between the clashes.
-- Copyright (C) 2026 gabrilend
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at
-- your option) any later version. See <https://www.gnu.org/licenses/>.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local desk

-- The project folder's real path: the simulation reads its data with plain
-- io rather than through the engine's sandbox, so the very same files run
-- under a bare luajit with no window.
-- {{{ function love.load()
function love.load(argv)
	local root = love.filesystem.getSource()
	package.path = root .. "/src/?.lua;" .. package.path
	desk = require("029-the-front-desk")
	desk.load(root, argv)
end
-- }}}

-- Closing the window is a clean ending too, so it writes the receipt.
-- {{{ function love.quit()
function love.quit()
	desk.finish()
	return false
end
-- }}}

-- The rest of the engine's callbacks go straight to the desk's function of
-- the same name, looked up when called (the desk exists only after load).
for _, name in ipairs({ "update", "draw", "keypressed", "keyreleased", "mousepressed",
	"mousereleased", "mousemoved", "wheelmoved" }) do
	love[name] = function(...) return desk[name](...) end
end
