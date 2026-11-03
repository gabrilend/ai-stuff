-- 112-checking-the-draft-form.lua
--
-- Checks issue 1003b: a strategem drafted from recurring lessons is in the
-- house form (the hand-written strategems' own headings, in their order),
-- and a draft from two lessons names both as examples. Also issue 1003's
-- first test: one lesson drafts nothing; a second of the same mechanism
-- drafts one.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local lesson = require("085-the-lesson")
local drafts = require("111-the-strategem-drafts")

local folder = kit.scratch("draft-form")
local lessons_path = folder .. "/output/story/lessons.md"
local strategems = folder .. "/strategems"
local mechanism = "a builder grading its own work passes itself"

lesson.append(lessons_path, lesson.build({ case = "notes", ledger_lines = { 12, 13 },
    what_happened = "the tags went missing after a repair", mechanism = mechanism }))
lesson.append(lessons_path, lesson.build({ case = "receipts", ledger_lines = { 40 },
    what_happened = "a total was off by a rounding error",
    mechanism = "a formatter rounds before a checker sums" }))

local once = drafts.draft_due(lessons_path, strategems)
kit.equal(#once.drafted, 0, "one lesson of a mechanism drafts nothing")
kit.check(not kit.fs.exists(strategems .. "/drafts"), "and makes no drafts folder")

lesson.append(lessons_path, lesson.build({ case = "receipts", ledger_lines = { 51, 52 },
    what_happened = "the second build passed its own tests and failed the workflow",
    mechanism = mechanism }))

local twice = drafts.draft_due(lessons_path, strategems)
kit.equal(#twice.drafted, 1, "a second lesson of the same mechanism drafts one")
local path = strategems .. "/drafts/a-builder-grading-its-own-work-passes-itself.md"
kit.equal(twice.drafted[1], path, "the draft is named for its mechanism, in strategems/drafts/")

local text = kit.fs.read(path)
kit.check(text:find("^# Strategem %(draft%): A builder grading its own work passes itself\n") ~= nil,
    "the draft's title is the mechanism, marked as a draft")
kit.equal(drafts.mechanism_of(text), mechanism, "the draft records the mechanism it was written for")

-- The hand-written strategems' own headings, in the same order.
local hand = kit.fs.read(kit.DIR .. "/strategems/a-referee-never-sees-the-answer.md")
local function headings(t)
    local out = {}
    for h in t:gmatch("\n(## [^\n]+)") do out[#out + 1] = h end
    return table.concat(out, " | ")
end
kit.equal(headings(text), headings(hand), "the draft has the house form's sections, in the house order")

local examples = text:match("## Examples in this project\n(.-)\n## ")
kit.check(examples and examples:find("**notes, ledger lines 12, 13.** the tags went missing after a repair", 1, true) ~= nil,
    "the draft names the first lesson as an example, with its case and ledger lines")
kit.check(examples and examples:find("**receipts, ledger lines 51, 52.** the second build passed", 1, true) ~= nil,
    "the draft names the second lesson as an example")
kit.check(examples and examples:find("Met 2 times, in 2 cases: notes, receipts.", 1, true) ~= nil,
    "the draft says how often and where the mechanism was met")
kit.check(examples and not examples:find("rounding error", 1, true),
    "a lesson of another mechanism is not among the examples")

kit.finish()
