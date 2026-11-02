-- 107-the-story-commands.lua
--
-- The story's row in the command table (docs/012, docs/069): `story` tells
-- the case's ledger lines not yet told as new chapters of
-- output/story/<case>.md and prints where the story is. Run it again after
-- more has happened and only the new lines are told.

local story = require("103-the-story")

return {
    story = {
        needs_case = true,
        usage = "<case>",
        what = "tell the ledger's untold lines as chapters (output/story/)",
        run = function(run)
            local path = story.path_for(run.case)
            local told = story.tell(run.case.ledger, path, run.case.name)
            run.say(path)
            local sentence = #told.chapters .. " new chapter(s), told through ledger line " .. told.told_through
            run.say(sentence)
            run.done[#run.done + 1] = "story: " .. sentence
            if #told.waiting > 0 then
                run.waiting[#run.waiting + 1] = #told.waiting .. " ledger line(s) wait for the next chapter"
            end
        end,
    },
}
