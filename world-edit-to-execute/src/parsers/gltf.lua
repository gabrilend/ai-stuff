--[[
glTF 2.0 Models (Issue 522g)

The open model format: what ComfyUI's image-to-3D nodes save (GLB), what
Blender and most tools export, and the architecture's choice for asset
packs (docs/wc3-engine-architecture.md, OQ-WC3-002). Read into the same
shape the renderer takes from MDX geosets (assets/gpu.lua), and written
from them, so WC3 models can go out to other tools.

  read    GLB, or .gltf with its buffers embedded (data URIs) or beside it
          (opts.dir); the default scene's node tree with each node's
          matrix or translation/rotation/scale; triangle primitives;
          POSITION, NORMAL, TEXCOORD_0, indices of any component type;
          each primitive's base colour and base colour texture (PNG or
          JPEG, embedded or beside it)
  write   GLB: one mesh per part, positions, normals, texture
          coordinates, indices, and each part's texture as an embedded PNG

Axes and units: glTF is Y up, metres; WC3 is Z up, its own units.
Reading maps glTF (x, y, z) to WC3 (x, -z, y) times opts.unit (WC3 units
to a metre, default 100), or scales to opts.height when given. Writing
does the reverse.

    local gltf = require("parsers.gltf")
    local model = gltf.decode(bytes, { height = 160 })
    -- model.meshes = { { positions = {x,y,z,...}, normals, uvs, indices (0-based),
    --                    color = {r,g,b,a}, image = {width,height,rgba} or nil }, ... }
    local glb = gltf.encode(model.meshes, { name = "Footman" })
]]

local ffi = require("ffi")
local bit = require("bit")

local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
package.path = HERE .. "/../../../libs/lua/?.lua;" .. package.path
local json = require("dkjson")

local gltf = {}

-- {{{ Matrices (column-major 4x4, as glTF stores them)
local function identity() return { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 } end

local function mul(a, b)
    local o = {}
    for c = 0, 3 do
        for r = 0, 3 do
            local s = 0
            for k = 0, 3 do s = s + a[k * 4 + r + 1] * b[c * 4 + k + 1] end
            o[c * 4 + r + 1] = s
        end
    end
    return o
end

local function trs(t, r, s)
    t, r, s = t or { 0, 0, 0 }, r or { 0, 0, 0, 1 }, s or { 1, 1, 1 }
    local x, y, z, w = r[1], r[2], r[3], r[4]
    local m = {
        1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0,
        2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0,
        2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0,
        t[1], t[2], t[3], 1,
    }
    for c = 0, 2 do for rr = 1, 3 do m[c * 4 + rr] = m[c * 4 + rr] * s[c + 1] end end
    return m
end

local function apply(m, x, y, z, w)
    return m[1] * x + m[5] * y + m[9] * z + m[13] * w,
           m[2] * x + m[6] * y + m[10] * z + m[14] * w,
           m[3] * x + m[7] * y + m[11] * z + m[15] * w
end
-- }}}

-- {{{ Accessors
local COMPONENT = { [5120] = { "int8_t", 1 }, [5121] = { "uint8_t", 1 }, [5122] = { "int16_t", 2 },
                    [5123] = { "uint16_t", 2 }, [5125] = { "uint32_t", 4 }, [5126] = { "float", 4 } }
local COUNT = { SCALAR = 1, VEC2 = 2, VEC3 = 3, VEC4 = 4, MAT4 = 16 }
local NORM = { [5120] = 127, [5121] = 255, [5122] = 32767, [5123] = 65535 }

local function read_accessor(doc, buffers, index)
    local acc = doc.accessors[index + 1]
    local view = doc.bufferViews[(acc.bufferView or 0) + 1]
    local buf = buffers[view.buffer + 1]
    local comp = COMPONENT[acc.componentType] or error("glTF: component type " .. tostring(acc.componentType))
    local n = COUNT[acc.type] or error("glTF: accessor type " .. tostring(acc.type))
    local stride = view.byteStride or comp[2] * n
    local base = (view.byteOffset or 0) + (acc.byteOffset or 0)
    local ptr = ffi.cast("const uint8_t*", buf)
    local ctype = ffi.typeof(comp[1] .. "*")
    local out = {}
    local norm = acc.normalized and NORM[acc.componentType]
    for i = 0, acc.count - 1 do
        local p = ffi.cast(ctype, ptr + base + i * stride)
        for k = 0, n - 1 do
            local v = tonumber(p[k])
            if norm then v = v / norm end
            out[#out + 1] = v
        end
    end
    return out, n
end
-- }}}

-- {{{ Images
local function b64decode(s)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local map = {}
    for i = 1, 64 do map[chars:byte(i)] = i - 1 end
    local out, acc, nbits = {}, 0, 0
    for i = 1, #s do
        local v = map[s:byte(i)]
        if v then
            acc = acc * 64 + v
            nbits = nbits + 6
            if nbits >= 8 then
                nbits = nbits - 8
                local byte = math.floor(acc / 2 ^ nbits)
                out[#out + 1] = string.char(byte)
                acc = acc % 2 ^ nbits
            end
        end
    end
    return table.concat(out)
end

local function read_uri(uri, dir)
    local data = uri:match("^data:[^,]*;base64,(.*)$")
    if data then return b64decode(data) end
    local f = io.open((dir or ".") .. "/" .. uri, "rb")
    if not f then error("glTF: can't read " .. uri) end
    local bytes = f:read("*a")
    f:close()
    return bytes
end

local function decode_image(bytes)
    if bytes:sub(1, 8) == "\137PNG\13\10\26\10" then return require("parsers.png").decode(bytes) end
    if bytes:sub(1, 2) == "\255\216" then
        local img = require("parsers.jpeg").decode(bytes)
        local n, out = img.width * img.height, ffi.new("uint8_t[?]", img.width * img.height * 4)
        for i = 0, n - 1 do
            local s = i * img.components
            if img.components >= 3 then
                out[i * 4], out[i * 4 + 1], out[i * 4 + 2] = img.pixels[s], img.pixels[s + 1], img.pixels[s + 2]
            else
                out[i * 4], out[i * 4 + 1], out[i * 4 + 2] = img.pixels[s], img.pixels[s], img.pixels[s]
            end
            out[i * 4 + 3] = 255
        end
        return { width = img.width, height = img.height, rgba = ffi.string(out, n * 4) }
    end
    error("glTF: an image that is neither PNG nor JPEG")
end
-- }}}

-- {{{ gltf.decode
function gltf.decode(bytes, opts)
    opts = opts or {}
    local doc, bin
    if bytes:sub(1, 4) == "glTF" then
        local function u32(p) local a, b, c, d = bytes:byte(p, p + 3) return a + b * 256 + c * 65536 + d * 16777216 end
        local pos = 13
        while pos < #bytes do
            local len, kind = u32(pos), bytes:sub(pos + 4, pos + 7)
            local body = bytes:sub(pos + 8, pos + 7 + len)
            if kind == "JSON" then doc = json.decode(body)
            elseif kind == "BIN\0" then bin = body end
            pos = pos + 8 + len
        end
    else
        doc = json.decode(bytes)
    end
    if type(doc) ~= "table" or not doc.asset then error("not a glTF model") end
    doc.accessors, doc.bufferViews = doc.accessors or {}, doc.bufferViews or {}

    local buffers = {}
    for i, b in ipairs(doc.buffers or {}) do
        buffers[i] = b.uri and read_uri(b.uri, opts.dir) or bin or ""
    end

    local images = {}
    local function image(index)
        if images[index] ~= nil then return images[index] or nil end
        local im = doc.images[index + 1]
        local data
        if im.bufferView then
            local v = doc.bufferViews[im.bufferView + 1]
            data = buffers[v.buffer + 1]:sub((v.byteOffset or 0) + 1, (v.byteOffset or 0) + v.byteLength)
        elseif im.uri then
            data = read_uri(im.uri, opts.dir)
        end
        local ok, img = pcall(decode_image, data or "")
        images[index] = ok and img or false
        return ok and img or nil
    end

    -- to WC3: (x, -z, y) * unit
    local unit = opts.unit or 100
    local meshes = {}
    local function visit(ni, parent)
        local node = doc.nodes[ni + 1]
        local m = node.matrix and node.matrix or trs(node.translation, node.rotation, node.scale)
        local world = mul(parent, m)
        if node.mesh then
            for _, prim in ipairs(doc.meshes[node.mesh + 1].primitives) do
                if (prim.mode or 4) == 4 and prim.attributes.POSITION then
                    local pos = read_accessor(doc, buffers, prim.attributes.POSITION)
                    local nrm = prim.attributes.NORMAL and read_accessor(doc, buffers, prim.attributes.NORMAL)
                    local uv = prim.attributes.TEXCOORD_0 and read_accessor(doc, buffers, prim.attributes.TEXCOORD_0)
                    local idx = prim.indices and read_accessor(doc, buffers, prim.indices)
                    local out = { positions = {}, normals = {}, uvs = uv or {}, indices = {} }
                    for i = 0, #pos / 3 - 1 do
                        local x, y, z = apply(world, pos[i * 3 + 1], pos[i * 3 + 2], pos[i * 3 + 3], 1)
                        out.positions[i * 3 + 1], out.positions[i * 3 + 2], out.positions[i * 3 + 3] = x * unit, -z * unit, y * unit
                        if nrm then
                            local nx, ny, nz = apply(world, nrm[i * 3 + 1], nrm[i * 3 + 2], nrm[i * 3 + 3], 0)
                            local len = math.sqrt(nx * nx + ny * ny + nz * nz)
                            if len > 0 then nx, ny, nz = nx / len, ny / len, nz / len end
                            out.normals[i * 3 + 1], out.normals[i * 3 + 2], out.normals[i * 3 + 3] = nx, -nz, ny
                        end
                    end
                    if idx then out.indices = idx else for i = 0, #pos / 3 - 1 do out.indices[i + 1] = i end end
                    local mat = prim.material and doc.materials and doc.materials[prim.material + 1]
                    local pbr = mat and mat.pbrMetallicRoughness or {}
                    out.color = pbr.baseColorFactor or { 1, 1, 1, 1 }
                    if pbr.baseColorTexture and doc.textures then
                        local tex = doc.textures[pbr.baseColorTexture.index + 1]
                        if tex and tex.source then out.image = image(tex.source) end
                    end
                    out.alpha_mode = mat and mat.alphaMode or "OPAQUE"
                    out.double_sided = mat and mat.doubleSided or false
                    meshes[#meshes + 1] = out
                end
            end
        end
        for _, c in ipairs(node.children or {}) do visit(c, world) end
    end
    local scene = doc.scenes and doc.scenes[(doc.scene or 0) + 1]
    local roots = scene and scene.nodes
    if not roots then
        roots = {}
        for i = 0, #(doc.nodes or {}) - 1 do roots[#roots + 1] = i end
    end
    for _, n in ipairs(roots) do visit(n, identity()) end

    -- missing normals: from the faces
    for _, m in ipairs(meshes) do
        if #m.normals == 0 then
            local acc = {}
            for i = 1, #m.positions do acc[i] = 0 end
            for t = 1, #m.indices - 2, 3 do
                local a, b, c = m.indices[t], m.indices[t + 1], m.indices[t + 2]
                local ax, ay, az = m.positions[a * 3 + 1], m.positions[a * 3 + 2], m.positions[a * 3 + 3]
                local ux, uy, uz = m.positions[b * 3 + 1] - ax, m.positions[b * 3 + 2] - ay, m.positions[b * 3 + 3] - az
                local vx, vy, vz = m.positions[c * 3 + 1] - ax, m.positions[c * 3 + 2] - ay, m.positions[c * 3 + 3] - az
                local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
                for _, v in ipairs({ a, b, c }) do
                    acc[v * 3 + 1], acc[v * 3 + 2], acc[v * 3 + 3] = acc[v * 3 + 1] + nx, acc[v * 3 + 2] + ny, acc[v * 3 + 3] + nz
                end
            end
            for i = 0, #m.positions / 3 - 1 do
                local x, y, z = acc[i * 3 + 1], acc[i * 3 + 2], acc[i * 3 + 3]
                local len = math.sqrt(x * x + y * y + z * z)
                if len == 0 then len, z = 1, 1 end
                m.normals[i * 3 + 1], m.normals[i * 3 + 2], m.normals[i * 3 + 3] = x / len, y / len, z / len
            end
        end
    end

    -- extent, and fitting to a height (standing on z = 0)
    local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
    for _, m in ipairs(meshes) do
        for i = 0, #m.positions / 3 - 1 do
            for k = 1, 3 do
                local v = m.positions[i * 3 + k]
                if v < lo[k] then lo[k] = v end
                if v > hi[k] then hi[k] = v end
            end
        end
    end
    if opts.height and hi[3] > lo[3] then
        local k = opts.height / (hi[3] - lo[3])
        local cx, cy = (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2
        for _, m in ipairs(meshes) do
            for i = 0, #m.positions / 3 - 1 do
                m.positions[i * 3 + 1] = (m.positions[i * 3 + 1] - cx) * k
                m.positions[i * 3 + 2] = (m.positions[i * 3 + 2] - cy) * k
                m.positions[i * 3 + 3] = (m.positions[i * 3 + 3] - lo[3]) * k
            end
        end
        lo, hi = { (lo[1] - cx) * k, (lo[2] - cy) * k, 0 },
                 { (hi[1] - cx) * k, (hi[2] - cy) * k, (hi[3] - lo[3]) * k }
    end
    return { meshes = meshes, min = lo, max = hi, generator = doc.asset.generator }
end
-- }}}

-- {{{ gltf.encode
-- meshes: { { positions, normals, uvs, indices (0-based), png (bytes) or nil, name }, ... }
function gltf.encode(meshes, opts)
    opts = opts or {}
    local unit = opts.unit or 100
    local chunks, offset = {}, 0
    local doc = { asset = { version = "2.0", generator = "world-edit-to-execute" },
                  scene = 0, scenes = { { nodes = {} } }, nodes = {}, meshes = {},
                  buffers = {}, bufferViews = {}, accessors = {}, materials = {}, textures = {},
                  images = {}, samplers = { { magFilter = 9729, minFilter = 9987, wrapS = 10497, wrapT = 10497 } } }

    local function add_view(bytes, target)
        local pad = (4 - #bytes % 4) % 4
        chunks[#chunks + 1] = bytes .. string.rep("\0", pad)
        doc.bufferViews[#doc.bufferViews + 1] = { buffer = 0, byteOffset = offset, byteLength = #bytes, target = target }
        offset = offset + #bytes + pad
        return #doc.bufferViews - 1
    end
    local function floats(list, n, want_bounds)
        local count = #list / n
        local buf = ffi.new("float[?]", #list)
        local lo, hi = {}, {}
        for i = 1, #list do
            buf[i - 1] = list[i]
            local k = (i - 1) % n + 1
            if want_bounds then
                lo[k] = math.min(lo[k] or math.huge, list[i])
                hi[k] = math.max(hi[k] or -math.huge, list[i])
            end
        end
        local view = add_view(ffi.string(buf, #list * 4), 34962)
        local acc = { bufferView = view, componentType = 5126, count = count,
                      type = n == 2 and "VEC2" or "VEC3" }
        if want_bounds then acc.min, acc.max = lo, hi end
        doc.accessors[#doc.accessors + 1] = acc
        return #doc.accessors - 1
    end

    for mi, m in ipairs(meshes) do
        local n = #m.positions / 3
        -- WC3 (x, y, z) -> glTF (x, z, -y) / unit
        local pos, nrm = {}, {}
        for i = 0, n - 1 do
            local x, y, z = m.positions[i * 3 + 1], m.positions[i * 3 + 2], m.positions[i * 3 + 3]
            pos[i * 3 + 1], pos[i * 3 + 2], pos[i * 3 + 3] = x / unit, z / unit, -y / unit
            local nx, ny, nz = m.normals[i * 3 + 1] or 0, m.normals[i * 3 + 2] or 0, m.normals[i * 3 + 3] or 1
            nrm[i * 3 + 1], nrm[i * 3 + 2], nrm[i * 3 + 3] = nx, nz, -ny
        end
        local attrs = { POSITION = floats(pos, 3, true), NORMAL = floats(nrm, 3) }
        if m.uvs and #m.uvs >= n * 2 then attrs.TEXCOORD_0 = floats(m.uvs, 2) end
        local ib = ffi.new("uint32_t[?]", #m.indices)
        for i = 1, #m.indices do ib[i - 1] = m.indices[i] end
        local iview = add_view(ffi.string(ib, #m.indices * 4), 34963)
        doc.accessors[#doc.accessors + 1] = { bufferView = iview, componentType = 5125, count = #m.indices, type = "SCALAR" }
        local mat = { name = m.name or ("part " .. mi), pbrMetallicRoughness = { metallicFactor = 0, roughnessFactor = 1 },
                      doubleSided = true }
        if m.png then
            local view = add_view(m.png)
            doc.images[#doc.images + 1] = { bufferView = view, mimeType = "image/png" }
            doc.textures[#doc.textures + 1] = { source = #doc.images - 1, sampler = 0 }
            mat.pbrMetallicRoughness.baseColorTexture = { index = #doc.textures - 1 }
            if m.alpha_test then mat.alphaMode, mat.alphaCutoff = "MASK", 0.75 end
        else
            mat.pbrMetallicRoughness.baseColorFactor = m.color or { 0.6, 0.6, 0.6, 1 }
        end
        doc.materials[#doc.materials + 1] = mat
        doc.meshes[#doc.meshes + 1] = { name = m.name, primitives = { { attributes = attrs, indices = #doc.accessors - 1,
                                                                       material = #doc.materials - 1, mode = 4 } } }
        doc.nodes[#doc.nodes + 1] = { mesh = #doc.meshes - 1, name = m.name }
        doc.scenes[1].nodes[#doc.scenes[1].nodes + 1] = #doc.nodes - 1
    end
    if #doc.images == 0 then doc.images, doc.textures, doc.samplers = nil, nil, nil end

    local binary = table.concat(chunks)
    doc.buffers[1] = { byteLength = #binary }
    local text = json.encode(doc)
    text = text .. string.rep(" ", (4 - #text % 4) % 4)
    local function u32(v) return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256) end
    local total = 12 + 8 + #text + 8 + #binary
    return "glTF" .. u32(2) .. u32(total) .. u32(#text) .. "JSON" .. text .. u32(#binary) .. "BIN\0" .. binary
end
-- }}}

return gltf
