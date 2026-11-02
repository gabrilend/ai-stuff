-- 111-the-strategem-drafts.lua
--
-- Strategems drafted from recurring lessons (docs/069, issue 1003). When a
-- mechanism has been counted in two or more lessons (1003a's trigger), the
-- machine writes a draft in the house strategem form (1003b) into
-- strategems/drafts/, one file per mechanism, and a further recurrence
-- rewrites only that draft's list of examples (1003c). A draft becomes a
-- strategem only when the person moves it with the promotion script
-- (1003d); nothing here ever writes outside strategems/drafts/.
--
-- The draft's prose sections -- what it means, the shape, when not to use
-- it -- are left for the person (or, later, a drafting turn) to write:
-- what the machine knows for certain is the mechanism and the lessons
-- where it was met, and those it writes in full.

local fs = require("017-the-filesystem")
local lesson = require("085-the-lesson")
local mechanism_counts = require("095-mechanism-counts")
local strategem_trigger = require("088-the-strategem-trigger")

local drafts = {}

-- What a draft says in each section the machine cannot write itself.
drafts.NOT_YET_WRITTEN = "*Not yet written: the person (or a drafting turn) writes this from the examples below.*"

local EXAMPLES_HEADING = "## Examples in this project"

-- {{{ function drafts.name_for
-- The one-file-per-mechanism naming rule (1003c): the mechanism's words in
-- lower case joined by dashes, as the hand-written strategems are named.
function drafts.name_for(mechanism)
    local words = {}
    for word in mechanism:lower():gmatch("[%w]+") do
        words[#words + 1] = word
    end
    if #words == 0 then
        error("drafts.name_for: a mechanism with no words cannot name a file: " .. tostring(mechanism))
    end
    return table.concat(words, "-") .. ".md"
end
-- }}}

-- {{{ local function capital
local function capital(text)
    return (text:gsub("^%l", string.upper))
end
-- }}}

-- {{{ local function cases_of
-- The distinct cases among some lessons, in the order first met.
local function cases_of(lessons)
    local seen, order = {}, {}
    for _, one in ipairs(lessons) do
        if not seen[one.case] then
            seen[one.case] = true
            order[#order + 1] = one.case
        end
    end
    return order
end
-- }}}

-- {{{ function drafts.examples_text
-- The examples section's body: one entry per lesson, naming its case and
-- ledger lines, then what happened.
function drafts.examples_text(lessons)
    local out = {}
    for _, one in ipairs(lessons) do
        local lines = {}
        for i, n in ipairs(one.ledger_lines) do
            lines[i] = tostring(n)
        end
        local account = one.what_happened:gsub("%s*\n%s*", " ")
        out[#out + 1] = string.format("- **%s, ledger lines %s.** %s", one.case,
            table.concat(lines, ", "), account)
    end
    local cases = cases_of(lessons)
    out[#out + 1] = ""
    out[#out + 1] = string.format("Met %d time%s, in %d case%s: %s.", #lessons, #lessons == 1 and "" or "s",
        #cases, #cases == 1 and "" or "s", table.concat(cases, ", "))
    return table.concat(out, "\n")
end
-- }}}

-- {{{ function drafts.draft_text
-- The draft in the house strategem form (1003b): title, what it is, the
-- mechanism quoted, then what it means, the shape, the examples (with
-- their lessons) and when not to use it -- the same headings as the
-- hand-written strategems.
function drafts.draft_text(mechanism, lessons)
    return table.concat({
        "# Strategem (draft): " .. capital(mechanism),
        "",
        "A strategem is a data flow pattern that recurs across areas of the project",
        "and has proven useful enough to name. This one is a draft: the machine",
        "counted its mechanism in more than one lesson and wrote it down. It becomes",
        "a strategem only when the person moves it out of `drafts/`.",
        "",
        "Mechanism: " .. mechanism,
        "",
        "> " .. mechanism,
        ">",
        "> — counted from output/story/lessons.md",
        "",
        "## What it means",
        "",
        drafts.NOT_YET_WRITTEN,
        "",
        "## The shape",
        "",
        drafts.NOT_YET_WRITTEN,
        "",
        EXAMPLES_HEADING,
        "",
        drafts.examples_text(lessons),
        "",
        "## When not to use it",
        "",
        drafts.NOT_YET_WRITTEN,
        "",
    }, "\n")
end
-- }}}

-- {{{ function drafts.mechanism_of
-- The mechanism a draft (or a promoted strategem) was written for, read
-- from its own `Mechanism:` line; nil for a hand-written strategem.
function drafts.mechanism_of(text)
    return text:match("\nMechanism: ([^\n]+)\n")
end
-- }}}

-- {{{ function drafts.with_examples
-- A draft's text with only its examples section replaced (1003c): every
-- other section -- including anything the person has written -- is kept
-- exactly as it was.
function drafts.with_examples(text, lessons)
    local start = text:find("\n" .. EXAMPLES_HEADING .. "\n", 1, true)
    if not start then
        error("drafts.with_examples: the draft has no '" .. EXAMPLES_HEADING .. "' section")
    end
    local body_start = start + #EXAMPLES_HEADING + 2
    local next_heading = text:find("\n## ", body_start, true)
    local before = text:sub(1, body_start - 1)
    local after = next_heading and text:sub(next_heading) or "\n"
    return before .. "\n" .. drafts.examples_text(lessons) .. "\n" .. after
end
-- }}}

-- {{{ local function markdown_files
local function markdown_files(folder)
    local names = {}
    if fs.is_folder(folder) then
        for _, name in ipairs(fs.list(folder)) do
            if name:match("%.md$") then
                names[#names + 1] = name
            end
        end
    end
    return names
end
-- }}}

-- {{{ function drafts.known
-- Every mechanism already written down, as {[mechanism] = {path, kept}}:
-- drafts in strategems/drafts/ (kept false) and promoted strategems in
-- strategems/ itself (kept true). Hand-written strategems carry no
-- `Mechanism:` line and are not listed.
function drafts.known(strategems_folder)
    local known = {}
    for _, place in ipairs({ { strategems_folder .. "/drafts", false }, { strategems_folder, true } }) do
        for _, name in ipairs(markdown_files(place[1])) do
            local path = place[1] .. "/" .. name
            local mechanism = drafts.mechanism_of(fs.read(path))
            if mechanism then
                known[mechanism] = { path = path, kept = place[2] }
            end
        end
    end
    return known
end
-- }}}

-- {{{ function drafts.draft_due
-- Reads the lessons file, counts mechanisms, and for every mechanism met at
-- least twice: writes a new draft (1003a's trigger says when, 1003b the
-- form), or rewrites an existing draft's examples when more lessons have
-- met it since (1003c). A strategem the person has kept is theirs and is
-- never touched. Returns { drafted, updated, kept } -- arrays of paths: new
-- drafts, drafts whose examples changed, and kept strategems whose
-- mechanism has recurred since (left as the person wrote them).
function drafts.draft_due(lessons_path, strategems_folder)
    local lessons = lesson.read(lessons_path)
    local counts = mechanism_counts.from_lessons(lessons)
    local by_mechanism = {}
    for _, one in ipairs(lessons) do
        by_mechanism[one.mechanism] = by_mechanism[one.mechanism] or {}
        table.insert(by_mechanism[one.mechanism], one)
    end
    local known = drafts.known(strategems_folder)
    local drafted_set = {}
    for mechanism in pairs(known) do
        drafted_set[mechanism] = true
    end
    local result = { drafted = {}, updated = {}, kept = {} }
    local folder = strategems_folder .. "/drafts"
    for _, mechanism in ipairs(strategem_trigger.due(counts, drafted_set)) do
        local path = folder .. "/" .. drafts.name_for(mechanism)
        if fs.exists(path) then
            -- Two mechanisms that differ only in case or punctuation would
            -- share a file; refuse rather than let one overwrite the other.
            error("drafts.draft_due: " .. path .. " is already the draft of another mechanism ("
                .. tostring(drafts.mechanism_of(fs.read(path))) .. "); not overwriting it for: " .. mechanism)
        end
        fs.make_folder(folder)
        fs.write(path, drafts.draft_text(mechanism, by_mechanism[mechanism]))
        result.drafted[#result.drafted + 1] = path
    end
    local mechanisms = {}
    for mechanism in pairs(known) do
        mechanisms[#mechanisms + 1] = mechanism
    end
    table.sort(mechanisms)
    for _, mechanism in ipairs(mechanisms) do
        local place = known[mechanism]
        local met = by_mechanism[mechanism]
        if met then
            if place.kept then
                if #met >= strategem_trigger.RECURRENCE_THRESHOLD then
                    result.kept[#result.kept + 1] = place.path
                end
            else
                local text = fs.read(place.path)
                local new_text = drafts.with_examples(text, met)
                if new_text ~= text then
                    fs.write(place.path, new_text)
                    result.updated[#result.updated + 1] = place.path
                end
            end
        end
    end
    return result
end
-- }}}

-- {{{ function drafts.promote
-- The promotion gate (1003d): moves strategems/drafts/<name> to
-- strategems/<name>, and its title from "Strategem (draft):" to
-- "Strategem:". Only the promotion script calls this, on the person's own
-- command; the drafting above never does. Refuses a name that is not a
-- draft, and a strategem already kept under that name. Returns the kept
-- strategem's path and the sections still marked not yet written.
function drafts.promote(strategems_folder, name)
    if not name:match("%.md$") then
        name = name .. ".md"
    end
    if name:find("/", 1, true) then
        error("drafts.promote: name a draft by its file name alone, got: " .. name)
    end
    local from = strategems_folder .. "/drafts/" .. name
    local to = strategems_folder .. "/" .. name
    if not fs.exists(from) then
        error("drafts.promote: there is no draft " .. from)
    end
    if fs.exists(to) then
        error("drafts.promote: a strategem is already kept at " .. to .. "; not overwriting it")
    end
    local text = fs.read(from)
    local kept_text = text:gsub("^# Strategem %(draft%): ", "# Strategem: ", 1)
    fs.write(to, kept_text)
    assert(os.remove(from))
    local unwritten = {}
    local section = nil
    for line in (kept_text .. "\n"):gmatch("([^\n]*)\n") do
        section = line:match("^## (.+)$") or section
        if line == drafts.NOT_YET_WRITTEN and section then
            unwritten[#unwritten + 1] = section
        end
    end
    return to, unwritten
end
-- }}}

return drafts
