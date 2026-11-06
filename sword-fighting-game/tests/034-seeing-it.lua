-- 034-seeing-it.lua
--
-- Tests for the parts of phase 4 that need no window: the matrix
-- arithmetic, the shapes as vertex data, the figures as part lists, and the
-- scenery with its hidden cat faces.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

return function(T)
	local mat = require("021-matrix")
	local meshes = require("022-clay-meshes")
	local figures = require("024-figures")
	local scenery = require("025-the-scenery")
	local battle_m = require("014-the-battle")

	-- A world point to normalised screen coordinates.
	-- {{{ local function project()
	local function project(proj, view, x, y, z)
		local vx, vy, vz, vw = mat.apply(view, x, y, z)
		local cx, cy, _, cw = mat.apply(proj, vx, vy, vz, vw)
		return cx / cw, cy / cw
	end
	-- }}}

	return {
		{ "a point on the centre line lands at the screen centre", function()
			local proj = mat.perspective(math.rad(60), 16 / 9, 0.1, 100)
			local view = mat.look_at(0, 1, 5, 0, 1, 0)
			local sx, sy = project(proj, view, 0, 1, -3)
			T.near(sx, 0, 1e-9, "x")
			T.near(sy, 0, 1e-9, "y")
		end },
		{ "ninety degrees across puts a 45 degree point on the screen edge", function()
			local aspect = 16 / 9
			local proj = mat.perspective(mat.vertical_fov(math.rad(90), aspect), aspect, 0.1, 100)
			local view = mat.look_at(0, 0, 0, 0, 0, -1)
			local sx = project(proj, view, 1, 0, -1)
			T.near(sx, 1, 1e-9, "right edge")
		end },
		{ "multiplying by the identity changes nothing", function()
			local m = mat.translate(1, 2, 3)
			local p = mat.multiply(mat.identity(), m)
			for k = 1, 16 do T.equal(p[k], m[k], "entry " .. k) end
		end },
		{ "every shape is whole triangles with unit normals", function()
			for name, verts in pairs(meshes.all()) do
				T.equal(#verts % 3, 0, name .. " triangles")
				for _, v in ipairs(verts) do
					local l = math.sqrt(v[4] ^ 2 + v[5] ^ 2 + v[6] ^ 2)
					T.near(l, 1, 1e-6, name .. " normal")
				end
			end
		end },
		{ "a figure is built from its record, and the arms alone are fewer parts", function()
			local config, catalogue, streams = T.world()
			local b = battle_m.new({ config = config, catalogue = catalogue, streams = streams,
				region = "meadow" })
			local opts = { cell = 1.2, clay = config.view.clay_color,
				team_colors = config.view.team_colors }
			local whole = figures.build({}, b.soldiers[1], opts)
			opts.only_arms = true
			local arms = figures.build({}, b.soldiers[1], opts)
			T.truthy(#whole > #arms, "whole figure has more parts")
			T.truthy(#arms >= 4, "two arms, a hand and a sword")
		end },
		{ "the sword follows the U", function()
			local left, right = figures.rest_pose(-1), figures.rest_pose(1)
			T.truthy(left[3] < 0 and right[3] > 0, "left arm left, right arm right")
			T.truthy(figures.rest_pose(0)[2] < left[2], "the bend dips below the arms")
		end },
		{ "the same seed builds the same scenery, with every cat face in it", function()
			local config, catalogue = T.world()
			local rs = require("003-random-streams")
			local a = scenery.build(config, catalogue.regions.meadow, rs.new(5, "scenery"))
			local b = scenery.build(config, catalogue.regions.meadow, rs.new(5, "scenery"))
			T.equal(#a, #b, "part count")
			T.equal(a[#a].model[4], b[#b].model[4], "last part placed alike")
			T.equal(scenery.cat_faces(a), config.view.cat_faces, "cat faces")
		end },
	}
end
