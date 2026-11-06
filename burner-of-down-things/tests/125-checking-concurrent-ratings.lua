-- 125-checking-concurrent-ratings.lua
--
-- Checks issue 809b: ratings append one line at a time beside the card,
-- safe under two writers at once -- two writers appending together both
-- survive, neither line lost or interleaved; the card is never rewritten;
-- what the ratings resolve to as one tier, and the per-tier counts.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local pool = require("076-the-pool")

local pool_dir = kit.scratch("concurrent-ratings")

-- {{{ local function make_asset
local function make_asset(name, category)
    local path = pool_dir .. "/" .. name
    kit.write_file(path, "not a real asset: nothing here may open it")
    pool.write_card(path, pool.card({
        what = name, category = category, params = {}, seed = 1,
        paintbrush = "test", paintbrush_version = "1", canvas = "test.lua",
    }))
    return path
end
-- }}}

local asset = make_asset("a.png", "diagram")
local card_before = kit.fs.read(asset .. ".card")

-- Two writers, two processes, started together, each appending many ratings.
local per_writer = 300
local writer = pool_dir .. "/writer.lua"
kit.write_file(writer, string.format([[
local dir, asset, label, count = %q, %q, arg[1], %d
dofile(dir .. "/src/013-paths.lua").set_search_path(dir)
local pool = require("076-the-pool")
for i = 1, count do
    pool.rate(asset, (i %% 5) + 1, "person", label .. " " .. i .. " " .. string.rep("x", 200))
end
]], kit.DIR, asset, per_writer))
local together = "luajit " .. kit.fs.quote(writer) .. " a & luajit " .. kit.fs.quote(writer) .. " b & wait"
kit.check(kit.fs.run(together), "both writers ran")

local ratings = pool.ratings(asset)
kit.equal(#ratings, per_writer * 2, "every rating from both writers survives")
local seen = { a = {}, b = {} }
local whole = true
for _, r in ipairs(ratings) do
    local label, i, pad = r.note:match("^(%a) (%d+) (x+)$")
    if not label or #pad ~= 200 or r.tier ~= (tonumber(i) % 5) + 1 then
        whole = false
    else
        seen[label][tonumber(i)] = true
    end
end
kit.check(whole, "no line is interleaved with another: every one reads back whole")
local all = true
for _, label in ipairs({ "a", "b" }) do
    for i = 1, per_writer do
        if not seen[label][i] then all = false end
    end
end
kit.check(all, "every rating from each writer is there, none lost")
kit.equal(kit.fs.read(asset .. ".card"), card_before, "rating never rewrites the card")
kit.equal(#pool.read_card(asset).ratings, per_writer * 2, "the card reads back with every rating appended")

-- What ratings resolve to as one tier: a person's latest, else a machine's.
local b = make_asset("b.png", "diagram")
kit.equal(pool.tier(pool.ratings(b)), nil, "an asset never rated has no tier")
pool.rate(b, 2, "machine")
kit.equal(pool.tier(pool.ratings(b)), 2, "a machine's rating counts when no person has rated")
pool.rate(b, 4, "person", "better than it looks")
pool.rate(b, 1, "machine")
kit.equal(pool.tier(pool.ratings(b)), 4, "a person's rating outranks any machine's")
pool.rate(b, 5, "person")
kit.equal(pool.tier(pool.ratings(b)), 5, "a person's latest rating is the one that counts")
kit.equal(pool.ratings(b)[2].note, "better than it looks", "a note reads back")

make_asset("c.png", "chart")
local counts = pool.tier_counts(pool_dir)
kit.equal(counts.diagram[5], 1, "per-tier counts: b is a five")
-- a's last rating is either writer's 300th, and (300 % 5) + 1 is 1.
kit.equal(counts.diagram[1], 1, "per-tier counts: a is a one, by its latest rating")
kit.equal(counts.chart.unrated, 1, "an unrated asset is counted as unrated")

-- Refusals.
kit.raises(function() pool.rate(b, 6, "person") end, "from 1 to 5", "a tier past five is refused")
kit.raises(function() pool.rate(b, 3, "a friend") end, "'person' or 'machine'", "a rater that is neither is refused")
kit.raises(function() pool.rate(pool_dir .. "/nothing.png", 3, "person") end, "no card", "an asset with no card is refused")
kit.raises(function() pool.rate(b, 3, "person", string.rep("y", 2000)) end, "at most", "a line too long to append whole is refused")

kit.finish()
