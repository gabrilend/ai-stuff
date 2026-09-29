--[[
Model Gallery (Issue 522e)

Every model a map carries (imported MDX files), or the install's models
named on the command line, set out in rows on flat ground with their
textures, as the in-engine renderer draws them (render/models.c,
assets/gpu.lua). A proof of the decoders and the renderer that doesn't
need a map's layout.

    src/render/run-map MAP ROOT   # (the map viewer)
    scene_viewer ROOT src/demo/models/main.lua MAP     # this gallery

MODEL_GALLERY_SPACING (default 420) sets the distance between models;
MODEL_GALLERY_TEXTURED=1 keeps only models whose textures are all found;
MODEL_GALLERY_GLB="a.glb b.glb" adds glTF models (MODEL_GALLERY_GLB_HEIGHT
fits them to a height).
]]

local render = require("render")
local mpq = require("mpq")
local assets_mod = require("assets")
local gpu = require("assets.gpu")
local mdx = require("parsers.mdx")

local ROOT = SCENE_ROOT or "."
local path = SCENE_ARG or (ROOT .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
local spacing = tonumber(os.getenv("MODEL_GALLERY_SPACING") or "") or 420

local A = assets_mod.open(path, { root = ROOT })
local cache = gpu.new(render, A)

-- every model stored in the map (named or not)
local archive = mpq.open(path)
local entries = {}
local seen = {}
for _, name in ipairs(archive:list()) do
    local ok, data = pcall(archive.extract, archive, name)
    if ok and data and data:sub(1, 4) == "MDLX" and not seen[data] then
        seen[data] = true
        local pok, m = pcall(mdx.parse, data)
        -- portrait models (the interface's talking heads) have a backdrop
        -- quad and never stand in the world: left out
        local portrait = pok and (m.name or ""):lower():find("portrait")
        if pok and not portrait then
            for _, sq in ipairs(m.sequences) do
                if sq.name:lower():find("portrait") then portrait = true end
            end
        end
        -- MODEL_GALLERY_TEXTURED=1: only models whose textures are all found
        local complete = true
        if pok and os.getenv("MODEL_GALLERY_TEXTURED") == "1" then
            for _, t in ipairs(m.textures) do
                if t.replaceable == 0 and t.path ~= "" and not A:texture(t.path) then complete = false end
            end
        end
        if pok and not portrait and complete then entries[#entries + 1] = { name = name, m = m } end
    end
end
archive:close()

-- GLB/glTF files too (MODEL_GALLERY_GLB="a.glb b.glb"): exported
-- models, or what ComfyUI's image-to-3D saves (fitted to 160 units tall)
local glb_list = {}
for f in (os.getenv("MODEL_GALLERY_GLB") or ""):gmatch("%S+") do
    local fh = io.open(f, "rb")
    if fh then
        local bytes = fh:read("*a")
        fh:close()
        local gok, g = pcall(require("parsers.gltf").decode, bytes, { height = tonumber(os.getenv("MODEL_GALLERY_GLB_HEIGHT") or "") })
        if gok then glb_list[#glb_list + 1] = { name = f, g = g } else print("[gallery] " .. f .. ": " .. tostring(g)) end
    end
end

-- lay them out, biggest last so the small ones aren't hidden
table.sort(entries, function(a, b)
    local ra = a.m.extent and a.m.extent.radius or 0
    local rb = b.m.extent and b.m.extent.radius or 0
    return ra < rb
end)
local cols = math.max(1, math.ceil(math.sqrt(#entries)))
local placed, parts = {}, 0
for i, e in ipairs(entries) do
    local id = cache:build(e.m, e.name)
    if id then
        local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
        placed[#placed + 1] = { id = id, x = c * spacing, y = -r * spacing, name = e.m.name }
    end
end
for _, e in ipairs(glb_list) do
    local id = cache:build_meshes(e.g.meshes, e.name)
    if id then
        local i = #placed
        local c, r = i % cols, math.floor(i / cols)
        placed[#placed + 1] = { id = id, x = c * spacing, y = -r * spacing, name = e.name }
    end
end
print(string.format("[gallery] %d models in the map, %d drawable, %d parts, %d textures decoded (%d missing)",
    #entries, #placed, cache.parts, A:report().textures, A:report().missing))

CAMERA_START = { spacing * 3, -spacing * 3, 1600 }

local t = 0
function scene_tick(dt) t = t + dt end

function scene_paint()
    for k, p in ipairs(placed) do
        -- a slow turn, each its own way round, to show every side
        local facing = t * 0.35 + k
        local team = (k % 12)
        render.model_draw(p.id, p.x, p.y, 0, facing, 1, 60 + (team * 53) % 196, 90 + (team * 97) % 166, 200 - (team * 31) % 150)
    end
end

function scene_status()
    local tx, meshes, models, drawn = render.model_stats()
    return string.format("model gallery: %d models, %d drawn this frame, %d textures", #placed, drawn, tx)
end

function scene_key(_) end
function scene_ground(_, _) return 0 end
