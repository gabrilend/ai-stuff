-- 102-checking-append-only-lessons.lua
--
-- Checks issue 1002b: lessons are appended to a file, never rewritten --
-- writing a second lesson leaves the first byte-for-byte unchanged.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local lesson = require("085-the-lesson")

local folder = kit.scratch("append-only-lessons")
local path = folder .. "/output/story/lessons.md"

local first = lesson.build({
    case = "notes",
    ledger_lines = { 12, 13 },
    what_happened = "the tags went missing after a repair",
    mechanism = "a builder grading its own work passes itself",
})
lesson.append(path, first)

local after_first = kit.fs.read(path)

local second = lesson.build({
    case = "receipts",
    ledger_lines = { 40 },
    what_happened = "a total was off by a rounding error",
    mechanism = "a formatter rounds before a checker sums",
})
local returned = lesson.append(path, second)

local after_second = kit.fs.read(path)

kit.check(returned == second, "append returns the lesson it was given")
kit.check(#after_second > #after_first, "the second append adds bytes")
kit.equal(after_second:sub(1, #after_first), after_first,
    "the first lesson's bytes are unchanged after a second lesson is appended")
kit.check(after_first:find("a builder grading its own work passes itself", 1, true) ~= nil,
    "the first lesson's mechanism reads back from disk")
kit.check(after_second:find("a formatter rounds before a checker sums", 1, true) ~= nil,
    "the second lesson's mechanism reads back from disk")

kit.finish()
