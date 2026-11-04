-- see-in-3d-imagine.lua - Builds the ComfyUI workflow that imagines one
-- see-in-3d view as a picture, and talks to the ComfyUI server to run it.
--
-- In plain terms: Stable Diffusion is given three things. The shape comes from
-- the view's depth map (exact, from the renderer's own depth buffer) through a
-- depth ControlNet, which makes the picture keep the scene's layout. The look
-- comes from the original picture through the "shuffle" ControlNet, which
-- carries its colours and textures but not its layout. The meaning comes from
-- the scene's own one-line description, as the prompt. What comes back is the
-- scene imagined from a viewpoint the original picture never showed.
--
-- The workflow is built by a pure function (same inputs, same JSON), so it can
-- be tested and kept beside the picture it made. Only core ComfyUI nodes are
-- used: the installation has no custom nodes (so no IP-Adapter, see issue A09).
--
-- Talking to the server is curl, one request each: upload an image, queue the
-- workflow, ask its history until it is done, fetch the result. Responses are
-- read with patterns for the few fields needed, not a full JSON reader.

local M = {}

-- {{{ M.defaults
-- The sampler settings and the files on this installation. Every one is
-- overridable from the command; these are the values used when not.
M.defaults = {
    -- mode "depth": shape from the depth map through a depth ControlNet.
    -- mode "render": shape from the rendered view itself, repainted
    -- (image-to-image), for a server with no ControlNet; denoise says how far
    -- the repainting may wander from the render (0 none, 1 all the way).
    mode = "depth", denoise = 0.65,
    model = "Dreamshaper-8",                       -- a folder in models/diffusers
    checkpoint = nil,                              -- a single-file checkpoint, used instead when given
    depth_controlnet = "Depth-Map.safetensors",
    look_controlnet = "Remix-shuffle.safetensors",
    -- no embedding named here: a server without it would read the word as
    -- text, so the negative is plain words that every model understands
    negative = "blurry, low quality, deformed, text, watermark",
    steps = 25, cfg = 7, sampler = "euler_ancestral", scheduler = "karras",
    depth_strength = 0.9, look_strength = 0.55, width = 512, height = 512,
    server = "http://127.0.0.1:8188",
}
-- }}}

-- {{{ M.json(value)
-- A value as JSON text, object keys sorted so the same workflow is the same
-- bytes. Lists are tables with a [1]; an empty table is an object.
function M.json(value)
    local kind = type(value)
    if kind == "string" then
        return '"' .. value:gsub('[%c"\\]', function(c)
            local named = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
            return named[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    elseif kind == "number" then
        if value == math.floor(value) and math.abs(value) < 2 ^ 53 then return string.format("%d", value) end
        return string.format("%.17g", value)
    elseif kind == "boolean" then
        return tostring(value)
    elseif kind == "table" then
        local parts = {}
        if value[1] ~= nil then
            for _, item in ipairs(value) do parts[#parts + 1] = M.json(item) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = tostring(key) end
        table.sort(keys)
        for _, key in ipairs(keys) do parts[#parts + 1] = M.json(key) .. ":" .. M.json(value[key]) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("see-in-3d imagine: cannot write a " .. kind .. " as JSON", 0)
end
-- }}}

-- {{{ M.workflow(settings)
-- The ComfyUI graph, in API format: node id -> { class_type, inputs }. A wire
-- is { node id, output index }. settings: prompt (string), depth_image and
-- look_image (names on the server; look_image may be absent), render_image
-- (mode "render"), seed (integer), prefix (string), and any field of
-- M.defaults to override.
function M.workflow(settings)
    local s = {}
    for key, value in pairs(M.defaults) do s[key] = value end
    for key, value in pairs(settings) do s[key] = value end
    -- a single-file checkpoint and a diffusers folder load through different
    -- nodes; both give model, text encoder and image decoder in that order
    local loader = s.checkpoint
        and { class_type = "CheckpointLoaderSimple", inputs = { ckpt_name = s.checkpoint } }
        or { class_type = "DiffusersLoader", inputs = { model_path = s.model } }
    local graph = {
        ["1"] = loader,
        ["2"] = { class_type = "CLIPTextEncode", inputs = { text = s.prompt, clip = { "1", 1 } } },
        ["3"] = { class_type = "CLIPTextEncode", inputs = { text = s.negative, clip = { "1", 1 } } },
    }
    -- the render mode: the drawn view, encoded, is where sampling starts
    if s.mode == "render" then
        graph["5"] = { class_type = "LoadImage", inputs = { image = s.render_image } }
        graph["14"] = { class_type = "VAEEncode", inputs = { pixels = { "5", 0 }, vae = { "1", 2 } } }
        graph["11"] = { class_type = "KSampler", inputs = {
            model = { "1", 0 }, positive = { "2", 0 }, negative = { "3", 0 }, latent_image = { "14", 0 },
            seed = s.seed, steps = s.steps, cfg = s.cfg, sampler_name = s.sampler, scheduler = s.scheduler, denoise = s.denoise } }
        graph["12"] = { class_type = "VAEDecode", inputs = { samples = { "11", 0 }, vae = { "1", 2 } } }
        graph["13"] = { class_type = "SaveImage", inputs = { images = { "12", 0 }, filename_prefix = s.prefix } }
        return graph
    end
    if s.mode ~= "depth" then error("see-in-3d imagine: mode is depth or render, not " .. tostring(s.mode), 0) end
    graph["4"] = { class_type = "ControlNetLoader", inputs = { control_net_name = s.depth_controlnet } }
    graph["5"] = { class_type = "LoadImage", inputs = { image = s.depth_image } }
    graph["6"] = { class_type = "ControlNetApplyAdvanced", inputs = {
        positive = { "2", 0 }, negative = { "3", 0 }, control_net = { "4", 0 }, image = { "5", 0 },
        strength = s.depth_strength, start_percent = 0, end_percent = 1, vae = { "1", 2 } } }
    graph["10"] = { class_type = "EmptyLatentImage", inputs = { width = s.width, height = s.height, batch_size = 1 } }
    local positive, negative = { "6", 0 }, { "6", 1 }
    -- with a picture to take the look from, a second ControlNet carries it;
    -- without one, the depth and the words alone decide
    if s.look_image then
        graph["7"] = { class_type = "ControlNetLoader", inputs = { control_net_name = s.look_controlnet } }
        graph["8"] = { class_type = "LoadImage", inputs = { image = s.look_image } }
        graph["9"] = { class_type = "ControlNetApplyAdvanced", inputs = {
            positive = { "6", 0 }, negative = { "6", 1 }, control_net = { "7", 0 }, image = { "8", 0 },
            strength = s.look_strength, start_percent = 0, end_percent = 0.8, vae = { "1", 2 } } }
        positive, negative = { "9", 0 }, { "9", 1 }
    end
    graph["11"] = { class_type = "KSampler", inputs = {
        model = { "1", 0 }, positive = positive, negative = negative, latent_image = { "10", 0 },
        seed = s.seed, steps = s.steps, cfg = s.cfg, sampler_name = s.sampler, scheduler = s.scheduler, denoise = 1 } }
    graph["12"] = { class_type = "VAEDecode", inputs = { samples = { "11", 0 }, vae = { "1", 2 } } }
    graph["13"] = { class_type = "SaveImage", inputs = { images = { "12", 0 }, filename_prefix = s.prefix } }
    return graph
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function curl()
-- A request's body, and its HTTP status (000 when nothing answered).
local function curl(arguments)
    local pipe = io.popen("curl -s -m 30 -w '\\n%{http_code}' " .. arguments)
    local text = pipe:read("*a")
    pipe:close()
    local body, status = text:match("^(.*)\n(%d%d%d)$")
    return body or text, status or "000"
end
-- }}}

-- {{{ M.reachable(server)
function M.reachable(server)
    local _, status = curl(shell_quote(server .. "/system_stats"))
    return status == "200"
end
-- }}}

-- {{{ M.missing(server, graph)
-- Every model file the workflow names that the server does not hold, as a
-- list of strings ("checkpoint X (it has: A, B)"). Asked of the server's own
-- node descriptions, so nothing is posted that would fail for a missing file,
-- and nothing is fetched or installed: a missing piece stops the run, named.
local wanted = {
    CheckpointLoaderSimple = { field = "ckpt_name", what = "checkpoint" },
    DiffusersLoader = { field = "model_path", what = "diffusers model" },
    ControlNetLoader = { field = "control_net_name", what = "ControlNet" },
}
function M.missing(server, graph)
    local missing, listings = {}, {}
    for _, node in pairs(graph) do
        local want = wanted[node.class_type]
        if want then
            if not listings[node.class_type] then
                local body = curl(shell_quote(server .. "/object_info/" .. node.class_type))
                local names = {}
                local list = body:match('"' .. want.field .. '"%s*:%s*%[%s*%[(.-)%]')
                for name in (list or ""):gmatch('"([^"]+)"') do names[#names + 1] = name end
                listings[node.class_type] = names
            end
            local name, found = node.inputs[want.field], false
            for _, held in ipairs(listings[node.class_type]) do if held == name then found = true end end
            if not found then
                local held = listings[node.class_type]
                missing[#missing + 1] = string.format("%s %s (it has: %s)", want.what, name,
                    #held > 0 and table.concat(held, ", ") or "none")
            end
        end
    end
    table.sort(missing)
    return missing
end
-- }}}

-- {{{ M.upload(server, path)
-- An image sent to the server's input folder; returns the name the server
-- gave it, or nil and why.
function M.upload(server, path)
    local body, status = curl("-F " .. shell_quote("image=@" .. path) .. " -F overwrite=true " .. shell_quote(server .. "/upload/image"))
    local name = body:match('"name"%s*:%s*"([^"]+)"')
    if status ~= "200" or not name then return nil, "upload of " .. path .. " failed (HTTP " .. status .. "): " .. body:sub(1, 300) end
    return name
end
-- }}}

-- {{{ M.queue(server, graph, json_path)
-- The workflow queued; returns its prompt id, or nil and the server's own
-- complaint (it names the node and input it rejects).
function M.queue(server, graph, json_path)
    local handle = io.open(json_path, "w")
    handle:write(M.json({ prompt = graph, client_id = "see-in-3d" }))
    handle:close()
    local body, status = curl("-X POST -H 'Content-Type: application/json' --data-binary @" .. shell_quote(json_path) .. " " .. shell_quote(server .. "/prompt"))
    local id = body:match('"prompt_id"%s*:%s*"([^"]+)"')
    if status ~= "200" or not id then return nil, "the server refused the workflow (HTTP " .. status .. "): " .. body:sub(1, 1200) end
    return id
end
-- }}}

-- {{{ M.wait(server, id, seconds)
-- Asks the history every two seconds until the prompt has an image or the
-- time runs out. Returns { filename, subfolder, type } or nil and why. A
-- timeout is reported as a timeout, never as a result.
function M.wait(server, id, seconds)
    local deadline = os.time() + seconds
    while os.time() < deadline do
        local body = curl(shell_quote(server .. "/history/" .. id))
        local filename = body:match('"filename"%s*:%s*"([^"]+)"')
        if filename then
            return { filename = filename, subfolder = body:match('"subfolder"%s*:%s*"([^"]*)"') or "",
                type = body:match('"type"%s*:%s*"([^"]+)"') or "output" }
        end
        if body:find('"status_str"%s*:%s*"error"') then return nil, "the run failed on the server: " .. body:sub(1, 1200) end
        os.execute("sleep 2")
    end
    return nil, "no picture after " .. seconds .. " seconds (still queued or still running; prompt " .. id .. ")"
end
-- }}}

-- {{{ M.fetch(server, result, path)
function M.fetch(server, result, path)
    local query = string.format("filename=%s&subfolder=%s&type=%s", result.filename, result.subfolder, result.type)
    local _, status = curl("-o " .. shell_quote(path) .. " " .. shell_quote(server .. "/view?" .. query))
    if status ~= "200" then return nil, "fetching the picture failed (HTTP " .. status .. ")" end
    return path
end
-- }}}

return M
