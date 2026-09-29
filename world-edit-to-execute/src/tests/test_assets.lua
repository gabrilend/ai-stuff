--[[
Tests for the art decoders, the asset source, glTF and the ComfyUI
workflow files (Issue 522). Image decoders are checked against another
decoder's output (ImageMagick's, stored in fixtures/images); BLP, TGA and
MDX against every such file the test maps carry.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local jpeg = require("parsers.jpeg")
local png = require("parsers.png")
local blp = require("parsers.blp")
local tga = require("parsers.tga")
local mdx = require("parsers.mdx")
local gltf = require("parsers.gltf")
local assets = require("assets")
local mpq = require("mpq")
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

local function b64(s)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local map, out, acc, nbits = {}, {}, 0, 0
    for i = 1, 64 do map[chars:byte(i)] = i - 1 end
    for i = 1, #s do
        local v = map[s:byte(i)]
        if v then
            acc, nbits = acc * 64 + v, nbits + 6
            if nbits >= 8 then
                nbits = nbits - 8
                out[#out + 1] = string.char(math.floor(acc / 2 ^ nbits))
                acc = acc % 2 ^ nbits
            end
        end
    end
    return table.concat(out)
end

-- largest difference between a decoded buffer and the reference bytes
local function max_diff(get, ref, n)
    local worst = 0
    for i = 0, n - 1 do
        local d = math.abs(get(i) - ref:byte(i + 1))
        if d > worst then worst = d end
    end
    return worst
end
-- }}}

local FIX = dofile(DIR .. "/src/tests/fixtures/images/fixtures.lua")

-- {{{ JPEG
test_section("JPEG")

for _, name in ipairs({ "base.jpg", "prog.jpg", "sub.jpg" }) do
    local f = FIX[name]
    local ok, img = pcall(jpeg.decode, b64(f.file))
    local ref = b64(f.pixels)
    local tol = name == "sub.jpg" and 40 or 4   -- subsampled colour: libjpeg smooths it, we repeat it
    local worst = ok and max_diff(function(i) return img.pixels[i] end, ref, #ref) or -1
    test(name .. ": decodes to ImageMagick's pixels (within " .. tol .. ")",
        ok and img.width == 16 and img.components == 3 and worst <= tol, ok and ("max " .. worst) or tostring(img))
end
test("a lossless JPEG is refused by name", not pcall(jpeg.decode, "\255\216\255\195\0\2"))
-- }}}

-- {{{ PNG
test_section("PNG")

-- both fixtures are 16-bit PNGs: squeezing 16 bits into 8, decoders round
-- differently (ImageMagick 6 truncates colour, rounds alpha), so one level
for _, name in ipairs({ "pal.png", "rgba.png" }) do
    local f = FIX[name]
    local ok, img = pcall(png.decode, b64(f.file))
    local ref = b64(f.pixels)
    local worst = ok and max_diff(function(i) return img.rgba:byte(i + 1) end, ref, #ref) or -1
    test(name .. " (16-bit): ImageMagick's pixels within one level", ok and worst <= 1, ok and ("max " .. worst) or tostring(img))
end
do
    local writer = dofile(DIR .. "/../kanji-learning-image-generator/src/017-write-a-picture.lua")
    local raw = {}
    for i = 0, 8 * 8 - 1 do raw[#raw + 1] = string.char(i * 3 % 256, i * 7 % 256, i * 11 % 256, 255 - i) end
    raw = table.concat(raw)
    local back = png.decode(writer.encode(raw, 8, 8, 4))
    test("the monorepo's PNG writer and this reader agree", back.rgba == raw)
end
-- }}}

-- {{{ BLP and TGA, every one in two maps
test_section("BLP and TGA")

local blp_ok, blp_bad, tga_ok, jpeg_blp, pal_blp, progressive = 0, 0, 0, 0, 0, 0
local mdx_list = {}
for _, map in ipairs({ "DAoW-5.4b-PUBLIC-TEST.w3x", "DaoW-(HvA)-7.5.w3x" }) do
    local a = mpq.open(DIR .. "/assets/" .. map)
    for _, n in ipairs(a:list()) do
        local ok, d = pcall(a.extract, a, n)
        if ok and d then
            if d:sub(1, 4) == "BLP1" then
                local s, img = pcall(blp.decode, d)
                if s and #img.rgba == img.width * img.height * 4 then
                    blp_ok = blp_ok + 1
                    if img.compression == "jpeg" then jpeg_blp = jpeg_blp + 1 else pal_blp = pal_blp + 1 end
                    -- the mipmap one level down is a quarter the size
                    local h = blp.header(d)
                    if h.sizes[1] and h.sizes[1] > 0 and h.width >= 2 then
                        local small = blp.decode(d, 1)
                        if small.width ~= math.floor(h.width / 2) then blp_bad = blp_bad + 1 end
                    end
                else
                    blp_bad = blp_bad + 1
                end
                if d:find("\255\194", 1, true) then progressive = progressive + 1 end
            elseif n:lower():match("%.tga$") then
                local s, img = pcall(tga.decode, d)
                if s and #img.rgba == img.width * img.height * 4 then tga_ok = tga_ok + 1 end
            elseif d:sub(1, 4) == "MDLX" then
                mdx_list[#mdx_list + 1] = d
            end
        end
    end
    a:close()
end
test("every BLP in two maps decodes, mipmaps too", blp_ok > 100 and blp_bad == 0, blp_ok .. " ok, " .. blp_bad .. " bad")
test("both kinds: JPEG and paletted", jpeg_blp > 0 and pal_blp > 0, jpeg_blp .. " JPEG, " .. pal_blp .. " paletted")
test("progressive-JPEG BLPs among them", progressive > 0, progressive .. "")
test("the map preview (TGA) decodes", tga_ok >= 1)
-- }}}

-- {{{ MDX
test_section("MDX")

local parsed, nodes_ok, total_geosets = 0, 0, 0
local tri_ok = true
for _, d in ipairs(mdx_list) do
    local ok, m = pcall(mdx.parse, d)
    if ok then
        parsed = parsed + 1
        total_geosets = total_geosets + #m.geosets
        -- every node (all kinds read) has a pivot: no id beyond the list
        -- (community models may repeat or skip ids, so not a count)
        local fits = true
        for id in pairs(mdx.nodes(m)) do if id >= #m.pivots then fits = false end end
        if fits then nodes_ok = nodes_ok + 1 end
        for _, g in ipairs(m.geosets) do
            for _, i in ipairs(g.faces) do if i >= #g.vertices / 3 then tri_ok = false end end
        end
    end
end
test("every model in two maps parses", parsed == #mdx_list and parsed > 50, parsed .. " of " .. #mdx_list)
test("every node has a pivot (all node kinds read)", nodes_ok == parsed, nodes_ok .. " of " .. parsed)
test("every triangle indexes its own geoset's vertices", tri_ok)
do
    local track = { interpolation = 1, keys = { { frame = 0, value = 0 }, { frame = 100, value = 10 } } }
    local rot = { interpolation = 1, keys = { { frame = 0, value = { 0, 0, 0, 1 } }, { frame = 100, value = { 0, 0, 1, 0 } } } }
    local q = mdx.sample(rot, 50, nil, nil, nil, true)
    test("tracks sample: linear, and rotations by slerp",
        mdx.sample(track, 25, 99) == 2.5 and math.abs(q[3] - math.sqrt(0.5)) < 1e-6 and mdx.sample(nil, 5, 7) == 7)
end
-- }}}

-- {{{ glTF
test_section("glTF")

do
    local m = mdx.parse(mdx_list[1])
    local g = m.geosets[1]
    local mesh = { positions = g.vertices, normals = g.normals, uvs = g.uvs[1], indices = {} }
    for _, i in ipairs(g.faces) do mesh.indices[#mesh.indices + 1] = i end
    local writer = dofile(DIR .. "/../kanji-learning-image-generator/src/017-write-a-picture.lua")
    mesh.png = writer.encode(string.rep("\200\100\50\255", 16), 4, 4, 4)
    local glb = gltf.encode({ mesh })
    local back = gltf.decode(glb)
    local worst = 0
    for i = 1, #g.vertices do worst = math.max(worst, math.abs(back.meshes[1].positions[i] - g.vertices[i])) end
    test("a model through GLB and back: same vertices", #back.meshes == 1 and worst < 1e-3, "max " .. worst)
    test("same triangles, and its texture", #back.meshes[1].indices == #mesh.indices
        and back.meshes[1].image and back.meshes[1].image.width == 4)
    local fitted = gltf.decode(glb, { height = 200 })
    test("fitting to a height", math.abs(fitted.max[3] - 200) < 1e-3 and fitted.min[3] == 0)
end
-- }}}

-- {{{ The asset source
test_section("The asset source")

do
    local Map = require("data")
    local path = DIR .. "/assets/DAoW-5.4b-PUBLIC-TEST.w3x"
    local map = Map.load(path)
    local A = assets.open(path, { root = DIR, install = "/nonexistent" })
    test("without an install, the map alone", A.chain == nil and A.map ~= nil)
    local m, mpath = A:model_for("unit", "o01F", nil, map.object_data)
    test("a custom unit's imported model is found by its object data", m ~= nil and mpath:find("OrcHero") ~= nil, mpath)
    local tex = A:texture("war3mapMap.blp")
    test("a texture by path", tex and tex.width == 256)
    local none = A:texture("Textures\\NoSuchThing.blp")
    test("a missing one is nil and counted", none == nil and #A.missing >= 1)
    test("model paths: .mdl becomes .mdx", assets.model_path("units/human/Footman/Footman.mdl") == "units\\human\\Footman\\Footman.mdx")
    A:close()
end
-- }}}

-- {{{ ComfyUI workflows
test_section("ComfyUI workflows")

do
    local comfy = dofile(DIR .. "/src/assets/comfy.lua")
    local tmp = os.tmpname()
    os.remove(tmp)
    local written = comfy.write(tmp)
    test("every workflow, both shapes", #written == 12, #written .. " files")
    package.path = DIR .. "/../libs/lua/?.lua;" .. package.path
    local json = require("dkjson")
    local api = json.decode(io.open(tmp .. "/texture-restyle-lines.api.json"):read("*a"))
    local ui = json.decode(io.open(tmp .. "/texture-restyle-lines.ui.json"):read("*a"))
    local kinds = {}
    for _, n in pairs(api) do kinds[n.class_type] = true end
    test("the API shape: nodes by id, wired by [id, slot]", kinds.Canny and kinds.ControlNetApplyAdvanced
        and type(api["1"].inputs) == "table")
    test("the editor's shape: nodes and links", #ui.nodes == 11 and #ui.links > 10)
    -- a ComfyUI that knows every node and input these use
    local info = {}
    for f in io.popen('ls "' .. tmp .. '"/*.api.json'):lines() do
        for _, n in pairs(json.decode(io.open(f):read("*a"))) do
            local d = info[n.class_type] or { input = { required = {} } }
            for k in pairs(n.inputs) do d.input.required[k] = { "X" } end
            info[n.class_type] = d
        end
    end
    local good = tmp .. "/object_info.json"
    local function save_info()
        local f = io.open(good, "w")
        f:write(json.encode(info))
        f:close()
    end
    save_info()
    test("check passes against a ComfyUI that has them", #comfy.check(good, tmp) == 0)
    info.Canny = nil
    save_info()
    test("and names a node that's missing", #comfy.check(good, tmp) == 1)
    os.execute('rm -rf "' .. tmp .. '"')
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
