-- 024-figures.lua
--
-- A clay soldier in brick armor, built from one soldier record and nothing
-- else. The result is a list of parts the renderer draws: { shape, model,
-- sx, sy, sz, color, look }.
--
-- Every figure is built in its own frame first, in metres: x forward, y up,
-- z to the right, feet at the origin. The frame is then placed on the field,
-- turned to the soldier's facing and scaled by its height.
--
-- The sword is posed from the record: at rest it sits on the U; during a
-- swing it travels from the rest pose to the kind's windup pose, then sweeps
-- to its strike pose as the windup ends, and returns during the recovery.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local mat = require("021-matrix")
local the_u = require("009-the-u")
local swings = require("010-swings")

local M = {}

local DARK = { 0.12, 0.09, 0.08 }
local WOOD = { 0.55, 0.38, 0.22 }
local GREY = { 0.55, 0.55, 0.55 }

-- Hand poses: where the grip is and which way the blade points, in the
-- figure's frame. Slashes are written from the left; the right is mirrored.
local POSES = {
	guard = { 0.38, 1.25, 0.0, 0.25, 0.45, -0.85 },
	stab = { wind = { 0.12, 1.05, 0.05, 1, 0.15, 0 }, strike = { 0.85, 1.15, 0, 1, 0.05, 0 } },
	slash = { wind = { 0.22, 1.5, -0.42, 0.3, 0.9, -0.4 },
		strike = { 0.6, 1.0, 0.35, 0.8, -0.1, 0.6 } },
	overhead = { wind = { 0.05, 1.9, 0, -0.4, 1, 0 }, strike = { 0.65, 0.95, 0, 1, -0.35, 0 } },
}

-- {{{ local function part()
local function part(out, base, shape, local_m, sx, sy, sz, color, look)
	out[#out + 1] = { shape = shape, model = mat.multiply(base, local_m), sx = sx, sy = sy,
		sz = sz, color = color, look = look }
end
-- }}}

-- {{{ local function blob_at()
local function blob_at(out, base, x, y, z, sx, sy, sz, color, look)
	part(out, base, "blob", mat.multiply(mat.translate(x, y, z), mat.scale(sx, sy, sz)),
		sx, sy, sz, color, look or "clay")
end
-- }}}

-- {{{ local function shape_at()
local function shape_at(out, base, shape, x, y, z, sx, sy, sz, color, look)
	part(out, base, shape, mat.multiply(mat.translate(x, y, z), mat.scale(sx, sy, sz)),
		sx, sy, sz, color, look)
end
-- }}}

-- A shape stretched from one point to another in the figure's frame.
-- {{{ local function span()
local function span(out, base, shape, a, b, r, color, look)
	local m, sx, sy, sz = mat.along(a[1], a[2], a[3], b[1], b[2], b[3], r)
	part(out, base, shape, m, sx, sy, sz, color, look)
end
-- }}}

-- {{{ local function mirror()
local function mirror(p, side)
	if side ~= "right" then return p end
	return { p[1], p[2], -p[3], p[4], p[5], -p[6] }
end
-- }}}

-- {{{ local function lerp_pose()
local function lerp_pose(a, b, t)
	t = t * t * (3 - 2 * t)
	local p = {}
	for k = 1, 6 do p[k] = util.lerp(a[k], b[k], t) end
	return p
end
-- }}}

-- The grip on the U: the arms of the U rise beside the target, the bend dips
-- in front of it.
-- {{{ function M.rest_pose()
function M.rest_pose(u)
	local lateral, lift = the_u.shape(u)
	return { 0.42, 1.0 + lift * 0.5, lateral * 0.32, 0.75, 0.25 + lift * 0.9, lateral * 0.35 }
end
-- }}}

-- {{{ function M.hand_pose()
function M.hand_pose(s)
	local rest = M.rest_pose(s.u)
	if s.guard then return POSES.guard end
	local w = s.swing
	if not w then return rest end
	local row = POSES[w.kind]
	local wind, strike = mirror(row.wind, w.side), mirror(row.strike, w.side)
	local phase, p = swings.progress(w)
	-- windup: to the windup pose, then the sweep to the strike as it ends
	if phase == "windup" then
		if p < 0.7 then return lerp_pose(rest, wind, p / 0.7) end
		return lerp_pose(wind, strike, (p - 0.7) / 0.3)
	end
	return lerp_pose(strike, rest, p)
end
-- }}}

-- The torso's frame: leans forward with fatigue, pivoting at the hips.
-- {{{ local function torso()
local function torso(s)
	local lean = (1 - s.stamina) * 0.28
	return mat.multiply(mat.translate(0, 0.85, 0),
		mat.multiply(mat.rotate_z(-lean), mat.translate(0, -0.85, 0)))
end
-- }}}

-- {{{ local function at_torso()
local function at_torso(t, x, y, z)
	local px, py, pz = mat.apply(t, x, y, z)
	return { px, py, pz }
end
-- }}}

-- {{{ local function add_sword()
local function add_sword(out, base, s, pose, team_color)
	local g = { pose[1], pose[2], pose[3] }
	local dx, dy, dz = mat.normalize3(pose[4], pose[5], pose[6])
	local len = s.weapon.length
	local guard_at = { g[1] + dx * 0.1, g[2] + dy * 0.1, g[3] + dz * 0.1 }
	local tip = { g[1] + dx * len, g[2] + dy * len, g[3] + dz * len }
	local stabs = s.weapon_name == "spear"
	-- a spear is a wooden shaft with a brick head; a sword a brick blade
	if stabs then
		span(out, base, "cylinder", { g[1] - dx * 0.5, g[2] - dy * 0.5, g[3] - dz * 0.5 },
			tip, 0.025, WOOD, "clay")
		span(out, base, "box", { tip[1] - dx * 0.2, tip[2] - dy * 0.2, tip[3] - dz * 0.2 },
			{ tip[1] + dx * 0.05, tip[2] + dy * 0.05, tip[3] + dz * 0.05 }, 0.04,
			s.weapon.brick_color, "brick")
		return
	end
	span(out, base, "box", guard_at, tip, 0.032, s.weapon.brick_color, "brick")
	local px, py, pz = mat.normalize3(mat.cross(dx, dy, dz, 0, 1, 0))
	if px == 0 and py == 0 and pz == 0 then px, py, pz = 0, 0, 1 end
	span(out, base, "box", { guard_at[1] - px * 0.15, guard_at[2] - py * 0.15,
		guard_at[3] - pz * 0.15 }, { guard_at[1] + px * 0.15, guard_at[2] + py * 0.15,
		guard_at[3] + pz * 0.15 }, 0.03, team_color, "brick")
	blob_at(out, base, g[1] - dx * 0.16, g[2] - dy * 0.16, g[3] - dz * 0.16, 0.045, 0.045,
		0.045, team_color, "brick")
end
-- }}}

-- More armor is more bricks: a chest plate always, shoulders from two
-- points, a helmet from three; thick armor makes every plate bigger.
-- {{{ local function add_armor()
local function add_armor(out, base, t, s, color)
	local k = s.thickness == 1 and 1.25 or 1
	if s.armor >= 1 then
		part(out, base, "brick", mat.multiply(t, mat.multiply(mat.translate(0.19, 1.2, 0),
			mat.scale(0.06 * k, 0.15 * k, 0.19 * k))), 0.06 * k, 0.15 * k, 0.19 * k,
			color, "brick")
	end
	if s.armor >= 2 then
		for _, z in ipairs({ -0.27, 0.27 }) do
			part(out, base, "brick", mat.multiply(t, mat.multiply(mat.translate(0, 1.5, z),
				mat.scale(0.1 * k, 0.05 * k, 0.09 * k))), 0.1 * k, 0.05 * k, 0.09 * k,
				color, "brick")
		end
	end
	if s.armor >= 3 then
		part(out, base, "brick", mat.multiply(t, mat.multiply(mat.translate(0.02, 1.86, 0),
			mat.scale(0.15, 0.05, 0.15))), 0.15, 0.05, 0.15, color, "brick")
	end
end
-- }}}

-- A round shield on the left arm, its rivets pressed in a cat's face.
-- {{{ local function add_shield()
local function add_shield(out, base, t, color)
	local disc = mat.multiply(t, mat.multiply(mat.translate(0.32, 1.15, -0.34),
		mat.multiply(mat.rotate_z(math.pi / 2), mat.scale(0.3, 0.025, 0.3))))
	part(out, base, "cylinder", disc, 0.3, 0.025, 0.3, color, "brick")
	local rivets = { { 0.07, -0.09 }, { 0.07, 0.09 }, { -0.02, 0 }, { 0.2, -0.16 }, { 0.2, 0.16 } }
	for _, r in ipairs(rivets) do
		local p = at_torso(t, 0.35, 1.15 + r[1], -0.34 + r[2])
		blob_at(out, base, p[1], p[2], p[3], 0.022, 0.022, 0.022, DARK, "brick")
	end
end
-- }}}

-- The figure's frame on the field. Lying down (tripped or fallen) tips it
-- onto its back.
-- {{{ local function base_matrix()
local function base_matrix(s, cell)
	local m = mat.multiply(mat.translate(s.x * cell, 0, s.y * cell), mat.rotate_y(-s.facing))
	m = mat.multiply(m, mat.scale(s.height, s.height, s.height))
	if s.tripped > 0 or not s.alive then
		m = mat.multiply(m, mat.multiply(mat.translate(0, 0.18, 0), mat.rotate_z(math.pi / 2)))
	end
	return m
end
-- }}}

-- {{{ local function tint()
local function tint(c, k, grey)
	if grey then return { util.lerp(c[1], GREY[1], 0.6) * k, util.lerp(c[2], GREY[2], 0.6) * k,
		util.lerp(c[3], GREY[3], 0.6) * k } end
	return { math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k) }
end
-- }}}

-- opts: cell (metres per cell), clay ({r,g,b}), team_colors, only_arms
-- (first person: the player's own arms and sword), bright (the lock),
-- pennant (mark the player in third person).
-- {{{ function M.build()
function M.build(out, s, opts)
	local base = base_matrix(s, opts.cell)
	local dead = not s.alive
	local k = (opts.bright and 1.18 or 1) * (1 - 0.06 * (s.id % 3))
	local clay = tint(opts.clay, k, dead)
	local team = tint(opts.team_colors[s.team], opts.bright and 1.2 or 1, dead)
	local t = torso(s)
	local pose = M.hand_pose(s)
	local grip = { pose[1], pose[2], pose[3] }
	-- arms reach from the shoulders to the grip, both hands on the hilt
	for _, z in ipairs({ -0.24, 0.24 }) do
		local shoulder = at_torso(t, 0.02, 1.42, z)
		span(out, base, "blob", shoulder, grip, 0.065, clay, "clay")
	end
	blob_at(out, base, grip[1], grip[2], grip[3], 0.075, 0.07, 0.075, clay)
	add_sword(out, base, s, pose, team)
	if opts.only_arms then return out end
	-- legs swing with the distance walked
	local stride = math.sin(s.distance_walked * 3.4) * 0.45
	for side, z in ipairs({ -0.12, 0.12 }) do
		local a = side == 1 and stride or -stride
		local foot = { math.sin(a) * 0.8, 0.85 - math.cos(a) * 0.8, z }
		span(out, base, "blob", { 0, 0.85, z }, foot, 0.1, clay, "clay")
		blob_at(out, base, foot[1] + 0.05, foot[2], foot[3], 0.13, 0.06, 0.09, team, "brick")
	end
	-- the body squashes as health is lost: a dent in the clay
	local hp = util.clamp(s.health / s.health_max, 0, 1)
	local body = mat.multiply(t, mat.multiply(mat.translate(0, 1.18, 0),
		mat.scale(0.2, 0.36 * (0.8 + 0.2 * hp), 0.26)))
	part(out, base, "blob", body, 0.2, 0.36, 0.26, clay, "clay")
	local head = at_torso(t, 0.02, 1.7, 0)
	blob_at(out, base, head[1], head[2], head[3], 0.16, 0.17, 0.16, clay)
	-- the face: two dots and a line
	for _, z in ipairs({ -0.055, 0.055 }) do
		local e = at_torso(t, 0.155, 1.73, z)
		blob_at(out, base, e[1], e[2], e[3], 0.022, 0.026, 0.022, DARK, "brick")
	end
	local mouth = at_torso(t, 0.16, 1.645, 0)
	shape_at(out, base, "box", mouth[1], mouth[2], mouth[3], 0.01, 0.008, 0.04, DARK, "flat")
	add_armor(out, base, t, s, team)
	if s.traits.shield then add_shield(out, base, t, team) end
	if opts.pennant then
		span(out, base, "cylinder", { 0, 2.0, 0 }, { 0, 2.6, 0 }, 0.015, WOOD, "clay")
		shape_at(out, base, "brick", 0.12, 2.5, 0, 0.12, 0.07, 0.015, { 1, 0.85, 0.2 }, "brick")
	end
	return out
end
-- }}}

return M
