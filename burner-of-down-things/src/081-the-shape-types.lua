-- 081-the-shape-types.lua
--
-- What a parcel is made of, without a model (docs/068, issue 902a): the
-- closed list of shape types, and recognisers for the simplest three.
-- Structured types (902b) and the remaining five plus `unknown` (902c) are
-- later pieces that extend TYPES and this same recognise() dispatch.

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

-- {{{ function shape_types.recognise
-- The first of the scalar recognisers a text matches, tried in order:
-- integer-array, number-array, text. Falls through to nil — never a
-- guess — for 902b/902c's recognisers to try, and finally `unknown`.
function shape_types.recognise(bytes)
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
