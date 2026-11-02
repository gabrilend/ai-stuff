#!/usr/bin/env luajit
-- distribute-ticket.lua - File one ticket template as a new issue in many projects.
--
-- Issue 019, the step after keyword processing (017) and project discovery
-- (018). A ticket template is written once, with ][keyword[] placeholders;
-- this script chooses the projects it is for, gives each its next free
-- issue number, fills the template with that project's facts, and writes it
-- into the project's issues/ folder. It holds none of those rules itself:
--
--   which projects        discover-projects.lua (same filters and profiles)
--   which phase           scripts/libs/issue-names.lua, the shared reader
--   which number          scripts/validate-issues --next PHASE
--   filling the template  libs/kml.lua with config/ticket-keywords.conf,
--                         layered with the project's own keyword file
--
-- It is a dry run unless --write is given: by default it prints what each
-- project would receive and writes nothing. With --write each ticket is
-- written once, never over an existing file, and recorded in
-- assets/ticket-distributions.tsv with a checksum. A template already filed
-- in a project (found by the marker line each ticket ends with) is not filed
-- there again unless --again is given, so a re-run only reaches the projects
-- it missed. --undo takes a distribution back out: it removes only the
-- tickets that are still exactly as they were written, so an issue someone
-- has since edited is left alone and named.
--
-- Usage:
--   distribute-ticket.lua <template> --phase=N|current <targets> [options]
--
-- Targets (at least one; passed to discover-projects.lua):
--   --projects=a,b         exactly these projects
--   --profile=NAME --language=.. --uses=.. --state=.. --has=PATH
--   --active-days=N --only=a,b --exclude=a,b
--
-- Filing:
--   --phase=N              file into phase N in every project
--   --phase=current        each project's lowest phase with open issues;
--                          else its highest phase; else phase 1
--   --slug=some-words      the file name's description (default: the
--                          template's first heading)
--   --error-mode=MODE      KML error mode (default fail: a ticket with a
--                          keyword that could not be filled is not written)
--   --again                file it even where this template already was
--   --create-issues        give a project with no issues/ folder one
--                          (issues/ and issues/completed/); without it such
--                          a project is skipped
--
-- Doing it:
--   (default)              dry run: print the plan, write nothing
--   --write                write the tickets and record them
--   --show=PROJECT         print the filled ticket one project would get
--   --undo=D-YYYYMMDD-HHMMSS   remove that distribution's unedited tickets
--                          (a dry run too unless --write is given)
--   --ledger=PATH          the record, default assets/ticket-distributions.tsv
--   --dir=/path/to/monorepo   default /mnt/mtwo/programming/ai-stuff
--
--   distribute-ticket.lua --undo=D-... [--write] [--ledger=] [--dir=]
--
-- Exit status: 0 when every chosen project got (or would get) the ticket;
-- 1 when any was skipped (each line says why); 2 for a usage error or when
-- no project was chosen.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff"
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
local DELTA = SCRIPT_DIR .. "/.."
local DISCOVER = SCRIPT_DIR .. "/discover-projects.lua"
local VALIDATE = SCRIPT_DIR .. "/../../scripts/validate-issues"
local ISSUE_NAMES = SCRIPT_DIR .. "/../../scripts/libs/issue-names.lua"
local KML = SCRIPT_DIR .. "/libs/kml.lua"
local LEDGER = DELTA .. "/assets/ticket-distributions.tsv"
-- }}}

-- {{{ Configuration
local config = {
    -- Options handed to discover-projects.lua unchanged.
    target_options = { profile = true, language = true, uses = true, state = true,
                       has = true, ["active-days"] = true, only = true, exclude = true },
    -- The line each filed ticket ends with; how a re-run knows it was filed.
    marker = "<!-- ticket-template: %s, distributed %s as %s -->",
    slug_words = 6,
    ledger_columns = { "date", "distribution", "template", "project", "file", "sha256", "status" },
}
-- }}}

-- {{{ Utility Functions
-- {{{ local function fail_usage()
local function fail_usage(message)
    io.stderr:write("distribute-ticket: " .. message .. "\n")
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

-- {{{ local function read_file()
local function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return text
end
-- }}}

-- {{{ local function exists()
local function exists(path)
    local ok, _, code = os.rename(path, path)
    return ok or code == 13
end
-- }}}

-- {{{ local function checksum()
local function checksum(path)
    local line = read_lines("sha256sum " .. shell_quote(path) .. " 2>/dev/null")[1]
    return line and line:match("^(%x+)") or nil
end
-- }}}

-- {{{ local function slugify()
local function slugify(text)
    local words = {}
    for word in text:lower():gsub("[^%w%s%-]", " "):gmatch("[%w%-]+") do
        if #words < config.slug_words then words[#words + 1] = word end
    end
    local slug = table.concat(words, "-"):gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
    return slug
end
-- }}}
-- }}}

-- {{{ Arguments
-- {{{ local function parse_arguments()
local function parse_arguments(argv)
    local options = { targets = {}, write = false, again = false, error_mode = "fail" }
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if argument == "--write" then options.write = true
        elseif argument == "--again" then options.again = true
        elseif argument == "--create-issues" then options.create_issues = true
        elseif key == "ledger" then LEDGER = value
        elseif key == "undo" then options.undo = value
        elseif argument == "-h" or argument == "--help" then options.help = true
        elseif key == "dir" then DIR = value
        elseif key == "phase" then options.phase = value
        elseif key == "slug" then options.slug = value
        elseif key == "error-mode" then options.error_mode = value
        elseif key == "show" then options.show = value
        elseif key == "projects" then
            options.targets[#options.targets + 1] = "--only=" .. value
        elseif key and config.target_options[key] then
            options.targets[#options.targets + 1] = argument
        elseif not argument:match("^%-") and not options.template then
            options.template = argument
        else
            fail_usage("unknown or repeated argument: " .. argument .. " (see --help)")
        end
    end
    return options
end
-- }}}

-- {{{ local function check_arguments()
local function check_arguments(options, kml)
    if options.undo then
        if not options.undo:match("^D%-%d%d%d%d%d%d%d%d%-%d%d%d%d%d%d$") then
            fail_usage("--undo takes a distribution id like D-20261102-142530")
        end
        if options.template or #options.targets > 0 or options.show then
            fail_usage("--undo takes no template, targets or --show")
        end
        return
    end
    if not options.template then fail_usage("name a ticket template (see --help)") end
    if not read_file(options.template) then fail_usage("cannot read the template " .. options.template) end
    if not options.phase then fail_usage("say which phase to file into: --phase=N or --phase=current") end
    if options.phase ~= "current" and not options.phase:match("^%d+$") and not options.phase:match("^[A-Z]$") then
        fail_usage("--phase takes a number, a capital letter, or current")
    end
    if #options.targets == 0 then
        fail_usage("choose the projects (--projects, --profile or a filter); "
            .. "every project is never chosen by default")
    end
    if not kml.ERROR_MODES[options.error_mode] then
        fail_usage("unknown --error-mode " .. options.error_mode)
    end
    if options.slug and (options.slug == "" or options.slug:match("[^a-z0-9%-]")) then
        fail_usage("--slug takes lower-case letters, digits and dashes")
    end
    if options.write and options.show then
        fail_usage("--show is a dry run; it cannot go with --write")
    end
end
-- }}}
-- }}}

-- {{{ Per-project steps
-- {{{ local function chosen_projects()
-- The projects discover-projects.lua chooses for these filters, as paths.
local function chosen_projects(targets)
    local quoted = {}
    for index, target in ipairs(targets) do quoted[index] = shell_quote(target) end
    local command = string.format("luajit %s --dir=%s --paths %s 2>&1",
        shell_quote(DISCOVER), shell_quote(DIR), table.concat(quoted, " "))
    local handle = io.popen(command)
    local lines = {}
    for line in handle:lines() do lines[#lines + 1] = line end
    local ok, _, code = handle:close()
    -- LuaJIT's close() gives no status; a refusal is recognised by its text.
    if lines[1] and lines[1]:match("^discover%-projects: ") then
        fail_usage(lines[1]:gsub("^discover%-projects: ", "choosing projects: "))
    end
    return lines
end
-- }}}

-- {{{ local function current_phase()
-- A project's lowest phase with open issues; else its highest phase; else 1.
local function current_phase(issue_names, project_path)
    local ok, issues = pcall(issue_names.scan, project_path)
    if not ok then return "1" end
    local lowest_open, highest
    for _, issue in ipairs(issues) do
        if issue.phase then
            local key = issue_names.phase_sort_key(issue.phase)
            if issue.status == "open" and (not lowest_open or key < issue_names.phase_sort_key(lowest_open)) then
                lowest_open = issue.phase
            end
            if not highest or key > issue_names.phase_sort_key(highest) then
                highest = issue.phase
            end
        end
    end
    return lowest_open or highest or "1"
end
-- }}}

-- {{{ local function next_id()
local function next_id(project_path, phase)
    local lines = read_lines(string.format("%s %s --next %s 2>/dev/null",
        shell_quote(VALIDATE), shell_quote(project_path), shell_quote(phase)))
    local id = lines[1]
    if id and id:match("^[%w%-]+$") then return id end
    return nil
end
-- }}}

-- {{{ local function already_filed()
-- The issue file in a project that already carries this template's marker.
local function already_filed(project_path, template_name)
    local pattern = "ticket-template: " .. template_name .. ", distributed "
    local found = read_lines(string.format("grep -rlF -- %s %s 2>/dev/null | head -1",
        shell_quote(pattern), shell_quote(project_path .. "/issues")))
    return found[1]
end
-- }}}

-- {{{ local function fill()
local function fill(kml, text, project_path, template_name, id, error_mode)
    local keyword_config, why = kml.load_config({ DELTA .. "/config/ticket-keywords.conf",
                                                  project_path .. "/config/ticket-keywords.conf" })
    if not keyword_config then return nil, why end
    local out, report = kml.process(text, {
        config = keyword_config, project_dir = project_path,
        template_name = template_name, ticket_id = id, error_mode = error_mode,
    })
    if not out then
        local first = report.errors[1] or {}
        return nil, string.format("keyword %s could not be filled: %s",
            tostring(first.name), tostring(first.message))
    end
    return out
end
-- }}}

-- {{{ local function plan_for()
-- Everything about one project's ticket, without writing anything:
-- { name, path, phase, id, file, text, status, why }.
local function plan_for(project_path, options, tools, template)
    local plan = { path = project_path, name = project_path:match("([^/]+)$") }
    if not exists(project_path .. "/issues") then
        if not options.create_issues then
            plan.status, plan.why = "skip", "no issues/ folder (add --create-issues to give it one)"
            return plan
        end
        plan.create = true
    end
    local filed = not plan.create and already_filed(project_path, template.name)
    if filed and not options.again then
        plan.status, plan.why = "skip", "already filed as " .. filed:sub(#project_path + 2)
        return plan
    end
    plan.phase = options.phase == "current" and current_phase(tools.issue_names, project_path)
        or options.phase
    -- A project with no issues/ yet starts the phase at its first number,
    -- in the shape the house rule uses (phase 5, issue 22 is 522).
    plan.id = plan.create and tools.issue_names.format_id("compact", plan.phase, 1, 2)
        or next_id(project_path, plan.phase)
    if not plan.id then
        plan.status, plan.why = "skip", "no next issue number for phase " .. plan.phase
        return plan
    end
    plan.file = string.format("issues/%s-%s.md", plan.id, template.slug)
    if exists(project_path .. "/" .. plan.file) then
        plan.status, plan.why = "skip", plan.file .. " already exists"
        return plan
    end
    local text, why = fill(tools.kml, template.text, project_path, template.name, plan.id,
        options.error_mode)
    if not text then
        plan.status, plan.why = "skip", why
        return plan
    end
    if not text:match("\n$") then text = text .. "\n" end
    plan.text = text .. "\n" .. string.format(config.marker, template.name,
        os.date("%Y-%m-%d"), tools.distribution_id) .. "\n"
    plan.status = "ready"
    return plan
end
-- }}}

-- {{{ local function write_plan()
local function write_plan(plan)
    local target = plan.path .. "/" .. plan.file
    if plan.create then
        os.execute("mkdir -p " .. shell_quote(plan.path .. "/issues/completed"))
        if not exists(plan.path .. "/issues") then return false, "could not create issues/" end
    end
    if exists(target) then return false, plan.file .. " appeared before it could be written" end
    local file, why = io.open(target, "w")
    if not file then return false, why end
    file:write(plan.text)
    file:close()
    return true
end
-- }}}

-- {{{ local function project_relative()
-- A project's path as the ledger names it: relative to the monorepo.
local function project_relative(path)
    if path:sub(1, #DIR + 1) == DIR .. "/" then return path:sub(#DIR + 2) end
    return path:match("([^/]+)$")
end
-- }}}

-- {{{ local function record()
-- One line per written ticket in the ledger: when, which distribution,
-- which template, which project, which file.
local function record(plans, template, distribution_id)
    local fresh = not exists(LEDGER)
    local file = io.open(LEDGER, "a")
    if not file then
        io.stderr:write("distribute-ticket: could not record in " .. LEDGER .. "\n")
        return false
    end
    if fresh then file:write(table.concat(config.ledger_columns, "\t") .. "\n") end
    for _, plan in ipairs(plans) do
        if plan.status == "written" then
            file:write(table.concat({ os.date("%Y-%m-%d"), distribution_id, template.name,
                project_relative(plan.path), plan.file,
                checksum(plan.path .. "/" .. plan.file) or "-", "written" }, "\t") .. "\n")
        end
    end
    file:close()
    return true
end
-- }}}
-- }}}

-- {{{ local function ledger_rows()
-- The ledger as a list of { column = value } rows; nil if it cannot be read.
local function ledger_rows()
    local text = read_file(LEDGER)
    if not text then return nil end
    local rows = {}
    for line in text:gmatch("[^\n]+") do
        local fields = {}
        for field in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = field end
        if fields[1] ~= config.ledger_columns[1] then
            local row = {}
            for index, column in ipairs(config.ledger_columns) do row[column] = fields[index] end
            rows[#rows + 1] = row
        end
    end
    return rows
end
-- }}}

-- {{{ local function undo()
-- Takes one distribution back out. A ticket is removed only while its
-- checksum still matches the one recorded when it was written; one that has
-- been edited, moved or already removed is named and left alone.
local function undo(distribution_id, write)
    local rows = ledger_rows()
    if not rows then
        io.stderr:write("distribute-ticket: cannot read the ledger " .. LEDGER .. "\n")
        return 2
    end
    local undone = {}
    for _, row in ipairs(rows) do
        if row.distribution == distribution_id and row.status == "undone" then
            undone[row.project .. "/" .. row.file] = true
        end
    end
    local found, removed, left = 0, {}, 0
    local verb = write and "removed" or "would remove"
    for _, row in ipairs(rows) do
        local key = (row.project or "") .. "/" .. (row.file or "")
        if row.distribution == distribution_id and row.status == "written" and not undone[key] then
            found = found + 1
            local path = DIR .. "/" .. key
            local why
            if not exists(path) then
                why = "no longer there (moved or removed)"
            elseif checksum(path) ~= row.sha256 then
                why = "edited since it was written; left in place"
            elseif write and not os.remove(path) then
                why = "could not be removed"
            end
            if why then
                left = left + 1
                print(string.format("%-36s kept %s: %s", row.project, row.file, why))
            else
                removed[#removed + 1] = row
                print(string.format("%-36s %s %s", row.project, verb, row.file))
            end
        end
    end
    if found == 0 then
        io.stderr:write("distribute-ticket: the ledger has no written tickets for "
            .. distribution_id .. "\n")
        return 2
    end
    if write and #removed > 0 then
        local file = io.open(LEDGER, "a")
        if file then
            for _, row in ipairs(removed) do
                file:write(table.concat({ os.date("%Y-%m-%d"), distribution_id, row.template,
                    row.project, row.file, row.sha256, "undone" }, "\t") .. "\n")
            end
            file:close()
        end
    end
    print(string.format("\n%d ticket(s) in %s, %d %s, %d kept%s", found, distribution_id,
        #removed, write and "removed" or "removable", left,
        write and "" or "; dry run, nothing removed (add --write)"))
    return left == 0 and 0 or 1
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
local function main()
    local options = parse_arguments(arg)
    if options.help then show_help() return 0 end

    local kml = dofile(KML)
    check_arguments(options, kml)
    if options.undo then return undo(options.undo, options.write) end
    local tools = {
        kml = kml,
        issue_names = dofile(ISSUE_NAMES),
        distribution_id = os.date("D-%Y%m%d-%H%M%S"),
    }

    local text = read_file(options.template)
    local template = {
        text = text,
        name = options.template:match("([^/]+)$"),
        slug = options.slug or slugify((text:match("^#+%s*([^\n]+)") or text:match("\n#+%s*([^\n]+)")
            or options.template:match("([^/]+)$"):gsub("%.%w+$", ""))),
    }
    if template.slug == "" then fail_usage("cannot make a file name from the template; give --slug") end

    local projects = chosen_projects(options.targets)
    if #projects == 0 then
        io.stderr:write("distribute-ticket: no project matches those filters\n")
        return 2
    end

    if options.show then
        for _, path in ipairs(projects) do
            if path:match("([^/]+)$") == options.show then
                local plan = plan_for(path, options, tools, template)
                if plan.status ~= "ready" then
                    io.stderr:write(plan.name .. ": " .. plan.why .. "\n")
                    return 1
                end
                io.write(plan.text)
                return 0
            end
        end
        fail_usage("--show names a project the filters did not choose: " .. options.show)
    end

    local plans, skipped = {}, 0
    for _, path in ipairs(projects) do
        local plan = plan_for(path, options, tools, template)
        if plan.status == "ready" and options.write then
            local ok, why = write_plan(plan)
            if ok then plan.status = "written" else plan.status, plan.why = "skip", why end
        end
        if plan.status == "skip" then skipped = skipped + 1 end
        plans[#plans + 1] = plan
    end

    local verb = options.write and "wrote" or "would write"
    for _, plan in ipairs(plans) do
        if plan.status == "skip" then
            print(string.format("%-36s skipped: %s", plan.name, plan.why))
        else
            print(string.format("%-36s %s %s (phase %s)", plan.name, verb, plan.file, plan.phase))
        end
    end
    if options.write then record(plans, template, tools.distribution_id) end
    print(string.format("\n%d project(s) chosen, %d %s, %d skipped%s", #plans, #plans - skipped,
        options.write and "written" or "ready", skipped,
        options.write and (" (" .. tools.distribution_id .. ")") or "; dry run, nothing written (add --write)"))
    return skipped == 0 and 0 or 1
end
-- }}}

os.exit(main())
