#!/usr/bin/env luajit
-- progress-dashboard.lua
-- Scans issue directories and generates progress statistics with ASCII visualizations.
-- Project-abstract: works on any project following the issue naming convention.
--
-- Usage:
--   lua progress-dashboard.lua [options]
--   lua progress-dashboard.lua -t          (terminal output, default)
--   lua progress-dashboard.lua -m          (markdown output)
--
-- Options:
--   -d, --dir <path>    Project directory (default: current)
--   -t, --terminal      Terminal output with ASCII graphics (default)
--   -m, --markdown      Markdown output
--   -j, --json          JSON output
--   -p, --phase <n>     Show only specific phase
--   -v, --verbose       Show individual issues
--   -h, --help          Show help
--
-- Library usage:
--   local dashboard = require("progress-dashboard")
--   dashboard.init("/path/to/project")
--   local phases = dashboard.scan()
--   dashboard.render_terminal(phases)

local DIR = arg[0]:match("(.*/)")
if not DIR then DIR = "./" end

-- {{{ Configuration
local config = {
    project_dir = ".",
    issues_dir = "issues",
    completed_dir = "issues/completed",
    phase_pattern = "^([A-Z]?)(%d+)",  -- Match phase letter/number + issue ID
    output_mode = "terminal",
    target_phase = nil,
    verbose = false,
}
-- }}}

-- {{{ ANSI Colors
local colors = {
    reset = "\27[0m",
    bold = "\27[1m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    cyan = "\27[36m",
}

local function c(color, text)
    return colors[color] .. text .. colors.reset
end
-- }}}

-- {{{ File utilities
local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function list_dir(path)
    local files = {}
    local handle = io.popen('ls -1 "' .. path .. '" 2>/dev/null')
    if not handle then return files end
    for file in handle:lines() do
        files[#files + 1] = file
    end
    handle:close()
    return files
end
-- }}}

-- {{{ parse_issue_file
-- Parse an issue file and extract metadata
local function parse_issue_file(filepath)
    local content = read_file(filepath)
    if not content then return nil end

    local issue = {
        path = filepath,
        name = filepath:match("([^/]+)%.md$"),
        status = "pending",
        total_criteria = 0,
        completed_criteria = 0,
    }

    -- Extract phase from filename
    local letter, number = issue.name:match(config.phase_pattern)
    if letter and letter ~= "" then
        issue.phase = letter
    elseif number then
        issue.phase = number:sub(1, 1)
    else
        issue.phase = "?"
    end

    -- Check if sub-issue (has letter suffix like 102a)
    if issue.name:match("^%d+%d+%d+[a-z]%-") then
        issue.is_sub = true
    end

    -- Count acceptance criteria
    for line in content:gmatch("[^\n]+") do
        if line:match("^%- %[.%]") then
            issue.total_criteria = issue.total_criteria + 1
            if line:match("^%- %[[xX]%]") then
                issue.completed_criteria = issue.completed_criteria + 1
            end
        end
    end

    -- Detect status
    if content:match("%*%*Status:%*%*%s*Completed") or
       content:match("%*%*Status:%*%*%s*%*%*Completed%*%*") then
        issue.status = "completed"
    elseif issue.total_criteria > 0 and issue.completed_criteria == issue.total_criteria then
        issue.status = "completed"
    elseif issue.completed_criteria > 0 then
        issue.status = "in_progress"
    else
        issue.status = "pending"
    end

    return issue
end
-- }}}

-- {{{ scan_issues
-- Scan issue directory and return grouped data
local function scan_issues()
    local issues = {}

    -- Scan pending issues
    local pending_path = config.project_dir .. "/" .. config.issues_dir
    for _, file in ipairs(list_dir(pending_path)) do
        if file:match("^[A-Z0-9].*%.md$") and file ~= "progress.md" then
            local issue = parse_issue_file(pending_path .. "/" .. file)
            if issue then
                issues[#issues + 1] = issue
            end
        end
    end

    -- Scan completed issues
    local completed_path = config.project_dir .. "/" .. config.completed_dir
    for _, file in ipairs(list_dir(completed_path)) do
        if file:match("^[A-Z0-9].*%.md$") then
            local issue = parse_issue_file(completed_path .. "/" .. file)
            if issue then
                issue.status = "completed"  -- Force completed status
                issues[#issues + 1] = issue
            end
        end
    end

    return issues
end
-- }}}

-- {{{ group_by_phase
-- Group issues by phase
local function group_by_phase(issues)
    local phases = {}

    for _, issue in ipairs(issues) do
        local phase = issue.phase
        if not phases[phase] then
            phases[phase] = {
                id = phase,
                issues = {},
                completed = 0,
                in_progress = 0,
                pending = 0,
                total_criteria = 0,
                completed_criteria = 0,
            }
        end

        local p = phases[phase]
        p.issues[#p.issues + 1] = issue
        p[issue.status] = p[issue.status] + 1
        p.total_criteria = p.total_criteria + issue.total_criteria
        p.completed_criteria = p.completed_criteria + issue.completed_criteria
    end

    return phases
end
-- }}}

-- {{{ progress_bar
-- Create ASCII progress bar
local function progress_bar(completed, total, width)
    width = width or 30
    local ratio = total > 0 and (completed / total) or 0
    local filled = math.floor(ratio * width)
    local empty = width - filled

    local bar = string.rep("█", filled) .. string.rep("░", empty)
    local pct = string.format("%.0f%%", ratio * 100)

    return bar, pct
end
-- }}}

-- {{{ render_terminal
-- Render ASCII dashboard to terminal
local function render_terminal(phases)
    local phase_order = {}
    for phase_id in pairs(phases) do
        phase_order[#phase_order + 1] = phase_id
    end
    table.sort(phase_order)

    print("╔════════════════════════════════════════════════════════════╗")
    print("║              PROJECT PROGRESS DASHBOARD                    ║")
    print("╠════════════════════════════════════════════════════════════╣")

    for _, phase_id in ipairs(phase_order) do
        local phase = phases[phase_id]
        local total = #phase.issues
        local done = phase.completed

        local bar, pct = progress_bar(done, total, 35)
        local color = "yellow"
        if done == total and total > 0 then
            color = "green"
        elseif done == 0 then
            color = "red"
        end

        print(string.format("║ Phase %s: %s %d/%d (%s)",
            phase_id, c(color, bar), done, total, pct))

        print(string.format("║   Issues: %s%d done%s, %s%d in progress%s, %s%d pending%s",
            colors.green, phase.completed, colors.reset,
            colors.yellow, phase.in_progress, colors.reset,
            colors.red, phase.pending, colors.reset))

        if phase.total_criteria > 0 then
            local cbar, cpct = progress_bar(phase.completed_criteria, phase.total_criteria, 25)
            print(string.format("║   Criteria: %s %d/%d (%s)",
                c(color, cbar), phase.completed_criteria, phase.total_criteria, cpct))
        end

        if config.verbose then
            for _, issue in ipairs(phase.issues) do
                local status_icon = "○"
                local status_color = "red"
                if issue.status == "completed" then
                    status_icon = "✓"
                    status_color = "green"
                elseif issue.status == "in_progress" then
                    status_icon = "◐"
                    status_color = "yellow"
                end
                print(string.format("║     %s %s",
                    c(status_color, status_icon), issue.name))
            end
        end

        print("╠────────────────────────────────────────────────────────────╣")
    end

    -- Summary
    local total_issues = 0
    local total_done = 0
    local total_criteria = 0
    local total_criteria_done = 0

    for _, phase in pairs(phases) do
        total_issues = total_issues + #phase.issues
        total_done = total_done + phase.completed
        total_criteria = total_criteria + phase.total_criteria
        total_criteria_done = total_criteria_done + phase.completed_criteria
    end

    print(string.format("║ TOTAL: %d/%d issues (%.0f%%) | %d/%d criteria (%.0f%%)",
        total_done, total_issues,
        total_issues > 0 and (total_done / total_issues * 100) or 0,
        total_criteria_done, total_criteria,
        total_criteria > 0 and (total_criteria_done / total_criteria * 100) or 0))
    print("╚════════════════════════════════════════════════════════════╝")
end
-- }}}

-- {{{ render_markdown
-- Render markdown report
local function render_markdown(phases)
    local lines = {}
    lines[#lines + 1] = "# Project Progress Dashboard"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Generated: " .. os.date("%Y-%m-%d %H:%M")
    lines[#lines + 1] = ""

    -- Summary table
    lines[#lines + 1] = "## Phase Summary"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "| Phase | Issues | Progress | Criteria |"
    lines[#lines + 1] = "|-------|--------|----------|----------|"

    local phase_order = {}
    for phase_id in pairs(phases) do
        phase_order[#phase_order + 1] = phase_id
    end
    table.sort(phase_order)

    for _, phase_id in ipairs(phase_order) do
        local phase = phases[phase_id]
        local total = #phase.issues
        local issue_pct = total > 0 and math.floor(phase.completed / total * 100) or 0
        local criteria_pct = phase.total_criteria > 0 and
            math.floor(phase.completed_criteria / phase.total_criteria * 100) or 0

        lines[#lines + 1] = string.format("| %s | %d/%d (%d%%) | %s | %d/%d (%d%%) |",
            phase_id, phase.completed, total, issue_pct,
            phase.completed == total and total > 0 and "✓ Complete" or "In Progress",
            phase.completed_criteria, phase.total_criteria, criteria_pct)
    end

    if config.verbose then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "## Issue Details"
        lines[#lines + 1] = ""

        for _, phase_id in ipairs(phase_order) do
            local phase = phases[phase_id]
            lines[#lines + 1] = "### Phase " .. phase_id
            lines[#lines + 1] = ""
            lines[#lines + 1] = "| Issue | Status | Criteria |"
            lines[#lines + 1] = "|-------|--------|----------|"

            for _, issue in ipairs(phase.issues) do
                local status = issue.status == "completed" and "✓" or
                    issue.status == "in_progress" and "◐" or "○"
                lines[#lines + 1] = string.format("| %s | %s | %d/%d |",
                    issue.name, status, issue.completed_criteria, issue.total_criteria)
            end
            lines[#lines + 1] = ""
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ render_json
-- Render JSON output
local function render_json(phases)
    local lines = {}
    lines[#lines + 1] = "{"
    lines[#lines + 1] = '  "generated": "' .. os.date("%Y-%m-%dT%H:%M:%S") .. '",'
    lines[#lines + 1] = '  "phases": {'

    local phase_order = {}
    for phase_id in pairs(phases) do
        phase_order[#phase_order + 1] = phase_id
    end
    table.sort(phase_order)

    for i, phase_id in ipairs(phase_order) do
        local phase = phases[phase_id]
        lines[#lines + 1] = '    "' .. phase_id .. '": {'
        lines[#lines + 1] = '      "total": ' .. #phase.issues .. ','
        lines[#lines + 1] = '      "completed": ' .. phase.completed .. ','
        lines[#lines + 1] = '      "in_progress": ' .. phase.in_progress .. ','
        lines[#lines + 1] = '      "pending": ' .. phase.pending .. ','
        lines[#lines + 1] = '      "total_criteria": ' .. phase.total_criteria .. ','
        lines[#lines + 1] = '      "completed_criteria": ' .. phase.completed_criteria
        lines[#lines + 1] = '    }' .. (i < #phase_order and ',' or '')
    end

    lines[#lines + 1] = "  }"
    lines[#lines + 1] = "}"

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ parse_args
local function parse_args(args)
    local i = 1
    while i <= #args do
        local arg = args[i]
        if arg == "-d" or arg == "--dir" then
            config.project_dir = args[i + 1]
            i = i + 2
        elseif arg == "-t" or arg == "--terminal" then
            config.output_mode = "terminal"
            i = i + 1
        elseif arg == "-m" or arg == "--markdown" then
            config.output_mode = "markdown"
            i = i + 1
        elseif arg == "-j" or arg == "--json" then
            config.output_mode = "json"
            i = i + 1
        elseif arg == "-p" or arg == "--phase" then
            config.target_phase = args[i + 1]
            i = i + 2
        elseif arg == "-v" or arg == "--verbose" then
            config.verbose = true
            i = i + 1
        elseif arg == "-h" or arg == "--help" then
            print([[
progress-dashboard.lua - Generate project progress visualizations

USAGE:
    lua progress-dashboard.lua [options]

OPTIONS:
    -d, --dir <path>    Project directory (default: current)
    -t, --terminal      Terminal output with ASCII graphics (default)
    -m, --markdown      Markdown output
    -j, --json          JSON output
    -p, --phase <n>     Show only specific phase
    -v, --verbose       Show individual issues
    -h, --help          Show help

EXAMPLES:
    lua progress-dashboard.lua -t           # Terminal output
    lua progress-dashboard.lua -m > report.md
    lua progress-dashboard.lua -j | jq .
    lua progress-dashboard.lua -v -p 2      # Verbose Phase 2 only
]])
            os.exit(0)
        else
            i = i + 1
        end
    end
end
-- }}}

-- {{{ init
-- Initialize dashboard for library use
local function init(project_dir)
    config.project_dir = project_dir or "."
end
-- }}}

-- {{{ main
local function main()
    parse_args(arg)

    local issues = scan_issues()
    local phases = group_by_phase(issues)

    -- Filter to target phase if specified
    if config.target_phase then
        local filtered = {}
        if phases[config.target_phase] then
            filtered[config.target_phase] = phases[config.target_phase]
        end
        phases = filtered
    end

    if config.output_mode == "terminal" then
        render_terminal(phases)
    elseif config.output_mode == "markdown" then
        print(render_markdown(phases))
    elseif config.output_mode == "json" then
        print(render_json(phases))
    end
end
-- }}}

-- Export for library use
local dashboard = {
    init = init,
    scan = scan_issues,
    group_by_phase = group_by_phase,
    render_terminal = render_terminal,
    render_markdown = render_markdown,
    render_json = render_json,
    get_stats = function(phases)
        local total_issues = 0
        local total_done = 0
        for _, phase in pairs(phases) do
            total_issues = total_issues + #phase.issues
            total_done = total_done + phase.completed
        end
        return { total = total_issues, completed = total_done }
    end,
}

-- Run if executed directly
if arg and arg[0] then
    main()
end

return dashboard
