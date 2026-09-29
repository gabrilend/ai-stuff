-- 098-checking-pool-counts.lua
--
-- Checks issue 809c: counts match the cards; nothing is read from any
-- asset file itself.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local pool = require("076-the-pool")

local pool_dir = kit.scratch("pool-counts")

-- {{{ local function make_asset
local function make_asset(name, category)
    local path = pool_dir .. "/" .. name
    -- Deliberately not a real asset: pool.counts must never open this.
    kit.write_file(path, "if opened as a real asset, this would not decode")
    pool.write_card(path, pool.card({
        what = name, category = category, params = {}, seed = 1,
        paintbrush = "test", paintbrush_version = "1", canvas = "test.lua",
    }))
end
-- }}}

make_asset("a.png", "diagram")
make_asset("b.png", "diagram")
make_asset("c.png", "chart")

kit.fs.make_folder(pool_dir .. "/nested")
kit.write_file(pool_dir .. "/nested/d.png", "not a real asset either")
pool.write_card(pool_dir .. "/nested/d.png", pool.card({
    what = "d", category = "still", params = {}, seed = 1,
    paintbrush = "test", paintbrush_version = "1", canvas = "test.lua",
}))

local counts = pool.counts(pool_dir)
kit.equal(counts.diagram, 2, "two diagrams counted")
kit.equal(counts.chart, 1, "one chart counted")
kit.equal(counts.still, 1, "a card nested in a subfolder still counts")
kit.equal(pool.counts(kit.scratch("empty-pool")).diagram, nil, "an empty pool counts nothing")

kit.finish()
