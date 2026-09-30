--[[
ComfyUI Workflows for Game Art (Issue 522f)

Workflow files for ComfyUI that make art this engine can use, built with
ComfyUI's own nodes only (no custom node packs, no Python of ours). Each
is written twice, as ComfyUI reads two shapes that aren't
interchangeable:

  <name>.api.json   the /prompt shape: nodes by id, inputs by name; what a
                    script posts (curl -d @file, or luasocket)
  <name>.ui.json    the editor's shape: nodes with positions, links, and
                    widget values in drawing order; drag it onto the canvas

The graphs are described once and written by the graph writer the
kanji-learning-image-generator project already has
(src/028-the-shape-of-a-graph.lua, which knows both shapes and the
widget-order traps). This file adds the node types it needs to that
writer's catalogue.

Workflows (comfyui/workflows/):

  icon                 a command-card icon: a picture from a prompt, and
                       the same scaled to 64 x 64 (WC3's button size)
  texture-restyle      a texture (exported with `export` below) redrawn
                       from a prompt, its layout kept by starting from it
                       (image to image, partial denoise)
  texture-restyle-lines  the same, its outlines held by a Canny ControlNet
                       (for model skins, whose islands must stay put)
  ground-tile          a top-down ground texture from a prompt (seamless
                       tiling is the engine's own post-pass, not a node)
  portrait-art         a character picture for a portrait or loading screen
  model-from-image     a 3D model (GLB) from one picture, with ComfyUI's
                       built-in Hunyuan3D 2 nodes

Every node's sockets and controls here were checked against ComfyUI's own
source (commit a716932, 2026-09-29: nodes.py, comfy_extras/nodes_canny.py,
nodes_hunyuan3d.py, nodes_save_3d.py, nodes_model_advanced.py,
nodes_video_model.py). ComfyUI changes; `check` compares the files with
the ComfyUI you actually run.

Model file names (checkpoints, ControlNet, Hunyuan3D) are in
comfyui/settings.lua: rename them to what your install has, then write
again.

    luajit src/assets/comfy.lua write                  -- all workflows into comfyui/workflows/
    luajit src/assets/comfy.lua check object_info.json -- every node and input known to your ComfyUI?
         (object_info.json: curl http://127.0.0.1:8188/object_info > object_info.json)
    luajit src/assets/comfy.lua export MAP PATH OUT.png  -- a map's (or the install's) texture as PNG
]]

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
local ROOT = HERE:gsub("/?src/assets$", "")
if ROOT == "" then ROOT = "." end
local MONOREPO = ROOT .. "/.."
local KANJI = MONOREPO .. "/kanji-learning-image-generator/src"

local comfy = {}

-- {{{ The graph writer (kanji project) and its catalogue additions
local graph_mod
local json

local function load_writer()
    if graph_mod then return end
    graph_mod = dofile(KANJI .. "/028-the-shape-of-a-graph.lua")
    local project = dofile(KANJI .. "/009-where-things-are.lua")
    json = project.load("018-write-the-numbers")
    local cat = graph_mod.catalogue()
    -- ComfyUI core nodes this project uses beyond the kanji project's
    -- dozen: sockets in order, controls in drawing order
    local add = {
        ImageScale = {
            inputs = { { "image", "IMAGE" } },
            outputs = { { "IMAGE", "IMAGE" } },
            widgets = { { "upscale_method", "lanczos" }, { "width", 64 }, { "height", 64 }, { "crop", "disabled" } },
        },
        VAEEncode = {
            inputs = { { "pixels", "IMAGE" }, { "vae", "VAE" } },
            outputs = { { "LATENT", "LATENT" } },
            widgets = {},
        },
        Canny = {
            inputs = { { "image", "IMAGE" } },
            outputs = { { "IMAGE", "IMAGE" } },
            widgets = { { "low_threshold", 0.4 }, { "high_threshold", 0.8 } },
        },
        -- Hunyuan3D 2 (comfy_extras/nodes_hunyuan3d.py and friends)
        ImageOnlyCheckpointLoader = {
            inputs = {},
            outputs = { { "MODEL", "MODEL" }, { "CLIP_VISION", "CLIP_VISION" }, { "VAE", "VAE" } },
            widgets = { { "ckpt_name", "" } },
        },
        CLIPVisionEncode = {
            inputs = { { "clip_vision", "CLIP_VISION" }, { "image", "IMAGE" } },
            outputs = { { "CLIP_VISION_OUTPUT", "CLIP_VISION_OUTPUT" } },
            widgets = { { "crop", "center" } },
        },
        ModelSamplingAuraFlow = {
            inputs = { { "model", "MODEL" } },
            outputs = { { "MODEL", "MODEL" } },
            -- sampling is optional (an "advanced" control): drawn, so listed
            widgets = { { "shift", 1.0 }, { "sampling", "flow" } },
        },
        Hunyuan3Dv2Conditioning = {
            inputs = { { "clip_vision_output", "CLIP_VISION_OUTPUT" } },
            outputs = { { "positive", "CONDITIONING" }, { "negative", "CONDITIONING" } },
            widgets = {},
        },
        EmptyLatentHunyuan3Dv2 = {
            inputs = {},
            outputs = { { "LATENT", "LATENT" } },
            widgets = { { "resolution", 3072 }, { "batch_size", 1 } },
        },
        VAEDecodeHunyuan3D = {
            inputs = { { "samples", "LATENT" }, { "vae", "VAE" } },
            outputs = { { "VOXEL", "VOXEL" } },
            widgets = { { "num_chunks", 8000 }, { "octree_resolution", 256 } },
        },
        VoxelToMesh = {
            inputs = { { "voxel", "VOXEL" } },
            outputs = { { "MESH", "MESH" } },
            widgets = { { "algorithm", "surface net" }, { "threshold", 0.6 } },
        },
        SaveGLB = {
            inputs = { { "mesh", "MESH" } },
            outputs = {},
            widgets = { { "filename_prefix", "mesh/ComfyUI" } },
        },
    }
    for k, v in pairs(add) do if not cat[k] then cat[k] = v end end
end
-- }}}

-- {{{ Settings
function comfy.settings()
    local path = ROOT .. "/comfyui/settings.lua"
    local chunk = loadfile(path)
    local s = chunk and chunk() or {}
    s.checkpoint = s.checkpoint or "v1-5-pruned-emaonly.safetensors"
    s.controlnet_canny = s.controlnet_canny or "control_v11p_sd15_canny.pth"
    s.hunyuan3d = s.hunyuan3d or "hunyuan3d-dit-v2.safetensors"
    s.negative = s.negative or "blurry, text, watermark, signature, frame, border"
    s.seed = s.seed or 5222
    return s
end
-- }}}

-- {{{ Building blocks
-- checkpoint, prompts, and the sampler + decode + save after them
local function base(G, s, prompt, negative)
    local ck = G:add("CheckpointLoaderSimple", { ckpt_name = s.checkpoint }, "checkpoint")
    local pos = G:add("CLIPTextEncode", { text = prompt }, "prompt")
    local neg = G:add("CLIPTextEncode", { text = negative or s.negative }, "negative prompt")
    G:link(ck, "CLIP", pos, "clip")
    G:link(ck, "CLIP", neg, "clip")
    return ck, pos, neg
end

local function sample(G, s, ck, pos, neg, latent, opts)
    local ks = G:add("KSampler", { seed = s.seed, steps = opts.steps or 24, cfg = opts.cfg or 7.0,
                                   sampler_name = opts.sampler or "dpmpp_2m", scheduler = opts.scheduler or "karras",
                                   denoise = opts.denoise or 1.0 }, "sampler")
    G:link(ck, "MODEL", ks, "model")
    G:link(pos, "CONDITIONING", ks, "positive")
    G:link(neg, "CONDITIONING", ks, "negative")
    G:link(latent, "LATENT", ks, "latent_image")
    local dec = G:add("VAEDecode", {}, "decode")
    G:link(ks, "LATENT", dec, "samples")
    G:link(ck, "VAE", dec, "vae")
    return dec
end

local function save(G, from, prefix, label)
    local sv = G:add("SaveImage", { filename_prefix = prefix }, label or "save")
    G:link(from, "IMAGE", sv, "images")
    return sv
end
-- }}}

-- {{{ The workflows
comfy.WORKFLOWS = {}

comfy.WORKFLOWS.icon = function(s)
    local G = graph_mod.new()
    local ck, pos, neg = base(G, s, "game ability icon, a flaming sword, bold simple shapes, strong silhouette,"
        .. " dark background, hand painted fantasy style, centered")
    local lat = G:add("EmptyLatentImage", { width = 512, height = 512, batch_size = 4 }, "canvas")
    local img = sample(G, s, ck, pos, neg, lat, {})
    save(G, img, "wete/icons/full", "save full size")
    local small = G:add("ImageScale", { upscale_method = "lanczos", width = 64, height = 64, crop = "center" }, "64 x 64")
    G:link(img, "IMAGE", small, "image")
    save(G, small, "wete/icons/64", "save 64")
    return G
end

comfy.WORKFLOWS["texture-restyle"] = function(s)
    local G = graph_mod.new()
    local ck, pos, neg = base(G, s, "hand painted fantasy armour texture, worn steel and leather, rich colour")
    local load = G:add("LoadImage", { image = "wete-texture.png" }, "texture (exported)")
    local enc = G:add("VAEEncode", {}, "encode")
    G:link(load, "IMAGE", enc, "pixels")
    G:link(ck, "VAE", enc, "vae")
    local img = sample(G, s, ck, pos, neg, enc, { denoise = 0.45 })
    save(G, img, "wete/textures/restyled")
    return G
end

comfy.WORKFLOWS["texture-restyle-lines"] = function(s)
    local G = graph_mod.new()
    local ck, pos, neg = base(G, s, "hand painted fantasy armour texture, worn steel and leather, rich colour")
    local load = G:add("LoadImage", { image = "wete-texture.png" }, "texture (exported)")
    local canny = G:add("Canny", { low_threshold = 0.3, high_threshold = 0.7 }, "its outlines")
    G:link(load, "IMAGE", canny, "image")
    local cn = G:add("ControlNetLoader", { control_net_name = s.controlnet_canny }, "canny controlnet")
    local apply = G:add("ControlNetApplyAdvanced", { strength = 0.9, start_percent = 0.0, end_percent = 1.0 },
        "hold the outlines")
    G:link(pos, "CONDITIONING", apply, "positive")
    G:link(neg, "CONDITIONING", apply, "negative")
    G:link(cn, "CONTROL_NET", apply, "control_net")
    G:link(canny, "IMAGE", apply, "image")
    local enc = G:add("VAEEncode", {}, "encode")
    G:link(load, "IMAGE", enc, "pixels")
    G:link(ck, "VAE", enc, "vae")
    local ks = G:add("KSampler", { seed = s.seed, steps = 26, cfg = 6.5, sampler_name = "dpmpp_2m",
                                   scheduler = "karras", denoise = 0.65 }, "sampler")
    G:link(ck, "MODEL", ks, "model")
    G:link(apply, "positive", ks, "positive")
    G:link(apply, "negative", ks, "negative")
    G:link(enc, "LATENT", ks, "latent_image")
    local dec = G:add("VAEDecode", {}, "decode")
    G:link(ks, "LATENT", dec, "samples")
    G:link(ck, "VAE", dec, "vae")
    save(G, dec, "wete/textures/restyled-lines")
    return G
end

comfy.WORKFLOWS["ground-tile"] = function(s)
    local G = graph_mod.new()
    local ck, pos, neg = base(G, s, "top-down ground texture, grass and small stones, even lighting, no shadows,"
        .. " no horizon, flat, hand painted game terrain", s.negative .. ", perspective, horizon, objects")
    local lat = G:add("EmptyLatentImage", { width = 512, height = 512, batch_size = 4 }, "canvas")
    local img = sample(G, s, ck, pos, neg, lat, {})
    save(G, img, "wete/ground/tile")
    return G
end

comfy.WORKFLOWS["portrait-art"] = function(s)
    local G = graph_mod.new()
    local ck, pos, neg = base(G, s, "portrait of a fantasy paladin, head and shoulders, dramatic light,"
        .. " painterly, dark background")
    local lat = G:add("EmptyLatentImage", { width = 512, height = 640, batch_size = 2 }, "canvas")
    local img = sample(G, s, ck, pos, neg, lat, { steps = 28 })
    save(G, img, "wete/portraits/art")
    return G
end

comfy.WORKFLOWS["model-from-image"] = function(s)
    local G = graph_mod.new()
    local ck = G:add("ImageOnlyCheckpointLoader", { ckpt_name = s.hunyuan3d }, "Hunyuan3D 2")
    local shift = G:add("ModelSamplingAuraFlow", { shift = 1.0 }, "sampling")
    G:link(ck, "MODEL", shift, "model")
    local load = G:add("LoadImage", { image = "wete-concept.png" }, "concept picture (plain background)")
    local see = G:add("CLIPVisionEncode", { crop = "center" }, "look at it")
    G:link(ck, "CLIP_VISION", see, "clip_vision")
    G:link(load, "IMAGE", see, "image")
    local cond = G:add("Hunyuan3Dv2Conditioning", {}, "condition")
    G:link(see, "CLIP_VISION_OUTPUT", cond, "clip_vision_output")
    local lat = G:add("EmptyLatentHunyuan3Dv2", { resolution = 3072, batch_size = 1 }, "shape latent")
    local ks = G:add("KSampler", { seed = s.seed, steps = 30, cfg = 5.0, sampler_name = "euler",
                                   scheduler = "normal", denoise = 1.0 }, "sampler")
    G:link(shift, "MODEL", ks, "model")
    G:link(cond, "positive", ks, "positive")
    G:link(cond, "negative", ks, "negative")
    G:link(lat, "LATENT", ks, "latent_image")
    local dec = G:add("VAEDecodeHunyuan3D", { num_chunks = 8000, octree_resolution = 256 }, "to voxels")
    G:link(ks, "LATENT", dec, "samples")
    G:link(ck, "VAE", dec, "vae")
    local mesh = G:add("VoxelToMesh", { algorithm = "surface net", threshold = 0.6 }, "to a mesh")
    G:link(dec, "VOXEL", mesh, "voxel")
    local sv = G:add("SaveGLB", { filename_prefix = "wete/models/mesh" }, "save GLB")
    G:link(mesh, "MESH", sv, "mesh")
    return G
end
-- }}}

-- {{{ comfy.write
function comfy.write(dir)
    load_writer()
    dir = dir or (ROOT .. "/comfyui/workflows")
    os.execute('mkdir -p "' .. dir .. '"')
    local s = comfy.settings()
    local names = {}
    for name in pairs(comfy.WORKFLOWS) do names[#names + 1] = name end
    table.sort(names)
    local written = {}
    for _, name in ipairs(names) do
        local G = comfy.WORKFLOWS[name](s)
        for _, shape in ipairs({ "api", "ui" }) do
            local path = dir .. "/" .. name .. "." .. shape .. ".json"
            local f = assert(io.open(path, "w"))
            f:write(json.encode(shape == "api" and G:api() or G:ui()), "\n")
            f:close()
            written[#written + 1] = path
        end
    end
    return written
end
-- }}}

-- {{{ comfy.check
-- Every node type and input of every written API workflow, against a
-- ComfyUI install's /object_info. Returns a list of problems.
function comfy.check(object_info_path, dir)
    dir = dir or (ROOT .. "/comfyui/workflows")
    package.path = MONOREPO .. "/libs/lua/?.lua;" .. package.path
    local dkjson = require("dkjson")
    local f = assert(io.open(object_info_path, "r"))
    local info = dkjson.decode(f:read("*a"))
    f:close()
    local problems = {}
    for path in io.popen('ls "' .. dir .. '"/*.api.json 2>/dev/null'):lines() do
        local wf = dkjson.decode(assert(io.open(path)):read("*a"))
        for id, node in pairs(wf) do
            local def = info[node.class_type]
            if not def then
                problems[#problems + 1] = path .. ": node " .. id .. " is " .. node.class_type .. ", which your ComfyUI doesn't have"
            else
                local known = {}
                for _, group in ipairs({ "required", "optional", "hidden" }) do
                    for name in pairs((def.input or {})[group] or {}) do known[name] = true end
                end
                for name in pairs(node.inputs or {}) do
                    if not known[name] then
                        problems[#problems + 1] = path .. ": " .. node.class_type .. " has no input " .. name
                    end
                end
                for name in pairs((def.input or {}).required or {}) do
                    if (node.inputs or {})[name] == nil then
                        problems[#problems + 1] = path .. ": " .. node.class_type .. " needs " .. name
                    end
                end
            end
        end
    end
    return problems
end
-- }}}

-- {{{ comfy.export
-- A texture from a map (or the install through it) as a PNG, to start a
-- restyle from
function comfy.export(map, path, out)
    package.path = ROOT .. "/src/?.lua;" .. ROOT .. "/src/?/init.lua;" .. package.path
    local A = require("assets").open(map, { root = ROOT })
    local img = A:texture(path)
    if not img then error("no texture " .. path .. " in " .. map .. (A.install and " or the install" or "")) end
    local png = dofile(KANJI .. "/017-write-a-picture.lua")
    local f = assert(io.open(out, "wb"))
    f:write(png.encode(img.rgba, img.width, img.height, 4))
    f:close()
    A:close()
    return img.width, img.height
end
-- }}}

-- {{{ command line
if arg and arg[0] and arg[0]:match("comfy%.lua$") then
    local cmd = arg[1]
    if cmd == "write" then
        for _, p in ipairs(comfy.write(arg[2])) do print("wrote " .. p) end
    elseif cmd == "check" and arg[2] then
        local problems = comfy.check(arg[2], arg[3])
        for _, p in ipairs(problems) do print(p) end
        print(#problems == 0 and "every node and input is known to that ComfyUI" or (#problems .. " problems"))
        os.exit(#problems == 0 and 0 or 1)
    elseif cmd == "export" and arg[4] then
        local w, h = comfy.export(arg[2], arg[3], arg[4])
        print(string.format("wrote %s (%d x %d)", arg[4], w, h))
    else
        print("usage: luajit src/assets/comfy.lua write [DIR] | check OBJECT_INFO.json [DIR] | export MAP PATH OUT.png")
        os.exit(2)
    end
end
-- }}}

return comfy
