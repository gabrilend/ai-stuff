--[[
JPEG Decoder (Issue 522a)

Baseline and progressive JPEG (SOF0, SOF1, SOF2; 8-bit samples):
Huffman coding, any number of components with any sampling factors,
restart intervals, spectral selection and successive approximation.
Lossless and arithmetic-coded JPEGs are refused with a message.
Subsampled colour is upsampled by repeating samples (libjpeg smooths it,
so edges of subsampled colour differ slightly from other decoders).

Written for Blizzard's BLP1 textures, whose image data is a JPEG with four
components holding B, G, R and A directly: no colour transform. So:

    components 1  grey
    components 3  YCbCr (JFIF), converted to RGB
    components 4  stored values, as they are (BLP: B, G, R, A)

The integer-free float IDCT is the plain separable one (precomputed
cosines); textures are small and this runs once per texture.

    local jpeg = require("parsers.jpeg")
    local img = jpeg.decode(bytes)
    -- img.width, img.height, img.components,
    -- img.pixels (ffi uint8_t[w*h*components], row by row, top first)
]]

local ffi = require("ffi")
local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local jpeg = {}

-- zigzag order: position k of the coded coefficients -> natural index
local ZIGZAG = {
    0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5,
    12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63,
}

-- {{{ IDCT tables
local COS = ffi.new("double[64]")   -- COS[x*8+u] = C(u) cos((2x+1)u pi / 16) / 2
for x = 0, 7 do
    for u = 0, 7 do
        local c = u == 0 and 1 / math.sqrt(2) or 1
        COS[x * 8 + u] = c * math.cos((2 * x + 1) * u * math.pi / 16) / 2
    end
end
local tmp = ffi.new("double[64]")

-- in: 64 dequantized coefficients (natural order); out: 64 samples 0..255
local function idct(coef, out, out_off)
    -- rows: tmp[y*8+x] = sum_u coef[y*8+u] * COS[x*8+u]
    for y = 0, 7 do
        local r = y * 8
        for x = 0, 7 do
            local s, cx = 0, x * 8
            for u = 0, 7 do s = s + coef[r + u] * COS[cx + u] end
            tmp[r + x] = s
        end
    end
    -- columns
    for x = 0, 7 do
        for y = 0, 7 do
            local s, cy = 0, y * 8
            for v = 0, 7 do s = s + tmp[v * 8 + x] * COS[cy + v] end
            local val = math.floor(s + 128.5)
            if val < 0 then val = 0 elseif val > 255 then val = 255 end
            out[out_off + y * 8 + x] = val
        end
    end
end
-- }}}

-- {{{ Huffman tables
-- A table maps (length, code) -> symbol through the canonical
-- mincode/maxcode/valptr arrays of the JPEG spec (F.2.2.3)
local function build_huffman(counts, symbols)
    local h = { maxcode = {}, valptr = {}, mincode = {}, symbols = symbols }
    local code, k = 0, 0
    for len = 1, 16 do
        local n = counts[len]
        if n > 0 then
            h.valptr[len] = k
            h.mincode[len] = code
            code = code + n
            k = k + n
            h.maxcode[len] = code - 1
        else
            h.maxcode[len] = -1
        end
        code = code * 2
    end
    return h
end
-- }}}

-- {{{ jpeg.decode
function jpeg.decode(data)
    local n = #data
    local buf = ffi.new("uint8_t[?]", n + 2)
    ffi.copy(buf, data, n)
    local pos = 0

    local function u8() local v = buf[pos]; pos = pos + 1; return v end
    local function u16() local v = buf[pos] * 256 + buf[pos + 1]; pos = pos + 2; return v end

    local qt = {}          -- id -> double[64] (natural order)
    local ht = { [0] = {}, [1] = {} }   -- class (0 DC, 1 AC) -> id -> table
    local frame, restart = nil, 0

    if u16() ~= 0xFFD8 then error("not a JPEG (no SOI)") end

    local img
    while pos < n do
        -- next marker
        local b = u8()
        if b ~= 0xFF then error(string.format("JPEG: expected a marker at %d", pos - 1)) end
        local m = u8()
        while m == 0xFF do m = u8() end
        if m == 0xD9 then break end                      -- EOI
        if m >= 0xD0 and m <= 0xD7 then goto continue end  -- stray RST
        do
            local len = u16()
            local seg_end = pos + len - 2
            if m == 0xDB then                             -- DQT
                while pos < seg_end do
                    local pq = u8()
                    local prec, id = rshift(pq, 4), band(pq, 15)
                    local t = ffi.new("double[64]")
                    for k = 1, 64 do
                        t[ZIGZAG[k]] = prec == 0 and u8() or u16()
                    end
                    qt[id] = t
                end
            elseif m == 0xC4 then                         -- DHT
                while pos < seg_end do
                    local tc = u8()
                    local class, id = rshift(tc, 4), band(tc, 15)
                    local counts, total = {}, 0
                    for i = 1, 16 do counts[i] = u8(); total = total + counts[i] end
                    local symbols = {}
                    for i = 0, total - 1 do symbols[i] = u8() end
                    ht[class][id] = build_huffman(counts, symbols)
                end
            elseif m == 0xC0 or m == 0xC1 or m == 0xC2 then   -- SOF0 / SOF1 / SOF2
                local precision = u8()
                if precision ~= 8 then error("JPEG: " .. precision .. "-bit samples not supported") end
                local height, width = u16(), u16()
                local nc = u8()
                frame = { width = width, height = height, comps = {}, progressive = m == 0xC2 }
                local hmax, vmax = 1, 1
                for i = 1, nc do
                    local c = { id = u8() }
                    local s = u8()
                    c.h, c.v = rshift(s, 4), band(s, 15)
                    c.tq = u8()
                    hmax, vmax = math.max(hmax, c.h), math.max(vmax, c.v)
                    frame.comps[i] = c
                end
                frame.hmax, frame.vmax = hmax, vmax
                frame.mcux = math.ceil(width / (8 * hmax))
                frame.mcuy = math.ceil(height / (8 * vmax))
                for _, c in ipairs(frame.comps) do
                    c.bw = frame.mcux * c.h         -- blocks across, padded to whole MCUs
                    c.bh = frame.mcuy * c.v
                    c.stride = c.bw * 8
                    c.coefs = ffi.new("int32_t[?]", c.bw * c.bh * 64)   -- zigzag-free natural order
                end
            elseif m == 0xC3 or (m >= 0xC5 and m <= 0xCF and m ~= 0xC8 and m ~= 0xCC) then
                error(string.format("JPEG: SOF%d (lossless/arithmetic) not supported", m - 0xC0))
            elseif m == 0xDD then                         -- DRI
                restart = u16()
            elseif m == 0xDA then                         -- SOS: the scan
                if not frame then error("JPEG: scan before frame") end
                local ns = u8()
                local scomps = {}
                for i = 1, ns do
                    local cid, tables = u8(), u8()
                    for _, c in ipairs(frame.comps) do
                        if c.id == cid then
                            c.td, c.ta = rshift(tables, 4), band(tables, 15)
                            scomps[i] = c
                        end
                    end
                end
                local ss, se = u8(), u8()
                local a = u8()
                pos = seg_end
                pos = jpeg._scan(buf, n, pos, frame, scomps, ht, restart,
                                 { ss = ss, se = se, ah = rshift(a, 4), al = band(a, 15) })
                goto continue
            end
            pos = seg_end
        end
        ::continue::
    end
    if not frame then error("JPEG: no frame") end

    -- {{{ assemble: dequantize and IDCT every block, upsample each
    -- component to full size, then colour
    local coef, block = ffi.new("double[64]"), ffi.new("uint8_t[64]")
    for _, c in ipairs(frame.comps) do
        local q = qt[c.tq] or error("JPEG: no quantization table " .. tostring(c.tq))
        c.samples = ffi.new("uint8_t[?]", c.bw * 8 * c.bh * 8)
        for by = 0, c.bh - 1 do
            for bx = 0, c.bw - 1 do
                local b0 = (by * c.bw + bx) * 64
                for k = 0, 63 do coef[k] = c.coefs[b0 + k] * q[k] end
                idct(coef, block, 0)
                local base = by * 8 * c.stride + bx * 8
                for y = 0, 7 do
                    local o = base + y * c.stride
                    for x = 0, 7 do c.samples[o + x] = block[y * 8 + x] end
                end
            end
        end
        c.coefs = nil
    end
    local w, h, nc = frame.width, frame.height, #frame.comps
    local out = ffi.new("uint8_t[?]", w * h * nc)
    for ci, c in ipairs(frame.comps) do
        local sx, sy = frame.hmax / c.h, frame.vmax / c.v
        local src, stride = c.samples, c.stride
        for y = 0, h - 1 do
            local row = math.floor(y / sy) * stride
            local o = y * w * nc + ci - 1
            for x = 0, w - 1 do
                out[o + x * nc] = src[row + math.floor(x / sx)]
            end
        end
    end
    if nc == 3 then
        for i = 0, w * h - 1 do
            local o = i * 3
            local Y, cb, cr = out[o], out[o + 1] - 128, out[o + 2] - 128
            local r = Y + 1.402 * cr
            local g = Y - 0.344136 * cb - 0.714136 * cr
            local b2 = Y + 1.772 * cb
            out[o] = r < 0 and 0 or (r > 255 and 255 or r + 0.5)
            out[o + 1] = g < 0 and 0 or (g > 255 and 255 or g + 0.5)
            out[o + 2] = b2 < 0 and 0 or (b2 > 255 and 255 or b2 + 0.5)
        end
    end
    -- }}}
    return { width = w, height = h, components = nc, pixels = out }
end
-- }}}

-- {{{ jpeg._scan
-- Decode one scan into the components' coefficients (baseline, or one
-- progressive pass: sp = { ss, se, ah, al }); returns the position after
-- the entropy-coded data
function jpeg._scan(buf, n, pos, frame, scomps, ht, restart, sp)
    local bitbuf, bitcnt = 0, 0
    local marker_hit = false

    local function fill()
        -- one byte into the bit buffer, unstuffing FF00; a marker stops input
        local b = 0
        if not marker_hit then
            b = buf[pos]
            if b == 0xFF then
                local b2 = buf[pos + 1]
                if b2 == 0 then
                    pos = pos + 2
                else
                    marker_hit = true
                    b = 0
                end
            else
                pos = pos + 1
            end
        end
        bitbuf = bor(lshift(band(bitbuf, 0xFFFFFF), 8), b)
        bitcnt = bitcnt + 8
    end
    local function getbit()
        if bitcnt == 0 then fill() end
        bitcnt = bitcnt - 1
        return band(rshift(bitbuf, bitcnt), 1)
    end
    local function getbits(k)
        local v = 0
        for _ = 1, k do v = v * 2 + getbit() end
        return v
    end
    local function decode(hf)
        if not hf then error("JPEG: missing Huffman table") end
        local code = getbit()
        for len = 1, 16 do
            local mx = hf.maxcode[len]
            if mx >= 0 and code <= mx then
                return hf.symbols[hf.valptr[len] + code - hf.mincode[len]]
            end
            code = code * 2 + getbit()
        end
        error("JPEG: bad Huffman code")
    end
    local function extend(v, t)
        if t == 0 then return 0 end
        if v < lshift(1, t - 1) then return v - lshift(1, t) + 1 end
        return v
    end

    local ss, se, ah, al = sp.ss, sp.se, sp.ah, sp.al
    local progressive = frame.progressive
    local pred = {}
    for i = 1, #scomps do pred[i] = 0 end
    local eobrun = 0

    -- {{{ one block, by the kind of pass
    local function block_baseline(c, ci, co)
        local t = decode(ht[0][c.td])
        pred[ci] = pred[ci] + extend(getbits(t), t)
        co[0] = pred[ci]
        local ac = ht[1][c.ta]
        local k = 1
        while k < 64 do
            local rs = decode(ac)
            local r, s = rshift(rs, 4), band(rs, 15)
            if s == 0 then
                if r ~= 15 then break end
                k = k + 16
            else
                k = k + r
                if k > 63 then break end
                co[ZIGZAG[k + 1]] = extend(getbits(s), s)
                k = k + 1
            end
        end
    end

    local function block_dc_first(c, ci, co)
        local t = decode(ht[0][c.td])
        pred[ci] = pred[ci] + extend(getbits(t), t)
        co[0] = lshift(pred[ci], al)
    end

    local function block_dc_refine(c, ci, co)
        if getbit() == 1 then co[0] = bor(co[0], lshift(1, al)) end
    end

    local function block_ac_first(c, ci, co)
        if eobrun > 0 then eobrun = eobrun - 1 return end
        local ac = ht[1][c.ta]
        local k = ss
        while k <= se do
            local rs = decode(ac)
            local r, s = rshift(rs, 4), band(rs, 15)
            if s == 0 then
                if r < 15 then
                    eobrun = lshift(1, r) - 1
                    if r > 0 then eobrun = eobrun + getbits(r) end
                    break
                end
                k = k + 16
            else
                k = k + r
                co[ZIGZAG[k + 1]] = extend(getbits(s), s) * lshift(1, al)
                k = k + 1
            end
        end
    end

    local function block_ac_refine(c, ci, co)
        local p1, m1 = lshift(1, al), -lshift(1, al)
        local k = ss
        local function refine(z)
            if getbit() == 1 and band(co[z], p1) == 0 then
                co[z] = co[z] + (co[z] >= 0 and p1 or m1)
            end
        end
        if eobrun <= 0 then
            local ac = ht[1][c.ta]
            while k <= se do
                local rs = decode(ac)
                local r, s = rshift(rs, 4), band(rs, 15)
                local value = 0
                if s == 0 then
                    if r < 15 then
                        eobrun = lshift(1, r)
                        if r > 0 then eobrun = eobrun + getbits(r) end
                        break
                    end
                else
                    value = getbit() == 1 and p1 or m1
                end
                -- skip r zero coefficients (refining the nonzero ones met),
                -- then place the new value
                while k <= se do
                    local z = ZIGZAG[k + 1]
                    if co[z] ~= 0 then
                        refine(z)
                    else
                        if r == 0 then
                            if value ~= 0 then co[z] = value end
                            k = k + 1
                            break
                        end
                        r = r - 1
                    end
                    k = k + 1
                end
            end
        end
        if eobrun > 0 then
            while k <= se do
                local z = ZIGZAG[k + 1]
                if co[z] ~= 0 then refine(z) end
                k = k + 1
            end
            eobrun = eobrun - 1
        end
    end

    local block_fn
    if not progressive then block_fn = block_baseline
    elseif ss == 0 then block_fn = ah == 0 and block_dc_first or block_dc_refine
    else block_fn = ah == 0 and block_ac_first or block_ac_refine end
    -- }}}

    local function at(c, bx, by) return c.coefs + (by * c.bw + bx) * 64 end

    local function reset()
        bitbuf, bitcnt, eobrun = 0, 0, 0
        for i = 1, #scomps do pred[i] = 0 end
        if marker_hit then
            marker_hit = false
            while pos < n and buf[pos] == 0xFF do pos = pos + 1 end
            local mk = buf[pos]
            if mk and mk >= 0xD0 and mk <= 0xD7 then pos = pos + 1 end
        end
    end

    local mcus = 0
    if #scomps == 1 then
        -- non-interleaved: blocks cover the component itself, unpadded
        local c = scomps[1]
        local bw = math.ceil(math.ceil(frame.width * c.h / frame.hmax) / 8)
        local bh = math.ceil(math.ceil(frame.height * c.v / frame.vmax) / 8)
        for by = 0, bh - 1 do
            for bx = 0, bw - 1 do
                if restart > 0 and mcus > 0 and mcus % restart == 0 then reset() end
                block_fn(c, 1, at(c, bx, by))
                mcus = mcus + 1
            end
        end
    else
        for my = 0, frame.mcuy - 1 do
            for mx = 0, frame.mcux - 1 do
                if restart > 0 and mcus > 0 and mcus % restart == 0 then reset() end
                for ci, c in ipairs(scomps) do
                    for v = 0, c.v - 1 do
                        for hh = 0, c.h - 1 do
                            block_fn(c, ci, at(c, mx * c.h + hh, my * c.v + v))
                        end
                    end
                end
                mcus = mcus + 1
            end
        end
    end
    -- after the entropy data: find the next marker (not a stuffed FF00 or RST)
    while pos < n do
        if buf[pos] == 0xFF and buf[pos + 1] ~= 0 and not (buf[pos + 1] >= 0xD0 and buf[pos + 1] <= 0xD7) then break end
        pos = pos + 1
    end
    return pos
end
-- }}}

return jpeg
