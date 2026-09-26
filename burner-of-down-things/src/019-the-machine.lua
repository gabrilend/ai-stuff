-- 019-the-machine.lua
--
-- The entry point. `machine` (the launcher at the project root) runs this
-- with the project folder and a command. Every command is one row of the
-- command table; every run that works on a case has the same shape:
--
--   read input/ first -> take the lock -> verify the ledger -> do the work
--   -> write output/goodbye -> append `goodbye` -> drop the lock
--
-- The goodbye, its ledger line and the unlock happen when the work fails
-- too, with the failure written into the goodbye, and the machine then exits
-- non-zero. See docs/003 and docs/012.

local DIR = arg[1]
if not DIR then
    io.stderr:write("019-the-machine.lua: run through ./machine, which passes the project folder\n")
    os.exit(1)
end
table.remove(arg, 1)

local paths_module = dofile(DIR .. "/src/013-paths.lua")
paths_module.set_search_path(DIR)
local project = paths_module.for_project(DIR)

local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local case = require("018-the-case")

-- {{{ local function say
local function say(...)
    io.write(table.concat({ ... }), "\n")
end
-- }}}

-- The work of one run, gathered for the goodbye. Arrays of sentences.
-- {{{ local function new_run
local function new_run(command_name, args)
    return {
        command = command_name,
        args = args,
        project = project,
        say = say,
        done = {},
        waiting = {},
        failed = {},
    }
end
-- }}}

-- The command table. Each row:
--   run          function(run) doing the work; run.case is loaded for rows
--                that need a case
--   needs_case   the first argument is a case name to load; the run holds
--                the case's lock, since it appends to the ledger
--   usage        the arguments, for help
--   what         one line, for help
-- Later phases add rows by requiring their module here.
local COMMANDS = {}

-- {{{ local function help
local function help()
    local names = {}
    for name in pairs(COMMANDS) do
        names[#names + 1] = name
    end
    table.sort(names)
    say("machine <command> [arguments]")
    for _, name in ipairs(names) do
        local row = COMMANDS[name]
        say(string.format("  %-9s %-34s %s", name, row.usage, row.what))
    end
end
-- }}}

COMMANDS.help = {
    run = help, needs_case = false,
    usage = "", what = "this table",
}

COMMANDS.open = {
    needs_case = false,
    usage = "<case> <source folder> [harness]",
    what = "make a case for a folder of source code",
    run = function(run)
        local name, source, harness = run.args[1], run.args[2], run.args[3]
        if not name or not source then
            error("open needs a case name and a source folder")
        end
        local record = case.open(project, name, source, harness)
        run.case = record
        run.done[#run.done + 1] = "opened case " .. name .. " on " .. record.source
        say("opened ", record.folder)
    end,
}

COMMANDS.ledger = {
    needs_case = true,
    usage = "<case>", what = "verify the case's ledger; print its length and head hash",
    run = function(run)
        local result = ledger.verify(run.case.ledger)
        if not result.ok then
            error(ledger.describe_failure(result))
        end
        say("lines ", result.count)
        say("head  ", result.head)
        run.done[#run.done + 1] = "verified " .. result.count .. " ledger lines"
    end,
}

-- Rows added by later phases: each module returns a table of rows.
local LATER_COMMAND_MODULES = {}

-- {{{ local function load_later_commands
local function load_later_commands()
    for _, module_name in ipairs(LATER_COMMAND_MODULES) do
        for name, row in pairs(require(module_name)) do
            COMMANDS[name] = row
        end
    end
end
-- }}}

-- {{{ local function read_project_input
-- The first thing every run does: see what the person has written into the
-- machine's own input/ folder. The names are written to the scratch log so a
-- run's starting state can be read back later.
local function read_project_input()
    local names = {}
    if fs.is_folder(project.input) then
        names = fs.list(project.input)
    end
    fs.make_folder(project.scratch)
    local log = io.open(project.scratch .. "/runs.log", "ab")
    if log then
        log:write(os.date("%Y-%m-%d %H:%M:%S"), "\tinput/: ", table.concat(names, " "), "\n")
        log:close()
    end
    return names
end
-- }}}

-- {{{ local function find_new_requests
-- The first thing a run on a case does is read its input/: the names of
-- files not yet noticed. They are written to the ledger only once the lock
-- is held and the ledger has verified (note_new_requests).
local function find_new_requests(run)
    local _, new = case.requests(run.case, ledger.read(run.case.ledger))
    return new
end
-- }}}

-- {{{ local function note_new_requests
local function note_new_requests(run, new)
    for _, name in ipairs(new) do
        ledger.append(run.case.ledger, "request-received", name, "noticed in input/")
        run.waiting[#run.waiting + 1] = "request " .. name
    end
end
-- }}}

-- {{{ local function goodbye_text
local function goodbye_text(run, failure)
    local lines = { "goodbye from `" .. run.command .. "`, " .. os.date("%Y-%m-%d %H:%M:%S"), "" }
    -- {{{ local function section
    local function section(title, items)
        lines[#lines + 1] = title
        if #items == 0 then
            lines[#lines + 1] = "  (nothing)"
        end
        for _, item in ipairs(items) do
            lines[#lines + 1] = "  " .. item
        end
        lines[#lines + 1] = ""
    end
    -- }}}
    section("done:", run.done)
    section("waiting:", run.waiting)
    local failed = run.failed
    if failure then
        failed = { failure }
        for _, f in ipairs(run.failed) do
            failed[#failed + 1] = f
        end
    end
    section("failed:", failed)
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function say_goodbye
-- The last thing every run does. Writes the case's goodbye (when there is a
-- case), its ledger line, and the project's own output/goodbye.
local function say_goodbye(run, failure)
    local text = goodbye_text(run, failure)
    if run.case then
        fs.write(run.case.output .. "/goodbye", text)
        -- Only a run that holds the lock over a verified ledger appends to it.
        -- A run refused the lock, or one that found the ledger broken, still
        -- writes its goodbye file, but leaves the history as found.
        if run.may_append then
            ledger.append(run.case.ledger, "goodbye", "-",
                run.command .. (failure and (": failed: " .. failure) or ": ok"))
        end
    end
    fs.make_folder(project.output)
    fs.write(project.output .. "/goodbye", text)
end
-- }}}

-- {{{ local function main
local function main()
    read_project_input()
    load_later_commands()
    local command_name = table.remove(arg, 1) or "help"
    local row = COMMANDS[command_name]
    if not row then
        say("unknown command: ", command_name)
        help()
        return 1
    end
    local run = new_run(command_name, arg)
    local locked = false
    local ok, err = pcall(function()
        if row.needs_case then
            local name = table.remove(run.args, 1)
            if not name then
                error(command_name .. " needs a case name")
            end
            run.case = case.load(project, name)
            local new_requests = find_new_requests(run)
            -- Every run on a case appends to its ledger (at least its
            -- goodbye), so every run on a case holds the lock.
            case.take_lock(run.case)
            locked = true
            local verified = ledger.verify(run.case.ledger)
            if not verified.ok then
                error(ledger.describe_failure(verified))
            end
            run.may_append = true
            note_new_requests(run, new_requests)
        end
        row.run(run)
        -- `open` makes its case (and its ledger) during the run itself.
        if not row.needs_case and run.case then
            run.may_append = true
        end
    end)
    local failure = (not ok) and tostring(err) or nil
    -- The goodbye itself must not be skipped by an error in it; if writing it
    -- fails, that is reported too, and the lock is still dropped.
    local ok_goodbye, goodbye_err = pcall(say_goodbye, run, failure)
    if locked then
        case.drop_lock(run.case)
    end
    if failure then
        io.stderr:write("machine: ", failure, "\n")
    end
    if not ok_goodbye then
        io.stderr:write("machine: could not write goodbye: ", tostring(goodbye_err), "\n")
    end
    if failure or not ok_goodbye then
        return 1
    end
    return 0
end
-- }}}

os.exit(main())
