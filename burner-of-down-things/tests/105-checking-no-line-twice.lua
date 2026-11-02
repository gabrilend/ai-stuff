-- 105-checking-no-line-twice.lua
--
-- Checks issue 1001c: every chapter's first line names the ledger line
-- numbers it tells; no line is told twice across two tellings; telling an
-- unchanged ledger again adds nothing; what is told is never rewritten; a
-- ledger that does not verify is never told.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local ledger = require("016-ledger")
local story = require("103-the-story")

local folder = kit.scratch("no-line-twice")
local ledger_path = folder .. "/ledger"
local story_path = folder .. "/output/story/notes.md"

ledger.create(ledger_path, "case notes opened on /src/notes")
ledger.append(ledger_path, "surveyed", "-", "12 files, 2 languages")
ledger.append(ledger_path, "turn-started", "0001-outline-notes", "outline notes by stand-in")
ledger.append(ledger_path, "turn-ended", "0001-outline-notes", "kept: exit 0; 1 file(s) changed")
ledger.append(ledger_path, "outlined", "-", "3 issues, attempt 1")
ledger.append(ledger_path, "described", "101", "attempt 1")
ledger.append(ledger_path, "goodbye", "-", "describe: ok")

local first = story.tell(ledger_path, story_path, "notes")
local after_first = kit.fs.read(story_path)

kit.equal(#first.chapters, 3, "the first telling has three chapters (opened, surveyed, described)")
kit.equal(first.told_through, 6, "the first telling tells through the last turning point")
kit.equal(#first.waiting, 1, "the trailing goodbye waits, untold")
kit.check(after_first:find("^# The story of notes\n") ~= nil, "the first telling writes the title")

-- {{{ local function chapter_ranges
-- Every chapter heading's line range, read from the file itself, and the
-- first line under each heading.
local function chapter_ranges(text)
    local ranges = {}
    for heading in text:gmatch("\n(## Chapter [^\n]*)") do
        local a, b = heading:match("%(ledger lines (%d+)%-(%d+)%)$")
        ranges[#ranges + 1] = { heading = heading, first = tonumber(a), last = tonumber(b) }
    end
    return ranges
end
-- }}}

for _, r in ipairs(chapter_ranges(after_first)) do
    kit.check(r.first ~= nil and r.last ~= nil,
        "the chapter's first line names the ledger lines it tells: " .. r.heading)
end

local again = story.tell(ledger_path, story_path, "notes")
kit.equal(#again.chapters, 0, "telling an unchanged ledger again adds no chapter")
kit.equal(kit.fs.read(story_path), after_first, "telling an unchanged ledger again leaves the file as it was")

-- The ledger grows; the story grows with it, from where it left off.
ledger.append(ledger_path, "request-received", "tags.txt", "noticed in input/")
ledger.append(ledger_path, "turn-started", "0002-build-101", "build 101 by stand-in")
ledger.append(ledger_path, "turn-ended", "0002-build-101", "kept: exit 0; 2 file(s) changed")
ledger.append(ledger_path, "built", "101", "acceptance passed")

local second = story.tell(ledger_path, story_path, "notes")
local after_second = kit.fs.read(story_path)

kit.equal(#second.chapters, 2, "the second telling adds the request and the build")
kit.equal(second.chapters[1].first, 7, "the second telling starts with the goodbye that was waiting")
kit.equal(after_second:sub(1, #after_first), after_first, "what was told is never rewritten")
kit.equal(select(2, after_second:gsub("\n# The story", "")) + (after_second:find("^# The story") and 1 or 0), 1,
    "the title is written once")

local told = {}
local twice = false
for _, r in ipairs(chapter_ranges(after_second)) do
    for seq = r.first, r.last do
        if told[seq] then twice = true end
        told[seq] = true
    end
end
kit.check(not twice, "no ledger line is told twice across two tellings")
local all_told = true
for seq = 1, 11 do
    if not told[seq] then all_told = false end
end
kit.check(all_told, "every line up to the last turning point is told")
kit.check(after_second:find("## Chapter 5: built (ledger lines 9-11)", 1, true) ~= nil,
    "chapters keep counting across tellings")

-- A ledger that does not verify is never told.
local text = kit.fs.read(ledger_path)
kit.write_file(ledger_path, (text:gsub("acceptance passed", "acceptance pa55ed")))
kit.raises(function() story.tell(ledger_path, story_path, "notes") end, "story.tell",
    "a broken ledger is refused, not told")

kit.finish()
