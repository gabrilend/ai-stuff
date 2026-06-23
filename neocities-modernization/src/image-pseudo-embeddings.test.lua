-- Tests for image-pseudo-embeddings.lua (Issue 9-013 redesign).
-- Run: luajit src/image-pseudo-embeddings.test.lua
-- Pure math + string checks; no I/O, no GPU. Fast and deterministic.
package.path = "./src/?.lua;./libs/?.lua;" .. package.path
local M = require("image-pseudo-embeddings")

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1
    else failed = failed + 1; print("  FAIL: " .. name) end
end
local function approx(a, b) return math.abs(a - b) < 1e-6 end
local function vec_approx(v, expected)
    if #v ~= #expected then return false end
    for i = 1, #v do if not approx(v[i], expected[i]) then return false end end
    return true
end
local function by_id(list)
    local m = {} for _, p in ipairs(list) do m[p.id] = p end return m
end

local R2 = 1 / math.sqrt(2)  -- 0.7071...

-- Chronological spine: three orthogonal unit embeddings at t=100,200,300.
local poems = {
    { poem_index = 1, timestamp = 100, embedding = {1, 0, 0} },
    { poem_index = 2, timestamp = 200, embedding = {0, 1, 0} },
    { poem_index = 3, timestamp = 300, embedding = {0, 0, 1} },
}

local images = {
    { id = "between12", source_name = "my-art", rel_below_source = "a.png",            timestamp = 150 },
    { id = "before",    source_name = "my-art", rel_below_source = "b.png",            timestamp = 50  },
    { id = "after",     source_name = "my-art", rel_below_source = "c.png",            timestamp = 350 },
    { id = "exact2",    source_name = "my-art", rel_below_source = "d.png",            timestamp = 200 },
    { id = "between23", source_name = "my-art", rel_below_source = "sub/e.png",        timestamp = 250 },
}

local pseudo, skipped = M.compute_image_pseudo_embeddings(poems, images)
local p = by_id(pseudo)

check("all 5 images got pseudo-embeddings", #pseudo == 5 and #skipped == 0)

-- Between p1 (1,0,0) and p2 (0,1,0): midpoint (0.5,0.5,0) -> normalized (R2,R2,0).
check("between12 is normalized midpoint", vec_approx(p.between12.embedding, {R2, R2, 0}))
-- Before the first poem: leans only on p1 -> (1,0,0).
check("before-first uses following poem", vec_approx(p.before.embedding, {1, 0, 0}))
-- After the last poem: leans only on p3 -> (0,0,1).
check("after-last uses preceding poem", vec_approx(p.after.embedding, {0, 0, 1}))
-- Exact timestamp match snaps to that poem (p2), not an average across it.
check("exact-match snaps to that poem", vec_approx(p.exact2.embedding, {0, 1, 0}))
-- Between p2 and p3: (0,0.5,0.5) -> (0,R2,R2).
check("between23 midpoint", vec_approx(p.between23.embedding, {0, R2, R2}))

-- Every pseudo-embedding is unit length.
for _, e in ipairs(pseudo) do
    local s = 0; for i = 1, #e.embedding do s = s + e.embedding[i]^2 end
    check("unit length: " .. e.id, approx(s, 1))
end

-- Title formatting (shared with 10-042d).
check("title: top-level",
    M.qualified_image_title("my-art", "air-defence-drones-5.png") == "my-art: air-defence-drones-5.png")
check("title: nested",
    M.qualified_image_title("my-art", "game-design/camera-idea.png") == "my-art: game-design: camera-idea.png")
check("title: leading slash tolerated",
    M.qualified_image_title("my-art", "/game-design/camera-idea.png") == "my-art: game-design: camera-idea.png")
check("title: display_title carried on pseudo-poem",
    p.between23.display_title == "my-art: sub: e.png")

-- Empty timeline -> every image skipped (no neighbours), reported not crashed.
local none, all_skipped = M.compute_image_pseudo_embeddings({}, images)
check("empty timeline skips all images", #none == 0 and #all_skipped == 5)

print(string.format("\nimage-pseudo-embeddings: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
