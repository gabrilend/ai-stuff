-- 054-amending.lua
--
-- Writing a request into the blueprint, with a way back (docs/008). Before
-- the amend turn runs, a copy of the outline and of every touched issue is
-- kept in the turn's folder. After it, the outline is checked again (401's
-- checks) and every changed or new issue file is checked (403); a failure
-- goes back to a new amend turn with its findings, up to three. When all
-- three fail, the blueprint is put back exactly as it was — the copies
-- restored, any new issue file removed — and the request is failed.

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local kinds = require("034-turn-kinds")
local pool = require("039-the-turn-pool")
local outline = require("042-the-outline")
local issue_files = require("044-issue-files")

local amending = {}

amending.MOST_ATTEMPTS = 3

-- {{{ local function snapshot_blueprint
-- The blueprint's files as they are now: name -> text, the outline under
-- the key "outline.tsv".
local function snapshot_blueprint(record)
    local files = { ["outline.tsv"] = fs.read(record.blueprint .. "/outline.tsv") }
    for _, name in ipairs(fs.list(record.issues)) do
        if name:match("%.md$") then
            files[name] = fs.read(record.issues .. "/" .. name)
        end
    end
    return files
end
-- }}}

-- {{{ local function put_back
-- Restores the blueprint to a snapshot: every file rewritten as it was,
-- every issue file the snapshot did not have removed.
local function put_back(record, before)
    fs.write(record.blueprint .. "/outline.tsv", before["outline.tsv"])
    for _, name in ipairs(fs.list(record.issues)) do
        if name:match("%.md$") and not before[name] then
            os.remove(record.issues .. "/" .. name)
        end
    end
    for name, text in pairs(before) do
        if name ~= "outline.tsv" then
            fs.write(record.issues .. "/" .. name, text)
        end
    end
end
-- }}}

-- {{{ local function check_amended
-- Findings for the blueprint after an amend: the outline's checks, then
-- each changed or new issue against its row, then the house validator.
-- Returns findings and the names of new issue files.
local function check_amended(project, record, before)
    local findings = {}
    local rows, problem = outline.read(record)
    if not rows then
        return { problem }, {}
    end
    local survey_rows = text_tables.read(record.survey .. "/files.tsv")
    local checks = outline.check(rows, survey_rows)
    for _, c in ipairs(checks) do
        for _, f in ipairs(c.findings) do
            findings[#findings + 1] = "outline " .. c.name .. ": " .. f
        end
    end
    local row_of = {}
    for _, row in ipairs(rows) do
        row_of[row.id] = row
    end
    local new_files = {}
    for _, name in ipairs(fs.list(record.issues)) do
        if name:match("%.md$") then
            local text = fs.read(record.issues .. "/" .. name)
            if not before[name] then
                new_files[#new_files + 1] = name
            end
            if before[name] ~= text then
                local path = record.issues .. "/" .. name
                local ok, issue = pcall(issue_files.read, path)
                if not ok then
                    findings[#findings + 1] = tostring(issue)
                elseif not row_of[issue.id] then
                    findings[#findings + 1] = name .. " has no row in the outline"
                else
                    for _, f in ipairs(issue_files.check(issue, row_of[issue.id])) do
                        findings[#findings + 1] = name .. ": " .. f
                    end
                    for _, f in ipairs(issue_files.validate(project.validate_issues, record.blueprint, path)) do
                        findings[#findings + 1] = name .. ": " .. f
                    end
                end
            end
        end
    end
    -- Every outline row must have its file.
    for _, row in ipairs(rows) do
        if not issue_files.find(record.issues, row.id) then
            findings[#findings + 1] = "the outline has issue " .. row.id .. " but no file for it"
        end
    end
    return findings, new_files
end
-- }}}

-- {{{ function amending.amend
-- Amends the blueprint for a request. Returns { ok = true, new_ids = ids of
-- new issues } or { ok = false, findings = text } with the blueprint put
-- back as it was.
function amending.amend(project, record, request, touched, options)
    local before = snapshot_blueprint(record)
    local request_text = fs.read(record.input .. "/" .. request)
    local touched_texts = {}
    for _, id in ipairs(touched) do
        local path = issue_files.find(record.issues, id)
        touched_texts[#touched_texts + 1] = "File: " .. path .. "\n\n" .. fs.read(path)
    end
    local findings_text = "none"
    for attempt = 1, amending.MOST_ATTEMPTS do
        local turn = kinds.make_turn(record, "amend", {
            about = request, request = request, request_text = request_text,
            touched_texts = #touched_texts > 0 and table.concat(touched_texts, "\n\n---\n\n")
                or "(none: the request needs new issues only)",
            outline_text = before["outline.tsv"], findings = findings_text,
        })
        -- The way back, kept beside the turn that might need it.
        fs.make_folder(turn.folder .. "/before")
        for name, text in pairs(before) do
            fs.write(turn.folder .. "/before/" .. name, text)
        end
        local results, summary = pool.run_set(project, record, { turn }, options)
        if #summary.breaches > 0 then
            put_back(record, before)
            error("amend: the amend turn for " .. request .. " wrote outside its folders; the blueprint was put back; stopping")
        end
        local problems
        if results[1].verdict == "failed" then
            problems = { "the amend turn failed: " .. results[1].why }
        else
            local new_files
            problems, new_files = check_amended(project, record, before)
            if #problems == 0 then
                local new_ids = {}
                for _, name in ipairs(new_files) do
                    local id = name:match("^(%d%d%d)%-")
                    new_ids[#new_ids + 1] = id
                    ledger.append(record.ledger, "described", id, "added by request " .. request)
                end
                return { ok = true, new_ids = new_ids, attempts = attempt }
            end
        end
        findings_text = table.concat(problems, "\n")
        -- Each attempt starts from the blueprint as it was, not from the
        -- last attempt's half-done edit.
        put_back(record, before)
    end
    return { ok = false, findings = findings_text }
end
-- }}}

return amending
