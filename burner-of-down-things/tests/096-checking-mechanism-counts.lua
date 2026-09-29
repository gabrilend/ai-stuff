-- 096-checking-mechanism-counts.lua
--
-- Checks issue 1002d: the same mechanism in two cases counts two. Then
-- proves the strategem this piece follows: its output feeds 1003a's
-- trigger unchanged.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local lesson = require("085-the-lesson")
local mechanism_counts = require("095-mechanism-counts")
local trigger = require("088-the-strategem-trigger")

local shared_mechanism = "a builder grading its own work passes itself"

local lessons = {
    lesson.build({
        case = "notes", ledger_lines = { 4 }, what_happened = "a build turn's own test passed a quiet bug",
        mechanism = shared_mechanism,
    }),
    lesson.build({
        case = "second-case", ledger_lines = { 9 }, what_happened = "a repair's own check missed the same shape of bug",
        mechanism = shared_mechanism,
    }),
    lesson.build({
        case = "notes", ledger_lines = { 11 }, what_happened = "a locate turn touched an issue the request never mentioned",
        mechanism = "a locator grades its own answer",
    }),
}

local counts = mechanism_counts.from_lessons(lessons)
kit.equal(counts[shared_mechanism], 2, "the same mechanism in two cases counts two")
kit.equal(counts["a locator grades its own answer"], 1, "a mechanism seen once counts one")

-- Strategem check: 1003a was built against "any counts table shaped like
-- 1002d's own output" before 1002d existed. The real counts, unchanged,
-- feed it directly.
local due = trigger.due(counts)
kit.equal(#due, 1, "only the recurring mechanism is due for a strategem draft")
kit.equal(due[1], shared_mechanism, "the due mechanism is the one that recurred")

kit.finish()
