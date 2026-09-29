-- 085-the-lesson.lua
--
-- One lesson: a turning point's own record (docs/069, issue 1002a). Every
-- field is required, and a mechanism must read as a short, single-sentence
-- form (`a builder grading its own work passes itself`) — this is the
-- shape check alone; 1002c's mood-vs-mechanism judgement tightens it
-- further once it is built.

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

return lesson
