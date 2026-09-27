-- 061-the-center-commands.lua
--
-- The last rows of the command table (docs/012): `center` computes and
-- prints the center; `run` does whatever the case is waiting for, start to
-- end; `view` writes the case's HTML page.

local ledger = require("016-ledger")
local center = require("058-the-center")
local running = require("059-running")
local viewer = require("060-the-case-viewer")

return {
    center = {
        needs_case = true,
        usage = "<case>",
        what = "compute and print the center (the case's personality)",
        run = function(run)
            local c = center.compute(ledger.read(run.case.ledger))
            run.say(center.write_view(run.case, c))
            run.say(center.paragraph(c, run.case))
            run.done[#run.done + 1] = "center computed from " .. c.lines .. " ledger lines"
        end,
    },
    run = {
        needs_case = true,
        usage = "<case>",
        what = "do whatever the case is waiting for, start to end",
        run = function(run)
            local steps = running.waiting_steps(run.case)
            if #steps == 0 then
                run.say("nothing is waiting: the case is surveyed, described, built, and every request is handled or held for you")
                run.done[#run.done + 1] = "nothing was waiting"
                return
            end
            local done = running.run(run.project, run.case, run.say)
            for _, d in ipairs(done) do
                if d.ok then
                    run.done[#run.done + 1] = d.step .. ": " .. d.sentence
                else
                    run.failed[#run.failed + 1] = d.step .. " could not finish: " .. d.sentence
                end
            end
            for _, w in ipairs(running.waiting_steps(run.case)) do
                run.waiting[#run.waiting + 1] = "still waiting: " .. w
            end
        end,
    },
    view = {
        needs_case = true,
        usage = "<case>",
        what = "write the case as one HTML page (view.html)",
        run = function(run)
            local path = viewer.write(run.case)
            run.say(path)
            run.done[#run.done + 1] = "wrote " .. path
        end,
    },
}
