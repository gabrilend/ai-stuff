#!/usr/bin/env luajit
-- discover-projects.lua - Choose which projects a ticket should go to.
--
-- Issue 018 asked for a project discovery system for ticket distribution.
-- Most of it already exists: census-projects.lua decides what is a project
-- (shelves like games/ opened up, furniture like libs/ skipped, backups and
-- copies left out) and what state each one is in, and list-projects.sh keeps
-- the external directories outside the repository. This script does not
-- repeat any of that. It asks the census for the project list and adds the
-- two things neither tool has:
--
--   classification -- each project's languages, counted from the files git
--                     tracks in it (vendored and generated folders left out),
--                     and the dominant one;
--   selection      -- filters that pick the projects a ticket is for, by
--                     language, state, a path the project holds, recent
--                     activity, or by name, alone or from a named profile in
--                     config/project-discovery.conf.
--
-- Filters are explicit rather than a relevance score: a project is chosen
-- because it matched every filter given, and --table shows why.
--
-- Usage:
--   discover-projects.lua [filters] [output]
--
-- Filters (all must match; lists are comma-separated, any one matches):
--   --language=lua,c       dominant language is one of these
--   --uses=bash            the project tracks at least one file in one of these
--   --state=tracked,building   census state (tracked, building, vision, empty)
--   --has=PATH             the project holds PATH (file or folder); repeatable
--   --active-days=N        a tracked file in it changed in the last N days
--   --only=a,games/b       only these projects (names as the census gives them)
--   --exclude=a,b          never these projects
--   --profile=NAME         start from a profile's filters; options add to it
--
-- Output (one of):
--   --names (default)  one project name per line
--   --paths            one absolute path per line
--   --table            name, state, dominant language, files, issues
--   --json             everything, for other scripts
--   --list-profiles    the profiles the configuration defines
--
-- Other options:
--   --dir=/path/to/monorepo   default /mnt/mtwo/programming/ai-stuff
--   --config=PATH             default <this script's project>/config/project-discovery.conf
--
-- Exit status: 0 when projects were chosen, 1 when none matched, 2 for a
-- usage or configuration error.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff"
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
local CENSUS = SCRIPT_DIR .. "/census-projects.lua"
local CONFIG_PATH = SCRIPT_DIR .. "/../config/project-discovery.conf"
-- }}}

-- {{{ Configuration
local config = {
    -- File extensions and the language they are written in.
    extensions = {
        lua = "lua", c = "c", h = "c",
        cc = "c++", cpp = "c++", cxx = "c++", hpp = "c++", hh = "c++",
        rs = "rust", sh = "bash", bash = "bash", py = "python",
        js = "javascript", mjs = "javascript", cjs = "javascript",
        ts = "typescript", go = "go", java = "java", zig = "zig", nim = "nim",
        rb = "ruby", pl = "perl", fnl = "fennel", moon = "moonscript",
        html = "html", htm = "html", css = "css",
        glsl = "glsl", vert = "glsl", frag = "glsl", asm = "assembly", s = "assembly",
    },
    -- Interpreters named on a #! line, for scripts with no extension.
    shebangs = { luajit = "lua", lua = "lua", bash = "bash", sh = "bash",
                 python = "python", python3 = "python", perl = "perl", node = "javascript" },
    -- Folders inside a project that hold someone else's code or the
    -- project's own generated output; their files say nothing about what the
    -- project is written in. The census leaves the same materials out of its
    -- activity ranking.
    not_its_own = { libs = true, vendor = true, node_modules = true,
                    external = true, third_party = true, ["third-party"] = true },
    materials = { "^input/", "^output/", "^docs/HTML/", "^llm%-transcripts/" },
    states = { tracked = true, building = true, vision = true, empty = true },
    -- Keys a profile may set, and whether each takes a list.
    profile_keys = { language = true, uses = true, state = true, has = true,
                     ["active-days"] = false, only = true, exclude = true,
                     description = false },
}
-- }}}

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message)
    io.stderr:write("discover-projects: " .. message .. "\n")
    os.exit(2)
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function read_lines()
local function read_lines(command)
    local handle = io.popen(command)
    if not handle then return {} end
    local lines = {}
    for line in handle:lines() do lines[#lines + 1] = line end
    handle:close()
    return lines
end
-- }}}

-- {{{ local function split_list()
local function split_list(text)
    local items = {}
    for item in text:gmatch("[^,]+") do
        item = item:match("^%s*(.-)%s*$")
        if item ~= "" then items[#items + 1] = item end
    end
    return items
end
-- }}}

-- {{{ local function set_of()
local function set_of(list)
    local set = {}
    for _, item in ipairs(list) do set[item] = true end
    return set
end
-- }}}

-- {{{ local function exists()
local function exists(path)
    local ok, _, code = os.rename(path, path)
    return ok or code == 13
end
-- }}}

-- {{{ local function json_string()
local function json_string(text)
    return '"' .. text:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end
-- }}}
-- }}}

-- {{{ Arguments
-- {{{ local function parse_arguments()
local function parse_arguments(argv)
    local options = { filters = { has = {} }, output = "names" }
    local filters = options.filters
    local outputs = { ["--names"] = "names", ["--paths"] = "paths",
                      ["--table"] = "table", ["--json"] = "json",
                      ["--list-profiles"] = "profiles" }
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if outputs[argument] then
            options.output = outputs[argument]
        elseif key == "dir" then DIR = value
        elseif key == "config" then CONFIG_PATH = value
        elseif key == "profile" then options.profile = value
        elseif key == "has" then filters.has[#filters.has + 1] = value
        elseif key == "active-days" then filters["active-days"] = value
        elseif key == "language" or key == "uses" or key == "state"
            or key == "only" or key == "exclude" then
            filters[key] = split_list(value)
        elseif argument == "-h" or argument == "--help" then
            options.output = "help"
        else
            fail("unknown option: " .. argument .. " (see --help)")
        end
    end
    return options
end
-- }}}
-- }}}

-- {{{ Profiles
-- {{{ local function load_profiles()
-- An INI file: [profile-name] sections of key = value lines, # comments.
local function load_profiles(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local profiles, order, current = {}, {}, nil
    local number = 0
    for line in file:lines() do
        number = number + 1
        local stripped = line:match("^%s*(.-)%s*$")
        if stripped == "" or stripped:match("^[#;]") then
            -- blank or comment
        elseif stripped:match("^%[.+%]$") then
            local name = stripped:match("^%[%s*(.-)%s*%]$")
            current = { has = {} }
            profiles[name] = current
            order[#order + 1] = name
        else
            local key, value = stripped:match("^([%w%-]+)%s*=%s*(.-)$")
            if not key or not current then
                file:close()
                fail(string.format("%s:%d: expected [profile] or key = value", path, number))
            end
            if config.profile_keys[key] == nil then
                file:close()
                fail(string.format("%s:%d: unknown key '%s'", path, number, key))
            end
            if key == "has" then
                for _, item in ipairs(split_list(value)) do current.has[#current.has + 1] = item end
            elseif config.profile_keys[key] then
                current[key] = split_list(value)
            else
                current[key] = value
            end
        end
    end
    file:close()
    return profiles, order
end
-- }}}

-- {{{ local function merge_profile()
-- A profile's filters first, then the command line's on top: a list option
-- given on the command line replaces the profile's, and --has adds to it.
local function merge_profile(profile, filters)
    local merged = { has = {} }
    for key, value in pairs(profile) do
        if key ~= "has" and key ~= "description" then merged[key] = value end
    end
    for _, path in ipairs(profile.has or {}) do merged.has[#merged.has + 1] = path end
    for key, value in pairs(filters) do
        if key == "has" then
            for _, path in ipairs(value) do merged.has[#merged.has + 1] = path end
        else
            merged[key] = value
        end
    end
    return merged
end
-- }}}
-- }}}

-- {{{ Discovery
-- {{{ local function census_projects()
-- The census's JSON list, one project per line; read with patterns rather
-- than a JSON library because the census writes a fixed shape.
local function census_projects()
    local command = string.format("luajit %s --json --dir=%s 2>/dev/null",
        shell_quote(CENSUS), shell_quote(DIR .. "/delta-version"))
    local projects, by_name = {}, {}
    for _, line in ipairs(read_lines(command)) do
        local name, state = line:match('"name": "(.-)", "state": "(.-)"')
        if name then
            local record = {
                name = name, state = state, path = DIR .. "/" .. name,
                open = tonumber(line:match('"open": (%d+)')) or 0,
                completed = tonumber(line:match('"completed": (%d+)')) or 0,
                total = tonumber(line:match('"total": (%d+)')) or 0,
                languages = {}, files = 0, language = "none",
            }
            projects[#projects + 1] = record
            by_name[name] = record
        end
    end
    if #projects == 0 then
        fail("the census listed no projects (is " .. DIR .. " the monorepo?)")
    end
    return projects, by_name
end
-- }}}

-- {{{ local function owner_of()
-- The project a repository path belongs to: the longest project name it
-- starts with, so a subproject's files are not also its parent's. Returns
-- the project and the part of the path inside it.
local function owner_of(path, by_name)
    local segments = {}
    for segment in path:gmatch("[^/]+") do segments[#segments + 1] = segment end
    for depth = math.min(4, #segments - 1), 1, -1 do
        local prefix = table.concat(segments, "/", 1, depth)
        if by_name[prefix] then
            return by_name[prefix], path:sub(#prefix + 2)
        end
    end
    return nil
end
-- }}}

-- {{{ local function is_material()
local function is_material(inside)
    for segment in inside:gmatch("([^/]+)/") do
        if config.not_its_own[segment] then return true end
    end
    for _, pattern in ipairs(config.materials) do
        if inside:match(pattern) then return true end
    end
    return false
end
-- }}}

-- {{{ local function language_of()
local function language_of(path)
    local base = path:match("([^/]+)$")
    local extension = base:match("%.([^.]+)$")
    if extension then return config.extensions[extension:lower()] end
    -- No extension: a script says what runs it on its first line. Only the
    -- first bytes are read, and only of a regular file (see classify).
    local file = io.open(DIR .. "/" .. path, "r")
    if not file then return nil end
    local first = (file:read(128) or ""):match("^[^\n]*")
    file:close()
    local interpreter = first:match("^#!%S*/env%s+(%S+)") or first:match("^#!%S*/(%S+)")
    return interpreter and config.shebangs[interpreter] or nil
end
-- }}}

-- {{{ local function classify()
-- Counts every tracked file of a known language into its project, then
-- names each project's dominant language (most files; ties by name).
-- Only regular files count. A tracked symbolic link is skipped: it is a
-- second name for a file counted elsewhere, and reading through one can
-- reach anything (one in this repository points at a serial device).
local function classify(by_name)
    local command = string.format("git -C %s -c core.quotepath=off ls-files --stage", shell_quote(DIR))
    for _, line in ipairs(read_lines(command)) do
        local mode, path = line:match("^(%d+) %x+ %d+\t(.+)$")
        local project, inside
        if mode == "100644" or mode == "100755" then
            project, inside = owner_of(path, by_name)
        end
        if project and not is_material(inside) then
            local language = language_of(path)
            if language then
                project.languages[language] = (project.languages[language] or 0) + 1
                project.files = project.files + 1
            end
        end
    end
    for _, project in pairs(by_name) do
        local best, best_count = "none", 0
        for language, count in pairs(project.languages) do
            if count > best_count or (count == best_count and language < best) then
                best, best_count = language, count
            end
        end
        project.language = best
    end
end
-- }}}

-- {{{ local function mark_active()
-- Marks each project that a commit in the last `days` days touched, not
-- counting changes to its materials (as the census does).
local function mark_active(by_name, days)
    local command = string.format(
        "git -C %s -c core.quotepath=off log --since=%s --name-only --pretty=format:",
        shell_quote(DIR), shell_quote(days .. ".days.ago"))
    for _, path in ipairs(read_lines(command)) do
        if path ~= "" then
            local project, inside = owner_of(path, by_name)
            if project and not is_material(inside) then project.active = true end
        end
    end
end
-- }}}
-- }}}

-- {{{ Selection
-- {{{ local function check_filters()
-- Refuses names that cannot match anything, so a typo is an error rather
-- than an empty result that looks like an answer.
local function check_filters(filters, by_name)
    local known_languages = {}
    for _, language in pairs(config.extensions) do known_languages[language] = true end
    for _, key in ipairs({ "language", "uses" }) do
        for _, language in ipairs(filters[key] or {}) do
            if not known_languages[language] then
                fail("unknown language '" .. language .. "' in --" .. key)
            end
        end
    end
    for _, state in ipairs(filters.state or {}) do
        if not config.states[state] then
            fail("unknown state '" .. state .. "' (tracked, building, vision, empty)")
        end
    end
    for _, key in ipairs({ "only", "exclude" }) do
        for _, name in ipairs(filters[key] or {}) do
            if not by_name[name] then fail("--" .. key .. " names no project: " .. name) end
        end
    end
    local days = filters["active-days"]
    if days and not tostring(days):match("^%d+$") then
        fail("--active-days needs a whole number of days, not '" .. tostring(days) .. "'")
    end
    for _, path in ipairs(filters.has) do
        if path:match("^/") or path:match("%.%.") then
            fail("--has takes a path inside the project, not '" .. path .. "'")
        end
    end
end
-- }}}

-- {{{ local function matches()
local function matches(project, filters)
    if filters.only and not set_of(filters.only)[project.name] then return false end
    if filters.exclude and set_of(filters.exclude)[project.name] then return false end
    if filters.state and not set_of(filters.state)[project.state] then return false end
    if filters.language and not set_of(filters.language)[project.language] then return false end
    if filters.uses then
        local any = false
        for _, language in ipairs(filters.uses) do
            if project.languages[language] then any = true end
        end
        if not any then return false end
    end
    for _, path in ipairs(filters.has) do
        if not exists(project.path .. "/" .. path) then return false end
    end
    if filters["active-days"] and not project.active then return false end
    return true
end
-- }}}
-- }}}

-- {{{ Rendering
-- {{{ local function render_table()
local function render_table(chosen)
    print(string.format("%-40s %-9s %-11s %6s  %s", "PROJECT", "STATE", "LANGUAGE", "FILES", "ISSUES"))
    for _, project in ipairs(chosen) do
        local issues = project.total > 0
            and string.format("%d/%d done", project.completed, project.total) or "-"
        print(string.format("%-40s %-9s %-11s %6d  %s", project.name, project.state,
            project.language, project.files, issues))
    end
    print(string.format("\n%d project(s)", #chosen))
end
-- }}}

-- {{{ local function render_json()
local function render_json(chosen, filters)
    print("{")
    print(string.format('  "count": %d,', #chosen))
    print('  "projects": [')
    for index, project in ipairs(chosen) do
        local names = {}
        for language in pairs(project.languages) do names[#names + 1] = language end
        table.sort(names)
        local parts = {}
        for _, language in ipairs(names) do
            parts[#parts + 1] = string.format("%s: %d", json_string(language), project.languages[language])
        end
        print(string.format(
            '    { "name": %s, "path": %s, "state": %s, "language": %s, "files": %d, "languages": { %s }, "open": %d, "completed": %d, "total": %d%s }%s',
            json_string(project.name), json_string(project.path), json_string(project.state),
            json_string(project.language), project.files, table.concat(parts, ", "),
            project.open, project.completed, project.total,
            filters["active-days"] and ', "active": true' or "",
            index < #chosen and "," or ""))
    end
    print("  ]")
    print("}")
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
-- }}}

-- {{{ main
local function main()
    local options = parse_arguments(arg)
    if options.output == "help" then show_help() return 0 end

    local filters = options.filters
    local profiles, order = load_profiles(CONFIG_PATH)
    if options.output == "profiles" then
        if not profiles then fail("no configuration at " .. CONFIG_PATH) end
        for _, name in ipairs(order) do
            print(string.format("%-20s %s", name, profiles[name].description or ""))
        end
        return 0
    end
    if options.profile then
        if not profiles then fail("no configuration at " .. CONFIG_PATH) end
        local profile = profiles[options.profile]
        if not profile then
            fail("no profile '" .. options.profile .. "' in " .. CONFIG_PATH
                .. " (have: " .. table.concat(order, ", ") .. ")")
        end
        filters = merge_profile(profile, filters)
    end

    -- Languages and activity come from git, so DIR must be the top of the
    -- repository, not merely a folder with projects in it.
    if not exists(DIR .. "/.git") then
        fail(DIR .. " is not the top of a git repository (see --dir)")
    end
    local projects, by_name = census_projects()
    check_filters(filters, by_name)
    classify(by_name)
    if filters["active-days"] then mark_active(by_name, filters["active-days"]) end

    local chosen = {}
    for _, project in ipairs(projects) do
        if matches(project, filters) then chosen[#chosen + 1] = project end
    end
    table.sort(chosen, function(a, b) return a.name < b.name end)

    if options.output == "table" then
        render_table(chosen)
    elseif options.output == "json" then
        render_json(chosen, filters)
    else
        for _, project in ipairs(chosen) do
            print(options.output == "paths" and project.path or project.name)
        end
    end
    return #chosen > 0 and 0 or 1
end
-- }}}

os.exit(main())
