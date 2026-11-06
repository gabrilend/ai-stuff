--[[
Tests for war3map.w3i's random unit and item tables (issue 103b): each
item is its chance, then its ID; a unit table is its positions' types,
then rows of a chance and one ID per position. Read from Conquest-v8-fix,
the one test map with random item tables, and from tables built here, then
written back byte for byte. Also what follows the forces on every test map
(issue 103c): the four sections, the last a count of 0 that ends the
file, or a lone 0xFF in their place.
Run: luajit src/tests/test_w3i_random_tables.lua [project dir]
]]

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

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

local mpq = require("mpq")
local w3i = require("parsers.w3i")

local function i32(n)
    if n < 0 then n = n + 4294967296 end
    return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256)
end

-- {{{ Conquest-v8-fix's item tables
test_section("Conquest-v8-fix's random item tables")
do
    local a = mpq.open(DIR .. "/assets/Conquest-v8-fix.w3x")
    local d = a:extract("war3map.w3i")
    a:close()
    local m = w3i.parse(d)
    local t = m and m.random_item_tables or {}
    test("ten tables", #t == 10, tostring(#t))
    local first = t[1] or { sets = {} }
    test("the first is \"CS +200 dmg\", of 5 sets", first.name == "CS +200 dmg" and #first.sets == 5,
        tostring(first.name) .. ", " .. #first.sets)
    local it = first.sets[1] and first.sets[1].items[1] or {}
    test("its first item: I00C at 3%", it.id == "I00C" and it.chance == 3,
        tostring(it.id) .. " " .. tostring(it.chance))
    local ok_ids, ok_chances = true, true
    for _, tbl in ipairs(t) do
        for _, set in ipairs(tbl.sets) do
            for _, item in ipairs(set.items) do
                if not item.id:match("^[%w][%w][%w][%w]$") then ok_ids = false end
                if item.chance < 0 or item.chance > 100 then ok_chances = false end
            end
        end
    end
    test("every item an ID of four letters and digits", ok_ids)
    test("every chance a percentage", ok_chances)
    test("written back byte for byte", m and w3i.write(m) == d)
end
-- }}}

-- {{{ A unit table and an item table built here
test_section("Tables built here")
do
    local a = mpq.open(DIR .. "/assets/Master-Crafters-Final-Conquest.w3x")
    local m = w3i.parse(a:extract("war3map.w3i"))
    a:close()
    m.sections.random_units, m.sections.random_items = true, true
    m.tail_raw = ""
    m.random_unit_tables = {
        { number = 0, name = "Creeps", positions = {
            { type = 0, units = { { id = "nfor", chance = 70 }, { id = "ngno", chance = 30 } } },
            { type = 2, units = { { id = "ratc", chance = 70 }, { id = "bspd", chance = 30 } } },
        } },
    }
    m.random_item_tables = {
        { number = 1, name = "Loot", sets = {
            { items = { { id = "phea", chance = 60 }, { id = "pman", chance = 40 } } },
        } },
    }
    local bytes = w3i.write(m)
    local units_part = i32(1) .. i32(0) .. "Creeps\0" .. i32(2) .. i32(0) .. i32(2)
        .. i32(2) .. i32(70) .. "nforratc" .. i32(30) .. "ngnobspd"
    local items_part = i32(1) .. i32(1) .. "Loot\0" .. i32(1) .. i32(2)
        .. i32(60) .. "phea" .. i32(40) .. "pman"
    test("written as the files have them", bytes:sub(-(#units_part + #items_part)) == units_part .. items_part)
    local again = w3i.parse(bytes)
    local u = again and again.random_unit_tables and again.random_unit_tables[1]
    test("the unit table read back", u and u.name == "Creeps" and #u.positions == 2
        and u.positions[2].type == 2 and u.positions[1].units[2].id == "ngno"
        and u.positions[2].units[1].id == "ratc" and u.positions[2].units[1].chance == 70)
    local it = again and again.random_item_tables and again.random_item_tables[1]
    test("the item table read back", it and it.name == "Loot" and it.sets[1].items[2].id == "pman"
        and it.sets[1].items[2].chance == 40)
    test("and written again the same", again and w3i.write(again) == bytes)
end
-- }}}

-- {{{ What follows the forces, on every test map (issue 103c)
test_section("After the forces, on every test map")
do
    local h = io.popen('ls "' .. DIR .. '/assets/"*.w3x 2>/dev/null')
    local paths = {}
    for p in h:lines() do paths[#paths + 1] = p end
    h:close()
    local all_four, lone_ff, other = 0, 0, {}
    for _, path in ipairs(paths) do
        local a = mpq.open(path)
        local d = a and a:extract("war3map.w3i")
        if a then a:close() end
        local m = d and w3i.parse(d)
        local name = path:match("([^/]+)%.w3x$")
        local s = m and m.sections or {}
        if not m or w3i.write(m) ~= d then
            other[#other + 1] = name .. " (not read, or not written back as read)"
        elseif m.tail_raw == "" and s.upgrades and s.tech and s.random_units and s.random_items then
            all_four = all_four + 1
        elseif m.tail_raw == "\255" and not (s.upgrades or s.tech or s.random_units or s.random_items) then
            lone_ff = lone_ff + 1
        else
            other[#other + 1] = string.format("%s (%d bytes after the sections read)", name, #m.tail_raw)
        end
    end
    test("every map: the four sections, or a lone 0xFF in their place", #paths > 0 and #other == 0,
        table.concat(other, ", "))
    test("both kinds are among the test maps", all_four > 0 and lone_ff > 0,
        all_four .. " with the sections, " .. lone_ff .. " with 0xFF")

    -- Master-Crafters' file ends with its random item tables' count of 0,
    -- which used to be left unread as four unnamed bytes
    local a = mpq.open(DIR .. "/assets/Master-Crafters-Final-Conquest.w3x")
    local d = a:extract("war3map.w3i")
    a:close()
    local m = w3i.parse(d)
    test("a count of 0 as the file's last 4 bytes is read", m and m.sections.random_items
        and #m.random_item_tables == 0 and m.tail_raw == "" and d:sub(-4) == i32(0))
end
-- }}}

print(string.format("\n%d/%d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
