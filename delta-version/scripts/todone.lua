#!/usr/bin/env luajit
-- todone.lua - which building blocks several projects are each planning to
-- build on their own.
--
-- Issue 053 (TODONE), its smallest useful slice: project scanning (053a)
-- and component matching (053b, its first two tiers). For each project, the
-- titles of its open issues and the headings of its roadmap are handed to the
-- local model, which lists the reusable components the project plans to
-- build (a threadpool, a TUI framework, a JSON parser...). The names are
-- matched across projects:
--   tier 1  the same name once case, spaces, "-" and "_" are ignored
--           (ThreadPool = thread-pool = thread_pool)
--   tier 2  names listed together in config/component-synonyms.conf
-- and every component that two or more projects plan is reported, with the
-- projects that plan it. That is the list of things worth building once.
--
-- Nothing is written anywhere; this only reports.
--
-- Usage: todone.lua [PROJECT_DIR ...] [--all] [--dir=MONOREPO] [--min=N]
--                   [--json] [--each]
--   PROJECT_DIR   the projects to compare, by path
--   --all         every top-level folder of the monorepo with an issues/ folder
--   --min=N       report components planned by at least N projects (default 2)
--   --each        also list what the model found in each project
--   --json        the report as JSON
--   --synonyms=FILE   default config/component-synonyms.conf
--
-- The model is reached through libs/llama-chat-client.lua (INFERENCE_CHAT_HOST
-- moves it). Exit status: 0 done, 1 the model failed for some project (it is
-- named, the rest are still reported), 2 usage error.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff"
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. SCRIPT_DIR .. "/../../libs/lua/?.lua;" .. package.path
local SYNONYMS = SCRIPT_DIR .. "/../config/component-synonyms.conf"
-- }}}

local component_names = require("component-names")
local key_of, load_synonyms = component_names.key_of, component_names.load_synonyms

-- {{{ Configuration
local config = {
    max_prompt_chars = 12000,
    system_prompt = table.concat({
        "Task: components.",
        "You read a software project's planned work: the titles of its open issues and its",
        "roadmap headings. List the reusable building blocks it plans to build that another",
        "project could share, such as a threadpool, a TUI framework, a JSON parser or an LLM",
        "client. One short generic name per line, lower case, no explanations. Leave out",
        "features specific to this project. If there are none, reply with the word none.",
    }, "\n"),
}
-- }}}

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message)
    io.stderr:write("todone: " .. message .. "\n")
    os.exit(2)
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function lines_of()
local function lines_of(command)
    local handle = io.popen(command .. " 2>/dev/null")
    local lines = {}
    if not handle then return lines end
    for line in handle:lines() do lines[#lines + 1] = line end
    handle:close()
    return lines
end
-- }}}

-- {{{ local function first_line()
local function first_line(path)
    local file = io.open(path, "r")
    if not file then return nil end
    for line in file:lines() do
        if line:match("%S") then file:close() return line end
    end
    file:close()
    return nil
end
-- }}}

-- }}}

-- {{{ local function planned_work()
-- The open issue titles and roadmap headings of one project, as text.
local function planned_work(project)
    local out = {}
    local files = lines_of("find " .. shell_quote(project .. "/issues") .. " -name '*.md' -not -path '*/completed/*'"
        .. " -not -path '*/done/*' -not -path '*/archive/*' -not -name 'progress.md' -not -name 'PRIORITY.md'"
        .. " -not -name 'moved-*' | sort")
    for _, path in ipairs(files) do
        local title = first_line(path)
        if title then out[#out + 1] = "issue: " .. title:gsub("^#+%s*", "") end
    end
    local roadmap = io.open(project .. "/docs/roadmap.md", "r")
    if roadmap then
        for line in roadmap:lines() do
            if line:match("^#+%s") then out[#out + 1] = "roadmap: " .. line:gsub("^#+%s*", "") end
        end
        roadmap:close()
    end
    return table.concat(out, "\n"):sub(1, config.max_prompt_chars), #out
end
-- }}}

-- {{{ local function components_of()
-- The component names the model finds in a project's planned work.
local function components_of(client, text)
    local answer, why = client.complete(config.system_prompt, text)
    if not answer then return nil, why end
    local names = {}
    for line in answer:gmatch("[^\n]+") do
        local name = line:gsub("^%s*[%-%*%d%.%)]*%s*", ""):gsub("%s+$", ""):lower()
        if name ~= "" and name ~= "none" and #name <= 60 then names[#names + 1] = name end
    end
    return names
end
-- }}}

-- {{{ local function choose_projects()
local function choose_projects(paths, all)
    local projects = {}
    for _, path in ipairs(paths) do
        local clean = path:gsub("/+$", "")
        projects[#projects + 1] = clean
    end
    if all then
        for _, path in ipairs(lines_of("find " .. shell_quote(DIR) .. " -mindepth 2 -maxdepth 2 -type d -name issues | sort")) do
            projects[#projects + 1] = path:gsub("/issues$", "")
        end
    end
    return projects
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
    local options, paths = {}, {}
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if key and ({ dir = true, min = true, synonyms = true })[key] then options[key] = value
        elseif argument == "--all" or argument == "--json" or argument == "--each" then
            options[argument:sub(3)] = true
        elseif argument == "-h" or argument == "--help" then show_help() return 0
        elseif not argument:match("^%-") then paths[#paths + 1] = argument
        else fail("unknown argument " .. argument .. " (see --help)") end
    end
    if options.dir then DIR = options.dir end
    local minimum = tonumber(options.min or "2")
    if not minimum or minimum < 1 or minimum % 1 ~= 0 then fail("--min takes a whole number") end
    local projects = choose_projects(paths, options.all)
    if #projects < 2 then fail("name two or more project folders, or give --all") end

    local synonyms = load_synonyms(options.synonyms or SYNONYMS)
    local client = require("llama-chat-client")
    local by_key, order, each, failed = {}, {}, {}, {}
    for _, project in ipairs(projects) do
        local name = project:match("([^/]+)$")
        local text, count = planned_work(project)
        if count == 0 then
            each[#each + 1] = { project = name, components = {}, note = "no open issues or roadmap" }
        else
            local names, why = components_of(client, text)
            if not names then
                failed[#failed + 1] = name .. ": " .. tostring(why)
            else
                local seen = {}
                for _, component in ipairs(names) do
                    local key = key_of(component)
                    local shown = synonyms[key] or component
                    key = key_of(shown)
                    if not seen[key] then
                        seen[key] = true
                        if not by_key[key] then
                            by_key[key] = { name = shown, projects = {} }
                            order[#order + 1] = by_key[key]
                        end
                        local entry = by_key[key]
                        entry.projects[#entry.projects + 1] = name
                    end
                end
                each[#each + 1] = { project = name, components = names }
            end
        end
    end

    local shared = {}
    for _, entry in ipairs(order) do
        if #entry.projects >= minimum then shared[#shared + 1] = entry end
    end
    table.sort(shared, function(a, b)
        if #a.projects ~= #b.projects then return #a.projects > #b.projects end
        return a.name < b.name
    end)

    if options.json then
        print(require("dkjson").encode({ projects = #projects, minimum = minimum, shared = shared,
            each = options.each and each or nil, failed = failed }, { indent = true }))
    else
        if #shared == 0 then
            print(string.format("No component is planned by %d or more of the %d projects.", minimum, #projects))
        else
            print(string.format("Planned by %d or more of %d projects (worth building once):\n", minimum, #projects))
            for _, entry in ipairs(shared) do
                print(string.format("  %-24s %d  %s", entry.name, #entry.projects, table.concat(entry.projects, ", ")))
            end
        end
        if options.each then
            print("\nEach project:")
            for _, item in ipairs(each) do
                print(string.format("  %-24s %s", item.project, item.note or
                    (#item.components > 0 and table.concat(item.components, ", ") or "none")))
            end
        end
        for _, line in ipairs(failed) do io.stderr:write("todone: the model failed for " .. line .. "\n") end
    end
    return #failed > 0 and 1 or 0
end
-- }}}

os.exit(main(arg))
