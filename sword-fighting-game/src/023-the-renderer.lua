-- 023-the-renderer.lua
--
-- Turns the shapes of 022 into engine meshes and owns the one shader that
-- draws them, with three looks:
--
--   clay   a wide wrap-around light, soft sky light from above, and a faint
--          thumbprint wobble in brightness, so it reads as something pressed
--          by hand
--   brick  a sharper light and a small glossy highlight
--   flat   barely lit: the ground, puddles, painted marks
--
-- The camera's projection and view are set once a frame (begin); every draw
-- after that is one shape, one model matrix, one colour and one look. The 3D
-- pass turns the depth test on and end_3d turns it off, so 2D drawing after
-- it is unaffected.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local meshes = require("022-clay-meshes")

local M = {}

M.LOOK = { clay = 0, brick = 1, flat = 2 }

local SHADER = [[
varying vec3 v_normal;
varying vec3 v_world;
uniform mat4 u_proj;
uniform mat4 u_view;
uniform mat4 u_model;
uniform vec3 u_nscale;
uniform vec3 u_light;
uniform vec3 u_eye;
uniform float u_look;
uniform vec3 u_fog_color;
uniform float u_fog;
#ifdef VERTEX
attribute vec3 VertexNormal;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
	vec4 world = u_model * vec4(vertex_position.xyz, 1.0);
	v_world = world.xyz;
	v_normal = mat3(u_model) * (VertexNormal * u_nscale);
	return u_proj * u_view * world;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
	vec3 n = normalize(v_normal);
	float ndl = dot(n, u_light);
	vec3 base = color.rgb;
	vec3 lit;
	if (u_look < 0.5) {
		float wrap = ndl * 0.5 + 0.5;
		float thumb = sin(v_world.x * 31.0 + sin(v_world.y * 23.0) * 2.0)
			* sin(v_world.z * 29.0 + v_world.y * 13.0);
		float sky = n.y * 0.5 + 0.5;
		lit = base * (0.32 + 0.68 * wrap * wrap) * (0.95 + 0.06 * thumb) + base * 0.10 * sky;
	} else if (u_look < 1.5) {
		vec3 v = normalize(u_eye - v_world);
		vec3 h = normalize(u_light + v);
		float spec = pow(max(dot(n, h), 0.0), 48.0);
		lit = base * (0.28 + 0.8 * max(ndl, 0.0)) + vec3(spec * 0.5);
	} else {
		lit = base * (0.78 + 0.22 * max(ndl, 0.0));
	}
	float dist = length(u_eye - v_world);
	float fog = clamp((dist - u_fog) / (u_fog * 1.5), 0.0, 0.65);
	return vec4(mix(lit, u_fog_color, fog), color.a);
}
#endif
]]

local FORMAT = {
	{ "VertexPosition", "float", 3 },
	{ "VertexNormal", "float", 3 },
}

-- Builds the meshes and the shader. Called once, after the window opens.
-- {{{ function M.new()
function M.new()
	local r = { meshes = {}, shader = love.graphics.newShader(SHADER), draws = 0 }
	for name, verts in pairs(meshes.all()) do
		r.meshes[name] = love.graphics.newMesh(FORMAT, verts, "triangles", "static")
	end
	return r
end
-- }}}

-- camera: proj and view matrices, eye position, fog distance and colour.
-- {{{ function M.begin_3d()
function M.begin_3d(r, camera)
	local g = love.graphics
	g.setShader(r.shader)
	g.setDepthMode("lequal", true)
	g.setMeshCullMode("none")
	local s = r.shader
	s:send("u_proj", "row", camera.proj)
	s:send("u_view", "row", camera.view)
	s:send("u_light", { 0.45, 0.78, 0.43 })
	s:send("u_eye", { camera.ex, camera.ey, camera.ez })
	s:send("u_fog", camera.fog)
	s:send("u_fog_color", camera.fog_color)
	r.draws = 0
end
-- }}}

-- One part: the shape's name, its model matrix, a colour {r, g, b[, a]}, the
-- look's name, and the scale on each axis (for turning normals correctly
-- under a stretched shape).
-- {{{ function M.draw()
function M.draw(r, part)
	local s = r.shader
	s:send("u_model", "row", part.model)
	s:send("u_nscale", { 1 / (part.sx * part.sx), 1 / (part.sy * part.sy),
		1 / (part.sz * part.sz) })
	s:send("u_look", M.LOOK[part.look])
	local c = part.color
	love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
	love.graphics.draw(r.meshes[part.shape])
	r.draws = r.draws + 1
end
-- }}}

-- {{{ function M.draw_list()
function M.draw_list(r, parts)
	for k = 1, #parts do M.draw(r, parts[k]) end
end
-- }}}

-- {{{ function M.end_3d()
function M.end_3d(r)
	love.graphics.setShader()
	love.graphics.setDepthMode("always", false)
	love.graphics.setColor(1, 1, 1, 1)
end
-- }}}

return M
