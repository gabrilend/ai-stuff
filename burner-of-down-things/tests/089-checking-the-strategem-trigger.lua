-- 089-checking-the-strategem-trigger.lua
--
-- Checks issue 1003a: one lesson drafts nothing; a second of the same
-- mechanism drafts one.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local trigger = require("088-the-strategem-trigger")

kit.equal(#trigger.due({ ["a builder grading its own work passes itself"] = 1 }), 0,
    "a mechanism seen once is not due")

local due = trigger.due({
    ["a builder grading its own work passes itself"] = 2,
    ["a referee that shares code with the design grades nothing"] = 1,
})
kit.equal(#due, 1, "only the mechanism seen twice is due")
kit.equal(due[1], "a builder grading its own work passes itself", "the due mechanism is named")

local already_drafted = trigger.due(
    { ["a builder grading its own work passes itself"] = 3 },
    { ["a builder grading its own work passes itself"] = true }
)
kit.equal(#already_drafted, 0, "an already-drafted mechanism is never due again")

kit.finish()
