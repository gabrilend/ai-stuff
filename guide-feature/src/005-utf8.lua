-- 005-utf8.lua - counting a canvas row in characters, not bytes.
--
-- In plain terms: the canvas is W characters wide, and a character such as é
-- or → takes more than one byte. Everything that measures a row - the canvas
-- reader (102), the word finder (103), the fit check (105) - counts through
-- here, so they cannot disagree about how long a row is.
--
-- A character is one UTF-8 code point (docs/fit-check.md). Text that is not
-- valid UTF-8 (a stray byte, a cut sequence, a long-winded encoding, a
-- surrogate) is refused rather than guessed at, with the byte where it went
-- wrong.
--
--   local utf8 = dofile(DIR .. "/src/005-utf8.lua")
--   utf8.length("café")          --> 4
--   utf8.length("\255")          --> nil, 1     (the bad byte's place)
--   utf8.split("a→b")            --> { "a", "→", "b" }
--   utf8.pad("ab", 4)            --> "ab  "
--
-- LuaJIT-compatible: Lua 5.1 has no utf8 library, so this is its own.

local M = {}

-- {{{ local function sequence_at()
-- The length in bytes of the valid code point starting at byte `at`, or nil.
-- The ranges are the ones RFC 3629 allows, which leaves out encodings longer
-- than needed, the surrogate halves, and anything above U+10FFFF.
local function sequence_at(text, at)
    local first = string.byte(text, at)
    if first < 0x80 then
        return 1
    end
    local need, low, high
    if first >= 0xC2 and first <= 0xDF then
        need, low, high = 1, 0x80, 0xBF
    elseif first == 0xE0 then
        need, low, high = 2, 0xA0, 0xBF
    elseif first == 0xED then
        need, low, high = 2, 0x80, 0x9F
    elseif first >= 0xE1 and first <= 0xEF then
        need, low, high = 2, 0x80, 0xBF
    elseif first == 0xF0 then
        need, low, high = 3, 0x90, 0xBF
    elseif first >= 0xF1 and first <= 0xF3 then
        need, low, high = 3, 0x80, 0xBF
    elseif first == 0xF4 then
        need, low, high = 3, 0x80, 0x8F
    else
        return nil
    end
    -- The second byte has the narrowed range; the rest are any continuation.
    local second = string.byte(text, at + 1)
    if not second or second < low or second > high then
        return nil
    end
    for offset = 2, need do
        local byte = string.byte(text, at + offset)
        if not byte or byte < 0x80 or byte > 0xBF then
            return nil
        end
    end
    return need + 1
end
-- }}}

-- {{{ function M.length()
-- The number of characters, or nil and the byte position where the text stops
-- being valid UTF-8.
function M.length(text)
    local at, count = 1, 0
    while at <= #text do
        local size = sequence_at(text, at)
        if not size then
            return nil, at
        end
        at, count = at + size, count + 1
    end
    return count
end
-- }}}

-- {{{ function M.split()
-- The characters, one string each, or nil and the bad byte's position.
function M.split(text)
    local at, characters = 1, {}
    while at <= #text do
        local size = sequence_at(text, at)
        if not size then
            return nil, at
        end
        characters[#characters + 1] = string.sub(text, at, at + size - 1)
        at = at + size
    end
    return characters
end
-- }}}

-- {{{ function M.pad()
-- The text with spaces added to make it `width` characters. Text already that
-- long or longer is returned as it is; the caller decides whether that is an
-- error.
function M.pad(text, width)
    local length = assert(M.length(text), "utf8.pad: not valid UTF-8")
    if length >= width then
        return text
    end
    return text .. string.rep(" ", width - length)
end
-- }}}

return M
