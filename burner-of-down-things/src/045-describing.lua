-- 045-describing.lua
--
-- Writing every issue file of the blueprint, many turns at once (docs/006).
-- Every outline row not yet described gets one describe turn; they all run
-- as one set. Each file that comes back is checked (044) — its own shape,
-- then the house validator once the whole set is back, since an issue's
-- blockers must exist as files before a link to them can be checked. A
-- failing issue gets a new turn told what was wrong, up to three turns per
-- issue; the third failure is recorded as describe-failed and everything
-- built on it will be held.

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local kinds = require("034-turn-kinds")
local pool = require("039-the-turn-pool")
local outline = require("042-the-outline")
local issue_files = require("044-issue-files")

local describing = {}

describing.MOST_ATTEMPTS = 3

-- {{{ local function outline_text
local function outline_text(record)
    return fs.read(record.blueprint .. "/outline.tsv")
end
-- }}}

-- {{{ local function covered_text
-- The covered files with their survey rows, for the prompt.
local function covered_text(row, survey_by_path)
    local lines = {}
    for _, p in ipairs(outline.words(row.covers)) do
        local f = survey_by_path[p]
        if f then
            lines[#lines + 1] = string.format("%s  (%s, %s lines)", p, f.language, f.lines)
        else
            lines[#lines + 1] = p
        end
    end
    if #lines == 0 then
        return "(no source files: this piece is described from the others)"
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function describing.issue_path
function describing.issue_path(record, row)
    return record.issues .. "/" .. row.id .. "-" .. row.name .. ".md"
end
-- }}}

-- {{{ function describing.step
-- Describes every outline row that has no `described` line yet. Returns
-- { described = array of ids, failed = array of ids, turns = count }.
function describing.step(project, record, rows, options)
    local survey_rows = text_tables.read(record.survey .. "/files.tsv")
    local survey_by_path = {}
    for _, f in ipairs(survey_rows) do
        survey_by_path[f.path] = f
    end
    local index = ledger.index(ledger.read(record.ledger))
    local pending, findings = {}, {}
    for _, row in ipairs(rows) do
        if not ledger.has(index, "described", row.id) then
            pending[#pending + 1] = row
            findings[row.id] = "none"
        end
    end
    local report = { described = {}, failed = {}, turns = 0 }
    local whole_outline = outline_text(record)
    for attempt = 1, describing.MOST_ATTEMPTS do
        if #pending == 0 then
            break
        end
        local turns = {}
        for i, row in ipairs(pending) do
            turns[i] = kinds.make_turn(record, "describe", {
                about = row.id, name = row.name,
                blocked_by = row.blocked_by == "" and "-" or row.blocked_by,
                covered_files = covered_text(row, survey_by_path),
                issue_path = describing.issue_path(record, row),
                outline_text = whole_outline,
                findings = findings[row.id],
            })
        end
        report.turns = report.turns + #turns
        local results, summary = pool.run_set(project, record, turns, options)
        if summary.breaches and #summary.breaches > 0 then
            error("describe: a describe turn wrote outside its folders"
                .. (summary.source_touched and " (into the source)" or "") .. "; stopping")
        end
        -- First each file's own shape; then, with every file of the set on
        -- disk, the house validator.
        local still = {}
        for i, row in ipairs(pending) do
            local problems = {}
            local path = describing.issue_path(record, row)
            if results[i].verdict == "failed" then
                problems[1] = "the describe turn failed: " .. results[i].why
            elseif not fs.exists(path) then
                problems[1] = "no issue file was written at " .. path
            else
                local ok, issue = pcall(issue_files.read, path)
                if not ok then
                    problems[1] = tostring(issue)
                else
                    for _, f in ipairs(issue_files.check(issue, row)) do
                        problems[#problems + 1] = f
                    end
                end
            end
            if #problems == 0 then
                for _, f in ipairs(issue_files.validate(project.validate_issues, record.blueprint, path)) do
                    problems[#problems + 1] = f
                end
            end
            if #problems == 0 then
                ledger.append(record.ledger, "described", row.id, "attempt " .. attempt)
                report.described[#report.described + 1] = row.id
            else
                findings[row.id] = table.concat(problems, "\n")
                if attempt == describing.MOST_ATTEMPTS then
                    ledger.append(record.ledger, "describe-failed", row.id, table.concat(problems, "; "))
                    report.failed[#report.failed + 1] = row.id
                else
                    still[#still + 1] = row
                end
            end
        end
        pending = still
    end
    return report
end
-- }}}

return describing
