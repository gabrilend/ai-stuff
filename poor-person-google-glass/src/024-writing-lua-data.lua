-- 024-writing-lua-data.lua - a Lua table written back out as Lua source.
--
-- In plain terms: results files and joint records are Lua files that a
-- program writes and a person may read or edit. This turns a table into
-- that text the same way every time: keys sorted, lists in order, numbers
-- with every digit they need to come back exactly, so the same data always
-- makes the same file (and a diff shows only what changed).
--
-- Moved here from 022-calculate.lua when the joint records (issue 010)
-- needed the same writer.

local M = {}

-- {{{ local function key_text()
-- A key as Lua writes it: a bare word when it can be one, else ["..."].
local function key_text(key)
    if type(key) == "string" and key:match("^[%a_][%w_]*$") then return key end
    if type(key) == "string" then return string.format("[%q]", key) end
    return "[" .. tostring(key) .. "]"
end
-- }}}

-- {{{ function M.serialise()
-- value -> Lua source text. Tables that are lists (1..n with nothing else)
-- are written as lists; others with their keys sorted (numbers before
-- strings). Functions and other kinds are refused: data only.
function M.serialise(value, indent)
    indent = indent or ""
    local kind = type(value)
    if kind == "number" then
        -- whole numbers plainly; others with 17 significant figures, the
        -- most a double needs to come back exactly
        if value == math.floor(value) and math.abs(value) < 1e15 then return string.format("%d", value) end
        return string.format("%.17g", value)
    end
    if kind == "string" then return string.format("%q", value) end
    if kind == "boolean" then return tostring(value) end
    if kind ~= "table" then error("cannot write a " .. kind .. " as data", 0) end
    local count, longest = 0, 0
    for key in pairs(value) do
        count = count + 1
        if type(key) == "number" and key > longest then longest = key end
    end
    if count == 0 then return "{}" end
    local inner, lines = indent .. "    ", {}
    if longest == count then
        for _, item in ipairs(value) do lines[#lines + 1] = inner .. M.serialise(item, inner) .. "," end
    else
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b)
            if type(a) ~= type(b) then return type(a) == "number" end
            return a < b
        end)
        for _, key in ipairs(keys) do lines[#lines + 1] = inner .. key_text(key) .. " = " .. M.serialise(value[key], inner) .. "," end
    end
    return "{\n" .. table.concat(lines, "\n") .. "\n" .. indent .. "}"
end
-- }}}

-- {{{ function M.write_file()
-- Writes `header` (comment lines, each starting "--") then "return <value>".
function M.write_file(path, header, value)
    local file, problem = io.open(path, "w")
    if file == nil then error("cannot write " .. path .. ": " .. tostring(problem), 0) end
    file:write(header .. "\nreturn " .. M.serialise(value) .. "\n")
    file:close()
end
-- }}}

-- {{{ function M.read_file()
-- Loads a data file written by write_file (or by hand). Returns its value,
-- or nil if the file does not exist; raises on a file that exists but
-- cannot be read as Lua.
function M.read_file(path)
    local probe = io.open(path)
    if probe == nil then return nil end
    probe:close()
    local chunk, problem = loadfile(path)
    if chunk == nil then error("cannot read " .. path .. ": " .. tostring(problem), 0) end
    return chunk()
end
-- }}}

return M
