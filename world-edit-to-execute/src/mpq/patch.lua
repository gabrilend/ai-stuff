--[[
Changing Files in an MPQ Without Rebuilding It (Issue 911a)

A map saved by the editor keeps every file of the map it came from,
including those whose names nobody knows (protected maps strip their
listfile; DAoW 5.4b has 199 such files). So instead of building a new
archive, the changed files go in the old one's way:

  replaced  the file's bytes go at the end of the archive, stored plain
            (not compressed or encrypted: WC3 reads plain files), and its
            block table entry is pointed at them; its hash entry stays
  added     likewise, with a new block table entry (the block table is
            written again at the end, longer) and a hash entry in the
            first free slot on the name's probe
  header    the archive size, and where the block table now is

The tables are found through the archive's header (at a 512-byte step:
maps carry a 512-byte HM3W header first), decrypted and encrypted with
MPQ's own table keys. The hashing is MPQ's (the crypt table from seed
0x00100001), as the project's first reader did (retired in issue 114,
source in history). Old file bytes aren't reclaimed.

    local patch = require("mpq.patch")
    local bytes, report = patch.apply(map_bytes, { ["war3map.w3e"] = w3e_bytes })
]]

local ffi = require("ffi")
local bit = require("bit")

local patch = {}

-- {{{ MPQ's crypt table and hash (32-bit wrapping through bit.tobit)
local tobit, bxor, bor, lshift, rshift, bnot = bit.tobit, bit.bxor, bit.bor, bit.lshift, bit.rshift, bit.bnot
local crypt = {}
do
    local seed = 0x00100001
    for i1 = 0, 255 do
        local i2 = i1
        for _ = 0, 4 do
            seed = (seed * 125 + 3) % 0x2AAAAB
            local t1 = (seed % 0x10000) * 0x10000
            seed = (seed * 125 + 3) % 0x2AAAAB
            local t2 = seed % 0x10000
            crypt[i2] = tobit(t1 + t2)
            i2 = i2 + 256
        end
    end
end

local function unsigned(v) return v % 4294967296 end

local function hash(str, kind)
    str = str:upper():gsub("/", "\\")
    local s1, s2 = tobit(0x7FED7FED), tobit(0xEEEEEEEE)
    for i = 1, #str do
        local ch = str:byte(i)
        s1 = bxor(crypt[kind * 256 + ch], tobit(s1 + s2))
        s2 = tobit(ch + s1 + s2 + lshift(s2, 5) + 3)
    end
    return unsigned(s1)
end
patch.hash = hash

-- words: an int32_t array, n of them, en- or decrypted in place
local function crypt_words(words, n, key, decrypt)
    local s1, s2 = tobit(key), tobit(0xEEEEEEEE)
    for i = 0, n - 1 do
        s2 = tobit(s2 + crypt[0x400 + unsigned(s1) % 256])
        local v = words[i]
        local out = bxor(v, tobit(s1 + s2))
        s1 = bor(tobit(lshift(bnot(s1), 21) + 0x11111111), rshift(s1, 11))
        local plain = decrypt and out or v
        s2 = tobit(plain + s2 + lshift(s2, 5) + 3)
        words[i] = out
    end
end
-- }}}

-- {{{ reading and writing words
local function words_of(bytes, from, count)
    local w = ffi.new("int32_t[?]", math.max(1, count))
    local avail = math.max(0, math.min(count * 4, #bytes - from))
    if avail > 0 then ffi.copy(w, ffi.cast("const char*", bytes) + from, avail) end
    return w
end
local function bytes_of(w, count) return ffi.string(w, count * 4) end
local function u32_at(bytes, at)
    local a, b, c, d = bytes:byte(at + 1, at + 4)
    return a + b * 256 + c * 65536 + d * 16777216
end
local function u32_str(v)
    v = v % 4294967296
    return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
end
-- }}}

-- {{{ patch.apply
-- files: { name = bytes }. The archive's new bytes, and a report
-- { replaced = n, added = n }; or nil and a message.
function patch.apply(bytes, files)
    -- the header: "MPQ\26" at a 512-byte step
    local base
    for at = 0, #bytes - 32, 512 do
        if bytes:sub(at + 1, at + 4) == "MPQ\26" then base = at break end
    end
    if not base then return nil, "no MPQ header found" end
    local hash_pos = u32_at(bytes, base + 16) + base
    local block_pos = u32_at(bytes, base + 20) + base
    local hash_n = u32_at(bytes, base + 24)
    local block_n = u32_at(bytes, base + 28)
    if hash_n == 0 or hash_n > 0x100000 then return nil, "hash table size " .. hash_n .. " not usable" end
    -- protected maps overstate the block table: only what the file holds
    block_n = math.min(block_n, math.max(0, math.floor((#bytes - block_pos) / 16)))

    local hkey, bkey = hash("(hash table)", 3), hash("(block table)", 3)
    local H = words_of(bytes, hash_pos, hash_n * 4)
    crypt_words(H, hash_n * 4, hkey, true)
    local blocks = {}
    do
        local B = words_of(bytes, block_pos, block_n * 4)
        crypt_words(B, block_n * 4, bkey, true)
        for i = 0, block_n - 1 do
            blocks[i] = { unsigned(B[i * 4]), unsigned(B[i * 4 + 1]), unsigned(B[i * 4 + 2]), unsigned(B[i * 4 + 3]) }
        end
    end

    local out = { bytes }
    local size = #bytes
    local replaced, added, how = 0, 0, {}
    local names = {}
    for name in pairs(files) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local data = files[name]
        local a, b = hash(name, 1), hash(name, 2)
        local start = hash(name, 0) % hash_n
        -- the name's entries along its probe (every locale), and the first free slot
        local found, free = {}, nil
        for k = 0, hash_n - 1 do
            local slot = (start + k) % hash_n
            local blk = unsigned(H[slot * 4 + 3])
            if blk == 0xFFFFFFFF then free = free or slot break end
            if blk == 0xFFFFFFFE then free = free or slot
            elseif unsigned(H[slot * 4]) == a and unsigned(H[slot * 4 + 1]) == b then
                found[#found + 1] = blk
            end
        end
        -- its bytes at the end, plain
        local offset = size - base
        out[#out + 1] = data
        size = size + #data
        local entry = { offset, #data, #data, 0x80000000 }
        if #found > 0 then
            for _, blk in ipairs(found) do blocks[blk] = entry end
            replaced = replaced + 1
            how[name] = "replaced"
        else
            if not free then return nil, "no free hash slot for " .. name end
            local blk = block_n
            block_n = block_n + 1
            blocks[blk] = entry
            H[free * 4], H[free * 4 + 1], H[free * 4 + 2], H[free * 4 + 3] = tobit(a), tobit(b), 0, tobit(blk)
            added = added + 1
            how[name] = "added"
        end
    end
    -- the block table again, at the end
    local B = ffi.new("int32_t[?]", math.max(1, block_n * 4))
    for i = 0, block_n - 1 do
        local e = blocks[i] or { 0, 0, 0, 0 }
        B[i * 4], B[i * 4 + 1], B[i * 4 + 2], B[i * 4 + 3] = tobit(e[1]), tobit(e[2]), tobit(e[3]), tobit(e[4])
    end
    crypt_words(B, block_n * 4, bkey, false)
    local new_block_pos = size - base
    out[#out + 1] = bytes_of(B, block_n * 4)
    size = size + block_n * 16
    -- the hash table where it was (its size unchanged)
    crypt_words(H, hash_n * 4, hkey, false)
    local all = table.concat(out)
    local htab = bytes_of(H, hash_n * 4)
    all = all:sub(1, hash_pos) .. htab .. all:sub(hash_pos + #htab + 1)
    -- the header: archive size, block table place and count
    all = all:sub(1, base + 8) .. u32_str(size - base) .. all:sub(base + 13)
    all = all:sub(1, base + 20) .. u32_str(new_block_pos) .. all:sub(base + 25)
    all = all:sub(1, base + 28) .. u32_str(block_n) .. all:sub(base + 33)
    return all, { replaced = replaced, added = added, names = how }
end
-- }}}

return patch
