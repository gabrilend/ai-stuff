-- 046-the-blueprint-commands.lua
--
-- The blueprint's rows in the command table (docs/012): `describe` plans the
-- outline (if the ledger has no `outlined` line) and then writes every issue
-- not yet described; `graph` prints the blueprint's levels.

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local outline = require("042-the-outline")
local graph = require("043-the-graph")
local describing = require("045-describing")
local center = require("058-the-center")

local commands = {}

-- {{{ function commands.outline_rows
-- The outline's rows, whether just planned or planned in an earlier run.
function commands.outline_rows(project, record, options)
    local index = ledger.index(ledger.read(record.ledger))
    if ledger.has(index, "outlined", "-") then
        return (text_tables.read(record.blueprint .. "/outline.tsv"))
    end
    if not fs.exists(record.survey .. "/files.tsv") then
        error("describe: the case has not been surveyed; run `survey " .. record.name .. "` first")
    end
    return outline.step(project, record, options)
end
-- }}}

-- {{{ function commands.marks
-- A mark per issue from the ledger, for the graph view: described, built,
-- failed, held.
function commands.marks(record)
    local index = ledger.index(ledger.read(record.ledger))
    local marks = {}
    -- Later marks win: a built issue is shown built, not merely described.
    for _, kind in ipairs({ "described", "describe-failed", "built", "build-failed" }) do
        for about in pairs(index[kind] or {}) do
            marks[about] = kind
        end
    end
    return marks
end
-- }}}

commands.rows = {
    describe = {
        needs_case = true,
        usage = "<case>",
        what = "plan the outline, then write every issue file",
        run = function(run)
            -- Every turn is handed the center's paragraph (phase 7).
            local guided = center.options_for(run.case)
            local rows = commands.outline_rows(run.project, run.case, guided.pool)
            local report = describing.step(run.project, run.case, rows, guided.pool)
            local g = graph.build(rows)
            run.say(graph.text(g, commands.marks(run.case)))
            run.say(string.format("described %d, failed %d, %d turns",
                #report.described, #report.failed, report.turns))
            run.done[#run.done + 1] = string.format("described %d issues in %d turns", #report.described, report.turns)
            for _, id in ipairs(report.failed) do
                run.failed[#run.failed + 1] = "issue " .. id .. " could not be described"
            end
        end,
    },
    graph = {
        needs_case = true,
        usage = "<case>",
        what = "print the blueprint's graph, level by level",
        run = function(run)
            local rows = text_tables.read(run.case.blueprint .. "/outline.tsv")
            run.say(graph.text(graph.build(rows), commands.marks(run.case)))
        end,
    },
}

return commands
