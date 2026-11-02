#!/usr/bin/env luajit
-- history-kernel.lua - what a project set out to be, read from its first
-- commits, and a first draft of its vision document.
--
-- Issue 051, its smallest useful slice (051a, initial commit analysis). The
-- facts are gathered from git, with no model involved: the project's first
-- commits (date, subject, the first lines of each message), its README as it
-- stood in the first commit that had one, its build files, and how far it
-- has come since (commit count, latest commit). --json prints just these
-- facts. Otherwise the local model is given them and asked for a draft
-- vision document: the original idea and what the project grew into.
--
-- The draft is printed. --write puts it at notes/vision.md only when the
-- project has no vision yet; an existing vision is never replaced.
--
-- Usage: history-kernel.lua PROJECT_DIR [--commits=N] [--json]
--                           [--write | --out=FILE]
--   --commits=N   how many of the first commits to read (default 10)
--   --json        print the gathered facts, ask the model nothing
--   --write       save the draft as PROJECT_DIR/notes/vision.md if absent
--   --out=FILE    save the draft here instead (never over an existing file)
--
-- The project may be a whole repository or a folder inside one (only the
-- commits that touch the folder are read). The model is reached through
-- libs/llama-chat-client.lua (INFERENCE_CHAT_HOST moves it).
-- Exit status: 0 done, 1 refused or the model failed, 2 usage error.

-- {{{ DIR Configuration
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. SCRIPT_DIR .. "/../../libs/lua/?.lua;" .. package.path
-- }}}

-- {{{ Configuration
local config = {
    readme_lines = 40,
    body_lines = 3,
    build_files = { "Makefile", "CMakeLists.txt", "Cargo.toml", "package.json", "build.zig",
                    "go.mod", "pyproject.toml", "rockspec", "meson.build" },
    system_prompt = table.concat({
        "Task: vision.",
        "You write the first draft of a project's vision document from the facts of its git history.",
        "Use two sections, \"## The original idea\" (what the first commits set out to build) and",
        "\"## What it grew into\" (bullets from the later commits). Start with \"# Vision\".",
        "State only what the facts support; where intent is unclear, say so instead of guessing.",
    }, "\n"),
}
-- }}}

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message, code)
    io.stderr:write("history-kernel: " .. message .. "\n")
    os.exit(code or 2)
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
-- }}}

-- {{{ local function gather()
-- The facts, from git alone.
local function gather(project, count)
    local git = "git -C " .. shell_quote(project)
    local top = run(git .. " rev-parse --show-toplevel"):gsub("%s+$", "")
    if top == "" then fail(project .. " is not inside a git repository") end
    local prefix = run(git .. " rev-parse --show-prefix"):gsub("%s+$", "")
    local facts = { name = (project:gsub("/+$", "")):match("([^/]+)$"), folder = prefix,
                    first_commits = {}, build_files = {} }

    -- Every commit touching the folder, oldest first, as hash, date, subject.
    local SEP = "\31"
    local log = run(git .. " log --reverse --format=%H" .. SEP .. "%ad" .. SEP .. "%s" .. SEP
        .. "%b%x1e --date=short -- .")
    local total = 0
    for record in log:gmatch("([^\30]+)\30") do
        local hash, date, subject, body = record:match("^%s*(%x+)" .. SEP .. "([^" .. SEP .. "]*)"
            .. SEP .. "([^" .. SEP .. "]*)" .. SEP .. "(.*)$")
        if hash then
            total = total + 1
            if total <= count then
                local lines = {}
                for line in body:gmatch("[^\n]+") do
                    if #lines < config.body_lines and line:match("%S")
                        and not line:match("^Co%-Authored%-By:") then
                        lines[#lines + 1] = line
                    end
                end
                facts.first_commits[#facts.first_commits + 1] = { hash = hash:sub(1, 7), date = date,
                    subject = subject, body = table.concat(lines, " ") }
            end
            facts.latest = { hash = hash:sub(1, 7), date = date, subject = subject }
        end
    end
    if total == 0 then fail("no commits touch " .. project, 1) end
    facts.commit_count = total
    facts.started = facts.first_commits[1].date

    -- The README as first committed, else as it is now.
    for _, commit in ipairs(facts.first_commits) do
        for _, name in ipairs({ "README.md", "README", "readme.md", "README.txt" }) do
            local text = run(git .. " show " .. shell_quote(commit.hash .. ":./" .. name))
            if text ~= "" then
                facts.readme = { from = commit.hash, text = text }
                break
            end
        end
        if facts.readme then break end
    end
    if not facts.readme then
        local file = io.open(project .. "/README.md", "r")
        if file then
            facts.readme = { from = "now", text = file:read("*a") }
            file:close()
        end
    end
    if facts.readme then
        local lines = {}
        for line in (facts.readme.text .. "\n"):gmatch("([^\n]*)\n") do
            if #lines < config.readme_lines then lines[#lines + 1] = line end
        end
        facts.readme.text = table.concat(lines, "\n")
    end
    for _, name in ipairs(config.build_files) do
        if exists(project .. "/" .. name) then facts.build_files[#facts.build_files + 1] = name end
    end
    return facts
end
-- }}}

-- {{{ local function as_prompt()
local function as_prompt(facts)
    local out = {
        "project: " .. facts.name,
        string.format("started: %s; %d commits since; latest %s %s", facts.started,
            facts.commit_count, facts.latest.date, facts.latest.subject),
        "build files: " .. (#facts.build_files > 0 and table.concat(facts.build_files, ", ") or "none"),
        "", "first commits, oldest first:",
    }
    for _, commit in ipairs(facts.first_commits) do
        out[#out + 1] = string.format("subject: %s", commit.subject)
        out[#out + 1] = string.format("  (%s %s)%s", commit.date, commit.hash,
            commit.body ~= "" and (" " .. commit.body) or "")
    end
    if facts.readme then
        out[#out + 1] = ""
        out[#out + 1] = "README (from " .. (facts.readme.from == "now" and "the current tree" or
            ("commit " .. facts.readme.from)) .. "):"
        out[#out + 1] = facts.readme.text
    end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ local function save()
local function save(path, text)
    if exists(path) then
        fail(path .. " already exists and is never replaced; use --out=FILE for the draft", 1)
    end
    local folder = path:match("(.*)/[^/]*$")
    if folder then os.execute("mkdir -p " .. shell_quote(folder)) end
    local file = io.open(path, "w") or fail("cannot write " .. path, 1)
    file:write(text)
    file:close()
    io.stderr:write("history-kernel: draft written to " .. path .. "\n")
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
        if key and (key == "commits" or key == "out") then options[key] = value
        elseif argument == "--json" then options.json = true
        elseif argument == "--write" then options.write = true
        elseif argument == "-h" or argument == "--help" then show_help() return 0
        elseif not argument:match("^%-") and not project then project = argument
        else fail("unknown or repeated argument " .. argument .. " (see --help)") end
    end
    if not project then fail("name a project folder") end
    local count = tonumber(options.commits or "10")
    if not count or count < 1 or count % 1 ~= 0 then fail("--commits takes a whole number") end
    if options.write and options.out then fail("give --write or --out, not both") end
    if options.json and (options.write or options.out) then fail("--json prints facts only") end

    local facts = gather(project, count)
    if options.json then
        print(require("dkjson").encode(facts, { indent = true }))
        return 0
    end

    local client = require("llama-chat-client")
    local draft, why = client.complete(config.system_prompt, as_prompt(facts))
    if not draft or not draft:match("%S") then fail("the model gave no draft: " .. tostring(why), 1) end
    if not draft:match("\n$") then draft = draft .. "\n" end
    draft = draft .. string.format("\n<!-- draft by history-kernel.lua from the first %d of %d commits; "
        .. "check it before trusting it -->\n", #facts.first_commits, facts.commit_count)

    if options.write then save(project .. "/notes/vision.md", draft)
    elseif options.out then save(options.out, draft)
    else io.write(draft) end
    return 0
end
-- }}}

os.exit(main(arg))
