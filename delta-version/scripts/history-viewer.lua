#!/usr/bin/env luajit
-- History Viewer - Terminal-based commit history browser
-- Presents project git history as a readable narrative with vim-style navigation.
-- Displays commit content in priority order: notes, completed issues, docs, other markdown.

local DIR = os.getenv("DIR") or "/mnt/mtwo/programming/ai-stuff"
local SCRIPT_DIR = arg[0]:match("(.*/)")  or "./"

-- Add libs to path
package.path = "/mnt/mtwo/programming/ai-stuff/scripts/libs/?.lua;" .. package.path

local tui = require("tui")

-- ============================================================================
-- Configuration
-- ============================================================================

local DOUBLE_TAP_THRESHOLD_MS = 300
local PAGE_SCROLL_LINES = 10

-- ============================================================================
-- Global State
-- ============================================================================

local state = {
    -- Project
    project_path = nil,
    project_name = nil,

    -- Commits (oldest first)
    commits = {},
    commit_count = 0,
    current_idx = 1,

    -- Content
    content_lines = {},
    line_count = 0,
    scroll_offset = 0,

    -- Position preservation: commit_hash -> scroll_offset
    saved_positions = {},

    -- Double-tap detection
    last_key = nil,
    last_key_time = 0,

    -- Display
    rows = 24,
    cols = 80,
}

-- ============================================================================
-- Utility Functions
-- ============================================================================

-- {{{ exec_capture
-- Execute command and capture output
local function exec_capture(cmd)
    local handle = io.popen(cmd .. " 2>/dev/null")
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    return result
end
-- }}}

-- {{{ exec_lines
-- Execute command and return lines as table
local function exec_lines(cmd)
    local lines = {}
    local handle = io.popen(cmd .. " 2>/dev/null")
    if not handle then return lines end
    for line in handle:lines() do
        table.insert(lines, line)
    end
    handle:close()
    return lines
end
-- }}}

-- {{{ get_time_ms
-- Get current time in milliseconds
local function get_time_ms()
    local handle = io.popen("date +%s%N")
    if not handle then return 0 end
    local result = handle:read("*a")
    handle:close()
    local ns = tonumber(result) or 0
    return math.floor(ns / 1000000)
end
-- }}}

-- {{{ string_split
local function string_split(str, sep)
    local parts = {}
    for part in str:gmatch("([^" .. sep .. "]+)") do
        table.insert(parts, part)
    end
    return parts
end
-- }}}

-- ============================================================================
-- Project Discovery
-- ============================================================================

-- {{{ get_projects_with_history
local function get_projects_with_history()
    local list_script = SCRIPT_DIR .. "list-projects.sh"
    local projects = {}

    local paths = exec_lines(list_script .. " --abs-paths")
    for _, path in ipairs(paths) do
        local name = path:match("([^/]+)$")
        local count_str = exec_capture("git -C '" .. path .. "' rev-list --count HEAD 2>/dev/null")
        local count = tonumber(count_str and count_str:gsub("%s+", "") or "0") or 0

        if count > 0 then
            table.insert(projects, {
                name = name,
                path = path,
                count = count
            })
        end
    end

    return projects
end
-- }}}

-- {{{ find_project_path
local function find_project_path(name)
    local list_script = SCRIPT_DIR .. "list-projects.sh"
    local paths = exec_lines(list_script .. " --abs-paths")

    for _, path in ipairs(paths) do
        local proj_name = path:match("([^/]+)$")
        if proj_name == name then
            return path
        end
    end

    return nil
end
-- }}}

-- {{{ select_project_interactive
local function select_project_interactive()
    local projects = get_projects_with_history()

    if #projects == 0 then
        return false
    end

    local selected = 1

    while true do
        tui.clear_back_buffer()

        -- Header
        tui.set_attrs(tui.ATTR_BOLD)
        tui.write_str(1, 1, "Select Project")
        tui.reset_style()

        tui.set_attrs(tui.ATTR_DIM)
        tui.write_str(2, 1, "Use j/k or arrows to navigate, Enter to select, q to quit")
        tui.reset_style()

        -- Project list
        for i, proj in ipairs(projects) do
            local row = i + 3

            if i == selected then
                tui.set_attrs(tui.ATTR_INVERSE)
                tui.write_str(row, 1, " " .. proj.name .. " ")
                tui.reset_style()
                tui.set_attrs(tui.ATTR_DIM)
                tui.write_str(row, #proj.name + 4, "(" .. proj.count .. " commits)")
            else
                tui.write_str(row, 1, "  " .. proj.name .. " ")
                tui.set_attrs(tui.ATTR_DIM)
                tui.write_str(row, #proj.name + 4, "(" .. proj.count .. " commits)")
            end
            tui.reset_style()
        end

        tui.present()

        local key = tui.read_key()

        if key == "UP" or key == "k" then
            if selected > 1 then selected = selected - 1 end
        elseif key == "DOWN" or key == "j" then
            if selected < #projects then selected = selected + 1 end
        elseif key == "g" then
            selected = 1
        elseif key == "G" then
            selected = #projects
        elseif key == "ENTER" or key == "l" then
            state.project_name = projects[selected].name
            state.project_path = projects[selected].path
            return true
        elseif key == "q" or key == "ESCAPE" or key == "CTRL_C" then
            return false
        end
    end
end
-- }}}

-- ============================================================================
-- Git Operations
-- ============================================================================

-- {{{ load_commits
local function load_commits()
    state.commits = {}

    -- Get commits oldest first (--reverse)
    local hashes = exec_lines("git -C '" .. state.project_path .. "' rev-list --reverse HEAD")

    for _, hash in ipairs(hashes) do
        table.insert(state.commits, hash)
    end

    state.commit_count = #state.commits
    return state.commit_count > 0
end
-- }}}

-- {{{ get_commit_metadata
local function get_commit_metadata(hash)
    local result = exec_capture("git -C '" .. state.project_path .. "' log -1 --format='%H|%ci|%an|%s' " .. hash)
    if not result then return nil end

    local parts = string_split(result:gsub("%s+$", ""), "|")
    return {
        hash = parts[1] or hash,
        date = parts[2] or "",
        author = parts[3] or "",
        subject = parts[4] or ""
    }
end
-- }}}

-- {{{ get_commit_message
local function get_commit_message(hash)
    return exec_capture("git -C '" .. state.project_path .. "' log -1 --format='%B' " .. hash) or ""
end
-- }}}

-- {{{ get_changed_files
local function get_changed_files(hash)
    return exec_lines("git -C '" .. state.project_path .. "' diff-tree --no-commit-id --name-only -r " .. hash)
end
-- }}}

-- {{{ get_file_content_at_commit
local function get_file_content_at_commit(hash, file)
    return exec_capture("git -C '" .. state.project_path .. "' show '" .. hash .. ":" .. file .. "'")
end
-- }}}

-- {{{ is_text_file
local function is_text_file(file)
    local ext = file:match("%.([^%.]+)$")
    if not ext then return true end

    ext = ext:lower()
    local text_exts = {
        md=true, txt=true, lua=true, sh=true, py=true, js=true, ts=true,
        json=true, yaml=true, yml=true, toml=true, ini=true, cfg=true, conf=true
    }
    local binary_exts = {
        png=true, jpg=true, jpeg=true, gif=true, ico=true, pdf=true,
        zip=true, tar=true, gz=true, exe=true, dll=true, so=true, o=true, a=true
    }

    if binary_exts[ext] then return false end
    return true
end
-- }}}

-- ============================================================================
-- Content Extraction
-- ============================================================================

-- {{{ extract_commit_content
local function extract_commit_content()
    state.content_lines = {}

    local hash = state.commits[state.current_idx]
    local meta = get_commit_metadata(hash)

    -- Header
    local function add_line(line)
        table.insert(state.content_lines, line or "")
    end

    add_line("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    add_line("COMMIT: " .. (meta.hash or ""):sub(1, 8) .. "  (" .. state.current_idx .. " of " .. state.commit_count .. ")")
    add_line("DATE:   " .. (meta.date or ""))
    add_line("AUTHOR: " .. (meta.author or ""))
    add_line("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    add_line("")

    -- Commit message
    local message = get_commit_message(hash)
    for line in message:gmatch("[^\n]+") do
        add_line(line)
    end
    add_line("")

    -- Categorize changed files
    local notes_content = {}
    local issues_content = {}
    local docs_content = {}
    local other_md_content = {}

    local files = get_changed_files(hash)
    for _, file in ipairs(files) do
        if is_text_file(file) then
            local content = get_file_content_at_commit(hash, file)
            if content then
                local category = nil

                if file:match("^notes/") then
                    category = notes_content
                elseif file:match("^issues/completed/") then
                    category = issues_content
                elseif file:match("^issues/[^/]+%.md$") then
                    -- Skip root-level issues (plans, not completed work)
                    category = nil
                elseif file:match("^docs/") then
                    category = docs_content
                elseif file:match("%.md$") then
                    category = other_md_content
                end

                if category then
                    table.insert(category, "### " .. file)
                    for line in content:gmatch("[^\n]*") do
                        table.insert(category, line)
                    end
                    table.insert(category, "")
                end
            end
        end
    end

    -- Add sections in priority order
    if #notes_content > 0 then
        add_line("§ NOTES")
        add_line("───────────────────────────────────────────────────────────────────────────────")
        for _, line in ipairs(notes_content) do add_line(line) end
    end

    if #issues_content > 0 then
        add_line("§ COMPLETED ISSUES")
        add_line("───────────────────────────────────────────────────────────────────────────────")
        for _, line in ipairs(issues_content) do add_line(line) end
    end

    if #docs_content > 0 then
        add_line("§ DOCUMENTATION")
        add_line("───────────────────────────────────────────────────────────────────────────────")
        for _, line in ipairs(docs_content) do add_line(line) end
    end

    if #other_md_content > 0 then
        add_line("§ OTHER MARKDOWN")
        add_line("───────────────────────────────────────────────────────────────────────────────")
        for _, line in ipairs(other_md_content) do add_line(line) end
    end

    state.line_count = #state.content_lines
end
-- }}}

-- ============================================================================
-- Rendering
-- ============================================================================

-- {{{ render_header
local function render_header()
    tui.set_bg(tui.BG_BLUE)
    tui.set_fg(tui.FG_WHITE)
    tui.set_attrs(tui.ATTR_BOLD)

    -- Fill header bar
    for x = 1, state.cols do
        tui.set_cell(1, x, " ")
    end

    local header = " " .. state.project_name .. " │ Commit " .. state.current_idx .. " of " .. state.commit_count .. " "
    tui.write_str(1, 1, header)

    tui.reset_style()
end
-- }}}

-- {{{ render_footer
local function render_footer()
    local row = state.rows

    tui.set_bg(tui.BG_WHITE)
    tui.set_fg(tui.FG_BLACK)

    -- Fill footer bar
    for x = 1, state.cols do
        tui.set_cell(row, x, " ")
    end

    local hints = " [←] Prev  [→] Next  [↑↓] Scroll  [g/G] First/Last  [q] Quit "
    tui.write_str(row, 1, hints)

    -- Scroll percentage
    local scroll_pct = 0
    if state.line_count > 0 then
        scroll_pct = math.floor(state.scroll_offset * 100 / state.line_count)
    end
    local pct_str = "│ " .. scroll_pct .. "% "
    tui.write_str(row, state.cols - #pct_str, pct_str)

    tui.reset_style()
end
-- }}}

-- {{{ render_content
local function render_content()
    local visible_rows = state.rows - 2  -- Header and footer

    -- Clear content area
    tui.reset_style()
    for row = 2, state.rows - 1 do
        for x = 1, state.cols do
            tui.set_cell(row, x, " ")
        end
    end

    -- Render visible lines
    local end_line = state.scroll_offset + visible_rows
    if end_line > state.line_count then end_line = state.line_count end

    local screen_row = 2
    for i = state.scroll_offset + 1, end_line do
        local line = state.content_lines[i] or ""

        -- Detect section headers and apply colors
        if line:match("^§ NOTES") then
            tui.set_fg(tui.FG_YELLOW)
            tui.set_attrs(tui.ATTR_BOLD)
        elseif line:match("^§ COMPLETED") then
            tui.set_fg(tui.FG_GREEN)
            tui.set_attrs(tui.ATTR_BOLD)
        elseif line:match("^§ DOCUMENTATION") then
            tui.set_fg(tui.FG_BLUE)
            tui.set_attrs(tui.ATTR_BOLD)
        elseif line:match("^§ OTHER") then
            tui.set_fg(tui.FG_MAGENTA)
            tui.set_attrs(tui.ATTR_BOLD)
        elseif line:match("^━") or line:match("^─") then
            tui.set_attrs(tui.ATTR_DIM)
        elseif line:match("^COMMIT:") or line:match("^DATE:") or line:match("^AUTHOR:") then
            tui.set_attrs(tui.ATTR_BOLD)
        elseif line:match("^### ") then
            tui.set_fg(tui.FG_CYAN)
        else
            tui.reset_style()
        end

        -- Truncate line to terminal width
        if #line > state.cols then
            line = line:sub(1, state.cols - 1) .. "…"
        end

        tui.write_str(screen_row, 1, line)
        tui.reset_style()

        screen_row = screen_row + 1
    end
end
-- }}}

-- {{{ render_full
local function render_full()
    tui.clear_back_buffer()
    render_header()
    render_content()
    render_footer()
    tui.present()
end
-- }}}

-- ============================================================================
-- Navigation
-- ============================================================================

-- {{{ save_position
local function save_position()
    local hash = state.commits[state.current_idx]
    state.saved_positions[hash] = state.scroll_offset
end
-- }}}

-- {{{ restore_position
local function restore_position()
    local hash = state.commits[state.current_idx]
    state.scroll_offset = state.saved_positions[hash] or 0
end
-- }}}

-- {{{ goto_commit
local function goto_commit(new_idx)
    -- Bounds check
    if new_idx < 1 then new_idx = 1 end
    if new_idx > state.commit_count then new_idx = state.commit_count end

    -- Save current position
    save_position()

    -- Move
    state.current_idx = new_idx

    -- Load content
    extract_commit_content()

    -- Restore position
    restore_position()

    -- Ensure valid scroll
    local max_scroll = state.line_count - (state.rows - 2)
    if max_scroll < 0 then max_scroll = 0 end
    if state.scroll_offset > max_scroll then state.scroll_offset = max_scroll end
end
-- }}}

-- {{{ scroll_to
local function scroll_to(target)
    local max_scroll = state.line_count - (state.rows - 2)
    if max_scroll < 0 then max_scroll = 0 end

    if target < 0 then target = 0 end
    if target > max_scroll then target = max_scroll end

    state.scroll_offset = target
end
-- }}}

-- {{{ scroll_by
local function scroll_by(delta)
    scroll_to(state.scroll_offset + delta)
end
-- }}}

-- ============================================================================
-- Double-Tap Detection
-- ============================================================================

-- {{{ check_double_tap
local function check_double_tap(key)
    local now = get_time_ms()

    if key == state.last_key then
        local elapsed = now - state.last_key_time
        if elapsed < DOUBLE_TAP_THRESHOLD_MS then
            -- Double-tap detected
            state.last_key = nil
            state.last_key_time = 0
            return true
        end
    end

    state.last_key = key
    state.last_key_time = now
    return false
end
-- }}}

-- ============================================================================
-- Main Loop
-- ============================================================================

-- {{{ handle_input
local function handle_input()
    local key = tui.read_key()

    if key == "LEFT" or key == "h" then
        goto_commit(state.current_idx - 1)
        render_full()

    elseif key == "RIGHT" or key == "l" then
        goto_commit(state.current_idx + 1)
        render_full()

    elseif key == "g" then
        goto_commit(1)
        render_full()

    elseif key == "G" then
        goto_commit(state.commit_count)
        render_full()

    elseif key == "UP" or key == "k" then
        if check_double_tap("UP") then
            scroll_to(0)
        else
            scroll_by(-1)
        end
        render_content()
        render_footer()
        tui.present()

    elseif key == "DOWN" or key == "j" then
        if check_double_tap("DOWN") then
            local max_scroll = state.line_count - (state.rows - 2)
            scroll_to(max_scroll)
        else
            scroll_by(1)
        end
        render_content()
        render_footer()
        tui.present()

    elseif key == "PAGEUP" then
        scroll_by(-PAGE_SCROLL_LINES)
        render_content()
        render_footer()
        tui.present()

    elseif key == "PAGEDOWN" then
        scroll_by(PAGE_SCROLL_LINES)
        render_content()
        render_footer()
        tui.present()

    elseif key == "q" or key == "ESCAPE" or key == "CTRL_C" then
        return false
    end

    return true
end
-- }}}

-- {{{ run_viewer
local function run_viewer()
    state.rows, state.cols = tui.init()

    -- Load first commit
    goto_commit(1)

    -- Initial render
    render_full()

    -- Main loop
    while handle_input() do
        -- Check for resize
        local new_rows, new_cols = tui.get_size()
        if new_rows ~= state.rows or new_cols ~= state.cols then
            state.rows, state.cols = new_rows, new_cols
            tui.resize()
            render_full()
        end
    end

    tui.cleanup()
end
-- }}}

-- ============================================================================
-- CLI and Entry Point
-- ============================================================================

-- {{{ show_help
local function show_help()
    print([[
Usage: history-viewer.lua [OPTIONS] [PROJECT]

Browse project git history as a readable narrative.

Options:
    -p, --project NAME    Select project directly (skip menu)
    -c, --commit HASH     Start at specific commit
    -h, --help            Show this help message

Navigation:
    ←/h         Previous commit (older)
    →/l         Next commit (newer)
    ↑/k         Scroll up one line
    ↓/j         Scroll down one line
    ↑↑/kk       Jump to top (double-tap)
    ↓↓/jj       Jump to bottom (double-tap)
    PgUp/PgDn   Scroll one page
    g           Go to first commit
    G           Go to last commit
    q/Esc       Quit

Examples:
    history-viewer.lua                           # Interactive project selection
    history-viewer.lua --project delta-version   # View specific project
    history-viewer.lua delta-version             # Same as above
]])
end
-- }}}

-- {{{ parse_args
local function parse_args()
    local project_arg = nil
    local commit_arg = nil

    local i = 1
    while i <= #arg do
        local a = arg[i]

        if a == "-p" or a == "--project" then
            i = i + 1
            project_arg = arg[i]
        elseif a == "-c" or a == "--commit" then
            i = i + 1
            commit_arg = arg[i]
        elseif a == "-h" or a == "--help" then
            show_help()
            os.exit(0)
        elseif not a:match("^%-") then
            project_arg = a
        end

        i = i + 1
    end

    return project_arg, commit_arg
end
-- }}}

-- {{{ main
local function main()
    local project_arg, commit_arg = parse_args()

    -- Select or find project
    if project_arg then
        state.project_path = find_project_path(project_arg)
        if not state.project_path then
            io.stderr:write("ERROR: Project not found: " .. project_arg .. "\n")
            os.exit(1)
        end
        state.project_name = project_arg
    else
        -- Interactive selection
        state.rows, state.cols = tui.init()

        local ok = select_project_interactive()

        tui.cleanup()

        if not ok then
            print("No project selected.")
            os.exit(0)
        end
    end

    -- Verify git
    local git_check = exec_capture("git -C '" .. state.project_path .. "' rev-parse --git-dir")
    if not git_check or git_check == "" then
        io.stderr:write("ERROR: Not a git repository: " .. state.project_path .. "\n")
        os.exit(1)
    end

    -- Load commits
    if not load_commits() then
        io.stderr:write("ERROR: No commits found in " .. state.project_name .. "\n")
        os.exit(1)
    end

    -- Start at specific commit if requested
    if commit_arg then
        for i, hash in ipairs(state.commits) do
            if hash:sub(1, #commit_arg) == commit_arg then
                state.current_idx = i
                break
            end
        end
    end

    -- Run viewer
    run_viewer()
end
-- }}}

main()
