-- Tests for augment-embeddings-with-images.lua (Issue 9-013 redesign).
-- Run: luajit src/augment-embeddings-with-images.test.lua [DIR]
-- Part 1: pure logic on fixtures. Part 2: a read-only sanity pass over the real
-- data (counts + idempotency) WITHOUT writing anything.
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path
_G.AUGMENT_NO_MAIN = true  -- suppress the script's main() on require
local A = require("augment-embeddings-with-images")

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

-- p4 (image-only @ Jan-4) sits between p2 (Jan-3) and p3 (Jan-5): avg -> (0,R2,R2).
local p4 = out[4]
check("class-2 embedding replaced with neighbor average", vapprox(p4.embedding, {0, R2, R2}))
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
check("idempotent: class-2 embedding stable", vapprox(out2[4].embedding, {0, R2, R2}))
-- }}}

-- {{{ Part 2: real-data sanity (read-only)
local function read_json(p)
    local f = io.open(p, "r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return require("dkjson").decode(s)
end
local model = (os.getenv("MODEL_NAME") or "nomic-embed-text-v1.5"):gsub(":", "_")
local real_emb = read_json(DIR .. "/assets/embeddings/" .. model .. "/embeddings.json")
local real_poems = read_json(DIR .. "/assets/poems.json")
local real_cat = read_json(DIR .. "/assets/image-catalog.json")
if real_emb and real_poems and real_cat then
    local rout, rmanifest, rreport = A.augment(real_emb, real_poems, real_cat)
    print(string.format("\n[real data] class1=%d class2=%d class3=%d skipped=%d  (%d -> %d entries)",
        rreport.class1, rreport.class2, rreport.class3, rreport.skipped, #real_emb.embeddings, #rout))
    check("real: image-only posts found (~52)", rreport.class2 >= 40 and rreport.class2 <= 70)
    check("real: standalone images appended (~692)", rreport.class3 >= 600 and rreport.class3 <= 720)
    check("real: output grew by class3", #rout == #real_poems.poems + rreport.class3)
    -- idempotency on real data (re-run on the augmented set)
    local rout2 = A.augment({ embeddings = rout, metadata = {} }, real_poems, real_cat)
    check("real: idempotent entry count", #rout2 == #rout)
else
    print("\n[real data] skipped (data files not all present)")
end
-- }}}

print(string.format("\naugment-embeddings: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
