#!/usr/bin/env luajit
-- test_wpm_shd_mmp.lua - the pathing map, shadow map and minimap icons (issue 119)
--
-- In plain terms: the three readers read files the test builds itself,
-- refuse damaged ones with an error saying what is wrong, and read every
-- test map's files. On the test maps, the pathing map is the size the
-- terrain says, its water lines up with the terrain's (row 0 is the south
-- edge, not the north), and the minimap's start icons sit where the
-- players start, in the players' colours.
--
-- Run: luajit src/tests/test_wpm_shd_mmp.lua [DIR]
-- Issue: issues/completed/119-pathing-shadow-and-minimap-readers.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local wpm = require("parsers.wpm")
local shd = require("parsers.shd")
local mmp = require("parsers.mmp")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function errors(f, ...)
    local ok, err = pcall(f, ...)
    return not ok, tostring(err)
end
local function i32(n)
    if n < 0 then n = n + 4294967296 end
    return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end

-- {{{ The pathing map
print("\n=== The pathing map (war3map.wpm) ===")
-- 4 x 2: the south row is ground, open; then no-walk, no-fly, no-build;
-- the north row is deep water, blight, the map's edge, shallow water.
local south = string.char(0x40, 0x42, 0x44, 0x48)
local north = string.char(0x0a, 0x60, 0xce, 0x00)
local built = "MP3W" .. i32(0) .. i32(4) .. i32(2) .. south .. north
local p = wpm.parse(built)
test("size and version", p.width == 4 and p.height == 2 and p.version == 0)
test("row 0 is the south edge", p:flags(0, 0) == 0x40 and p:flags(0, 1) == 0x0a)
test("open ground: walk, fly, build, no water", p:walkable(0, 0) and p:flyable(0, 0) and p:buildable(0, 0)
    and not p:water(0, 0) and not p:blighted(0, 0))
test("each flag on its own", not p:walkable(1, 0) and p:flyable(1, 0)
    and not p:flyable(2, 0) and p:walkable(2, 0) and not p:buildable(3, 0) and p:walkable(3, 0))
test("deep water: no walking or building, water", not p:walkable(0, 1) and not p:buildable(0, 1) and p:water(0, 1))
test("blight", p:blighted(1, 1) and p:walkable(1, 1))
test("the edge: nothing", not p:walkable(2, 1) and not p:flyable(2, 1) and not p:buildable(2, 1))
test("shallow water: walkable, buildable as the editor says", p:water(3, 1) and p:walkable(3, 1))
test("outside the map is nil", p:flags(4, 0) == nil and p:walkable(-1, 0) == nil and p:flags(0, 2) == nil)
local c = p:counts()
test("counts", c.cells == 8 and c.NO_WALK == 3 and c.NO_WATER == 6 and c.BLIGHT == 1 and c.UNKNOWN == 1,
    string.format("%d %d %d", c.NO_WALK, c.NO_WATER, c.BLIGHT))
test("size from the terrain: four per cell each way", select(1, wpm.size_for(257, 129)) == 1024
    and select(2, wpm.size_for(257, 129)) == 512)

local bad, msg = errors(wpm.parse, built:sub(1, -2))
test("one byte short: cut short, by how much", bad and msg:find("need a file of 24 bytes, but it is 23 (cut short)", 1, true), msg)
bad, msg = errors(wpm.parse, built .. "x")
test("one byte over: refused", bad and msg:find("bytes left over", 1, true), msg)
bad, msg = errors(wpm.parse, "MP3W" .. i32(0))
test("a short header", bad and msg:find("header needs 16", 1, true), msg)
bad, msg = errors(wpm.parse, "W3E!" .. built:sub(5))
test("another file's start", bad and msg:find("not \"MP3W\"", 1, true), msg)
bad, msg = errors(wpm.parse, "MP3W" .. i32(1) .. built:sub(9))
test("an unknown version", bad and msg:find("version 1", 1, true), msg)
bad, msg = errors(wpm.parse, "MP3W" .. i32(0) .. i32(-4) .. i32(2) .. south .. north)
test("a negative size", bad and msg:find("-4 x 2", 1, true), msg)
bad, msg = errors(wpm.parse, "MP3W" .. i32(0) .. i32(100000) .. i32(100000))
test("a size that would ask for gigabytes", bad and msg:find("each side 1 to", 1, true), msg)
local cuts_ok = true
for n = 0, #built - 1 do
    if not errors(wpm.parse, built:sub(1, n)) then cuts_ok = false end
end
test("every cut of the file is refused", cuts_ok)
-- }}}

-- {{{ The shadow map
print("\n=== The shadow map (war3map.shd) ===")
local sbytes = string.char(0, 0, 255, 0, 255, 255, 0, 0)
local s = shd.parse(sbytes, 4, 2)
test("shadowed cells, row 0 the south edge", s:shadowed(2, 0) and not s:shadowed(0, 0)
    and s:shadowed(0, 1) and s:shadowed(1, 1) and not s:shadowed(3, 1))
test("the count", s.shadowed_cells == 3 and s.odd_bytes == 0)
test("outside the map is nil", s:shadowed(4, 0) == nil)
local free = shd.parse(sbytes)
test("without a size: counts, no lookups", free.shadowed_cells == 3 and free:shadowed(0, 0) == nil)
test("a byte other than 0 or 255 counts as shadow, and is counted as odd",
    shd.parse(string.char(0, 7, 255), 3, 1).odd_bytes == 1 and shd.parse(string.char(0, 7, 255), 3, 1):shadowed(1, 0))
bad, msg = errors(shd.parse, sbytes, 4, 3)
test("a size that disagrees with the file", bad and msg:find("4 x 3 cells need 12 bytes, but the file is 8", 1, true), msg)
bad = errors(shd.parse, sbytes, 4)
test("a width without a height", bad)
test("an empty map with no shadows", shd.parse("", nil, nil).shadowed_cells == 0)
-- }}}

-- {{{ The minimap icons
print("\n=== The minimap icons (war3map.mmp) ===")
local function icon(t, x, y, r, g, b, a)
    return i32(t) .. i32(x) .. i32(y) .. string.char(b, g, r, a)
end
local mbytes = i32(0) .. i32(4) .. icon(0, 10, 20, 255, 255, 0, 255) .. icon(1, 30, 40, 255, 255, 255, 255)
    .. icon(2, 52, 80, 255, 3, 3, 255) .. icon(7, 1, 2, 0, 0, 0, 0)
local m = mmp.parse(mbytes)
test("four icons", #m.icons == 4 and m.version == 0)
test("the kinds", m.icons[1].kind == "gold_mine" and m.icons[2].kind == "neutral_building"
    and m.icons[3].kind == "player_start")
test("positions", m.icons[3].x == 52 and m.icons[3].y == 80)
test("the colour is stored blue first", m.icons[3].color.r == 255 and m.icons[3].color.g == 3
    and m.icons[3].color.b == 3 and m.icons[1].color.b == 0)
test("an unknown type is kept, not refused", m.icons[4].kind == "unknown" and m.icons[4].type == 7)
test("counted by kind", m.by_kind.player_start == 1 and m.by_kind.unknown == 1)
bad, msg = errors(mmp.parse, mbytes:sub(1, -2))
test("cut short", bad and msg:find("4 icons need a file of 72 bytes, but it is 71 (cut short)", 1, true), msg)
bad, msg = errors(mmp.parse, i32(0) .. i32(-1))
test("a negative count", bad and msg:find("count of -1", 1, true), msg)
bad, msg = errors(mmp.parse, i32(3) .. i32(0))
test("an unknown version", bad and msg:find("version 3", 1, true), msg)
test("no icons at all", #mmp.parse(i32(0) .. i32(0)).icons == 0)
-- }}}

-- {{{ The test maps
print("\n=== Every test map ===")
local ok_mpq, mpq = pcall(require, "mpq")
local maps = {}
local ls = io.popen('ls "' .. DIR .. '/assets/"*.w3x 2>/dev/null')
for line in ls:lines() do maps[#maps + 1] = line end
ls:close()
if not ok_mpq or #maps == 0 then
    print("  [SKIP] no test maps (or no StormLib) here")
else
    local w3e, w3i = require("parsers.w3e"), require("parsers.w3i")
    local read, sized, problems = 0, 0, {}
    local water_up, water_down = {}, {}
    local starts_ok, starts = 0, 0
    -- The standard player colours, by player number
    local COLOURS = { [0] = { 255, 3, 3 }, { 0, 66, 255 }, { 28, 230, 185 }, { 84, 0, 129 }, { 255, 252, 1 },
        { 254, 138, 14 }, { 32, 192, 0 }, { 229, 91, 176 }, { 149, 150, 151 }, { 126, 191, 241 },
        { 16, 98, 70 }, { 78, 42, 4 } }
    for _, path in ipairs(maps) do
        local name = path:match("([^/]+)%.w3x$")
        local a = mpq.open(path)
        local t = w3e.parse(a:extract("war3map.w3e"))
        local okp, pm = pcall(wpm.parse, a:extract("war3map.wpm"))
        local w, h = wpm.size_for(t.width, t.height)
        local oks, sm = pcall(shd.parse, a:extract("war3map.shd"), w, h)
        local okm, mm = pcall(mmp.parse, a:extract("war3map.mmp"))
        if okp and oks and okm then read = read + 1 else
            problems[#problems + 1] = name .. ": " .. tostring(not okp and pm or not oks and sm or mm)
        end
        if okp and pm.width == w and pm.height == h then sized = sized + 1 end
        -- Water by the terrain against water by the pathing map, both ways up
        if okp and (name == "DAoW-2.1" or name == "Daow4.4") then
            local up, down, n = 0, 0, 0
            for y = 0, t.height - 1, 3 do
                for x = 0, t.width - 1, 3 do
                    local tp = t:get_tile(x, y)
                    local wet = tp.has_water and tp.water_level > tp.height
                    local a1 = pm:water(math.min(4 * x, w - 1), math.min(4 * y, h - 1))
                    local a2 = pm:water(math.min(4 * x, w - 1), h - 1 - math.min(4 * y, h - 1))
                    n = n + 1
                    if a1 == wet then up = up + 1 end
                    if a2 == wet then down = down + 1 end
                end
            end
            water_up[name], water_down[name] = up / n, down / n
        end
        -- Each start icon, against the start of the player in its colour
        if okm then
            local info = w3i.parse(a:extract("war3map.w3i"))
            -- The minimap shows the playable area: the map less its margins
            -- (A left, B right, C bottom, D top, in cells)
            local left = t.offset_x + info.margins[1] * 128
            local top = t.offset_y + (info.margins[3] + info.playable_height) * 128
            local span_x, span_y = info.playable_width * 128, info.playable_height * 128
            for _, ic in ipairs(mm.icons) do
                if ic.kind == "player_start" then
                    starts = starts + 1
                    for _, pl in ipairs(info.players or {}) do
                        local col = COLOURS[pl.number]
                        -- (within 2 a channel: one map's yellow is 255/252/0, not /1)
                        if col and math.abs(col[1] - ic.color.r) <= 2 and math.abs(col[2] - ic.color.g) <= 2
                            and math.abs(col[3] - ic.color.b) <= 2 then
                            local mx = (pl.start_x - left) / span_x * 256
                            local my = (top - pl.start_y) / span_y * 256
                            if math.abs(mx - ic.x) <= 2 and math.abs(my - ic.y) <= 2 then
                                starts_ok = starts_ok + 1
                            end
                        end
                    end
                end
            end
        end
        a:close()
    end
    test("all three read in every test map (" .. #maps .. ")", read == #maps, table.concat(problems, "; "))
    test("every pathing map is four cells per terrain cell each way", sized == #maps)
    for name, up in pairs(water_up) do
        test(string.format("%s: the pathing map's water lines up with the terrain's south-up (%.0f%%, %.0f%% upside down)",
            name, up * 100, water_down[name] * 100), up > 0.85 and up > water_down[name] + 0.15)
    end
    test(string.format("every start icon (%d) is within 2 minimap pixels of the start of the player in its colour, y from the top",
        starts), starts > 0 and starts_ok == starts, starts_ok .. " of " .. starts)
end
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
