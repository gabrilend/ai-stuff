-- 006-canvas-text.lua - the canvas as text, read and written.
--
-- In plain terms: the canvas travels as plain text, from kuvalu to the voices,
-- from a voice back to kuvalu, and from kuvalu to every viewer
-- (docs/canvas-format.md). This is the one reader and the one writer for all of
-- it. The reader turns text into a canvas record, or refuses it, naming the
-- line that is wrong. It never guesses. The writer turns a record back into
-- the same text, byte for byte.
--
--   local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
--   local record = canvas.read(text, "to-voices", "the-canvas")
--   record.headers.canvas, record.width, record.rows[3], record.marks[1].voice
--   local text = canvas.write(record)
--
-- The three header sets (which lines come first, and in what order):
--   to-voices    kuvalu -> voices   canvas size mode project endpoint written
--   from-voice   a voice -> kuvalu  voice turn base size written
--   for-viewers  kuvalu -> viewers  canvas size mode project written voices
--
-- The record:
--   set            which header set it was read with
--   headers        name -> parsed value (size as { width, height }, project as
--                  { name, commit }, endpoint as { name, address }, voices as
--                  a list of names, the rest as numbers or text)
--   width, height  whole numbers, from size
--   rows           `height` strings, each padded to exactly `width` characters
--   marks          list of { row, column, length, voice, version, kind }
--   cuts           (to-voices only) nil when the section is absent, else a list
--                  of { voice, version, row, column, text }
--   ignored_marks  (from-voice only) how many mark lines a voice sent; a
--                  voice's marks are ignored and counted, never read
--
-- The reader does not count changes; that is the fit check (105).
-- LuaJIT-compatible.

-- {{{ local DIR
-- Sibling files are found next to this one, wherever the project is, so a
-- copy of the project (a voice's, a test's) loads its own 005 and not the one
-- at the hard-coded root. The hard-coded root is only the last resort.
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local utf8 = dofile(DIR .. "/src/005-utf8.lua")

local M = {}

-- {{{ local function refuse()
-- Every refusal names where: the source and the line, "the-canvas:23: ...".
local function refuse(source, line, text)
    error(source .. ":" .. line .. ": " .. text, 0)
end
-- }}}

-- {{{ value readers and writers
-- Each turns a header's or a field's text into a value, or returns nil. They
-- are strict on purpose: only text the writer would write back the same way
-- is accepted, so reading and writing again is byte for byte.

-- {{{ local function whole()
-- A whole number of zero or more, with no leading zeros ("018" is refused,
-- because it could not be written back as it came).
local function whole(text)
    if string.match(text, "^0$") or string.match(text, "^[1-9]%d*$") then
        return tonumber(text)
    end
    return nil
end
-- }}}

-- {{{ local function name()
-- A voice's, a project's or an endpoint's name.
local function name(text)
    return string.match(text, "^[%w%._%-]+$") and text or nil
end
-- }}}

-- {{{ local function utc_time()
local function utc_time(text)
    return string.match(text, "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") and text or nil
end
-- }}}
-- }}}

-- {{{ M.HEADERS
-- A table from header name to its value's reader, its writer and what a value
-- should look like (for the refusal). Positions come from M.SETS.
M.HEADERS = {
    canvas = { read = whole, write = tostring, looks = "a whole number" },
    turn   = { read = whole, write = tostring, looks = "a whole number" },
    base   = { read = whole, write = tostring, looks = "a whole number" },
    voice  = { read = name, write = tostring, looks = "a name" },
    written = { read = utc_time, write = tostring, looks = "a UTC time like 2026-10-21T22:10:05Z" },
    size = {
        read = function(text)
            local width, height = string.match(text, "^(%d+)x(%d+)$")
            width, height = width and whole(width), height and whole(height)
            if width and height and width >= 1 and height >= 1 then
                return { width = width, height = height }
            end
            return nil
        end,
        write = function(value) return value.width .. "x" .. value.height end,
        looks = "a size like 60x20",
    },
    mode = {
        read = function(text)
            return (text == "newest" or text == "distill") and text or nil
        end,
        write = tostring,
        looks = "newest or distill",
    },
    project = {
        read = function(text)
            local project, commit = string.match(text, "^(%S+) (%x+)$")
            if project and name(project) then
                return { name = project, commit = commit }
            end
            return nil
        end,
        write = function(value) return value.name .. " " .. value.commit end,
        looks = "a name and a commit, like guide-feature 9f2c1e0",
    },
    endpoint = {
        read = function(text)
            local endpoint, address = string.match(text, "^(%S+) (%S+)$")
            if endpoint and name(endpoint) then
                return { name = endpoint, address = address }
            end
            return nil
        end,
        write = function(value) return value.name .. " " .. value.address end,
        looks = "a name and an address, like voice-small http://192.168.1.100:20166",
    },
    voices = {
        read = function(text)
            local list, seen = {}, {}
            for word in string.gmatch(text, "[^ ]+") do
                if not name(word) or seen[word] then
                    return nil
                end
                seen[word] = true
                list[#list + 1] = word
            end
            if #list == 0 or table.concat(list, " ") ~= text then
                return nil
            end
            return list
        end,
        write = function(value) return table.concat(value, " ") end,
        looks = "names separated by one space, none twice",
    },
}
-- }}}

-- {{{ M.SETS
-- Which headers each direction carries, in order (docs/canvas-format.md).
M.SETS = {
    ["to-voices"]   = { "canvas", "size", "mode", "project", "endpoint", "written" },
    ["from-voice"]  = { "voice", "turn", "base", "size", "written" },
    ["for-viewers"] = { "canvas", "size", "mode", "project", "written", "voices" },
}
-- }}}

-- {{{ M.KINDS
M.KINDS = { word = true, sentence = true, orphan = true }
-- }}}

-- {{{ local function row_problem()
-- Why a row cannot be on a canvas `width` wide, or nil. A row holds printable
-- characters only: a tab or other control character has no agreed width, so
-- it is refused rather than counted as one.
local function row_problem(row, width)
    local length, bad_at = utf8.length(row)
    if not length then
        return "is not valid UTF-8 (at byte " .. bad_at .. ")"
    end
    local control = string.find(row, "[%z\1-\31\127]")
    if control then
        return string.format("holds a control character (byte %d, code %d); "
            .. "a row holds printable characters only", control, string.byte(row, control))
    end
    if length > width then
        return string.format("is %d characters, %d over the width of %d",
            length, length - width, width)
    end
    return nil
end
-- }}}

-- {{{ local function mark_problem()
-- Why a mark cannot be on this canvas, or nil.
local function mark_problem(mark, width, height)
    if type(mark.row) ~= "number" or mark.row < 1 or mark.row > height then
        return "its row is not between 1 and " .. height
    end
    if type(mark.column) ~= "number" or mark.column < 1 or mark.column > width then
        return "its column is not between 1 and " .. width
    end
    if type(mark.length) ~= "number" or mark.length < 1
        or mark.column + mark.length - 1 > width then
        return "its length is not at least 1, or runs past the width of " .. width
    end
    if type(mark.voice) ~= "string" or not name(mark.voice) then
        return "its voice is not a name"
    end
    if type(mark.version) ~= "number" or mark.version < 0 then
        return "its version is not a whole number"
    end
    if not M.KINDS[mark.kind] then
        return "its kind is not word, sentence or orphan"
    end
    return nil
end
-- }}}

-- {{{ local function cut_problem()
local function cut_problem(cut, width, height)
    if type(cut.voice) ~= "string" or not name(cut.voice) then
        return "its voice is not a name"
    end
    if type(cut.version) ~= "number" or cut.version < 0 then
        return "its version is not a whole number"
    end
    if type(cut.row) ~= "number" or cut.row < 1 or cut.row > height then
        return "its row is not between 1 and " .. height
    end
    local length = type(cut.text) == "string" and utf8.length(cut.text)
    if not length or length < 1 or string.find(cut.text, "[%z\1-\32\127]") then
        return "its text is not one word of printable characters"
    end
    if type(cut.column) ~= "number" or cut.column < 1 or cut.column + length - 1 > width then
        return "its word does not fit between its column and the width of " .. width
    end
    return nil
end
-- }}}

-- {{{ local function split_lines()
-- The text's lines, numbered from 1. A final newline ends the last line; it
-- does not start an empty one.
local function split_lines(text)
    local lines = {}
    for line in string.gmatch(text, "([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    local tail = string.match(text, "([^\n]+)$")
    if tail then
        lines[#lines + 1] = tail
    end
    return lines
end
-- }}}

-- {{{ local function read_headers()
-- The header block, which must hold exactly the set's headers, in its order,
-- each once, then one blank line. Returns the headers and the next line number.
local function read_headers(lines, set, order, source)
    local position = {}
    for index, header in ipairs(order) do position[header] = index end

    local headers, expected, number = {}, 1, 1
    while true do
        local line = lines[number]
        if line == nil then
            refuse(source, number, "the canvas ends inside its headers")
        end
        if line == "" then
            if expected <= #order then
                refuse(source, number, "the headers end without '" .. order[expected]
                    .. "' (the " .. set .. " headers are: " .. table.concat(order, ", ") .. ")")
            end
            return headers, number + 1
        end
        local header, value = string.match(line, "^([%w%-]+): (.*)$")
        if not header then
            refuse(source, number, "expected a header line `name: value`, found: " .. line)
        end
        if not position[header] then
            refuse(source, number, "'" .. header .. "' is not a " .. set .. " header ("
                .. table.concat(order, ", ") .. ")")
        end
        if headers[header] ~= nil then
            refuse(source, number, "'" .. header .. "' is here a second time")
        end
        if position[header] ~= expected then
            refuse(source, number, "expected '" .. tostring(order[expected]) .. "' here, found '"
                .. header .. "' (the " .. set .. " headers come in this order: "
                .. table.concat(order, ", ") .. ")")
        end
        local parsed = M.HEADERS[header].read(value)
        if parsed == nil then
            refuse(source, number, "'" .. header .. "' should be " .. M.HEADERS[header].looks
                .. "; found: " .. value)
        end
        headers[header], expected, number = parsed, expected + 1, number + 1
    end
end
-- }}}

-- {{{ local function read_mark()
local function read_mark(line, width, height, source, number)
    local row, column, length, voice, version, kind = string.match(line,
        "^mark: (%S+) (%S+) (%S+) (%S+) (%S+) (%S+)$")
    if not row then
        refuse(source, number, "a mark is `mark: ROW COLUMN LENGTH VOICE VERSION KIND`; found: " .. line)
    end
    local mark = { row = whole(row), column = whole(column), length = whole(length),
                   voice = voice, version = whole(version), kind = kind }
    local problem = mark_problem(mark, width, height)
    if problem then
        refuse(source, number, "this mark cannot be on the canvas: " .. problem)
    end
    return mark
end
-- }}}

-- {{{ local function read_cut()
local function read_cut(line, width, height, source, number)
    local voice, version, row, column, text = string.match(line,
        "^cut: (%S+) (%S+) (%S+) (%S+) (%S+)$")
    if not voice then
        refuse(source, number, "a cut is `cut: VOICE VERSION ROW COLUMN TEXT`; found: " .. line)
    end
    local cut = { voice = voice, version = whole(version), row = whole(row),
                  column = whole(column), text = text }
    local problem = cut_problem(cut, width, height)
    if problem then
        refuse(source, number, "this cut cannot be on the canvas: " .. problem)
    end
    return cut
end
-- }}}

-- {{{ function M.read()
-- Text in, a canvas record out, or an error naming the line. `set` is which
-- header set to expect; `source` names the text in errors ("canvas" if left
-- out).
function M.read(text, set, source)
    source = source or "canvas"
    local order = M.SETS[set]
    if not order then
        error("canvas.read: no header set called '" .. tostring(set) .. "'", 2)
    end
    if type(text) ~= "string" then
        error("canvas.read: the canvas is not text", 2)
    end
    local lines = split_lines(text)
    local headers, number = read_headers(lines, set, order, source)
    local width, height = headers.size.width, headers.size.height

    -- {{{ the rows
    local rows, saw_marks_row = {}, nil
    for index = 1, height do
        local row = lines[number]
        if row == nil then
            refuse(source, number, "the canvas ends after " .. (index - 1) .. " of its "
                .. height .. " rows")
        end
        local problem = row_problem(row, width)
        if problem then
            refuse(source, number, "row " .. index .. " " .. problem)
        end
        if row == "marks:" then saw_marks_row = number end
        rows[index] = utf8.pad(row, width)
        number = number + 1
    end
    if lines[number] ~= "marks:" then
        refuse(source, number, "expected `marks:` after the " .. height .. " rows, found: "
            .. tostring(lines[number] or "the end of the canvas")
            .. (saw_marks_row and (" (line " .. saw_marks_row
                .. " reads `marks:`; are there fewer rows than the size's "
                .. height .. "?)") or ""))
    end
    number = number + 1
    -- }}}

    local record = { set = set, headers = headers, width = width, height = height,
                     rows = rows, marks = {} }

    -- {{{ the marks, and the cuts
    if set == "from-voice" then
        record.ignored_marks = 0
    end
    while lines[number] ~= nil and lines[number] ~= "cuts:" do
        local line = lines[number]
        if set == "from-voice" then
            if string.sub(line, 1, 6) ~= "mark: " then
                refuse(source, number, "expected a `mark:` line or the end; found: " .. line)
            end
            record.ignored_marks = record.ignored_marks + 1
        else
            record.marks[#record.marks + 1] = read_mark(line, width, height, source, number)
        end
        number = number + 1
    end
    if lines[number] == "cuts:" then
        if set ~= "to-voices" then
            refuse(source, number, "only a canvas sent to the voices has a `cuts:` section")
        end
        record.cuts = {}
        number = number + 1
        while lines[number] ~= nil do
            record.cuts[#record.cuts + 1] = read_cut(lines[number], width, height, source, number)
            number = number + 1
        end
    end
    -- }}}
    return record
end
-- }}}

-- {{{ function M.write()
-- A canvas record in, its text out: the headers of its set in order, a blank
-- line, the rows without trailing spaces, `marks:` and its lines, and, for a
-- canvas to the voices that has them, `cuts:` and its lines. Every line ends
-- with a newline. The size header is written from width and height. A record
-- that could not be read back the same is refused, so a mistake shows here and
-- not on another machine.
function M.write(record, set)
    set = set or record.set
    local order = M.SETS[set]
    if not order then
        error("canvas.write: no header set called '" .. tostring(set) .. "'", 2)
    end
    local width, height = record.width, record.height
    if type(width) ~= "number" or type(height) ~= "number" or width < 1 or height < 1
        or #record.rows ~= height then
        error("canvas.write: the record's width, height and number of rows disagree", 2)
    end

    local out = {}
    for _, header in ipairs(order) do
        local value = record.headers[header]
        if header == "size" then
            value = { width = width, height = height }
        end
        if value == nil then
            error("canvas.write: the record has no '" .. header .. "' header", 2)
        end
        local written = M.HEADERS[header].write(value)
        if M.HEADERS[header].read(written) == nil then
            error("canvas.write: '" .. header .. "' would not read back: " .. written, 2)
        end
        out[#out + 1] = header .. ": " .. written
    end
    out[#out + 1] = ""

    for index, row in ipairs(record.rows) do
        local trimmed = string.gsub(row, " +$", "")
        local problem = row_problem(trimmed, width)
        if problem then
            error("canvas.write: row " .. index .. " " .. problem, 2)
        end
        out[#out + 1] = trimmed
    end

    out[#out + 1] = "marks:"
    for index, mark in ipairs(record.marks or {}) do
        local problem = mark_problem(mark, width, height)
        if problem then
            error("canvas.write: mark " .. index .. " cannot be on the canvas: " .. problem, 2)
        end
        out[#out + 1] = string.format("mark: %d %d %d %s %d %s", mark.row, mark.column,
            mark.length, mark.voice, mark.version, mark.kind)
    end

    if record.cuts ~= nil then
        if set ~= "to-voices" then
            error("canvas.write: only a canvas sent to the voices has cuts", 2)
        end
        out[#out + 1] = "cuts:"
        for index, cut in ipairs(record.cuts) do
            local problem = cut_problem(cut, width, height)
            if problem then
                error("canvas.write: cut " .. index .. " cannot be on the canvas: " .. problem, 2)
            end
            out[#out + 1] = string.format("cut: %s %d %d %d %s", cut.voice, cut.version,
                cut.row, cut.column, cut.text)
        end
    end
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ function M.blank()
-- An empty canvas record of a size, for a set: rows of spaces, no marks.
-- The blitter starts from one (107); the headers are the caller's to fill.
function M.blank(width, height, set)
    local rows = {}
    for index = 1, height do rows[index] = string.rep(" ", width) end
    return { set = set, headers = {}, width = width, height = height,
             rows = rows, marks = {} }
end
-- }}}

return M
