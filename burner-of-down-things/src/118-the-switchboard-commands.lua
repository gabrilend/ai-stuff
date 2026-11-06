-- 118-the-switchboard-commands.lua
--
-- The switchboard's row in the command table (docs/012, docs/068):
-- `number` prints the next free tag number -- the one to write into
-- `language model prompt <number>: <what is wanted>`. Numbers are given by
-- the machine, never chosen by whoever writes the tag (issue 901c). It
-- records nothing: a number is recorded only when a parcel first uses it.

local numbers = require("117-tag-numbers")

return {
    number = {
        needs_case = false,
        usage = "",
        what = "print the next free tag number for a parcel",
        run = function(run)
            local n = numbers.next_free(run.project)
            run.say("language model prompt ", n, ": <what is wanted>")
            run.done[#run.done + 1] = "the next free tag number is " .. n
        end,
    },
}
