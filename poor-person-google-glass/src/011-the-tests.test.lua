-- 011-the-tests.test.lua - checks every piece of phase 0 that runs without a
-- window: the shape record, the three formats, the file door, the camera,
-- the settings.
--
-- In plain terms: makes shapes by formula, writes them out in every format,
-- reads them back, and checks nothing was lost or bent on the way; then
-- checks the camera always frames the whole shape, and that broken files
-- and settings are refused with a message naming where they broke.
--
-- Run with LuaJIT (scripts/run-tests does this):
--   luajit src/011-the-tests.test.lua <project-dir>
-- Exit status 0 when every test passes, 1 otherwise.

local project_dir = arg[1]
if project_dir == nil then error("usage: luajit 011-the-tests.test.lua <project-dir>", 0) end
package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path

local record = require("001-the-shape-record")
local shapes = require("002-the-test-shapes")
local stl = require("003-stl")
local obj = require("004-obj")
local gltf = require("005-gltf")
local any_file = require("006-read-any-cad-file")
local settings_reader = require("007-read-the-input")
local camera_math = require("009-the-orbit-camera")

local SCRATCH = project_dir .. "/tmp/shared-memory/tests"
os.execute("mkdir -p '" .. SCRATCH .. "'")

local tests = {}
local function test(name, body) tests[#tests + 1] = { name = name, body = body } end

-- {{{ helpers
-- {{{ local function expect()
local function expect(condition, message)
    if not condition then error(message, 2) end
end
-- }}}

-- {{{ local function expect_error()
-- Runs body; it must raise, and the message must contain `fragment`.
local function expect_error(fragment, body)
    local ok, problem = pcall(body)
    if ok then error("expected an error mentioning '" .. fragment .. "', got none", 2) end
    if not tostring(problem):find(fragment, 1, true) then
        error("expected an error mentioning '" .. fragment .. "', got: " .. tostring(problem), 2)
    end
end
-- }}}

-- {{{ local function no_files()
-- A read_neighbour for readers given no companion files.
local function no_files(name) error("no file " .. name, 0) end
-- }}}

-- {{{ local function same_corners()
-- Two parts hold the same corners to within float32 rounding.
local function same_corners(a, b, label)
    expect(#a.positions == #b.positions, label .. ": " .. #a.positions .. " vs " .. #b.positions .. " position numbers")
    for k = 1, #a.positions do
        local difference = math.abs(a.positions[k] - b.positions[k])
        expect(difference <= 1e-4 * math.max(1, math.abs(a.positions[k])),
            label .. ": position number " .. k .. " moved by " .. difference)
    end
end
-- }}}

-- {{{ local function stood_upright()
-- A part read from a z-up file, with its corners turned the way the viewer
-- turns them (009's upright), so they can be compared with the y-up original.
local function stood_upright(part)
    local m = camera_math.upright("z")
    local turned = { name = part.name, positions = {} }
    for k = 1, #part.positions, 3 do
        local x, y, z = camera_math.transform(m, { part.positions[k], part.positions[k + 1], part.positions[k + 2] })
        turned.positions[k], turned.positions[k + 1], turned.positions[k + 2] = x, y, z
    end
    return turned
end
-- }}}

-- {{{ local function write_file()
local function write_file(path, bytes)
    local file = assert(io.open(path, "wb"))
    file:write(bytes)
    file:close()
end
-- }}}
-- }}}

-- {{{ the shape record and the test shapes
test("a cube is 12 triangles inside the unit box", function()
    local cube = shapes.cube()
    expect(cube.triangle_count == 12, "triangles: " .. cube.triangle_count)
    for axis = 1, 3 do
        expect(cube.bounds.min[axis] == 0 and cube.bounds.max[axis] == 1, "bounds on axis " .. axis)
    end
end)

test("every cube face points outward", function()
    local part = shapes.cube().parts[1]
    local p, n = part.positions, part.normals
    for base = 0, #p - 9, 9 do
        local cx = (p[base + 1] + p[base + 4] + p[base + 7]) / 3 - 0.5
        local cy = (p[base + 2] + p[base + 5] + p[base + 8]) / 3 - 0.5
        local cz = (p[base + 3] + p[base + 6] + p[base + 9]) / 3 - 0.5
        expect(cx * n[base + 1] + cy * n[base + 2] + cz * n[base + 3] > 0, "triangle " .. (base / 9 + 1) .. " faces inward")
    end
end)

test("the crown sketch has its six parts and no slivers", function()
    local crown = shapes.crown()
    expect(#crown.parts == 6, "parts: " .. #crown.parts)
    expect(crown.degenerate_count == 0, "degenerate triangles: " .. crown.degenerate_count)
end)

test("a sliver triangle is counted, not removed", function()
    local shape = record.new("sliver", "made", "y")
    local part = record.add_part(shape, "sliver")
    record.add_triangle(part, 0, 0, 0, 1, 0, 0, 2, 0, 0)
    record.add_triangle(part, 0, 0, 0, 1, 0, 0, 0, 1, 0)
    record.finish(shape)
    expect(shape.degenerate_count == 1 and shape.triangle_count == 2, "counted wrong")
end)

test("a shape with no triangles is refused", function()
    local shape = record.new("empty", "made", "y")
    record.add_part(shape, "nothing")
    expect_error("has no triangles", function() record.finish(shape) end)
end)
-- }}}

-- {{{ STL
test("STL text: the crown survives a round trip, part by part", function()
    local crown = shapes.crown()
    local back = stl.read(stl.write_text(crown, "the tests"), "crown.stl")
    expect(#back.parts == #crown.parts, "parts: " .. #back.parts)
    expect(back.up_axis == "z", "STL reads as z up")
    for k, part in ipairs(crown.parts) do same_corners(part, stood_upright(back.parts[k]), "part " .. part.name) end
end)

test("STL: a y-up shape written out stands the same height read back", function()
    local crown = shapes.crown()
    local back = stl.read(stl.write_binary(crown, "the tests"), "crown.stl")
    local height_made, height_read = record.size(crown)[2], record.size(back)[3]
    expect(math.abs(height_made - height_read) < 1e-3, "height " .. height_made .. " came back as " .. height_read)
end)

test("STL binary: the crown survives a round trip as one part", function()
    local crown = shapes.crown()
    local bytes = stl.write_binary(crown, "the tests")
    expect(stl.is_binary(bytes), "own binary output not recognised")
    local back = stl.read(bytes, "crown.stl")
    expect(back.triangle_count == crown.triangle_count, "triangles: " .. back.triangle_count)
end)

test("STL binary whose header starts with 'solid' still reads as binary", function()
    local bytes = stl.write_binary(shapes.cube(), "")
    bytes = "solid fooled you" .. bytes:sub(17)
    local back = stl.read(bytes, "cube.stl")
    expect(back.triangle_count == 12, "triangles: " .. back.triangle_count)
end)

test("STL text with a facet of two corners names its line", function()
    local broken = "solid x\nfacet normal 0 0 1\nouter loop\nvertex 0 0 0\nvertex 1 0 0\nendloop\nendfacet\nendsolid x\n"
    expect_error("line 6", function() stl.read(broken, "broken.stl") end)
end)
-- }}}

-- {{{ OBJ
test("OBJ: a quad becomes two triangles; negative numbers count back", function()
    local text = "v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf -4 -3 -2 -1\n"
    local shape = obj.read(text, "quad.obj", no_files)
    expect(shape.triangle_count == 2, "triangles: " .. shape.triangle_count)
end)

test("OBJ: parts by 'o', colours from the material library", function()
    local text = "mtllib colours.mtl\nv 0 0 0\nv 1 0 0\nv 0 1 0\no first\nusemtl red\nf 1 2 3\no second\nf 1 3 2\n"
    local shape = obj.read(text, "two.obj", function(name)
        expect(name == "colours.mtl", "asked for " .. name)
        return "newmtl red\nKd 1 0 0\n"
    end)
    expect(#shape.parts == 2, "parts: " .. #shape.parts)
    expect(shape.parts[1].colour[1] == 1 and shape.parts[1].colour[2] == 0, "first part is not red")
    expect(shape.parts[2].name == "second (red)", "second part name: " .. shape.parts[2].name)
end)

test("OBJ: a face naming a missing corner names its line", function()
    expect_error("line 4", function() obj.read("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 9\n", "bad.obj", no_files) end)
end)

test("OBJ: a material no library defines is refused", function()
    expect_error("not in any loaded library", function()
        obj.read("v 0 0 0\nv 1 0 0\nv 0 1 0\nusemtl ghost\nf 1 2 3\n", "ghost.obj", no_files)
    end)
end)

test("OBJ: the crown survives a round trip with names and colours", function()
    local crown = shapes.crown()
    local obj_text, mtl_text = obj.write(crown, "the tests", "crown.mtl")
    local back = obj.read(obj_text, "crown.obj", function() return mtl_text end)
    expect(#back.parts == #crown.parts, "parts: " .. #back.parts)
    for k, part in ipairs(crown.parts) do
        local other = back.parts[k]
        expect(other.name:find(part.name, 1, true) == 1, "name " .. other.name)
        for c = 1, 3 do expect(math.abs(other.colour[c] - part.colour[c]) < 1e-3, part.name .. " colour changed") end
        same_corners(part, other, "part " .. part.name)
    end
end)
-- }}}

-- {{{ glTF
test("base64 round trip, every byte value", function()
    local bytes = {}
    for k = 0, 255 do bytes[#bytes + 1] = string.char(k) end
    bytes = table.concat(bytes)
    for cut = 0, 2 do
        local piece = bytes:sub(1, 256 - cut)
        expect(gltf.base64_decode(gltf.base64_encode(piece)) == piece, "length " .. #piece .. " changed")
    end
end)

test("glTF: the crown survives a round trip with names and colours", function()
    local crown = shapes.crown()
    local back = gltf.read(gltf.write(crown, "the tests", "millimetres"), "crown.gltf", no_files)
    expect(#back.parts == #crown.parts, "parts: " .. #back.parts)
    expect(back.units == "millimetres", "units: " .. tostring(back.units))
    for k, part in ipairs(crown.parts) do
        local other = back.parts[k]
        expect(other.name == part.name, "name " .. other.name)
        for c = 1, 3 do expect(math.abs(other.colour[c] - part.colour[c]) < 1e-6, part.name .. " colour changed") end
        same_corners(part, other, "part " .. part.name)
    end
end)

-- {{{ local function handmade_gltf()
-- A one-triangle glTF built by hand: 16-bit indices, a node placement.
local function handmade_gltf(node_fields, count_override)
    local ffi = require("ffi")
    local block = ffi.new("uint8_t[44]")
    local floats = ffi.cast("float *", block)
    local corners = { 0, 0, 0, 1, 0, 0, 0, 1, 0 }
    for k = 1, 9 do floats[k - 1] = corners[k] end
    local shorts = ffi.cast("uint16_t *", block + 36)
    shorts[0], shorts[1], shorts[2] = 0, 1, 2
    local data = gltf.base64_encode(ffi.string(block, 44))
    local node = { mesh = 0 }
    for key, value in pairs(node_fields) do node[key] = value end
    local json = require("dkjson")
    return json.encode({
        asset = { version = "2.0" }, scene = 0, scenes = { { nodes = { 0 } } }, nodes = { node },
        meshes = { { primitives = { { attributes = { POSITION = 0 }, indices = 1 } } } },
        accessors = {
            { bufferView = 0, componentType = 5126, count = count_override or 3, type = "VEC3" },
            { bufferView = 1, componentType = 5123, count = 3, type = "SCALAR" },
        },
        bufferViews = { { buffer = 0, byteOffset = 0, byteLength = 36 }, { buffer = 0, byteOffset = 36, byteLength = 6 } },
        buffers = { { byteLength = 44, uri = "data:application/octet-stream;base64," .. data } },
    })
end
-- }}}

test("glTF: 16-bit indices and a node's move are followed", function()
    local shape = gltf.read(handmade_gltf({ translation = { 10, 20, 30 } }), "moved.gltf", no_files)
    expect(shape.triangle_count == 1, "triangles: " .. shape.triangle_count)
    expect(shape.bounds.min[1] == 10 and shape.bounds.min[2] == 20 and shape.bounds.min[3] == 30, "not moved")
    expect(shape.parts[1].colour[1] == 1, "a primitive with no material should be white")
end)

test("glTF: a mirroring scale keeps the triangle facing out", function()
    local plain = gltf.read(handmade_gltf({}), "plain.gltf", no_files)
    local mirrored = gltf.read(handmade_gltf({ scale = { 1, 1, -1 } }), "mirrored.gltf", no_files)
    expect(plain.parts[1].normals[3] > 0, "plain triangle should face +z")
    expect(mirrored.parts[1].normals[3] < 0, "mirrored triangle should face -z")
end)

test("glTF: an accessor running past its buffer is refused", function()
    expect_error("runs past the end", function() gltf.read(handmade_gltf({}, 4), "long.gltf", no_files) end)
end)
-- }}}

-- {{{ the file door
test("every format through the file door, from disk", function()
    local crown = shapes.crown()
    write_file(SCRATCH .. "/crown.stl", stl.write_binary(crown, "the tests"))
    write_file(SCRATCH .. "/crown-text.stl", stl.write_text(crown, "the tests"))
    local obj_text, mtl_text = obj.write(crown, "the tests", "crown.mtl")
    write_file(SCRATCH .. "/crown.obj", obj_text)
    write_file(SCRATCH .. "/crown.mtl", mtl_text)
    write_file(SCRATCH .. "/crown.gltf", gltf.write(crown, "the tests", "millimetres"))
    for _, name in ipairs({ "crown.stl", "crown-text.stl", "crown.obj", "crown.gltf" }) do
        local shape = any_file.read(SCRATCH .. "/" .. name)
        expect(shape.triangle_count == crown.triangle_count, name .. ": " .. shape.triangle_count .. " triangles")
    end
end)

test("an ending with no reader is refused, naming the readable ones", function()
    expect_error("readable: .glb, .gltf, .obj, .stl", function() any_file.read(SCRATCH .. "/crown.step") end)
end)
-- }}}

-- {{{ the camera
test("fitting the camera keeps every corner of the box on screen", function()
    local corners = {}
    for i = 0, 1 do for j = 0, 1 do for k = 0, 1 do
        corners[#corners + 1] = { i * 300 - 50, j * 80 - 70, k * 200 - 100 }
    end end end
    for _, aspect in ipairs({ 1.6, 1.0, 0.6 }) do
        for _, yaw in ipairs({ 0, 1, 2.5, -2 }) do
            for _, pitch in ipairs({ -1.4, 0, 0.5, 1.4 }) do
                local camera = camera_math.new(40)
                camera.yaw, camera.pitch = yaw, pitch
                local radius = math.sqrt(300 ^ 2 + 80 ^ 2 + 200 ^ 2) / 2
                camera_math.fit(camera, { 100, -30, 0 }, radius, aspect)
                local m = camera_math.multiply(camera_math.projection(camera, aspect), camera_math.view(camera))
                for _, corner in ipairs(corners) do
                    local x, y, z, w = camera_math.transform(m, corner)
                    expect(w > 0, "a corner is behind the camera")
                    for _, value in ipairs({ x / w, y / w, z / w }) do
                        expect(math.abs(value) <= 1, string.format("aspect %.1f yaw %.1f pitch %.1f: corner off screen (%.3f)", aspect, yaw, pitch, value))
                    end
                end
            end
        end
    end
end)

test("standing at a station puts its look point at the picture's centre", function()
    local camera = camera_math.new(40)
    camera.radius = 100
    camera_math.stand_at(camera, { 30, 12, -5 }, { 80, 0, 20 })
    local x, y = camera_math.to_screen(camera, { 80, 0, 20 }, 800, 600)
    expect(math.abs(x - 400) < 1e-6 and math.abs(y - 300) < 1e-6, string.format("look point at %.3f, %.3f", x, y))
    local eye = camera_math.eye(camera)
    expect(math.abs(eye[1] - 30) < 1e-9 and math.abs(eye[2] - 12) < 1e-9 and math.abs(eye[3] + 5) < 1e-9, "the camera is not at the eye")
end)

test("glTF carries a model's stations and filling", function()
    local cube = shapes.cube()
    cube.stations = { { name = "corner", eye = { 0.1, 0.2, 0.3 }, look = { 0.5, 0.5, 0.5 } } }
    cube.filling = { colour = { 0.5, 0.7, 0.8 }, density = 0.02 }
    local back = gltf.read(gltf.write(cube, "the tests", "units"), "cube.gltf", no_files)
    expect(back.stations[1].name == "corner" and back.stations[1].look[3] == 0.5, "station lost")
    expect(back.filling.density == 0.02, "filling lost")
    cube.stations = { { name = "broken", eye = { 1, 2 } } }
    expect_error("station 1 needs", function() gltf.read(gltf.write(cube, "the tests", "units"), "cube.gltf", no_files) end)
end)

test("the light pipe model is whole, with a station for every stretch", function()
    local pipe = require("018-the-light-pipe-model").build()
    expect(#pipe.parts == 14, "parts: " .. #pipe.parts)
    expect(pipe.degenerate_count == 0, "slivers: " .. pipe.degenerate_count)
    expect(#pipe.stations >= 10, "stations: " .. #pipe.stations)
end)

test("sliding the pillar moves it level, sideways and away, whatever the tilt", function()
    local camera = camera_math.new(40)
    camera.yaw, camera.pitch = 0.7, 1.2
    camera_math.slide_pillar(camera, 5, 0)
    expect(camera.target[2] == 0, "the pillar rose or sank")
    -- moved toward the screen's right: the old pillar (the origin) now lies
    -- left of the picture's centre, at the same height on screen
    local x, y = camera_math.to_screen(camera, { 0, 0, 0 }, 800, 600)
    expect(x < 400 and math.abs(y - 300) < 1e-6, string.format("old pillar at %.3f, %.3f", x, y))
    camera_math.slide_pillar(camera, 0, 3)
    local eye = camera_math.eye(camera)
    expect(math.abs(camera.target[2]) < 1e-12 and eye[2] > 0, "sliding away changed the height")
end)

test("standing a z-up shape upright sends its z to the world's y", function()
    local x, y, z = camera_math.transform(camera_math.upright("z"), { 0, 0, 5 })
    expect(x == 0 and y == 5 and z == 0, string.format("got %g %g %g", x, y, z))
end)
-- }}}

-- {{{ the settings
test("the project's own settings pass their check", function()
    settings_reader.read(project_dir)
end)

test("a missing setting is named", function()
    expect_error("missing setting 'edge_colour'", function()
        settings_reader.check_settings({ window_width = 800, window_height = 600, field_of_view_degrees = 40,
            turn_degrees_per_second = 10, window_resizable = false, edge_margin_pixels = 40, edge_speed = 1,
            background_colour = { 0, 0, 0 } }, "made-up")
    end)
end)
-- }}}

-- {{{ run them
local failed = 0
for _, entry in ipairs(tests) do
    local ok, problem = pcall(entry.body)
    if ok then
        print("pass  " .. entry.name)
    else
        failed = failed + 1
        print("FAIL  " .. entry.name .. "\n      " .. tostring(problem))
    end
end
print(string.format("%d of %d passed", #tests - failed, #tests))
os.exit(failed == 0 and 0 or 1)
-- }}}
