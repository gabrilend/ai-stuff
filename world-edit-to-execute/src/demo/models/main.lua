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

Animation (Issue 523): the models play their own sequences, all asked
for the same one in turn (Stand, Walk, Attack, Spell, Death ...), a few
seconds each; a model without the one asked for stands. Every other
sequence a model has (Stand Ready, Attack Slam ...) comes round after
the common ones. MODEL_GALLERY_ANIM=walk plays one only;
MODEL_GALLERY_ANIM=none leaves them in their rest pose.
]]

local render = require("render")
local mpq = require("mpq")
local assets_mod = require("assets")
local gpu = require("assets.gpu")
local mdx = require("parsers.mdx")
local anim = require("assets.anim")

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
        placed[#placed + 1] = { id = id, x = c * spacing, y = -r * spacing, name = e.m.name,
                                rig = cache:rig(id), st = anim.state(i * 0.37) }
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

-- {{{ the programme: the common sequences first, then every other name
-- any model has
local only = os.getenv("MODEL_GALLERY_ANIM")
local programme = { "stand", "walk", "attack", "spell", "stand ready", "death" }
if only and only ~= "" then
    programme = only ~= "none" and { only:lower() } or {}
else
    local listed = {}
    for _, n in ipairs(programme) do listed[n] = true end
    local extra = {}
    for _, p in ipairs(placed) do
        for name in pairs(p.rig and p.rig.by_name or {}) do
            if not listed[name] and not name:find("portrait") then listed[name] = true; extra[#extra + 1] = name end
        end
    end
    table.sort(extra)
    for _, n in ipairs(extra) do programme[#programme + 1] = n end
end
local step, step_time, STEP_LENGTH = 1, 0, 4
local function start_step()
    local name = programme[step]
    local having = 0
    for _, p in ipairs(placed) do
        if p.rig then
            if anim.play(p.rig, p.st, name, { restart = true, fallback = "stand" }) and p.st.name == name then
                having = having + 1
            end
        end
    end
    print(string.format("[gallery] playing %s (%d of %d models have it)", name, having, #placed))
end
if #programme > 0 then start_step() end
-- }}}

local t = 0
function scene_tick(dt)
    t = t + dt
    if #programme == 0 then return end
    step_time = step_time + dt
    if step_time >= STEP_LENGTH then
        step_time, step = 0, step % #programme + 1
        start_step()
    end
    for _, p in ipairs(placed) do
        if p.rig then anim.step(p.rig, p.st, dt) end
    end
end

function scene_paint()
    for k, p in ipairs(placed) do
        -- a slow turn, each its own way round, to show every side
        local facing = t * 0.35 + k
        local team = (k % 12)
        local pose = #programme > 0 and p.rig and anim.pose(p.rig, p.st) or nil
        render.model_draw(p.id, p.x, p.y, 0, facing, 1, 60 + (team * 53) % 196, 90 + (team * 97) % 166, 200 - (team * 31) % 150,
            1, pose)
    end
end

function scene_status()
    local tx, meshes, models, drawn = render.model_stats()
    return string.format("model gallery: %d models, %d drawn this frame, %d textures%s", #placed, drawn, tx,
        #programme > 0 and (", playing " .. programme[step]) or "")
end

function scene_ui()
    if #programme > 0 then render.ui_text(programme[step], 20, 20, 28, 255, 235, 160) end
end

function scene_key(_) end
function scene_ground(_, _) return 0 end
