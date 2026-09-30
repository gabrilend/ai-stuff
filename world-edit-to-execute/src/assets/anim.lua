--[[
Model Animation (Issue 523)

Plays a WC3 model's own sequences (Stand, Walk, Attack, Death ...) on the
renderer's skinned meshes (render/models.c). The model's parts come from
assets/gpu.lua; this works out, for one moment of one sequence:

  nodes    every node's matrix: its translation, rotation and scaling
           tracks at that frame, about its pivot, under its parent's
  groups   each geoset's matrix groups (the bones a vertex follows): the
           average of their nodes' matrices, which is what WC3 does
  alphas   each part's opacity: its geoset animation's alpha (parts come
           and go: a death's corpse, a weapon swapped) times its
           material layer's alpha

and hands them to the renderer as one string of floats (a "pose").

Tracks: linear, Hermite and Bezier for values; rotations are slerped
(Hermite/Bezier rotations taken as slerp). Global sequences (tracks that
loop on their own clock) follow the playhead's own running time.

Sequences are asked for by name, as WC3's animation names work: "stand"
plays one of Stand, Stand - 2, Stand - 3 ... (picked by rarity, again at
each loop), not Stand Ready; "stand ready" plays that. A sequence that
doesn't loop (Death) holds its last frame.

    local anim = require("assets.anim")
    local rig = cache:rig(model_id)            -- assets/gpu.lua
    local st = anim.state()                    -- one per thing drawn
    anim.play(rig, st, "walk", { rate = 1.2 })
    anim.step(rig, st, dt)
    render.model_draw(model_id, x, y, z, facing, scale, r, g, b, 1, anim.pose(rig, st))

Not done: billboarded nodes (they face the camera in WC3; here they turn
with their parent), the "don't inherit" node flags, geoset colour
animation, texture animation, particles and ribbons.
]]

local ffi = require("ffi")
local bit = require("bit")

local anim = {}

anim.MAX_GROUPS = 128        -- the renderer's limit per skin (render/models.c)
anim.QUANTUM = 20            -- ms: poses are cached per model at this step

-- {{{ Sampling
-- The keys of a track inside [first, last] (cached per interval): lo, hi
local function range(track, first, last)
    local rc = track._range
    if not rc then rc = {}; track._range = rc end
    local key = first * 4194304 + last
    local v = rc[key]
    if v == nil then
        local keys = track.keys
        local lo, hi
        for i = 1, #keys do
            local f = keys[i].frame
            if f >= first and f <= last then
                lo = lo or i
                hi = i
            end
        end
        v = lo and (lo * 65536 + hi) or false
        rc[key] = v
    end
    if not v then return nil end
    return math.floor(v / 65536), v % 65536
end

-- the key pair around frame: a, b, t (b nil when frame is at or past an end)
local function around(keys, lo, hi, frame)
    if frame <= keys[lo].frame then return keys[lo], nil, 0 end
    if frame >= keys[hi].frame then return keys[hi], nil, 0 end
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if keys[mid].frame <= frame then lo = mid else hi = mid end
    end
    local a, b = keys[lo], keys[hi]
    if b.frame <= a.frame then return b, nil, 0 end   -- repeated (or unordered) keys
    return a, b, (frame - a.frame) / (b.frame - a.frame)
end

-- weights of a, a's out tangent, b's in tangent, b
local function curve(kind, t)
    if kind == 2 then
        local t2 = t * t
        return t2 * (2 * t - 3) + 1, t2 * (t - 2) + t, t2 * (t - 1), t2 * (3 - 2 * t)
    end
    local s = 1 - t
    return s * s * s, 3 * t * s * s, 3 * t * t * s, t * t * t
end

-- the frame a track is read at, and its interval: the sequence's, or its
-- global sequence's own loop
local function when(track, rig, first, last, frame, clock)
    if track.global then
        local len = rig.globals[track.global + 1] or 0
        if len <= 0 then return 0, 0, 0 end
        return clock % len, 0, len
    end
    return frame, first, last
end

local function sample1(track, def, rig, first, last, frame, clock)
    if not track or #track.keys == 0 then return def end
    local f, a0, a1 = when(track, rig, first, last, frame, clock)
    local lo, hi = range(track, a0, a1)
    if not lo then return def end
    local a, b, t = around(track.keys, lo, hi, f)
    if not b or track.interpolation == 0 then return a.value end
    if track.interpolation == 1 then return a.value + (b.value - a.value) * t end
    local w1, w2, w3, w4 = curve(track.interpolation, t)
    return a.value * w1 + a.outTan * w2 + b.inTan * w3 + b.value * w4
end

local function sample3(track, dx, dy, dz, rig, first, last, frame, clock)
    if not track or #track.keys == 0 then return dx, dy, dz end
    local f, a0, a1 = when(track, rig, first, last, frame, clock)
    local lo, hi = range(track, a0, a1)
    if not lo then return dx, dy, dz end
    local a, b, t = around(track.keys, lo, hi, f)
    local av = a.value
    if not b or track.interpolation == 0 then return av[1], av[2], av[3] end
    local bv = b.value
    if track.interpolation == 1 then
        return av[1] + (bv[1] - av[1]) * t, av[2] + (bv[2] - av[2]) * t, av[3] + (bv[3] - av[3]) * t
    end
    local w1, w2, w3, w4 = curve(track.interpolation, t)
    local ao, bi = a.outTan, b.inTan
    return av[1] * w1 + ao[1] * w2 + bi[1] * w3 + bv[1] * w4,
           av[2] * w1 + ao[2] * w2 + bi[2] * w3 + bv[2] * w4,
           av[3] * w1 + ao[3] * w2 + bi[3] * w3 + bv[3] * w4
end

local function sample_rotation(track, rig, first, last, frame, clock)
    if not track or #track.keys == 0 then return 0, 0, 0, 1 end
    local f, a0, a1 = when(track, rig, first, last, frame, clock)
    local lo, hi = range(track, a0, a1)
    if not lo then return 0, 0, 0, 1 end
    local a, b, t = around(track.keys, lo, hi, f)
    local q = a.value
    if not b or track.interpolation == 0 then return q[1], q[2], q[3], q[4] end
    local r = b.value
    local x1, y1, z1, w1 = q[1], q[2], q[3], q[4]
    local x2, y2, z2, w2 = r[1], r[2], r[3], r[4]
    local dot = x1 * x2 + y1 * y2 + z1 * z2 + w1 * w2
    if dot < 0 then x2, y2, z2, w2, dot = -x2, -y2, -z2, -w2, -dot end
    local wa, wb
    if dot > 0.9995 then
        wa, wb = 1 - t, t
    else
        local th = math.acos(dot)
        local s = math.sin(th)
        wa, wb = math.sin((1 - t) * th) / s, math.sin(t * th) / s
    end
    local x, y, z, w = x1 * wa + x2 * wb, y1 * wa + y2 * wb, z1 * wa + z2 * wb, w1 * wa + w2 * wb
    local len = math.sqrt(x * x + y * y + z * z + w * w)
    if len < 1e-9 then return 0, 0, 0, 1 end
    return x / len, y / len, z / len, w / len
end

anim.sample1, anim.sample3, anim.sample_rotation = sample1, sample3, sample_rotation
-- }}}

-- {{{ Sequence names
-- "Stand - 2" -> "stand"; "Attack Slam" -> "attack slam"; "Stand Ready 3" -> "stand ready"
function anim.base_name(name)
    local words = {}
    for w in name:lower():gmatch("[%a]+") do words[#words + 1] = w end
    return table.concat(words, " ")
end
-- }}}

-- {{{ anim.rig
-- m: the parsed model; parts: { {geoset = 0-based index, layer = layer}, ... }
-- in the renderer's part order; skins: { 0-based geoset index, ... } in
-- skin slot order (assets/gpu.lua gives both)
function anim.rig(m, parts, skins)
    local rig = { m = m, sequences = m.sequences or {}, globals = m.global_sequences or {},
                  cache = {}, cached = 0 }
    -- nodes, parents before children
    local all, attach = {}, {}
    for _, n in ipairs(m.attachments or {}) do attach[n.id] = true end
    for _, list in ipairs({ m.bones, m.helpers, m.attachments or {}, m.lights or {}, m.particle_emitters or {},
                            m.particle_emitters2 or {}, m.ribbons or {}, m.events or {}, m.collision or {} }) do
        for _, n in ipairs(list) do all[n.id] = n end   -- (a repeated id: the last one)
    end
    local depth = {}
    local function depth_of(id, guard)
        if depth[id] then return depth[id] end
        local n = all[id]
        if not n or guard > 64 or n.parent == id or n.parent < 0 or not all[n.parent] then
            depth[id] = 0
        else
            depth[id] = depth_of(n.parent, guard + 1) + 1
        end
        return depth[id]
    end
    local order = {}
    for id in pairs(all) do depth_of(id, 0); order[#order + 1] = id end
    table.sort(order, function(a, b) if depth[a] ~= depth[b] then return depth[a] < depth[b] end return a < b end)
    local slot = {}
    rig.nodes = {}
    for i, id in ipairs(order) do
        local n = all[id]
        local p = m.pivots[id + 1] or { 0, 0, 0 }
        slot[id] = i
        rig.nodes[i] = { id = id, name = n.name, pivot = p, T = n.tracks.KGTR, R = n.tracks.KGRT, S = n.tracks.KGSC,
                         attach = attach[id] }
    end
    for i, id in ipairs(order) do
        local n = all[id]
        rig.nodes[i].parent = (depth[id] > 0) and slot[n.parent] or nil
    end
    rig.slot = slot
    rig.world = ffi.new("double[?]", math.max(1, #order) * 12)
    -- does anything follow a global sequence (then poses depend on the clock too)
    for _, nd in ipairs(rig.nodes) do
        for _, t in ipairs({ nd.T or false, nd.R or false, nd.S or false }) do
            if t and t.global then rig.global_nodes = true end
        end
    end
    -- the geoset animation for each geoset
    local geoa = {}
    for _, a in ipairs(m.geoset_animations or {}) do geoa[a.geoset] = a end
    -- parts' alphas, then the skins' groups
    rig.parts = {}
    for i, p in ipairs(parts) do
        rig.parts[i] = { geoa = geoa[p.geoset], layer = p.layer }
        local ga = geoa[p.geoset]
        local ka = ga and ga.tracks.KGAO
        local la = p.layer and p.layer.tracks and p.layer.tracks.KMTA
        if (ka and ka.global) or (la and la.global) then rig.global_parts = true end
    end
    rig.floats = #parts
    rig.skins = {}
    for s, gi in ipairs(skins) do
        local g = m.geosets[gi + 1]
        local groups, at = {}, 1
        for k, size in ipairs(g.group_sizes) do
            local members = {}
            for j = 0, size - 1 do
                local sl = slot[g.group_indices[at + j]]
                if sl then members[#members + 1] = sl end
            end
            groups[k] = members
            at = at + size
        end
        rig.skins[s] = { groups = groups, offset = rig.floats }
        rig.floats = rig.floats + #groups * 12
    end
    rig.out = ffi.new("float[?]", math.max(1, rig.floats))
    -- sequences by name
    rig.by_name = {}
    for i, sq in ipairs(rig.sequences) do
        local base = anim.base_name(sq.name)
        local list = rig.by_name[base]
        if not list then list = {}; rig.by_name[base] = list end
        list[#list + 1] = i
    end
    return rig
end
-- }}}

-- {{{ Posing
-- every node's world matrix (3 x 4, rows) at frame of sequence seq
local function pose_nodes(rig, first, last, frame, clock)
    local W = rig.world
    for i, nd in ipairs(rig.nodes) do
        local tx, ty, tz = sample3(nd.T, 0, 0, 0, rig, first, last, frame, clock)
        local qx, qy, qz, qw = sample_rotation(nd.R, rig, first, last, frame, clock)
        local sx, sy, sz = sample3(nd.S, 1, 1, 1, rig, first, last, frame, clock)
        -- some models store NaN keys (a WC2-style Great Hall's hidden
        -- roof): taken as no change
        if tx ~= tx or ty ~= ty or tz ~= tz then tx, ty, tz = 0, 0, 0 end
        if qx ~= qx or qy ~= qy or qz ~= qz or qw ~= qw then qx, qy, qz, qw = 0, 0, 0, 1 end
        if sx ~= sx or sy ~= sy or sz ~= sz then sx, sy, sz = 1, 1, 1 end
        local xx, yy, zz = qx * qx, qy * qy, qz * qz
        local xy, xz, yz = qx * qy, qx * qz, qy * qz
        local wx, wy, wz = qw * qx, qw * qy, qw * qz
        -- rotation times scaling
        local a00, a01, a02 = (1 - 2 * (yy + zz)) * sx, 2 * (xy - wz) * sy, 2 * (xz + wy) * sz
        local a10, a11, a12 = 2 * (xy + wz) * sx, (1 - 2 * (xx + zz)) * sy, 2 * (yz - wx) * sz
        local a20, a21, a22 = 2 * (xz - wy) * sx, 2 * (yz + wx) * sy, (1 - 2 * (xx + yy)) * sz
        -- about the pivot: p + t - A p
        local p = nd.pivot
        local px, py, pz = p[1], p[2], p[3]
        local b0 = px + tx - (a00 * px + a01 * py + a02 * pz)
        local b1 = py + ty - (a10 * px + a11 * py + a12 * pz)
        local b2 = pz + tz - (a20 * px + a21 * py + a22 * pz)
        local o = (i - 1) * 12
        if nd.parent then
            local q = (nd.parent - 1) * 12
            local p00, p01, p02, p03 = W[q], W[q + 1], W[q + 2], W[q + 3]
            local p10, p11, p12, p13 = W[q + 4], W[q + 5], W[q + 6], W[q + 7]
            local p20, p21, p22, p23 = W[q + 8], W[q + 9], W[q + 10], W[q + 11]
            W[o] = p00 * a00 + p01 * a10 + p02 * a20
            W[o + 1] = p00 * a01 + p01 * a11 + p02 * a21
            W[o + 2] = p00 * a02 + p01 * a12 + p02 * a22
            W[o + 3] = p00 * b0 + p01 * b1 + p02 * b2 + p03
            W[o + 4] = p10 * a00 + p11 * a10 + p12 * a20
            W[o + 5] = p10 * a01 + p11 * a11 + p12 * a21
            W[o + 6] = p10 * a02 + p11 * a12 + p12 * a22
            W[o + 7] = p10 * b0 + p11 * b1 + p12 * b2 + p13
            W[o + 8] = p20 * a00 + p21 * a10 + p22 * a20
            W[o + 9] = p20 * a01 + p21 * a11 + p22 * a21
            W[o + 10] = p20 * a02 + p21 * a12 + p22 * a22
            W[o + 11] = p20 * b0 + p21 * b1 + p22 * b2 + p23
        else
            W[o], W[o + 1], W[o + 2], W[o + 3] = a00, a01, a02, b0
            W[o + 4], W[o + 5], W[o + 6], W[o + 7] = a10, a11, a12, b1
            W[o + 8], W[o + 9], W[o + 10], W[o + 11] = a20, a21, a22, b2
        end
    end
end

-- The pose string for sequence index seq at frame (and clock, ms, for
-- global sequences): see render/models.h
function anim.pose_at(rig, seq, frame, clock)
    local sq = rig.sequences[seq]
    if not sq then return nil end
    local first, last = sq.start, sq.finish
    clock = clock or 0
    pose_nodes(rig, first, last, frame, clock)
    local W, out = rig.world, rig.out
    for i, p in ipairs(rig.parts) do
        local a = 1
        if p.geoa then a = sample1(p.geoa.tracks.KGAO, p.geoa.alpha, rig, first, last, frame, clock) end
        local layer = p.layer
        if layer then a = a * sample1(layer.tracks and layer.tracks.KMTA, layer.alpha or 1, rig, first, last, frame, clock) end
        out[i - 1] = (a == a) and a or 1
    end
    for _, sk in ipairs(rig.skins) do
        local o = sk.offset
        for _, members in ipairs(sk.groups) do
            local n = #members
            if n == 0 then
                for k = 0, 11 do out[o + k] = 0 end
                out[o], out[o + 5], out[o + 10] = 1, 1, 1
            else
                for k = 0, 11 do
                    local sum = 0
                    for j = 1, n do sum = sum + W[(members[j] - 1) * 12 + k] end
                    out[o + k] = sum / n
                end
            end
            o = o + 12
        end
    end
    return ffi.string(out, rig.floats * 4)
end
-- }}}

-- {{{ Playheads
function anim.state(seed)
    return { name = nil, seq = nil, t = 0, rate = 1, clock = (seed or math.random()) * 10000, done = false }
end

-- the sequence to play for name: one of its variants, by rarity
local function pick(rig, name)
    local list = rig.by_name[name]
    if not list then
        -- "stand" when only "Stand Ready" exists; anything starting with it
        for base, l in pairs(rig.by_name) do
            if base:sub(1, #name + 1) == name .. " " then list = l; break end
        end
    end
    if not list then return nil end
    if #list == 1 then return list[1] end
    local total = 0
    for _, i in ipairs(list) do total = total + 1 / (1 + math.max(0, rig.sequences[i].rarity or 0)) end
    local r = math.random() * total
    for _, i in ipairs(list) do
        r = r - 1 / (1 + math.max(0, rig.sequences[i].rarity or 0))
        if r <= 0 then return i end
    end
    return list[#list]
end

-- Play the sequence named name (if it isn't already): opts.rate (1 is
-- the model's own speed), opts.restart (from its start even if it's
-- already playing), opts.phase (0..1: start part way, so a crowd doesn't
-- move in step), opts.fallback (a name to play when the model has none).
-- Returns whether the model has such a sequence.
function anim.play(rig, st, name, opts)
    opts = opts or {}
    st.rate = opts.rate or 1
    if st.name == name and st.seq and not opts.restart then return true end
    local seq = pick(rig, name)
    if not seq and opts.fallback then
        return anim.play(rig, st, opts.fallback, { rate = opts.rate, restart = opts.restart, phase = opts.phase })
    end
    st.name, st.seq, st.done = name, seq, false
    st.t = 0
    if seq and opts.phase then
        local sq = rig.sequences[seq]
        st.t = (sq.finish - sq.start) * (opts.phase % 1)
    end
    return seq ~= nil
end

-- Move the playhead dt seconds on: a looping sequence starts over (as
-- another of its variants), one that doesn't holds its end
function anim.step(rig, st, dt)
    st.clock = st.clock + dt * 1000
    local sq = st.seq and rig.sequences[st.seq]
    if not sq then return end
    st.t = st.t + dt * 1000 * st.rate
    local len = sq.finish - sq.start
    if st.t >= len then
        if sq.non_looping then
            st.t, st.done = len, true
        elseif len > 0 then
            st.t = st.t % len
            local nxt = pick(rig, st.name)
            if nxt then st.seq = nxt end
        else
            st.t = 0
        end
    end
end

-- The playhead's pose (cached per model at anim.QUANTUM), or nil when
-- the model has nothing to play
function anim.pose(rig, st)
    local sq = st.seq and rig.sequences[st.seq]
    if not sq then return nil end
    local q = anim.QUANTUM
    local fq = math.floor(st.t / q + 0.5)
    local frame = math.min(sq.start + fq * q, sq.finish)
    local key = st.seq * 1000000 + fq
    local clock = 0
    if rig.global_nodes or rig.global_parts then
        clock = math.floor(st.clock / q) * q
        key = key .. ":" .. (clock % 3600000)
    end
    local v = rig.cache[key]
    if v then st.key = key return v end
    v = anim.pose_at(rig, st.seq, frame, clock)
    if rig.cached >= 4096 then rig.cache, rig.points, rig.cached = {}, {}, 0 end
    rig.cache[key] = v
    rig.cached = rig.cached + 1
    -- where the attachment points are in this pose (issue 538)
    local W, pts = rig.world, {}
    for i, nd in ipairs(rig.nodes) do
        if nd.attach then
            local o, p = (i - 1) * 12, nd.pivot
            pts[nd.id] = {
                W[o] * p[1] + W[o + 1] * p[2] + W[o + 2] * p[3] + W[o + 3],
                W[o + 4] * p[1] + W[o + 5] * p[2] + W[o + 6] * p[3] + W[o + 7],
                W[o + 8] * p[1] + W[o + 9] * p[2] + W[o + 10] * p[3] + W[o + 11],
            }
        end
    end
    rig.points = rig.points or {}
    rig.points[key] = pts
    st.key = key
    return v
end

-- Where attachment node id is in the playhead's last pose (model space),
-- or nil before it has one (issue 538)
function anim.attachment(rig, st, id)
    local pts = st and st.key and rig.points and rig.points[st.key]
    local p = pts and pts[id]
    if p and p[1] == p[1] and p[2] == p[2] and p[3] == p[3] then return p end
    return nil
end
-- }}}

-- {{{ anim.duration
-- A sequence's length in seconds (by name; nil if the model hasn't it)
function anim.duration(rig, name)
    local list = rig.by_name[name]
    if not list then return nil end
    local sq = rig.sequences[list[1]]
    return (sq.finish - sq.start) / 1000
end
-- }}}

return anim
