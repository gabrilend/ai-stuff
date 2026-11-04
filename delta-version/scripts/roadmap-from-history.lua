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
-- The phases come from libs/history-phases.lua. The project may be a whole
-- repository or a folder inside one (only the commits that touch the folder
-- are read; merges are left out). The model is reached through
-- libs/llama-chat-client.lua (INFERENCE_CHAT_HOST moves it).
-- Exit status: 0 done, 1 refused, 2 usage error.

-- {{{ DIR Configuration
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. SCRIPT_DIR .. "/../../libs/lua/?.lua;" .. package.path
-- }}}

-- {{{ Configuration
local phases_lib = require("history-phases")
local config = {
    max_phases = phases_lib.config.max_phases,
    gap_days = phases_lib.config.gap_days,
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

    local commits, phases = phases_lib.phases(project, { max_phases = max_phases, gap_days = gap_days })
    if not commits then fail(phases, phases:match("^no commits") and 1 or 2) end
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
