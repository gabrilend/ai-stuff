--[[
Tests for the MDX model reader (Issue 116).

In plain terms: builds a small model byte by byte (so no downloaded or
proprietary file is needed), reads it back and checks every chunk the
renderer uses; then cuts it short, corrupts it and gives it the wrong
version, and checks each fails with an error that names what and where,
never with a Lua error from inside the reader. When the owner's WC3
install is present, every stock unit model is read as well; without it
that part is skipped and says so.

Usage: luajit src/tests/test_mdx.lua [DIR]
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mdx = require("parsers.mdx")
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

local function near(a, b) return math.abs(a - b) < 1e-5 end
-- }}}

-- {{{ Building a model
-- A fixed-width, zero-padded string, as the format stores names and paths
local function fixed(s, len) return s .. string.rep("\0", len - #s) end

local function u32(v) return bw.new():u32(v):done() end

local function chunk(tag, body) return tag .. u32(#body) .. body end

-- A record whose size field counts itself
local function record(body) return u32(#body + 4) .. body end

local function extent(b, r)
    b:f32(r) b:f32(-r) b:f32(-r) b:f32(0) b:f32(r) b:f32(r) b:f32(r * 2)
end

-- {{{ build_model
-- version: written into VERS (800 unless given)
local function build_model(version)
    local parts = { "MDLX" }
    local function add(tag, b) parts[#parts + 1] = chunk(tag, type(b) == "string" and b or b:done()) end

    add("VERS", u32(version or 800))

    local b = bw.new()
    b:str(fixed("TestFootman", 80)) b:str(fixed("", 260))
    extent(b, 50)
    b:u32(150)
    add("MODL", b)

    b = bw.new()
    for _, s in ipairs({ { "Stand", 0, 1000, 0, 0 }, { "Walk", 1100, 1900, 270, 1 } }) do
        b:str(fixed(s[1], 80)) b:u32(s[2]) b:u32(s[3]) b:f32(s[4]) b:u32(s[5]) b:f32(0) b:u32(0)
        extent(b, 40)
    end
    add("SEQS", b)

    add("GLBS", bw.new():u32(2000))

    b = bw.new()
    b:u32(0) b:str(fixed("Textures\\Test.blp", 260)) b:u32(3)
    b:u32(1) b:str(fixed("", 260)) b:u32(0)
    add("TEXS", b)

    -- one material, one layer: blend, texture 0, alpha animated
    local track = bw.new():str("KMTA"):u32(2):u32(1):i32(-1)
        :i32(0):f32(1.0):i32(1000):f32(0.25):done()
    local layer = bw.new():u32(2):u32(16):u32(0):i32(-1):u32(0):f32(1.0):done() .. track
    local material = bw.new():i32(0):u32(0):str("LAYS"):u32(1):done() .. record(layer)
    add("MTLS", record(material))

    -- one geoset: a triangle
    b = bw.new()
    b:str("VRTX"):u32(3)
    for _, v in ipairs({ 0, 0, 0, 10, 0, 0, 0, 10, 5 }) do b:f32(v) end
    b:str("NRMS"):u32(3)
    for _ = 1, 3 do b:f32(0) b:f32(0) b:f32(1) end
    b:str("PTYP"):u32(1):u32(4)
    b:str("PCNT"):u32(1):u32(3)
    b:str("PVTX"):u32(3):u16(0):u16(1):u16(2)
    b:str("GNDX"):u32(3):u8(0):u8(0):u8(0)
    b:str("MTGC"):u32(1):u32(1)
    b:str("MATS"):u32(1):u32(0)
    b:u32(0) b:u32(0) b:u32(0)          -- material, selection group, selection flags
    extent(b, 10)
    b:u32(1) extent(b, 10)               -- one sequence extent
    b:str("UVAS"):u32(1)
    b:str("UVBS"):u32(3)
    for _, v in ipairs({ 0, 0, 1, 0, 0, 1 }) do b:f32(v) end
    add("GEOS", record(b:done()))

    -- a bone with a hermite translation track, and a helper as its parent
    local kgtr = bw.new():str("KGTR"):u32(2):u32(2):i32(-1)
    for _, k in ipairs({ { 0, 0 }, { 1000, 30 } }) do
        kgtr:i32(k[1])
        kgtr:f32(0) kgtr:f32(0) kgtr:f32(k[2])          -- value: up by k[2]
        kgtr:f32(0) kgtr:f32(0) kgtr:f32(k[2] / 2)      -- in and out tangents
        kgtr:f32(0) kgtr:f32(0) kgtr:f32(k[2] / 2)
    end
    local function node(name, id, parent, tracks)
        return record(bw.new():str(fixed(name, 80)):i32(id):i32(parent):u32(256):done() .. (tracks or ""))
    end
    add("BONE", node("Bone_Root", 0, 1, kgtr:done()) .. bw.new():i32(0):i32(-1):done())
    add("HELP", node("Mesh_Origin", 1, -1))

    b = bw.new()
    for _, v in ipairs({ 0, 0, 0, 0, 0, 40 }) do b:f32(v) end
    add("PIVT", b)

    add("ZZZZ", "kept as it is")
    return table.concat(parts)
end
-- }}}
-- }}}

-- {{{ Reading the model back
test_section("A version-800 model reads back")

local bytes = build_model()
local ok, m = pcall(mdx.parse, bytes)
test("the built model parses", ok, not ok and tostring(m) or nil)
if not ok then
    print("\nTests: " .. pass_count .. " passed, " .. (test_count - pass_count) .. " failed")
    os.exit(1)
end

test("version and name", m.version == 800 and m.name == "TestFootman")
test("bounds", near(m.extent.radius, 50) and near(m.extent.max[3], 100) and m.blend_time == 150)
test("sequences: names, frames, looping",
    #m.sequences == 2 and m.sequences[1].name == "Stand" and m.sequences[2].start == 1100
    and m.sequences[2].finish == 1900 and near(m.sequences[2].move_speed, 270)
    and m.sequences[1].non_looping == false and m.sequences[2].non_looping == true)
test("global sequences", m.global_sequences and m.global_sequences[1] == 2000)
test("textures: a path, and a replaceable id",
    m.textures[1].path == "Textures\\Test.blp" and m.textures[1].replaceable == 0
    and m.textures[1].wrap_width and m.textures[1].wrap_height
    and m.textures[2].path == "" and m.textures[2].replaceable == 1)
local layer = m.materials[1] and m.materials[1].layers[1]
test("a material layer: filter, shading, texture, alpha",
    layer and layer.filter == "blend" and layer.shading == 16 and layer.texture == 0 and near(layer.alpha, 1))
local kmta = layer and layer.tracks.KMTA
test("the layer's alpha track", kmta and kmta.interpolation == 1 and kmta.global == nil
    and #kmta.keys == 2 and kmta.keys[2].frame == 1000 and near(kmta.keys[2].value, 0.25))
local g = m.geosets[1]
test("geoset: vertices and normals", g and #g.vertices == 9 and near(g.vertices[9], 5) and #g.normals == 9)
test("geoset: one triangle", g and #g.faces == 3 and g.faces[3] == 2 and g.face_types[1] == 4)
test("geoset: vertex groups and bone groups",
    g and #g.vertex_groups == 3 and g.group_sizes[1] == 1 and g.group_indices[1] == 0)
test("geoset: texture coordinates", g and #g.uvs == 1 and #g.uvs[1] == 6 and near(g.uvs[1][6], 1))
test("geoset: extents", g and near(g.extent.radius, 10) and #g.sequence_extents == 1)
local bone = m.bones[1]
test("a bone: name, id, parent", bone and bone.name == "Bone_Root" and bone.id == 0 and bone.parent == 1
    and bone.geoset == 0 and bone.geoset_animation == -1)
local kgtr = bone and bone.tracks.KGTR
test("its hermite track keeps both tangents", kgtr and kgtr.interpolation == 2 and #kgtr.keys == 2
    and #kgtr.keys[2].value == 3 and near(kgtr.keys[2].value[3], 30) and near(kgtr.keys[2].inTan[3], 15) and near(kgtr.keys[2].outTan[3], 15))
test("a helper", m.helpers[1] and m.helpers[1].name == "Mesh_Origin" and m.helpers[1].parent == -1)
test("pivots, one per node", #m.pivots == 2 and near(m.pivots[2][3], 40))
test("nodes by id", mdx.nodes(m)[0] == bone and mdx.nodes(m)[1] == m.helpers[1])
test("an unknown chunk is kept, with where it was",
    #m.unread == 1 and m.unread[1].tag == "ZZZZ" and m.unread[1].bytes == "kept as it is"
    and bytes:sub(m.unread[1].offset + 1, m.unread[1].offset + 4) == "ZZZZ"
    and m.other.ZZZZ == "kept as it is")
test("chunks listed in file order", m.chunks[1] == "VERS" and m.chunks[#m.chunks] == "ZZZZ")
test("the sampler reads the alpha track halfway", near(mdx.sample(kmta, 500, 1), 0.625))
-- }}}

-- {{{ Summary
test_section("The summary for the fetcher and the catalogue")

local s = mdx.summary(m)
test("counts", s.version == 800 and s.geosets == 1 and s.vertices == 3 and s.triangles == 1 and s.nodes == 2)
test("sequence names", #s.sequences == 2 and s.sequences[1] == "Stand" and s.sequences[2] == "Walk")
test("texture paths and replaceable ids", #s.textures == 1 and s.textures[1] == "Textures\\Test.blp"
    and #s.replaceable_ids == 1 and s.replaceable_ids[1] == 1)
test("chunks left unread", #s.unread == 1 and s.unread[1] == "ZZZZ")
-- }}}

-- {{{ Errors that name what and where
test_section("Bad files fail with errors that name what and where")

-- An error from the reader itself, not a Lua error from deep inside it
local function reader_error(err)
    err = tostring(err)
    return err:match("^MDX: ") ~= nil and not err:find("attempt to", 1, true)
end

-- {{{ every truncation
do
    -- the offsets where a chunk ends: cutting there leaves a shorter, valid model
    local boundaries, pos = {}, 4
    while pos < #bytes do
        local size = bytes:byte(pos + 5) + bytes:byte(pos + 6) * 256 + bytes:byte(pos + 7) * 65536
        pos = pos + 8 + size
        boundaries[pos] = true
    end
    local good, bad, example = 0, 0, nil
    for cut = 5, #bytes - 1 do
        local cok, err = pcall(mdx.parse, bytes:sub(1, cut))
        if (cok and boundaries[cut]) or (not cok and reader_error(err) and err:match("at byte %d+")) then
            good = good + 1
        else
            bad = bad + 1
            example = example or (cut .. ": " .. tostring(err))
        end
        if cut == 600 then print("    e.g. cut at byte 600: " .. tostring(err)) end
    end
    test("cut at every byte: a shorter model, or an error naming the byte", bad == 0,
        bad .. " of " .. (good + bad) .. " wrong, first " .. tostring(example))
end
-- }}}

-- {{{ a count inside a chunk that runs past it
do
    local at = bytes:find("VRTX", 1, true)
    local broken = bytes:sub(1, at + 3) .. u32(1000) .. bytes:sub(at + 8)
    local cok, err = pcall(mdx.parse, broken)
    print("    " .. tostring(err))
    test("a vertex count too large names the chunk GEOS and a byte", not cok and reader_error(err)
        and err:find("chunk GEOS (starting at byte", 1, true) and err:find("truncated", 1, true))
end
-- }}}

-- {{{ a record size of zero, which would otherwise loop forever
do
    local at = bytes:find("MTLS", 1, true)
    local broken = bytes:sub(1, at + 7) .. u32(0) .. bytes:sub(at + 12)
    local cok, err = pcall(mdx.parse, broken)
    print("    " .. tostring(err))
    test("a material whose size is zero is refused, naming MTLS", not cok and reader_error(err)
        and err:find("chunk MTLS", 1, true) and err:find("claims 0 bytes", 1, true))
end
-- }}}

-- {{{ an unknown track
do
    local broken = bytes:gsub("KMTA", "KQQQ")
    local cok, err = pcall(mdx.parse, broken)
    test("an unknown track tag is named", not cok and reader_error(err) and err:find("KQQQ", 1, true))
end
-- }}}

-- {{{ stray bytes after the last chunk
do
    local cok, err = pcall(mdx.parse, bytes .. "abc")
    test("three stray bytes at the end are reported", not cok and reader_error(err)
        and err:find("3 stray bytes", 1, true))
end
-- }}}

-- {{{ every field overwritten
-- Each 4-byte window set to all ones, then all zeros: the reader either
-- reads a (wrong but well-formed) model or fails with its own error; it
-- never raises a Lua error, never reads past its buffer and never hangs.
do
    local bad, example, failures = 0, nil, 0
    for at = 5, #bytes - 3 do
        for _, fill in ipairs({ "\255\255\255\255", "\0\0\0\0" }) do
            local cok, err = pcall(mdx.parse, bytes:sub(1, at - 1) .. fill .. bytes:sub(at + 4))
            if not cok then
                failures = failures + 1
                if not reader_error(err) then
                    bad = bad + 1
                    example = example or (at .. ": " .. tostring(err))
                end
            end
        end
    end
    test("every 4-byte window corrupted: only the reader's own errors (" .. failures .. " of them)",
        bad == 0 and failures > 0, tostring(example))
end
-- }}}
-- }}}

-- {{{ Versions
test_section("Only classic models are read")

do
    local cok, err = pcall(mdx.parse, build_model(900))
    print("    " .. tostring(err))
    test("version 900 (Reforged HD) is refused, naming the version and why", not cok
        and err:find("version 900", 1, true) and err:find("versions-we-leave-alone", 1, true))
    cok, err = pcall(mdx.parse, build_model(1100))
    test("so is version 1100", not cok and err:find("version 1100", 1, true))
    cok, err = pcall(mdx.parse, build_model(700))
    test("and an older version than 800", not cok and err:find("version 700", 1, true))
    cok, err = pcall(mdx.parse, "RIFF" .. bytes:sub(5))
    test("a file that isn't a model", not cok and tostring(err):find("no MDLX", 1, true))
end
-- }}}

-- {{{ Stock models, when the owner's install is present
test_section("Stock unit models from the install")

do
    local assets = require("assets")
    local A = assets.open(DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x", { root = DIR })
    if not A.install then
        print("  SKIPPED: no WC3 install here ($WC3_INSTALL or wc3-installs/frozen-throne);"
            .. " every stock unit model is read where there is one")
    else
        local stock = A:table("Units\\UnitUI.slk")
        local read, failed, missing, seen, first = 0, 0, 0, {}, nil
        for _, row in pairs(stock and stock.rows or {}) do
            local path = assets.model_path(row.file and tostring(row.file))
            if path and not seen[path:lower()] then
                seen[path:lower()] = true
                local data = A:read(path)
                if not data then
                    missing = missing + 1
                else
                    local pok, err = pcall(mdx.parse, data)
                    if pok then read = read + 1 else
                        failed = failed + 1
                        first = first or (path .. ": " .. tostring(err))
                    end
                end
            end
        end
        print(string.format("    %d stock unit models read, %d failed, %d not in the install", read, failed, missing))
        test("every stock unit model reads", read > 0 and failed == 0, first)
    end
    A:close()
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
