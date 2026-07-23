-- 01-utils.lua — the shared toolbox: logging, JSON, and path scraps.
--
-- General description: small, boring helpers that every other file leans on.
-- Two jobs matter here. First, logging that makes warnings LOUD — because in
-- this project a fallback is a warning and a warning is treated as an error, so
-- it must never slip by in grey text. Second, a tiny JSON reader/writer, because
-- the catalog is stored one JSON object per line and file paths in the wild
-- contain quotes, spaces, backslashes and unicode that must survive the trip.

local M = {}

-- {{{ colour helpers
-- Colour only when stderr is a terminal; piped output stays plain so logs are
-- greppable. WHY stderr: logs must not pollute stdout, which carries data.
local function is_tty()
    -- LuaJIT/5.1 has no isatty; ask the OS cheaply. A non-zero exit means "not a
    -- tty" and we simply fall back to no colour — harmless either way.
    local ok = os.execute("test -t 2")
    return ok == 0 or ok == true
end

local USE_COLOUR = is_tty()

local function paint(code, text)
    if not USE_COLOUR then return text end
    return "\27[" .. code .. "m" .. text .. "\27[0m"
end
-- }}}

-- {{{ M.log_info / log_warn / log_error
function M.log_info(msg)
    io.stderr:write(paint("36", "[info] ") .. msg .. "\n")
end

-- A fallback anywhere in the system calls this. It is deliberately shouted.
function M.log_warn(msg)
    io.stderr:write(paint("33", "[WARN] ") .. msg .. "\n")
end

function M.log_error(msg)
    io.stderr:write(paint("31", "[ERROR] ") .. msg .. "\n")
end
-- }}}

-- {{{ M.basename / M.extension
function M.basename(path)
    return path:match("[^/]+$") or path
end

-- Lower-cased extension without the dot, or "" if none. We look only at the
-- final segment so a dot in a parent directory name cannot masquerade as a type.
function M.extension(path)
    local base = M.basename(path)
    local ext = base:match("%.([%w]+)$")
    return ext and ext:lower() or ""
end
-- }}}

-- {{{ M.json_encode
-- Encodes a flat table (string keys; string/number/boolean/nil values) as a
-- single-line JSON object. That is all the catalog needs, so we keep it narrow
-- and fast rather than general.
local ESCAPES = {
    ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b',
    ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function encode_string(s)
    -- Escape the JSON-special characters plus any control byte, so no raw
    -- newline or control char can break the one-object-per-line invariant.
    local out = s:gsub('[%z\1-\31"\\]', function(c)
        return ESCAPES[c] or string.format("\\u%04x", c:byte())
    end)
    return '"' .. out .. '"'
end

local function encode_value(v)
    local t = type(v)
    if t == "string" then return encode_string(v)
    elseif t == "number" then
        -- Integers print without a decimal point; math.floor test keeps epoch
        -- seconds and byte counts clean.
        if v == math.floor(v) and v == v then
            return string.format("%d", v)
        end
        return tostring(v)
    elseif t == "boolean" then return v and "true" or "false"
    elseif v == nil then return "null"
    else error("json_encode: unsupported value type " .. t) end
end

function M.json_encode(record)
    local parts = {}
    -- Sorted keys give byte-stable output, which makes catalogs diffable and
    -- checksums reproducible.
    local keys = {}
    for k in pairs(record) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        parts[#parts + 1] = encode_string(k) .. ":" .. encode_value(record[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end
-- }}}

-- {{{ M.json_decode
-- A small recursive-descent parser: objects, arrays, strings (with \uXXXX),
-- numbers, true/false/null. Enough to read back exactly what json_encode wrote,
-- and robust to hand-authored input/ files too.
local decode_value  -- forward declaration for mutual recursion

local function skip_ws(s, i)
    local _, j = s:find("^[ \t\r\n]*", i)
    return (j or i - 1) + 1
end

local UNESCAPE = {
    ['"'] = '"', ['\\'] = '\\', ['/'] = '/', ['b'] = '\b',
    ['f'] = '\f', ['n'] = '\n', ['r'] = '\r', ['t'] = '\t',
}

local function decode_string(s, i)
    -- i points at the opening quote.
    local buf, j = {}, i + 1
    while j <= #s do
        local c = s:sub(j, j)
        if c == '"' then
            return table.concat(buf), j + 1
        elseif c == '\\' then
            local nxt = s:sub(j + 1, j + 1)
            if nxt == 'u' then
                local hex = s:sub(j + 2, j + 5)
                local code = tonumber(hex, 16) or error("bad \\u escape")
                -- Encode the codepoint as UTF-8 (BMP range is all we wrote).
                if code < 0x80 then
                    buf[#buf + 1] = string.char(code)
                elseif code < 0x800 then
                    buf[#buf + 1] = string.char(0xC0 + math.floor(code / 0x40),
                                                0x80 + (code % 0x40))
                else
                    buf[#buf + 1] = string.char(
                        0xE0 + math.floor(code / 0x1000),
                        0x80 + (math.floor(code / 0x40) % 0x40),
                        0x80 + (code % 0x40))
                end
                j = j + 6
            else
                buf[#buf + 1] = UNESCAPE[nxt] or nxt
                j = j + 2
            end
        else
            buf[#buf + 1] = c
            j = j + 1
        end
    end
    error("json_decode: unterminated string")
end

local function decode_object(s, i)
    local obj, j = {}, skip_ws(s, i + 1)
    if s:sub(j, j) == "}" then return obj, j + 1 end
    while true do
        j = skip_ws(s, j)
        local key; key, j = decode_string(s, j)
        j = skip_ws(s, j)
        assert(s:sub(j, j) == ":", "json_decode: expected ':'")
        local val; val, j = decode_value(s, skip_ws(s, j + 1))
        obj[key] = val
        j = skip_ws(s, j)
        local c = s:sub(j, j)
        if c == "}" then return obj, j + 1 end
        assert(c == ",", "json_decode: expected ',' or '}'")
        j = j + 1
    end
end

local function decode_array(s, i)
    local arr, j = {}, skip_ws(s, i + 1)
    if s:sub(j, j) == "]" then return arr, j + 1 end
    while true do
        local val; val, j = decode_value(s, skip_ws(s, j))
        arr[#arr + 1] = val
        j = skip_ws(s, j)
        local c = s:sub(j, j)
        if c == "]" then return arr, j + 1 end
        assert(c == ",", "json_decode: expected ',' or ']'")
        j = j + 1
    end
end

decode_value = function(s, i)
    local c = s:sub(i, i)
    if c == '"' then return decode_string(s, i)
    elseif c == "{" then return decode_object(s, i)
    elseif c == "[" then return decode_array(s, i)
    elseif c == "t" then return true, i + 4
    elseif c == "f" then return false, i + 5
    elseif c == "n" then return nil, i + 4
    else
        local num = s:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", i)
        assert(num and #num > 0, "json_decode: unexpected char '" .. c .. "'")
        return tonumber(num), i + #num
    end
end

function M.json_decode(line)
    local val = decode_value(line, skip_ws(line, 1))
    return val
end
-- }}}

return M
