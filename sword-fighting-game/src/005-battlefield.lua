-- 005-battlefield.lua
--
-- The grid a battle is fought on. Positions are continuous, but a soldier
-- holds exactly one cell (the one its centre is in), and the occupancy array
-- is what "moving into an occupied space" is judged against.
--
-- Cells are numbered from 0; the occupancy array is allocated once at
-- creation and never grows. An empty slot holds false rather than nil so the
-- array has no holes.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- Compass directions as unit vectors on the map. North is toward smaller y,
-- which is "up" on the commander's map and away from the player's home.
local D = math.sqrt(0.5)
M.COMPASS = {
	N  = { 0, -1 },  NE = { D, -D },
	E  = { 1, 0 },   SE = { D, D },
	S  = { 0, 1 },   SW = { -D, D },
	W  = { -1, 0 },  NW = { -D, -D },
}
M.COMPASS_ORDER = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

-- {{{ function M.new()
function M.new(width, height)
	local cells = {}
	for i = 1, width * height do cells[i] = false end
	return { width = width, height = height, cells = cells }
end
-- }}}

-- {{{ function M.cell_of()
function M.cell_of(x, y)
	return math.floor(x), math.floor(y)
end
-- }}}

-- {{{ function M.inside()
function M.inside(field, cx, cy)
	return cx >= 0 and cy >= 0 and cx < field.width and cy < field.height
end
-- }}}

-- Who holds the cell, or false. Outside the field counts as held by the
-- edge, which is returned as the string "edge" so a caller cannot mistake it
-- for a soldier or for an empty cell.
-- {{{ function M.holder()
function M.holder(field, cx, cy)
	if not M.inside(field, cx, cy) then return "edge" end
	return field.cells[cy * field.width + cx + 1]
end
-- }}}

-- Takes an empty cell. Claiming a held cell is a bug in the caller, so it
-- stops the program rather than quietly stacking two bodies in one place.
-- {{{ function M.claim()
function M.claim(field, cx, cy, soldier)
	local i = cy * field.width + cx + 1
	if field.cells[i] then
		error(string.format("cell %d,%d is already held by soldier %d",
			cx, cy, field.cells[i].id))
	end
	field.cells[i] = soldier
	soldier.cell_x, soldier.cell_y = cx, cy
end
-- }}}

-- {{{ function M.release()
function M.release(field, soldier)
	local i = soldier.cell_y * field.width + soldier.cell_x + 1
	if field.cells[i] == soldier then field.cells[i] = false end
end
-- }}}

-- Two soldiers trade cells: the ally-yield rule.
-- {{{ function M.swap()
function M.swap(field, a, b)
	local ax, ay, bx, by = a.cell_x, a.cell_y, b.cell_x, b.cell_y
	field.cells[ay * field.width + ax + 1] = b
	field.cells[by * field.width + bx + 1] = a
	a.cell_x, a.cell_y, b.cell_x, b.cell_y = bx, by, ax, ay
end
-- }}}

-- The soldiers within radius of a point, appended to `out` in cell order
-- (so the result is the same on every run). The cost depends on the radius,
-- not on how many soldiers there are.
-- {{{ function M.near()
function M.near(field, x, y, radius, out)
	local r2 = radius * radius
	local x0 = math.max(0, math.floor(x - radius))
	local x1 = math.min(field.width - 1, math.floor(x + radius))
	local y0 = math.max(0, math.floor(y - radius))
	local y1 = math.min(field.height - 1, math.floor(y + radius))
	for cy = y0, y1 do
		for cx = x0, x1 do
			local s = field.cells[cy * field.width + cx + 1]
			if s then
				local dx, dy = s.x - x, s.y - y
				if dx * dx + dy * dy <= r2 then out[#out + 1] = s end
			end
		end
	end
	return out
end
-- }}}

return M
