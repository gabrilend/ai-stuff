#!/usr/bin/env luajit
-- progress-dashboard.lua
--
-- Counts a project's issue files by phase and shows how many of each phase are
-- done, as a terminal chart, a markdown table, or JSON. It is the statistics
-- tool the documentation points at instead of writing numbers down, so the
-- numbers are always read fresh from the files.
--
-- How it works, in general terms: it asks the shared issue-name reader
-- (libs/issue-names.lua) for every issue in the project, groups them by the
-- phase in their names, and counts an issue as done when it has been moved
-- into issues/completed/. Anything it could not place -- a name that could be
-- two phases, a folder it does not recognise, a phase with no progress file --
-- is printed as a warning at the bottom rather than silently folded in.
--
-- Usage:
--   progress-dashboard.lua [DIR] [options]
--
--   DIR                 project to read (default: the hard-coded DIR below)
--   -d, --dir <path>    same as DIR
--   -t, --terminal      terminal chart (default)
--   -m, --markdown      markdown table
--   -j, --json          JSON
--   -p, --phase <n>     only this phase
--   -v, --verbose       list every issue under its phase
--   -h, --help          this text
--
-- Library use:
--   local dashboard = dofile("/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua")
--   local phases, report = dashboard.collect("/path/to/project")
--
-- Exit status: 0 when nothing needed a warning, 1 when warnings were printed
-- (warnings are treated as errors), 2 on bad arguments or a missing issues/.

-- {{{ local DIR
-- The project read when no directory is given. Hard-coded per the house rule;
-- override with a positional argument or -d.
local DIR = "/home/ritz/programming/ai-stuff/scripts"
-- Where this tool and its shared library live, independent of DIR.
local SCRIPTS_DIR = "/home/ritz/programming/ai-stuff/scripts"
-- }}}

local issue_names = dofile(SCRIPTS_DIR .. "/libs/issue-names.lua")

-- {{{ local config
local config = {
    project_dir = DIR,
    output_mode = "terminal",
    target_phase = nil,
    verbose = false,
}
-- }}}

-- {{{ local colors
local colors = {
    reset = "\27[0m", bold = "\27[1m", red = "\27[31m", green = "\27[32m",
    yellow = "\27[33m", blue = "\27[34m", cyan = "\27[36m",
}
-- }}}

-- {{{ local function paint
local function paint(color, text)
    return colors[color] .. text .. colors.reset
end
-- }}}

-- {{{ local function read_file
local function read_file(path)
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    return content
end
-- }}}

-- {{{ local function count_criteria
-- Checkbox lines are counted for information only. They never decide whether an
-- issue is done: that is where the file sits (see libs/issue-names.lua).
local function count_criteria(path)
    local total, ticked = 0, 0
    for line in read_file(path):gmatch("[^\n]+") do
        if line:match("^%s*%- %[.%]") then
            total = total + 1
            if line:match("^%s*%- %[[xX]%]") then
                ticked = ticked + 1
            end
        end
    end
    return total, ticked
end
-- }}}

-- {{{ local function collect
-- Reads the project and groups its issues by phase. Returns the phases table
-- (keyed by phase string) and the reader's report of what it could not place.
-- Issues whose phase is ambiguous are left out of the phases and listed in the
-- report instead.
local function collect(project_dir)
    local issues, report = issue_names.scan(project_dir)
    local phases = {}
    for _, issue in ipairs(issues) do
        -- an ambiguous name has no phase; it is already in report.ambiguous
        if issue.phase then
            local phase = phases[issue.phase]
            if not phase then
                phase = { id = issue.phase, issues = {}, completed = 0, open = 0,
                          retired = 0, unknown = 0, total_criteria = 0,
                          ticked_criteria = 0 }
                phases[issue.phase] = phase
            end
            issue.total_criteria, issue.ticked_criteria = count_criteria(issue.path)
            phase.issues[#phase.issues + 1] = issue
            phase[issue.status] = phase[issue.status] + 1
            phase.total_criteria = phase.total_criteria + issue.total_criteria
            phase.ticked_criteria = phase.ticked_criteria + issue.ticked_criteria
        end
    end
    return phases, report
end
-- }}}

-- {{{ local function ordered_phase_ids
local function ordered_phase_ids(phases)
    local ids = {}
    for id in pairs(phases) do
        ids[#ids + 1] = id
    end
    table.sort(ids, function(a, b)
        return issue_names.phase_sort_key(a) < issue_names.phase_sort_key(b)
    end)
    return ids
end
-- }}}

-- {{{ local function counted_total
-- Retired issues are neither done nor to-do, so they are left out of the
-- denominator: a phase whose only leftovers were superseded reads as complete.
local function counted_total(phase)
    return #phase.issues - phase.retired
end
-- }}}

-- {{{ local function progress_bar
local function progress_bar(done, total, width)
    local ratio = total > 0 and (done / total) or 0
    local filled = math.floor(ratio * width)
    return string.rep("█", filled) .. string.rep("░", width - filled),
           string.format("%.0f%%", ratio * 100)
end
-- }}}

-- {{{ local function warning_lines
-- Turns the reader's report into plain sentences, one per finding. Returns an
-- empty list when there is nothing to warn about.
local function warning_lines(report)
    local lines = {}
    -- only compact names ("522-...") need their digits split, so only they can
    -- be split without confirmation
    if report.has_compact and not report.width_confirmed then
        lines[#lines + 1] = "nothing confirms how names split into phase and number "
            .. "(no progress files, phase folders, or phase-N-demo names); split with a "
            .. report.width .. "-digit issue number, the house rule"
    end
    for _, rel in ipairs(report.ambiguous) do
        lines[#lines + 1] = "name has no valid phase with a " .. report.width
            .. "-digit issue number: " .. rel
    end
    for _, line in ipairs(report.folder_disagreements) do
        lines[#lines + 1] = "counted in its phase-N/ folder's phase, not its name's: " .. line
    end
    for _, rel in ipairs(report.unknown_locations) do
        lines[#lines + 1] = "folder not recognised as open, completed or retired: " .. rel
    end
    for _, phase in ipairs(report.phases_without_evidence) do
        lines[#lines + 1] = "phase " .. phase .. " has issues but no phase-"
            .. phase .. "-progress.md"
    end
    return lines
end
-- }}}

-- {{{ local function render_terminal
local function render_terminal(phases, report)
    print("╔════════════════════════════════════════════════════════════╗")
    print("║              PROJECT PROGRESS DASHBOARD                    ║")
    print("╠════════════════════════════════════════════════════════════╣")
    local all_total, all_done = 0, 0
    for _, id in ipairs(ordered_phase_ids(phases)) do
        local phase = phases[id]
        local total = counted_total(phase)
        local bar, pct = progress_bar(phase.completed, total, 35)
        -- green = every counted issue done, red = none done, yellow = between
        local color = (total > 0 and phase.completed == total) and "green"
            or (phase.completed == 0 and "red" or "yellow")
        print(string.format("║ Phase %s: %s %d/%d (%s)", id, paint(color, bar),
            phase.completed, total, pct))
        print(string.format("║   %s done, %s open, %d retired%s",
            paint("green", tostring(phase.completed)), paint("red", tostring(phase.open)),
            phase.retired, phase.unknown > 0 and (", " .. phase.unknown .. " in unknown folders") or ""))
        if config.verbose then
            local icons = { completed = "✓", open = "○", retired = "–", unknown = "?" }
            for _, issue in ipairs(phase.issues) do
                print(string.format("║     %s %s", icons[issue.status], issue.rel))
            end
        end
        print("╠────────────────────────────────────────────────────────────╣")
        all_total, all_done = all_total + total, all_done + phase.completed
    end
    print(string.format("║ TOTAL: %d/%d issues (%.0f%%)", all_done, all_total,
        all_total > 0 and (all_done / all_total * 100) or 0))
    print("╚════════════════════════════════════════════════════════════╝")
    local warnings = warning_lines(report)
    for _, line in ipairs(warnings) do
        io.stderr:write(paint("yellow", "warning: ") .. line .. "\n")
    end
    return #warnings
end
-- }}}

-- {{{ local function render_markdown
local function render_markdown(phases, report)
    local lines = {
        "# Project Progress Dashboard", "",
        "Generated by `progress-dashboard.lua -m` on " .. os.date("%Y-%m-%d %H:%M") .. ".", "",
        "| Phase | Done | Open | Retired | Progress |",
        "|-------|------|------|---------|----------|",
    }
    for _, id in ipairs(ordered_phase_ids(phases)) do
        local phase = phases[id]
        local total = counted_total(phase)
        local _, pct = progress_bar(phase.completed, total, 1)
        lines[#lines + 1] = string.format("| %s | %d | %d | %d | %s |",
            id, phase.completed, phase.open, phase.retired, pct)
    end
    if config.verbose then
        for _, id in ipairs(ordered_phase_ids(phases)) do
            lines[#lines + 1] = ""
            lines[#lines + 1] = "## Phase " .. id
            lines[#lines + 1] = ""
            for _, issue in ipairs(phases[id].issues) do
                lines[#lines + 1] = "- " .. issue.status .. ": `" .. issue.rel .. "`"
            end
        end
    end
    local warnings = warning_lines(report)
    if #warnings > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "## Warnings"
        lines[#lines + 1] = ""
        for _, line in ipairs(warnings) do
            lines[#lines + 1] = "- " .. line
        end
    end
    print(table.concat(lines, "\n"))
    return #warnings
end
-- }}}

-- {{{ local function json_string
local function json_string(text)
    return '"' .. text:gsub('[%c"\\]', function(ch)
        return string.format("\\u%04x", ch:byte())
    end) .. '"'
end
-- }}}

-- {{{ local function render_json
local function render_json(phases, report)
    local parts = {}
    for _, id in ipairs(ordered_phase_ids(phases)) do
        local phase = phases[id]
        parts[#parts + 1] = string.format(
            '%s:{"total":%d,"completed":%d,"open":%d,"retired":%d,"unknown":%d,'
            .. '"total_criteria":%d,"ticked_criteria":%d}',
            json_string(id), #phase.issues, phase.completed, phase.open,
            phase.retired, phase.unknown, phase.total_criteria, phase.ticked_criteria)
    end
    local warnings = warning_lines(report)
    local quoted = {}
    for i, line in ipairs(warnings) do
        quoted[i] = json_string(line)
    end
    print(string.format('{"generated":%s,"issue_number_width":%d,"phases":{%s},"warnings":[%s]}',
        json_string(os.date("%Y-%m-%dT%H:%M:%S")), report.width,
        table.concat(parts, ","), table.concat(quoted, ",")))
    return #warnings
end
-- }}}

-- {{{ local renderers
local renderers = {
    terminal = render_terminal,
    markdown = render_markdown,
    json = render_json,
}
-- }}}

-- {{{ local function usage
local function usage()
    print([[
progress-dashboard.lua - count a project's issues by phase

USAGE:  progress-dashboard.lua [DIR] [-t|-m|-j] [-p PHASE] [-v]

    DIR / -d PATH    project to read (default ]] .. DIR .. [[)
    -t               terminal chart (default)
    -m               markdown table
    -j               JSON
    -p PHASE         only this phase
    -v               list every issue
    -h               this help

An issue is done when it sits in issues/completed/. Exit 1 means warnings were
printed; read them.]])
end
-- }}}

-- {{{ local function parse_args
-- Each flag is a small handler returning how many arguments it consumed.
-- An unknown flag is an error rather than something to skip past.
local function parse_args(args)
    local takes_value = function(key)
        return function(i)
            if not args[i + 1] then
                io.stderr:write("missing value after " .. args[i] .. "\n")
                os.exit(2)
            end
            config[key] = args[i + 1]
            return 2
        end
    end
    local sets_mode = function(mode)
        return function() config.output_mode = mode return 1 end
    end
    local handlers = {
        ["-d"] = takes_value("project_dir"), ["--dir"] = takes_value("project_dir"),
        ["-p"] = takes_value("target_phase"), ["--phase"] = takes_value("target_phase"),
        ["-t"] = sets_mode("terminal"), ["--terminal"] = sets_mode("terminal"),
        ["-m"] = sets_mode("markdown"), ["--markdown"] = sets_mode("markdown"),
        ["-j"] = sets_mode("json"), ["--json"] = sets_mode("json"),
        ["-v"] = function() config.verbose = true return 1 end,
        ["--verbose"] = function() config.verbose = true return 1 end,
        ["-h"] = function() usage() os.exit(0) end,
        ["--help"] = function() usage() os.exit(0) end,
    }
    local i = 1
    while i <= #args do
        local handler = handlers[args[i]]
        -- a known flag consumes itself (and its value)
        if handler then
            i = i + handler(i)
        -- a bare word is the project directory
        elseif not args[i]:match("^%-") then
            config.project_dir = args[i]
            i = i + 1
        -- anything else is a mistake worth stopping for
        else
            io.stderr:write("unknown option: " .. args[i] .. "\n")
            os.exit(2)
        end
    end
end
-- }}}

-- {{{ local function main
local function main()
    parse_args(arg)
    local ok, phases, report = pcall(collect, config.project_dir)
    if not ok then
        io.stderr:write(tostring(phases) .. "\n")
        os.exit(2)
    end
    -- -p keeps one phase; asking for a phase that does not exist is an error
    if config.target_phase then
        if not phases[config.target_phase] then
            io.stderr:write("no issues in phase " .. config.target_phase .. "\n")
            os.exit(2)
        end
        phases = { [config.target_phase] = phases[config.target_phase] }
    end
    local warning_count = renderers[config.output_mode](phases, report)
    os.exit(warning_count > 0 and 1 or 0)
end
-- }}}

local dashboard = {
    collect = collect,
    render_terminal = render_terminal,
    render_markdown = render_markdown,
    render_json = render_json,
    warning_lines = warning_lines,
}

-- run as a program only when invoked directly, not when loaded with dofile
if arg and arg[0] and arg[0]:match("progress%-dashboard%.lua$") then
    main()
end

return dashboard
