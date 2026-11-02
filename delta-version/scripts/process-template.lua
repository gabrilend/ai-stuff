#!/usr/bin/env luajit
-- process-template.lua - fills a ticket template's ][keyword[] placeholders
-- with facts about a project, and prints the filled ticket.
--
-- In general terms: each placeholder names a keyword from
-- config/ticket-keywords.conf, whose bash command is run in the project's
-- folder; its output replaces the placeholder. The work is done by
-- libs/kml.lua (the Keyword Markup Language engine, issue 017); this is the
-- command line around it. Specification: docs/keyword-markup-language-spec.md.
--
-- Usage:
--   process-template.lua <template> [project-dir] [options]
--
--   project-dir          the folder the commands run in (default: current)
--
-- Options (a value may follow "=" or come as the next argument):
--   --config=FILE        the keyword configuration to use, instead of
--                        delta-version's config/ticket-keywords.conf with the
--                        project's own config/ticket-keywords.conf over it
--   --error-mode=MODE    placeholder, remove, verbose or fail (default: the
--                        configuration's, else placeholder)
--   --timeout=SECONDS    per command (default: the configuration's, else 10)
--   --ticket-id=ID       the value of ][ticket_id[] (default: generated)
--   --output=FILE        write the ticket here instead of standard output
--   --check              run nothing: list each placeholder and whether it
--                        is usable, and exit 1 if any is not
--   --list               list the configured keywords and their parameters
--   --dir=PATH           the delta-version folder (default
--                        /mnt/mtwo/programming/ai-stuff/delta-version)
--   -h, --help           this text
--
-- Exit 0 when the ticket was written (failed keywords are marked in it as the
-- error mode says), 1 when the error mode is "fail" and a keyword failed, or
-- --check found a problem, or a file could not be read or written; 2 for bad
-- arguments. Failures are also listed on standard error.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
-- }}}

-- The engine lives beside this script, so a copy run from a worktree uses
-- its own.
local HERE = (arg[0]:match("^(.*)/[^/]+$") or ".")
local kml = dofile(HERE .. "/libs/kml.lua")

-- {{{ local function read_file
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ local function show_help
local function show_help()
    local text = read_file(arg[0]) or ""
    for line in text:gmatch("[^\n]*\n") do
        if line:match("^%-%- {{{") then break end
        if not line:match("^#!") then io.write((line:gsub("^%-%- ?", ""))) end
    end
end
-- }}}

-- {{{ local function fail_usage
local function fail_usage(message)
    io.stderr:write("process-template: ", message, " (see --help)\n")
    os.exit(2)
end
-- }}}

-- {{{ local function parse_args
local function parse_args()
    local o = { positional = {} }
    local value_options = {
        config = true, ["error-mode"] = true, timeout = true, ["ticket-id"] = true,
        output = true, dir = true,
    }
    local i = 1
    while arg[i] do
        local a = arg[i]
        if a == "-h" or a == "--help" then
            show_help(); os.exit(0)
        elseif a == "--check" then
            o.check = true; i = i + 1
        elseif a == "--list" then
            o.list = true; i = i + 1
        elseif a:match("^%-%-") then
            local name, v = a:match("^%-%-([%w%-]+)=(.*)$")
            if not name then
                name = a:sub(3)
                v = arg[i + 1]
                i = i + 1
            end
            if not value_options[name] then fail_usage("unknown option " .. a) end
            if v == nil then fail_usage("--" .. name .. " needs a value") end
            o[name] = v
            i = i + 1
        else
            o.positional[#o.positional + 1] = a
            i = i + 1
        end
    end
    if o.dir then DIR = o.dir:gsub("/+$", "") end
    if o["error-mode"] and not kml.ERROR_MODES[o["error-mode"]] then
        fail_usage("unknown error mode " .. o["error-mode"])
    end
    if o.timeout and not (tonumber(o.timeout) and tonumber(o.timeout) > 0) then
        fail_usage("--timeout needs a number of seconds")
    end
    return o
end
-- }}}

-- {{{ local function load_config
local function load_config(o, project_dir)
    local paths
    if o.config then
        if not read_file(o.config) then
            io.stderr:write("process-template: cannot read ", o.config, "\n")
            os.exit(1)
        end
        paths = { o.config }
    else
        paths = { DIR .. "/config/ticket-keywords.conf",
                  project_dir .. "/config/ticket-keywords.conf" }
    end
    local config, why = kml.load_config(paths)
    if not config then
        io.stderr:write("process-template: ", why, " (looked in ", table.concat(paths, ", "), ")\n")
        os.exit(1)
    end
    return config
end
-- }}}

-- {{{ local function list_keywords
local function list_keywords(config)
    local names = {}
    for name in pairs(config.keywords) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        local sa, sb = config.keywords[a].section, config.keywords[b].section
        if sa ~= sb then return sa < sb end
        return a < b
    end)
    local section
    for _, name in ipairs(names) do
        local entry = config.keywords[name]
        if entry.section ~= section then
            section = entry.section
            io.write("[", section, "]\n")
        end
        local needed = kml.params_needed(entry.command)
        local shape = "][" .. name .. "["
        if needed > 0 then
            local params = {}
            for k = 1, needed do params[k] = "p" .. k end
            shape = shape .. table.concat(params, ",") .. "]["
        end
        io.write("  ", shape, "]\n")
    end
    io.write("[internal]\n")
    for _, name in ipairs({ "generation_date", "kml_version", "template_name", "ticket_id" }) do
        io.write("  ][", name, "[]\n")
    end
end
-- }}}

-- {{{ local function check_template
-- Lists each placeholder and whether it could be filled, running nothing.
local function check_template(text, config)
    local problems = 0
    for _, piece in ipairs(kml.scan(text)) do
        if type(piece) == "table" then
            local why = kml.problem(piece, config)
            if why then
                problems = problems + 1
                io.write("bad  ", piece.raw, "  ", why, "\n")
            else
                io.write("ok   ", piece.raw, "\n")
            end
        end
    end
    return problems
end
-- }}}

-- {{{ local function main
local function main()
    local o = parse_args()
    local template_path = o.positional[1]
    local project_dir = o.positional[2] or "."
    if #o.positional > 2 then fail_usage("one template and one project folder at most") end

    local config = load_config(o, project_dir)
    if o.list then
        list_keywords(config)
        return 0
    end

    if not template_path then fail_usage("a template file is required") end
    local text = read_file(template_path)
    if not text then
        io.stderr:write("process-template: cannot read ", template_path, "\n")
        return 1
    end

    if o.check then
        return check_template(text, config) == 0 and 0 or 1
    end

    local dir_ok = os.execute("test -d " .. "'" .. project_dir:gsub("'", "'\\''") .. "'")
    if dir_ok ~= 0 and dir_ok ~= true then
        io.stderr:write("process-template: not a folder: ", project_dir, "\n")
        return 1
    end

    local out, report = kml.process(text, {
        config = config,
        project_dir = project_dir,
        template_name = template_path:match("([^/]+)$"),
        error_mode = o["error-mode"],
        timeout = o.timeout,
        ticket_id = o["ticket-id"],
    })
    for _, e in ipairs(report.errors) do
        io.stderr:write("process-template: ", e.raw or e.name, ": ", e.message, "\n")
    end
    if not out then return 1 end

    if o.output then
        local f = io.open(o.output, "wb")
        if not f then
            io.stderr:write("process-template: cannot write ", o.output, "\n")
            return 1
        end
        f:write(out)
        f:close()
    else
        io.write(out)
    end
    return 0
end
-- }}}

os.exit(main())
