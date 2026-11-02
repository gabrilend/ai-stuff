-- 146-checking-the-viewer-keys.lua
--
-- Checks issue 810, step 2, with no window: a keypress 1-5 appends one
-- rating line to the right asset and touches nothing else; a floor is
-- only proposed by "]" (its cost said first) and set by "y"; the frame's
-- draw list holds one tile per asset, the selection, and the floor's
-- left-out assets drawn dim.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local pool = require("076-the-pool")
local viewer = require("144-the-viewer")
local sha = require("015-sha-256")

local pool_dir = kit.scratch("viewer-keys")

-- {{{ local function make_asset
local function make_asset(name, category)
    local path = pool_dir .. "/" .. name
    kit.write_file(path, "not a real " .. name)
    pool.write_card(path, pool.card({
        what = name, category = category, params = {}, seed = 1,
        paintbrush = "test", paintbrush_version = "1", canvas = "test.lua",
    }))
    return path
end
-- }}}

-- {{{ local function fingerprint
local function fingerprint(skip)
    local out = {}
    for _, name in ipairs(kit.fs.list(pool_dir)) do
        local path = pool_dir .. "/" .. name
        if not skip[path] then
            out[#out + 1] = name .. " " .. sha.of_string(kit.fs.read(path))
        end
    end
    return table.concat(out, "\n")
end
-- }}}

local a = make_asset("a.png", "still")
local b = make_asset("b.png", "still")
local c = make_asset("c.txt", "note")

local state = viewer.open(pool_dir, 600, 400)
kit.equal(#state.entries, 3, "the viewer opens on every pooled asset")
kit.equal(state.entries[state.selected].asset, c, "the first selected is the first in gallery order (note before still)")

viewer.key(state, "right")
kit.equal(state.entries[state.selected].asset, a, "right moves the selection on")
local before = fingerprint({ [pool.ratings_path(a)] = true })
viewer.key(state, "3")
local ratings = pool.ratings(a)
kit.equal(#ratings, 1, "a keypress appends one rating line")
kit.equal(ratings[1].tier, 3, "with the key's tier")
kit.equal(ratings[1].by, "person", "by a person")
kit.equal(#pool.ratings(b), 0, "to the selected asset only")
kit.equal(fingerprint({ [pool.ratings_path(a)] = true }), before, "every other file in the pool is unchanged, the card included")
kit.equal(state.entries[state.selected].tier, 3, "the gallery shows the new tier at once")
kit.equal(state.entries[state.selected].asset, a, "and keeps the selection on the rated asset")
kit.check(state.status:find("rated a.png 3", 1, true) ~= nil, "the status line says what was rated")

viewer.key(state, "6")
viewer.key(state, "0")
kit.equal(#pool.ratings(a), 1, "keys outside 1-5 rate nothing")

viewer.key(state, "]")
kit.check(state.status:find("still: floor 0 -> 1 leaves 1 of 2 in use; 1 below it", 1, true) ~= nil,
    "] says what raising the floor would leave: " .. state.status)
kit.check(not kit.fs.exists(pool.floors_path(pool_dir)), "] alone sets nothing")
viewer.key(state, "left")
kit.check(not kit.fs.exists(pool.floors_path(pool_dir)), "any other key leaves the floor as it was")
viewer.key(state, "right")
viewer.key(state, "]")
viewer.key(state, "y")
kit.equal(pool.floors(pool_dir).still, 1, "y after ] sets the floor")
kit.check(state.status:find("^floor set: still: floor 0 %-> 1") ~= nil, "the status line says the floor was set")
viewer.key(state, "y")
kit.equal(pool.floors(pool_dir).still, 1, "y with nothing proposed does nothing")

local list = viewer.frame(state)
kit.equal(list[1].op, "clear", "a frame starts by clearing to the ground")
kit.equal(table.concat(list[1].colour, ","), "0,0,0", "the default ground is black")
local tiles, images, dim, bright_tile_for_b = 0, 0, 0, nil
for _, cmd in ipairs(list) do
    if cmd.op == "rect" and cmd.w == viewer.TILE then
        tiles = tiles + 1
        if cmd.colour == viewer.INK.night.dim then dim = dim + 1 end
    elseif cmd.op == "image" then
        images = images + 1
    end
end
kit.equal(tiles, 3, "one tile per asset")
kit.equal(images, 2, "the two stills are drawn as pictures")
kit.equal(dim, 1, "the unrated still the floor leaves out is drawn dim")
local selection = 0
for _, cmd in ipairs(list) do
    if cmd.op == "rect" and cmd.w == viewer.TILE + 8 then selection = selection + 1 end
end
kit.equal(selection, 1, "the selection is drawn once")
kit.equal(list[#list].op, "text", "the status line is drawn last")

viewer.key(state, "q")
kit.check(state.quit, "q quits")

local empty = viewer.open(kit.scratch("viewer-empty"), 600, 400)
viewer.key(empty, "3")
kit.equal(empty.status, "the pool is empty", "an empty pool rates nothing and says so")
kit.equal(viewer.frame(empty)[2].text, "the pool is empty", "and draws only the status line")

kit.finish()
