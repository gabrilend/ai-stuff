-- 030-screenshots.lua
--
-- Takes a picture of the screen into tmp/shared-memory/screenshots/, with a
-- small sidecar file beside it saying what run took it: the seed, the tick,
-- the run's arguments. Nothing here files the picture; scripts/file-screenshots
-- does that after the game exits, numbering it into development-history/.
--
-- The engine delivers the picture at the end of the frame it was asked for,
-- so a quit asked for at the same moment waits until every pending picture
-- has been written.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

M.pending = 0
M.taken = 0

-- {{{ function M.folder()
function M.folder(dir)
	return dir .. "/tmp/shared-memory/screenshots"
end
-- }}}

-- name: a short word for the picture; info: { seed, tick, args }.
-- {{{ function M.take()
function M.take(dir, name, info)
	local folder = M.folder(dir)
	os.execute('mkdir -p "' .. folder .. '"')
	local stem = string.format("%s/%08d-%s", folder, info.tick, name:gsub("[^%w%-]", "-"))
	M.pending = M.pending + 1
	love.graphics.captureScreenshot(function(image)
		local f = io.open(stem .. ".png", "wb")
		f:write(image:encode("png"):getString())
		f:close()
		local side = io.open(stem .. ".run", "w")
		side:write(string.format("seed: %s\ntick: %d\nname: %s\nargs: %s\n", tostring(info.seed),
			info.tick, name, info.args))
		side:close()
		M.pending = M.pending - 1
		M.taken = M.taken + 1
	end)
end
-- }}}

return M
