-- 113-checking-the-drafts-folder.lua
--
-- Checks issue 1003c: one draft per mechanism, never duplicated -- a third
-- lesson of an already-drafted mechanism updates that draft's example list
-- rather than creating a second file, and keeps what the person wrote in
-- the draft's other sections.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local lesson = require("085-the-lesson")
local drafts = require("111-the-strategem-drafts")

local folder = kit.scratch("drafts-folder")
local lessons_path = folder .. "/output/story/lessons.md"
local strategems = folder .. "/strategems"
local mechanism = "a builder grading its own work passes itself"

kit.equal(drafts.name_for("A builder, grading its own work, passes itself!"),
    "a-builder-grading-its-own-work-passes-itself.md", "a draft's name is its mechanism's words, joined by dashes")

-- {{{ local function add
local function add(case_name, lines, what)
    lesson.append(lessons_path, lesson.build({ case = case_name, ledger_lines = lines,
        what_happened = what, mechanism = mechanism }))
end
-- }}}

add("notes", { 12 }, "the tags went missing after a repair")
add("receipts", { 40 }, "the build passed its own tests and failed the workflow")
local first = drafts.draft_due(lessons_path, strategems)
kit.equal(#first.drafted, 1, "two lessons draft one strategem")
local path = first.drafted[1]

-- The person writes into the draft's own sections before the next recurrence.
local text = kit.fs.read(path)
local written = "Whoever checks a piece of work must not be the one who made it."
text = text:gsub("(## What it means\n\n)[^\n]*", "%1" .. written, 1)
kit.write_file(path, text)

local unchanged = drafts.draft_due(lessons_path, strategems)
kit.equal(#unchanged.drafted + #unchanged.updated, 0, "running again with no new lessons changes nothing")
kit.equal(kit.fs.read(path), text, "and leaves the draft byte for byte as it was")

add("ledgers", { 7, 8 }, "a repair turn wrote the test it then passed")
local third = drafts.draft_due(lessons_path, strategems)
kit.equal(#third.drafted, 0, "a third lesson of a drafted mechanism writes no second draft")
kit.equal(#third.updated, 1, "it updates the existing draft instead")
kit.equal(#kit.fs.list(strategems .. "/drafts"), 1, "the drafts folder still holds one file for the mechanism")

local after = kit.fs.read(path)
kit.check(after:find("**ledgers, ledger lines 7, 8.** a repair turn wrote the test", 1, true) ~= nil,
    "the third lesson is among the draft's examples")
kit.check(after:find("Met 3 times, in 3 cases: notes, receipts, ledgers.", 1, true) ~= nil,
    "the draft's count of where it was met is updated")
kit.check(after:find(written, 1, true) ~= nil, "what the person wrote in the draft is kept")
kit.equal(after:match("^(.-)## Examples"), text:match("^(.-)## Examples"),
    "everything before the examples is unchanged")
kit.equal(after:match("(\n## When not to use it.*)$"), text:match("(\n## When not to use it.*)$"),
    "everything after the examples is unchanged")

-- Two mechanisms that differ only in punctuation would share a file: refused.
lesson.append(lessons_path, lesson.build({ case = "a", ledger_lines = { 1 }, what_happened = "x",
    mechanism = "a builder, grading its own work, passes itself" }))
lesson.append(lessons_path, lesson.build({ case = "b", ledger_lines = { 2 }, what_happened = "y",
    mechanism = "a builder, grading its own work, passes itself" }))
kit.raises(function() drafts.draft_due(lessons_path, strategems) end, "already the draft of another mechanism",
    "a second mechanism that would share a draft's file is refused, not written over it")

kit.finish()
