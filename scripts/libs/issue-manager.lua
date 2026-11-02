-- issue-manager.lua
--
-- The everyday operations on a project's issue files, for any project: what
-- number the next issue takes, which issues there are, writing a new one,
-- marking one done, checking one, and finding words in them (issue 012).
--
-- How it works, in general terms: it reads issues through the shared
-- issue-name reader (libs/issue-names.lua), the one the progress dashboard
-- and validate-issues use, so all of them agree on what an issue's phase,
-- number and status are. Writing is kept to the two moves the house makes by
-- hand: a new file at the top of issues/, and a finished one moved into
-- issues/completed/. Checking is handed to validate-issues itself, so there
-- is one set of rules for what a well-formed issue is.
--
-- It never stages or commits anything. A move is a plain rename on disk:
-- the shared git staging area belongs to every session working in the
-- repository, and the commit route (commit-own-changes) picks up a move from
-- the files themselves.
--
-- Usage as a library:
--
--   local issues = dofile(SCRIPTS_DIR .. "/libs/issue-manager.lua")
--   issues.init("/path/to/project")
--   local id = issues.next_id("3")                        -- "308"
--   local path = issues.create(id, "implement-feature")   -- template body
--   issues.complete(id)
--
-- Usage as a command (what libs/issue-manager.sh runs):
--
--   luajit issue-manager.lua DIR next PHASE
--   luajit issue-manager.lua DIR list [--status S] [--phase P]
--   luajit issue-manager.lua DIR show ID                  path of the issue
--   luajit issue-manager.lua DIR create ID NAME [-]       "-": body on stdin
--   luajit issue-manager.lua DIR complete ID
--   luajit issue-manager.lua DIR validate ID
--   luajit issue-manager.lua DIR search WORDS
--
-- Exit status: 0 done, 1 refused or findings (the reason on stderr),
-- 2 bad arguments or no issues/ folder.

local M = {}

-- {{{ paths
-- Where the shared reader and validate-issues live: the folder above this
-- file's, so a checkout uses its own copies.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local SCRIPTS_DIR = HERE .. ".."
local issue_names = dofile(HERE .. "issue-names.lua")
-- }}}

-- {{{ state
local project_dir = nil
-- }}}

-- {{{ local function shell_quote
local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function file_exists
local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end
-- }}}

-- {{{ function M.init
-- Sets the project; raises when it has no issues/ folder.
function M.init(dir)
    project_dir = (dir or "."):gsub("/+$", "")
    issue_names.scan(project_dir)
end
-- }}}

-- {{{ local function scan
local function scan()
    assert(project_dir, "issue-manager: call init first")
    return issue_names.scan(project_dir)
end
-- }}}

-- {{{ function M.next_id
-- The id a new issue in a phase should take, in the project's own shape
-- (522, 9-014, A08). Phase is a string: "5", "10", "A".
function M.next_id(phase)
    local issues, report = scan()
    return issue_names.next_id(issues, report, tostring(phase))
end
-- }}}

-- {{{ function M.list
-- Issues sorted by phase then id, each the table issue-names gives (path,
-- rel, id, phase, status, descr, ...). Filters: status ("open",
-- "completed", "retired", "unknown") and phase.
function M.list(filters)
    filters = filters or {}
    local issues = scan()
    local out = {}
    for _, issue in ipairs(issues) do
        if (not filters.status or issue.status == filters.status)
            and (not filters.phase or issue.phase == tostring(filters.phase)) then
            out[#out + 1] = issue
        end
    end
    table.sort(out, function(a, b)
        local ka = issue_names.phase_sort_key(a.phase or "~")
        local kb = issue_names.phase_sort_key(b.phase or "~")
        if ka ~= kb then return ka < kb end
        if a.id ~= b.id then return a.id < b.id end
        return a.rel < b.rel
    end)
    return out
end
-- }}}

-- {{{ function M.find
-- The issue with this id. Returns it, or nil and why: no such issue, or more
-- than one file claims the id (only open and completed files count, as
-- validate-issues counts duplicates; a retired file keeping an old id is
-- history).
function M.find(id)
    local hits = {}
    for _, issue in ipairs(scan()) do
        if issue.id == id and (issue.status == "open" or issue.status == "completed") then
            hits[#hits + 1] = issue
        end
    end
    if #hits == 0 then return nil, "no issue " .. id end
    if #hits > 1 then
        local rels = {}
        for i, h in ipairs(hits) do rels[i] = h.rel end
        return nil, "more than one file claims " .. id .. ": " .. table.concat(rels, ", ")
    end
    return hits[1]
end
-- }}}

-- {{{ function M.template
-- The body a new issue gets when none is given: a title and the three
-- headings validate-issues requires, each waiting to be written.
function M.template(id, name)
    local title = name:gsub("%-", " "):gsub("^%l", string.upper)
    return table.concat({
        "# Issue " .. id .. ": " .. title,
        "",
        "## Current Behavior",
        "",
        "",
        "## Intended Behavior",
        "",
        "",
        "## Suggested Implementation Steps",
        "",
        "1. ",
        "",
    }, "\n")
end
-- }}}

-- {{{ function M.create
-- Writes issues/<id>-<name>.md. Returns its path, or nil and why. Refused:
-- a name that is not lower-case words joined by dashes, an id that does not
-- read back as an issue id, an id some file already claims, a file that
-- already exists. The id is not required to be the next free one -- a
-- sub-issue (104a) or a deliberate gap is the author's call.
function M.create(id, name, body)
    name = name:gsub("%.md$", "")
    if not name:match("^[a-z0-9]+[a-z0-9%-]*$") or name:match("%-%-") or name:match("%-$") then
        return nil, "name is not lower-case words joined by dashes: " .. name
    end
    local filename = id .. "-" .. name .. ".md"
    local parsed = issue_names.split_name(filename)
    if not parsed or parsed.id ~= id then
        return nil, "not an issue id: " .. id
    end
    for _, issue in ipairs(scan()) do
        if issue.id == id and issue.status ~= "retired" then
            return nil, id .. " is already taken by " .. issue.rel
        end
    end
    local path = project_dir .. "/issues/" .. filename
    if file_exists(path) then return nil, "already exists: " .. path end
    local f, err = io.open(path, "w")
    if not f then return nil, err end
    f:write(body or M.template(id, name))
    f:close()
    return path
end
-- }}}

-- {{{ function M.complete
-- Moves an open issue into issues/completed/, keeping its name. Returns the
-- new path, or nil and why: no such issue, not open, or a file of that name
-- already in completed/.
function M.complete(id)
    local issue, why = M.find(id)
    if not issue then return nil, why end
    if issue.status ~= "open" then
        return nil, issue.rel .. " is " .. issue.status .. ", not open"
    end
    local dest_dir = project_dir .. "/issues/completed"
    os.execute("mkdir -p " .. shell_quote(dest_dir))
    local dest = dest_dir .. "/" .. issue.filename
    if file_exists(dest) then return nil, "already exists: " .. dest end
    local ok, err = os.rename(issue.path, dest)
    if not ok then return nil, err end
    return dest
end
-- }}}

-- {{{ function M.validate
-- Runs validate-issues on one issue. Returns true and no findings, or false
-- and the finding lines.
function M.validate(id)
    local issue, why = M.find(id)
    if not issue then return false, { why } end
    local cmd = "luajit " .. shell_quote(SCRIPTS_DIR .. "/validate-issues") .. " "
        .. shell_quote(project_dir) .. " --file " .. shell_quote(issue.path) .. " 2>&1"
    local pipe = io.popen(cmd)
    local findings = {}
    for line in pipe:lines() do
        if line ~= "" then findings[#findings + 1] = line end
    end
    pipe:close()
    return #findings == 0, findings
end
-- }}}

-- {{{ function M.search
-- Lines containing all the given words, case ignored, across every issue
-- (any status). Returns a list of { issue, line_number, line }, in list
-- order.
function M.search(query)
    local words = {}
    for w in query:lower():gmatch("%S+") do words[#words + 1] = w end
    local hits = {}
    if #words == 0 then return hits end
    for _, issue in ipairs(M.list()) do
        local f = io.open(issue.path, "r")
        if f then
            local n = 0
            for line in f:lines() do
                n = n + 1
                local lower = line:lower()
                local all = true
                for _, w in ipairs(words) do
                    if not lower:find(w, 1, true) then all = false break end
                end
                if all then hits[#hits + 1] = { issue = issue, line_number = n, line = line } end
            end
            f:close()
        end
    end
    return hits
end
-- }}}

-- {{{ local function main
local function main(args)
    local dir, command = args[1], args[2]
    local function usage()
        io.stderr:write("usage: issue-manager.lua DIR next PHASE | list [--status S] [--phase P]"
            .. " | show ID | create ID NAME [-] | complete ID | validate ID | search WORDS\n")
        os.exit(2)
    end
    if not dir or not command then usage() end
    local ok, err = pcall(M.init, dir)
    if not ok then
        io.stderr:write(tostring(err) .. "\n")
        os.exit(2)
    end
    local function refuse(why)
        io.stderr:write(why .. "\n")
        os.exit(1)
    end

    if command == "next" and args[3] then
        print(M.next_id(args[3]))
    elseif command == "list" then
        local filters, i = {}, 3
        while args[i] do
            if args[i] == "--status" and args[i + 1] then filters.status = args[i + 1]
            elseif args[i] == "--phase" and args[i + 1] then filters.phase = args[i + 1]
            else usage() end
            i = i + 2
        end
        for _, issue in ipairs(M.list(filters)) do
            print(table.concat({ issue.id, issue.phase or "?", issue.status, issue.rel }, "\t"))
        end
    elseif command == "show" and args[3] then
        local issue, why = M.find(args[3])
        if not issue then refuse(why) end
        print(issue.path)
    elseif command == "create" and args[3] and args[4] then
        local body = nil
        -- "-" reads the body from standard input; nothing arriving there
        -- (a pipe that was empty) gets the template, never an empty file
        if args[5] == "-" then body = io.stdin:read("*a")
        elseif args[5] then usage() end
        if body == "" then body = nil end
        local path, why = M.create(args[3], args[4], body)
        if not path then refuse(why) end
        print(path)
    elseif command == "complete" and args[3] then
        local path, why = M.complete(args[3])
        if not path then refuse(why) end
        print(path)
    elseif command == "validate" and args[3] then
        local clean, findings = M.validate(args[3])
        for _, line in ipairs(findings) do print(line) end
        os.exit(clean and 0 or 1)
    elseif command == "search" and args[3] then
        local query = table.concat(args, " ", 3)
        for _, hit in ipairs(M.search(query)) do
            print(hit.issue.rel .. ":" .. hit.line_number .. ": " .. hit.line)
        end
    else
        usage()
    end
end
-- }}}

-- Run as a command only when this file is the one started.
if arg and arg[0] and arg[0]:match("issue%-manager%.lua$") then
    main(arg)
end

return M
