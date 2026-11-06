-- 016-the-campaign.lua
--
-- The map the rounds add up to: a grid of regions, each a kind of ground and
-- an owner. The front is the region the next battle is pushed from; the
-- player picks a compass direction from it, and the battle is fought in the
-- neighbour that way. Winning there takes it; losing gives ground back toward
-- home. A battle won in the enemy's home wins the match; a battle lost with
-- the front at the player's home loses it.
--
-- Region coordinates count from 0: column across, row down. Row 0 is the
-- enemy's side (north), the last row the player's.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local field_m = require("005-battlefield")

local M = {}

-- {{{ function M.new()
function M.new(config, catalogue, stream)
	local c = config.campaign
	local kinds = util.sorted_keys(catalogue.regions)
	local map = { width = c.width, height = c.height, regions = {} }
	for row = 0, c.height - 1 do
		for col = 0, c.width - 1 do
			-- each side starts owning its home row; the middle belongs to nobody
			local owner = 0
			if row == 0 then owner = 2 end
			if row == c.height - 1 then owner = 1 end
			map.regions[row * c.width + col + 1] = {
				col = col, row = row, kind = stream:pick(kinds), owner = owner }
		end
	end
	local mid = math.floor(c.width / 2)
	map.home = { { col = mid, row = c.height - 1 }, { col = mid, row = 0 } }
	-- the homes are always meadows, so the first and last battles are fair ground
	M.region(map, mid, c.height - 1).kind = "meadow"
	M.region(map, mid, 0).kind = "meadow"
	map.front = { col = mid, row = c.height - 1 }
	map.result = false
	return map
end
-- }}}

-- {{{ function M.region()
function M.region(map, col, row)
	if col < 0 or row < 0 or col >= map.width or row >= map.height then return false end
	return map.regions[row * map.width + col + 1]
end
-- }}}

-- The neighbour one region away in a compass direction. Compass vectors are
-- unit length; rounding the diagonals gives the corner neighbour.
-- {{{ local function step_from()
local function step_from(col, row, dir)
	local v = field_m.COMPASS[dir]
	if not v then error("no compass direction named " .. tostring(dir)) end
	return col + util.sign(v[1]), row + util.sign(v[2])
end
-- }}}

-- The region a push in this direction would be fought in, or false when it
-- leads off the map.
-- {{{ function M.target()
function M.target(map, dir)
	local col, row = step_from(map.front.col, map.front.row, dir)
	return M.region(map, col, row)
end
-- }}}

-- {{{ function M.legal_pushes()
function M.legal_pushes(map)
	local list = {}
	for _, dir in ipairs(field_m.COMPASS_ORDER) do
		if M.target(map, dir) then list[#list + 1] = dir end
	end
	return list
end
-- }}}

-- {{{ function M.is_home()
function M.is_home(map, team, region)
	local h = map.home[team]
	return region.col == h.col and region.row == h.row
end
-- }}}

-- The enemy commander's direction: weighted toward heading straight for the
-- player's home (south, as the enemy sees the map). Its choice decides
-- whether it meets our push head on or toward a wing.
-- {{{ function M.enemy_push()
function M.enemy_push(map, stream, straight_weight)
	local choices = { "S", "SW", "SE" }
	local weights = { straight_weight, 1, 1 }
	local total = straight_weight + 2
	local r = stream:float() * total
	for k = 1, 3 do
		r = r - weights[k]
		if r < 0 then return choices[k] end
	end
	return "S"
end
-- }}}

-- Which wing the enemy comes at, given its push. Head on is straight.
M.WING_OF = { S = "straight", SW = "left", SE = "right" }

-- Updates the map after a battle pushed in `dir` ended with `winner`
-- (1, 2, or 0 for a draw, which changes nothing). Returns the match result:
-- false while it goes on, else the winning team.
-- {{{ function M.resolve()
function M.resolve(map, dir, winner)
	local target = M.target(map, dir)
	if not target then error("push " .. dir .. " leads off the map") end
	local front = M.region(map, map.front.col, map.front.row)
	-- the player won: the region is theirs and the front moves into it
	if winner == 1 then
		if M.is_home(map, 2, target) then map.result = 1 end
		target.owner = 1
		map.front = { col = target.col, row = target.row }
	-- the enemy won: the front falls back one region toward the player's home
	elseif winner == 2 then
		if M.is_home(map, 1, front) then
			map.result = 2
		else
			front.owner = 2
			local h = map.home[1]
			map.front = { col = front.col + util.sign(h.col - front.col),
				row = front.row + util.sign(h.row - front.row) }
		end
	end
	return map.result
end
-- }}}

return M
