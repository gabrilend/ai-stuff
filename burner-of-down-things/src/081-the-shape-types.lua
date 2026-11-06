-- 081-the-shape-types.lua
--
-- What a parcel is made of, without a model (docs/068): the closed list of
-- shape types and a recogniser for every one -- the three scalar types
-- (issue 902a); `image` and `clip` by their files' own signatures, `table`
-- by loading it as data in a sandbox (902b); `program`, `request`,
-- `finding`, `results` and `source` by the machine's own forms (902c).
-- Anything none of them match is `unknown`, never a guess.

local fs = require("017-the-filesystem")
local languages = require("027-the-language-table")

local shape_types = {}

-- What a thing matching none of the closed list is called: not a type of
-- its own, but the plain statement that nothing recognised it (902c).
shape_types.UNKNOWN = "unknown"

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

-- {{{ local function is_program
-- Something that can be run: it opens with a `#!` line naming what runs
-- it, or (when the file's path is known) the file is executable.
local function is_program(bytes, path)
    if bytes:match("^#![^\n]*%S") then
        return true
    end
    return path ~= nil and fs.run("test -f " .. fs.quote(path) .. " && test -x " .. fs.quote(path))
end
-- }}}

-- {{{ local function is_request
-- Something asked for, in the switchboard's own form (docs/068, 079): a
-- first line that is a well-formed tag, `language model prompt <number>:
-- <what is wanted>`.
local function is_request(bytes)
    local first = bytes:match("^[^\n]*")
    return first:match("^language model prompt %d+: %S") ~= nil
end
-- }}}

-- {{{ local function is_finding
-- What was found and the mechanism behind it, in the house Markdown form
-- that lessons (085) and observations (906) share: a `## ` heading, and a
-- line of its own reading `Mechanism: <a sentence>`.
local function is_finding(bytes)
    return bytes:match("^## %S") ~= nil and ("\n" .. bytes):match("\nMechanism: [^\n]*%S") ~= nil
end
-- }}}

-- How deep a JSON document may nest before it is refused rather than read.
local JSON_MAX_DEPTH = 200

-- {{{ local function json_end
-- Where one JSON value starting at `i` ends (the index after it), or nil
-- when it is not well-formed JSON (RFC 8259). Reads the text; builds
-- nothing.
local function json_end(text, i, depth)
    if depth > JSON_MAX_DEPTH then
        return nil
    end
    i = text:find("[^ \t\r\n]", i) or (#text + 1)
    local c = text:sub(i, i)
    if c == "{" or c == "[" then
        local close = (c == "{") and "}" or "]"
        local j = text:find("[^ \t\r\n]", i + 1)
        if j and text:sub(j, j) == close then
            return j + 1
        end
        j = i + 1
        while true do
            if c == "{" then
                local k = text:find("[^ \t\r\n]", j)
                if not k or text:sub(k, k) ~= '"' then
                    return nil
                end
                j = json_end(text, k, depth + 1)
                if not j then return nil end
                k = text:find("[^ \t\r\n]", j)
                if not k or text:sub(k, k) ~= ":" then
                    return nil
                end
                j = k + 1
            end
            j = json_end(text, j, depth + 1)
            if not j then return nil end
            local k = text:find("[^ \t\r\n]", j)
            if not k then return nil end
            local d = text:sub(k, k)
            if d == close then
                return k + 1
            elseif d ~= "," then
                return nil
            end
            j = k + 1
        end
    elseif c == '"' then
        local j = i + 1
        while true do
            local d = text:sub(j, j)
            if d == "" or d:byte() < 0x20 then
                return nil
            elseif d == '"' then
                return j + 1
            elseif d == "\\" then
                local e = text:sub(j + 1, j + 1)
                if e == "u" then
                    if not text:sub(j + 2, j + 5):match("^%x%x%x%x$") then
                        return nil
                    end
                    j = j + 6
                elseif e ~= "" and ('"\\/bfnrt'):find(e, 1, true) then
                    j = j + 2
                else
                    return nil
                end
            else
                j = j + 1
            end
        end
    elseif c == "-" or c:match("%d") then
        -- -? (0 | [1-9][0-9]*) (.[0-9]+)? ([eE][+-]?[0-9]+)?
        local j = i
        if c == "-" then
            j = j + 1
        end
        local whole = text:match("^0", j) or text:match("^[1-9]%d*", j)
        if not whole then
            return nil
        end
        j = j + #whole
        if text:sub(j, j) == "." then
            local fraction = text:match("^%.%d+", j)
            if not fraction then
                return nil
            end
            j = j + #fraction
        end
        if text:sub(j, j):match("^[eE]$") then
            local exponent = text:match("^[eE][%+%-]?%d+", j)
            if not exponent then
                return nil
            end
            j = j + #exponent
        end
        return j
    end
    for _, word in ipairs({ "true", "false", "null" }) do
        if text:sub(i, i + #word - 1) == word then
            return i + #word
        end
    end
    return nil
end
-- }}}

-- {{{ local function is_results
-- A program's results as the harnesses write them (037's result.json): a
-- well-formed JSON object or array, and nothing after it but space.
local function is_results(bytes)
    local start = bytes:find("[^ \t\r\n]")
    if not start or not bytes:sub(start, start):match("[%[{]") then
        return false
    end
    local finish = json_end(bytes, start, 0)
    return finish ~= nil and not bytes:find("[^ \t\r\n]", finish)
end
-- }}}

-- {{{ local function is_source
-- Code by its name: 027's language table gives the file the role `code`.
-- Only a file whose path is known can be source; the bytes alone could be
-- anything's.
local function is_source(bytes, path)
    return path ~= nil and languages.classify(path, bytes:sub(1, 8192)).role == "code"
end
-- }}}

-- {{{ function shape_types.recognise
-- The first recogniser a file's bytes (and, when known, its path) match,
-- tried in order:
--   image, clip        exact signatures, binary or ASCII that would
--                      otherwise read as text
--   table              a Lua data file is also text
--   program            a #! line, or an executable file
--   request            a first line that is a tag
--   finding            a ## heading and a Mechanism: line
--   results            a JSON object or array
--   source             code, by its name (027)
--   integer-array, number-array, text    902a's scalar types, last
-- Anything none of these match is `unknown`, never a guess (902c); so is
-- a file holding nothing but space.
function shape_types.recognise(bytes, path)
    -- Nothing in it, or only space: there is nothing to recognise, and
    -- calling it text would be a guess.
    if not bytes:find("[^ \t\r\n]") then
        return shape_types.UNKNOWN
    end
    if is_image(bytes) then
        return "image"
    end
    if is_clip(bytes) then
        return "clip"
    end
    if is_table(bytes) then
        return "table"
    end
    if is_program(bytes, path) then
        return "program"
    end
    if is_request(bytes) then
        return "request"
    end
    if is_finding(bytes) then
        return "finding"
    end
    if is_results(bytes) then
        return "results"
    end
    if is_source(bytes, path) then
        return "source"
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
    return shape_types.UNKNOWN
end
-- }}}

-- {{{ function shape_types.recognise_file
-- A parcel file (079's {name, path}, or a path) recognised from its bytes
-- and its path.
function shape_types.recognise_file(file)
    local path = type(file) == "table" and file.path or file
    return shape_types.recognise(fs.read(path), path)
end
-- }}}

return shape_types
