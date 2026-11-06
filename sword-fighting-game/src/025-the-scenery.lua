-- 025-the-scenery.lua
--
-- The ground a battle stands on, built once from the battle's seed and its
-- region: the field and its margin, stones and grass, puddles in a swamp
-- park, fences across a prairie, clouds overhead, and the cat faces the
-- vision asks for, hidden in all of it:
--
--   a cluster of field stones that is two eyes, a nose and whiskers;
--   clouds with two ears.
--
-- (The third, rivets on shields, is pressed by 024-figures.lua.) The same
-- seed always hides the same faces in the same places. None of it carries
-- gameplay. The result is a part list in the shape 024 makes.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local mat = require("021-matrix")

local M = {}

local STONE = { 0.58, 0.56, 0.52 }
local GRASS = { 0.30, 0.50, 0.22 }
local CLOUD = { 0.97, 0.97, 0.99 }
local NOSE = { 0.82, 0.52, 0.52 }
local EYE = { 0.86, 0.80, 0.46 }
local PUPIL = { 0.10, 0.10, 0.10 }
local WATER = { 0.32, 0.46, 0.56 }
local POST = { 0.50, 0.36, 0.22 }

-- {{{ local function put()
local function put(out, shape, x, y, z, sx, sy, sz, color, look, turn)
	local m = mat.translate(x, y, z)
	if turn then m = mat.multiply(m, mat.rotate_y(turn)) end
	m = mat.multiply(m, mat.scale(sx, sy, sz))
	out[#out + 1] = { shape = shape, model = m, sx = sx, sy = sy, sz = sz, color = color,
		look = look }
end
-- }}}

-- {{{ local function shade()
local function shade(c, k)
	return { c[1] * k, c[2] * k, c[3] * k }
end
-- }}}

-- Two eye stones with pupils, a nose stone between and below them, and
-- grass-tuft whiskers either side, lying in the grass.
-- {{{ local function cat_face()
local function cat_face(out, x, z, size, turn)
	local c, s = math.cos(turn), math.sin(turn)
	-- {{{ local function at()
	local function at(across, along)
		return x + c * along - s * across, z + s * along + c * across
	end
	-- }}}
	for _, side in ipairs({ -1, 1 }) do
		local ex, ez = at(side * 0.32 * size, 0.25 * size)
		put(out, "blob", ex, 0.04 * size, ez, 0.16 * size, 0.09 * size, 0.13 * size, EYE, "clay")
		put(out, "blob", ex, 0.1 * size, ez, 0.05 * size, 0.04 * size, 0.07 * size, PUPIL, "brick")
		for k = -1, 1 do
			local wx, wz = at(side * 0.62 * size, -0.05 * size + k * 0.09 * size)
			put(out, "box", wx, 0.02, wz, 0.22 * size, 0.012, 0.012, GRASS, "flat",
				-turn + k * 0.15 * side)
		end
	end
	local nx, nz = at(0, -0.05 * size)
	put(out, "blob", nx, 0.04 * size, nz, 0.09 * size, 0.06 * size, 0.08 * size, NOSE, "clay")
end
-- }}}

-- A cloud is a few blobs, and two of them on top are ears.
-- {{{ local function cloud()
local function cloud(out, stream, x, y, z)
	for k = 0, 3 do
		put(out, "blob", x + (k - 1.5) * 2.2, y + stream:range(-0.3, 0.3), z, 2.0, 1.1, 1.6,
			CLOUD, "flat")
	end
	put(out, "blob", x - 1.3, y + 1.3, z, 0.6, 0.9, 0.5, CLOUD, "flat")
	put(out, "blob", x + 1.3, y + 1.3, z, 0.6, 0.9, 0.5, CLOUD, "flat")
end
-- }}}

-- Stones and faces are kept off the cells the contingents start on.
-- {{{ local function in_deployment()
local function in_deployment(config, cy)
	local f = config.field
	local depth = f.deploy_margin + f.battalion_deep + 1
	return cy < depth or cy > f.height - depth
end
-- }}}

-- {{{ function M.build()
function M.build(config, region, stream)
	local f, cell, out = config.field, config.field.cell_metres, {}
	local w, h = f.width * cell, f.height * cell
	-- the margin beyond the edges is darker, so the edge reads as an edge
	put(out, "box", w / 2, -0.06, h / 2, w * 1.6, 0.05, h * 1.6, shade(region.ground_color, 0.72),
		"flat")
	put(out, "box", w / 2, -0.04, h / 2, w / 2, 0.05, h / 2, region.ground_color, "flat")
	for _ = 1, math.floor(config.view.stones * region.stones) do
		local x, z = stream:range(0, w), stream:range(0, h)
		local r = stream:range(0.05, 0.22)
		put(out, "blob", x, 0, z, r * 1.3, r * 0.7, r, shade(STONE, stream:range(0.8, 1.1)), "clay")
	end
	for _ = 1, 260 do
		local x, z = stream:range(-w * 0.2, w * 1.2), stream:range(-h * 0.2, h * 1.2)
		put(out, "box", x, 0.05, z, 0.015, 0.1, 0.015, shade(GRASS, stream:range(0.8, 1.2)), "flat",
			stream:range(0, 3))
	end
	for _ = 1, region.puddles do
		local x, z = stream:range(0, w), stream:range(0, h)
		put(out, "cylinder", x, -0.005, z, stream:range(0.6, 1.6), 0.01, stream:range(0.5, 1.2),
			WATER, "brick")
	end
	-- fences run along the field's flanks, as the roads across a prairie do
	for k = 1, region.fences do
		local z = h * k / (region.fences + 1)
		for _, x in ipairs({ -1.5, w + 1.5 }) do
			put(out, "box", x, 0.5, z, 0.06, 0.5, 0.06, POST, "clay")
			put(out, "box", x, 0.75, z + 1.2, 0.04, 0.04, 1.2, POST, "clay")
		end
	end
	local placed = 0
	while placed < config.view.cat_faces do
		local cx, cy = stream:between(1, f.width - 2), stream:between(1, f.height - 2)
		if not in_deployment(config, cy) then
			cat_face(out, (cx + 0.5) * cell, (cy + 0.5) * cell, stream:range(1.4, 2.4),
				stream:range(0, math.pi * 2))
			placed = placed + 1
		end
	end
	for _ = 1, config.view.clouds do
		cloud(out, stream, stream:range(-w * 0.3, w * 1.3), stream:range(22, 34),
			stream:range(-h * 0.8, h * 0.6))
	end
	return out
end
-- }}}

-- How many cat faces a part list holds, counted by their noses: for tests.
-- {{{ function M.cat_faces()
function M.cat_faces(parts)
	local n = 0
	for _, p in ipairs(parts) do
		if p.color == NOSE then n = n + 1 end
	end
	return n
end
-- }}}

return M
