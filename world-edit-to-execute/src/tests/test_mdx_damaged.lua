--[[
Tests for damaged models (Issue 118): parsers/mdx.lua on records whose
size is 0 or runs past their chunk, on 16-bit and 8-bit lists cut short
by the file's end, and assets/gpu.lua on a triangle corner numbered past
its geoset's points. Every model here is built byte by byte, so the tests
need no maps.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local ffi = require("ffi")
local mdx = require("parsers.mdx")
local gpu = require("assets.gpu")
local bw = require("parsers.binwrite")
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

-- mdx.parse with a budget of Lua instructions, so a reading that never
-- ends fails its test instead of hanging the run (the count hook runs
-- only in the interpreter, so the JIT is off meanwhile)
local function parse_within(bytes)
    jit.off()
    jit.flush()
    debug.sethook(function() error("MDX test: still reading after the budget (a loop)") end, "", 2e7)
    local ok, m = pcall(mdx.parse, bytes)
    debug.sethook()
    jit.on()
    return ok, m
end
-- }}}

-- {{{ Writers for the format's pieces
local function u32(v) return bw.new():u32(v):done() end
local function i32(v) return bw.new():i32(v):done() end
local function u16(v) return bw.new():u16(v):done() end
local function f32(v) return bw.new():f32(v):done() end
local function fl(list) local b = bw.new() for _, v in ipairs(list) do b:f32(v) end return b:done() end
local function name(s, len) return s .. string.rep("\0", len - #s) end
local function chunk(tag, body) return tag .. u32(#body) .. body end
-- a record: its size (counting itself), then its body
local function sized(body) return u32(#body + 4) .. body end
local function ext() return f32(1) .. fl({ 0, 0, 0, 1, 1, 1 }) end

local function model(...) return "MDLX" .. chunk("VERS", u32(800)) .. table.concat({ ... }) end

-- one geoset's body (without its size): points, triangles, one group
local function geoset_body(points, corners)
    local b = { "VRTX" .. u32(#points / 3) .. fl(points), "NRMS" .. u32(#points / 3) }
    for _ = 1, #points / 3 do b[#b + 1] = fl({ 0, 0, 1 }) end
    b[#b + 1] = "PTYP" .. u32(1) .. u32(4) .. "PCNT" .. u32(1) .. u32(#corners) .. "PVTX" .. u32(#corners)
    for _, c in ipairs(corners) do b[#b + 1] = u16(c) end
    b[#b + 1] = "GNDX" .. u32(#points / 3) .. string.rep("\0", #points / 3)
    b[#b + 1] = "MTGC" .. u32(1) .. u32(1) .. "MATS" .. u32(1) .. u32(0)
    b[#b + 1] = u32(0) .. u32(0) .. u32(0) .. ext() .. u32(0)
    b[#b + 1] = "UVAS" .. u32(1) .. "UVBS" .. u32(#points / 3) .. string.rep(fl({ 0, 0 }), #points / 3)
    return table.concat(b)
end

-- one material with one plain layer
local function material_body(layer_size)
    local layer = u32(0) .. u32(0) .. u32(0) .. i32(-1) .. u32(0) .. f32(1)
    return i32(0) .. u32(0) .. "LAYS" .. u32(1) .. (layer_size and u32(layer_size) or u32(#layer + 4)) .. layer
end

local function node_body(n, id) return name(n, 80) .. i32(id) .. i32(-1) .. u32(0) end
-- }}}

-- {{{ A record whose size is 0
test_section("A record whose size is 0")

do
    local good = model(chunk("MTLS", sized(material_body())), chunk("GEOS", sized(geoset_body({ 0, 0, 0, 1, 0, 0, 0, 1, 0 }, { 0, 1, 2 }))))
    local ok, m = parse_within(good)
    test("the same records with their sizes read", ok and #m.materials == 1 and #m.geosets == 1, tostring(m))

    local cases = {
        -- each was read again from its own start, forever
        { "a material", chunk("MTLS", u32(0) .. material_body()) },
        { "a geoset", chunk("GEOS", u32(0) .. geoset_body({ 0, 0, 0, 1, 0, 0, 0, 1, 0 }, { 0, 1, 2 })) },
        { "an attachment", chunk("ATCH", u32(0) .. sized(node_body("Origin Ref", 0)) .. name("", 260) .. u32(0)) },
        { "a particle emitter", chunk("PRE2", u32(0) .. sized(node_body("dust", 0)) .. string.rep("\7", 40)) },
        -- these moved on, but read a record that isn't there
        { "a material's layer", chunk("MTLS", sized(material_body(0))) },
        { "a geoset animation", chunk("GEOA", u32(0) .. f32(1) .. u32(0) .. fl({ 1, 1, 1 }) .. u32(0)) },
        { "a bone", chunk("BONE", u32(0) .. node_body("root", 0) .. i32(0) .. i32(-1)) },
        { "a helper", chunk("HELP", u32(0) .. node_body("hand ref", 0)) },
        { "a texture animation", chunk("TXAN", u32(0) .. u32(0)) },
    }
    for _, case in ipairs(cases) do
        local ok2, err = parse_within(model(case[2]))
        test(case[1] .. " of size 0 is refused, not read forever",
            not ok2 and tostring(err):find("too short to move on", 1, true) ~= nil, tostring(err))
    end
    local ok3, err3 = parse_within(model(chunk("MTLS", u32(1000) .. material_body())))
    test("a material larger than its chunk is refused", not ok3 and tostring(err3):find("past its chunk's end", 1, true) ~= nil,
        tostring(err3))
    test("both say where, as the reader's other refusals do", tostring(err3):find("MDX: a record in the materials", 1, true) ~= nil,
        tostring(err3))
end
-- }}}

-- {{{ 16-bit and 8-bit reads at the file's end
test_section("16-bit and 8-bit reads at the file's end")

do
    local function geoset_until(rest)
        local body = "VRTX" .. u32(1) .. fl({ 0, 0, 0 }) .. "NRMS" .. u32(1) .. fl({ 0, 0, 1 }) ..
                     "PTYP" .. u32(1) .. u32(4) .. "PCNT" .. u32(1) .. u32(3) .. rest
        return model(chunk("GEOS", sized(body)))
    end
    -- three corners promised, one there: the second runs past the end
    local ok, err = parse_within(geoset_until("PVTX" .. u32(3) .. u16(0)))
    test("a corner list (16-bit) cut by the file's end is refused",
        not ok and tostring(err):find("MDX: read past the end", 1, true) ~= nil, tostring(err))
    -- one point's group promised as three, one byte there
    local ok2, err2 = parse_within(geoset_until("PVTX" .. u32(3) .. u16(0) .. u16(0) .. u16(0) .. "GNDX" .. u32(3) .. "\0"))
    test("a group list (8-bit) cut by the file's end is refused",
        not ok2 and tostring(err2):find("MDX: read past the end", 1, true) ~= nil, tostring(err2))
    -- one byte short of a 16-bit value: half of it is there
    local ok3, err3 = parse_within(geoset_until("PVTX" .. u32(1) .. "\0"))
    test("half a 16-bit value at the end is refused",
        not ok3 and tostring(err3):find("MDX: read past the end", 1, true) ~= nil, tostring(err3))
end
-- }}}

-- {{{ A corner past its geoset's points, onto the GPU
test_section("A corner past its geoset's points")

do
    local got = {}
    local fake = {
        tex_create = function() return 1 end,
        mesh_create = function(verts, idx) got[#got + 1] = idx; return #got end,
        model_create = function() return 1 end,
    }
    -- three points; the second triangle names a tenth (corner 9)
    local bytes = model(chunk("GEOS", sized(geoset_body({ 0, 0, 0, 1, 0, 0, 0, 1, 0 }, { 0, 1, 2, 2, 1, 9 }))))
    local m = mdx.parse(bytes)
    test("the reader keeps the corner as the file has it", m.geosets[1].faces[6] == 9)
    local cache = gpu.new(fake, { texture = function() return nil end })
    local id = cache:build(m, "corner.mdx")
    local idx = got[1] and ffi.cast("const uint16_t *", got[1])
    local list = {}
    if idx then for k = 0, #got[1] / 2 - 1 do list[#list + 1] = idx[k] end end
    test("the mesh is built, both triangles", id ~= nil and #list == 6, #list .. " corners")
    test("the corner past the points is the geoset's first point (as the C twin)",
        list[6] == 0, table.concat(list, " "))
    test("the corners within the points are kept", list[1] == 0 and list[2] == 1 and list[3] == 2
        and list[4] == 2 and list[5] == 1)
    local worst = 0
    for _, c in ipairs(list) do worst = math.max(worst, c) end
    test("no corner the card gets is past the mesh", worst < #m.geosets[1].vertices / 3, "largest " .. worst)
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
