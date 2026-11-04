#!/usr/bin/env luajit
-- roadmap-from-history.lua - a project's development phases, read from its
-- git history, as a draft roadmap.
--
-- Issue 051, its second slice (051b, roadmap generation). The phases come
-- from the history itself, with no model involved: a new phase starts where
-- the commits show a break, scored from long time gaps, version or release
-- commits, README updates, unusually large commits and the first commit in
-- a new folder. Each phase is then named and described by the local model
-- from its commits; where no model is reachable (or --no-model is given),
-- or the model fails for a phase, the phase keeps a plain name drawn from
-- the folders it changed most.
--
-- The roadmap is printed as Markdown, or as JSON with --json. --write saves
-- both as docs/roadmap.md and docs/roadmap.json, only when neither exists;
-- an existing roadmap is never replaced.
--
-- Usage: roadmap-from-history.lua PROJECT_DIR [--json] [--no-model]
--                                 [--phases=N] [--gap-days=N]
--                                 [--write | --out=FILE]
--   --json        print the roadmap as JSON instead of Markdown
--   --no-model    name the phases from the history alone
--   --phases=N    at most N phases (default 8)
--   --gap-days=N  a quiet spell this many days long starts a phase (default 14)
--   --write       save docs/roadmap.md and docs/roadmap.json if both are absent
--   --out=FILE    save the roadmap here instead (never over an existing file)
--
-- The project may be a whole repository or a folder inside one (only the
-- commits that touch the folder are read; merges are left out). The model
-- is reached through libs/llama-chat-client.lua (INFERENCE_CHAT_HOST moves
-- it). Exit status: 0 done, 1 refused, 2 usage error.

-- {{{ DIR Configuration
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. SCRIPT_DIR .. "/../../libs/lua/?.lua;" .. package.path
-- }}}

-- {{{ Configuration
local config = {
    max_phases = 8,
    min_phase_commits = 3,       -- no phase is shorter than this
    gap_days = 14,
    large_files = 20,            -- a commit this wide, or
    large_lines = 1000,          -- this many lines changed, is "large"
    threshold = 2,               -- the score a break needs to start a phase
    weights = { gap = 3, version = 3, readme = 1, large = 1, new_folder = 1 },
    accomplishments = 5,
    prompt_subjects = 30,
    name_length = 60,
    system_prompt = table.concat({
        "Task: name-phase.",
        "You name one phase of a project's development from the commits made in it.",
        "Answer with the name on the first line (two to six words, without \"Phase\" or a number),",
        "then one or two sentences saying what the phase did. Use only what the commits show.",
    }, "\n"),
}
-- }}}

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message, code)
    io.stderr:write("roadmap-from-history: " .. message .. "\n")
    os.exit(code or 2)
end
-- }}}

-- {{{ local function note()
local function note(message)
    io.stderr:write("roadmap-from-history: " .. message .. "\n")
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
-- }}}

-- {{{ local function commit_stream()
-- Every commit touching the folder, oldest first, with what it changed.
-- Paths are relative to the project folder.
local function commit_stream(project)
    local git = "git -C " .. shell_quote(project)
    local top = run(git .. " rev-parse --show-toplevel"):gsub("%s+$", "")
    if top == "" then fail(project .. " is not inside a git repository") end
    local log = run(git .. " log --reverse --no-merges --no-renames --relative --numstat"
        .. " --date=short --format=%x1e%H%x1f%at%x1f%ad%x1f%s -- .")
    local commits = {}
    for record in log:gmatch("\30([^\30]*)") do
        local header, rest = record:match("^([^\n]*)\n?(.*)$")
        local hash, stamp, date, subject = header:match("^(%x+)\31(%d+)\31([^\31]*)\31(.*)$")
        if hash then
            local commit = { hash = hash:sub(1, 7), time = tonumber(stamp), date = date,
                             subject = subject, files = 0, lines = 0, paths = {} }
            for added, deleted, path in rest:gmatch("([%d%-]+)\t([%d%-]+)\t([^\n]+)") do
                commit.files = commit.files + 1
                local changed = (tonumber(added) or 0) + (tonumber(deleted) or 0)
                commit.lines = commit.lines + changed
                commit.paths[#commit.paths + 1] = { path = path, lines = changed }
            end
            commits[#commits + 1] = commit
        end
    end
    return commits
end
-- }}}

-- {{{ local function folder_of()
local function folder_of(path)
    return path:match("^([^/]+)/") or "(top level)"
end
-- }}}

-- {{{ local function score_breaks()
-- For each commit after the first, why a phase might start there. A break
-- before commit i scores the quiet spell since commit i-1, a version or
-- release made in commit i-1 (it closes a phase), a README update in
-- commit i-1, and commit i being large or the first in a new folder.
local function score_breaks(commits, gap_days)
    local w, seen, candidates = config.weights, {}, {}
    for _, entry in ipairs(commits[1] and commits[1].paths or {}) do seen[folder_of(entry.path)] = true end
    for index = 2, #commits do
        local before, commit, reasons, score = commits[index - 1], commits[index], {}, 0
        local days = math.floor((commit.time - before.time) / 86400)
        if days >= gap_days then
            score = score + w.gap
            reasons[#reasons + 1] = days .. " days after the commit before"
        end
        local lower = before.subject:lower()
        if lower:match("%f[%w]v?%d+%.%d+") or lower:match("%f[%a]release") then
            score = score + w.version
            reasons[#reasons + 1] = "follows a version or release (" .. before.hash .. ")"
        end
        for _, entry in ipairs(before.paths) do
            if entry.path:match("^[Rr][Ee][Aa][Dd][Mm][Ee]") then
                score = score + w.readme
                reasons[#reasons + 1] = "follows a README update (" .. before.hash .. ")"
                break
            end
        end
        if commit.files >= config.large_files or commit.lines >= config.large_lines then
            score = score + w.large
            reasons[#reasons + 1] = string.format("a large commit (%d files, %d lines)", commit.files, commit.lines)
        end
        local new = {}
        for _, entry in ipairs(commit.paths) do
            local folder = folder_of(entry.path)
            if not seen[folder] then
                seen[folder] = true
                if folder ~= "(top level)" then new[#new + 1] = folder .. "/" end
            end
        end
        if #new > 0 then
            score = score + w.new_folder
            reasons[#reasons + 1] = "first work in " .. table.concat(new, ", ")
        end
        if score >= config.threshold then
            candidates[#candidates + 1] = { index = index, score = score, reasons = reasons }
        end
    end
    return candidates
end
-- }}}

-- {{{ local function choose_breaks()
-- The strongest breaks, as long as every phase keeps its minimum length,
-- up to max_phases - 1 of them. Ties go to the earlier break.
local function choose_breaks(candidates, count, max_phases)
    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.index < b.index
    end)
    local chosen = {}
    for _, candidate in ipairs(candidates) do
        if #chosen >= max_phases - 1 then break end
        local fits = candidate.index - 1 >= config.min_phase_commits
            and count - candidate.index + 1 >= config.min_phase_commits
        for _, other in ipairs(chosen) do
            if math.abs(other.index - candidate.index) < config.min_phase_commits then fits = false end
        end
        if fits then chosen[#chosen + 1] = candidate end
    end
    table.sort(chosen, function(a, b) return a.index < b.index end)
    return chosen
end
-- }}}

-- {{{ local function build_phases()
local function build_phases(commits, breaks)
    local phases, starts = {}, { { index = 1, reasons = {} } }
    for _, entry in ipairs(breaks) do starts[#starts + 1] = entry end
    for number, start in ipairs(starts) do
        local stop = (starts[number + 1] and starts[number + 1].index - 1) or #commits
        local slice, lines_by_folder = {}, {}
        for index = start.index, stop do
            slice[#slice + 1] = commits[index]
            for _, entry in ipairs(commits[index].paths) do
                local folder = folder_of(entry.path)
                lines_by_folder[folder] = (lines_by_folder[folder] or 0) + entry.lines
            end
        end
        local areas = {}
        for folder, lines in pairs(lines_by_folder) do areas[#areas + 1] = { folder = folder, lines = lines } end
        table.sort(areas, function(a, b)
            if a.lines ~= b.lines then return a.lines > b.lines end
            return a.folder < b.folder
        end)
        local area_names = {}
        for index = 1, math.min(3, #areas) do
            area_names[index] = areas[index].folder == "(top level)" and "the top level"
                or (areas[index].folder .. "/")
        end
        -- The largest commits, shown in the order they were made.
        local ranked = {}
        for position, commit in ipairs(slice) do ranked[#ranked + 1] = { position = position, commit = commit } end
        table.sort(ranked, function(a, b)
            if a.commit.lines ~= b.commit.lines then return a.commit.lines > b.commit.lines end
            return a.position < b.position
        end)
        local picked = {}
        for index = 1, math.min(config.accomplishments, #ranked) do picked[index] = ranked[index] end
        table.sort(picked, function(a, b) return a.position < b.position end)
        local accomplishments = {}
        for index, entry in ipairs(picked) do accomplishments[index] = entry.commit.subject end

        local first, last = slice[1], slice[#slice]
        phases[number] = {
            number = number,
            commits = #slice,
            from = first.date, to = last.date,
            first = first.hash, last = last.hash,
            areas = area_names,
            accomplishments = accomplishments,
            starts_because = start.reasons,
            subjects = slice,
            name = #area_names > 0 and ("Work in " .. table.concat(area_names, " and ", 1, math.min(2, #area_names)))
                or "Work",
            description = string.format("%d commit%s from %s to %s%s, from \"%s\" to \"%s\".", #slice,
                #slice == 1 and "" or "s", first.date, last.date,
                #area_names > 0 and (", most changes in " .. table.concat(area_names, ", ")) or "",
                first.subject, last.subject),
            named_by = "heuristics",
        }
    end
    return phases
end
-- }}}

-- {{{ local function clean_answer()
-- Drop a reasoning model's <think> block, then split the answer into its
-- name line and the description after it.
local function clean_answer(text)
    text = text:gsub("<think>.-</think>", ""):gsub("^.*</think>", "")
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        if line:match("%S") then lines[#lines + 1] = trim(line) end
    end
    if #lines == 0 then return nil end
    local name = lines[1]:gsub("^#+%s*", ""):gsub("^[Nn]ame:%s*", ""):gsub("^%*+", ""):gsub("%*+$", "")
    name = trim(name:gsub("^[\"']", ""):gsub("[\"'%.]$", ""))
    if #name > config.name_length then name = trim(name:sub(1, config.name_length)) end
    if name == "" then return nil end
    return name, table.concat(lines, " ", 2)
end
-- }}}

-- {{{ local function name_phases()
-- Ask the model for each phase's name and description. A phase the model
-- fails for keeps its plain name.
local function name_phases(project_name, phases)
    local client = require("llama-chat-client")
    if not client.is_reachable() then
        note("no model at " .. client.endpoint() .. "; the phases keep plain names")
        return
    end
    for _, phase in ipairs(phases) do
        local out = {
            string.format("phase %d of %d: %s to %s, %d commits", phase.number, #phases, phase.from,
                phase.to, phase.commits),
            "project: " .. project_name,
            "most changes in: " .. (#phase.areas > 0 and table.concat(phase.areas, ", ") or "nothing"),
            "commit subjects, oldest first:",
        }
        for index = 1, math.min(config.prompt_subjects, #phase.subjects) do
            out[#out + 1] = "- " .. phase.subjects[index].subject
        end
        if #phase.subjects > config.prompt_subjects then
            out[#out + 1] = string.format("(and %d more)", #phase.subjects - config.prompt_subjects)
        end
        local answer, why = client.complete(config.system_prompt, table.concat(out, "\n"))
        local name, description = clean_answer(answer or "")
        if name then
            phase.name = name
            if description ~= "" then phase.description = description end
            phase.named_by = "model"
        else
            note(string.format("the model gave no name for phase %d (%s); it keeps a plain name",
                phase.number, tostring(why or "an empty answer")))
        end
    end
end
-- }}}

-- {{{ local function as_record()
local function as_record(project_name, folder, commits, phases)
    local named = {}
    for _, phase in ipairs(phases) do named[phase.named_by] = true end
    local record = {
        roadmap = "roadmap-from-history v1",
        project = project_name, folder = folder,
        commit_count = #commits, from = commits[1].date, to = commits[#commits].date,
        named_by = (named.model and named.heuristics) and "mixed" or (named.model and "model" or "heuristics"),
        phases = {},
    }
    for index, phase in ipairs(phases) do
        record.phases[index] = {
            number = phase.number, name = phase.name, description = phase.description,
            named_by = phase.named_by, from = phase.from, to = phase.to,
            first = phase.first, last = phase.last, commits = phase.commits,
            areas = phase.areas, accomplishments = phase.accomplishments,
            starts_because = phase.starts_because,
        }
    end
    return record
end
-- }}}

-- {{{ local function as_json()
local function as_json(record)
    return require("dkjson").encode(record, { indent = true, keyorder = {
        "roadmap", "project", "folder", "commit_count", "from", "to", "named_by", "phases",
        "number", "name", "description", "first", "last", "commits", "areas",
        "accomplishments", "starts_because",
    } }) .. "\n"
end
-- }}}

-- {{{ local function as_markdown()
local function as_markdown(record)
    local out = {
        "# Roadmap: " .. record.project, "",
        string.format("Drawn from %d commits, %s to %s. A new phase starts where the history shows a "
            .. "break: a long quiet spell, a version or release, a README update, a large commit or "
            .. "work in a new folder.", record.commit_count, record.from, record.to),
    }
    for _, phase in ipairs(record.phases) do
        out[#out + 1] = ""
        out[#out + 1] = string.format("## Phase %d: %s", phase.number, phase.name)
        out[#out + 1] = ""
        out[#out + 1] = string.format("*%s to %s, %d commit%s (%s to %s)*", phase.from, phase.to,
            phase.commits, phase.commits == 1 and "" or "s", phase.first, phase.last)
        out[#out + 1] = ""
        out[#out + 1] = phase.description
        if #phase.starts_because > 0 then
            out[#out + 1] = ""
            out[#out + 1] = "Starts here because: " .. table.concat(phase.starts_because, "; ") .. "."
        end
        out[#out + 1] = ""
        out[#out + 1] = "Largest changes:"
        out[#out + 1] = ""
        for _, subject in ipairs(phase.accomplishments) do out[#out + 1] = "- " .. subject end
    end
    out[#out + 1] = ""
    out[#out + 1] = string.format("<!-- draft by roadmap-from-history.lua; phases named by %s; "
        .. "check it before trusting it -->", record.named_by)
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ local function save()
local function save(path, text)
    local folder = path:match("(.*)/[^/]*$")
    if folder then os.execute("mkdir -p " .. shell_quote(folder)) end
    local file = io.open(path, "w") or fail("cannot write " .. path, 1)
    file:write(text)
    file:close()
    note("roadmap written to " .. path)
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

-- {{{ local function whole_number()
local function whole_number(text, name, least)
    local number = tonumber(text)
    if not number or number < least or number % 1 ~= 0 then
        fail(string.format("--%s takes a whole number, %d or more", name, least))
    end
    return number
end
-- }}}

-- {{{ main
local function main(argv)
    local options, project = {}, nil
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if key and (key == "phases" or key == "gap-days" or key == "out") and not options[key] then
            options[key] = value
        elseif argument == "--json" then options.json = true
        elseif argument == "--no-model" then options.no_model = true
        elseif argument == "--write" then options.write = true
        elseif argument == "-h" or argument == "--help" then show_help() return 0
        elseif not argument:match("^%-") and not project then project = argument
        else fail("unknown or repeated argument " .. argument .. " (see --help)") end
    end
    if not project then fail("name a project folder") end
    local max_phases = whole_number(options.phases or tostring(config.max_phases), "phases", 1)
    local gap_days = whole_number(options["gap-days"] or tostring(config.gap_days), "gap-days", 1)
    if options.write and options.out then fail("give --write or --out, not both") end
    if options.write and options.json then fail("--write saves both Markdown and JSON; leave out --json") end

    local targets = {}
    if options.write then
        targets = { { path = project .. "/docs/roadmap.md", kind = "markdown" },
                    { path = project .. "/docs/roadmap.json", kind = "json" } }
    elseif options.out then
        targets = { { path = options.out, kind = options.json and "json" or "markdown" } }
    end
    for _, target in ipairs(targets) do
        if exists(target.path) then
            fail(target.path .. " already exists and is never replaced; use --out=FILE for the draft", 1)
        end
    end

    local commits = commit_stream(project)
    if #commits == 0 then fail("no commits touch " .. project, 1) end
    local phases = build_phases(commits, choose_breaks(score_breaks(commits, gap_days), #commits, max_phases))
    local name = (project:gsub("/+$", "")):match("([^/]+)$")
    if not options.no_model then name_phases(name, phases) end

    local folder = run("git -C " .. shell_quote(project) .. " rev-parse --show-prefix"):gsub("%s+$", "")
    local record = as_record(name, folder, commits, phases)
    if #targets == 0 then
        io.write(options.json and as_json(record) or as_markdown(record))
    else
        for _, target in ipairs(targets) do
            save(target.path, target.kind == "json" and as_json(record) or as_markdown(record))
        end
    end
    return 0
end
-- }}}

os.exit(main(arg))
