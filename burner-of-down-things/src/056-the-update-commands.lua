-- 056-the-update-commands.lua
--
-- The update's rows in the command table (docs/012): `update [--go]`
-- handles every waiting request; `grade <request>` locates and grades one
-- request and changes nothing else — the person sees how deep a change goes
-- before deciding to make it.

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local graph = require("043-the-graph")
local grading = require("053-grading")
local updating = require("055-updating")
local center = require("058-the-center")

local commands = {}

commands.rows = {
    update = {
        needs_case = true,
        usage = "<case> [--go]",
        what = "handle waiting requests in input/ (--go: past the hold)",
        run = function(run)
            local go = run.args[1] == "--go"
            -- The center orders the waiting requests and each wave (phase 7).
            local guided = center.options_for(run.case)
            local results = updating.step(run.project, run.case, {
                go = go, order = guided.order, build_order = guided.build_order, pool = guided.pool,
            })
            if #results == 0 then
                run.say("no requests are waiting")
            end
            for _, r in ipairs(results) do
                local line = string.format("%-24s %-10s %s", r.name, r.grade or "-", r.outcome)
                if r.reach then
                    line = line .. "  (reach " .. table.concat(r.reach, " ") .. ")"
                end
                run.say(line)
                if r.outcome == "done" then
                    run.done[#run.done + 1] = "request " .. r.name .. " (" .. r.grade .. ") done"
                elseif r.outcome == "held" then
                    run.waiting[#run.waiting + 1] = "request " .. r.name .. " is " .. r.grade
                        .. "-grade and held; see output/" .. r.name .. ".grade, then run `update "
                        .. run.case.name .. " --go`"
                else
                    run.failed[#run.failed + 1] = "request " .. r.name .. ": " .. tostring(r.why or "the rebuild did not pass")
                end
            end
        end,
    },
    grade = {
        needs_case = true,
        usage = "<case> <request>",
        what = "locate and grade one request; change nothing else",
        run = function(run)
            local request = run.args[1]
            if not request or not fs.exists(run.case.input .. "/" .. request) then
                error("grade needs the name of a request file in " .. run.case.input)
            end
            local index = ledger.index(ledger.read(run.case.ledger))
            if not ledger.has(index, "graded", request) then
                local g = graph.build((text_tables.read(run.case.blueprint .. "/outline.tsv")))
                local touched, new_phases = grading.locate(run.project, run.case, g, request, center.options_for(run.case).pool)
                local grade, reach = grading.grade(g, touched, new_phases)
                grading.record(run.case, request, grade, touched, new_phases, reach, #g.ids)
            end
            run.say(fs.read(run.case.output .. "/" .. request .. ".grade"))
            run.done[#run.done + 1] = "graded " .. request
        end,
    },
}

return commands
