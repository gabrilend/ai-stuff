-- 014-text-tables.lua
--
-- The one reader and writer of everything the machine keeps on disk as data.
-- Tables are tab-separated text, one row per line, with a header line; records
-- are Lua files that return one table. No other module parses a line of a
-- table file or loads a record by hand, so the escaping rules live in exactly
-- one place.

local text_tables = {}

-- Escaping: a field may hold any bytes, but a row must stay on one line and
-- its fields must stay separated. Backslash is escaped first on the way out
-- and last on the way in, or `\t` written literally would read back as a tab.
local ESCAPE_OUT = { ["\\"] = "\\\\", ["\t"] = "\\t", ["\n"] = "\\n", ["\r"] = "\\r" }
local ESCAPE_IN = { ["\\"] = "\\", ["t"] = "\t", ["n"] = "\n", ["r"] = "\r" }

-- {{{ function text_tables.escape
function text_tables.escape(field)
    if type(field) ~= "string" then
        -- Numbers are welcome as fields; anything else is a caller mistake.
        if type(field) == "number" then
            field = tostring(field)
        else
            error("text_tables.escape: a field must be a string or number, got " .. type(field))
        end
    end
    return (field:gsub("[\\\t\n\r]", ESCAPE_OUT))
end
-- }}}

-- {{{ function text_tables.unescape
function text_tables.unescape(field)
    return (field:gsub("\\(.)", function(c)
        local out = ESCAPE_IN[c]
        -- A backslash followed by anything else was never written by escape;
        -- the file was edited by hand or torn. Refuse rather than guess.
        if not out then
            error("text_tables.unescape: unknown escape \\" .. c)
        end
        return out
    end))
end
-- }}}

-- {{{ function text_tables.split_line
-- Splits one line into its raw (still escaped) fields.
function text_tables.split_line(line)
    local fields = {}
    local start = 1
    while true do
        local tab = line:find("\t", start, true)
        if not tab then
            fields[#fields + 1] = line:sub(start)
            break
        end
        fields[#fields + 1] = line:sub(start, tab - 1)
        start = tab + 1
    end
    return fields
end
-- }}}

-- {{{ function text_tables.row_line
-- One row (an array of fields) as one escaped line, without the newline.
function text_tables.row_line(row)
    local out = {}
    for i = 1, #row do
        out[i] = text_tables.escape(row[i])
    end
    return table.concat(out, "\t")
end
-- }}}

-- {{{ function text_tables.write
-- Writes a whole table: header (array of field names) and rows (arrays of
-- fields, in header order). The file is written to a neighbour name first and
-- renamed over the target, so a reader never sees half a table.
function text_tables.write(path, header, rows)
    local tmp_path = path .. ".writing"
    local file = assert(io.open(tmp_path, "wb"))
    file:write("#", table.concat(header, "\t"), "\n")
    for r = 1, #rows do
        local row = rows[r]
        if #row ~= #header then
            file:close()
            os.remove(tmp_path)
            error(string.format("text_tables.write: row %d has %d fields, header has %d",
                r, #row, #header))
        end
        file:write(text_tables.row_line(row), "\n")
    end
    file:close()
    assert(os.rename(tmp_path, path))
end
-- }}}

-- {{{ function text_tables.parse
-- Reads table text (a whole file's contents) into rows keyed by the header's
-- field names. `where` names the source in error messages.
function text_tables.parse(text, where)
    -- Every line the writer makes ends in a newline, so text that does not
    -- is a torn last line. Reading on would silently drop it.
    if #text > 0 and text:sub(-1) ~= "\n" then
        error(where .. ": last line has no newline (torn write?)")
    end
    local header
    local rows = {}
    local line_number = 0
    for line in text:gmatch("([^\n]*)\n") do
        line_number = line_number + 1
        if line_number == 1 then
            -- The header is the only line allowed to start with '#'.
            if line:sub(1, 1) ~= "#" then
                error(where .. ": first line is not a header")
            end
            header = text_tables.split_line(line:sub(2))
        else
            local fields = text_tables.split_line(line)
            -- A row with the wrong number of fields is a torn or hand-edited
            -- file. Blank fields are written as empty strings and still count,
            -- so a short row is never "a row with blanks".
            if #fields ~= #header then
                error(string.format("%s:%d: %d fields, header has %d",
                    where, line_number, #fields, #header))
            end
            local row = {}
            for i = 1, #header do
                row[header[i]] = text_tables.unescape(fields[i])
            end
            rows[#rows + 1] = row
        end
    end
    if not header then
        error(where .. ": empty table file")
    end
    return rows, header
end
-- }}}

-- {{{ function text_tables.read
function text_tables.read(path)
    local file = io.open(path, "rb")
    if not file then
        error("text_tables.read: cannot open " .. path)
    end
    local text = file:read("*a")
    file:close()
    return text_tables.parse(text, path)
end
-- }}}

-- Records ---------------------------------------------------------------

-- {{{ local function sorted_keys
local function sorted_keys(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end
    -- Numbers before strings, each group in natural order, so a record always
    -- writes the same bytes.
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then
            return ta == "number"
        end
        return a < b
    end)
    return keys
end
-- }}}

-- Values a record may hold, each with how it is written. A dispatch table
-- rather than a chain of ifs; a type with no row is refused.
local write_value

local VALUE_WRITERS = {
    string = function(v) return string.format("%q", v) end,
    number = function(v)
        -- Integers stay integers on disk; others keep full precision.
        if v == math.floor(v) and v > -2^53 and v < 2^53 then
            return string.format("%d", v)
        end
        return string.format("%.17g", v)
    end,
    boolean = function(v) return tostring(v) end,
    table = function(v, indent) return write_value(v, indent) end,
}

-- {{{ function write_value
function write_value(t, indent)
    local pad = string.rep("    ", indent + 1)
    local lines = { "{" }
    for _, k in ipairs(sorted_keys(t)) do
        local v = t[k]
        local writer = VALUE_WRITERS[type(v)]
        if not writer then
            error("text_tables: a record cannot hold a " .. type(v))
        end
        local key
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
            key = k
        else
            key = "[" .. VALUE_WRITERS[type(k)](k, 0) .. "]"
        end
        lines[#lines + 1] = pad .. key .. " = " .. writer(v, indent + 1) .. ","
    end
    lines[#lines + 1] = string.rep("    ", indent) .. "}"
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function text_tables.write_record
function text_tables.write_record(path, record)
    if type(record) ~= "table" then
        error("text_tables.write_record: a record is a table")
    end
    local tmp_path = path .. ".writing"
    local file = assert(io.open(tmp_path, "wb"))
    file:write("return ", write_value(record, 0), "\n")
    file:close()
    assert(os.rename(tmp_path, path))
end
-- }}}

-- {{{ function text_tables.read_record
-- Loads a record with an empty environment: the file can build a table from
-- literals and nothing else — no os, no io, no require.
function text_tables.read_record(path)
    local chunk, err = loadfile(path)
    if not chunk then
        error("text_tables.read_record: " .. tostring(err))
    end
    setfenv(chunk, {})
    local ok, value = pcall(chunk)
    if not ok then
        error("text_tables.read_record: " .. path .. " did more than return a table: " .. tostring(value))
    end
    if type(value) ~= "table" then
        error("text_tables.read_record: " .. path .. " does not return a table")
    end
    return value
end
-- }}}

return text_tables
