-- 031-the-survey-commands.lua
--
-- The survey's rows in the command table (docs/012): `survey` reads a case's
-- source into its survey/ folder and writes the summary; `summary` rebuilds
-- and prints the summary from the tables alone.

local ledger = require("016-ledger")
local survey = require("029-the-survey")
local summary = require("030-the-survey-summary")

return {
    survey = {
        needs_case = true,
        usage = "<case> [threads]",
        what = "read the source into survey/ (every core unless told)",
        run = function(run)
            local threads = tonumber(run.args[1])
            local started = os.clock()
            local wall_start = os.time()
            local counts = survey.run(run.project, run.case, threads)
            local text = summary.write(run.case.survey)
            local sentence = string.format("%d files, %d links, %d threads, %.2fs cpu, %ds wall",
                counts.files, counts.links, counts.threads, os.clock() - started, os.time() - wall_start)
            ledger.append(run.case.ledger, "surveyed", "-", sentence)
            run.say(text)
            run.say("surveyed: ", sentence)
            run.done[#run.done + 1] = "surveyed: " .. sentence
        end,
    },
    summary = {
        needs_case = true,
        usage = "<case>",
        what = "rebuild and print the survey summary from its tables",
        run = function(run)
            run.say(summary.write(run.case.survey))
            run.done[#run.done + 1] = "summary rebuilt"
        end,
    },
}
