-- 050-building.lua
--
-- Building the blueprint into the design, level by level (docs/007). Each
-- level's wanted issues are one set of build turns; each built issue is
-- checked by running its own acceptance commands; a failure gets a repair
-- turn shown the failing command and its output, up to two; an issue that
-- still fails is build-failed, and everything built on it (its reach) is
-- held for the rest of the run. After every level the acceptance of every
-- issue built so far is run again, because a later build can break an
-- earlier one; anything that now fails is repaired before the next level.
-- When every issue has passed and a final full run passes, the design is
-- checked by the case's workflows (issue 506): end-to-end scripts written
-- from the blueprint alone by a referee turn that never saw the design. The
-- issues' own acceptance commands run tests the builder wrote for itself —
-- useful to the builder, but a referee that shares code with what it checks
-- grades nothing, so delivery trusts the workflows. A failing workflow gets
-- repair turns for the issues it covers; only when every workflow passes is
-- the design delivered, with the ledger's head hash as the fingerprint of
-- its history.
--
-- Which issues are wanted: those with no `built` line, plus a rebuild set
-- (from an update, phase 6) whose `built` lines are stale. Held from the
-- start: the reach of every issue that could not be described.

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local kinds = require("034-turn-kinds")
local pool = require("039-the-turn-pool")
local graph = require("043-the-graph")
local issue_files = require("044-issue-files")
local design_folder = require("048-the-design-folder")
local acceptance = require("049-acceptance")
local workflows = require("063-workflows")

local building = {}

building.MOST_REPAIRS = 2

-- {{{ function building.target_text
-- What the design should be, for the build prompt: the person's words, or
-- "the same kind of software", named by the survey's main language.
function building.target_text(record)
    if record.target and record.target ~= "" then
        return record.target
    end
    local languages = {}
    if fs.exists(record.survey .. "/files.tsv") then
        local lines_by_language = {}
        for _, f in ipairs((text_tables.read(record.survey .. "/files.tsv"))) do
            if f.role == "code" then
                lines_by_language[f.language] = (lines_by_language[f.language] or 0) + tonumber(f.lines)
            end
        end
        for name, lines in pairs(lines_by_language) do
            languages[#languages + 1] = { name = name, lines = lines }
        end
        table.sort(languages, function(a, b) return a.lines > b.lines end)
    end
    local main = languages[1] and languages[1].name or "the same language"
    return "the same kind of software as the one described, written in " .. main
        .. " (the person named no other target)"
end
-- }}}

-- {{{ local function issue_of
local function issue_of(record, id)
    local path = issue_files.find(record.issues, id)
    if not path then
        error("build: issue " .. id .. " has no file in the blueprint")
    end
    return issue_files.read(path)
end
-- }}}

-- {{{ local function blocker_texts
local function blocker_texts(record, node)
    if #node.blocked_by == 0 then
        return "(none: this issue is a foundation)"
    end
    local parts = {}
    for _, b in ipairs(node.blocked_by) do
        parts[#parts + 1] = issue_of(record, b).text
    end
    return table.concat(parts, "\n\n---\n\n")
end
-- }}}

-- {{{ function building.step
-- Builds what is wanted. `options`:
--   rebuild   array of ids to build again even though built
--   order     function(ids) -> ids, the order within a wave (phase 7's center)
--   pool      pool options (harness, size, limit, center)
--   limit     acceptance time limit per command
-- Returns a report: { built = ids, failed = ids, held = ids, turns = n,
-- waves = n, repairs = n, delivered = boolean }.
function building.step(project, record, options)
    options = options or {}
    local rows = text_tables.read(record.blueprint .. "/outline.tsv")
    local g = graph.build(rows)
    design_folder.lay_out(project, record)
    local index = ledger.index(ledger.read(record.ledger))
    local rebuild = {}
    for _, id in ipairs(options.rebuild or {}) do
        rebuild[id] = true
    end
    local built, held = {}, {}
    for _, id in ipairs(g.ids) do
        if ledger.has(index, "built", id) and not rebuild[id] then
            built[id] = true
        end
    end
    local report = { built = {}, failed = {}, held = {}, turns = 0, waves = 0, repairs = 0, delivered = false }
    -- {{{ local function hold_reach
    local function hold_reach(id, why)
        for _, above in ipairs(graph.reach(g, { id })) do
            if above ~= id and not held[above] then
                held[above] = why
                report.held[#report.held + 1] = above
            end
        end
    end
    -- }}}
    for _, id in ipairs(g.ids) do
        if ledger.has(index, "describe-failed", id) and not ledger.has(index, "described", id) then
            held[id] = "it could not be described"
            hold_reach(id, "issue " .. id .. " could not be described")
        end
    end
    local target = building.target_text(record)
    local turn_folder_of = {}
    -- The referees are written before anything is built: they come from the
    -- blueprint alone, and a design with no referees cannot be delivered.
    if not ledger.has(index, "refereed", "-") then
        local written = workflows.write(project, record, target, options.pool)
        report.referee_turns = 1
        report.refereed = written.ok
        report.referee_findings = written.findings
    else
        report.refereed = true
    end

    -- {{{ local function run_turns
    -- Runs build or repair turns for `ids` as one set; returns results by id.
    local function run_turns(kind, ids, failures)
        local turns = {}
        for i, id in ipairs(ids) do
            local issue = issue_of(record, id)
            local values = {
                about = id, target = target, issue_text = issue.text,
                blocker_texts = blocker_texts(record, g.nodes[id]),
            }
            if kind == "repair" then
                values.command = failures[id].command
                values.output = failures[id].output
            end
            turns[i] = kinds.make_turn(record, kind, values)
            turn_folder_of[id] = turns[i].folder
        end
        report.turns = report.turns + #turns
        if kind == "repair" then
            report.repairs = report.repairs + #turns
        end
        local results, summary = pool.run_set(project, record, turns, options.pool)
        if #summary.breaches > 0 then
            error("build: a " .. kind .. " turn wrote outside its folders"
                .. (summary.source_touched and " (into the source)" or "") .. "; stopping")
        end
        local by_id = {}
        for i, id in ipairs(ids) do
            by_id[id] = results[i]
        end
        return by_id
    end
    -- }}}

    -- {{{ local function settle
    -- Accepts, repairs and records a group of ids just built (or found
    -- broken). Each ends built (ledger `built`) or failed (`build-failed`,
    -- its reach held).
    local function settle(ids, turn_results)
        local failing = {}
        for _, id in ipairs(ids) do
            local r = turn_results and turn_results[id]
            if r and r.verdict == "failed" then
                failing[id] = { command = "(the build turn itself)", output = r.why }
            else
                local result = acceptance.run(record, issue_of(record, id), turn_folder_of[id], options.limit)
                if not result.ok then
                    failing[id] = result
                end
            end
        end
        for repair = 1, building.MOST_REPAIRS do
            local ids_to_repair = {}
            for _, id in ipairs(ids) do
                if failing[id] then
                    ids_to_repair[#ids_to_repair + 1] = id
                end
            end
            if #ids_to_repair == 0 then
                break
            end
            local repaired = run_turns("repair", ids_to_repair, failing)
            for _, id in ipairs(ids_to_repair) do
                if repaired[id].verdict == "failed" then
                    failing[id] = { command = "(the repair turn itself)", output = repaired[id].why }
                else
                    local result = acceptance.run(record, issue_of(record, id), turn_folder_of[id], options.limit)
                    failing[id] = (not result.ok) and result or nil
                end
            end
        end
        for _, id in ipairs(ids) do
            if failing[id] then
                built[id] = nil
                ledger.append(record.ledger, "build-failed", id,
                    "`" .. failing[id].command .. "` still fails after " .. building.MOST_REPAIRS .. " repairs")
                report.failed[#report.failed + 1] = id
                held[id] = "its own build failed"
                hold_reach(id, "issue " .. id .. " could not be built")
            else
                built[id] = true
                ledger.append(record.ledger, "built", id, "acceptance passed")
                report.built[#report.built + 1] = id
            end
        end
    end
    -- }}}

    for _, level_ids in ipairs(graph.levels(g)) do
        local wave = {}
        for _, id in ipairs(level_ids) do
            local ready = not built[id] and not held[id]
            for _, b in ipairs(g.nodes[id].blocked_by) do
                if not built[b] then
                    ready = false
                end
            end
            if ready then
                wave[#wave + 1] = id
            end
        end
        if options.order then
            wave = options.order(wave)
        end
        if #wave > 0 then
            report.waves = report.waves + 1
            settle(wave, run_turns("build", wave))
            -- A later build can break an earlier one: check everything built
            -- so far, and repair what broke before moving up a level.
            local broken = {}
            for _, id in ipairs(g.ids) do
                if built[id] and not acceptance.run(record, issue_of(record, id), nil, options.limit).ok then
                    broken[#broken + 1] = id
                end
            end
            if #broken > 0 then
                settle(broken, nil)
            end
        end
    end

    -- Delivered: every issue built, and one last full acceptance run passes.
    local all_built = true
    for _, id in ipairs(g.ids) do
        if not built[id] then
            all_built = false
        end
    end
    if all_built then
        for _, id in ipairs(g.ids) do
            if not acceptance.run(record, issue_of(record, id), nil, options.limit).ok then
                all_built = false
                report.failed[#report.failed + 1] = id
            end
        end
    end
    -- The workflows: the checks delivery trusts. Only run on a design that
    -- has something new in it, or has never been delivered.
    local fresh = report.turns > 0 or not ledger.has(index, "delivered", "-")
    if all_built and not report.refereed then
        all_built = false
    elseif all_built and fresh then
        local failures = workflows.run_all(record, options.limit)
        for round = 1, building.MOST_REPAIRS do
            if #failures == 0 then
                break
            end
            -- Each failing workflow's output goes to the repair of every
            -- issue it covers; the workflow's text does not.
            local to_repair, why = {}, {}
            for _, fail in ipairs(failures) do
                for _, id in ipairs(fail.workflow.covers) do
                    if g.nodes[id] and not why[id] then
                        why[id] = { command = "the end-to-end workflow " .. fail.workflow.name, output = fail.output }
                        to_repair[#to_repair + 1] = id
                    end
                end
            end
            table.sort(to_repair)
            run_turns("repair", to_repair, why)
            failures = workflows.run_all(record, options.limit)
        end
        report.workflow_failures = failures
        if #failures > 0 then
            all_built = false
            for _, fail in ipairs(failures) do
                ledger.append(record.ledger, "workflow-failed", fail.workflow.name,
                    "covers " .. table.concat(fail.workflow.covers, " ") .. "; still failing after "
                    .. building.MOST_REPAIRS .. " rounds of repair")
            end
        else
            -- A repair made for a workflow can break an issue's own checks.
            for _, id in ipairs(g.ids) do
                if not acceptance.run(record, issue_of(record, id), nil, options.limit).ok then
                    all_built = false
                    report.failed[#report.failed + 1] = id
                end
            end
        end
    end
    -- A run that built nothing new over an already-delivered design delivers
    -- nothing new: another `delivered` line would claim a history event that
    -- did not happen.
    if all_built and report.turns == 0 and ledger.has(index, "delivered", "-") then
        report.delivered = true
        report.head = ledger.head(record.ledger)
        report.already = true
    elseif all_built then
        local turns_spent = 0
        for _, name in ipairs(fs.list(record.turns)) do
            if name:match("^%d%d%d%d%-") then turns_spent = turns_spent + 1 end
        end
        local line = ledger.append(record.ledger, "delivered", "-",
            #g.ids .. " issues built; " .. turns_spent .. " turns spent on this case")
        fs.write(record.output .. "/delivered", table.concat({
            "delivered: " .. record.design,
            "issues:    " .. #g.ids,
            "turns:     " .. turns_spent .. " on this case so far",
            "ledger:    line " .. line.seq .. ", head " .. line.hash,
            "",
            "The head hash is the fingerprint of the history that produced this",
            "design: `machine ledger " .. record.name .. "` shows it, and any change",
            "to that history changes it.",
            "",
        }, "\n"))
        report.delivered = true
        report.head = line.hash
    end
    table.sort(report.held)
    report.held_why = held
    return report
end
-- }}}

return building
