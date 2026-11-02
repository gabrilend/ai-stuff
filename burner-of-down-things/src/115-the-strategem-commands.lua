-- 115-the-strategem-commands.lua
--
-- The strategems' row in the command table (docs/012, docs/069):
-- `strategems` reads the project's lessons file, and for every mechanism
-- met in two or more lessons writes or refreshes its draft in
-- strategems/drafts/. It never promotes a draft: that is the person's own
-- step, scripts/116-promote-strategem.lua.

local drafts = require("111-the-strategem-drafts")

return {
    strategems = {
        needs_case = false,
        usage = "",
        what = "draft strategems from recurring lessons (strategems/drafts/)",
        run = function(run)
            local lessons_path = run.project.output .. "/story/lessons.md"
            local result = drafts.draft_due(lessons_path, run.project.dir .. "/strategems")
            for _, path in ipairs(result.drafted) do
                run.say("drafted ", path)
            end
            for _, path in ipairs(result.updated) do
                run.say("new examples in ", path)
            end
            for _, path in ipairs(result.kept) do
                run.say("met again, kept by you and left as you wrote it: ", path)
            end
            local sentence = string.format("%d drafted, %d drafts given new examples",
                #result.drafted, #result.updated)
            run.say(sentence)
            run.done[#run.done + 1] = "strategems: " .. sentence
            for _, path in ipairs(result.drafted) do
                run.waiting[#run.waiting + 1] = "a draft for you to keep, change or leave: " .. path
            end
        end,
    },
}
