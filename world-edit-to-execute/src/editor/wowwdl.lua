--[[
A WoW Map's Far View from Its Tiles (Issue W10c)

The WDL (<map>.wdl) is the ground the client draws past its view of the
tiles: per tile 17 x 17 heights at the chunks' corners and 16 x 16 at
their middles (signed 16-bit yards), and 16 x 16 hole bits, one a chunk.
When the terrain tools change a tile's ground or holes, its far view is
made again from the tile (editor/wowterrain.lua's save does this), so
the far view follows the edits.

Layout (as the W client's reader takes it, 020-adt.c adt_wdl_read, and
W02a writes it, wowbuild/adt.lua): MVER; MAOF, 64 x 64 file offsets, row
by row north to south (ty * 64 + tx; the W client's horizon names the
same index [its tx, from world x] * 64 + [its ty]), 0 for no tile; each
to an MARE block (1090 bytes: 17 x 17 corners, then 16 x 16 middles,
rows south, columns east), then an MAHO block (16 rows of 16 bits, the
lowest bit the first column). A stock WDL may hold other blocks
(low-detail buildings) before MAOF; they are kept as they are.

    local wdl = require("editor.wowwdl")
    local bytes, why = wdl.patch(original, { tile, ... })   -- the tiles whose ground or holes changed
    local bytes, why = wdl.make(m)                          -- afresh from every tile of the map

patch changes what a tile's edits touched and nothing else:
  - a corner or middle height whose chunk's heights were edited (a
    point shared by chunks is edited in each, editor/wowterrain.lua);
  - a chunk's hole bit when its holes were edited: set when every one of
    its 16 holes is cut (the far view draws a chunk as one square, so a
    chunk with ground left in it shows from far away);
  - a tile the WDL hadn't: its MARE and MAHO added at the end, its MAOF
    entry set (a tile made by editor/wowtiles.lua, W10d, has every chunk
    edited, so a far view the WDL had for it is patched whole).
wdl.remove takes a tile's far view out (W10d: a tile taken off the map).
A tile listed in MAOF with no MAHO after its MARE gets one only when a
hole bit is to be set; MAOF's offsets then move along with the blocks
after it, each of which must be where an MARE starts, or the write is
refused.
]]

local bw = require("parsers.binwrite")
local adt = require("wowbuild.adt")
local wt = require("editor.wowterrain")

local wdl = {}

local I = wt.internal
local u32, u16, tag_at, put, le32 = I.u32, I.u16, I.tag_at, I.put, I.le32

local MARE_BYTES, MAHO_BYTES = 1090, 32

-- {{{ a tile's far view
-- each MARE value's source: { chunk 1-256, point 1-145 }
local SOURCES = {}
for r = 0, 16 do
    for c = 0, 16 do
        SOURCES[#SOURCES + 1] = { math.min(r, 15) * 16 + math.min(c, 15) + 1, (r == 16 and 8 or 0) * 17 + (c == 16 and 8 or 0) + 1 }
    end
end
for r = 0, 15 do
    for c = 0, 15 do SOURCES[#SOURCES + 1] = { r * 16 + c + 1, 4 * 17 + 4 + 1 } end
end
wdl.SOURCES = SOURCES

local function h16(v)
    v = math.floor(v + 0.5)
    if v < -32768 then v = -32768 elseif v > 32767 then v = 32767 end
    return v
end
local function i16(v) return bw.new():i16(v):done() end

local function value(t, n)
    local s = SOURCES[n]
    local c = t.chunks[s[1]]
    return h16(c.z + c.heights[s[2]])
end

local function all_holes(c) return c.holes % 65536 == 65535 end

-- the tile's MARE and MAHO blocks, whole
function wdl.blocks(t)
    local B = bw.new()
    for n = 1, #SOURCES do B:i16(value(t, n)) end
    local H = bw.new()
    for r = 0, 15 do
        local row = 0
        for c = 0, 15 do if all_holes(t.chunks[r * 16 + c + 1]) then row = row + 2 ^ c end end
        H:u16(row)
    end
    return adt.block("MARE", B:done()), adt.block("MAHO", H:done())
end
-- }}}

-- {{{ wdl.patch
function wdl.patch(original, tiles)
    local blocks, tail = wt.walk(original)
    if not blocks then return nil, tail end
    local maof
    for _, b in ipairs(blocks) do if b.tag == "MAOF" then maof = b break end end
    if not maof or maof.len < 8 + 4096 * 4 then return nil, "no tile list (MAOF) of 64 x 64 offsets" end
    local OF = maof.at + 8
    local s = original
    local appended, inserts = {}, {}
    for _, t in ipairs(tiles) do
        local i = t.ty * 64 + t.tx
        local o = u32(s, OF + i * 4)
        if o == 0 then
            local mare, maho = wdl.blocks(t)
            appended[#appended + 1] = { i = i, bytes = mare .. maho }
        else
            if o + 8 + MARE_BYTES > #s or tag_at(s, o) ~= "MARE" or u32(s, o + 4) < MARE_BYTES then
                return nil, string.format("tile %d, %d: MAOF points at byte %d, where no MARE of %d bytes is",
                    t.tx, t.ty, o, MARE_BYTES)
            end
            for n = 1, #SOURCES do
                local c = t.chunks[SOURCES[n][1]]
                if c.dirty and c.dirty.heights then s = put(s, o + 8 + (n - 1) * 2, i16(value(t, n))) end
            end
            local h = o + 8 + u32(s, o + 4)
            local has_maho = h + 8 + MAHO_BYTES <= #s and tag_at(s, h) == "MAHO" and u32(s, h + 4) >= MAHO_BYTES
            local rows, want_any = {}, false
            for r = 0, 15 do
                local row = has_maho and u16(s, h + 8 + r * 2) or 0
                for c = 0, 15 do
                    local ch = t.chunks[r * 16 + c + 1]
                    if ch.dirty and ch.dirty.holes then
                        local b = 2 ^ c
                        local on = math.floor(row / b) % 2 == 1
                        if all_holes(ch) and not on then row = row + b elseif not all_holes(ch) and on then row = row - b end
                    end
                end
                rows[r + 1] = row
                if row ~= 0 then want_any = true end
            end
            local H = bw.new()
            for r = 1, 16 do H:u16(rows[r]) end
            if has_maho then
                s = put(s, h + 8, H:done())
            elseif want_any then
                inserts[#inserts + 1] = { start = h, stop = h, data = adt.block("MAHO", H:done()), seq = i }
            end
        end
    end
    if #inserts > 0 then
        -- MAHO blocks put in: everything after them moves, and MAOF with it
        local out, moved = wt.splice(s, inserts)
        if not out then return nil, moved end
        for i = 0, 4095 do
            local o = u32(s, OF + i * 4)
            if o ~= 0 then
                if tag_at(s, o) ~= "MARE" then
                    return nil, string.format("MAOF's entry %d points at byte %d, where no MARE starts; "
                        .. "the blocks after it can't be moved", i, o)
                end
                out = put(out, moved(OF) + i * 4, le32(moved(o)))
            end
        end
        s = out
        OF = moved(OF)
    end
    for _, a in ipairs(appended) do
        local at = #s
        s = s .. a.bytes
        s = put(s, OF + a.i * 4, le32(at))
    end
    return s
end
-- }}}

-- {{{ wdl.remove: tiles taken off the map (W10d)
-- tiles: { { tx, ty } }. Each one's MARE (and the MAHO right after it)
-- taken out, its MAOF entry 0, the later entries moved along. Refused
-- when a block to take out isn't an MARE where MAOF says, or when
-- another entry points into it.
function wdl.remove(original, tiles)
    local blocks, tail = wt.walk(original)
    if not blocks then return nil, tail end
    local maof
    for _, b in ipairs(blocks) do if b.tag == "MAOF" then maof = b break end end
    if not maof or maof.len < 8 + 4096 * 4 then return nil, "no tile list (MAOF) of 64 x 64 offsets" end
    local OF = maof.at + 8
    local s = original
    local cut, regions = {}, {}
    for _, t in ipairs(tiles) do
        local i = t.ty * 64 + t.tx
        local o = u32(s, OF + i * 4)
        if o ~= 0 then
            if o + 8 > #s or tag_at(s, o) ~= "MARE" then
                return nil, string.format("tile %d, %d: MAOF points at byte %d, where no MARE is", t.tx, t.ty, o)
            end
            local stop = o + 8 + u32(s, o + 4)
            if stop + 8 <= #s and tag_at(s, stop) == "MAHO" then stop = stop + 8 + u32(s, stop + 4) end
            if stop > #s then return nil, string.format("tile %d, %d: its far view runs past the file's end", t.tx, t.ty) end
            cut[i] = true
            regions[#regions + 1] = { start = o, stop = stop, data = "", seq = i }
        end
    end
    if #regions == 0 then return s end
    for i = 0, 4095 do
        local o = u32(s, OF + i * 4)
        if o ~= 0 and not cut[i] then
            for _, g in ipairs(regions) do
                if o >= g.start and o < g.stop then
                    return nil, string.format("MAOF's entry %d points into the far view being taken out (byte %d)", i, o)
                end
            end
        end
    end
    local out, moved = wt.splice(s, regions)
    if not out then return nil, moved end
    local NOF = moved(OF)
    for i = 0, 4095 do
        local o = u32(s, OF + i * 4)
        if cut[i] then out = put(out, NOF + i * 4, le32(0))
        elseif o ~= 0 then out = put(out, NOF + i * 4, le32(moved(o))) end
    end
    return out
end
-- }}}

-- {{{ wdl.make: afresh, from every tile (W02a's layout)
function wdl.make(m)
    local ok, bad = m:read_all()
    if not ok then return nil, table.concat(bad, "; ") end
    local mver = adt.block("MVER", bw.new():u32(adt.VERSION):done())
    local at = #mver + 8 + 4096 * 4
    local offsets, parts = {}, {}
    for _, e in ipairs(m.tiles) do
        local t = m.read_tiles[e.tx .. "_" .. e.ty]
        local mare, maho = wdl.blocks(t)
        offsets[e.ty * 64 + e.tx] = at
        parts[#parts + 1] = mare .. maho
        at = at + #mare + #maho
    end
    local O = bw.new()
    for i = 0, 4095 do O:u32(offsets[i] or 0) end
    return mver .. adt.block("MAOF", O:done()) .. table.concat(parts)
end
-- }}}

return wdl
