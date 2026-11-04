#!/usr/bin/env luajit
-- picture-embeddings.lua: Stage 6's picture step (Issue 9-013).
--
-- WHAT IT DOES (for a CEO): the embedding model can look at a picture and
-- turn what it shows -- including handwriting and screenshots of text -- into
-- the same kind of numbers it makes for a poem. This step does that for every
-- picture the site ranks: the pictures in posts and the gallery pictures. It
-- shrinks each picture, sends it to the embedding server, and keeps the
-- numbers in a cache, so a picture already seen is never sent again.
--
-- How it decides what is "already seen": each picture file is fingerprinted
-- by its contents (md5), so a renamed or moved file is still known, and an
-- edited one is sent again. The fingerprint is filed together with the size
-- it was shrunk to, so changing that size remakes every picture.
--
-- It runs while the Stage 6 server is up; Stage 6.7
-- (src/augment-embeddings-with-images.lua) only reads the cache. The work is
-- split: fingerprinting and shrinking run on every processor at once; the
-- server takes one picture at a time (it is started with one slot,
-- scripts/start-llamacpp-server.sh).
--
-- Usage: luajit src/picture-embeddings.lua [--dir PATH] --model NAME --server NAME
--   --dir PATH     project folder (default below)
--   --model NAME   the embedding model (one with a vision_projector in
--                  config.lua); required, as run.sh's --model is
--   --server NAME  the inference server, by name from config.lua; required

-- --help: print the header above and exit, before any work (libs/script-help.lua)
if not _G.PICTURE_EMBEDDINGS_NO_MAIN then
    dofile(debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../libs/script-help.lua").handle(arg)
end

-- {{{ local function parse_args()
-- The two required names. A missing name is an error: the stage must say
-- which model sees the pictures (Issue 10-065). The project folder, --dir,
-- is read before this, by libs/project-dir.lua (Issue 10-076).
local function parse_args(args)
    local model, server = nil, nil
    local i = 1
    while args[i] do
        local a = args[i]
        if a == "--model" then model = args[i + 1]; i = i + 2
        elseif a:match("^%-%-model=") then model = a:match("=(.*)"); i = i + 1
        elseif a == "--server" then server = args[i + 1]; i = i + 2
        elseif a:match("^%-%-server=") then server = a:match("=(.*)"); i = i + 1
        else error("picture-embeddings: unknown option " .. a) end
    end
    return model, server
end
-- }}}

local DIR, MODEL, SERVER = "/mnt/mtwo/programming/ai-stuff/neocities-modernization", nil, nil
if not _G.PICTURE_EMBEDDINGS_NO_MAIN then
    -- The project folder: --dir PATH, or the path above; a stray word stops
    -- the stage, named (libs/project-dir.lua, Issue 10-076). It used to be
    -- any bare word.
    local own_args
    DIR, own_args = dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./") .. "../libs/project-dir.lua")
        .read(arg or {}, DIR, { ["--model"] = true, ["--server"] = true })
    MODEL, SERVER = parse_args(own_args)
end

package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local M = {}

M.CACHE_FORMAT = "picture-embeddings-v1"

-- {{{ local function shell_quote()
local function shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function processors()
-- How many processors to split the file work across.
local function processors()
    local p = assert(io.popen("nproc"))
    local n = tonumber(p:read("*l"))
    p:close()
    if not n then error("picture-embeddings: nproc gave no count") end
    return n
end
-- }}}

-- {{{ function M.post_picture_path()
-- Where a post's attachment lives: the fediverse export keeps attachments
-- under input/media_attachments/, and each record's relative_path starts
-- with "files/".
function M.post_picture_path(dir, attachment)
    return dir .. "/input/media_attachments/" .. attachment.relative_path
end
-- }}}

-- {{{ function M.is_picture()
-- A post's attachment that is a picture (videos and sound are not; those
-- posts keep the neighbours-in-time placement).
function M.is_picture(attachment)
    return (attachment.media_type or ""):match("^image/") ~= nil
end
-- }}}

-- {{{ function M.pictures_to_place()
-- Every picture file the site ranks, each once:
--   the picture attachments of every post (posts with text blend them in,
--   posts without text are placed by them), and every gallery picture
--   (the catalog's own fediverse-media entries are those same attachments).
-- returns: array of absolute paths (strings), sorted
function M.pictures_to_place(dir, poems_data, catalog_data)
    local seen, list = {}, {}
    local function add(path)
        if not seen[path] then seen[path] = true; list[#list + 1] = path end
    end
    for _, poem in ipairs(poems_data.poems) do
        for _, attachment in ipairs(poem.attachments or {}) do
            if M.is_picture(attachment) then add(M.post_picture_path(dir, attachment)) end
        end
    end
    for _, image in ipairs(catalog_data.images) do
        if image.source_name ~= "fediverse-media" then add(image.file_path) end
    end
    table.sort(list)
    return list
end
-- }}}

-- {{{ function M.fingerprints()
-- The md5 of each file, worked out on every processor at once.
-- paths   : array of absolute paths
-- scratch : a RAM folder for the list handed to the workers
-- returns : { [path] = md5 hex string }; a file that cannot be read is an error
--
-- Each batch of 64 writes its answers to a file of its own, and the files are
-- read once every batch is done. They must not share one pipe: each md5sum
-- copy sends its answers out in 4 KB pieces, a piece can end mid-answer, and
-- another copy's piece then lands in the gap -- a few answers per run came
-- back unreadable, a different few each time (2026-11-02; the "many pictures
-- at once" case in picture-embeddings.test.lua is the check).
function M.fingerprints(paths, scratch)
    if #paths == 0 then return {} end
    local answers = scratch .. "/fingerprint-answers"
    -- emptied first, so no batch file from an earlier call is read as an answer
    os.execute("rm -rf " .. shell_quote(answers))
    os.execute("mkdir -p " .. shell_quote(answers))
    local list_path = scratch .. "/fingerprint-list"
    local f = assert(io.open(list_path, "wb"))
    for _, path in ipairs(paths) do f:write(path, "\0") end
    f:close()
    -- -z: each answer ends in a NUL and names are not escaped, so any file
    -- name comes back as it went in. mktemp gives each batch a file name
    -- nothing else is using, whichever processor it runs on.
    local status = os.execute(string.format("xargs -0 -P %d -n 64 sh -c %s %s < %s",
        processors(),
        shell_quote('out=$(mktemp "$0/batch.XXXXXX") && md5sum -z "$@" > "$out"'),
        shell_quote(answers), shell_quote(list_path)))
    -- LuaJIT gives 0 here, or true when built with the Lua 5.2 extensions
    local every_batch_finished = (status == 0 or status == true)
    -- at least one batch ran (there is at least one path), so the pattern
    -- always names a file
    local p = assert(io.popen("cat " .. shell_quote(answers) .. "/batch.*"))
    local out = p:read("*a")
    p:close()
    local result = {}
    for hash, path in out:gmatch("(%x+)  (%Z+)%z") do result[path] = hash end
    local missing = {}
    for _, path in ipairs(paths) do
        if not result[path] then missing[#missing + 1] = path end
    end
    -- Two ways to come up short, and both stop the stage: a picture with no
    -- answer (named, so it can be looked at; md5sum has already said why on
    -- the terminal), or a batch that failed although every picture has an
    -- answer (an md5sum or mktemp that broke after writing).
    if #missing > 0 then
        error(string.format("picture-embeddings: could not fingerprint %d of %d pictures; the first is %s",
            #missing, #paths, missing[1]))
    end
    if not every_batch_finished then
        error("picture-embeddings: a fingerprint batch failed (status " .. tostring(status) .. ")")
    end
    return result
end
-- }}}

-- {{{ function M.cache_key()
-- One picture at one size: a picture shrunk to another size is another entry.
function M.cache_key(hash, long_side)
    return hash .. "@" .. tostring(long_side)
end
-- }}}

-- {{{ function M.shrink_all()
-- Shrinks pictures, on every processor at once, into JPEG files: the long
-- side down to long_side (smaller pictures are left their size),
-- transparency flattened onto white, an animation's first frame.
-- jobs : array of { source = path, target = path }
-- An output that did not appear is an error naming its source.
function M.shrink_all(jobs, long_side, scratch)
    if #jobs == 0 then return end
    os.execute("mkdir -p " .. shell_quote(scratch))
    local list_path = scratch .. "/shrink-list"
    local f = assert(io.open(list_path, "wb"))
    for _, job in ipairs(jobs) do f:write(job.source, "\0", job.target, "\0") end
    f:close()
    local size = string.format("%dx%d>", long_side, long_side)
    local command = string.format(
        "xargs -0 -n 2 -P %d sh -c %s sh < %s",
        processors(),
        shell_quote('magick "$1[0]" -auto-orient -background white -alpha remove -alpha off -resize '
            .. shell_quote(size) .. ' -quality 95 "$2"'),
        shell_quote(list_path))
    os.execute(command)
    for _, job in ipairs(jobs) do
        local out = io.open(job.target, "rb")
        if not out then error("picture-embeddings: could not shrink " .. job.source) end
        out:close()
    end
end
-- }}}

-- {{{ function M.server_embedder()
-- An embed function that asks the server at endpoint for a picture's vector.
-- returns: function(jpeg_path) -> array of numbers
function M.server_embedder(endpoint, scratch, timeout_seconds)
    local json = require("dkjson")
    return function(jpeg_path)
        local b64 = assert(io.popen("base64 -w0 " .. shell_quote(jpeg_path)))
        local data = b64:read("*a")
        b64:close()
        local request_path = scratch .. "/request.json"
        local f = assert(io.open(request_path, "w"))
        f:write(json.encode({ input = { { content = { { type = "image_url",
            image_url = { url = "data:image/jpeg;base64," .. data } } } } } }))
        f:close()
        local p = assert(io.popen(string.format(
            "curl -s --max-time %d -H 'Content-Type: application/json' -d @%s %s/v1/embeddings",
            timeout_seconds, shell_quote(request_path), endpoint)))
        local reply = p:read("*a")
        p:close()
        local decoded = json.decode(reply)
        local vector = decoded and decoded.data and decoded.data[1] and decoded.data[1].embedding
        if type(vector) ~= "table" or #vector == 0 then
            -- The usual cause: a server started without the vision projector
            -- (one the operator started by hand, before 9-013) answers a
            -- picture with an error. Its own words follow.
            error(string.format("picture-embeddings: the server at %s gave no vector for %s "
                .. "(is it running with its vision projector, --mmproj?): %s",
                endpoint, jpeg_path, reply:sub(1, 300)))
        end
        return vector
    end
end
-- }}}

-- {{{ function M.update()
-- The step's core, with the file work and the server passed in, so it can be
-- tested without either.
-- cache     : { metadata = {...}, pictures = { [key] = { embedding, example } } }
-- paths     : the pictures to place (absolute paths)
-- hashes    : { [path] = md5 }
-- long_side : the size pictures are shrunk to
-- shrink    : function(jobs) -- makes each job.target from job.source
-- embed     : function(jpeg_path) -> vector
-- scratch   : RAM folder for shrunk copies (each removed once sent)
-- say       : function(text) for progress lines
-- returns   : the new cache (only the pictures still on the site) and a
--             report { reused, made, total }
function M.update(cache, paths, hashes, long_side, shrink, embed, scratch, say)
    local old = cache.pictures
    local new, jobs, wanted = {}, {}, {}
    local reused = 0
    for _, path in ipairs(paths) do
        local key = M.cache_key(hashes[path], long_side)
        if new[key] then
            -- the same picture in two places: one entry serves both
        elseif old[key] then
            new[key] = old[key]
            reused = reused + 1
        elseif not wanted[key] then
            wanted[key] = true
            jobs[#jobs + 1] = { source = path, target = scratch .. "/" .. hashes[path] .. ".jpg", key = key }
        end
    end
    shrink(jobs)
    for i, job in ipairs(jobs) do
        new[job.key] = { embedding = embed(job.target), example = job.source }
        os.remove(job.target)
        if i % 50 == 0 or i == #jobs then
            say(string.format("  pictures embedded: %d of %d", i, #jobs))
        end
    end
    local count = 0
    for _ in pairs(new) do count = count + 1 end
    return { metadata = cache.metadata, pictures = new },
        { reused = reused, made = #jobs, total = count }
end
-- }}}

-- {{{ local function main()
local function main()
    local json = require("dkjson")
    local utils = require("utils")
    local output = require("output")
    local inference = require("inference-server-config")
    inference.set_project_root(DIR)
    if not MODEL then error("picture-embeddings: --model NAME is required") end
    if not SERVER then error("picture-embeddings: --server NAME is required") end
    inference.set_selected_server(SERVER)
    inference.set_selected_model(MODEL)
    local model = inference.get_selected_model()
    local model_config = inference.get_selected_model_config()
    if not model_config.vision_projector then
        error(string.format("picture-embeddings: model %s cannot see pictures (it has no "
            .. "vision_projector in config.lua). Pictures are placed by what they show "
            .. "(Issue 9-013), so build with a model that has one, e.g. embeddinggemma-2.", model))
    end
    local settings = require("config-loader").load().picture_embeddings
        or error("config.lua has no picture_embeddings section")
    local long_side = settings.long_side or error("config.lua picture_embeddings.long_side is missing")
    local timeout = settings.request_seconds or error("config.lua picture_embeddings.request_seconds is missing")

    local function load(path)
        local f = io.open(path, "r")
        if not f then error("picture-embeddings: cannot open " .. path) end
        local data = json.decode(f:read("*a"))
        f:close()
        return data
    end
    local poems_data = load(DIR .. "/assets/poems.json")
    local catalog_data = load(DIR .. "/assets/image-catalog.json")

    local cache_path = utils.embeddings_dir(model) .. "/picture_embeddings.json"
    local cache
    local existing = io.open(cache_path, "r")
    if existing then
        cache = json.decode(existing:read("*a"))
        existing:close()
        if not (cache and cache.metadata and cache.metadata.format == M.CACHE_FORMAT and cache.pictures) then
            error("picture-embeddings: " .. cache_path .. " is not a " .. M.CACHE_FORMAT .. " cache")
        end
    else
        -- First run for this model: every picture is new.
        cache = { metadata = { format = M.CACHE_FORMAT }, pictures = {} }
    end

    local scratch = DIR .. "/tmp/shared-memory/picture-embeddings"
    local paths = M.pictures_to_place(DIR, poems_data, catalog_data)
    output.say(string.format("[pictures] %d pictures to place; fingerprinting...", #paths), "both")
    local hashes = M.fingerprints(paths, scratch)

    local endpoint = inference.build_host_url(inference.get_selected_server())
    local new_cache, report = M.update(cache, paths, hashes, long_side,
        function(jobs) M.shrink_all(jobs, long_side, scratch) end,
        M.server_embedder(endpoint, scratch, timeout),
        scratch,
        function(text) output.say(text, "both") end)
    new_cache.metadata = { format = M.CACHE_FORMAT, model = model, long_side = long_side,
        generated_at = os.date("%Y-%m-%d %H:%M:%S") }

    local f = assert(io.open(cache_path .. ".partial", "w"))
    f:write(json.encode(new_cache))
    f:close()
    assert(os.rename(cache_path .. ".partial", cache_path))
    output.say(string.format("[pictures] %d pictures: %d already embedded, %d embedded now -> %s",
        report.total, report.reused, report.made, cache_path), "both")
end
-- }}}

if not _G.PICTURE_EMBEDDINGS_NO_MAIN then
    -- start, end and any stopping error go to the run's log (Issue 10-075)
    require("output").guard("picture-embeddings.lua", main)
end

return M
