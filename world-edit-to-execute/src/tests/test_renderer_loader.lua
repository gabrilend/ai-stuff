#!/usr/bin/env luajit
-- test_renderer_loader.lua - the renderer reads through the asset loader (issue 606a)
--
-- In plain terms: the loader answers the renderer's questions (a texture,
-- a model, a stock table, which model an object uses and its scale) the
-- way the map's asset handle does, but with the player's asset packs
-- first; the model cache and the ground take a loader in place of the
-- handle; and a texture saved again in a pack goes into the texture
-- already made for it, once the renderer can replace one (tex_update,
-- faked here: render/models.c doesn't have it yet).
--
-- Nothing here is drawn: the renderer is a fake that records its calls.
--
-- Run: luajit src/tests/test_renderer_loader.lua [DIR]
-- Issue: issues/606a-hot-reload-swaps-in-renderer-sound-and-ui.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local assets = require("assets")
local loader = require("assets.loader")
local gpu = require("assets.gpu")
local ground = require("assets.ground")
local hotreload = require("assets.hotreload")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

-- {{{ helpers
-- An uncompressed TGA, N by N, every pixel one colour.
local function tga(n, r, g, b)
    local head = string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                             n % 256, math.floor(n / 256), n % 256, math.floor(n / 256), 32, 0x28)
    return head .. string.char(b, g, r, 255):rep(n * n)
end
local RED, BLUE, GREY = tga(2, 255, 0, 0), tga(3, 0, 0, 255), tga(4, 90, 90, 90)
local function colour(img)
    if not img then return "none" end
    local r, g, b = img.rgba:byte(1, 3)
    return r .. "," .. g .. "," .. b
end
local function rgb(rgba) local r, g, b = rgba:byte(1, 3); return r .. "," .. g .. "," .. b end

local function write(path, bytes)
    os.execute("mkdir -p " .. sh(path:match("^(.*)/[^/]*$")))
    local f = assert(io.open(path, "wb"))
    f:write(bytes)
    f:close()
end

-- A BLP and an MDX from a test map, when the maps are here
local BLP, MDX
do
    local ok, mpq = pcall(require, "mpq")
    local map = DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"
    local ar = ok and io.open(map, "rb") and mpq.open(map)
    if ar then
        for _, n in ipairs(ar:list()) do
            local got, d = pcall(ar.extract, ar, n)
            if got and d then
                if not BLP and d:sub(1, 4) == "BLP1" then BLP = d end
                if not MDX and d:sub(1, 4) == "MDLX" then MDX = d end
            end
            if BLP and MDX then break end
        end
    end
end

-- A stand-in for assets.open's handle: the map's files, two stock tables,
-- and model_for / scale_for written the way assets/init.lua writes them
-- (through self:table and self:model), so a loader that borrows them
-- reads the model packs first.
local Map = {}
Map.__index = Map
function Map.new(files, tables)
    return setmetatable({ files = files, tables = tables, map = {}, reads = 0 }, Map)
end
function Map:read(path)
    self.reads = self.reads + 1
    local d = self.files[loader.key_of(path)]
    if d then return d, "map" end
    return nil, "not in the map"
end
function Map:table(path) return self.tables[path] end
function Map:texture(path)
    local d = self:read(path)
    return d and require("parsers.tga").decode(d) or nil
end
function Map:model() return nil end    -- the map has no models of its own
function Map:model_for(kind, id)
    local t = self:table("Units\\UnitUI.slk")
    local row = t and t.rows[id]
    if not row then return nil end
    local m = self:model(row.file)
    if m then return m, assets.model_path(row.file) end
    return nil
end
function Map:scale_for(kind, id)
    local t = self:table("Units\\UnitUI.slk")
    local row = t and t.rows[id]
    return row and row.scale or 1
end

-- A renderer that records what it was asked to make and replace
local function fake_render(with_update)
    local calls = { created = {}, updated = {} }
    local r = {
        tex_create = function(w, h, rgba) calls.created[#calls.created + 1] = { w = w, h = h, rgba = rgba }; return #calls.created end,
        mesh_create = function() return 1 end,
        model_create = function() return 1 end,
        calls = calls,
    }
    if with_update then
        r.tex_update = function(id, w, h, rgba) calls.updated[#calls.updated + 1] = { id = id, w = w, h = h, rgba = rgba } end
    end
    return r
end
-- }}}

local SCRATCH = os.tmpname()
os.remove(SCRATCH)
local DATA = SCRATCH .. "/player-data"
local MINE = DATA .. "/asset-packs/mine"
write(MINE .. "/Textures/Shield.tga", RED)
write(MINE .. "/textures/onlyblp.tga", RED)          -- a .tga beside nothing: L:texture("...blp") won't take it
if BLP then
    write(MINE .. "/textures/plain.blp", BLP)
    write(MINE .. "/TerrainArt/Test/Grass.blp", BLP)
end
if MDX then write(MINE .. "/units/mine/Knight.mdx", MDX) end

local A = Map.new({
    ["textures/shield.tga"] = GREY,                      -- the map has it too: the pack's comes first
    ["textures/maponly.tga"] = GREY,
}, {
    ["Units\\UnitUI.slk"] = { rows = { hkni = { file = "units\\mine\\Knight.mdl", scale = 1.25 } } },
    ["TerrainArt\\Terrain.slk"] = { rows = { Tgrs = { dir = "TerrainArt\\Test", file = "Grass" } } },
})
local L = loader.new({ packs = { "mine" }, data = DATA, root = DIR, assets = A })

-- {{{ The loader answers as the handle does
print("\n=== The loader answers the renderer's questions ===")
test("a texture the pack and the map both have: the pack's", colour(L:texture("Textures\\Shield.tga")) == "255,0,0",
    colour(L:texture("Textures\\Shield.tga")))
test("the map's own reader still gives the map's", colour(A:texture("Textures\\Shield.tga")) == "90,90,90")
test("a texture only the map has: the map's", colour(L:texture("textures/maponly.tga")) == "90,90,90")
test("a missing texture: nil", L:texture("textures/nothing.tga") == nil and L:texture("") == nil and L:texture(nil) == nil)
test("a .blp asked for isn't answered with a .tga of the same name", L:texture("textures/onlyblp.blp") == nil)
if BLP then
    local plain = L:texture("textures/plain.blp")
    test("a pack's BLP decodes", plain and plain.width > 0 and #plain.rgba == plain.width * plain.height * 4)
    test("a path with no extension is tried as .blp", L:texture("Textures\\Plain") == plain)
    test("a missing .tga is tried as .blp", L:texture("textures/plain.tga") == plain)
else
    print("  (no test map here: BLP checks skipped)")
end
test("a stock table comes through the handle", L:table("Units\\UnitUI.slk") == A.tables["Units\\UnitUI.slk"])
test("a stock table without a handle: nil", loader.new({ packs = {}, data = DATA, root = DIR }):table("x.slk") == nil)
if MDX then
    local m = L:model("units/mine/Knight.mdl")
    test("a model by its .mdl name: the pack's .mdx, parsed", type(m) == "table" and m.rgba == nil and m.geosets ~= nil)
    test("the same model again: the same table (cached)", L:model("Units\\Mine\\Knight") == m)
    test("a texture's path isn't a model", L:model("textures/shield.tga") == nil)
    local fm, fpath = L:model_for("unit", "hkni")
    test("model_for, borrowed from the handle, finds the pack's model", fm == m and fpath == "units\\mine\\Knight.mdx",
        tostring(fpath))
    test("the handle alone doesn't (the map has no models)", A:model_for("unit", "hkni") == nil)
else
    print("  (no test map here: model checks skipped)")
end
test("model_for of an object with no row: nil", L:model_for("unit", "zzzz") == nil)
test("scale_for, borrowed", L:scale_for("unit", "hkni") == 1.25 and L:scale_for("unit", "zzzz") == 1)
local bare = loader.new({ packs = { "mine" }, data = DATA, root = DIR })
local ok, err = pcall(bare.model_for, bare, "unit", "hkni")
test("model_for without a handle says it needs one", not ok and tostring(err):match("needs an assets handle"), tostring(err))
-- }}}

-- {{{ The model cache through the loader
print("\n=== The model cache reads through the loader ===")
local R = fake_render(false)
local cache = gpu.new(R, L)
local id = cache:texture({ path = "Textures\\Shield.tga", replaceable = 0 })
local made = R.calls.created[id]
test("a model texture is made from the pack's pixels", made and rgb(made.rgba) == "255,0,0" and made.w == 2)
local id2 = cache:texture({ path = "textures/shield.tga", replaceable = 0 })
test("the same path again (other case and slashes): no new texture", #R.calls.created == 1 and id2 == id)
local _, _, missing = cache:texture({ path = "textures/nothing.tga", replaceable = 0 })
test("a texture no source has is grey and marked missing", missing == true)
if MDX then
    local function asked() local n = 0; for _ in pairs(L.missing) do n = n + 1 end; return n end
    local before = asked()
    local mid = cache:build(L:model("units/mine/Knight.mdl"), "units\\mine\\Knight.mdx")
    test("the pack's model builds", mid ~= nil and cache.parts > 0)
    test("its textures were asked for through the loader (none is in the pack: noted missing)", asked() > before)
end
-- }}}

-- {{{ Retexturing
print("\n=== A texture saved again goes into the one already made ===")
local blue = require("parsers.tga").decode(BLUE)
test("without render.tex_update: nothing swapped", cache:retexture("Textures/Shield.tga", blue) == false)
local RU = fake_render(true)
local c2 = gpu.new(RU, L)
local sid = c2:texture({ path = "Textures\\Shield.tga", replaceable = 0 })
test("with it: swapped, by any spelling of the path", c2:retexture("textures/SHIELD.tga", blue) == true)
local u = RU.calls.updated[1]
test("into the same texture id, with the new size and pixels", u and u.id == sid and u.w == 3 and u.h == 3 and rgb(u.rgba) == "0,0,255")
test("a path no texture was made for: false", c2:retexture("textures/other.tga", blue) == false and #RU.calls.updated == 1)
test("no picture: false", c2:retexture("textures/shield.tga", nil) == false and c2:retexture("textures/shield.tga", "bytes") == false)
if BLP then
    -- asked for as .tga, read as the .blp: the .blp's reload reaches it
    local gid = c2:texture({ path = "Textures\\Plain.tga", replaceable = 0 })
    test("a .tga read as its .blp: the .blp saved again reaches it", c2:retexture("textures/plain.blp", blue) == true
        and RU.calls.updated[#RU.calls.updated].id == gid)
end
c2:solid_texture("<grey>", 1, 2, 3)
test("the cache's own made-up textures are never swapped", c2:retexture("<grey>", blue) == false)
-- }}}

-- {{{ The ground through the loader
print("\n=== The ground reads through the loader ===")
if BLP then
    local RG = fake_render(true)
    local terrain = { ground_tilesets = { "Tgrs", "Ldrt" } }
    local ids, extended, report = ground.textures(RG, L, terrain)
    test("a tileset a pack has: from the pack", report.real == 1 and report.paths.Tgrs == "TerrainArt\\Test\\Grass.blp")
    test("one nobody has: a stand-in", report.standin == 1 and #ids == 2)
    local on = ground.on_reload(RG, ids, terrain, report)
    test("its tileset saved again: swapped into its texture", on("terrainart/test/grass.blp", blue) == true
        and RG.calls.updated[1].id == ids[1])
    test("another path: nothing", on("terrainart/test/dirt.blp", blue) == false)
    test("no tex_update: nothing", ground.on_reload(fake_render(false), ids, terrain, report)("terrainart/test/grass.blp", blue) == false)
else
    print("  (no test map here: ground checks skipped)")
end
-- }}}

-- {{{ Hot-reload end to end
print("\n=== Saved in a pack, swapped in the renderer ===")
do
    local t = 0
    local RH = fake_render(true)
    local LH = loader.new({ packs = { "mine" }, data = DATA, root = DIR, assets = A })
    local ch = gpu.new(RH, LH)
    local tid = ch:texture({ path = "Textures\\Shield.tga", replaceable = 0 })
    local H = hotreload.new(LH, {
        backend = "poll", poll_interval = 0.5, quiet = 0.1,
        clock = function() return t end,
        on_reload = gpu.on_reload(ch),
    })
    write(MINE .. "/Textures/Shield.tga", BLUE)
    for _ = 1, 30 do
        t = t + 0.1
        H:poll()
        if #RH.calls.updated > 0 then break end
    end
    local up = RH.calls.updated[1]
    test("the saved texture reaches its texture id, blue", up and up.id == tid and rgb(up.rgba) == "0,0,255",
        up and rgb(up.rgba) or "no update")
    test("and the loader now gives the blue one", colour(LH:texture("Textures\\Shield.tga")) == "0,0,255")
    H:close()
    LH:close()
end
-- }}}

-- {{{ The viewer's switch (step 8) and the corner's lines (step 6)
print("\n=== WC3_HOT_RELOAD in the viewer and editor ===")
do
    local live = require("assets.live")
    local LV = loader.new({ packs = { "mine" }, data = DATA, root = DIR, assets = A })
    test("off unless asked for", live.from_env(LV, {}, {}) == nil and live.from_env(LV, {}, { WC3_HOT_RELOAD = "0" }) == nil)
    local t, said = 0, {}
    local RV = fake_render(true)
    local cv = gpu.new(RV, LV)
    local tid = cv:texture({ path = "Textures\\Shield.tga", replaceable = 0 })
    local terrain = { ground_tilesets = { "Tgrs" } }
    local gids, _, grep = ground.textures(RV, LV, terrain)
    local hot = live.from_env(LV, { models = cv, ground = { RV, gids, terrain, grep }, clock = function() return t end,
                                     poll_interval = 0.5, quiet = 0.1, print = function(l) said[#said + 1] = l end },
                              { WC3_HOT_RELOAD = "poll" })
    test("WC3_HOT_RELOAD=poll turns it on, with that watcher", hot and hot:status().backend == "poll")
    local function settle()
        for _ = 1, 30 do t = t + 0.1; if hot:tick() > 0 then return true end end
        return false
    end
    write(MINE .. "/Textures/Shield.tga", RED)
    test("a saved texture is read on a tick", settle())
    local up = RV.calls.updated[#RV.calls.updated]
    test("and swapped into its model texture", up and up.id == tid and rgb(up.rgba) == "255,0,0")
    test("the corner says so", hot:lines()[1] == "[hot-reload] reloaded Textures/Shield.tga" and said[1] == hot:lines()[1],
        tostring(hot:lines()[1]))
    if BLP then
        write(MINE .. "/TerrainArt/Test/Grass.blp", BLP .. "")
        os.execute("touch -d '+1 second' " .. sh(MINE .. "/TerrainArt/Test/Grass.blp"))
        test("a saved tileset is read", settle())
        test("and swapped into the ground's texture", RV.calls.updated[#RV.calls.updated].id == gids[1])
    end
    write(MINE .. "/Textures/Shield.tga", "not a picture")
    settle()
    local last = hot:lines()[#hot:lines()]
    test("a broken save: the corner says the old one stays", last and last:match("can't reload") and last:match("old one stays"),
        tostring(last))
    t = t + live.SHOW_FOR + 1
    test("the corner's lines go after a few seconds", #hot:lines() == 0)
    local texts = {}
    hot:say("one")
    local drawn = live.draw(hot, { ui_text = function(text, x, y) texts[#texts + 1] = { text, x, y } end }, 600)
    test("drawn bottom left through ui_text", drawn == 1 and texts[1][1] == "[hot-reload] one" and texts[1][3] == 576)
    test("no text in the renderer: nothing drawn", live.draw(hot, {}) == 0)
    -- without tex_update the corner says why nothing changed
    local RN = fake_render(false)
    local cn = gpu.new(RN, LV)
    cn:texture({ path = "Textures\\Shield.tga", replaceable = 0 })
    local hot2 = live.new(LV, { models = cn, clock = function() return t end, backend = "poll", print = function() end })
    write(MINE .. "/Textures/Shield.tga", BLUE)
    hot2.H:reload("Textures/Shield.tga")
    test("without tex_update: read, and the corner says it can't be shown yet",
        hot2:lines()[1]:match("not shown: the renderer can't replace a texture yet") and hot2:status().unshown == 1)
    hot:close(); hot2:close(); LV:close()
end
-- }}}

L:close()
os.execute("rm -rf " .. sh(SCRATCH))

print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
