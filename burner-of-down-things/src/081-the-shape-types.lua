-- 081-the-shape-types.lua
--
-- What a parcel is made of, without a model (docs/068): the closed list of
-- shape types, recognisers for the three scalar types (issue 902a) and the
-- three structured ones -- `image` and `clip` by their files' own
-- signatures, `table` by loading it as data in a sandbox (902b). The
-- remaining five plus `unknown` (902c) extend this same recognise()
-- dispatch.

local shape_types = {}

-- The closed list, docs/068's own words. Adding a type means adding a row
-- here and a recogniser below it — never a type nothing can detect.
shape_types.TYPES = {
    "integer-array", "number-array", "text", "table", "image", "clip",
    "source", "program", "results", "finding", "request",
}

-- {{{ local function is_integer_array
-- Whitespace-separated integers, and nothing else; refuses an empty or
-- blank string rather than call it an array of nothing.
local function is_integer_array(text)
    if not text:match("%S") then
        return false
    end
    for token in text:gmatch("%S+") do
        if not token:match("^%-?%d+$") then
            return false
        end
    end
    return true
end
-- }}}

-- {{{ local function is_number_array
-- Like is_integer_array, but each token may also hold a fractional part.
local function is_number_array(text)
    if not text:match("%S") then
        return false
    end
    for token in text:gmatch("%S+") do
        if not token:match("^%-?%d*%.?%d+$") then
            return false
        end
    end
    return true
end
-- }}}

-- {{{ local function is_text
-- Well-formed UTF-8: every byte is ASCII or part of a legal multi-byte
-- sequence. Tried last among the scalar types, so plain ASCII numbers are
-- caught by the two recognisers above it first.
local function is_text(bytes)
    local i, n = 1, #bytes
    while i <= n do
        local b = bytes:byte(i)
        local extra
        if b < 0x80 then
            extra = 0
        elseif b >= 0xC2 and b <= 0xDF then
            extra = 1
        elseif b >= 0xE0 and b <= 0xEF then
            extra = 2
        elseif b >= 0xF0 and b <= 0xF4 then
            extra = 3
        else
            return false
        end
        if i + extra > n then
            return false
        end
        for k = 1, extra do
            local c = bytes:byte(i + k)
            if c < 0x80 or c > 0xBF then
                return false
            end
        end
        i = i + extra + 1
    end
    return true
end
-- }}}

-- The PNG signature, eight bytes, then the first chunk's type at bytes
-- 13-16, which the PNG format says is always IHDR.
local PNG_SIGNATURE = "\137PNG\r\n\26\n"

-- {{{ local function is_image
-- A PNG: its eight-byte signature exactly, and IHDR where the first chunk's
-- type must be. One wrong byte in the signature is not an image.
local function is_image(bytes)
    return #bytes >= 16 and bytes:sub(1, 8) == PNG_SIGNATURE and bytes:sub(13, 16) == "IHDR"
end
-- }}}

-- {{{ local function is_clip
-- An MP4 (an ISO media file: a box size, then `ftyp` at bytes 5-8, then a
-- four-letter brand) or a GIF (`GIF87a` or `GIF89a`, then its screen
-- descriptor).
local function is_clip(bytes)
    if #bytes >= 12 and bytes:sub(5, 8) == "ftyp" then
        return true
    end
    local head = bytes:sub(1, 6)
    return #bytes >= 13 and (head == "GIF87a" or head == "GIF89a")
end
-- }}}

-- How many Lua instructions a table file may take to build its table. A
-- data file of literals takes a handful per value; a loop that never ends
-- takes them all and is refused.
shape_types.TABLE_INSTRUCTION_LIMIT = 1000000

-- {{{ local function is_table
-- A Lua data file that loads and returns a table (the same form as 014's
-- read_record), run as data and never for effect: an empty environment (no
-- os, io, require, or anything else), text only (precompiled bytecode is
-- refused unread, since loading it is not safe), JIT off and an
-- instruction limit so a loop cannot hang the machine, and the string
-- methods (`("x"):rep(...)`) out of reach while it runs.
local function is_table(bytes)
    if bytes:sub(1, 1) == "\27" or not bytes:match("%S") then
        return false
    end
    local chunk = loadstring(bytes, "=parcel")
    if not chunk then
        return false
    end
    setfenv(chunk, {})
    jit.off(chunk, true)
    local string_meta = getmetatable("")
    local string_index = string_meta.__index
    string_meta.__index = nil
    debug.sethook(function()
        error("the table file ran past " .. shape_types.TABLE_INSTRUCTION_LIMIT .. " instructions", 0)
    end, "", shape_types.TABLE_INSTRUCTION_LIMIT)
    local ok, value = pcall(chunk)
    debug.sethook()
    string_meta.__index = string_index
    return ok and type(value) == "table"
end
-- }}}

-- {{{ function shape_types.recognise
-- The first recogniser a file's bytes match, tried in order: image and
-- clip (their signatures are exact and binary, or ASCII that would
-- otherwise read as text), table (a Lua data file is also text), then the
-- scalar types in 902a's order: integer-array, number-array, text. Falls
-- through to nil -- never a guess -- for 902c's recognisers to try, and
-- finally `unknown`.
function shape_types.recognise(bytes)
    if is_image(bytes) then
        return "image"
    end
    if is_clip(bytes) then
        return "clip"
    end
    if is_table(bytes) then
        return "table"
    end
    if is_integer_array(bytes) then
        return "integer-array"
    end
    if is_number_array(bytes) then
        return "number-array"
    end
    if is_text(bytes) then
        return "text"
    end
    return nil
end
-- }}}

return shape_types
