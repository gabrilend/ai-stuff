-- 028-command-screen.lua
--
-- The table between rounds, seen from above: the campaign map of regions in
-- clay and brick colours, each side's regions edged in its colour, the two
-- homes bannered, the front marked, and eight compass arrows around the
-- front (the ones leading off the map greyed). Below it, the perk cards.
-- If the chosen perk converts soldiers, the table asks whether the player is
-- to be one of them.
--
-- This is the one screen with words on it, because it is a table of choices
-- and not the battlefield. Everything is drawn in 2D; clicks are tested
-- against the same rectangles and circles the drawing used, kept in a list
-- of hit areas rebuilt every frame.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local field_m = require("005-battlefield")
local campaign = require("016-the-campaign")
local perks = require("015-perks")

local M = {}

local PAPER = { 0.93, 0.89, 0.80 }
local INK = { 0.18, 0.13, 0.10 }
local DIM = { 0.62, 0.58, 0.52 }

-- {{{ function M.layout()
function M.layout(w, h, map)
	local cell = math.floor(math.min(w * 0.5 / map.width, h * 0.62 / map.height))
	return { cell = cell, ox = math.floor(w * 0.06), oy = math.floor(h * 0.12) }
end
-- }}}

-- {{{ local function region_rect()
local function region_rect(l, col, row)
	return l.ox + col * l.cell, l.oy + row * l.cell, l.cell, l.cell
end
-- }}}

-- {{{ local function draw_map()
local function draw_map(match, l, catalogue, team_colors, fonts)
	local g = love.graphics
	local map = match.map
	for _, r in ipairs(map.regions) do
		local x, y, cw, ch = region_rect(l, r.col, r.row)
		local c = catalogue.regions[r.kind].ground_color
		g.setColor(c[1], c[2], c[3])
		g.rectangle("fill", x + 3, y + 3, cw - 6, ch - 6, 10, 10)
		-- an owned region is edged in its owner's brick colour
		if r.owner > 0 then
			local t = team_colors[r.owner]
			g.setColor(t[1], t[2], t[3])
			g.setLineWidth(5)
			g.rectangle("line", x + 5, y + 5, cw - 10, ch - 10, 8, 8)
		end
		g.setColor(INK)
		g.setFont(fonts.tiny)
		g.printf(catalogue.regions[r.kind].title, x + 8, y + ch - 34, cw - 16)
	end
	for team = 1, 2 do
		local hm = map.home[team]
		local x, y = region_rect(l, hm.col, hm.row)
		local t = team_colors[team]
		g.setColor(t)
		g.polygon("fill", x + 14, y + 12, x + 40, y + 20, x + 14, y + 28)
		g.setColor(INK)
		g.line(x + 14, y + 10, x + 14, y + 44)
	end
end
-- }}}

-- The compass around the front; each arrow is a hit area.
-- {{{ local function draw_arrows()
local function draw_arrows(match, l, hits)
	local g = love.graphics
	local fx, fy = region_rect(l, match.map.front.col, match.map.front.row)
	local cx, cy = fx + l.cell / 2, fy + l.cell / 2
	g.setColor(1, 0.85, 0.2)
	g.circle("fill", cx, cy, l.cell * 0.12)
	for _, dir in ipairs(field_m.COMPASS_ORDER) do
		local v = field_m.COMPASS[dir]
		local ax, ay = cx + v[1] * l.cell * 0.36, cy + v[2] * l.cell * 0.36
		local legal = campaign.target(match.map, dir)
		local picked = match.choice.push == dir
		g.setColor(picked and { 0.85, 0.2, 0.15 } or (legal and INK or DIM))
		g.circle("fill", ax, ay, picked and 16 or 12)
		g.setColor(PAPER)
		g.print(dir, ax - 7, ay - 7)
		if legal then hits[#hits + 1] = { kind = "push", value = dir, x = ax, y = ay, r = 18 } end
	end
end
-- }}}

-- {{{ local function draw_cards()
local function draw_cards(match, w, h, hits, fonts)
	local g = love.graphics
	local n = #match.cards
	local cw, ch = math.floor(w * 0.36), math.floor(h * 0.17)
	local x0, y0 = math.floor(w * 0.6), math.floor(h * 0.12)
	for k, name in ipairs(match.cards) do
		local perk = match.catalogue.perks[name]
		local x, y = x0, y0 + (k - 1) * (ch + 14)
		local picked = match.choice.perk == name
		g.setColor(picked and { 1, 0.93, 0.7 } or { 1, 1, 1 })
		g.rectangle("fill", x, y, cw, ch, 10, 10)
		g.setColor(picked and { 0.85, 0.2, 0.15 } or INK)
		g.setLineWidth(picked and 4 or 2)
		g.rectangle("line", x, y, cw, ch, 10, 10)
		g.setFont(fonts.big)
		g.print(perk.title, x + 14, y + 10)
		g.setFont(fonts.small)
		g.printf(perk.text, x + 14, y + 44, cw - 28)
		hits[#hits + 1] = { kind = "perk", value = name, x = x, y = y, w = cw, h = ch }
	end
	if n == 0 then
		g.setColor(INK)
		g.print("every perk has been taken", x0, y0)
	end
end
-- }}}

-- Returns the hit areas, which the front desk keeps for the next click.
-- {{{ function M.draw()
function M.draw(match, w, h, fonts)
	local g = love.graphics
	local config, catalogue = match.config, match.catalogue
	g.clear(PAPER[1], PAPER[2], PAPER[3], 1)
	local hits = {}
	local l = M.layout(w, h, match.map)
	g.setFont(fonts.big)
	g.setColor(INK)
	g.print(string.format("round %d - choose where to push, and one perk", match.round),
		l.ox, math.floor(h * 0.04))
	g.setFont(fonts.small)
	draw_map(match, l, catalogue, config.view.team_colors, fonts)
	g.setFont(fonts.small)
	draw_arrows(match, l, hits)
	draw_cards(match, w, h, hits, fonts)
	local y = math.floor(h * 0.84)
	g.setColor(INK)
	local last = match.history[#match.history]
	if last then
		g.print(string.format("last round: pushed %s into %s, %s", last.push, last.region,
			last.winner == 1 and "won" or (last.winner == 2 and "lost" or "drawn")), l.ox, y)
	end
	-- the question, asked only of a perk that converts soldiers
	if match.choice.perk and perks.asks_player(catalogue, match.choice.perk) then
		g.print(string.format("be one of them?  [Y] yes  [N] no    now: %s",
			match.choice.be_affected and "yes" or "no"), l.ox, y + 24)
	end
	local ready = match.choice.push and "press RETURN to begin the round"
		or "click a compass arrow to choose the push"
	g.setFont(fonts.big)
	g.print(ready, l.ox, y + 52)
	return hits
end
-- }}}

-- The banner over the battlefield at the end of a round.
-- {{{ function M.draw_result()
function M.draw_result(match, w, h, fonts)
	local g = love.graphics
	local b = match.battle
	local words = { [0] = "a draw", [1] = "the round is won", [2] = "the round is lost" }
	local text = words[b.outcome] or ""
	if match.result then text = match.result == 1 and "the match is won" or "the match is lost" end
	g.setColor(0, 0, 0, 0.45)
	g.rectangle("fill", 0, h * 0.4, w, h * 0.16)
	g.setColor(1, 1, 1)
	g.setFont(fonts.huge)
	g.printf(text, 0, h * 0.42, w, "center")
	g.setFont(fonts.small)
	g.printf(string.format("%d of yours standing, %d of theirs", b.standing[1], b.standing[2]),
		0, h * 0.5, w, "center")
end
-- }}}

-- The hit area under a point, or false.
-- {{{ function M.hit()
function M.hit(hits, x, y)
	for _, a in ipairs(hits or {}) do
		if a.r then
			if (x - a.x) ^ 2 + (y - a.y) ^ 2 <= a.r * a.r then return a end
		elseif x >= a.x and y >= a.y and x <= a.x + a.w and y <= a.y + a.h then
			return a
		end
	end
	return false
end
-- }}}

return M
