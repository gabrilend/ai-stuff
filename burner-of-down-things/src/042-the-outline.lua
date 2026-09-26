-- 042-the-outline.lua
--
-- The first step of describing (docs/006, "the outline"): one turn plans the
-- whole blueprint as a table — which issues, in which phases, built on
-- which, covering which source files — and the machine checks the table
-- without a model. Planning everything at once is what lets numbering follow
-- the house rule (foundations low, because others build on them), which a
-- file-by-file description could not know.
--
-- An outline row (docs/002): id, name, blocked_by ("-" or ids separated by
-- spaces), covers ("-" or source paths separated by spaces).

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local kinds = require("034-turn-kinds")
local pool = require("039-the-turn-pool")

local outline = {}

outline.HEADER = { "id", "name", "blocked_by", "covers" }
outline.MOST_ATTEMPTS = 3

-- {{{ function outline.words
-- The space-separated words of a field; "-" and "" mean none.
function outline.words(field)
    local out = {}
    for word in (field or ""):gmatch("%S+") do
        if word ~= "-" then
            out[#out + 1] = word
        end
    end
    return out
end
-- }}}

-- The checks, each a function(rows, survey_rows) -> array of findings
-- (sentences). A dispatch table so each check has a name the ledger can
-- record and a test can aim at.
outline.CHECKS = {
    {
        name = "ids",
        run = function(rows)
            local findings, seen = {}, {}
            for _, row in ipairs(rows) do
                if not row.id:match("^[1-9]%d%d$") then
                    findings[#findings + 1] = "id '" .. row.id .. "' is not a phase digit then two digits"
                elseif seen[row.id] then
                    findings[#findings + 1] = "id " .. row.id .. " appears twice"
                end
                seen[row.id] = true
            end
            if #rows == 0 then
                findings[#findings + 1] = "the outline has no issues"
            end
            return findings
        end,
    },
    {
        name = "names",
        run = function(rows)
            local findings = {}
            for _, row in ipairs(rows) do
                if not row.name:match("^[a-z0-9]+[a-z0-9%-]*$") then
                    findings[#findings + 1] = "issue " .. row.id .. "'s name '" .. row.name
                        .. "' is not lower-case words joined by dashes"
                end
            end
            return findings
        end,
    },
    {
        name = "blockers",
        run = function(rows)
            local findings, ids = {}, {}
            for _, row in ipairs(rows) do
                ids[row.id] = true
            end
            for _, row in ipairs(rows) do
                for _, b in ipairs(outline.words(row.blocked_by)) do
                    if not ids[b] then
                        findings[#findings + 1] = "issue " .. row.id .. " is blocked by " .. b .. ", which is not in the outline"
                    elseif b == row.id then
                        findings[#findings + 1] = "issue " .. row.id .. " is blocked by itself"
                    end
                end
            end
            return findings
        end,
    },
    {
        name = "cycles",
        run = function(rows)
            local blocked_by = {}
            for _, row in ipairs(rows) do
                blocked_by[row.id] = outline.words(row.blocked_by)
            end
            -- Depth-first: a node met again while still on the path closes
            -- a cycle; the path from its first appearance is the cycle.
            local state, path, findings = {}, {}, {}
            -- {{{ local function visit
            local function visit(id)
                if state[id] == "done" or not blocked_by[id] then
                    return
                end
                if state[id] == "on-path" then
                    local cycle = {}
                    local started = false
                    for _, p in ipairs(path) do
                        if p == id then started = true end
                        if started then cycle[#cycle + 1] = p end
                    end
                    cycle[#cycle + 1] = id
                    findings[#findings + 1] = "blockers go round in a circle: " .. table.concat(cycle, " -> ")
                    return
                end
                state[id] = "on-path"
                path[#path + 1] = id
                for _, b in ipairs(blocked_by[id]) do
                    visit(b)
                end
                path[#path] = nil
                state[id] = "done"
            end
            -- }}}
            for _, row in ipairs(rows) do
                visit(row.id)
            end
            return findings
        end,
    },
    {
        name = "coverage",
        run = function(rows, survey_rows)
            local covered, findings = {}, {}
            for _, row in ipairs(rows) do
                for _, p in ipairs(outline.words(row.covers)) do
                    covered[p] = true
                end
            end
            local surveyed = {}
            for _, f in ipairs(survey_rows) do
                surveyed[f.path] = true
                if (f.role == "code" or f.role == "build") and not covered[f.path] then
                    findings[#findings + 1] = "the " .. f.role .. " file " .. f.path .. " is covered by no issue"
                end
            end
            for p in pairs(covered) do
                if not surveyed[p] then
                    findings[#findings + 1] = "an issue covers " .. p .. ", which the survey does not have"
                end
            end
            table.sort(findings)
            return findings
        end,
    },
}

-- {{{ function outline.check
-- Every check's findings, as { name = check name, findings = array }, and
-- whether all passed.
function outline.check(rows, survey_rows)
    local results, all_ok = {}, true
    for _, check in ipairs(outline.CHECKS) do
        local findings = check.run(rows, survey_rows)
        results[#results + 1] = { name = check.name, findings = findings }
        if #findings > 0 then
            all_ok = false
        end
    end
    return results, all_ok
end
-- }}}

-- {{{ function outline.read
-- Reads blueprint/outline.tsv; returns rows, or nil and a finding when the
-- file is missing or not a table of the right shape.
function outline.read(record)
    local path = record.blueprint .. "/outline.tsv"
    if not fs.exists(path) then
        return nil, "no outline was written at " .. path
    end
    local ok, rows, header = pcall(text_tables.read, path)
    if not ok then
        return nil, "the outline is not a well-formed table: " .. tostring(rows)
    end
    if table.concat(header, " ") ~= table.concat(outline.HEADER, " ") then
        return nil, "the outline's header is '" .. table.concat(header, " ") .. "', not '"
            .. table.concat(outline.HEADER, " ") .. "'"
    end
    return rows
end
-- }}}

-- {{{ local function file_table_text
-- The survey's file table as the prompt shows it.
local function file_table_text(survey_rows)
    local lines = {}
    for _, f in ipairs(survey_rows) do
        lines[#lines + 1] = table.concat({ f.path, f.language, f.role, f.lines, f.bytes }, "\t")
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function outline.step
-- Runs outline turns until one passes the checks, up to MOST_ATTEMPTS.
-- Returns the rows. Appends outline-failed per failed attempt and outlined
-- when one passes. A breach stops the step (error).
function outline.step(project, record, options)
    local survey_rows = text_tables.read(record.survey .. "/files.tsv")
    local summary_text = fs.read(record.survey .. "/summary.txt")
    local findings_text = "none"
    for attempt = 1, outline.MOST_ATTEMPTS do
        local turn = kinds.make_turn(record, "outline", {
            about = "-",
            survey_summary = summary_text,
            file_table = file_table_text(survey_rows),
            outline_path = record.blueprint .. "/outline.tsv",
            findings = findings_text,
        })
        local results, summary = pool.run_set(project, record, { turn }, options)
        if results[1].verdict == "breach" then
            error("outline: the outline turn " .. turn.id .. " wrote outside its folders"
                .. (summary.source_touched and " (into the source)" or "") .. "; stopping")
        end
        local problems = {}
        if results[1].verdict == "failed" then
            problems[1] = "the outline turn failed: " .. results[1].why
        else
            local rows, read_problem = outline.read(record)
            if not rows then
                problems[1] = read_problem
            else
                local checks, all_ok = outline.check(rows, survey_rows)
                if all_ok then
                    ledger.append(record.ledger, "outlined", "-", #rows .. " issues, attempt " .. attempt)
                    return rows
                end
                for _, c in ipairs(checks) do
                    for _, f in ipairs(c.findings) do
                        problems[#problems + 1] = c.name .. ": " .. f
                    end
                end
            end
        end
        ledger.append(record.ledger, "outline-failed", "attempt " .. attempt, table.concat(problems, "; "))
        findings_text = table.concat(problems, "\n")
    end
    error("outline: " .. outline.MOST_ATTEMPTS .. " outline turns failed their checks; the last findings:\n"
        .. findings_text)
end
-- }}}

return outline
