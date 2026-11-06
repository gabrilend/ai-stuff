--[[
MDX Models (Issues 522b, 116)

Warcraft III's binary model format (version 800): "MDLX", then chunks of
a four-character tag and a byte size. Read here:

  VERS  version
  MODL  name, extent, blend time
  SEQS  sequences (animations): name, frame interval, looping, extent
  GLBS  global sequence durations
  TEXS  textures: path, or a replaceable id (1 team colour, 2 team glow,
        11 cliff, 31-37 trees ...), flags (wrap)
  MTLS  materials: layers with filter mode, shading flags (two sided,
        unshaded ...), texture, alpha, and their animated alpha/texture
  GEOS  geosets: vertices, normals, triangles, vertex groups, matrix
        groups (bone indices), material, texture coordinates
  GEOA  geoset animations: alpha and colour, static or keyed
  BONE, HELP  nodes: name, id, parent, translation/rotation/scaling keys
  PIVT  pivot points (one per node, by object id)
  ATCH  attachments (node, path, id, visibility)
  EVTS  event objects (node, frames)
  CLID  collision shapes (node, box/plane/sphere/cylinder)
  CAMS  cameras   TXAN  texture animations (tracks)
  LITE, PREM, PRE2, RIBB  lights, particle emitters, ribbons: their node
        is read (they're in the hierarchy), their own fields kept as raw
        bytes until something draws them
  anything else: kept whole, in file order in m.unread ({tag, offset,
        bytes}) and by tag in m.other; mdx.summary lists their tags

Only version 800, classic WC3's, is read; Reforged's HD versions (900 and
later) are refused with an error naming the version. A file cut short, or a
size inside it that runs past its chunk, raises an error naming the chunk
and the byte offset (issue 116).

Animated values are tracks: { interpolation = 0 none | 1 linear |
2 hermite | 3 bezier, global = id or nil, keys = { {frame, value, in, out}, ... } };
mdx.sample(track, frame, default) evaluates one.

    local mdx = require("parsers.mdx")
    local m = mdx.parse(bytes)
    m.geosets[1].vertices   -- { x1, y1, z1, x2, ... }
    m.textures[1].path, m.materials[1].layers[1].filter
    mdx.summary(m)          -- { vertices, triangles, sequences, textures, ... }

Inputs and outputs in full: parsers/mdx.info.md.
]]

local ffi = require("ffi")

local mdx = {}

mdx.VERSION = 800   -- the one version read: classic WC3's

mdx.FILTER = { [0] = "none", "transparent", "blend", "additive", "add_alpha", "modulate", "modulate2x" }
mdx.SHADING = { unshaded = 1, sphere_env = 2, two_sided = 16, unfogged = 32, no_depth_test = 64, no_depth_set = 128 }

-- {{{ Reader
-- Every read checks it stays inside the chunk being decoded (r.limit), and
-- a failed check names the chunk and the byte offset (issue 116): the
-- buffer is raw memory, so an unchecked read past it would read whatever
-- lies beyond instead of failing.
local R = {}
R.__index = R

local f32 = ffi.new("float[1]")

local function reader(data)
    local n = #data
    local buf = ffi.new("uint8_t[?]", math.max(n, 1))
    ffi.copy(buf, data, n)
    return setmetatable({ data = data, buf = buf, pos = 0, n = n, limit = n, where = "the file header" }, R)
end

-- {{{ R:fail
-- An error naming where the reader is: the chunk and the byte offset
function R:fail(fmt, ...)
    error(string.format("MDX: %s, at byte %d: " .. fmt, self.where, self.pos, ...), 0)
end
-- }}}

-- {{{ R:need
function R:need(count)
    if self.pos + count > self.limit then
        self:fail("truncated (needs %d bytes, %d left)", count, math.max(0, self.limit - self.pos))
    end
end
-- }}}

-- {{{ R:record
-- A record that starts with its own byte size (counting the size field):
-- the position where it ends, checked to lie inside the chunk and past the
-- size field, so a bad size can neither run off the chunk nor loop forever
function R:record()
    local start = self.pos
    local size = self:u32()
    if size < 4 or start + size > self.limit then
        self.pos = start
        self:fail("a record claims %d bytes, but %d are left", size, self.limit - start)
    end
    return start + size
end
-- }}}

function R:u32()
    self:need(4)
    local b, p = self.buf, self.pos
    self.pos = p + 4
    return b[p] + b[p + 1] * 256 + b[p + 2] * 65536 + b[p + 3] * 16777216
end
function R:i32()
    local v = self:u32()
    return v >= 2147483648 and v - 4294967296 or v
end
function R:f32()
    self:need(4)
    ffi.copy(f32, self.buf + self.pos, 4)
    self.pos = self.pos + 4
    return f32[0]
end
function R:u16()
    self:need(2)
    local b, p = self.buf, self.pos
    self.pos = p + 2
    return b[p] + b[p + 1] * 256
end
function R:u8()
    self:need(1)
    local v = self.buf[self.pos]
    self.pos = self.pos + 1
    return v
end
function R:tag()
    self:need(4)
    local t = self.data:sub(self.pos + 1, self.pos + 4)
    self.pos = self.pos + 4
    return t
end
function R:peek_tag() return self.data:sub(self.pos + 1, self.pos + 4) end
function R:str(len)
    self:need(len)
    local s = self.data:sub(self.pos + 1, self.pos + len)
    self.pos = self.pos + len
    return (s:gsub("%z.*$", ""))
end
function R:floats(count)
    local t = {}
    for i = 1, count do t[i] = self:f32() end
    return t
end
function R:extent()
    return { radius = self:f32(), min = self:floats(3), max = self:floats(3) }
end
-- }}}

-- {{{ Tracks
-- tag -> number of floats in its value (or "int" for integer values)
local TRACK_SIZE = {
    KGTR = 3, KGRT = 4, KGSC = 3,            -- node translation, rotation, scaling
    KGAO = 1, KGAC = 3,                      -- geoset animation alpha, colour
    KMTA = 1, KMTF = "int",                  -- layer alpha, texture id
    KATV = 1, KLAV = 1, KLAI = 1, KLAC = 3, KLBC = 3, KLBI = 1, KLAS = 1, KLAE = 1,
    KP2V = 1, KP2S = 1, KP2E = 1, KP2L = 1, KP2G = 1, KP2W = 1, KP2N = 1, KP2Z = 1, KP2R = 1,
    KPEV = 1, KPPV = 1, KRVS = 1, KRHA = 1, KRHB = 1, KRAL = 1, KRCO = 3, KRTX = "int",
    KTAT = 3, KTAR = 4, KTAS = 3, KCTR = 3, KTTR = 3, KCRL = 1,
}

local function read_track(r, tag)
    local size = TRACK_SIZE[tag]
    if not size then r.pos = r.pos - 4 r:fail("unknown track %q", tag) end
    local count = r:u32()
    local t = { interpolation = r:u32(), keys = {} }
    local g = r:i32()
    if g >= 0 then t.global = g end
    local function value()
        if size == "int" then return r:u32() end
        if size == 1 then return r:f32() end
        return r:floats(size)
    end
    for i = 1, count do
        local k = { frame = r:i32(), value = value() }
        if t.interpolation > 1 then k.inTan, k.outTan = value(), value() end
        t.keys[i] = k
    end
    return t
end

-- Tracks that follow a record's fixed fields, up to the record's end
-- (reads may not pass the record's end while they're read)
local function read_tracks(r, stop, into)
    local limit = r.limit
    r.limit = stop
    while r.pos < stop do
        local tag = r:tag()
        into[tag] = read_track(r, tag)
    end
    r.limit = limit
end
-- }}}

-- {{{ mdx.sample
-- A track's value at frame (within [first, last] of the playing
-- sequence); constant tracks, or no track, give default
local function lerp(a, b, t)
    if type(a) == "number" then return a + (b - a) * t end
    local o = {}
    for i = 1, #a do o[i] = a[i] + (b[i] - a[i]) * t end
    return o
end

local function slerp(a, b, t)
    local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4]
    local bb = b
    if dot < 0 then bb, dot = { -b[1], -b[2], -b[3], -b[4] }, -dot end
    if dot > 0.9995 then
        local o = lerp(a, bb, t)
        local len = math.sqrt(o[1] ^ 2 + o[2] ^ 2 + o[3] ^ 2 + o[4] ^ 2)
        return { o[1] / len, o[2] / len, o[3] / len, o[4] / len }
    end
    local th = math.acos(dot)
    local s = math.sin(th)
    local wa, wb = math.sin((1 - t) * th) / s, math.sin(t * th) / s
    return { a[1] * wa + bb[1] * wb, a[2] * wa + bb[2] * wb, a[3] * wa + bb[3] * wb, a[4] * wa + bb[4] * wb }
end

function mdx.sample(track, frame, default, first, last, rotation)
    if not track or #track.keys == 0 then return default end
    local keys = track.keys
    -- keys inside the sequence's interval only (when given)
    local lo, hi = 1, #keys
    if first then
        lo = nil
        for i = 1, #keys do
            if keys[i].frame >= first and keys[i].frame <= last then
                lo = lo or i
                hi = i
            end
        end
        if not lo then return default end
    end
    if frame <= keys[lo].frame then return keys[lo].value end
    if frame >= keys[hi].frame then return keys[hi].value end
    for i = lo, hi - 1 do
        local a, b = keys[i], keys[i + 1]
        if frame >= a.frame and frame < b.frame then
            if track.interpolation == 0 then return a.value end
            local t = (frame - a.frame) / (b.frame - a.frame)
            if rotation then return slerp(a.value, b.value, t) end
            return lerp(a.value, b.value, t)   -- hermite/bezier taken as linear (close for WC3's curves)
        end
    end
    return keys[hi].value
end
-- }}}

-- {{{ Chunks
local chunk = {}

-- {{{ chunk.VERS
-- Classic WC3 writes version 800. Reforged's HD models (900 and later) are
-- refused, not guessed at: the project leaves Reforged's formats alone
-- (docs/versions-we-leave-alone.md), and a caller that gets the error
-- falls back to a stand-in as for any unreadable model.
function chunk.VERS(r, m)
    m.version = r:u32()
    if m.version > mdx.VERSION then
        error(string.format("MDX: version %d is Reforged's HD model format, which isn't read"
            .. " (only version %d; see docs/versions-we-leave-alone.md)", m.version, mdx.VERSION), 0)
    elseif m.version < mdx.VERSION then
        error(string.format("MDX: version %d is older than the classic version %d, which isn't read",
            m.version, mdx.VERSION), 0)
    end
end
-- }}}

function chunk.MODL(r, m, stop)
    m.name = r:str(80)
    m.animation_file = r:str(260)
    m.extent = r:extent()
    m.blend_time = r:u32()
end

function chunk.SEQS(r, m, stop)
    m.sequences = {}
    while r.pos < stop do
        local s = { name = r:str(80), start = r:u32(), finish = r:u32(), move_speed = r:f32() }
        s.non_looping = r:u32() == 1
        s.rarity = r:f32()
        s.sync_point = r:u32()
        s.extent = r:extent()
        m.sequences[#m.sequences + 1] = s
    end
end

function chunk.GLBS(r, m, stop)
    m.global_sequences = {}
    while r.pos < stop do m.global_sequences[#m.global_sequences + 1] = r:u32() end
end

function chunk.TEXS(r, m, stop)
    m.textures = {}
    while r.pos < stop do
        local t = { replaceable = r:u32(), path = r:str(260), flags = r:u32() }
        t.wrap_width, t.wrap_height = t.flags % 2 == 1, math.floor(t.flags / 2) % 2 == 1
        m.textures[#m.textures + 1] = t
    end
end

function chunk.MTLS(r, m, stop)
    m.materials = {}
    while r.pos < stop do
        local stop_mat = r:record()
        local mat = { priority_plane = r:i32(), flags = r:u32(), layers = {} }
        if r:tag() ~= "LAYS" then r.pos = r.pos - 4 r:fail("a material without LAYS") end
        local count = r:u32()
        for i = 1, count do
            local stop_layer = r:record()
            local layer = { filter_mode = r:u32(), shading = r:u32(), texture = r:u32(),
                            texture_animation = r:i32(), coord = r:u32(), alpha = r:f32(), tracks = {} }
            layer.filter = mdx.FILTER[layer.filter_mode] or "none"
            read_tracks(r, stop_layer, layer.tracks)
            mat.layers[i] = layer
        end
        r.pos = stop_mat
        m.materials[#m.materials + 1] = mat
    end
end

local function counted(r, tag, per, read)
    local t = r:tag()
    if t ~= tag then r.pos = r.pos - 4 r:fail("expected %s, found %q", tag, t) end
    local count = r:u32()
    local out = {}
    for i = 1, count * per do out[i] = read(r) end
    return out, count
end

function chunk.GEOS(r, m, stop)
    m.geosets = {}
    while r.pos < stop do
        local stop_geoset = r:record()
        local g = {}
        g.vertices = counted(r, "VRTX", 3, R.f32)
        g.normals = counted(r, "NRMS", 3, R.f32)
        g.face_types = counted(r, "PTYP", 1, R.u32)
        g.face_counts = counted(r, "PCNT", 1, R.u32)
        g.faces = counted(r, "PVTX", 1, R.u16)
        g.vertex_groups = counted(r, "GNDX", 1, R.u8)
        g.group_sizes = counted(r, "MTGC", 1, R.u32)
        g.group_indices = counted(r, "MATS", 1, R.u32)
        g.material = r:u32()
        g.selection_group = r:u32()
        g.selection_flags = r:u32()
        g.extent = r:extent()
        local nextents = r:u32()
        g.sequence_extents = {}
        for i = 1, nextents do g.sequence_extents[i] = r:extent() end
        local t = r:tag()
        if t ~= "UVAS" then r.pos = r.pos - 4 r:fail("expected UVAS, found %q", t) end
        local sets = r:u32()
        g.uvs = {}
        for i = 1, sets do g.uvs[i] = counted(r, "UVBS", 2, R.f32) end
        r.pos = stop_geoset
        m.geosets[#m.geosets + 1] = g
    end
end

function chunk.GEOA(r, m, stop)
    m.geoset_animations = {}
    while r.pos < stop do
        local stop_anim = r:record()
        local a = { alpha = r:f32(), flags = r:u32(), color = r:floats(3), geoset = r:u32(), tracks = {} }
        read_tracks(r, stop_anim, a.tracks)
        r.pos = stop_anim
        m.geoset_animations[#m.geoset_animations + 1] = a
    end
end

local function read_node(r)
    local stop_node = r:record()
    local node = { name = r:str(80), id = r:i32(), parent = r:i32(), flags = r:u32(), tracks = {} }
    read_tracks(r, stop_node, node.tracks)
    r.pos = stop_node
    return node
end

function chunk.BONE(r, m, stop)
    m.bones = {}
    while r.pos < stop do
        local node = read_node(r)
        node.geoset, node.geoset_animation = r:i32(), r:i32()
        m.bones[#m.bones + 1] = node
    end
end

function chunk.HELP(r, m, stop)
    m.helpers = {}
    while r.pos < stop do m.helpers[#m.helpers + 1] = read_node(r) end
end

-- Records that are a node plus fields this reader keeps raw (particle
-- emitters, ribbons, lights, attachments): the node joins the hierarchy,
-- the rest is kept as bytes for when they're drawn
local function node_records(field, extra)
    return function(r, m, stop)
        m[field] = {}
        while r.pos < stop do
            local stop_record = r:record()
            local node = read_node(r)
            if extra then extra(r, node, stop_record) end
            node.raw = r.data:sub(r.pos + 1, stop_record)
            r.pos = stop_record
            m[field][#m[field] + 1] = node
        end
    end
end

chunk.LITE = node_records("lights")
chunk.PREM = node_records("particle_emitters")
chunk.PRE2 = node_records("particle_emitters2")
chunk.RIBB = node_records("ribbons")
chunk.ATCH = node_records("attachments", function(r, node, stop)
    node.path = r:str(260)
    node.attachment_id = r:u32()
    read_tracks(r, stop, node.tracks)
end)

-- Event objects: a node and the frames it fires on
function chunk.EVTS(r, m, stop)
    m.events = {}
    while r.pos < stop do
        local node = read_node(r)
        if r.pos < stop and r:peek_tag() == "KEVT" then
            r:tag()
            local count = r:u32()
            node.global = r:i32()
            node.frames = {}
            for i = 1, count do node.frames[i] = r:u32() end
        end
        m.events[#m.events + 1] = node
    end
end

-- Collision shapes: 0 box, 1 plane (two corners), 2 sphere (centre,
-- radius), 3 cylinder (two ends, radius)
function chunk.CLID(r, m, stop)
    m.collision = {}
    while r.pos < stop do
        local node = read_node(r)
        node.shape = r:u32()
        local n = (node.shape == 2) and 1 or 2
        node.points = {}
        for i = 1, n do node.points[i] = r:floats(3) end
        if node.shape == 2 or node.shape == 3 then node.radius = r:f32() end
        m.collision[#m.collision + 1] = node
    end
end

function chunk.CAMS(r, m, stop)
    m.cameras = {}
    while r.pos < stop do
        local stop_camera = r:record()
        local c = { name = r:str(80), position = r:floats(3), fov = r:f32(), far = r:f32(), near = r:f32(),
                    target = r:floats(3), tracks = {} }
        read_tracks(r, stop_camera, c.tracks)
        r.pos = stop_camera
        m.cameras[#m.cameras + 1] = c
    end
end

function chunk.TXAN(r, m, stop)
    m.texture_animations = {}
    while r.pos < stop do
        local stop_anim = r:record()
        local t = { tracks = {} }
        read_tracks(r, stop_anim, t.tracks)
        r.pos = stop_anim
        m.texture_animations[#m.texture_animations + 1] = t
    end
end

function chunk.PIVT(r, m, stop)
    m.pivots = {}
    while r.pos < stop do m.pivots[#m.pivots + 1] = r:floats(3) end
end
-- }}}

-- {{{ mdx.parse
-- Raises an error naming the chunk and byte offset when the file is cut
-- short or a size inside it is wrong, and naming the version when it isn't
-- classic WC3's. Chunks this reader doesn't decode are kept, in file order,
-- in m.unread ({ tag, offset, bytes }) and by tag in m.other.
function mdx.parse(data)
    if data:sub(1, 4) ~= "MDLX" then error("not an MDX model (no MDLX)") end
    local r = reader(data)
    r.pos = 4
    local m = { chunks = {}, other = {}, unread = {} }
    while r.pos < r.n do
        local start = r.pos
        r.where, r.limit = "the chunk list", r.n
        if r.pos + 8 > r.n then
            r:fail("%d stray bytes, too few for a chunk header (the file is cut short?)", r.n - r.pos)
        end
        local tag = r:tag()
        local size = r:u32()
        local stop = r.pos + size
        if stop > r.n then
            r.pos = start
            r:fail("chunk %q claims %d bytes, but %d are left", tag, size, r.n - start - 8)
        end
        r.where = string.format("chunk %s (starting at byte %d)", tag, start)
        r.limit = stop
        local fn = chunk[tag]
        if fn then
            fn(r, m, stop)
        else
            local bytes = data:sub(r.pos + 1, stop)
            m.unread[#m.unread + 1] = { tag = tag, offset = start, bytes = bytes }
            if not m.other[tag] then m.other[tag] = bytes end
        end
        m.chunks[#m.chunks + 1] = tag
        r.pos = stop
    end
    m.textures = m.textures or {}
    m.materials = m.materials or {}
    m.geosets = m.geosets or {}
    m.sequences = m.sequences or {}
    m.bones = m.bones or {}
    m.helpers = m.helpers or {}
    m.pivots = m.pivots or {}
    m.geoset_animations = m.geoset_animations or {}
    return m
end
-- }}}

-- {{{ mdx.summary
-- The facts the fetcher (603) and the catalogue (1001) show about a model
-- without drawing it: counts, sequence names, the textures it names, the
-- replaceable ids it uses (1 team colour, 2 team glow, ...), and the tags
-- of the chunks left unread.
function mdx.summary(m)
    local s = { version = m.version, name = m.name, geosets = #m.geosets, vertices = 0, triangles = 0,
                sequences = {}, textures = {}, replaceable_ids = {}, nodes = 0, unread = {} }
    for _, g in ipairs(m.geosets) do
        s.vertices = s.vertices + #g.vertices / 3
        s.triangles = s.triangles + math.floor(#g.faces / 3)
    end
    for i, q in ipairs(m.sequences) do s.sequences[i] = q.name end
    local seen = {}
    for _, t in ipairs(m.textures) do
        if t.replaceable ~= 0 then
            if not seen[t.replaceable] then
                seen[t.replaceable] = true
                s.replaceable_ids[#s.replaceable_ids + 1] = t.replaceable
            end
        elseif t.path ~= "" then
            s.textures[#s.textures + 1] = t.path
        end
    end
    table.sort(s.replaceable_ids)
    for _ in pairs(mdx.nodes(m)) do s.nodes = s.nodes + 1 end
    for i, u in ipairs(m.unread or {}) do s.unread[i] = u.tag end
    return s
end
-- }}}

-- {{{ mdx.nodes
-- Every node (bones, helpers, attachments, lights, emitters, ribbons,
-- events, collision shapes) by object id
function mdx.nodes(m)
    local by = {}
    for _, list in ipairs({ m.bones, m.helpers, m.attachments or {}, m.lights or {}, m.particle_emitters or {},
                            m.particle_emitters2 or {}, m.ribbons or {}, m.events or {}, m.collision or {} }) do
        for _, n in ipairs(list) do by[n.id] = n end
    end
    return by
end
-- }}}

-- {{{ mdx.sequence
-- The sequence named like `name` ("Stand" matches "Stand 1"), else the first
function mdx.sequence(m, name)
    name = (name or "stand"):lower()
    for _, s in ipairs(m.sequences) do
        if s.name:lower():match("^%s*" .. name .. "[%s%d]*$") then return s end
    end
    for _, s in ipairs(m.sequences) do
        if s.name:lower():find(name, 1, true) then return s end
    end
    return m.sequences[1]
end
-- }}}

return mdx
