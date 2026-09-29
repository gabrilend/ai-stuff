-- 077-checking-the-pool.lua
--
-- Checks issue 809a: a card holds every field docs/067 lists.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local pool = require("076-the-pool")

local folder = kit.scratch("pool")
local asset_path = folder .. "/still-001.png"
kit.write_file(asset_path, "not a real png, just a stand-in for the test")

local card = pool.card({
    what = "a still of the blueprint graph",
    category = "diagram",
    params = { seed = 7, width = 800, height = 600 },
    seed = 7,
    paintbrush = "the-chart-canvas",
    paintbrush_version = "805a",
    canvas = "notes-blueprint.lua",
})

for _, field in ipairs(pool.FIELDS) do
    kit.check(card[field] ~= nil, "the card holds the field " .. field)
end
kit.equal(#card.ratings, 0, "ratings start empty")

pool.write_card(asset_path, card)
local read_back = pool.read_card(asset_path)
kit.equal(read_back.what, card.what, "what round-trips")
kit.equal(read_back.category, card.category, "category round-trips")
kit.equal(read_back.seed, card.seed, "seed round-trips")
kit.equal(read_back.params.width, 800, "a nested param round-trips")

kit.raises(function() pool.card({ what = "x" }) end, "missing field",
    "a card missing a required field is refused, naming it")

kit.finish()
