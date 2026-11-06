-- 022-clay-meshes.lua
--
-- The shapes everything is pressed from, as plain vertex data: lists of
-- triangles whose vertices are rows { x, y, z, nx, ny, nz }. No engine call
-- is made here, so the shapes can be built and checked without a window.
--
-- Each shape is unit-sized and centred, built once at start-up, and drawn at
-- any size and place by its model matrix:
--
--   blob      a sphere of radius 1: clay heads, bodies, limbs, stones, clouds
--   box       a cube from -1 to 1: blades, fences, the ground
--   brick     a box with four studs on top: armor plates
--   cylinder  radius 1, height -1..1: studs, pommels, shields, puddles
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- {{{ local function push()
local function push(out, x, y, z, nx, ny, nz)
	out[#out + 1] = { x, y, z, nx, ny, nz }
end
-- }}}

-- Latitude rings by longitude segments; the normal of a unit sphere is its
-- position.
-- {{{ function M.blob()
function M.blob(rings, segments)
	rings, segments = rings or 10, segments or 14
	local out = {}
	-- {{{ local function at()
	local function at(r, s)
		local phi = math.pi * r / rings
		local theta = 2 * math.pi * s / segments
		local x = math.sin(phi) * math.cos(theta)
		local y = math.cos(phi)
		local z = math.sin(phi) * math.sin(theta)
		return x, y, z
	end
	-- }}}
	for r = 0, rings - 1 do
		for s = 0, segments - 1 do
			local ax, ay, az = at(r, s)
			local bx, by, bz = at(r + 1, s)
			local cx, cy, cz = at(r + 1, s + 1)
			local dx, dy, dz = at(r, s + 1)
			push(out, ax, ay, az, ax, ay, az)
			push(out, bx, by, bz, bx, by, bz)
			push(out, cx, cy, cz, cx, cy, cz)
			push(out, ax, ay, az, ax, ay, az)
			push(out, cx, cy, cz, cx, cy, cz)
			push(out, dx, dy, dz, dx, dy, dz)
		end
	end
	return out
end
-- }}}

-- The six faces of a cube: the normal, then two axes spanning the face.
local FACES = {
	{ 1, 0, 0,  0, 1, 0,  0, 0, 1 }, { -1, 0, 0,  0, 0, 1,  0, 1, 0 },
	{ 0, 1, 0,  0, 0, 1,  1, 0, 0 }, { 0, -1, 0,  1, 0, 0,  0, 0, 1 },
	{ 0, 0, 1,  1, 0, 0,  0, 1, 0 }, { 0, 0, -1,  0, 1, 0,  1, 0, 0 },
}

-- A box centred at (cx, cy, cz) with half-sizes (hx, hy, hz).
-- {{{ local function add_box()
local function add_box(out, cx, cy, cz, hx, hy, hz)
	for _, f in ipairs(FACES) do
		local nx, ny, nz = f[1], f[2], f[3]
		local corners = {}
		for k, uv in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			local x = nx + f[4] * uv[1] + f[7] * uv[2]
			local y = ny + f[5] * uv[1] + f[8] * uv[2]
			local z = nz + f[6] * uv[1] + f[9] * uv[2]
			corners[k] = { cx + x * hx, cy + y * hy, cz + z * hz }
		end
		for _, k in ipairs({ 1, 2, 3, 1, 3, 4 }) do
			local p = corners[k]
			push(out, p[1], p[2], p[3], nx, ny, nz)
		end
	end
	return out
end
-- }}}

-- {{{ local function add_cylinder()
local function add_cylinder(out, cx, cy, cz, r, h, segments)
	for s = 0, segments - 1 do
		local a0 = 2 * math.pi * s / segments
		local a1 = 2 * math.pi * (s + 1) / segments
		local x0, z0, x1, z1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
		-- the side, two triangles
		push(out, cx + x0 * r, cy - h, cz + z0 * r, x0, 0, z0)
		push(out, cx + x1 * r, cy - h, cz + z1 * r, x1, 0, z1)
		push(out, cx + x1 * r, cy + h, cz + z1 * r, x1, 0, z1)
		push(out, cx + x0 * r, cy - h, cz + z0 * r, x0, 0, z0)
		push(out, cx + x1 * r, cy + h, cz + z1 * r, x1, 0, z1)
		push(out, cx + x0 * r, cy + h, cz + z0 * r, x0, 0, z0)
		-- the top and the bottom
		push(out, cx, cy + h, cz, 0, 1, 0)
		push(out, cx + x0 * r, cy + h, cz + z0 * r, 0, 1, 0)
		push(out, cx + x1 * r, cy + h, cz + z1 * r, 0, 1, 0)
		push(out, cx, cy - h, cz, 0, -1, 0)
		push(out, cx + x1 * r, cy - h, cz + z1 * r, 0, -1, 0)
		push(out, cx + x0 * r, cy - h, cz + z0 * r, 0, -1, 0)
	end
	return out
end
-- }}}

-- {{{ function M.box()
function M.box()
	return add_box({}, 0, 0, 0, 1, 1, 1)
end
-- }}}

-- {{{ function M.cylinder()
function M.cylinder(segments)
	return add_cylinder({}, 0, 0, 0, 1, 1, segments or 16)
end
-- }}}

-- A box with a two-by-two grid of studs on its top face, the way the
-- bricks in the vision's armor are made.
-- {{{ function M.brick()
function M.brick()
	local out = add_box({}, 0, 0, 0, 1, 1, 1)
	for _, p in ipairs({ { -0.5, -0.5 }, { 0.5, -0.5 }, { 0.5, 0.5 }, { -0.5, 0.5 } }) do
		add_cylinder(out, p[1], 1.12, p[2], 0.3, 0.12, 10)
	end
	return out
end
-- }}}

-- Every shape, by name, built once.
-- {{{ function M.all()
function M.all()
	return { blob = M.blob(), box = M.box(), brick = M.brick(), cylinder = M.cylinder() }
end
-- }}}

return M
