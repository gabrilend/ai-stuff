-- 005-gltf.lua - reads and writes glTF 2.0, the house format for the
-- project's own models: structured JSON text with parts, colours and
-- placement.
--
-- In plain terms: a glTF file is a JSON description that points into blocks
-- of raw numbers. The JSON says "this mesh's corners are 36 groups of three
-- floats, starting 288 bytes into block 0"; the blocks are either written
-- into the JSON itself as base64 text (a "data:" address), or kept in a
-- ".bin" file beside it. This file follows those pointers into a shape
-- record (001), and writes a shape as a single self-contained .gltf.
--
-- The chain of pointers, outermost first:
--   scene     -> list of root nodes
--   node      -> optional mesh, optional children, optional placement
--                (a 4x4 "matrix", or translation [x,y,z] / rotation
--                quaternion [x,y,z,w] / scale [x,y,z]); placements multiply
--                down the tree, parent first
--   mesh      -> primitives; each primitive has attributes { POSITION,
--                NORMAL, ... } and optional indices, each an accessor number,
--                a mode (4 = triangles, the default), and a material number
--   accessor  -> bufferView, byteOffset, componentType (5120 int8, 5121
--                uint8, 5122 int16, 5123 uint16, 5125 uint32, 5126 float32),
--                count, type ("SCALAR", "VEC3", ...)
--   bufferView-> buffer, byteOffset, byteLength, byteStride (gap between
--                elements; absent means tightly packed)
--   buffer    -> uri ("data:...;base64,..." or a file name), byteLength
-- All numbers in buffers are little-endian. A material's colour is
-- pbrMetallicRoughness.baseColorFactor [r,g,b,a]; a primitive with no
-- material is white, as the glTF specification says.
-- The binary form (.glb) is the same JSON and one buffer in a single file:
-- 12-byte header "glTF", version 2, total length; then chunks of
-- { length uint32, type "JSON" or "BIN\0", bytes }.
-- glTF's convention is y up, metres (the crown sketch writes millimetres,
-- and says so in asset.extras.units).

local ffi = require("ffi")
local bit = require("bit")
local json = require("dkjson")
local record = require("001-the-shape-record")

local M = {}

local COMPONENT = {
    [5120] = { ctype = "const int8_t *", size = 1 },
    [5121] = { ctype = "const uint8_t *", size = 1 },
    [5122] = { ctype = "const int16_t *", size = 2 },
    [5123] = { ctype = "const uint16_t *", size = 2 },
    [5125] = { ctype = "const uint32_t *", size = 4 },
    [5126] = { ctype = "const float *", size = 4 },
}
local WIDTH = { SCALAR = 1, VEC2 = 2, VEC3 = 3, VEC4 = 4, MAT4 = 16 }

-- {{{ base64
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE = {}
for index = 1, 64 do DECODE[ALPHABET:byte(index)] = index - 1 end

-- {{{ function M.base64_decode()
-- Four letters carry three bytes. Written into one preallocated byte block
-- rather than joined from pieces, because buffers can be megabytes.
function M.base64_decode(text)
    text = text:gsub("[%s=]", "")
    local out = ffi.new("uint8_t[?]", math.floor(#text * 3 / 4) + 3)
    local written, accumulator, held = 0, 0, 0
    for index = 1, #text do
        local value = DECODE[text:byte(index)]
        if value == nil then error("base64: '" .. text:sub(index, index) .. "' is not a base64 letter", 0) end
        accumulator = bit.bor(bit.lshift(accumulator, 6), value)
        held = held + 6
        if held >= 8 then
            held = held - 8
            out[written] = bit.band(bit.rshift(accumulator, held), 255)
            written = written + 1
        end
    end
    return ffi.string(out, written)
end
-- }}}

-- {{{ function M.base64_encode()
function M.base64_encode(bytes)
    local out = {}
    for index = 1, #bytes, 3 do
        local a, b, c = bytes:byte(index, index + 2)
        local n = bit.bor(bit.lshift(a, 16), bit.lshift(b or 0, 8), c or 0)
        local piece = {}
        for k = 3, 0, -1 do
            local six = bit.band(bit.rshift(n, k * 6), 63) + 1
            piece[#piece + 1] = ALPHABET:sub(six, six)
        end
        -- a final group of one or two bytes is padded with "="
        if b == nil then piece[3], piece[4] = "=", "="
        elseif c == nil then piece[4] = "=" end
        out[#out + 1] = table.concat(piece)
    end
    return table.concat(out)
end
-- }}}
-- }}}

-- {{{ 4x4 placement arithmetic
-- Matrices are flat lists of 16 numbers in glTF's own order: column by
-- column (element [column*4 + row + 1]).

-- {{{ local function multiply()
local function multiply(a, b)
    local out = {}
    for column = 0, 3 do
        for row = 0, 3 do
            local sum = 0
            for k = 0, 3 do sum = sum + a[k * 4 + row + 1] * b[column * 4 + k + 1] end
            out[column * 4 + row + 1] = sum
        end
    end
    return out
end
-- }}}

-- {{{ local function node_placement()
-- A node's own placement: its matrix, or scale then rotate then move.
local function node_placement(node)
    if node.matrix then return node.matrix end
    local t = node.translation or { 0, 0, 0 }
    local q = node.rotation or { 0, 0, 0, 1 }
    local s = node.scale or { 1, 1, 1 }
    local x, y, z, w = q[1], q[2], q[3], q[4]
    -- the rotation a unit quaternion stands for, column by column
    return {
        (1 - 2 * (y * y + z * z)) * s[1], (2 * (x * y + z * w)) * s[1], (2 * (x * z - y * w)) * s[1], 0,
        (2 * (x * y - z * w)) * s[2], (1 - 2 * (x * x + z * z)) * s[2], (2 * (y * z + x * w)) * s[2], 0,
        (2 * (x * z + y * w)) * s[3], (2 * (y * z - x * w)) * s[3], (1 - 2 * (x * x + y * y)) * s[3], 0,
        t[1], t[2], t[3], 1,
    }
end
-- }}}

-- {{{ local function normal_matrix()
-- Directions turn by the inverse-transpose of the placement's 3x3 part, so
-- a squashed shape's normals stay at right angles to its surfaces. The
-- cofactor matrix is that inverse-transpose times the determinant; scaling
-- by the determinant's sign keeps directions pointing out. Returns the 3x3
-- (row by row) and the determinant (a mirror placement has a negative one).
local function normal_matrix(m)
    local a, b, c = m[1], m[5], m[9]
    local d, e, f = m[2], m[6], m[10]
    local g, h, i = m[3], m[7], m[11]
    local det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    local sign = det < 0 and -1 or 1
    return {
        sign * (e * i - f * h), sign * (f * g - d * i), sign * (d * h - e * g),
        sign * (c * h - b * i), sign * (a * i - c * g), sign * (b * g - a * h),
        sign * (b * f - c * e), sign * (c * d - a * f), sign * (a * e - b * d),
    }, det
end
-- }}}
-- }}}

-- {{{ local function read_accessor()
-- An accessor's numbers as a flat Lua list (count × width numbers).
local function read_accessor(document, buffers, index, fail)
    local accessor = document.accessors and document.accessors[index + 1]
    if accessor == nil then fail("accessor " .. index .. " does not exist") end
    if accessor.sparse then fail("accessor " .. index .. " is sparse, which this reader does not handle") end
    local component = COMPONENT[accessor.componentType]
    local width = WIDTH[accessor.type]
    if component == nil or width == nil then fail("accessor " .. index .. " has an unknown type") end
    local view = document.bufferViews and document.bufferViews[(accessor.bufferView or -1) + 1]
    if view == nil then fail("accessor " .. index .. " has no bufferView") end
    local bytes = buffers[view.buffer + 1]
    if bytes == nil then fail("bufferView points at missing buffer " .. tostring(view.buffer)) end
    local element_size = component.size * width
    local stride = view.byteStride or element_size
    local start = (view.byteOffset or 0) + (accessor.byteOffset or 0)
    local last_byte = start + stride * (accessor.count - 1) + element_size
    if last_byte > (view.byteOffset or 0) + view.byteLength or last_byte > #bytes then
        fail("accessor " .. index .. " runs past the end of its buffer")
    end
    local base = ffi.cast("const uint8_t *", bytes)
    local out = {}
    for element = 0, accessor.count - 1 do
        local values = ffi.cast(component.ctype, base + start + element * stride)
        for k = 0, width - 1 do out[#out + 1] = values[k] end
    end
    return out
end
-- }}}

-- {{{ local function load_buffers()
-- Every buffer's bytes, in order. `embedded` is the .glb's binary chunk,
-- which stands in for a buffer with no uri.
local function load_buffers(document, read_neighbour, embedded, fail)
    local buffers = {}
    for index, buffer in ipairs(document.buffers or {}) do
        local bytes
        if buffer.uri == nil then
            if embedded == nil then fail("buffer " .. (index - 1) .. " has no uri and the file has no binary chunk") end
            bytes = embedded
        elseif buffer.uri:match("^data:") then
            local payload = buffer.uri:match("^data:[^,]*;base64,(.*)$")
            if payload == nil then fail("buffer " .. (index - 1) .. " has a data address that is not base64") end
            bytes = M.base64_decode(payload)
        else
            bytes = read_neighbour(buffer.uri)
        end
        if #bytes < buffer.byteLength then
            fail("buffer " .. (index - 1) .. " is " .. #bytes .. " bytes, but says it is " .. buffer.byteLength)
        end
        buffers[index] = bytes
    end
    return buffers
end
-- }}}

-- {{{ local function add_primitive()
-- One triangle primitive, placed by `placement`, as a new part.
local function add_primitive(shape, document, buffers, primitive, part_name, placement, fail)
    if (primitive.mode or 4) ~= 4 then
        fail("primitive of '" .. part_name .. "' draws mode " .. primitive.mode .. "; only triangles (4) are read")
    end
    if primitive.attributes.POSITION == nil then fail("primitive of '" .. part_name .. "' has no POSITION") end
    local positions = read_accessor(document, buffers, primitive.attributes.POSITION, fail)
    local normals = primitive.attributes.NORMAL and read_accessor(document, buffers, primitive.attributes.NORMAL, fail)
    local order = primitive.indices and read_accessor(document, buffers, primitive.indices, fail)
    if order == nil then
        order = {}
        for k = 0, #positions / 3 - 1 do order[k + 1] = k end
    end
    if #order % 3 ~= 0 then fail("primitive of '" .. part_name .. "' has " .. #order .. " indices, not a multiple of 3") end

    -- colour: the material's base colour, or white when there is none
    local colour = { 1, 1, 1 }
    if primitive.material ~= nil then
        local material = document.materials and document.materials[primitive.material + 1]
        if material == nil then fail("material " .. primitive.material .. " does not exist") end
        local factor = material.pbrMetallicRoughness and material.pbrMetallicRoughness.baseColorFactor
        if factor then colour = { factor[1], factor[2], factor[3] } end
    end
    local part = record.add_part(shape, part_name, colour)

    local m = placement
    local n, det = normal_matrix(m)
    local corner_count = #positions / 3
    local function place(k)
        if k >= corner_count then fail("an index points at corner " .. k .. " of " .. corner_count) end
        local x, y, z = positions[k * 3 + 1], positions[k * 3 + 2], positions[k * 3 + 3]
        return m[1] * x + m[5] * y + m[9] * z + m[13],
               m[2] * x + m[6] * y + m[10] * z + m[14],
               m[3] * x + m[7] * y + m[11] * z + m[15]
    end
    local function turn(k)
        local x, y, z = normals[k * 3 + 1], normals[k * 3 + 2], normals[k * 3 + 3]
        local nx, ny, nz = n[1] * x + n[2] * y + n[3] * z, n[4] * x + n[5] * y + n[6] * z, n[7] * x + n[8] * y + n[9] * z
        local length = math.sqrt(nx * nx + ny * ny + nz * nz)
        if length > 0 then return nx / length, ny / length, nz / length end
        return 0, 0, 0
    end
    for t = 1, #order, 3 do
        local ia, ib, ic = order[t], order[t + 1], order[t + 2]
        -- a mirroring placement turns triangles inside out; swapping two
        -- corners turns them back
        if det < 0 then ib, ic = ic, ib end
        local ax, ay, az = place(ia)
        local bx, by, bz = place(ib)
        local cx, cy, cz = place(ic)
        if normals then
            local nax, nay, naz = turn(ia)
            local nbx, nby, nbz = turn(ib)
            local ncx, ncy, ncz = turn(ic)
            record.add_triangle(part, ax, ay, az, bx, by, bz, cx, cy, cz,
                { nax, nay, naz, nbx, nby, nbz, ncx, ncy, ncz })
        else
            record.add_triangle(part, ax, ay, az, bx, by, bz, cx, cy, cz)
        end
    end
end
-- }}}

-- {{{ local function split_glb()
-- The .glb container into its JSON text and its binary chunk (or nil).
local function split_glb(bytes, fail)
    local base = ffi.cast("const uint8_t *", bytes)
    local words = ffi.cast("const uint32_t *", base)
    if words[1] ~= 2 then fail("glb version " .. words[1] .. "; only version 2 is read") end
    local offset, json_text, binary = 12, nil, nil
    while offset + 8 <= #bytes do
        local length = ffi.cast("const uint32_t *", base + offset)[0]
        local kind = bytes:sub(offset + 5, offset + 8)
        local chunk = bytes:sub(offset + 9, offset + 8 + length)
        if kind == "JSON" then json_text = chunk elseif kind == "BIN\0" then binary = chunk end
        offset = offset + 8 + length
    end
    if json_text == nil then fail("glb has no JSON chunk") end
    return json_text, binary
end
-- }}}

-- {{{ function M.read()
-- bytes: the .gltf or .glb file. read_neighbour(file_name): bytes of a file
-- beside it (external .bin buffers), raising when missing.
function M.read(bytes, name, read_neighbour)
    local function fail(message) error(name .. ": " .. message, 0) end
    local json_text, embedded = bytes, nil
    if bytes:sub(1, 4) == "glTF" then json_text, embedded = split_glb(bytes, fail) end
    local document, position, problem = json.decode(json_text, 1, json.null)
    if document == nil then fail("not JSON: " .. tostring(problem) .. " at character " .. tostring(position)) end
    if not (document.asset and tostring(document.asset.version):match("^2")) then
        fail("not glTF 2 (asset.version is " .. tostring(document.asset and document.asset.version) .. ")")
    end
    local buffers = load_buffers(document, read_neighbour, embedded, fail)
    local scene = document.scenes and document.scenes[(document.scene or 0) + 1]
    if scene == nil then fail("has no scene to show") end

    local shape = record.new(name, "gltf", "y")
    shape.units = document.asset.extras and document.asset.extras.units or "metres"

    -- {{{ local function visit()
    -- Walks one node and its children, carrying the placement down.
    local function visit(node_index, parent_placement, depth)
        if depth > 64 then fail("nodes nest more than 64 deep; is a node its own ancestor?") end
        local node = document.nodes and document.nodes[node_index + 1]
        if node == nil then fail("node " .. node_index .. " does not exist") end
        local placement = multiply(parent_placement, node_placement(node))
        if node.mesh ~= nil then
            local mesh = document.meshes and document.meshes[node.mesh + 1]
            if mesh == nil then fail("mesh " .. node.mesh .. " does not exist") end
            local base_name = node.name or mesh.name or ("mesh " .. node.mesh)
            for k, primitive in ipairs(mesh.primitives) do
                local part_name = (#mesh.primitives > 1) and (base_name .. " #" .. k) or base_name
                add_primitive(shape, document, buffers, primitive, part_name, placement, fail)
            end
        end
        for _, child in ipairs(node.children or {}) do visit(child, placement, depth + 1) end
    end
    -- }}}

    local identity = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
    for _, root in ipairs(scene.nodes or {}) do visit(root, identity, 1) end
    return record.finish(shape)
end
-- }}}

-- {{{ function M.write()
-- One self-contained .gltf text: one node, mesh, material and pair of
-- accessors (positions, normals) per part, all numbers in one base64 buffer.
-- units: a word saved in asset.extras.units ("millimetres" for the crown).
function M.write(shape, made_by, units)
    local floats = 0
    for _, part in ipairs(shape.parts) do floats = floats + 2 * #part.positions end
    local block = ffi.new("float[?]", math.max(floats, 1))
    local document = {
        asset = { version = "2.0", generator = made_by or "005-gltf.lua", extras = { units = units } },
        scene = 0,
        scenes = { { nodes = {} } },
        nodes = {}, meshes = {}, materials = {}, accessors = {}, bufferViews = {},
    }
    local written = 0
    for index, part in ipairs(shape.parts) do
        local p, n = part.positions, part.normals
        local corners = #p / 3
        local min, max = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
        for k = 1, #p do
            block[written + k - 1] = p[k]
            local axis = (k - 1) % 3 + 1
            if p[k] < min[axis] then min[axis] = p[k] end
            if p[k] > max[axis] then max[axis] = p[k] end
        end
        for k = 1, #n do block[written + #p + k - 1] = n[k] end
        local view_base = #document.bufferViews
        -- positions, then normals, each a tightly packed run of 3 floats
        document.bufferViews[view_base + 1] = { buffer = 0, byteOffset = written * 4, byteLength = #p * 4 }
        document.bufferViews[view_base + 2] = { buffer = 0, byteOffset = (written + #p) * 4, byteLength = #n * 4 }
        -- glTF requires min and max on POSITION accessors
        document.accessors[view_base + 1] = { bufferView = view_base, componentType = 5126, count = corners,
            type = "VEC3", min = min, max = max }
        document.accessors[view_base + 2] = { bufferView = view_base + 1, componentType = 5126, count = corners, type = "VEC3" }
        document.materials[index] = { name = part.name,
            pbrMetallicRoughness = { baseColorFactor = { part.colour[1], part.colour[2], part.colour[3], 1 } } }
        document.meshes[index] = { name = part.name, primitives = { {
            attributes = { POSITION = view_base, NORMAL = view_base + 1 }, material = index - 1, mode = 4 } } }
        document.nodes[index] = { name = part.name, mesh = index - 1 }
        document.scenes[1].nodes[index] = index - 1
        written = written + #p + #n
    end
    local bytes = ffi.string(block, floats * 4)
    document.buffers = { { byteLength = #bytes,
        uri = "data:application/octet-stream;base64," .. M.base64_encode(bytes) } }
    return json.encode(document, { indent = true })
end
-- }}}

return M
