-- Tests for augment-embeddings-with-images.lua (Issue 9-013 redesign).
-- Run: luajit src/augment-embeddings-with-images.test.lua [DIR]
-- Part 1: pure logic on fixtures. Part 2: a read-only sanity pass over the real
-- data (counts + idempotency) WITHOUT writing anything.
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
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
local function make_inputs()
    local embeddings = { embeddings = {
        { embedding = {1,0,0}, poem_index = 1, id = 1 },
        { embedding = {0,1,0}, poem_index = 2, id = 2 },
        { embedding = {0,0,1}, poem_index = 3, id = 3 },
        { embedding = {0.9,0.1,0}, poem_index = 4, id = 4 },  -- image-only, junk 🖼 vec
    }}
    local poems = { poems = {
        { poem_index = 1, id = 1, category = "fediverse", content = "a real thought about the world", creation_date = "2024-01-01T00:00:00Z" },
        { poem_index = 2, id = 2, category = "fediverse", content = "another genuine sentence here", creation_date = "2024-01-03T00:00:00Z" },
        { poem_index = 3, id = 3, category = "fediverse", content = "text with an attached picture below", creation_date = "2024-01-05T00:00:00Z", attachments = {{ url = "/m/x.png", media_type = "image/png" }} },
        { poem_index = 4, id = 4, category = "fediverse", content = "🖼", creation_date = "2024-01-04T00:00:00Z", attachments = {{ url = "/m/y.png", media_type = "image/png" }} },
    }}
    local catalog = { images = {
        { source_name = "my-art", hash = "abc123", filename = "factory-cube.png",
          source_directory = "/p/input/images/my-art",
          relative_path = "/p/input/images/my-art/factory-cube.png",
          modification_date = "2024-01-02T00:00:00Z", width = 100, height = 100 },
    }}
    return embeddings, poems, catalog
end

local emb, poems, catalog = make_inputs()
local out, manifest, report = A.augment(emb, poems, catalog)

check("class1 (text+image) counted", report.class1 == 1)
check("class2 (image-only) counted", report.class2 == 1)
check("class3 (standalone) appended", report.class3 == 1)
check("no skips", report.skipped == 0)
check("output has 5 entries (4 poems + 1 image)", #out == 5)

-- p4 (image-only @ Jan-4) sits between p2 (Jan-3) and p3 (Jan-5). Since
-- 2026-06-23 an image CROSS-CUTS its neighbours (image-pseudo-embeddings.lua:
-- the first half of its dimensions from the poem before, the rest from the
-- poem after) instead of averaging them. With 3 dimensions the seam falls
-- after the first: (p2[1], p3[2], p3[3]) = (0, 0, 1). This test still
-- expected the old midpoint (0, R2, R2) until 2026-10-20.
local p4 = out[4]
check("class-2 embedding is its neighbours cross-cut", vapprox(p4.embedding, {0, 0, 1}))
-- catalog image @ Jan-2 sits between p1 (Jan-1) and p2 (Jan-3): avg -> (R2,R2,0).
local appended = out[5]
check("class-3 appended embedding is the midpoint", vapprox(appended.embedding, {R2, R2, 0}))
check("appended entry flagged is_image", appended.is_image == true)
check("appended entry id prefixed", appended.id == "img-abc123")
check("appended entry got a fresh poem_index", appended.poem_index == 5)

check("manifest marks poem 4 as class-2 image", manifest["4"] and manifest["4"].class == 2)
check("manifest marks poem 5 as class-3 image", manifest["5"] and manifest["5"].class == 3)
check("manifest carries the qualified title", manifest["5"].display_title == "my-art: factory-cube.png")

-- Idempotency: feed the output back in (as if re-running on an augmented file).
local emb2 = { embeddings = out, metadata = {} }
local out2, _, report2 = A.augment(emb2, poems, catalog)
check("idempotent: same entry count on re-run", #out2 == #out)
check("idempotent: same class counts", report2.class2 == 1 and report2.class3 == 1)
check("idempotent: class-2 embedding stable", vapprox(out2[4].embedding, {0, 0, 1}))

-- Pictures are numbered after the highest poem in poems.json, not after the
-- highest poem that has an embedding. Poems can arrive after the embeddings
-- were made (16 notes on 2026-10-07); numbering after the embeddings gave
-- pictures those new poems' numbers, and the pictures drew in their place.
do
    local e, p, c = make_inputs()
    -- a fifth poem, written after the embeddings were made: no embedding yet
    p.poems[#p.poems + 1] = { poem_index = 5, id = 5, category = "notes",
        content = "a note added later", creation_date = "2024-01-06T00:00:00Z" }
    local o, m = A.augment(e, p, c)
    check("a picture is numbered after the highest poem, embedded or not", o[#o].poem_index == 6)
    check("no picture takes a real poem's number", m["5"] == nil)
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
        local rout, rmanifest, rreport = A.augment(real_emb, real_poems, real_cat)
        print(string.format("\n[real data: %s] class1=%d class2=%d class3=%d skipped=%d  (%d -> %d entries)",
            model, rreport.class1, rreport.class2, rreport.class3, rreport.skipped, #real_emb.embeddings, #rout))
        check(model .. ": image-only posts found (~52)", rreport.class2 >= 40 and rreport.class2 <= 70)
        check(model .. ": standalone images appended (~692)", rreport.class3 >= 600 and rreport.class3 <= 720)
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
        local rout2 = A.augment({ embeddings = rout, metadata = {} }, real_poems, real_cat)
        check(model .. ": idempotent entry count", #rout2 == #rout)
    end
end
check("real data: at least one model's embeddings were checked", checked > 0)
-- }}}

print(string.format("\naugment-embeddings: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
