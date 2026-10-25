#!/usr/bin/env luajit

-- Does the vision model still see what a picture shows? (Issue 9-013)
--
-- Pictures are placed among the poems by the vision model's vector for each
-- one, so the placement is only as good as the model's sight. This test draws
-- pictures of known words (a line of poetry, a line of C, a grocery list, a
-- sentence about the sea), sends them through the build's own route (the
-- picture step's shrink and server request), embeds a sentence for each, and
-- checks every picture sits closest to its own sentence. A failure means the
-- pictures on the site are being placed by numbers that no longer mean what
-- they show: a new model, a projector that did not load, a server change.
--
-- It needs the testing server (config.lua testing) running with its vision
-- projector; without one it prints SKIP and passes, as the other
-- server-dependent tests do.
--
-- Run directly:  luajit src/picture-sight.test.lua [project-dir]

-- {{{ local function setup()
local function setup()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local dir = (arg[1] or src_dir:gsub("src/$", "")):gsub("/$", "")
    package.path = dir .. "/libs/?.lua;" .. dir .. "/src/?.lua;" .. package.path
    return dir
end
-- }}}

local DIR = setup()
_G.PICTURE_EMBEDDINGS_NO_MAIN = true
local pictures = dofile(DIR .. "/src/picture-embeddings.lua")
local json = require("dkjson")
local inference = require("inference-server-config")
inference.set_project_root(DIR)
local testing = require("config-loader").load().testing
inference.set_selected_server(testing.server)
inference.set_selected_model(testing.model)
local endpoint = inference.build_host_url(inference.get_selected_server())

local SCRATCH = DIR .. "/tmp/shared-memory/picture-sight-test"
os.execute(string.format("rm -rf %q && mkdir -p %q", SCRATCH, SCRATCH))

-- {{{ is the server up?
do
    local p = assert(io.popen(string.format("curl -s -o /dev/null -w '%%{http_code}' --max-time 5 %s/health", endpoint)))
    local code = p:read("*a")
    p:close()
    if code ~= "200" then
        print(string.format("SKIP: no server at %s/health (got '%s')", endpoint, code))
        os.exit(0)
    end
end
-- }}}

local passed, failed = 0, 0
-- {{{ local function check()
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. tostring(detail)) or ""))
    end
end
-- }}}

-- {{{ local function cosine()
local function cosine(a, b)
    local d, na, nb = 0, 0, 0
    for i = 1, #a do d = d + a[i] * b[i]; na = na + a[i] ^ 2; nb = nb + b[i] ^ 2 end
    return d / math.sqrt(na * nb)
end
-- }}}

-- {{{ local function text_vector()
local function text_vector(text)
    local request = SCRATCH .. "/text.json"
    local f = assert(io.open(request, "w"))
    f:write(json.encode({ input = { inference.format_embedding_prompt(text) } }))
    f:close()
    local p = assert(io.popen(string.format("curl -s --max-time 60 -H 'Content-Type: application/json' -d @%s %s/v1/embeddings", request, endpoint)))
    local reply = json.decode(p:read("*a"))
    p:close()
    return assert(reply and reply.data and reply.data[1].embedding, "no vector for a sentence")
end
-- }}}

-- What each picture says, and the sentence it should sit closest to.
local cases = {
    { name = "poem", font = "DejaVu-Sans", size = 40, lines = { "the river remembers", "every rain that fed it" },
      sentence = "the river remembers every rain that fed it" },
    { name = "code", font = "DejaVu-Sans-Mono", size = 30, lines = { "int main(void) {", "    pthread_mutex_lock(&m);", "    return 0; }" },
      sentence = "int main(void) { pthread_mutex_lock(&m); return 0; }" },
    { name = "groceries", font = "DejaVu-Sans", size = 40, lines = { "grocery list:", "eggs, milk, bread, apples" },
      sentence = "grocery list: eggs, milk, bread, apples" },
    { name = "sea", font = "DejaVu-Serif", size = 40, lines = { "the tide comes in", "and takes the sandcastle" },
      sentence = "the tide comes in and takes the sandcastle" },
}

-- Draw each picture, then shrink it the build's way into a JPEG.
local jobs = {}
for _, c in ipairs(cases) do
    local cmd = { "magick -size 900x300 xc:white -font", c.font, "-pointsize", c.size, "-fill black" }
    for n, line in ipairs(c.lines) do cmd[#cmd + 1] = string.format("-annotate +30+%d %q", 50 + n * 60, line) end
    local drawn = SCRATCH .. "/" .. c.name .. ".png"
    cmd[#cmd + 1] = string.format("%q", drawn)
    local r = os.execute(table.concat(cmd, " "))
    if r ~= 0 and r ~= true then error("could not draw " .. c.name .. " (ImageMagick)") end
    jobs[#jobs + 1] = { source = drawn, target = SCRATCH .. "/" .. c.name .. ".jpg" }
end
local long_side = require("config-loader").load().picture_embeddings.long_side
pictures.shrink_all(jobs, long_side, SCRATCH)

local embed = pictures.server_embedder(endpoint, SCRATCH, 120)
local ok, first = pcall(embed, jobs[1].target)
if not ok then
    -- the server is up but answers no picture: started without its vision
    -- projector, or a text-only model
    print("SKIP: the server at " .. endpoint .. " cannot see pictures: " .. tostring(first):sub(1, 200))
    os.exit(0)
end

local picture_vectors, sentence_vectors = { first }, {}
for i = 2, #cases do picture_vectors[i] = embed(jobs[i].target) end
for i, c in ipairs(cases) do sentence_vectors[i] = text_vector(c.sentence) end

for i, c in ipairs(cases) do
    local best, best_j, own = -2, nil, nil
    for j = 1, #cases do
        local score = cosine(picture_vectors[i], sentence_vectors[j])
        if j == i then own = score end
        if score > best then best, best_j = score, j end
    end
    check(string.format("the picture of the %s sits closest to its own words (%.3f)", c.name, own),
        best_j == i, "closest was the " .. cases[best_j].name .. string.format(" sentence (%.3f)", best))
end

os.execute(string.format("rm -rf %q", SCRATCH))
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
