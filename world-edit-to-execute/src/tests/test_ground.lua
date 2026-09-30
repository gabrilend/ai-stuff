--[[
Tests for ground textures (Issue 526): which tileset layers and subtiles
each cell gets, the stand-in textures' layout and corner shapes, tile
paths from TerrainArt\Terrain.slk, and a whole map handed to the
renderer (a recording stand-in for it).
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ground = require("assets.ground")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ A 3 x 2 tile point terrain (two cells) from a table of textures
-- tex[j][i] (rows from the south)
local function terrain(tex, var)
    local t = { width = #tex[1], height = #tex }
    function t:get_tile(i, j)
        return { ground_texture = tex[j + 1][i + 1], texture_details = var and var[j + 1][i + 1] or 0 }
    end
    return t
end

local function entry(cells, cell, q)
    local o = cell * 8 + (q - 1) * 2
    return cells:byte(o + 1), cells:byte(o + 2)
end
-- }}}

-- {{{ Layers per cell
test_section("Layers per cell")
do
    local B = ground.BITS
    -- cell 0: all tileset 2; cell 1: 0 at south-west... see below
    local t = terrain({ { 2, 2, 1 }, { 2, 2, 3 } }, { { 5, 0, 0 }, { 0, 0, 0 } })
    local cells, used = ground.cells(t, { [1] = true, [2] = true, [3] = false })
    test("two cells", #cells == 16 and used == 2)
    local l, v = entry(cells, 0, 1)
    test("a cell of one tileset: that tileset, whole", l == 2 and entry(cells, 0, 2) == 255)
    test("an extended tileset's variation 5 -> whole variation subtile 21", v == 21)
    -- cell 1: SW 2, SE 1, NW 2, NE 3
    l, v = entry(cells, 1, 1)
    test("the lowest tileset first, whole", l == 1 and v == ground.variation(true, 0))
    local l2, v2 = entry(cells, 1, 2)
    test("then tileset 2 on its corners (south-west, north-west)", l2 == 2 and v2 == B.sw + B.nw)
    local l3, v3 = entry(cells, 1, 3)
    test("then tileset 3 on its corner (north-east)", l3 == 3 and v3 == B.ne)
    test("and nothing more", entry(cells, 1, 4) == 255)
    test("plain tilesets: variation 0 is the whole tile (15), others 0", ground.variation(false, 0) == 15
        and ground.variation(false, 3) == 0)
    test("extended: 16 is 15, beyond is 0", ground.variation(true, 16) == 15 and ground.variation(true, 17) == 0)
    local skipped = ground.cells(t, {}, function(i) return i == 1 end)
    test("a skipped cell has no layers", entry(skipped, 1, 1) == 255 and entry(skipped, 0, 1) == 2)
end
-- }}}

-- {{{ Stand-in textures
test_section("Stand-in textures")
do
    local img = ground.standin({ 100, 150, 50 }, 7)
    test("extended layout, 512 x 256", img.width == 512 and img.height == 256 and #img.rgba == 512 * 256 * 4)
    local function alpha(px, py) return img.rgba:byte((py * 512 + px) * 4 + 4) end
    local function subtile_alpha(v, fx, fy)       -- fx east, fy south, 0..1
        local col, row = v % 4, math.floor(v / 4)
        return alpha(col * 64 + math.floor(fx * 63), row * 64 + math.floor(fy * 63))
    end
    test("subtile 0 is clear", subtile_alpha(0, 0.5, 0.5) == 0)
    test("subtile 15 is whole", subtile_alpha(15, 0.1, 0.9) == 255 and subtile_alpha(15, 0.9, 0.1) == 255)
    local B = ground.BITS
    test("the north-west subtile covers its north-west corner, not the south-east",
        subtile_alpha(B.nw, 0.02, 0.02) == 255 and subtile_alpha(B.nw, 0.98, 0.98) == 0)
    test("the south-east one the other way round",
        subtile_alpha(B.se, 0.98, 0.98) == 255 and subtile_alpha(B.se, 0.02, 0.02) == 0)
    test("the right half is whole variations", alpha(300, 100) == 255 and alpha(511, 255) == 255)
    local r, g = img.rgba:byte(1), img.rgba:byte(2)
    test("in the tileset's colour, roughly", g > r and math.abs(r - 100) < 60)
end
-- }}}

-- {{{ Paths from the install's table
test_section("Tile paths")
do
    local A = { table = function(_, path)
        if path ~= ground.SLK then return nil end
        return { rows = { Ldrt = { dir = "TerrainArt\\LordaeronSummer", file = "Lords_Dirt" } } }
    end }
    test("a tileset's path: folder, file, .blp", ground.path(A, "Ldrt") == "TerrainArt\\LordaeronSummer\\Lords_Dirt.blp")
    test("one the table lacks: nil", ground.path(A, "Zzzz") == nil)
    test("no install: nil", ground.path(nil, "Ldrt") == nil)
end
-- }}}

-- {{{ A whole map onto the renderer
test_section("DAoW 5.4b's ground")
do
    local map_scene = require("demo.wc3map.scene")
    local s = map_scene.load(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x")
    local got = { textures = 0 }
    local fake = {
        tex_create = function(w, h, rgba, wrap)
            got.textures = got.textures + 1
            got.wrap = wrap
            return got.textures
        end,
        land_tiles = function(ids, cells)
            got.ids, got.cells = ids, cells
            return 123
        end,
    }
    local t0 = os.clock()
    local r = ground.apply(fake, nil, s)
    print(string.format("  %d tilesets, %d cells textured, %.2fs", r.tilesets, r.cells, os.clock() - t0))
    test("every tileset the map lists gets a texture", got.textures == #s.terrain.ground_tilesets and r.standin == r.tilesets)
    test("clamped, not wrapped (subtiles mustn't bleed)", got.wrap == false)
    local w, h = s.terrain.width, s.terrain.height
    test("a layer list for every cell", #got.cells == (w - 1) * (h - 1) * 8)
    test("most cells are textured (cliffs and blight aren't)", r.cells > (w - 1) * (h - 1) * 0.5, tostring(r.cells))
    local bad = 0
    for k = 0, (w - 1) * (h - 1) - 1 do
        local o = k * 8
        local last = -1
        for q = 0, 3 do
            local l = got.cells:byte(o + q * 2 + 1)
            if l ~= 255 then
                if l <= last or l >= r.tilesets then bad = bad + 1 end
                last = l
            end
        end
    end
    test("layers rise within each cell and are the map's tilesets", bad == 0, bad .. " bad cells")
    test("what the renderer built is reported", r.triangles == 123)
end
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
