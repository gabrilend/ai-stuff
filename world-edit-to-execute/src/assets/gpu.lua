--[[
Models onto the GPU (Issue 522c)

A parsed MDX (parsers/mdx.lua) into the renderer's model (render/models.c):
one part per geoset and material layer, with its texture uploaded once
per path.

  shown       every geoset is a part; those their geoset animation hides
              at the start of Stand (death and alternate parts) have
              alpha 0 when drawn without a pose, and show when a
              sequence brings them in (Issue 523)
  textures    a path is read and decoded through the asset source
              (assets/init.lua); replaceable id 1 is the team colour (a
              white texture the draw tints), 2 the team glow (a soft
              round glow, tinted), others their stock replaceable
              texture when the install has it; anything not found is a
              neutral grey on solid layers, so the shape still shows, and
              left out on blended ones (a glow without its texture would
              light up its whole quad)
  skins       a geoset's vertices carry their matrix group, so a pose
              (assets/anim.lua) moves them; without one they stand in the
              model's rest pose. A geoset with more groups than the
              renderer takes (anim.MAX_GROUPS) stays in its rest pose

    local gpu = require("assets.gpu")
    local cache = gpu.new(render, A)                  -- A: assets.open(...)
    local id = cache:build(m, path)                   -- a model id, or nil (nothing drawable)
    render.model_draw(id, x, y, z, facing, scale, r, g, b)
    local rig = cache:rig(id)                         -- to animate it (assets/anim.lua)
]]

local ffi = require("ffi")
local bit = require("bit")
local mdx = require("parsers.mdx")
local anim = require("assets.anim")

local gpu = {}

local C = {}
C.__index = C

-- stock replaceable textures, by id (the install has them)
gpu.REPLACEABLE = {
    [11] = "ReplaceableTextures\\Cliff\\Cliff0.blp",
    [21] = "ReplaceableTextures\\Splats\\LordaeronSummerTreeSplat.blp",
    [31] = "ReplaceableTextures\\LordaeronTree\\LordaeronSummerTree.blp",
    [32] = "ReplaceableTextures\\AshenvaleTree\\AshenTree.blp",
    [33] = "ReplaceableTextures\\BarrensTree\\BarrensTree.blp",
    [34] = "ReplaceableTextures\\NorthrendTree\\NorthTree.blp",
    [35] = "ReplaceableTextures\\Mushroom\\MushroomTree.blp",
    [36] = "ReplaceableTextures\\RuinsTree\\RuinsTree.blp",
    [37] = "ReplaceableTextures\\OutlandMushroomTree\\MushroomTree.blp",
}

-- {{{ gpu.new
function gpu.new(render, assets)
    local self = setmetatable({ render = render, assets = assets, tex = {}, models = {}, built = 0, parts = 0,
                                meta = {}, rigs = {} }, C)
    return self
end
-- }}}

-- {{{ Textures
local function solid(r, g, b, a)
    local px = string.char(r, g, b, a or 255)
    return px:rep(4)
end

function C:solid_texture(key, r, g, b, a)
    if not self.tex[key] then self.tex[key] = self.render.tex_create(2, 2, solid(r, g, b, a)) end
    return self.tex[key]
end

-- a soft round glow, white, for team glow (tinted when drawn)
function C:glow_texture()
    if self.tex["<glow>"] then return self.tex["<glow>"] end
    local n = 64
    local buf = ffi.new("uint8_t[?]", n * n * 4)
    for y = 0, n - 1 do
        for x = 0, n - 1 do
            local dx, dy = (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1
            local a = math.max(0, 1 - math.sqrt(dx * dx + dy * dy))
            local o = (y * n + x) * 4
            buf[o], buf[o + 1], buf[o + 2], buf[o + 3] = 255, 255, 255, math.floor(255 * a * a)
        end
    end
    self.tex["<glow>"] = self.render.tex_create(n, n, ffi.string(buf, n * n * 4))
    return self.tex["<glow>"]
end

-- (texture id, team flag) for a model texture entry
function C:texture(t)
    if not t then return self:solid_texture("<grey>", 150, 146, 140) , 0 end
    if t.replaceable == 1 then return self:solid_texture("<white>", 255, 255, 255), 1 end
    if t.replaceable == 2 then return self:glow_texture(), 1 end
    local path = t.path
    if t.replaceable ~= 0 then path = gpu.REPLACEABLE[t.replaceable] end
    if not path or path == "" then return self:solid_texture("<grey>", 150, 146, 140), 0 end
    local key = path:lower()
    if self.tex[key] == nil then
        local img = self.assets:texture(path)
        if img then
            self.tex[key] = self.render.tex_create(img.width, img.height, img.rgba, t.wrap_width or t.wrap_height)
        else
            self.tex[key] = false
        end
    end
    if self.tex[key] then return self.tex[key], 0 end
    -- missing: trees green, the rest grey (the third value says so)
    if t.replaceable >= 31 and t.replaceable <= 37 then return self:solid_texture("<leaf>", 70, 110, 60), 0, true end
    return self:solid_texture("<grey>", 150, 146, 140), 0, true
end
-- }}}

-- {{{ Geoset alpha at the start of Stand (how it's drawn without a pose)
local function stand_alphas(m)
    local alphas = {}
    local stand = mdx.sequence(m, "stand")
    local frame = stand and stand.start or 0
    for _, a in ipairs(m.geoset_animations) do
        local alpha = mdx.sample(a.tracks.KGAO, frame, a.alpha, stand and stand.start, stand and stand.finish)
        alphas[a.geoset] = tonumber(alpha) or 1
    end
    return alphas
end
-- }}}

-- {{{ Meshes
-- one geoset: interleaved x y z nx ny nz u v floats, and uint16 triangles
local function geoset_arrays(g)
    local nv = #g.vertices / 3
    if nv == 0 or nv > 65535 then return nil end
    local verts = ffi.new("float[?]", nv * 8)
    local uv = g.uvs[1] or {}
    for i = 0, nv - 1 do
        local o = i * 8
        verts[o] = g.vertices[i * 3 + 1]
        verts[o + 1] = g.vertices[i * 3 + 2]
        verts[o + 2] = g.vertices[i * 3 + 3]
        verts[o + 3] = g.normals[i * 3 + 1] or 0
        verts[o + 4] = g.normals[i * 3 + 2] or 0
        verts[o + 5] = g.normals[i * 3 + 3] or 1
        verts[o + 6] = uv[i * 2 + 1] or 0
        verts[o + 7] = uv[i * 2 + 2] or 0
    end
    -- triangles only (face type 4); WC3 models use nothing else
    local tris = {}
    local at = 1
    for k, kind in ipairs(g.face_types) do
        local count = g.face_counts[k] or 0
        if kind == 4 then
            for i = 0, count - 1 do tris[#tris + 1] = g.faces[at + i] end
        end
        at = at + count
    end
    local ni = #tris - #tris % 3
    if ni < 3 then return nil end
    local idx = ffi.new("uint16_t[?]", ni)
    for i = 0, ni - 1 do idx[i] = tris[i + 1] end
    -- each vertex's matrix group, when the renderer can pose them all
    local skin
    local groups = #g.group_sizes
    if groups >= 1 and groups <= anim.MAX_GROUPS and #g.vertex_groups >= nv then
        local sk = ffi.new("uint16_t[?]", nv)
        for i = 0, nv - 1 do
            local k = g.vertex_groups[i + 1]
            if k >= groups then sk = nil; break end
            sk[i] = k
        end
        if sk then skin = ffi.string(sk, nv * 2) end
    end
    return ffi.string(verts, nv * 32), ffi.string(idx, ni * 2), skin, groups
end
-- }}}

-- {{{ C:build
-- The renderer model for a parsed MDX (cached by path); nil when nothing
-- in it can be drawn
function C:build(m, path)
    local key = path and path:lower() or tostring(m)
    if self.models[key] ~= nil then return self.models[key] or nil end
    local shown = stand_alphas(m)
    local parts, meta, skins, skin_groups = {}, {}, {}, {}
    local stand = mdx.sequence(m, "stand")
    for gi, g in ipairs(m.geosets) do
        local verts, idx, skin, groups = geoset_arrays(g)
        if verts then
            local mesh = self.render.mesh_create(verts, idx, skin)
            local slot = 0
            if skin then
                skins[#skins + 1] = gi - 1
                skin_groups[#skin_groups + 1] = groups
                slot = #skins
            end
            local mat = m.materials[g.material + 1]
            local layers = mat and mat.layers or { { filter_mode = 0, shading = 0, texture = 0, alpha = 1, tracks = {} } }
            -- a body: team colour under a blended skin (WC3's usual
            -- layering). With the skin missing, a solid grey body
            -- stands in (the team colour would show as a flat fill)
            local has_team = false
            for _, layer in ipairs(layers) do
                local t = m.textures[layer.texture + 1]
                if t and t.replaceable == 1 then has_team = true end
            end
            if has_team then
                local body = {}
                local skin_missing = false
                for _, layer in ipairs(layers) do
                    local t = m.textures[layer.texture + 1]
                    if t and t.replaceable ~= 1 and t.replaceable ~= 2 then
                        local _, _, missing = self:texture(t)
                        if missing then skin_missing = true end
                    end
                end
                if skin_missing then
                    for _, layer in ipairs(layers) do
                        local t = m.textures[layer.texture + 1]
                        if not (t and t.replaceable == 1) then
                            local copy = {}
                            for k, v in pairs(layer) do copy[k] = v end
                            copy.filter_mode = 0
                            body[#body + 1] = copy
                        end
                    end
                    layers = body
                end
            end
            for _, layer in ipairs(layers) do
                local tex, team, missing = self:texture(m.textures[layer.texture + 1])
                local alpha = mdx.sample(layer.tracks.KMTA, stand and stand.start or 0, layer.alpha,
                    stand and stand.start, stand and stand.finish)
                -- a stand-in colour only where the layer is solid: a
                -- blended one (glows, runes, auras) without its texture
                -- would light up its whole quad
                if missing and layer.filter_mode >= 2 then
                    self.skipped = (self.skipped or 0) + 1
                else
                    parts[#parts + 1] = {
                        mesh = mesh, tex = tex, team = team, filter = layer.filter_mode,
                        two_sided = bit.band(layer.shading, 16) ~= 0,
                        unshaded = bit.band(layer.shading, 1) ~= 0,
                        alpha = (tonumber(alpha) or 1) * (shown[gi - 1] or 1),
                        skin = slot,
                    }
                    meta[#meta + 1] = { geoset = gi - 1, layer = layer }
                end
            end
        end
    end
    if #parts == 0 then
        self.models[key] = false
        return nil
    end
    local id = self.render.model_create(parts, skin_groups)
    self.models[key] = id
    self.meta[id] = { m = m, parts = meta, skins = skins }
    self.built = self.built + 1
    self.parts = self.parts + #parts
    return id
end
-- }}}

-- {{{ C:rig
-- The model's rig for animation (assets/anim.lua), built when first asked;
-- nil for models that aren't MDX
function C:rig(id)
    if not id then return nil end
    local r = self.rigs[id]
    if r == nil then
        local meta = self.meta[id]
        r = meta and anim.rig(meta.m, meta.parts, meta.skins) or false
        self.rigs[id] = r
    end
    return r or nil
end
-- }}}

-- {{{ C:build_meshes
-- The renderer model for plain meshes (a glTF's, parsers/gltf.lua):
-- { { positions, normals, uvs, indices (0-based), image or nil, color }, ... }
function C:build_meshes(meshes, key)
    if key and self.models[key] ~= nil then return self.models[key] or nil end
    local parts = {}
    for i, m in ipairs(meshes) do
        local nv = #m.positions / 3
        if nv > 0 and nv <= 65535 and #m.indices >= 3 then
            local verts = ffi.new("float[?]", nv * 8)
            for v = 0, nv - 1 do
                local o = v * 8
                verts[o], verts[o + 1], verts[o + 2] = m.positions[v * 3 + 1], m.positions[v * 3 + 2], m.positions[v * 3 + 3]
                verts[o + 3], verts[o + 4], verts[o + 5] = m.normals[v * 3 + 1] or 0, m.normals[v * 3 + 2] or 0, m.normals[v * 3 + 3] or 1
                verts[o + 6], verts[o + 7] = m.uvs[v * 2 + 1] or 0, m.uvs[v * 2 + 2] or 0
            end
            local ni = #m.indices - #m.indices % 3
            local idx = ffi.new("uint16_t[?]", ni)
            for k = 0, ni - 1 do idx[k] = m.indices[k + 1] end
            local mesh = self.render.mesh_create(ffi.string(verts, nv * 32), ffi.string(idx, ni * 2))
            local tex
            if m.image then
                tex = self.render.tex_create(m.image.width, m.image.height, m.image.rgba, true)
            else
                local c = m.color or { 0.7, 0.7, 0.7, 1 }
                tex = self:solid_texture(string.format("<rgb %d %d %d>", c[1] * 255, c[2] * 255, c[3] * 255),
                    math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
            end
            parts[#parts + 1] = { mesh = mesh, tex = tex, team = 0, two_sided = true,
                                  filter = m.alpha_mode == "MASK" and 1 or (m.alpha_mode == "BLEND" and 2 or 0) }
        end
    end
    local id = #parts > 0 and self.render.model_create(parts) or nil
    if key then self.models[key] = id or false end
    return id
end
-- }}}

return gpu
