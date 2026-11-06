-- Tests for augment-embeddings-with-images.lua (Issue 9-013): pictures placed
-- among the poems by their own vectors.
-- Run: luajit src/augment-embeddings-with-images.test.lua [--dir PATH]
-- Part 1: pure logic on fixtures. Part 2: a read-only sanity pass over the real
-- data (counts + idempotency) WITHOUT writing anything.
-- The project folder from --dir PATH, or nil when it was not given (the
-- default below is then used); a stray word on the command line stops the
-- program, named (libs/project-dir.lua, Issue 10-076).
local PROJECT_DIR_ARG = (function()
    local own = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    local dir = dofile(own .. "../libs/project-dir.lua").read(arg, "")
    if dir == "" then return nil end
    return dir
end)()

local DIR = PROJECT_DIR_ARG or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path
_G.AUGMENT_NO_MAIN = true  -- suppress the script's main() on require
local A = require("augment-embeddings-with-images")
local utils = require("utils")  -- Issue 10-054: locate embeddings wherever they live

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; print("  FAIL: " .. name) end
end
local function approx(a, b) return math.abs(a - b) < 1e-6 end
local function vapprox(v, e)
    if #v ~= #e then return false end
    for i = 1, #v do if not approx(v[i], e[i]) then return false end end
    return true
end
local R2 = 1 / math.sqrt(2)

-- {{{ Part 1: fixtures
-- Since 2026-10-25 a picture is placed by its own vector (Stage 6's picture
-- step asks the vision model). The fixtures stand in for that step with a
-- table of picture vectors by path; a picture missing from it is an error,
-- as a picture missing from the real cache is.
local PICTURES = {
    ["/p/input/media_attachments/files/x.png"] = { 1, 0, 0 },     -- poem 3's picture
    ["/p/input/media_attachments/files/y.png"] = { 0, 3, 4 },     -- poem 4's picture
    ["/p/input/images/my-art/factory-cube.png"] = { 0, 0.6, 0.8 }, -- the gallery picture
}
local function pictures_in(table_of)
    local asked = {}
    return {
        dir = "/p",
        text_share = 0.5,
        vector_of = function(p)
            asked[#asked + 1] = p
            return (table_of or PICTURES)[p] or error("no picture vector for " .. p)
        end,
    }, asked
end

local function make_inputs()
    local embeddings = { embeddings = {
        { embedding = {1,0,0}, poem_index = 1, id = 1 },
        { embedding = {0,1,0}, poem_index = 2, id = 2 },
        { embedding = {0,0,1}, poem_index = 3, id = 3 },
        { embedding = {0.9,0.1,0}, poem_index = 4, id = 4 },  -- image-only, junk 🖼 vec
        { embedding = {0.5,0.5,0}, poem_index = 6, id = 6 },  -- video-only, junk vec
    }}
    local poems = { poems = {
        { poem_index = 1, id = 1, category = "fediverse", content = "a real thought about the world", creation_date = "2024-01-01T00:00:00Z" },
        { poem_index = 2, id = 2, category = "fediverse", content = "another genuine sentence here", creation_date = "2024-01-03T00:00:00Z" },
        { poem_index = 3, id = 3, category = "fediverse", content = "text with an attached picture below", creation_date = "2024-01-05T00:00:00Z", attachments = {{ relative_path = "files/x.png", media_type = "image/png" }} },
        { poem_index = 4, id = 4, category = "fediverse", content = "🖼", creation_date = "2024-01-04T00:00:00Z", attachments = {{ relative_path = "files/y.png", media_type = "image/png" }} },
        { poem_index = 6, id = 6, category = "fediverse", content = "", creation_date = "2024-01-02T00:00:00Z", attachments = {{ relative_path = "files/v.mp4", media_type = "video/mp4" }} },
    }}
    local catalog = { images = {
        { source_name = "my-art", hash = "abc123", filename = "factory-cube.png",
          source_directory = "/p/input/images/my-art",
          relative_path = "/p/input/images/my-art/factory-cube.png",
          file_path = "/p/input/images/my-art/factory-cube.png",
          modification_date = "2024-01-02T00:00:00Z", width = 100, height = 100 },
        { source_name = "fediverse-media", hash = "def456", file_path = "/p/input/media_attachments/files/x.png" },
    }}
    return embeddings, poems, catalog
end

local emb, poems, catalog = make_inputs()
local out, manifest, report = A.augment(emb, poems, catalog, pictures_in())
local by_number = {}
for _, e in ipairs(out) do by_number[e.poem_index] = e end

check("class1 (text+image) counted", report.class1 == 1)
check("class2 (image-only, a picture or a video) counted", report.class2 == 2)
check("class3 (standalone) appended, fediverse-media left to the posts", report.class3 == 1)
check("placed by pictures: the picture-only post and the gallery picture", report.by_picture == 2)
check("placed by neighbours: only the post with no picture", report.by_neighbours == 1)
check("blended: the text + picture post", report.blended == 1)
check("no skips", report.skipped == 0)
check("output has 6 entries (5 poems + 1 picture)", #out == 6)

check("a picture-only post takes its picture's vector, normalised",
    vapprox(by_number[4].embedding, {0, 0.6, 0.8}))
check("a text + picture post is half its text, half its picture",
    vapprox(by_number[3].embedding, {R2, 0, R2}))
check("and keeps its text vector beside the blend", vapprox(by_number[3].text_embedding, {0, 0, 1}))
-- The video-only post (Jan-2) sits between p1 (Jan-1) and p2 (Jan-3): their
-- cross-cut, the first dimension from p1, the rest from p2: (1, 1, 0)/sqrt 2.
check("a post with no picture keeps the neighbours-in-time cross-cut",
    vapprox(by_number[6].embedding, {R2, R2, 0}))
local appended = out[6]
check("a gallery picture takes its own vector", vapprox(appended.embedding, {0, 0.6, 0.8}))
check("appended entry flagged is_image", appended.is_image == true)
check("appended entry id prefixed", appended.id == "img-abc123")
check("appended entry got a fresh poem_index", appended.poem_index == 7)

check("manifest marks poem 4 as class-2, placed by its picture",
    manifest["4"] and manifest["4"].class == 2 and manifest["4"].placed_by == "picture")
check("manifest marks poem 6 as class-2, placed by its neighbours",
    manifest["6"] and manifest["6"].placed_by == "neighbours")
check("manifest marks poem 7 as class-3 image", manifest["7"] and manifest["7"].class == 3)
check("manifest carries the qualified title", manifest["7"].display_title == "my-art: factory-cube.png")

-- Idempotency: feed the output back in (as if re-running on an augmented
-- file). The blend is made again from the kept text vector, not from the
-- blend: blending a blend would pull the post further toward its picture
-- every run.
local emb2 = { embeddings = out, metadata = {} }
local out2, _, report2 = A.augment(emb2, poems, catalog, pictures_in())
local by_number2 = {}
for _, e in ipairs(out2) do by_number2[e.poem_index] = e end
check("idempotent: same entry count on re-run", #out2 == #out)
check("idempotent: same class counts", report2.class2 == 2 and report2.class3 == 1)
check("idempotent: the blend is not blended again", vapprox(by_number2[3].embedding, {R2, 0, R2}))
check("idempotent: the text vector is still the text", vapprox(by_number2[3].text_embedding, {0, 0, 1}))

-- A picture with no vector stops the step, naming the picture.
do
    local e, p, c = make_inputs()
    local partial = { ["/p/input/media_attachments/files/x.png"] = { 1, 0, 0 },
                      ["/p/input/media_attachments/files/y.png"] = { 0, 3, 4 } }
    local ok, err = pcall(A.augment, e, p, c, pictures_in(partial))
    check("a picture with no vector is an error naming it",
        not ok and tostring(err):find("factory-cube.png", 1, true) ~= nil)
end

-- The two steps agree on the pictures: every picture this step asks for is
-- one Stage 6's picture step embeds.
do
    local e, p, c = make_inputs()
    local into, asked = pictures_in()
    A.augment(e, p, c, into)
    _G.PICTURE_EMBEDDINGS_NO_MAIN = true
    local step = dofile(DIR .. "/src/picture-embeddings.lua")
    local placed = {}
    for _, path in ipairs(step.pictures_to_place("/p", p, c)) do placed[path] = true end
    local all = #asked > 0
    for _, path in ipairs(asked) do if not placed[path] then all = false end end
    check("every picture asked for is one the picture step embeds", all)
end

-- Pictures are numbered after the highest poem in poems.json, not after the
-- highest poem that has an embedding. Poems can arrive after the embeddings
-- were made (16 notes on 2026-10-07); numbering after the embeddings gave
-- pictures those new poems' numbers, and the pictures drew in their place.
do
    local e, p, c = make_inputs()
    -- an eighth poem, written after the embeddings were made: no embedding yet
    p.poems[#p.poems + 1] = { poem_index = 8, id = 8, category = "notes",
        content = "a note added later", creation_date = "2024-01-06T00:00:00Z" }
    local o, m = A.augment(e, p, c, pictures_in())
    check("a picture is numbered after the highest poem, embedded or not", o[#o].poem_index == 9)
    check("no picture takes a real poem's number", m["8"] == nil)
end
-- }}}

-- {{{ Part 2: real-data sanity (read-only)
local function read_json(p)
    local f = io.open(p, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return require("dkjson").decode(s)
end
-- Every model with embeddings on disk is checked by name: config.lua names
-- no default model (owner, 2026-10-21), and this check used to read
-- "whichever model is the default" -- nomic, months out of date.
local real_poems = read_json(DIR .. "/assets/poems.json")
local real_cat = read_json(DIR .. "/assets/image-catalog.json")
local listing = io.popen("ls " .. DIR .. "/assets/embeddings")
local models = {}
for name in listing:lines() do models[#models + 1] = name end
listing:close()
local checked = 0
for _, model in ipairs(models) do
    local real_emb = read_json(utils.embeddings_dir(model) .. "/embeddings.json")
    -- a model folder without embeddings (an old evaluation leftover): nothing
    -- to check for it
    if real_emb and real_poems and real_cat then
        checked = checked + 1
        -- Stand-in picture vectors, the model's length: the real ones exist
        -- only for a model whose Stage 6 has run with its vision projector,
        -- and this pass checks the counts, not the vectors.
        local dims = #real_emb.embeddings[1].embedding
        local real_in = {
            dir = DIR, text_share = 0.5,
            vector_of = function(p)
                local v = {}
                for i = 1, dims do v[i] = 0 end
                v[#p % dims + 1] = 1
                return v
            end,
        }
        local rout, rmanifest, rreport = A.augment(real_emb, real_poems, real_cat, real_in)
        print(string.format("\n[real data: %s] text+picture=%d (blended %d) picture-only=%d gallery=%d by-neighbours=%d skipped=%d  (%d -> %d entries)",
            model, rreport.class1, rreport.blended, rreport.class2, rreport.class3, rreport.by_neighbours,
            rreport.skipped, #real_emb.embeddings, #rout))
        check(model .. ": image-only posts found (~68)", rreport.class2 >= 40 and rreport.class2 <= 80)
        check(model .. ": standalone images appended (~667)", rreport.class3 >= 600 and rreport.class3 <= 720)
        check(model .. ": only a few posts have no picture in their media (3 in 2026-10)",
            rreport.by_neighbours <= 10)
        -- one entry per poem that HAS an embedding, plus the pictures. Poems
        -- without one (added after the embeddings were made) are counted and
        -- shown: they are data to refresh, not a code fault.
        local embedded = 0
        local in_poems = {}
        for _, p in ipairs(real_poems.poems) do in_poems[p.poem_index] = true end
        for _, e in ipairs(real_emb.embeddings) do
            if not e.is_image and in_poems[e.poem_index] then embedded = embedded + 1 end
        end
        print(string.format("[real data: %s] %d of %d poems have an embedding",
            model, embedded, #real_poems.poems))
        check(model .. ": output is the embedded poems plus the pictures", #rout == embedded + rreport.class3)
        -- idempotency on real data (re-run on the augmented set)
        local rout2 = A.augment({ embeddings = rout, metadata = {} }, real_poems, real_cat, real_in)
        check(model .. ": idempotent entry count", #rout2 == #rout)
    end
end
check("real data: at least one model's embeddings were checked", checked > 0)
-- }}}

print(string.format("\naugment-embeddings: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
