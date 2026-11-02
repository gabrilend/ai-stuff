-- 145-checking-the-gallery.lua
--
-- Checks issue 810, step 1: the gallery lists exactly the assets the
-- count utility counts — per category, nested folders included, nothing
-- that is not a pooled asset (ratings files, the floor table) — each with
-- its category, its kind and its tier. Runs with no window.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local pool = require("076-the-pool")
local viewer = require("144-the-viewer")

local pool_dir = kit.scratch("gallery")

-- {{{ local function make_asset
local function make_asset(name, category)
    local path = pool_dir .. "/" .. name
    local folder = path:match("^(.*)/[^/]*$")
    kit.fs.make_folder(folder)
    kit.write_file(path, "not a real " .. name)
    pool.write_card(path, pool.card({
        what = name, category = category, params = {}, seed = 1,
        paintbrush = "test", paintbrush_version = "1", canvas = "test.lua",
    }))
    return path
end
-- }}}

local still = make_asset("b-still.png", "still")
make_asset("a-still.png", "still")
make_asset("clips/turn.gif", "clip")
make_asset("clips/turn.mp4", "clip")
make_asset("notes/story.txt", "note")
make_asset("src/adder.lua", "source")
make_asset("deep/er/chart.png", "chart")
kit.write_file(pool_dir .. "/stray.png", "an asset with no card is not pooled")
pool.rate(still, 4, "person")
pool.rate(still, 2, "machine")
pool.set_floor(pool_dir, "still", 3)

local entries = viewer.gallery(pool_dir)
local by_category = {}
for _, e in ipairs(entries) do
    by_category[e.category] = (by_category[e.category] or 0) + 1
end
local counts = pool.counts(pool_dir)
local total = 0
for category, n in pairs(counts) do
    kit.equal(by_category[category], n, "the gallery shows as many " .. category .. " as the count utility counts")
    total = total + n
end
for category in pairs(by_category) do
    kit.check(counts[category] ~= nil, "every category the gallery shows is one the count utility counts: " .. category)
end
kit.equal(#entries, total, "the gallery lists exactly the assets the count utility counts")
kit.equal(#entries, 7, "seven pooled assets, the stray file without a card left out")

local names = {}
for i, e in ipairs(entries) do names[i] = e.name end
kit.equal(table.concat(names, " "),
    "deep/er/chart.png clips/turn.gif clips/turn.mp4 notes/story.txt src/adder.lua a-still.png b-still.png",
    "sorted by category, then name, nested folders included")

local b = entries[7]
kit.equal(b.tier, 4, "an asset's tier is its person's latest rating")
kit.equal(b.ratings, 2, "every rating is counted")
kit.equal(entries[6].tier, nil, "an unrated asset has no tier")
kit.equal(b.kind, "still", "a .png is a still")
kit.equal(entries[2].kind, "clip", "a .gif is a clip")
kit.equal(entries[3].kind, "clip", "an .mp4 is a clip")
kit.equal(entries[4].kind, "text", "a .txt is text")
kit.equal(entries[5].kind, "source", "anything else with a card is source")

local floors = pool.floors(pool_dir)
kit.check(viewer.in_use(b, floors), "a tier-4 still is in use above floor 3")
kit.check(not viewer.in_use(entries[6], floors), "an unrated still is left out by floor 3")
kit.check(viewer.in_use(entries[1], floors), "floor 0 leaves nothing out")

kit.equal(#viewer.gallery(kit.scratch("empty-gallery")), 0, "an empty pool shows nothing")

kit.finish()
