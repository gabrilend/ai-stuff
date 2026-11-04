#!/usr/bin/env luajit
-- discover-projects.lua - Choose which projects a ticket should go to.
--
-- Issue 018 asked for a project discovery system for ticket distribution.
-- The rules for which folders are projects, and what kind each one is, live
-- in one shared place: scripts/libs/project-discovery.lua (the rules
-- list-projects.sh has always used, lifted into a library). This script
-- does not hold a second copy of them. It loads that library for the
-- project list and each project's kind, asks census-projects.lua for each
-- project's state and issue counts, and adds the two things neither has:
--
--   language census -- every language a project uses, counted from the files
--                      git tracks in it (vendored and generated folders left
--                      out), in the library's own vocabulary of kinds;
--   selection       -- filters that pick the projects a ticket is for, by
--                      kind, a language used, state, a path the project
--                      holds, recent activity, or by name, alone or from a
--                      named profile in config/project-discovery.conf.
--
-- Filters are explicit rather than a relevance score: a project is chosen
-- because it matched every filter given, and --table shows why.
--
-- Usage:
--   discover-projects.lua [filters] [output]
--
-- Filters (all must match; lists are comma-separated, any one matches):
--   --language=lua,c       the project's kind (from the library) is one of these
--   --uses=shell           the project tracks at least one file of one of these
--   --state=tracked,building   census state (tracked, building, vision, empty)
--   --has=PATH             the project holds PATH (file or folder); repeatable
--   --active-days=N        a tracked file in it changed in the last N days
--   --only=a,b             only these projects
--   --exclude=a,b          never these projects
--   --profile=NAME         start from a profile's filters; options add to it
--
-- Output (one of):
--   --names (default)  one project name per line
--   --paths            one absolute path per line
--   --table            name, state, kind, files, issues
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
-- The tools this one stands on are found beside it, not under --dir, so a
-- test can point --dir at a scratch monorepo.
local CENSUS = SCRIPT_DIR .. "/census-projects.lua"
local LIBRARY = SCRIPT_DIR .. "/../../scripts/libs/project-discovery.lua"
local CONFIG_PATH = SCRIPT_DIR .. "/../config/project-discovery.conf"
-- }}}

-- {{{ Configuration
local config = {
    -- Interpreters named on a #! line, for scripts with no extension, given
    -- in the library's vocabulary of kinds.
    shebangs = { luajit = "lua", lua = "lua", bash = "shell", sh = "shell",
                 python = "python", python3 = "python", node = "node" },
    -- Folders inside a project that hold someone else's code or the
    -- project's own generated output; their files say nothing about what the
    -- project is written in. The census leaves the same materials out of its
    -- activity ranking.
    not_its_own = { libs = true, vendor = true, node_modules = true,
                    external = true, third_party = true, ["third-party"] = true },
    materials = { "^input/", "^output/", "^docs/HTML/", "^llm%-transcripts/" },
    states = { tracked = true, building = true, vision = true, empty = true, unknown = true },
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
-- {{{ local function load_library()
local function load_library()
    local ok, library = pcall(dofile, LIBRARY)
    if not ok or type(library) ~= "table" then
        fail("cannot load the shared project-discovery library at " .. LIBRARY)
    end
    return library
end
-- }}}

-- {{{ local function census_states()
-- The census's state and issue counts for each project it lists, by name.
-- Its JSON list has one project per line in a fixed shape, so it is read
-- with patterns rather than a JSON library. A census that cannot run
-- leaves every state "unknown" rather than stopping discovery.
local function census_states()
    local command = string.format("luajit %s --json --dir=%s 2>/dev/null",
        shell_quote(CENSUS), shell_quote(DIR .. "/delta-version"))
    local states = {}
    for _, line in ipairs(read_lines(command)) do
        local name, state = line:match('"name": "(.-)", "state": "(.-)"')
        if name then
            states[name] = {
                state = state,
                open = tonumber(line:match('"open": (%d+)')) or 0,
                completed = tonumber(line:match('"completed": (%d+)')) or 0,
                total = tonumber(line:match('"total": (%d+)')) or 0,
            }
        end
    end
    return states
end
-- }}}

-- {{{ local function gather()
-- The library's projects, each joined with what the census knows of it.
local function gather(library)
    library.init(DIR)
    local states = census_states()
    local projects, by_name = {}, {}
    for _, entry in ipairs(library.scan()) do
        local known = states[entry.name] or {}
        local record = {
            name = entry.name, path = DIR .. "/" .. entry.name,
            kind = entry.type or "unknown", score = entry.score,
            state = known.state or "unknown",
            open = known.open or 0, completed = known.completed or 0, total = known.total or 0,
            languages = {}, files = 0,
        }
        projects[#projects + 1] = record
        by_name[record.name] = record
    end
    return projects, by_name
end
-- }}}

-- {{{ local function owner_of()
-- The project a repository path belongs to, and the part of the path inside
-- it. Projects are the library's, which sit directly under DIR.
local function owner_of(path, by_name)
    local top, inside = path:match("^([^/]+)/(.+)$")
    if top and by_name[top] then return by_name[top], inside end
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
local function language_of(path, extensions)
    local base = path:match("([^/]+)$")
    local extension = base:match("%.([^.]+)$")
    if extension then return extensions[extension:lower()] end
    -- No extension: a script says what runs it on its first line. Only the
    -- first bytes are read, and only of a regular file (see count_languages).
    local file = io.open(DIR .. "/" .. path, "r")
    if not file then return nil end
    local first = (file:read(128) or ""):match("^[^\n]*")
    file:close()
    local interpreter = first:match("^#!%S*/env%s+(%S+)") or first:match("^#!%S*/(%S+)")
    return interpreter and config.shebangs[interpreter] or nil
end
-- }}}

-- {{{ local function count_languages()
-- Counts every tracked file of a known kind into its project. Only regular
-- files count. A tracked symbolic link is skipped: it is a second name for a
-- file counted elsewhere, and reading through one can reach anything (Wine's
-- dosdevices links in this repository point at serial ports and disks).
local function count_languages(by_name, extensions)
    local command = string.format("git -C %s -c core.quotepath=off ls-files --stage", shell_quote(DIR))
    for _, line in ipairs(read_lines(command)) do
        local mode, path = line:match("^(%d+) %x+ %d+\t(.+)$")
        local project, inside
        if mode == "100644" or mode == "100755" then
            project, inside = owner_of(path, by_name)
        end
        if project and not is_material(inside) then
            local language = language_of(path, extensions)
            if language then
                project.languages[language] = (project.languages[language] or 0) + 1
                project.files = project.files + 1
            end
        end
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
-- {{{ local function known_kinds()
-- Every kind the library can name: its source-file kinds, its build-file
-- kinds, and "unknown".
local function known_kinds(library)
    local kinds = { unknown = true }
    for _, kind in pairs(library.EXTENSIONS) do kinds[kind] = true end
    for _, build in ipairs(library.BUILD_FILES) do kinds[build.type] = true end
    return kinds
end
-- }}}

-- {{{ local function check_filters()
-- Refuses names that cannot match anything, so a typo is an error rather
-- than an empty result that looks like an answer.
local function check_filters(filters, by_name, kinds)
    for _, key in ipairs({ "language", "uses" }) do
        for _, kind in ipairs(filters[key] or {}) do
            if not kinds[kind] then
                local names = {}
                for name in pairs(kinds) do names[#names + 1] = name end
                table.sort(names)
                fail("unknown kind '" .. kind .. "' in --" .. key
                    .. " (kinds: " .. table.concat(names, ", ") .. ")")
            end
        end
    end
    for _, state in ipairs(filters.state or {}) do
        if not config.states[state] then
            fail("unknown state '" .. state .. "' (tracked, building, vision, empty, unknown)")
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
    if filters.language and not set_of(filters.language)[project.kind] then return false end
    if filters.uses then
        local any = false
        for _, kind in ipairs(filters.uses) do
            if project.languages[kind] then any = true end
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
    print(string.format("%-40s %-9s %-8s %6s  %s", "PROJECT", "STATE", "KIND", "FILES", "ISSUES"))
    for _, project in ipairs(chosen) do
        local issues = project.total > 0
            and string.format("%d/%d done", project.completed, project.total) or "-"
        print(string.format("%-40s %-9s %-8s %6d  %s", project.name, project.state,
            project.kind, project.files, issues))
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
            '    { "name": %s, "path": %s, "kind": %s, "score": %d, "state": %s, "files": %d, "languages": { %s }, "open": %d, "completed": %d, "total": %d%s }%s',
            json_string(project.name), json_string(project.path), json_string(project.kind),
            project.score, json_string(project.state), project.files, table.concat(parts, ", "),
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
    local library = load_library()
    local projects, by_name = gather(library)
    check_filters(filters, by_name, known_kinds(library))
    count_languages(by_name, library.EXTENSIONS)
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
