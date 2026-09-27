-- 055-updating.lua
--
-- Handling every waiting request, one at a time (docs/008). A request waits
-- from its `request-received` line until a `request-done` or
-- `request-failed` line. For each, in order:
--
--   not yet graded      locate it, grade it, record the grade (the person
--                       sees output/<request>.grade before anything else)
--   graded at or above  hold it: `held`, and move on — until the person
--   the case's hold     runs `update --go`
--   otherwise           amend the blueprint (with the way back), then
--                       rebuild the reach; all built -> request-done
--
-- Requests are never merged: each is located against the blueprint as the
-- last one left it, so each finishes before the next begins.

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local graph = require("043-the-graph")
local grading = require("053-grading")
local amending = require("054-amending")
local building = require("050-building")
local workflows = require("063-workflows")

local updating = {}

-- {{{ function updating.waiting
-- Requests received and not yet done or failed, oldest first: array of
-- { name, seq (of its request-received line) }.
function updating.waiting(lines)
    local received, finished = {}, {}
    for _, line in ipairs(lines) do
        if line.kind == "request-received" and not received[line.about] then
            received[line.about] = line.seq
        elseif line.kind == "request-done" or line.kind == "request-failed" then
            finished[line.about] = true
        end
    end
    local out = {}
    for name, seq in pairs(received) do
        if not finished[name] then
            out[#out + 1] = { name = name, seq = seq }
        end
    end
    table.sort(out, function(a, b) return a.seq < b.seq end)
    return out
end
-- }}}

-- {{{ local function current_graph
local function current_graph(record)
    return graph.build((text_tables.read(record.blueprint .. "/outline.tsv")))
end
-- }}}

-- {{{ function updating.step
-- `options`: go (boolean: proceed past the hold), order (function(waiting)
-- -> waiting, phase 7's center), pool (pool options), limit.
-- Returns an array of { name, grade, outcome, reach, report } where outcome
-- is "done", "held", "failed".
function updating.step(project, record, options)
    options = options or {}
    local lines = ledger.read(record.ledger)
    local waiting = updating.waiting(lines)
    if options.order then
        waiting = options.order(waiting)
    end
    local hold_depth = grading.DEPTH[record.hold or "foundation"] or grading.DEPTH.foundation

    -- {{{ local function handle
    -- One request, start to end; returns its result.
    local function handle(request)
        local index = ledger.index(ledger.read(record.ledger))
        local g = current_graph(record)
        local grade, touched, new_phases, reach
        if ledger.has(index, "graded", request) then
            grade, touched, new_phases, reach = grading.parse_graded(index.graded[request].text)
        else
            local ok, t, n = pcall(grading.locate, project, record, g, request, options.pool)
            if not ok then
                -- A breach stops the whole run; a locate that never gave a
                -- usable answer fails only this request.
                if tostring(t):find("wrote outside", 1, true) then
                    error(t, 0)
                end
                ledger.append(record.ledger, "request-failed", request, tostring(t))
                return { name = request, outcome = "failed", why = tostring(t) }
            end
            touched, new_phases = t, n
            grade, reach = grading.grade(g, touched, new_phases)
            grading.record(record, request, grade, touched, new_phases, reach, #g.ids)
        end
        -- The hold: "none" holds nothing; "middle" holds middle and
        -- foundation; "foundation" holds foundation only.
        if hold_depth > 0 and grading.DEPTH[grade] >= hold_depth and not options.go then
            if not ledger.has(index, "held", request) then
                ledger.append(record.ledger, "held", request, grade .. ": waiting for `update --go`")
            end
            return { name = request, grade = grade, outcome = "held", reach = reach }
        end
        local amended = amending.amend(project, record, request, touched, options.pool)
        if not amended.ok then
            ledger.append(record.ledger, "request-failed", request, "the blueprint could not be amended: " .. amended.findings)
            return { name = request, grade = grade, outcome = "failed", why = amended.findings }
        end
        -- The referees are written again from the amended blueprint, so the
        -- rebuilt design is checked against the changed behaviour (506).
        local refereed = workflows.write(project, record, building.target_text(record), options.pool)
        if not refereed.ok then
            ledger.append(record.ledger, "request-failed", request, "the workflows could not be rewritten: " .. refereed.findings)
            return { name = request, grade = grade, outcome = "failed", why = refereed.findings }
        end
        -- The reach is taken again on the amended blueprint: an amend may
        -- add issues, and those must be built too.
        local amended_graph = current_graph(record)
        local rebuild = graph.reach(amended_graph, touched)
        local report = building.step(project, record, {
            rebuild = rebuild, order = options.build_order, pool = options.pool, limit = options.limit,
        })
        if #report.failed == 0 and #report.held == 0 then
            ledger.append(record.ledger, "request-done", request,
                grade .. "; rebuilt " .. #report.built .. " of " .. #amended_graph.ids .. " issues")
            return { name = request, grade = grade, outcome = "done", reach = rebuild, report = report }
        end
        ledger.append(record.ledger, "request-failed", request,
            "the rebuild left " .. #report.failed .. " failed and " .. #report.held .. " held")
        return { name = request, grade = grade, outcome = "failed", reach = rebuild, report = report }
    end
    -- }}}

    local results = {}
    for _, w in ipairs(waiting) do
        results[#results + 1] = handle(w.name)
    end
    return results
end
-- }}}

return updating
