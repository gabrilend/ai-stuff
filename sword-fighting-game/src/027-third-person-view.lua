-- 027-third-person-view.lua
--
-- The commander's seat: a raised camera behind the player's contingent,
-- looking down at the field, slid with the movement keys and zoomed with the
-- wheel. Every figure is drawn at the same detail as in the front rank.
--
-- Drawn in the world itself, not as interface: the push direction as a clay
-- arrow on the ground ahead, the ring where the next volley's fixed arc will
-- land, darts in flight, raised shields, and a pennant over the player's own
-- soldier so the commander can find themself before dropping in.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local mat = require("021-matrix")
local renderer = require("023-the-renderer")
local fp = require("026-first-person-view")

local M = {}

local RING = { 1.0, 0.85, 0.25 }
local ARROW = { 0.86, 0.66, 0.50 }

-- The middle of a team's standing soldiers, in cells.
-- {{{ local function centre()
local function centre(battle, team)
	local x, y, n = 0, 0, 0
	for _, s in ipairs(battle.soldiers) do
		if s.team == team and s.alive then
			x, y, n = x + s.x, y + s.y, n + 1
		end
	end
	if n == 0 then return battle.config.field.width / 2, battle.config.field.height / 2 end
	return x / n, y / n
end
-- }}}

-- The middle of a team's front: the mean of its battalion origins.
-- {{{ local function front()
local function front(battle, team)
	local x, y, f = 0, 0, 0
	local list = battle.battalions[team]
	for _, b in ipairs(list) do x, y, f = x + b.x, y + b.y, f + b.facing end
	return x / #list, y / #list, f / #list
end
-- }}}

-- view.slide_x, view.slide_z: how far the commander has slid the camera, in
-- metres; view.zoom: the distance multiplier.
-- {{{ function M.camera()
function M.camera(battle, view, w, h)
	local config = battle.config
	local cell = config.field.cell_metres
	local cx, cy = centre(battle, 1)
	local tx, tz = cx * cell + view.slide_x, (cy - 4) * cell + view.slide_z
	local pitch, dist = config.view.third_pitch, config.view.third_distance * view.zoom
	local ex, ey, ez = tx, math.sin(pitch) * dist, tz + math.cos(pitch) * dist
	local fov = mat.vertical_fov(math.rad(config.view.third_fov), w / h)
	return { proj = mat.perspective(fov, w / h, 0.5, 600), view = mat.look_at(ex, ey, ez, tx, 0, tz),
		ex = ex, ey = ey, ez = ez, fog = 90, fog_color = config.view.sky_bottom }
end
-- }}}

-- {{{ local function flat()
local function flat(parts, shape, x, y, z, sx, sy, sz, color, turn)
	local m = mat.translate(x, y, z)
	if turn then m = mat.multiply(m, mat.rotate_y(turn)) end
	parts[#parts + 1] = { shape = shape, model = mat.multiply(m, mat.scale(sx, sy, sz)),
		sx = sx, sy = sy, sz = sz, color = color, look = "flat" }
end
-- }}}

-- The arrow, the landing ring and the shield wall.
-- {{{ function M.marks()
function M.marks(battle, parts, show_arrow)
	local config = battle.config
	local cell = config.field.cell_metres
	local fx, fy, facing = front(battle, 1)
	local dx, dy = math.cos(facing), math.sin(facing)
	-- the push arrow, a few cells ahead of the front
	if show_arrow then
		local ax, az = (fx + dx * 3) * cell, (fy + dy * 3) * cell
		flat(parts, "box", ax, 0.03, az, 1.6, 0.03, 0.18, ARROW, -facing)
		local hx, hz = ax + dx * 1.6, az + dy * 1.6
		flat(parts, "box", hx - dx * 0.4 - dy * 0.35, 0.04, hz - dy * 0.4 + dx * 0.35, 0.6, 0.03,
			0.16, ARROW, -facing + 0.7)
		flat(parts, "box", hx - dx * 0.4 + dy * 0.35, 0.04, hz - dy * 0.4 - dx * 0.35, 0.6, 0.03,
			0.16, ARROW, -facing - 0.7)
	end
	-- where the fixed arc lands: the commander chooses when, not where
	local reach = battle.volley_range[1] * config.ranged.battalion_length
	local middle = (config.field.battalion_deep - 1) / 2
	local rx, rz = (fx + dx * (reach - middle)) * cell, (fy + dy * (reach - middle)) * cell
	local ready = battle.time >= battle.volley_ready[1]
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local r = 3.2
		local c = ready and RING or { 0.6, 0.6, 0.6 }
		flat(parts, "box", rx + math.cos(a) * r * 1.6, 0.04, rz + math.sin(a) * r, 0.25, 0.03, 0.08,
			c, -a)
	end
	for _, s in ipairs(battle.soldiers) do
		-- a raised wall shows a shield on everyone who does not carry one already
		if battle.shields[s.team] and s.alive and not s.traits.shield then
			M.raised_shield(parts, s, cell, config.view.team_colors[s.team])
		end
	end
end
-- }}}

-- A shield disc held upright a little in front of a soldier.
-- {{{ function M.raised_shield()
function M.raised_shield(parts, s, cell, color)
	local x = (s.x + math.cos(s.facing) * 0.35) * cell
	local z = (s.y + math.sin(s.facing) * 0.35) * cell
	local upright = mat.multiply(mat.rotate_z(math.pi / 2), mat.scale(0.35, 0.03, 0.35))
	local m = mat.multiply(mat.translate(x, 1.2, z), mat.multiply(mat.rotate_y(-s.facing), upright))
	parts[#parts + 1] = { shape = "cylinder", model = m, sx = 0.35, sy = 0.03, sz = 0.35,
		color = color, look = "brick" }
end
-- }}}

-- {{{ function M.draw()
function M.draw(battle, view, w, h, show_arrow)
	fp.sky(battle.config, w, h)
	local cam = M.camera(battle, view, w, h)
	renderer.begin_3d(view.renderer, cam)
	renderer.draw_list(view.renderer, view.scenery)
	local parts = fp.world_parts(battle, view, nil, { pennant = true })
	M.marks(battle, parts, show_arrow)
	renderer.draw_list(view.renderer, parts)
	renderer.end_3d(view.renderer)
end
-- }}}

return M
