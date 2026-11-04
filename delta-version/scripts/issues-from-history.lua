#!/usr/bin/env luajit
-- issues-from-history.lua - issue files for work a project has already
-- done, drafted from its git history.
--
-- Issue 051, its third slice (051c, issue files from the roadmap). The
-- project's phases come from docs/roadmap.json when there is one (written by
-- roadmap-from-history.lua --write), else straight from the history through
-- libs/history-phases.lua. Inside each phase, commits in a row that work in
-- the same folder, no more than a few days apart, become one issue. Each
-- issue is typed from its commit subjects (feature, fix, refactor, docs,
-- test, chore) and titled and summed up by the local model; without a model
-- (or with --no-model), or where the model fails, the title is the subject
-- of its largest commit.
--
-- The issues describe finished work, so they are written as completed
-- issues. With no option the plan is printed and nothing is written.
--   --write    puts them in PROJECT/issues/completed/ and the mapping in
--              PROJECT/docs/issue-mapping.json, only for a project that has
--              no issue files yet (its ids would clash with the ones it has)
--   --out=DIR  puts them and issue-mapping.json in DIR instead, which must
--              be empty or new
-- No file is ever replaced: every target is checked before any is written.
--
-- Usage: issues-from-history.lua PROJECT_DIR [--roadmap=FILE] [--no-model]
--                                [--json] [--write | --out=DIR]
--   --roadmap=FILE  the roadmap JSON to follow (default docs/roadmap.json)
--   --no-model      title the issues from their commits alone
--   --json          print the plan (the issue mapping) as JSON
--
-- The model is reached through libs/llama-chat-client.lua (INFERENCE_CHAT_HOST
-- moves it). Exit status: 0 done, 1 refused, 2 usage error.

-- {{{ DIR Configuration
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. SCRIPT_DIR .. "/../../libs/lua/?.lua;" .. package.path
-- }}}

-- {{{ Configuration
local config = {
    group_days = 3,           -- a commit further apart than this starts a new issue
    group_size = 6,           -- and no issue holds more commits than this
    body_lines = 3,
    files_listed = 20,
    title_length = 60,
    slug_length = 40,
    system_prompt = table.concat({
        "Task: name-issue.",
        "You name one piece of finished work in a software project from the commits that made it.",
        "Answer with a title on the first line (three to eight words), then one or two sentences",
        "saying what the work did. Use only what the commits show.",
    }, "\n"),
    types = {   -- the first rule a subject matches gives its type
        { "fix", { "%f[%a]fix", "%f[%a]bug", "%f[%a]repair" } },
        { "refactor", { "%f[%a]refactor", "%f[%a]rename", "%f[%a]clean", "%f[%a]move" } },
        { "test", { "%f[%a]test" } },
        { "docs", { "%f[%a]doc", "readme", "%f[%a]guide" } },
        { "chore", { "%f[%a]chore", "%f[%a]bump", "%f[%a]merge" } },
    },
}
-- }}}

local phases_lib = require("history-phases")

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message, code)
    io.stderr:write("issues-from-history: " .. message .. "\n")
    os.exit(code or 2)
end
-- }}}

-- {{{ local function note()
local function note(message)
    io.stderr:write("issues-from-history: " .. message .. "\n")
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function run()
local function run(command)
    local handle = io.popen(command .. " 2>/dev/null")
    if not handle then return "" end
    local out = handle:read("*a")
    handle:close()
    return out
end
-- }}}

-- {{{ local function exists()
local function exists(path)
    local ok, _, code = os.rename(path, path)
    return ok or code == 13
end
-- }}}

-- {{{ local function trim()
local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
-- }}}

-- {{{ local function read_file()
local function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return text
end
-- }}}
-- }}}

-- {{{ local function commit_bodies()
-- The first lines of each commit's message after its subject, by short hash.
local function commit_bodies(project)
    local log = run("git -C " .. shell_quote(project) .. " log --no-merges --format=%x1e%h%x1f%b -- .")
    local bodies = {}
    for record in log:gmatch("\30([^\30]*)") do
        local hash, body = record:match("^(%x+)\31(.*)$")
        if hash then
            local lines = {}
            for line in body:gmatch("[^\n]+") do
                if #lines < config.body_lines and line:match("%S") and not line:match("^Co%-Authored%-By:") then
                    lines[#lines + 1] = trim(line)
                end
            end
            bodies[hash:sub(1, 7)] = table.concat(lines, " ")
        end
    end
    return bodies
end
-- }}}

-- {{{ local function phases_from_roadmap()
-- The roadmap's phases laid over the commit stream, by their first and last
-- commits. Commits newer than the roadmap are left out, and said so.
local function phases_from_roadmap(path, commits)
    local record = require("dkjson").decode(read_file(path) or "")
    if type(record) ~= "table" or type(record.phases) ~= "table" or #record.phases == 0 then
        fail(path .. " is not a roadmap (roadmap-from-history.lua --json writes one)", 1)
    end
    local index_of = {}
    for index, commit in ipairs(commits) do index_of[commit.hash] = index end
    local phases, covered = {}, 0
    for _, phase in ipairs(record.phases) do
        local from, to = index_of[tostring(phase.first)], index_of[tostring(phase.last)]
        if not from or not to or to < from then
            fail(string.format("%s does not match the history (phase %s, %s to %s); make it again",
                path, tostring(phase.number), tostring(phase.first), tostring(phase.last)), 1)
        end
        local slice = {}
        for index = from, to do slice[#slice + 1] = commits[index] end
        phases[#phases + 1] = { number = phase.number or #phases + 1,
            name = phase.name or ("Phase " .. (phase.number or #phases + 1)), subjects = slice }
        covered = math.max(covered, to)
    end
    if covered < #commits then
        note(string.format("%d commit%s newer than %s left out; make the roadmap again to include them",
            #commits - covered, #commits - covered == 1 and " is" or "s are", path))
    end
    return phases
end
-- }}}

-- {{{ local function main_place()
-- Where a commit did most of its work: the first two folders of its
-- largest change ("src/parser"), its top folder, or "(top level)".
local function main_place(commit)
    local best
    for _, entry in ipairs(commit.paths) do
        if not best or entry.lines > best.lines then best = entry end
    end
    if not best then return "(top level)" end
    local folders = best.path:match("^(.*)/[^/]*$")
    if not folders then return "(top level)" end
    return folders:match("^([^/]+/[^/]+)") or folders
end
-- }}}

-- {{{ local function type_of()
local function type_of(commit)
    local lower = commit.subject:lower()
    for _, rule in ipairs(config.types) do
        for _, pattern in ipairs(rule[2]) do
            if lower:match(pattern) then return rule[1] end
        end
    end
    local all_docs = #commit.paths > 0
    for _, entry in ipairs(commit.paths) do
        if not entry.path:match("%.md$") then all_docs = false end
    end
    return all_docs and "docs" or "feature"
end
-- }}}

-- {{{ local function group_phase()
-- Commits in a row, in the same place, a few days apart at most.
local function group_phase(phase)
    local groups, current = {}, nil
    for _, commit in ipairs(phase.subjects) do
        local place = main_place(commit)
        if not current or current.place ~= place or #current.commits >= config.group_size
            or commit.time - current.commits[#current.commits].time > config.group_days * 86400 then
            current = { place = place, commits = {} }
            groups[#groups + 1] = current
        end
        current.commits[#current.commits + 1] = commit
    end
    return groups
end
-- }}}

-- {{{ local function describe_group()
-- The plain facts of a group: its type (most common among its commits,
-- ties to the earlier), its largest commit, its files.
local function describe_group(group)
    local counts, order, largest = {}, {}, nil
    for _, commit in ipairs(group.commits) do
        local kind = type_of(commit)
        if not counts[kind] then order[#order + 1] = kind end
        counts[kind] = (counts[kind] or 0) + 1
        if not largest or commit.lines > largest.lines then largest = commit end
    end
    local kind = order[1]
    for _, name in ipairs(order) do
        if counts[name] > counts[kind] then kind = name end
    end
    local files, seen = {}, {}
    for _, commit in ipairs(group.commits) do
        for _, entry in ipairs(commit.paths) do
            if not seen[entry.path] then
                seen[entry.path] = true
                files[#files + 1] = entry.path
            end
        end
    end
    table.sort(files)
    group.type, group.largest, group.files = kind, largest, files
    group.title, group.summary, group.named_by = largest.subject, nil, "commits"
end
-- }}}

-- {{{ local function clean_answer()
local function clean_answer(text)
    text = text:gsub("<think>.-</think>", ""):gsub("^.*</think>", "")
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        if line:match("%S") then lines[#lines + 1] = trim(line) end
    end
    if #lines == 0 then return nil end
    local title = lines[1]:gsub("^#+%s*", ""):gsub("^[Tt]itle:%s*", ""):gsub("^%- ", "")
    title = trim(title:gsub("^%*+", ""):gsub("%*+$", ""):gsub("^[\"']", ""):gsub("[\"'%.]$", ""))
    if #title > config.title_length then title = trim(title:sub(1, config.title_length)) end
    if title == "" then return nil end
    return title, table.concat(lines, " ", 2)
end
-- }}}

-- {{{ local function name_groups()
local function name_groups(project_name, issues)
    local client = require("llama-chat-client")
    if not client.is_reachable() then
        note("no model at " .. client.endpoint() .. "; each issue is titled by its largest commit")
        return
    end
    for _, issue in ipairs(issues) do
        local out = { "- " .. issue.largest.subject,
                      "project: " .. project_name,
                      string.format("phase %d: %s", issue.phase, issue.phase_name),
                      "commit subjects, oldest first:" }
        for _, commit in ipairs(issue.commits) do out[#out + 1] = "- " .. commit.subject end
        out[#out + 1] = "files: " .. table.concat(issue.files, ", ", 1, math.min(#issue.files, config.files_listed))
        local answer, why = client.complete(config.system_prompt, table.concat(out, "\n"))
        local title, summary = clean_answer(answer or "")
        if title then
            issue.title, issue.named_by = title, "model"
            if summary ~= "" then issue.summary = summary end
        else
            note(string.format("the model gave no title for issue %s (%s); it keeps its largest commit's subject",
                issue.id, tostring(why or "an empty answer")))
        end
    end
end
-- }}}

-- {{{ local function slugify()
local function slugify(text)
    local slug = text:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    if #slug > config.slug_length then slug = slug:sub(1, config.slug_length):gsub("%-[^%-]*$", "") end
    return slug ~= "" and slug or "work"
end
-- }}}

-- {{{ local function issue_text()
local function issue_text(issue, bodies, today)
    local first, last = issue.commits[1], issue.commits[#issue.commits]
    local out = {
        string.format("# Issue %s: %s", issue.id, issue.title), "",
        string.format("**Phase**: %d - %s", issue.phase, issue.phase_name),
        "**Status**: Completed",
        "**Type**: " .. issue.type,
        string.format("**Created**: %s (drafted from git history on %s)", first.date, today),
        string.format("**Commits**: %d, %s to %s", #issue.commits, first.date, last.date),
        "", "---", "",
        "## Current Behavior", "",
        string.format("Before `%s` (%s) this work had not begun.", first.hash, first.date),
        "", "---", "",
        "## Intended Behavior", "",
    }
    if issue.summary then
        out[#out + 1] = issue.summary
    else
        out[#out + 1] = "What the commits set out to do:"
        out[#out + 1] = ""
        for _, commit in ipairs(issue.commits) do out[#out + 1] = "- " .. commit.subject end
    end
    out[#out + 1] = ""
    out[#out + 1] = "---"
    out[#out + 1] = ""
    out[#out + 1] = "## What Happened"
    out[#out + 1] = ""
    for _, commit in ipairs(issue.commits) do
        local body = bodies[commit.hash] or ""
        out[#out + 1] = string.format("- `%s` (%s): %s%s", commit.hash, commit.date, commit.subject,
            body ~= "" and (". " .. body) or "")
    end
    out[#out + 1] = ""
    out[#out + 1] = "## Files Changed"
    out[#out + 1] = ""
    for index = 1, math.min(#issue.files, config.files_listed) do
        out[#out + 1] = "- `" .. issue.files[index] .. "`"
    end
    if #issue.files > config.files_listed then
        out[#out + 1] = string.format("- (and %d more)", #issue.files - config.files_listed)
    end
    out[#out + 1] = ""
    out[#out + 1] = "---"
    out[#out + 1] = ""
    out[#out + 1] = "## Metadata"
    out[#out + 1] = ""
    out[#out + 1] = string.format("- **Drafted by**: issues-from-history.lua; titled by %s. "
        .. "Check it before trusting it.", issue.named_by == "model" and "the local model" or "its largest commit")
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ local function plan_record()
local function plan_record(project_name, issues)
    local record = { mapping = "issues-from-history v1", project = project_name, issues = {} }
    for index, issue in ipairs(issues) do
        local hashes = {}
        for position, commit in ipairs(issue.commits) do hashes[position] = commit.hash end
        record.issues[index] = { id = issue.id, file = issue.file, phase = issue.phase,
            title = issue.title, type = issue.type, named_by = issue.named_by, commits = hashes }
    end
    return record
end
-- }}}

-- {{{ local function has_issue_files()
local function has_issue_files(project)
    local found = run("find " .. shell_quote(project .. "/issues") .. " -name '*.md' -type f -print -quit")
    return found:match("%S") ~= nil
end
-- }}}

-- {{{ local function show_help()
local function show_help()
    local file = io.open(arg[0], "r")
    if not file then return end
    for line in file:lines() do
        if line:match("^%-%- {{{") then break end
        if line:match("^%-%-") then print((line:gsub("^%-%- ?", ""))) end
    end
    file:close()
end
-- }}}

-- {{{ main
local function main(argv)
    local options, project = {}, nil
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if key and (key == "roadmap" or key == "out") and not options[key] then options[key] = value
        elseif argument == "--json" then options.json = true
        elseif argument == "--no-model" then options.no_model = true
        elseif argument == "--write" then options.write = true
        elseif argument == "-h" or argument == "--help" then show_help() return 0
        elseif not argument:match("^%-") and not project then project = argument
        else fail("unknown or repeated argument " .. argument .. " (see --help)") end
    end
    if not project then fail("name a project folder") end
    if options.write and options.out then fail("give --write or --out, not both") end
    project = project:gsub("/+$", "")

    -- Where the files would go, refused before any work.
    local issue_dir, mapping_path
    if options.write then
        if has_issue_files(project) then
            fail(project .. "/issues already has issue files, whose ids these would clash with; "
                .. "use --out=DIR and move what you want by hand", 1)
        end
        issue_dir, mapping_path = project .. "/issues/completed", project .. "/docs/issue-mapping.json"
    elseif options.out then
        if run("ls -A " .. shell_quote(options.out)):match("%S") then
            fail(options.out .. " is not empty; give a new or empty folder", 1)
        end
        issue_dir, mapping_path = options.out, options.out .. "/issue-mapping.json"
    end

    local commits, phases = phases_lib.phases(project)
    if not commits then fail(phases, phases:match("^no commits") and 1 or 2) end
    local roadmap = options.roadmap or (project .. "/docs/roadmap.json")
    if options.roadmap and not exists(roadmap) then fail(roadmap .. " does not exist", 1) end
    if exists(roadmap) then phases = phases_from_roadmap(roadmap, commits) end

    local issues = {}
    for _, phase in ipairs(phases) do
        for position, group in ipairs(group_phase(phase)) do
            describe_group(group)
            group.phase, group.phase_name = phase.number, phase.name
            group.id = string.format("%d%02d", phase.number, position)
            issues[#issues + 1] = group
        end
    end
    local name = project:match("([^/]+)$")
    if not options.no_model then name_groups(name, issues) end
    for _, issue in ipairs(issues) do issue.file = issue.id .. "-" .. slugify(issue.title) .. ".md" end

    local record = plan_record(name, issues)
    local json = require("dkjson").encode(record, { indent = true, keyorder = {
        "mapping", "project", "issues", "id", "file", "phase", "title", "type", "named_by", "commits" } }) .. "\n"

    if not issue_dir then
        if options.json then io.write(json) return 0 end
        print(string.format("%d issues from %d commits in %d phases (nothing written; --write or --out=DIR):",
            #issues, #commits, #phases))
        for _, issue in ipairs(issues) do
            print(string.format("  %-6s %-8s %2d  %s", issue.id, issue.type, #issue.commits, issue.title))
        end
        return 0
    end

    local targets = { { path = mapping_path, text = json } }
    local bodies, today = commit_bodies(project), os.date("%Y-%m-%d")
    for _, issue in ipairs(issues) do
        targets[#targets + 1] = { path = issue_dir .. "/" .. issue.file, text = issue_text(issue, bodies, today) }
    end
    for _, target in ipairs(targets) do
        if exists(target.path) then fail(target.path .. " already exists and is never replaced", 1) end
    end
    for _, target in ipairs(targets) do
        os.execute("mkdir -p " .. shell_quote(target.path:match("(.*)/[^/]*$")))
        local file = io.open(target.path, "w") or fail("cannot write " .. target.path, 1)
        file:write(target.text)
        file:close()
    end
    note(string.format("%d issue files written to %s, the mapping to %s", #issues, issue_dir, mapping_path))
    if options.json then io.write(json) end
    return 0
end
-- }}}

os.exit(main(arg))
