-- 085-the-lesson.lua
--
-- One lesson: a turning point's own record (docs/069, issue 1002a). Every
-- field is required, and a mechanism must read as a short, single-sentence
-- form (`a builder grading its own work passes itself`) — this is the
-- shape check alone; 1002c's mood-vs-mechanism judgement tightens it
-- further once it is built.

local fs = require("017-the-filesystem")

local lesson = {}

lesson.FIELDS = { "case", "ledger_lines", "what_happened", "mechanism" }

-- A mechanism reads short: one sentence, not a paragraph — the house's own
-- example ("a builder grading its own work passes itself") is six words.
local MAX_MECHANISM_WORDS = 20

-- {{{ local function is_short_sentence
local function is_short_sentence(text)
    if text:find("\n") then
        return false
    end
    local words = 0
    for _ in text:gmatch("%S+") do
        words = words + 1
    end
    return words > 0 and words <= MAX_MECHANISM_WORDS
end
-- }}}

-- {{{ function lesson.build
-- fields: case (string), ledger_lines (array of numbers), what_happened
-- (string), mechanism (string). Refuses a missing field by name, and a
-- mechanism that does not read as a short sentence.
function lesson.build(fields)
    for _, name in ipairs(lesson.FIELDS) do
        if fields[name] == nil then
            error("lesson.build: missing field '" .. name .. "'")
        end
    end
    if not is_short_sentence(fields.mechanism) then
        error("lesson.build: mechanism must be a short sentence (at most "
            .. MAX_MECHANISM_WORDS .. " words, one line), got: " .. tostring(fields.mechanism))
    end
    return {
        case = fields.case,
        ledger_lines = fields.ledger_lines,
        what_happened = fields.what_happened,
        mechanism = fields.mechanism,
    }
end
-- }}}

-- {{{ local function ledger_lines_text
-- ledger_lines {12, 13} reads as "12, 13" -- prose for the story file, not a
-- data format. Nothing yet parses this file back into lesson tables; that
-- reader is a later piece (1002d's own note on this).
local function ledger_lines_text(ledger_lines)
    local parts = {}
    for i, n in ipairs(ledger_lines) do
        parts[i] = tostring(n)
    end
    return table.concat(parts, ", ")
end
-- }}}

-- {{{ function lesson.append
-- Appends one already-built lesson (the shape lesson.build returns) to
-- `path` as a new Markdown section. Same discipline as the ledger's append
-- (016) -- open for append only, one write() call, the file is never
-- opened for reading and never rewritten -- but without the ledger's
-- hash-chaining: a lesson does not need to prove its place in a sequence,
-- only that nothing already on disk is ever touched. Makes the file's
-- folder if this is the first lesson written to it.
function lesson.append(path, one)
    local folder = path:match("^(.*)/[^/]*$")
    if folder then
        fs.make_folder(folder)
    end
    local block = string.format(
        "## %s (ledger lines %s)\n\n%s\n\nMechanism: %s\n\n",
        one.case, ledger_lines_text(one.ledger_lines), one.what_happened, one.mechanism
    )
    local file = assert(io.open(path, "ab"))
    file:write(block)
    file:close()
    return one
end
-- }}}

return lesson
