--[[
adt.lua - WoW 3.3.5a ground files as bytes: ADT, WDT, WDL (issue W02a)

Writes what wowbuild.terrain decided. Every block is a four-letter tag
stored reversed ("MVER" is written "REVM"), its size (u32, not counting
these 8 bytes), then its data; numbers are little-endian (parsers.binwrite).

ADT (<map>_<tx>_<ty>.adt; tx west to east, ty north to south), in order:
  MVER  18
  MHDR  64 bytes: flags 0, then where each block's tag is, counted from the
        start of MHDR's data (byte 20): MCIN MTEX MMDX MMID MWMO MWID MDDF
        MODF MFBO(0) MH2O(0 when the tile has no water) MTXF(0), 4 unused
  MCIN  256 x 16: each MCNK's file offset and size (with its 8-byte head)
  MTEX  the tile's texture paths, each ended by a zero byte
  MMDX  the models placed on the tile (M2 paths), each ended by a zero byte
  MMID  where each MMDX name starts (u32 each)
  MWMO  the buildings placed on the tile (WMO paths), the same way
  MWID  where each MWMO name starts
  MDDF  36 bytes a model placement: name number (into MMID), unique id,
        position (3 floats), rotation (3 floats, degrees), scale (u16,
        1024 = 1.0), flags (u16, 0)
  MODF  64 bytes a building placement: name number (into MWID), unique id,
        position, rotation, bounding box (lowest corner, then highest, 6
        floats), flags (u16, 0), doodad set (u16, 0), name set (u16, 0),
        unused (u16)
        Positions are in placement space, measured from the map's
        north-west corner: (17066.67 - world y, world z, 17066.67 - world x).
        All six are empty on a tile with nothing placed (W02b: placements)
  MH2O  water, when any chunk has some
  MCNK x 256, row by row (index y north to south, index x west to east)

MCNK: a 128-byte header, then MCVT (145 heights), MCNR (145 x 3 normal
bytes and 13 bytes of padding, counted in its size, as Noggit writes it),
MCLY (16 bytes a layer: texture number, flags 0x100 for a layer with a
blend map, its offset in MCAL, ground effect 0), MCRF (which of the tile's
MDDF entries, then which MODF entries, stand in this chunk: u32 numbers,
counted at header offsets 16 and 56), MCAL (one
4096-byte map a layer above the first, uncompressed: the WDT says 8-bit
maps), MCSE (empty), MCLQ (empty; 3.3.5a keeps water in MH2O). Header
offsets count from the MCNK tag; MCAL's and MCLQ's sizes there count their
8-byte heads, as the original's files do. Header fields written:
  0 flags 0x8000 (the blend maps' last row and column are real)
  4 index x   8 index y   12 layers   16 model references (MCRF)
  20 MCVT  24 MCNR  28 MCLY  32 MCRF  36 MCAL  40 MCAL size  44 MCSH 0  48 0
  52 area 0 (an AreaTable row is W02c's)   56 building references (MCRF)   60 holes 0
  64 the low-quality texture map (8 x 8 cells, 2 bits each: the layer
     covering most of the cell; row by row, lowest bits first)
  80 0  84 0  88 MCSE  92 0  96 MCLQ  100 8
  104 position: world x (north), y (west) of the chunk's north-west corner,
      base height z
  116 MCCV 0 (no colour tints)  120 0  124 0

MH2O: 256 heads of 12 bytes (offset of the chunk's layer, layer count 0 or
1, offset of its attributes; offsets from MH2O's data), then per wet chunk
its layer (24 bytes: LiquidType u16, vertex format u16 = 0, lowest and
highest height, first column, first row, width, height (u8 each), offset of
the which-cells bitmap (0: every cell of the rectangle), offset of the
vertices), its attributes (fishable cells u64, deep cells u64 = 0), the
bitmap, then (w+1)(h+1) heights (float) and as many depth bytes.

WDT (<map>.wdt): MVER 18; MPHD 32 bytes, flags 0x4 (8-bit blend maps);
MAIN 64 x 64 x 8 bytes, row by row (ty * 64 + tx), flags 1 where a tile is
written; MWMO empty (a ground map, not a single building).

WDL (<map>.wdl, the far-off ground): MVER 18; MAOF 64 x 64 file offsets
(ty * 64 + tx, 0 where no tile); per tile MARE (17 x 17 chunk-corner heights
then 16 x 16 chunk-centre heights, signed 16-bit yards, rows south and
columns east) and MAHO (16 rows of 16 hole bits, all 0).

    local adt = require("wowbuild.adt")
    local bytes = adt.tile_bytes(tile, placed)  -- tile: wowbuild.terrain's Job:tile;
                                                -- placed: wowbuild.placements' tile, or nil
    local wdt = adt.wdt_bytes({ { tx = 32, ty = 32 }, ... })
    local wdl = adt.wdl_bytes(job)              -- job: wowbuild.terrain's
]]

local bw = require("parsers.binwrite")

local adt = {}

adt.VERSION = 18
adt.MPHD_BIG_ALPHA = 0x4
adt.MCNK_NO_FIX_ALPHA = 0x8000
adt.MCLY_USE_ALPHA = 0x100

-- {{{ block: a tag, its size, its data
local function block(tag, data)
    data = data or ""
    return tag:reverse() .. bw.new():u32(#data):done() .. data
end
adt.block = block
-- }}}

-- {{{ mcnk
-- c: the chunk; refs: its MCRF references { d = {MDDF numbers}, w = {MODF numbers} }, or nil
local function mcnk(c, refs)
    local n = #c.layers
    local B = bw.new()
    for i = 1, 145 do B:f32(c.heights[i]) end
    local mcvt = block("MCVT", B:done())
    local mcnr = block("MCNR", c.normals .. string.rep("\0", 13))
    B = bw.new()
    for l = 1, n do
        local layer = c.layers[l]
        B:u32(layer.tex):u32(l > 1 and adt.MCLY_USE_ALPHA or 0):u32(l > 1 and (l - 2) * 4096 or 0):u32(0)
    end
    local mcly = block("MCLY", B:done())
    local nd, nw = refs and #refs.d or 0, refs and #refs.w or 0
    B = bw.new()
    if refs then
        for _, n in ipairs(refs.d) do B:u32(n) end
        for _, n in ipairs(refs.w) do B:u32(n) end
    end
    local mcrf = block("MCRF", B:done())
    local alphas = {}
    for l = 2, n do alphas[#alphas + 1] = c.layers[l].alpha end
    local mcal = block("MCAL", table.concat(alphas))
    local mcse = block("MCSE", "")
    local mclq = block("MCLQ", "")

    local at = 8 + 128
    local o = {}
    for _, part in ipairs({ { "mcvt", mcvt }, { "mcnr", mcnr }, { "mcly", mcly }, { "mcrf", mcrf },
                            { "mcal", mcal }, { "mcse", mcse }, { "mclq", mclq } }) do
        o[part[1]] = at
        at = at + #part[2]
    end
    local H = bw.new()
    H:u32(adt.MCNK_NO_FIX_ALPHA):u32(c.ix):u32(c.iy):u32(n):u32(nd)
    H:u32(o.mcvt):u32(o.mcnr):u32(o.mcly):u32(o.mcrf):u32(o.mcal):u32(#mcal)
    H:u32(0):u32(0)                 -- no shadow map
    H:u32(0):u32(nw)                -- area, building refs
    H:u16(0):u16(0)                 -- holes, padding
    H:str(c.lowres)
    H:u32(0):u32(0)                 -- predTex, noEffectDoodad
    H:u32(o.mcse):u32(0)
    H:u32(o.mclq):u32(#mclq)
    H:f32(c.x):f32(c.y):f32(c.z)
    H:u32(0):u32(0):u32(0)          -- MCCV, MCLV, unused
    local head = H:done()
    assert(#head == 128, "MCNK header is " .. #head .. " bytes")
    return block("MCNK", head .. mcvt .. mcnr .. mcly .. mcrf .. mcal .. mcse .. mclq)
end
-- }}}

-- {{{ mh2o: the tile's water, or nil
local function pad4(s) return s .. string.rep("\0", (4 - #s % 4) % 4) end
local function mh2o(tile)
    local any = false
    for k = 0, 255 do if tile.chunks[k].liquid then any = true break end end
    if not any then return nil end
    local heads, body = {}, {}
    local at = 256 * 12
    for k = 0, 255 do
        local q = tile.chunks[k].liquid
        if not q then
            heads[#heads + 1] = bw.new():u32(0):u32(0):u32(0):done()
        else
            local inst_at, attr_at = at, at + 24
            local after = at + 24 + 16
            -- which cells of the rectangle are wet; none needed when all are
            local all, bits = true, {}
            for r = 0, q.h - 1 do
                for c = 0, q.w - 1 do
                    local w = q.wet[q.row + r][q.col + c]
                    bits[#bits + 1] = w
                    if w == 0 then all = false end
                end
            end
            local bitmap = ""
            if not all then
                local bytes = {}
                for b = 0, #bits - 1, 8 do
                    local v = 0
                    for k2 = 0, 7 do v = v + (bits[b + k2 + 1] or 0) * 2 ^ k2 end
                    bytes[#bytes + 1] = string.char(v)
                end
                bitmap = pad4(table.concat(bytes))
            end
            local bitmap_at = all and 0 or after
            local vert_at = after + #bitmap
            local V = bw.new()
            for i = 1, #q.heights do V:f32(q.heights[i]) end
            for i = 1, #q.depths do V:u8(q.depths[i]) end
            local verts = pad4(V:done())
            local fish_lo, fish_hi = 0, 0
            for r = 0, 7 do
                for c = 0, 7 do
                    if q.wet[r][c] == 1 then
                        local bit_n = r * 8 + c
                        if bit_n < 32 then fish_lo = fish_lo + 2 ^ bit_n else fish_hi = fish_hi + 2 ^ (bit_n - 32) end
                    end
                end
            end
            local inst = bw.new():u16(q.kind):u16(0):f32(q.lo):f32(q.hi)
                :u8(q.col):u8(q.row):u8(q.w):u8(q.h):u32(bitmap_at):u32(vert_at):done()
            local attr = bw.new():u32(fish_lo):u32(fish_hi):u32(0):u32(0):done()
            body[#body + 1] = inst .. attr .. bitmap .. verts
            heads[#heads + 1] = bw.new():u32(inst_at):u32(1):u32(attr_at):done()
            at = vert_at + #verts
        end
    end
    return block("MH2O", table.concat(heads) .. table.concat(body))
end
-- }}}

-- {{{ placement blocks: names (MMDX/MWMO) and where each starts (MMID/MWID)
local function name_blocks(text_tag, id_tag, names)
    local parts, I, at = {}, bw.new(), 0
    for _, p in ipairs(names or {}) do
        I:u32(at)
        parts[#parts + 1] = p .. "\0"
        at = at + #p + 1
    end
    return block(text_tag, table.concat(parts)), block(id_tag, I:done())
end

local function mddf(list)
    local B = bw.new()
    for _, d in ipairs(list or {}) do
        B:u32(d.name):u32(d.uid)
        B:f32(d.pos[1]):f32(d.pos[2]):f32(d.pos[3])
        B:f32(d.rot[1]):f32(d.rot[2]):f32(d.rot[3])
        B:u16(d.scale):u16(d.flags or 0)
    end
    return block("MDDF", B:done())
end

local function modf(list)
    local B = bw.new()
    for _, w in ipairs(list or {}) do
        B:u32(w.name):u32(w.uid)
        B:f32(w.pos[1]):f32(w.pos[2]):f32(w.pos[3])
        B:f32(w.rot[1]):f32(w.rot[2]):f32(w.rot[3])
        B:f32(w.lo[1]):f32(w.lo[2]):f32(w.lo[3])
        B:f32(w.hi[1]):f32(w.hi[2]):f32(w.hi[3])
        B:u16(w.flags or 0):u16(w.doodad_set or 0):u16(w.name_set or 0):u16(0)
    end
    return block("MODF", B:done())
end
-- }}}

-- {{{ adt.tile_bytes
-- tile: wowbuild.terrain's; placed: wowbuild.placements' tile (models,
-- doodads, buildings, places, refs[chunk]), or nil for a bare tile
function adt.tile_bytes(tile, placed)
    local mver = block("MVER", bw.new():u32(adt.VERSION):done())
    local names = {}
    for _, p in ipairs(tile.textures) do names[#names + 1] = p .. "\0" end
    local mtex = block("MTEX", table.concat(names))
    placed = placed or {}
    local mmdx, mmid = name_blocks("MMDX", "MMID", placed.models)
    local mwmo, mwid = name_blocks("MWMO", "MWID", placed.buildings)
    local empties = { mmdx, mmid, mwmo, mwid, mddf(placed.doodads), modf(placed.places) }
    local water = mh2o(tile)
    local chunks = {}
    for k = 0, 255 do chunks[k + 1] = mcnk(tile.chunks[k], placed.refs and placed.refs[k]) end

    local HDR_DATA = #mver + 8                     -- where MHDR's data starts
    local at = #mver + 8 + 64                      -- after MHDR
    local mcin_at = at; at = at + 8 + 4096
    local mtex_at = at; at = at + #mtex
    local e = {}
    for i = 1, 6 do e[i] = at; at = at + #empties[i] end
    local mh2o_at = water and at or nil
    if water then at = at + #water end
    local C = bw.new()
    for k = 1, 256 do
        C:u32(at):u32(#chunks[k]):u32(0):u32(0)
        at = at + #chunks[k]
    end
    local mcin = block("MCIN", C:done())
    local H = bw.new():u32(0)
    for _, off in ipairs({ mcin_at, mtex_at, e[1], e[2], e[3], e[4], e[5], e[6] }) do H:u32(off - HDR_DATA) end
    H:u32(0)                                        -- MFBO
    H:u32(mh2o_at and (mh2o_at - HDR_DATA) or 0)
    H:u32(0)                                        -- MTXF
    H:u32(0):u32(0):u32(0):u32(0)
    local mhdr = block("MHDR", H:done())
    return table.concat({ mver, mhdr, mcin, mtex, table.concat(empties), water or "", table.concat(chunks) })
end
-- }}}

-- {{{ adt.wdt_bytes
-- tiles: { tx, ty } each
function adt.wdt_bytes(tiles)
    local have = {}
    for _, t in ipairs(tiles) do have[t.ty * 64 + t.tx] = true end
    local M = bw.new()
    for i = 0, 4095 do M:u32(have[i] and 1 or 0):u32(0) end
    local P = bw.new():u32(adt.MPHD_BIG_ALPHA)
    for _ = 1, 7 do P:u32(0) end
    return block("MVER", bw.new():u32(adt.VERSION):done()) .. block("MPHD", P:done())
        .. block("MAIN", M:done()) .. block("MWMO", "")
end
-- }}}

-- {{{ adt.wdl_bytes
-- job: wowbuild.terrain's (its height grid gives the chunk corners)
function adt.wdl_bytes(job)
    local L = job.layout
    local mver = block("MVER", bw.new():u32(adt.VERSION):done())
    local at = #mver + 8 + 4096 * 4
    local offsets, parts = {}, {}
    local function h16(v)
        v = math.floor(v + 0.5)
        if v < -32768 then v = -32768 elseif v > 32767 then v = 32767 end
        return v
    end
    local function H(r, c)
        if r > job.rows - 1 then r = job.rows - 1 end
        if c > job.cols - 1 then c = job.cols - 1 end
        return job.gh[r * job.cols + c]
    end
    for _, t in ipairs(L:tiles()) do
        local R0, C0 = t.by * 128, t.bx * 128
        local B = bw.new()
        for r = 0, 16 do for c = 0, 16 do B:i16(h16(H(R0 + r * 8, C0 + c * 8))) end end
        for r = 0, 15 do for c = 0, 15 do B:i16(h16(H(R0 + r * 8 + 4, C0 + c * 8 + 4))) end end
        local mare = block("MARE", B:done())
        local maho = block("MAHO", string.rep("\0", 32))
        offsets[t.ty * 64 + t.tx] = at
        parts[#parts + 1] = mare .. maho
        at = at + #mare + #maho
    end
    local O = bw.new()
    for i = 0, 4095 do O:u32(offsets[i] or 0) end
    return mver .. block("MAOF", O:done()) .. table.concat(parts)
end
-- }}}

return adt
