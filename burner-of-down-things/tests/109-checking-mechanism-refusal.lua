-- 109-checking-mechanism-refusal.lua
--
-- Checks issue 1002c: a lesson without a mechanism is sent back -- a mood
-- ("the build was bad") is refused, naming why; a mechanism ("a builder
-- grading its own work passes itself") is kept.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local lesson = require("085-the-lesson")

-- {{{ local function with_mechanism
local function with_mechanism(mechanism)
    return function()
        return lesson.build({
            case = "notes", ledger_lines = { 9 },
            what_happened = "issue 101 could not be built", mechanism = mechanism,
        })
    end
end
-- }}}

local kept = {
    "a builder grading its own work passes itself",
    "a formatter rounds before a checker sums",
    "a locator grades its own answer",
    "a checker fails silently when the input is empty",
    "a referee who saw the design writes checks that agree with it",
}
for _, mechanism in ipairs(kept) do
    local ok, result = pcall(with_mechanism(mechanism))
    kit.check(ok and result.mechanism == mechanism, "a mechanism is kept: " .. mechanism)
end

local moods = {
    { "the build was bad", "'was bad'" },
    { "the tests were not very good", "'were good'" },
    { "everything broke", "too few words" },
    { "the whole repair went wrong", "'went wrong'" },
    { "the build failed", "ends on a verdict" },
    { "sloppy and buggy and broken", "ends on a verdict" },
    { "bad", "too few words" },
    { "it was all just so bad", "'was bad'" },
}
for _, pair in ipairs(moods) do
    kit.raises(with_mechanism(pair[1]), "reads as a mood, not a mechanism",
        "a mood is sent back: " .. pair[1])
    kit.raises(with_mechanism(pair[1]), pair[2], "the refusal says why: " .. pair[1])
end

kit.raises(with_mechanism(nil), "missing field 'mechanism'", "a lesson with no mechanism at all is sent back")
kit.raises(with_mechanism("   "), "short sentence", "a blank mechanism is sent back")
kit.equal(lesson.mood_of("a builder grading its own work passes itself"), nil,
    "mood_of finds nothing wrong with a mechanism")

kit.finish()
