-- 049-turn-prompt.lua - the conversation a voice's turn begins with.
--
-- In plain terms: at the start of a turn the voice's model is told who it is,
-- the rules (change as little as possible, single words before sentences,
-- the operative words first), the canvas's exact size and the recommended
-- change counts, how to look into the project, and then the canvas itself,
-- with a ruler of column numbers above it and row numbers beside it so the
-- model can see where words sit (docs/datapath-voice-turn.md, step 4). The
-- words are not in this file: they are in input/turn-instructions, with
-- markers this fills in, so the owner can change how the voices are spoken
-- to without touching source. (issue 403)
--
--   local prompt = dofile(DIR .. "/src/049-turn-prompt.lua")
--   local text = prompt.read_instructions(root)        -- input/turn-instructions
--   local conversation = prompt.build({
--       instructions = text, canvas = record, voice = "fg-sora-1", turn = 7,
--       recommended = { words = 12, sentences = 1 }, look_limit = 3,
--       note = "last turn you changed ...",             -- or nil
--   })
--   -- { { role = "system", content = ... }, { role = "user", content = ... } }
--
-- The ruler is drawn here and recognised here, so the two cannot drift:
--   prompt.ruler(record)          -- the canvas as the model sees it
--   prompt.ruler_problem(reply)   -- { kind = "ruler" } when a reply copied it
-- and so is the look call's form, a line the turn recognises in a reply
-- (open question 3, answered for now in issue 403):
--   prompt.look_call(reply)       -- { focus = "focused"|"broad", words } or nil
--
-- Every refusal is a Lua error naming input/turn-instructions and its line.
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local utf8 = dofile(DIR .. "/src/005-utf8.lua")
local fit = dofile(DIR .. "/src/012-fit-check.lua")
local shape = dofile(DIR .. "/src/027-exact-shape.lua")

local M = {}

M.SOURCE = "input/turn-instructions"

-- {{{ M.PARTS and M.MARKERS
-- The file's three parts, and the markers each may hold. A marker anywhere
-- else, or one not listed, is refused, so a misspelt marker is never sent to
-- a model as it is.
M.PARTS = { "system", "user", "look" }
M.MARKERS = {
    voice = true, width = true, height = true, words = true, sentences = true,
    version = true, ["look-limit"] = true, look = true, shape = true, note = true,
    cuts = true, canvas = true,
}
-- Each part must hold these, or the model would not see what it needs.
M.REQUIRED = {
    system = { "width", "height", "words", "sentences" },
    user = { "canvas" },
    look = {},
}
-- }}}

-- {{{ local function fail()
local function fail(line, text)
    error(M.SOURCE .. (line and (":" .. line) or "") .. ": " .. text, 0)
end
-- }}}

-- {{{ function M.read_instructions()
-- The instruction file's text, from a project root.
function M.read_instructions(root)
    local handle = io.open(root .. "/" .. M.SOURCE, "rb")
    if not handle then
        fail(nil, "there is no instruction file; the turn's words live there (issue 403)")
    end
    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

-- {{{ function M.parse()
-- The instruction text as its parts: { system = text, user = text, look =
-- text }, comments dropped, each part's leading and trailing blank lines
-- trimmed. Refused: text before the first part, an unknown or repeated part,
-- a missing part, an unknown marker, a part without a marker it needs.
function M.parse(text)
    local parts, lines_of, current, seen = {}, {}, nil, {}
    local number = 0
    for line in (text .. (text:sub(-1) == "\n" and "" or "\n")):gmatch("([^\n]*)\n") do
        number = number + 1
        line = line:gsub("\r$", "")
        local name = line:match("^%[([%w%-]+)%]%s*$")
        if name then
            local known = false
            for _, part in ipairs(M.PARTS) do known = known or part == name end
            if not known then
                fail(number, "[" .. name .. "] is not a part; the parts are [system], [user] and [look]")
            end
            if seen[name] then fail(number, "[" .. name .. "] is given twice") end
            seen[name], current = number, name
            lines_of[name] = {}
        elseif not line:match("^#") then
            if not current then
                if line:match("%S") then
                    fail(number, "text before the first part; start with [system]")
                end
            else
                for marker in line:gmatch("{{([^}]*)}}") do
                    if not M.MARKERS[marker] then
                        fail(number, "{{" .. marker .. "}} is not a marker this file can use")
                    end
                end
                if line:match("{{[^}]*$") or line:match("^[^{]*}}") then
                    fail(number, "a marker is not closed: markers are written {{name}}")
                end
                table.insert(lines_of[current], line)
            end
        end
    end
    for _, part in ipairs(M.PARTS) do
        if not lines_of[part] then fail(nil, "there is no [" .. part .. "] part") end
        local body = table.concat(lines_of[part], "\n"):gsub("^%s*\n", ""):gsub("%s+$", "")
        for _, needed in ipairs(M.REQUIRED[part]) do
            if not body:find("{{" .. needed .. "}}", 1, true) then
                fail(seen[part], "the [" .. part .. "] part has no {{" .. needed .. "}}")
            end
        end
        parts[part] = body
    end
    return parts
end
-- }}}

-- {{{ local function fill()
-- A part with its markers filled from `values`. A marker alone on its line
-- that is filled with nothing takes its line with it; runs of blank lines
-- are then closed up to one, so a missing note leaves no gap.
local function fill(body, values)
    local out = {}
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        local alone = line:match("^%s*{{([^}]+)}}%s*$")
        if not (alone and values[alone] == "") then
            out[#out + 1] = (line:gsub("{{([^}]+)}}", function(marker)
                return values[marker]
            end))
        end
    end
    local text = table.concat(out, "\n")
    text = text:gsub("\n\n\n+", "\n\n")
    return (text:gsub("^\n+", ""):gsub("\n+$", ""))
end
-- }}}

-- {{{ function M.ruler()
-- The canvas as the model is shown it: every row padded to the width, between
-- a | on each side, numbered on the left; above it, the column numbers, read
-- downwards (hundreds when the canvas is that wide, then tens, then ones).
--
--         |         1         2
--         |12345678901234567890
--       1 |the kitten  on the  |
--       2 |mat.                |
function M.ruler(record)
    local width, height = record.width, record.height
    local label = #tostring(height)
    local blank = string.rep(" ", label) .. " |"
    local lines = {}
    local places = width >= 100 and { 100, 10, 1 } or (width >= 10 and { 10, 1 } or { 1 })
    for _, place in ipairs(places) do
        local digits = {}
        for column = 1, width do
            if place == 1 then
                digits[column] = tostring(column % 10)
            elseif column % place == 0 or (place == 100 and column >= 100 and column % 10 == 0) then
                digits[column] = tostring(math.floor(column / place) % 10)
            else
                digits[column] = " "
            end
        end
        lines[#lines + 1] = (blank .. table.concat(digits)):gsub("%s+$", "")
    end
    for row = 1, height do
        lines[#lines + 1] = string.format("%" .. label .. "d |%s|", row,
            utf8.pad(record.rows[row], width))
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.ruler_problem()
-- A problem { kind = "ruler", rows = {...} } when a reply copied the ruler:
-- a column-number line (it holds "1234567890", or is only digits and spaces
-- after a |), a row that begins with a number and " |", or a row between a
-- | at each end. nil otherwise. The fit check reports it with its other problems (404).
function M.ruler_problem(reply)
    local found = {}
    for number, line in ipairs(fit.lines_of(reply)) do
        local labelled = line:match("^%s*(%d+) |")
        if (labelled and tonumber(labelled) >= 1)
            or line:find("1234567890", 1, true)
            or line:match("^%s*|[%d%s]+$")
            or line:match("^|.*|%s*$") then
            found[#found + 1] = number
        end
    end
    if #found == 0 then return nil end
    return { kind = "ruler", rows = found }
end
-- }}}

-- {{{ function M.look_call()
-- A reply that is a look call: one line, "look focused: WORDS" or "look
-- broad: WORDS" (any case, spaces around), and nothing else but blank lines.
-- Returns { focus, words } or nil. A canvas that merely has such a line among
-- its rows is not a look call.
function M.look_call(reply)
    local lines = {}
    for _, line in ipairs(fit.lines_of(reply)) do
        if line:match("%S") then lines[#lines + 1] = line end
    end
    if #lines ~= 1 then return nil end
    local focus, words = lines[1]:lower():match("^%s*look%s+(%a+)%s*:%s*(.-)%s*$")
    if (focus == "focused" or focus == "broad") and words ~= "" then
        return { focus = focus, words = lines[1]:match(":%s*(.-)%s*$") }
    end
    return nil
end
-- }}}

-- {{{ local function cuts_text()
-- This voice's own cut lines (the words its last edit cut, under
-- tell-the-voice), as sentences.
local function cuts_text(record, voice)
    local lines = {}
    for _, cut in ipairs(record.cuts or {}) do
        if cut.voice == voice then
            lines[#lines + 1] = string.format('Your edit at version %d cut the word "%s" '
                .. "at row %d, column %d.", cut.version, cut.text, cut.row, cut.column)
        end
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function whole()
local function whole(value)
    return type(value) == "number" and value >= 0 and value == math.floor(value)
end
-- }}}

-- {{{ function M.build()
-- The conversation: a system turn and a user turn, each { role, content }, in
-- the order of docs/datapath-voice-turn.md, step 4. opts:
--   instructions  the instruction file's text (read_instructions)
--   canvas        the to-voices canvas record (006)
--   voice         this voice's name
--   turn          this voice's turn number (seeds the exact-shape example)
--   recommended   { words, sentences }, whole numbers
--   look_limit    look calls this turn may make; 0 leaves the look part out
--   note          last turn's advisory note (012's advice), or nil or false
function M.build(opts)
    local record = opts.canvas
    if type(record) ~= "table" or not record.rows or not record.width then
        error("prompt.build: canvas is not a canvas record", 2)
    end
    if type(opts.voice) ~= "string" or opts.voice == "" then
        error("prompt.build: voice is not a name", 2)
    end
    local recommended = opts.recommended
    if type(recommended) ~= "table" or not whole(recommended.words)
        or not whole(recommended.sentences) then
        error("prompt.build: recommended must be { words = N, sentences = N }", 2)
    end
    if not whole(opts.turn) or not whole(opts.look_limit) then
        error("prompt.build: turn and look_limit must be whole numbers", 2)
    end
    local parts = M.parse(opts.instructions)

    local values = {
        voice = opts.voice,
        width = tostring(record.width),
        height = tostring(record.height),
        words = tostring(recommended.words),
        sentences = tostring(recommended.sentences),
        version = tostring(record.headers and record.headers.canvas or "?"),
        ["look-limit"] = tostring(opts.look_limit),
        shape = shape.EXAMPLE_LINE .. ":\n\n"
            .. table.concat(shape.example(record.width, record.height, opts.turn), "\n"),
        note = opts.note or "",
        cuts = cuts_text(record, opts.voice),
        canvas = M.ruler(record),
    }
    values.look = opts.look_limit > 0 and fill(parts.look, values) or ""
    return {
        { role = "system", content = fill(parts.system, values) },
        { role = "user", content = fill(parts.user, values) },
    }
end
-- }}}

return M
