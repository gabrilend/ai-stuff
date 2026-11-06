-- 021-matrix.lua
--
-- Four-by-four matrices: how a point in the world becomes a point on the
-- screen. A matrix is a flat array of 16 numbers in row-major order (entries
-- 1-4 are the first row) and is sent to the shader with the engine's "row"
-- layout, so the arithmetic here reads the way it is written on paper.
--
-- World axes, fixed for the whole project: x east, y up, z south, in metres.
-- A map point (mx, my) in cells is world (mx * cell, ?, my * cell).
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- {{{ function M.identity()
function M.identity()
	return { 1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1 }
end
-- }}}

-- a * b: apply b first, then a.
-- {{{ function M.multiply()
function M.multiply(a, b)
	local c = {}
	for i = 0, 3 do
		for j = 1, 4 do
			c[i * 4 + j] = a[i * 4 + 1] * b[j] + a[i * 4 + 2] * b[4 + j]
				+ a[i * 4 + 3] * b[8 + j] + a[i * 4 + 4] * b[12 + j]
		end
	end
	return c
end
-- }}}

-- {{{ function M.translate()
function M.translate(x, y, z)
	return { 1, 0, 0, x,  0, 1, 0, y,  0, 0, 1, z,  0, 0, 0, 1 }
end
-- }}}

-- {{{ function M.scale()
function M.scale(x, y, z)
	return { x, 0, 0, 0,  0, y, 0, 0,  0, 0, z, 0,  0, 0, 0, 1 }
end
-- }}}

-- About the vertical axis. A figure facing map angle f is turned by -f, so
-- its local +x (forward) points along (cos f, sin f) on the map.
-- {{{ function M.rotate_y()
function M.rotate_y(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0,  0, 1, 0, 0,  -s, 0, c, 0,  0, 0, 0, 1 }
end
-- }}}

-- About the local sideways axis: tips forward-and-up, as a leg swings.
-- {{{ function M.rotate_z()
function M.rotate_z(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, 0,  s, c, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1 }
end
-- }}}

-- {{{ function M.rotate_x()
function M.rotate_x(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0,  0, c, -s, 0,  0, s, c, 0,  0, 0, 0, 1 }
end
-- }}}

-- OpenGL clip space: the vertical field of view in radians.
-- {{{ function M.perspective()
function M.perspective(fovy, aspect, near, far)
	local f = 1 / math.tan(fovy / 2)
	return {
		f / aspect, 0, 0, 0,
		0, f, 0, 0,
		0, 0, (far + near) / (near - far), 2 * far * near / (near - far),
		0, 0, -1, 0,
	}
end
-- }}}

-- The vertical field of view that gives a horizontal one at this aspect:
-- the vision's 90 degrees is across the screen.
-- {{{ function M.vertical_fov()
function M.vertical_fov(horizontal, aspect)
	return 2 * math.atan(math.tan(horizontal / 2) / aspect)
end
-- }}}

-- {{{ local function normalize3()
local function normalize3(x, y, z)
	local l = math.sqrt(x * x + y * y + z * z)
	if l == 0 then return 0, 0, 0 end
	return x / l, y / l, z / l
end
-- }}}

-- {{{ local function cross()
local function cross(ax, ay, az, bx, by, bz)
	return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
end
-- }}}

M.normalize3 = normalize3
M.cross = cross

-- {{{ function M.look_at()
function M.look_at(ex, ey, ez, tx, ty, tz)
	local fx, fy, fz = normalize3(tx - ex, ty - ey, tz - ez)
	local sx, sy, sz = normalize3(cross(fx, fy, fz, 0, 1, 0))
	local ux, uy, uz = cross(sx, sy, sz, fx, fy, fz)
	return {
		sx, sy, sz, -(sx * ex + sy * ey + sz * ez),
		ux, uy, uz, -(ux * ex + uy * ey + uz * ez),
		-fx, -fy, -fz, fx * ex + fy * ey + fz * ez,
		0, 0, 0, 1,
	}
end
-- }}}

-- The matrix times the point (x, y, z, 1): returns x, y, z, w.
-- {{{ function M.apply()
function M.apply(m, x, y, z)
	return m[1] * x + m[2] * y + m[3] * z + m[4],
		m[5] * x + m[6] * y + m[7] * z + m[8],
		m[9] * x + m[10] * y + m[11] * z + m[12],
		m[13] * x + m[14] * y + m[15] * z + m[16]
end
-- }}}

-- A matrix that stretches a unit shape (spanning -1..1 on its y axis) from
-- point a to point b, with radius r across: arms, blades, darts. Returns the
-- matrix and the scale it used, which the renderer needs for normals.
-- {{{ function M.along()
function M.along(ax, ay, az, bx, by, bz, r)
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	local yx, yy, yz = normalize3(dx, dy, dz)
	-- any axis not parallel to the span will do for the first side
	local hx, hy, hz = 0, 1, 0
	if math.abs(yy) > 0.9 then hx, hy, hz = 1, 0, 0 end
	local xx, xy, xz = normalize3(cross(yx, yy, yz, hx, hy, hz))
	local zx, zy, zz = cross(xx, xy, xz, yx, yy, yz)
	local h = len / 2
	return {
		xx * r, yx * h, zx * r, (ax + bx) / 2,
		xy * r, yy * h, zy * r, (ay + by) / 2,
		xz * r, yz * h, zz * r, (az + bz) / 2,
		0, 0, 0, 1,
	}, r, h, r
end
-- }}}

return M
