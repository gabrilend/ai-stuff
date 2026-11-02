-- 085-the-lesson.lua
--
-- One lesson: a turning point's own record (docs/069, issue 1002a). Every
-- field is required, and a mechanism must read as a short, single-sentence
-- form (`a builder grading its own work passes itself`) that names an actor
-- and what followed, not a mood (`the build was bad`) -- issue 1002c. The
-- mood check is mechanical, from closed word lists below: counted, not
-- judged, like everything else the story does with mechanisms.

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

-- The mood check (1002c). A mood says how something was ("the build was
-- bad"); a mechanism says what someone does and what follows from it ("a
-- builder grading its own work passes itself"). Closed lists, so the check
-- is the same every time and a refusal can say exactly why.
lesson.MIN_MECHANISM_WORDS = 3

-- Words that pass a verdict instead of naming what happened.
lesson.JUDGEMENT_WORDS = {}
for word in ([[bad good poor terrible awful horrible wrong broken messy
    sloppy flaky ugly great fine ok okay nice fragile buggy unstable careless
    lazy weird confusing hard difficult slow failed fails failing broke
    worked works sad unlucky luck]]):gmatch("%S+") do
    lesson.JUDGEMENT_WORDS[word] = true
end

-- Words that link a subject to a verdict ("was bad", "felt off").
local COPULAS = {}
for word in ("is was were are be been being went got gets felt feels seemed seems looked looks"):gmatch("%S+") do
    COPULAS[word] = true
end

-- Words that carry no actor and no consequence on their own.
local FILLER = {}
for word in ([[a an the this that these those it its everything something
    nothing things stuff all very really so too quite pretty just not never
    always and or but]]):gmatch("%S+") do
    FILLER[word] = true
end

-- {{{ local function words_of
local function words_of(text)
    local words = {}
    for word in text:lower():gmatch("[%a']+") do
        words[#words + 1] = word
    end
    return words
end
-- }}}

-- {{{ function lesson.mood_of
-- Why `text` reads as a mood rather than a mechanism, or nil when it names
-- an actor and what followed. Three shapes are refused: too few words to
-- name both; a verdict after a linking word ("the build was bad", "the
-- tests were not good"); and a sentence that ends on a verdict or holds
-- nothing but verdicts and filler ("everything broke", "bad").
function lesson.mood_of(text)
    local words = words_of(text)
    if #words < lesson.MIN_MECHANISM_WORDS then
        return "too few words to name an actor and what followed"
    end
    for i, word in ipairs(words) do
        if COPULAS[word] then
            local j = i + 1
            while words[j] and FILLER[words[j]] do
                j = j + 1
            end
            if words[j] and lesson.JUDGEMENT_WORDS[words[j]] then
                return "a verdict ('" .. word .. " " .. words[j] .. "'), not what happened"
            end
        end
    end
    if lesson.JUDGEMENT_WORDS[words[#words]] then
        return "it ends on a verdict ('" .. words[#words] .. "'), not on what followed"
    end
    for _, word in ipairs(words) do
        if not (FILLER[word] or COPULAS[word] or lesson.JUDGEMENT_WORDS[word]) then
            return nil
        end
    end
    return "nothing but verdicts, with no actor in it"
end
-- }}}

-- {{{ function lesson.build
-- fields: case (string), ledger_lines (array of numbers), what_happened
-- (string), mechanism (string). Refuses a missing field by name, a
-- mechanism that does not read as a short sentence, and one that reads as a
-- mood rather than a mechanism (`mood_of`) -- the lesson is sent back.
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
    local mood = lesson.mood_of(fields.mechanism)
    if mood then
        error("lesson.build: the mechanism reads as a mood, not a mechanism (" .. mood
            .. "); name who does what and what follows, as in 'a builder grading its own"
            .. " work passes itself', got: " .. fields.mechanism)
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

-- {{{ function lesson.read
-- Every lesson in a file `append` wrote, back as lesson records (`build`'s
-- shape), in the order they were appended; a file not yet written holds
-- none. Each one is rebuilt through `build`, so a lesson edited by hand into
-- a mood is refused here too, naming its place. The reader 1002d's counter
-- was waiting for: `mechanism_counts.from_lessons(lesson.read(path))`.
function lesson.read(path)
    local file = io.open(path, "rb")
    if not file then
        return {}
    end
    local text = file:read("*a")
    file:close()
    local lessons = {}
    -- Each section runs from its "## " heading to the next one.
    local start = text:find("## ", 1, true)
    while start do
        local after = text:find("\n## ", start, true)
        local section = text:sub(start + 3, after or #text)
        local case_name, lines_text = section:match("^(.-) %(ledger lines ([%d, ]*)%)\n")
        local mechanism = section:match("\nMechanism: ([^\n]*)%s*$")
        if not case_name or not mechanism then
            error("lesson.read: lesson " .. (#lessons + 1) .. " of " .. path .. " is not in append's form")
        end
        local body = section:match("^[^\n]*\n\n(.-)\n\nMechanism: [^\n]*%s*$") or ""
        local ledger_lines = {}
        for n in lines_text:gmatch("%d+") do
            ledger_lines[#ledger_lines + 1] = tonumber(n)
        end
        local ok, built = pcall(lesson.build, {
            case = case_name, ledger_lines = ledger_lines,
            what_happened = body, mechanism = mechanism,
        })
        if not ok then
            error("lesson.read: lesson " .. (#lessons + 1) .. " of " .. path .. ": " .. tostring(built))
        end
        lessons[#lessons + 1] = built
        start = after and after + 1
    end
    return lessons
end
-- }}}

return lesson
