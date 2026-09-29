-- 086-checking-the-lesson.lua
--
-- Checks issue 1002a: a lesson missing any field is refused, naming which.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local lesson = require("085-the-lesson")

local good = lesson.build({
    case = "notes",
    ledger_lines = { 12, 13 },
    what_happened = "the tags went missing after a repair",
    mechanism = "a builder grading its own work passes itself",
})
kit.equal(good.case, "notes", "case is kept")
kit.equal(#good.ledger_lines, 2, "ledger_lines is kept")
kit.equal(good.mechanism, "a builder grading its own work passes itself", "mechanism is kept")

kit.raises(function()
    lesson.build({ ledger_lines = {}, what_happened = "x", mechanism = "a thing happens" })
end, "missing field 'case'", "a lesson missing case is refused, naming it")

kit.raises(function()
    lesson.build({ case = "notes", ledger_lines = {}, what_happened = "x", mechanism = nil })
end, "missing field 'mechanism'", "a lesson missing mechanism is refused, naming it")

kit.raises(function()
    lesson.build({
        case = "notes", ledger_lines = {}, what_happened = "x",
        mechanism = "the build was bad and everyone felt sad about it and nobody really knew quite why or what to do next about it either",
    })
end, "short sentence", "a mechanism longer than 20 words is refused")

kit.finish()
