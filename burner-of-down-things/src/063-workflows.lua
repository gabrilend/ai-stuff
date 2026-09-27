-- 063-workflows.lua
--
-- The design's referees (issue 506). A referee turn reads the blueprint and
-- nothing else, and writes end-to-end workflows into the case's workflows/
-- folder: shell scripts that use the design the way a person would and
-- check only what a person could see. They live outside the design folder,
-- so no build or repair turn can touch them without a breach, and the
-- builder never sees them — it is graded on the behaviour the blueprint
-- describes, not on a test it could teach itself to pass.
--
-- > Protocols, not procedures. — the owner, 2026-09-27
--
-- A workflow: `NN-<name>.sh`, run with bash from the design folder, exit 0
-- when the behaviour holds; a `# covers: <ids>` line among its first five
-- names the issues it exercises. Before a set of workflows is accepted each
-- one is run against an empty folder and must fail there: a workflow that
-- passes with nothing built checks nothing.

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local kinds = require("034-turn-kinds")
local pool = require("039-the-turn-pool")
local issue_files = require("044-issue-files")

local workflows = {}

workflows.MOST_ATTEMPTS = 3
workflows.LIMIT = 120

-- {{{ function workflows.list
-- The workflows in the case: array of { name, path, covers (array of ids) },
-- by name.
function workflows.list(record)
    fs.make_folder(record.workflows)
    local out = {}
    for _, name in ipairs(fs.list(record.workflows)) do
        if name:match("^%d%d%-.+%.sh$") then
            local path = record.workflows .. "/" .. name
            local covers = {}
            local n = 0
            for line in io.lines(path) do
                n = n + 1
                local ids = line:match("^#%s*covers:%s*(.*)$")
                if ids then
                    for id in ids:gmatch("%d%d%d") do covers[#covers + 1] = id end
                end
                if n >= 5 then break end
            end
            out[#out + 1] = { name = name, path = path, covers = covers }
        end
    end
    return out
end
-- }}}

-- {{{ function workflows.run_one
-- Runs one workflow from `folder` (the design, or an empty folder for the
-- teeth check). Returns ok (boolean), output (last lines), status.
function workflows.run_one(workflow, folder, limit)
    local out, ok, status = fs.capture("cd " .. fs.quote(folder) .. " && timeout --kill-after=5 "
        .. tostring(limit or workflows.LIMIT) .. " bash " .. fs.quote(workflow.path) .. " 2>&1")
    local lines = {}
    for line in out:gmatch("[^\n]+") do lines[#lines + 1] = line end
    local tail = table.concat(lines, "\n", math.max(1, #lines - 40 + 1))
    if status == 124 or status == 137 then
        tail = "(stopped after " .. tostring(limit or workflows.LIMIT) .. " seconds)\n" .. tail
    end
    return ok, tail, status
end
-- }}}

-- {{{ function workflows.run_all
-- Runs every workflow in the design. Returns the failures: array of
-- { workflow, output }.
function workflows.run_all(record, limit)
    local failures = {}
    for _, w in ipairs(workflows.list(record)) do
        local ok, output = workflows.run_one(w, record.design, limit)
        if not ok then
            failures[#failures + 1] = { workflow = w, output = output }
        end
    end
    return failures
end
-- }}}

-- {{{ local function blueprint_text
-- Every issue of the blueprint, whole, for the referee's prompt.
local function blueprint_text(record)
    local parts = {}
    for _, row in ipairs((text_tables.read(record.blueprint .. "/outline.tsv"))) do
        local path = issue_files.find(record.issues, row.id)
        parts[#parts + 1] = path and fs.read(path) or ("(issue " .. row.id .. " has no file)")
    end
    return table.concat(parts, "\n\n---\n\n")
end
-- }}}

-- {{{ local function check_set
-- Findings for the workflows now in the folder: none at all; no covers
-- line, or covers naming no issue of the blueprint; passing an empty folder.
local function check_set(record, empty_folder)
    local findings = {}
    local ids = {}
    for _, row in ipairs((text_tables.read(record.blueprint .. "/outline.tsv"))) do
        ids[row.id] = true
    end
    local list = workflows.list(record)
    if #list == 0 then
        return { "no workflow was written (NN-<name>.sh in the workflows folder)" }
    end
    local covered = {}
    for _, w in ipairs(list) do
        if #w.covers == 0 then
            findings[#findings + 1] = w.name .. " has no '# covers: <ids>' line among its first five"
        end
        for _, id in ipairs(w.covers) do
            if not ids[id] then
                findings[#findings + 1] = w.name .. " covers " .. id .. ", which is not an issue of the blueprint"
            end
            covered[id] = true
        end
        if workflows.run_one(w, empty_folder, 30) then
            findings[#findings + 1] = w.name .. " passes against an empty folder: it checks nothing"
        end
    end
    for id in pairs(ids) do
        if not covered[id] then
            findings[#findings + 1] = "no workflow covers issue " .. id
        end
    end
    table.sort(findings)
    return findings
end
-- }}}

-- {{{ local function take_away
-- Moves the current workflows into `folder` (a turn's before/), so a new
-- set starts clean and the old set can be put back.
local function take_away(record, folder)
    fs.make_folder(folder)
    for _, name in ipairs(fs.list(record.workflows)) do
        os.rename(record.workflows .. "/" .. name, folder .. "/" .. name)
    end
end
-- }}}

-- {{{ local function put_back
local function put_back(record, folder)
    for _, name in ipairs(fs.list(record.workflows)) do
        os.remove(record.workflows .. "/" .. name)
    end
    for _, name in ipairs(fs.list(folder)) do
        fs.write(record.workflows .. "/" .. name, fs.read(folder .. "/" .. name))
    end
end
-- }}}

-- {{{ function workflows.write
-- Writes (or rewrites) the case's workflows from the blueprint, up to
-- MOST_ATTEMPTS referee turns. Returns { ok = true, count } or
-- { ok = false, findings } with the previous workflows put back. Appends
-- `refereed` or `referee-failed`. A breach raises an error.
function workflows.write(project, record, target, options)
    fs.make_folder(record.workflows)
    local findings_text = "none"
    local keep = nil
    for attempt = 1, workflows.MOST_ATTEMPTS do
        local turn = kinds.make_turn(record, "referee", {
            about = "-", target = target, blueprint_text = blueprint_text(record), findings = findings_text,
        })
        if not keep then
            keep = turn.folder .. "/before"
            take_away(record, keep)
        else
            for _, name in ipairs(fs.list(record.workflows)) do
                os.remove(record.workflows .. "/" .. name)
            end
        end
        local results, summary = pool.run_set(project, record, { turn }, options)
        if #summary.breaches > 0 then
            put_back(record, keep)
            error("referee: the referee turn wrote outside its folders; the workflows were put back; stopping")
        end
        local findings
        if results[1].verdict == "failed" then
            findings = { "the referee turn failed: " .. results[1].why }
        else
            local empty = turn.folder .. "/empty-design"
            fs.make_folder(empty)
            findings = check_set(record, empty)
        end
        if #findings == 0 then
            local count = #workflows.list(record)
            ledger.append(record.ledger, "refereed", "-", count .. " workflows, attempt " .. attempt)
            return { ok = true, count = count }
        end
        findings_text = table.concat(findings, "\n")
    end
    put_back(record, keep)
    ledger.append(record.ledger, "referee-failed", "-", (findings_text:gsub("\n", "; ")))
    return { ok = false, findings = findings_text }
end
-- }}}

return workflows
