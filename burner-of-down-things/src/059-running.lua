-- 059-running.lua
--
-- One command that does whatever a case is waiting for, start to end —
-- *continue until it's built, as the harness would be designed to do.*
-- What is waiting is read from the ledger alone, in the order the work must
-- happen, and the run stops at the first step that cannot finish:
--
--   no `surveyed` line                          survey
--   no `outlined`, or an outline row neither    describe
--     described nor describe-failed
--   an issue neither built nor build-failed,    build
--     or no delivery yet
--   a request received, not done or failed,    update (never past the hold:
--     and not held for the person               only the person says --go)
--
-- Every step takes its order and its paragraph from the center.

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local survey = require("029-the-survey")
local summary = require("030-the-survey-summary")
local outline = require("042-the-outline")
local describing = require("045-describing")
local building = require("050-building")
local updating = require("055-updating")
local center = require("058-the-center")

local running = {}

-- {{{ local function outline_rows
local function outline_rows(record)
    local path = record.blueprint .. "/outline.tsv"
    if not fs.exists(path) then
        return {}
    end
    return (text_tables.read(path))
end
-- }}}

-- {{{ function running.waiting_steps
-- The steps a case is waiting for, from its ledger, in order: an array of
-- step names ("survey", "describe", "build", "update").
function running.waiting_steps(record)
    local lines = ledger.read(record.ledger)
    local index = ledger.index(lines)
    local steps = {}
    -- Requests waiting for the machine: a held request waits for the
    -- person's --go instead, and `run` never gives it.
    local requests_waiting = false
    for _, w in ipairs(updating.waiting(lines)) do
        if not ledger.has(index, "held", w.name) then
            requests_waiting = true
        end
    end
    if not ledger.has(index, "surveyed", "-") then
        steps = { "survey", "describe", "build" }
        if requests_waiting then
            steps[#steps + 1] = "update"
        end
        return steps
    end
    local rows = outline_rows(record)
    local undescribed = not ledger.has(index, "outlined", "-")
    for _, row in ipairs(rows) do
        if not ledger.has(index, "described", row.id) and not ledger.has(index, "describe-failed", row.id) then
            undescribed = true
        end
    end
    if undescribed then
        steps[#steps + 1] = "describe"
    end
    local unbuilt = undescribed or not ledger.has(index, "delivered", "-")
    for _, row in ipairs(rows) do
        if not ledger.has(index, "built", row.id) and not ledger.has(index, "build-failed", row.id) then
            unbuilt = true
        end
    end
    -- A design with failed issues waits for the person, not for another
    -- build: building again would only fail again the same way.
    local any_failed = false
    for _, row in ipairs(rows) do
        if ledger.has(index, "build-failed", row.id) and not ledger.has(index, "built", row.id) then
            any_failed = true
        end
    end
    if unbuilt and not any_failed then
        steps[#steps + 1] = "build"
    end
    if requests_waiting then
        steps[#steps + 1] = "update"
    end
    return steps
end
-- }}}

-- The steps themselves, by name. Each returns a sentence for the goodbye,
-- and whether the run may go on.
running.STEPS = {
    survey = function(project, record, say)
        local counts = survey.run(project, record, nil)
        summary.write(record.survey)
        local sentence = counts.files .. " files, " .. counts.links .. " links"
        ledger.append(record.ledger, "surveyed", "-", sentence)
        return "surveyed: " .. sentence, true
    end,
    describe = function(project, record, say)
        local guided = center.options_for(record)
        local index = ledger.index(ledger.read(record.ledger))
        local rows
        if ledger.has(index, "outlined", "-") then
            rows = outline_rows(record)
        else
            rows = outline.step(project, record, guided.pool)
        end
        local report = describing.step(project, record, rows, guided.pool)
        local sentence = string.format("described %d issues (%d failed) in %d turns",
            #report.described, #report.failed, report.turns)
        return sentence, #report.failed == 0
    end,
    build = function(project, record, say)
        local guided = center.options_for(record)
        local report = building.step(project, record, { pool = guided.pool, order = guided.build_order })
        local sentence = string.format("built %d, failed %d, held %d in %d waves%s",
            #report.built, #report.failed, #report.held, report.waves, report.delivered and "; delivered" or "")
        return sentence, report.delivered
    end,
    update = function(project, record, say)
        local guided = center.options_for(record)
        local results = updating.step(project, record, {
            order = guided.order, build_order = guided.build_order, pool = guided.pool,
        })
        local counts = { done = 0, held = 0, failed = 0 }
        for _, r in ipairs(results) do
            counts[r.outcome] = counts[r.outcome] + 1
        end
        local sentence = string.format("requests: %d done, %d held for the person, %d failed",
            counts.done, counts.held, counts.failed)
        return sentence, counts.failed == 0
    end,
}

-- {{{ function running.run
-- Runs every waiting step in order, stopping at the first that cannot
-- finish. Returns an array of { step, sentence, ok }.
function running.run(project, record, say)
    local done = {}
    local steps = running.waiting_steps(record)
    for _, name in ipairs(steps) do
        say("— " .. name)
        local sentence, ok = running.STEPS[name](project, record, say)
        say("  " .. sentence)
        done[#done + 1] = { step = name, sentence = sentence, ok = ok }
        if not ok then
            break
        end
    end
    center.write_view(record, center.compute(ledger.read(record.ledger)))
    return done
end
-- }}}

return running
