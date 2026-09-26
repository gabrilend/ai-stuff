#!/usr/bin/env luajit
-- phase-progress-files.lua - writes issues/phase-<N>-progress.md for every phase that has issues
--
-- In plain terms: every phase keeps a progress file saying what the phase is
-- for and where each of its issues stands. This tool writes the issue table
-- from the issue files themselves (their names, titles, folders and
-- dependency lines), so the table can't drift from the files. A new progress
-- file also gets the phase's goals, copied once from the phase's section of
-- docs/roadmap.md; after that the goals and any other hand-written text are
-- the owner's, and the tool only rewrites the table between its two markers.
-- A progress file that exists without the markers is hand-kept and left alone.
--
-- Usage: luajit scripts/phase-progress-files.lua [DIR] [--dry-run]
--
-- Phases are read by the shared issue-name reader that the progress
-- dashboard and the issue validator also use, so all three agree.

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local dry_run = false
for i = 1, #arg do
    if arg[i] == "--dry-run" then dry_run = true else DIR = arg[i] end
end
local names = dofile("/home/ritz/programming/ai-stuff/scripts/libs/issue-names.lua")

local BEGIN = "<!-- phase-progress-files: issues begin (generated; edits here are overwritten) -->"
local FINISH = "<!-- phase-progress-files: issues end -->"

-- {{{ local function read_file
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ local function write_file
local function write_file(path, text)
    local f = assert(io.open(path, "wb"))
    f:write(text)
    f:close()
end
-- }}}

-- {{{ local function issue_title
-- The first "# " heading, without its "Issue 522:" prefix.
local function issue_title(text)
    local title = text:match("^#%s+([^\n]+)") or text:match("\n#%s+([^\n]+)") or "(no title)"
    return (title:gsub("^Issue%s+[%w%-]+:%s*", ""):gsub("|", "/"))
end
-- }}}

-- {{{ local function issue_dependencies
-- Ids named on the header's Dependencies line, in order, no repeats.
local function issue_dependencies(text)
    local line = text:match("\n%*%*Dependencies:%*%*([^\n]*)")
    if not line then return "—" end
    local seen, ids = {}, {}
    for id in line:gmatch("%f[%w]([A-Z]?%d%d%d?%d?%l?)%f[^%w]") do
        if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    return #ids > 0 and table.concat(ids, ", ") or "—"
end
-- }}}

-- {{{ local function roadmap_goals
-- The phase's section of docs/roadmap.md: its heading and its first paragraph.
-- Returns nil when the roadmap has no section for the phase.
local function roadmap_goals(roadmap, phase)
    if not roadmap then return nil end
    local escaped = phase:gsub("%p", "%%%0")
    local s, e, heading = roadmap:find("\n## Phase " .. escaped .. ": ([^\n]+)")
    if not s then return nil end
    local rest = roadmap:sub(e + 1)
    local para = rest:match("^%s*\n(.-)\n%s*\n") or ""
    if para:match("^[#|`]") then para = "" end
    return heading, para
end
-- }}}

-- {{{ local function status_text
local STATUS = { open = "open", completed = "completed", retired = "retired", unknown = "unplaced" }
local function status_text(issue)
    local s = STATUS[issue.status] or issue.status
    if issue.status == "retired" and issue.folder ~= "" then s = s .. " (" .. issue.folder .. "/)" end
    return s
end
-- }}}

-- {{{ local function issue_table
local function issue_table(list)
    local lines = {
        BEGIN, "",
        "| ID | Title | Status | Depends on |",
        "|----|-------|--------|------------|",
    }
    local counts = { open = 0, completed = 0, retired = 0 }
    for _, issue in ipairs(list) do
        local text = read_file(issue.path) or ""
        counts[issue.status] = (counts[issue.status] or 0) + 1
        lines[#lines + 1] = string.format("| %s | [%s](./%s) | %s | %s |",
            issue.id, issue_title(text), issue.rel, status_text(issue), issue_dependencies(text))
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Completed %d, open %d, retired %d, as of the last run of `scripts/phase-progress-files.lua`.",
        counts.completed or 0, counts.open or 0, counts.retired or 0)
    lines[#lines + 1] = ""
    lines[#lines + 1] = FINISH
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ main
local issues = names.scan(DIR)
local by_phase = {}
for _, issue in ipairs(issues) do
    if issue.phase and issue.has_extension then
        by_phase[issue.phase] = by_phase[issue.phase] or {}
        table.insert(by_phase[issue.phase], issue)
    end
end
local phases = {}
for phase in pairs(by_phase) do phases[#phases + 1] = phase end
table.sort(phases, function(a, b) return names.phase_sort_key(a) < names.phase_sort_key(b) end)

local roadmap = read_file(DIR .. "/docs/roadmap.md")
local written, updated, hand_kept = 0, 0, {}
for _, phase in ipairs(phases) do
    local list = by_phase[phase]
    table.sort(list, function(a, b) return a.id < b.id end)
    local path = DIR .. "/issues/phase-" .. phase .. "-progress.md"
    local old = read_file(path)
    local block = issue_table(list)
    local new
    if not old then
        -- A new file: the phase's goals from the roadmap, once, then the table.
        local heading, para = roadmap_goals(roadmap, phase)
        local goals = heading
            and ("From `docs/roadmap.md`, \"Phase " .. phase .. ": " .. heading .. "\"" .. (para ~= "" and (":\n\n" .. para) or "."))
            or "Phase " .. phase .. " has no section in `docs/roadmap.md`; its goals are to be written here."
        new = "# Phase " .. phase .. (heading and (": " .. heading:gsub("%s*%(.-%)%s*$", "")) or "") .. " — Progress\n\n"
            .. "## Goals\n\n" .. goals .. "\n\n"
            .. "Live counts: `lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua " .. DIR .. " -m`\n\n"
            .. "## Issues\n\n" .. block .. "\n"
        written = written + 1
    elseif old:find(BEGIN, 1, true) and old:find(FINISH, 1, true) then
        local s = old:find(BEGIN, 1, true)
        local _, e = old:find(FINISH, 1, true)
        new = old:sub(1, s - 1) .. block .. old:sub(e + 1)
        if new ~= old then updated = updated + 1 end
    else
        hand_kept[#hand_kept + 1] = "phase-" .. phase .. "-progress.md"
    end
    if new and not dry_run then write_file(path, new) end
end
print(string.format("%d files %s, %d tables %s; hand-kept (no markers, left alone): %s",
    written, dry_run and "would be written" or "written",
    updated, dry_run and "would be updated" or "updated",
    #hand_kept > 0 and table.concat(hand_kept, ", ") or "none"))
-- }}}
