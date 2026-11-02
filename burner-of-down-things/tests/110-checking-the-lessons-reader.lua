-- 110-checking-the-lessons-reader.lua
--
-- Checks the lessons reader 1002d was waiting for: lessons appended to a
-- file read back as the same records, in order, and feed the mechanism
-- counter unchanged -- the same mechanism in two cases counts two, read
-- from the file itself.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local lesson = require("085-the-lesson")
local mechanism_counts = require("095-mechanism-counts")

local folder = kit.scratch("lessons-reader")
local path = folder .. "/output/story/lessons.md"

kit.equal(#lesson.read(path), 0, "a lessons file not yet written holds no lessons")

local written = {
    lesson.build({ case = "notes", ledger_lines = { 12, 13 },
        what_happened = "the tags went missing after a repair",
        mechanism = "a builder grading its own work passes itself" }),
    lesson.build({ case = "receipts", ledger_lines = { 40 },
        what_happened = "a total was off by a rounding error\nfound only by the person",
        mechanism = "a formatter rounds before a checker sums" }),
    lesson.build({ case = "receipts", ledger_lines = { 51, 52, 60 },
        what_happened = "the second build passed its own tests and failed the workflow",
        mechanism = "a builder grading its own work passes itself" }),
}
for _, one in ipairs(written) do
    lesson.append(path, one)
end

local read = lesson.read(path)
kit.equal(#read, 3, "every appended lesson reads back")
for i, one in ipairs(written) do
    local back = read[i] or {}
    kit.equal(back.case, one.case, "lesson " .. i .. "'s case reads back")
    kit.equal(table.concat(back.ledger_lines or {}, ","), table.concat(one.ledger_lines, ","),
        "lesson " .. i .. "'s ledger lines read back")
    kit.equal(back.what_happened, one.what_happened, "lesson " .. i .. "'s account reads back, line breaks and all")
    kit.equal(back.mechanism, one.mechanism, "lesson " .. i .. "'s mechanism reads back")
end

local counts = mechanism_counts.from_lessons(read)
kit.equal(counts["a builder grading its own work passes itself"], 2,
    "the same mechanism in two cases counts two, read from the file")
kit.equal(counts["a formatter rounds before a checker sums"], 1, "a mechanism met once counts one")

-- A lesson edited by hand into a mood is refused on reading, naming its place.
local text = kit.fs.read(path)
kit.write_file(path, (text:gsub("Mechanism: a formatter rounds before a checker sums", "Mechanism: the build was bad")))
kit.raises(function() lesson.read(path) end, "lesson 2 of", "a hand-edited mood is refused on reading, naming the lesson")

kit.finish()
