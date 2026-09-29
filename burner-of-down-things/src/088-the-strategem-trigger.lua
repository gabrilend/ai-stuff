-- 088-the-strategem-trigger.lua
--
-- When a mechanism's count reaches two, a draft is triggered (docs/069,
-- issue 1003a) — reading the count, not judging it. Takes any mechanism-
-- count table shaped like 1002d's own output, so it does not have to wait
-- for 1002d to be built.

local strategem_trigger = {}

-- A mechanism met once is an observation; met twice, a pattern (docs/069:
-- "a mechanism recurs; a mood does not").
strategem_trigger.RECURRENCE_THRESHOLD = 2

-- {{{ function strategem_trigger.due
-- counts: {[mechanism] = how many times it has been seen}. drafted: a set
-- of mechanisms already drafted ({[mechanism] = true}, or nil for none).
-- Returns the sorted array of mechanisms newly due for a draft: counted at
-- least twice, and not already drafted.
function strategem_trigger.due(counts, drafted)
    drafted = drafted or {}
    local due = {}
    for mechanism, count in pairs(counts) do
        if count >= strategem_trigger.RECURRENCE_THRESHOLD and not drafted[mechanism] then
            due[#due + 1] = mechanism
        end
    end
    table.sort(due)
    return due
end
-- }}}

return strategem_trigger
