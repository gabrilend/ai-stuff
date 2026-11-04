-- text-fingerprint.lua: a short code for a piece of text, the same every time
-- for the same bytes and different (in all but astronomically rare cases)
-- for different ones. Used to tie each cached embedding to the exact text it
-- was made from, so a vector can never again be handed to a poem whose text
-- it does not describe (Issue 8-019: on 2026-10-07 the notes were renumbered
-- under their vectors and about 555 of 582 were ranked by another note's
-- meaning).
--
-- The code is FNV-1a over 64 bits: each byte is folded in with an exclusive-or
-- and a multiply by a fixed prime. It is fast, needs no library, and is not
-- meant to resist someone forging a match -- only to notice that a text has
-- changed. LuaJIT's 64-bit numbers (ffi uint64) carry the arithmetic.

local ffi = require("ffi")
local bit = require("bit")

local M = {}

local OFFSET = 0xcbf29ce484222325ULL   -- FNV-1a 64-bit starting value
local PRIME = 0x100000001b3ULL         -- FNV-1a 64-bit prime

-- {{{ function M.of
-- text   : a string (any bytes)
-- returns: 16 lower-case hex digits, e.g. "af63bd4c8601b7df"
function M.of(text)
    if type(text) ~= "string" then
        error("text-fingerprint: a string is needed, not " .. type(text))
    end
    local h = OFFSET
    for i = 1, #text do
        h = bit.bxor(h, ffi.cast("uint64_t", text:byte(i))) * PRIME
    end
    return bit.tohex(h, 16)
end
-- }}}

return M
