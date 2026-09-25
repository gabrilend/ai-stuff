--[[
system_codecs.lua - zlib and bzip2 decompression through the system libraries

MPQ sectors compressed with zlib (byte 0x02) or bzip2 (byte 0x10) are handed
to the system's libz and libbz2 through LuaJIT's FFI, the same libraries
StormLib links to. This replaces an earlier route that wrote each sector to a
temporary file and ran a Python one-liner on it; that route also skipped the
zlib header and checksum, a workaround for a decryption bug since fixed
(see extract.lua's decrypt_sector).

Behaviour matches StormLib's wrappers: zlib data must carry its 2-byte header
and a valid checksum; output is capped at the expected sector size.

Usage:
  local codecs = require("mpq.system_codecs")
  local bytes, err = codecs.zlib(data, expected_length)
  local bytes, err = codecs.bzip2(data, expected_length)

Issue: issues/completed/113-remaining-mpq-compressions.md
]]

local ok_ffi, ffi = pcall(require, "ffi")

local M = {}

local zlib, bz2 = nil, nil
if ok_ffi then
    -- {{{ C declarations
    ffi.cdef[[
    int uncompress(unsigned char *dest, unsigned long *destLen,
                   const unsigned char *source, unsigned long sourceLen);
    int BZ2_bzBuffToBuffDecompress(char *dest, unsigned int *destLen,
                                   char *source, unsigned int sourceLen,
                                   int small, int verbosity);
    ]]
    -- }}}
end

-- {{{ local function load
-- Loads a system library once. Missing LuaJIT or a missing library is an
-- error naming what's needed, never a quiet skip.
local function load(name)
    if not ok_ffi then
        error("zlib/bzip2 decompression needs LuaJIT's FFI (run under luajit)")
    end
    local ok, lib = pcall(ffi.load, name)
    if not ok then
        error("system library " .. name .. " not found: " .. tostring(lib))
    end
    return lib
end
-- }}}

local ZLIB_RESULT = { [0] = "ok", [-2] = "stream error", [-3] = "data error (corrupt data or bad checksum)",
    [-4] = "out of memory", [-5] = "output buffer too small" }

-- {{{ function M.zlib
function M.zlib(data, expected_length)
    zlib = zlib or load("libz.so.1")
    local out = ffi.new("unsigned char[?]", expected_length)
    local out_len = ffi.new("unsigned long[1]", expected_length)
    local result = zlib.uncompress(out, out_len, data, #data)
    if result ~= 0 then
        return nil, "zlib: " .. (ZLIB_RESULT[result] or ("error " .. result))
    end
    return ffi.string(out, out_len[0])
end
-- }}}

-- {{{ function M.bzip2
function M.bzip2(data, expected_length)
    bz2 = bz2 or load("libbz2.so.1")
    local out = ffi.new("char[?]", expected_length)
    local out_len = ffi.new("unsigned int[1]", expected_length)
    local source = ffi.new("char[?]", #data)
    ffi.copy(source, data, #data)
    local result = bz2.BZ2_bzBuffToBuffDecompress(out, out_len, source, #data, 0, 0)
    if result ~= 0 then
        return nil, "bzip2: error " .. result
    end
    return ffi.string(out, out_len[0])
end
-- }}}

return M
