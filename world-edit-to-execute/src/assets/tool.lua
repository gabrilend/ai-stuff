--[[
Asset Tool (Issue 522)

Art out of a map (or, through it, the owner's install), into files other
tools read: textures as PNG, models as GLB (glTF, with their textures
embedded), for Blender, ComfyUI, or an asset pack.

    luajit src/assets/tool.lua texture MAP PATH OUT.png    -- a BLP/TGA as PNG
    luajit src/assets/tool.lua model MAP PATH OUT.glb      -- an MDX (as it stands) as GLB
    luajit src/assets/tool.lua list MAP                    -- the models and textures a map carries

PATH is as the game names it ("Textures\\Footman.blp",
"war3mapImported\\Hero.mdx"); for a map's unnamed files, their listed names
("File00000027.mdx").
]]

local ROOT = (arg[0]:match("^(.*)/src/assets/tool%.lua$")) or "."
package.path = ROOT .. "/src/?.lua;" .. ROOT .. "/src/?/init.lua;" .. package.path

local assets = require("assets")
local mdx = require("parsers.mdx")
local gltf = require("parsers.gltf")
local png = dofile(ROOT .. "/../kanji-learning-image-generator/src/017-write-a-picture.lua")

local cmd, map, path, out = arg[1], arg[2], arg[3], arg[4]

-- {{{ model: MDX -> GLB
-- The geosets shown at the start of Stand, each with its first layer's
-- texture (team colour layers left out; blended parts without a texture of
-- their own, like team glows, left out whole)
local function mdx_to_meshes(A, m)
    local stand = mdx.sequence(m, "stand")
    local hidden = {}
    for _, a in ipairs(m.geoset_animations) do
        local alpha = mdx.sample(a.tracks.KGAO, stand and stand.start or 0, a.alpha, stand and stand.start, stand and stand.finish)
        if (tonumber(alpha) or 1) <= 0.01 then hidden[a.geoset] = true end
    end
    local meshes, pngs = {}, {}
    for gi, g in ipairs(m.geosets) do
        if not hidden[gi - 1] then
            local mesh = { positions = g.vertices, normals = g.normals, uvs = g.uvs[1] or {}, indices = {}, name = "geoset " .. gi }
            local at = 1
            for k, kind in ipairs(g.face_types) do
                local count = g.face_counts[k] or 0
                if kind == 4 then for i = 0, count - 1 do mesh.indices[#mesh.indices + 1] = g.faces[at + i] end end
                at = at + count
            end
            local mat = m.materials[g.material + 1]
            for _, layer in ipairs(mat and mat.layers or {}) do
                local t = m.textures[layer.texture + 1]
                if t and t.replaceable == 0 and t.path ~= "" and not mesh.png then
                    if pngs[t.path] == nil then
                        local img = A:texture(t.path)
                        pngs[t.path] = img and png.encode(img.rgba, img.width, img.height, 4) or false
                    end
                    mesh.png = pngs[t.path] or nil
                    mesh.alpha_test = layer.filter_mode == 1
                end
            end
            -- a blended part without a texture of its own (team glow, a
            -- missing effect texture) would export as a flat solid: left out
            local solid = false
            for _, layer in ipairs(mat and mat.layers or {}) do
                if layer.filter_mode <= 1 then solid = true end
            end
            if #mesh.indices >= 3 and (mesh.png or solid) then meshes[#meshes + 1] = mesh end
        end
    end
    return meshes
end
-- }}}

if cmd == "texture" and out then
    local A = assets.open(map, { root = ROOT })
    local img = A:texture(path) or error("no texture " .. path)
    local f = assert(io.open(out, "wb"))
    f:write(png.encode(img.rgba, img.width, img.height, 4))
    f:close()
    print(string.format("wrote %s (%d x %d)", out, img.width, img.height))
elseif cmd == "model" and out then
    local A = assets.open(map, { root = ROOT })
    local m = A:model(path) or error("no model " .. path)
    local meshes = mdx_to_meshes(A, m)
    local f = assert(io.open(out, "wb"))
    f:write(gltf.encode(meshes, { name = m.name }))
    f:close()
    local textured = 0
    for _, x in ipairs(meshes) do if x.png then textured = textured + 1 end end
    print(string.format("wrote %s: %s, %d meshes (%d textured)", out, m.name, #meshes, textured))
elseif cmd == "list" and map then
    local mpq = require("mpq")
    local a = mpq.open(map)
    for _, n in ipairs(a:list()) do
        local ok, d = pcall(a.extract, a, n)
        if ok and d then
            local kind = d:sub(1, 4) == "MDLX" and "model" or (d:sub(1, 4) == "BLP1" and "texture") or nil
            if kind then
                local extra = ""
                if kind == "model" then
                    local pok, m = pcall(mdx.parse, d)
                    extra = pok and (m.name .. ", " .. #m.geosets .. " geosets") or "unreadable"
                end
                print(kind, n, #d, extra)
            end
        end
    end
    a:close()
else
    print("usage: luajit src/assets/tool.lua texture MAP PATH OUT.png | model MAP PATH OUT.glb | list MAP")
    os.exit(2)
end
