-- 026-first-person-view.lua
--
-- Standing in the front rank. The camera is the player soldier's eyes, with
-- the vision's 90 degree field of view, and there is no interface at all:
-- the player sees their own arms and sword, the field, and the bodies.
--
-- What the player needs to know is in the picture instead:
--   fatigue   the view sways and the edges darken
--   a wound   red pulses in from the edges
--   the sides soldiers inside the 160 degree awareness arc (narrowed by
--             armor) but outside the 90 degree view glow at the screen edge
--             on their side: warm for allies, cold for enemies, brighter
--             when nearer
--   the lock  the locked enemy is drawn a little brighter
--
-- The helpers that draw the world (sky, scenery, every figure, darts and
-- sparks) live here too, and the third-person view uses them.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local mat = require("021-matrix")
local renderer = require("023-the-renderer")
local figures = require("024-figures")
local ranged = require("013-ranged")

local M = {}

local WARM = { 1.0, 0.62, 0.25 }
local COLD = { 0.35, 0.62, 1.0 }
local SPARK = { 1.0, 0.92, 0.55 }
local PARRY = { 0.9, 0.95, 1.0 }

-- A rectangle fading from one alpha to another, across or down.
-- {{{ local function gradient()
local function gradient(x, y, w, h, color, a0, a1, horizontal)
	local r, g, b = color[1], color[2], color[3]
	local v
	if horizontal then
		v = { { x, y, 0, 0, r, g, b, a0 }, { x + w, y, 0, 0, r, g, b, a1 },
			{ x + w, y + h, 0, 0, r, g, b, a1 }, { x, y + h, 0, 0, r, g, b, a0 } }
	else
		v = { { x, y, 0, 0, r, g, b, a0 }, { x + w, y, 0, 0, r, g, b, a0 },
			{ x + w, y + h, 0, 0, r, g, b, a1 }, { x, y + h, 0, 0, r, g, b, a1 } }
	end
	love.graphics.draw(love.graphics.newMesh(v, "fan"))
end
-- }}}

M.gradient = gradient

-- {{{ function M.sky()
function M.sky(config, w, h)
	love.graphics.clear(config.view.sky_bottom[1], config.view.sky_bottom[2],
		config.view.sky_bottom[3], 1)
	gradient(0, 0, w, h * 0.6, config.view.sky_top, 1, 0, false)
end
-- }}}

-- {{{ function M.figure_opts()
function M.figure_opts(config)
	return { cell = config.field.cell_metres, clay = config.view.clay_color,
		team_colors = config.view.team_colors }
end
-- }}}

-- Sparks for hits, a pale flash for parries: read from the tick's events
-- into the view's own short-lived list, which never touches the battle.
-- {{{ function M.add_effects()
function M.add_effects(fx, battle)
	for _, e in ipairs(battle.events) do
		if e.kind == "hit" or e.kind == "dart_hit" then
			fx[#fx + 1] = { x = e.who.x, y = e.who.y, t = 0.3, color = SPARK,
				size = e.critical and 0.28 or 0.16 }
		end
		if e.kind == "parry" or e.kind == "block" then
			fx[#fx + 1] = { x = e.who.x, y = e.who.y, t = 0.2, color = PARRY, size = 0.12 }
		end
	end
end
-- }}}

-- {{{ function M.age_effects()
function M.age_effects(fx, dt)
	local keep = 0
	for k = 1, #fx do
		local f = fx[k]
		f.t = f.t - dt
		if f.t > 0 then
			keep = keep + 1
			fx[keep] = f
		end
	end
	for k = #fx, keep + 1, -1 do fx[k] = nil end
end
-- }}}

-- Every figure, the darts in flight and the sparks, as one part list.
-- `skip` is a soldier not to draw (the player, whose eyes the camera is).
-- {{{ function M.world_parts()
function M.world_parts(battle, view, skip, opts)
	local config = battle.config
	local parts = {}
	local fopts = M.figure_opts(config)
	local cell = config.field.cell_metres
	for _, s in ipairs(battle.soldiers) do
		if s ~= skip then
			fopts.bright = opts.lock == s
			fopts.pennant = opts.pennant and s.is_player
			figures.build(parts, s, fopts)
		end
	end
	for _, d in ipairs(battle.darts) do
		local x, y, lift = ranged.position(battle, d)
		local back = { t = math.max(0, d.t - 0.08), flight = d.flight, sx = d.sx, sy = d.sy,
			ex = d.ex, ey = d.ey }
		local bx, by, blift = ranged.position(battle, back)
		local m, sx, sy, sz = mat.along(bx * cell, 1.5 + blift * cell, by * cell, x * cell,
			1.5 + lift * cell, y * cell, 0.025)
		parts[#parts + 1] = { shape = "box", model = m, sx = sx, sy = sy, sz = sz,
			color = config.view.team_colors[d.team], look = "brick" }
	end
	for _, f in ipairs(view.fx) do
		local r = f.size * (0.5 + f.t * 2)
		parts[#parts + 1] = { shape = "blob", model = mat.multiply(mat.translate(f.x * cell, 1.3,
			f.y * cell), mat.scale(r, r, r)), sx = r, sy = r, sz = r, color = f.color,
			look = "flat" }
	end
	return parts
end
-- }}}

-- {{{ function M.camera()
function M.camera(battle, s, w, h, time)
	local config = battle.config
	local cell = config.field.cell_metres
	local fatigue = 1 - s.stamina
	local bob = math.sin(time * 5.5) * config.view.fatigue_bob * fatigue
		+ math.sin(s.distance_walked * 6.8) * 0.02
	-- the eye sits a little behind and above the shoulders, so the arms come
	-- into the picture from its lower corners rather than filling it
	local back = config.view.eye_back
	local ex = s.x * cell - math.cos(s.facing) * back
	local ey = config.view.eye_height * s.height + bob
	local ez = s.y * cell - math.sin(s.facing) * back
	local yaw = s.facing + s.look_offset + math.sin(time * 1.7) * 0.012 * fatigue
	local pitch = -0.1
	-- the eyes rest on the locked enemy's chest
	if s.lock and s.look_offset == 0 then
		local d = util.distance(s.x, s.y, s.lock.x, s.lock.y) * cell
		pitch = math.atan2(1.15 * s.lock.height - ey, math.max(d, 0.5))
	end
	local tx = ex + math.cos(yaw) * math.cos(pitch)
	local ty = ey + math.sin(pitch)
	local tz = ez + math.sin(yaw) * math.cos(pitch)
	local fov = mat.vertical_fov(math.rad(config.view.fov), w / h)
	return { proj = mat.perspective(fov, w / h, 0.05, 400), view = mat.look_at(ex, ey, ez, tx, ty, tz),
		ex = ex, ey = ey, ez = ez, fog = 40, fog_color = config.view.sky_bottom, yaw = yaw }
end
-- }}}

-- How strongly allies and enemies are felt beyond each edge of the view.
-- {{{ local function awareness()
local function awareness(battle, s, yaw)
	local config = battle.config
	local half_view = math.rad(config.view.fov) / 2
	local half_aware = math.rad(s.awareness) / 2
	local felt = { left = { 0, 0 }, right = { 0, 0 } }
	for _, o in ipairs(battle.soldiers) do
		local d = util.distance(s.x, s.y, o.x, o.y)
		if o ~= s and o.alive and d < 8 then
			local rel = util.wrap_angle(util.bearing(s.x, s.y, o.x, o.y) - yaw)
			-- outside the eyes, inside what the body knows
			if math.abs(rel) > half_view and math.abs(rel) <= half_aware then
				local side = rel > 0 and felt.right or felt.left
				local k = o.team == s.team and 1 or 2
				side[k] = side[k] + (1 - d / 8)
			end
		end
	end
	return felt
end
-- }}}

-- The only things drawn over the world: light at the edges.
-- {{{ local function edges()
local function edges(battle, s, w, h, yaw)
	local glow = battle.config.view.edge_glow
	local felt = awareness(battle, s, yaw)
	local band = w * 0.16
	for _, side in ipairs({ "left", "right" }) do
		local f = felt[side]
		local x = side == "left" and 0 or w - band
		local a0, a1 = 1, 0
		if side == "right" then a0, a1 = 0, 1 end
		if f[1] > 0 then gradient(x, 0, band, h, WARM, a0 * math.min(1, f[1]) * glow,
			a1 * math.min(1, f[1]) * glow, true) end
		if f[2] > 0 then gradient(x, 0, band, h, COLD, a0 * math.min(1, f[2]) * glow,
			a1 * math.min(1, f[2]) * glow, true) end
	end
	local fatigue = 1 - s.stamina
	if fatigue > 0.2 then
		local a = (fatigue - 0.2) * 0.6
		gradient(0, 0, w, h * 0.2, { 0, 0, 0 }, a, 0, false)
		gradient(0, h * 0.8, w, h * 0.2, { 0, 0, 0 }, 0, a, false)
	end
	if s.hurt_flash > 0 then
		local a = s.hurt_flash * 0.45
		gradient(0, 0, band, h, { 0.8, 0.05, 0.05 }, a, 0, true)
		gradient(w - band, 0, band, h, { 0.8, 0.05, 0.05 }, 0, a, true)
	end
end
-- }}}

-- view: the front desk's view state (renderer, scenery parts, fx, time).
-- {{{ function M.draw()
function M.draw(battle, view, w, h)
	local s = battle.player
	M.sky(battle.config, w, h)
	local cam = M.camera(battle, s, w, h, view.time)
	renderer.begin_3d(view.renderer, cam)
	renderer.draw_list(view.renderer, view.scenery)
	renderer.draw_list(view.renderer, M.world_parts(battle, view, s, { lock = s.lock }))
	-- the player's own arms and sword, drawn last so nothing hides them
	love.graphics.clear(false, false, true)
	local arms = figures.build({}, s, { cell = battle.config.field.cell_metres,
		clay = battle.config.view.clay_color, team_colors = battle.config.view.team_colors,
		only_arms = true })
	renderer.draw_list(view.renderer, arms)
	renderer.end_3d(view.renderer)
	edges(battle, s, w, h, cam.yaw)
end
-- }}}

return M
