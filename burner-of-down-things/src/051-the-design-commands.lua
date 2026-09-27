-- 051-the-design-commands.lua
--
-- The design's row in the command table (docs/012): `build` lays out the
-- design folder the first time, builds every issue not yet built wave by
-- wave, and says whether the design was delivered.

local text_tables = require("014-text-tables")
local graph = require("043-the-graph")
local blueprint_commands = require("046-the-blueprint-commands")
local building = require("050-building")
local center = require("058-the-center")

return {
    build = {
        needs_case = true,
        usage = "<case>",
        what = "build every issue not yet built, wave by wave",
        run = function(run)
            -- The center orders each wave and speaks to every turn (phase 7).
            local guided = center.options_for(run.case)
            local report = building.step(run.project, run.case, { pool = guided.pool, order = guided.build_order })
            local rows = text_tables.read(run.case.blueprint .. "/outline.tsv")
            run.say(graph.text(graph.build(rows), blueprint_commands.marks(run.case)))
            run.say(string.format("built %d, failed %d, held %d; %d waves, %d turns (%d repairs)",
                #report.built, #report.failed, #report.held, report.waves, report.turns, report.repairs))
            if report.delivered then
                run.say("delivered: " .. run.case.design .. (report.already and " (no change since the last delivery)" or ""))
                run.done[#run.done + 1] = "design delivered, ledger head " .. report.head
            end
            for _, id in ipairs(report.failed) do
                run.failed[#run.failed + 1] = "issue " .. id .. " could not be built"
            end
            for _, id in ipairs(report.held) do
                run.waiting[#run.waiting + 1] = "issue " .. id .. " is held: " .. tostring(report.held_why[id])
            end
        end,
    },
}
