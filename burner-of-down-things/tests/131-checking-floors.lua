-- 131-checking-floors.lua
--
-- Checks issue 809d: a floor per category, 0 until raised; raising one
-- reports how many assets fall below it before the table changes; the
-- utility discards nothing — every asset, card and ratings file is byte for
-- byte what it was.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local pool = require("076-the-pool")
local sha = require("015-sha-256")

local pool_dir = kit.scratch("pool-floors")

-- {{{ local function make_asset
local function make_asset(name, category, tiers)
    local path = pool_dir .. "/" .. name
    kit.write_file(path, "asset bytes of " .. name)
    pool.write_card(path, pool.card({
        what = name, category = category, params = {}, seed = 1,
        paintbrush = "test", paintbrush_version = "1", canvas = "test.lua",
    }))
    for _, t in ipairs(tiers) do
        pool.rate(path, t[1], t[2])
    end
end
-- }}}

-- {{{ local function fingerprint
-- Every file under the pool but the floor table, by name and SHA-256.
local function fingerprint(dir, out)
    out = out or {}
    for _, name in ipairs(kit.fs.list(dir)) do
        local path = dir .. "/" .. name
        if kit.fs.is_folder(path) then
            fingerprint(path, out)
        elseif name ~= pool.FLOORS_FILE then
            local f = assert(io.open(path, "rb"))
            out[#out + 1] = path .. " " .. sha.of_string(f:read("*a"))
            f:close()
        end
    end
    table.sort(out)
    return table.concat(out, "\n")
end
-- }}}

make_asset("a.png", "still", { { 5, "person" } })
make_asset("b.png", "still", { { 2, "person" }, { 4, "machine" } })   -- person's 2 wins
make_asset("c.png", "still", { { 3, "machine" } })
make_asset("d.png", "still", {})                                      -- unrated
make_asset("e.png", "chart", { { 1, "person" } })

local before = fingerprint(pool_dir)

kit.equal(pool.floor(pool.floors(pool_dir), "still"), 0, "every category's floor is 0 until raised")

local dry = pool.floor_report(pool_dir, "still", 3)
kit.equal(dry.total, 4, "the dry run counts every still")
kit.equal(dry.remain, 2, "floor 3 keeps the 5 and the 3")
kit.equal(dry.below, 2, "floor 3 leaves the 2 and the unrated one below it")
kit.equal(dry.unrated, 1, "the unrated still is named among those below")
kit.equal(dry.from, 0, "the report says the floor it starts from")
kit.check(dry.line:find("leaves 2 of 4 in use; 2 below it") ~= nil, "the report says the cost in one line: " .. dry.line)
kit.equal(pool.floors(pool_dir).still, nil, "a dry run changes no floor")

local zero = pool.floor_report(pool_dir, "still", 0)
kit.equal(zero.below, 0, "floor 0 leaves nothing out, the unrated included")

local set = pool.set_floor(pool_dir, "still", 3)
kit.equal(set.below, 2, "raising the floor says its cost first")
kit.equal(pool.floor(pool.floors(pool_dir), "still"), 3, "the raised floor is in the table")
kit.equal(pool.floor(pool.floors(pool_dir), "chart"), 0, "another category keeps floor 0")

local higher = pool.floor_report(pool_dir, "still", 5)
kit.equal(higher.from, 3, "a later report starts from the raised floor")
kit.equal(higher.remain, 1, "floor 5 keeps only the 5")

pool.set_floor(pool_dir, "chart", 2)
kit.equal(pool.floors(pool_dir).still, 3, "setting one category's floor keeps the others")
kit.equal(pool.floor_report(pool_dir, "nothing-yet", 4).total, 0, "a category with no assets costs nothing")

kit.equal(fingerprint(pool_dir), before, "the utility discards nothing: every asset, card and ratings file is unchanged")
kit.equal(pool.counts(pool_dir).still, 4, "the floor table is not counted as a card")

kit.raises(function() pool.floor_report(pool_dir, "still", 6) end, "0 to 5", "a floor above 5 is refused")
kit.raises(function() pool.set_floor(pool_dir, "still", -1) end, "0 to 5", "a negative floor is refused")
kit.raises(function() pool.set_floor(pool_dir, "", 1) end, "non-empty string", "an empty category is refused")

kit.finish()
