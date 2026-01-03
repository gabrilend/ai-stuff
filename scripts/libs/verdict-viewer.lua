-- verdict-viewer.lua - Read-only content viewer for analysis review
-- Displays analysis content and lets user decide: execute, skip, or quit.
-- LuaJIT compatible. Uses tui.lua for rendering.
--
-- Usage: luajit verdict-viewer.lua <content_file> <title> <counter_text>
--   content_file: file containing the analysis content to display
--   title: issue file name to show in title bar
--   counter_text: e.g., "Issue 3 of 15"
--
-- Outputs to stdout: "execute", "skip", or "quit"
-- Exit code 0 = decision made, 1 = error

local tui = require("tui")
local bit = require("bit")

-- {{{ State
local state = {
    title = "Review",
    counter = "",
    content_lines = {},   -- Lines of content to display
    scroll_offset = 0,    -- Current scroll position (0-indexed line at top)
    rows = 24,
    cols = 80,
    content_height = 0,   -- Height of scrollable area
    content_start_row = 0, -- Row where content starts
}
-- }}}

-- {{{ parse_args
local function parse_args()
    if #arg < 3 then
        io.stderr:write("Usage: luajit verdict-viewer.lua <content_file> <title> <counter_text>\n")
        os.exit(1)
    end

    -- Read content from file
    local f = io.open(arg[1], "r")
    if not f then
        io.stderr:write("Error: Cannot open content file: " .. arg[1] .. "\n")
        os.exit(1)
    end

    for line in f:lines() do
        table.insert(state.content_lines, line)
    end
    f:close()

    state.title = arg[2]
    state.counter = arg[3]
end
-- }}}

-- {{{ calculate_layout
local function calculate_layout()
    state.rows, state.cols = tui.get_size()

    -- Layout:
    -- Row 1: Title bar (issue name)
    -- Row 2: Separator
    -- Rows 3 to (rows-3): Content area (scrollable)
    -- Row rows-2: Separator
    -- Row rows-1: Hotkeys
    -- Row rows: Counter

    state.content_start_row = 3
    -- Reserve: title(1) + sep(1) + sep(1) + hotkeys(1) + counter(1) = 5
    state.content_height = state.rows - 5
end
-- }}}

-- {{{ wrap_line
-- Wrap a line at word boundaries to fit within max_width
-- Returns table of wrapped line strings
local function wrap_line(line, max_width)
    if #line <= max_width then
        return {line}
    end

    local result = {}
    local remaining = line

    while #remaining > 0 do
        if #remaining <= max_width then
            table.insert(result, remaining)
            break
        end

        -- Find word boundary to break at
        local break_at = max_width
        for i = max_width, 1, -1 do
            if remaining:sub(i, i) == " " then
                break_at = i
                break
            end
        end

        -- If no space found in reasonable range, hard-break at width
        if break_at < max_width * 0.5 then
            break_at = max_width
        end

        local segment = remaining:sub(1, break_at)
        table.insert(result, segment)

        -- Skip the space if we broke at one
        local skip = (remaining:sub(break_at, break_at) == " ") and 1 or 0
        remaining = remaining:sub(break_at + 1 + skip)
    end

    -- Handle empty result
    if #result == 0 then
        table.insert(result, "")
    end

    return result
end
-- }}}

-- {{{ build_visual_lines
-- Build table of all visual lines (with word wrapping applied)
local function build_visual_lines()
    local visual = {}
    local max_width = state.cols - 4  -- Leave margin

    for _, line in ipairs(state.content_lines) do
        local wrapped = wrap_line(line, max_width)
        for _, segment in ipairs(wrapped) do
            table.insert(visual, segment)
        end
    end

    return visual
end
-- }}}

-- {{{ render_title
local function render_title()
    tui.clear_row(1)
    tui.set_fg(tui.FG_CYAN)
    tui.set_attrs(tui.ATTR_BOLD)

    -- Show "Review: <title>" centered
    local title = " Review: " .. state.title .. " "
    local start_col = math.max(1, math.floor((state.cols - #title) / 2))
    tui.write_str(1, start_col, title)

    tui.reset_style()

    -- Separator
    tui.clear_row(2)
    tui.draw_hline(2, 1, state.cols)
end
-- }}}

-- {{{ render_content
local function render_content(visual_lines)
    local start_row = state.content_start_row

    -- Calculate max scroll
    local max_scroll = math.max(0, #visual_lines - state.content_height)
    state.scroll_offset = math.min(state.scroll_offset, max_scroll)
    state.scroll_offset = math.max(0, state.scroll_offset)

    for i = 1, state.content_height do
        local row = start_row + i - 1
        tui.clear_row(row)

        local line_idx = state.scroll_offset + i
        local line = visual_lines[line_idx]

        if line then
            -- Highlight markdown headers
            if line:match("^##+ ") then
                tui.set_fg(tui.FG_YELLOW)
                tui.set_attrs(tui.ATTR_BOLD)
            elseif line:match("^%*") or line:match("^%-") then
                -- List items
                tui.set_fg(tui.FG_GREEN)
            elseif line:match("^%d+%.") then
                -- Numbered items
                tui.set_fg(tui.FG_GREEN)
            else
                tui.reset_style()
            end

            tui.write_str(row, 3, line)
            tui.reset_style()
        end
    end

    -- Scroll indicator on right edge
    if #visual_lines > state.content_height then
        local scroll_pct = state.scroll_offset / max_scroll
        local indicator_row = start_row + math.floor(scroll_pct * (state.content_height - 1))

        tui.set_fg(tui.FG_CYAN)
        tui.set_attrs(tui.ATTR_BOLD)
        tui.write_str(indicator_row, state.cols, "|")
        tui.reset_style()

        -- Show scroll percentage
        local pct_text = string.format(" %d%% ", math.floor(scroll_pct * 100))
        tui.set_attrs(tui.ATTR_DIM)
        tui.write_str(start_row + state.content_height - 1, state.cols - #pct_text, pct_text)
        tui.reset_style()
    end
end
-- }}}

-- {{{ render_footer
local function render_footer()
    local sep_row = state.rows - 2
    local hotkey_row = state.rows - 1
    local counter_row = state.rows

    -- Separator
    tui.clear_row(sep_row)
    tui.draw_hline(sep_row, 1, state.cols)

    -- Hotkeys
    tui.clear_row(hotkey_row)
    local hotkeys = "  [e] Execute   [s] Skip   [q] Quit          [j/k] Scroll   [g/G] Top/Bottom"
    tui.set_attrs(tui.ATTR_DIM)
    tui.write_str(hotkey_row, 1, hotkeys)
    tui.reset_style()

    -- Counter on the right
    tui.clear_row(counter_row)
    tui.set_fg(tui.FG_CYAN)
    local counter_start = state.cols - #state.counter - 1
    tui.write_str(counter_row, counter_start, state.counter)
    tui.reset_style()
end
-- }}}

-- {{{ render
local function render(visual_lines)
    tui.clear_back_buffer()
    render_title()
    render_content(visual_lines)
    render_footer()
    tui.present()
end
-- }}}

-- {{{ main_loop
local function main_loop()
    local visual_lines = build_visual_lines()
    local max_scroll = math.max(0, #visual_lines - state.content_height)

    while true do
        render(visual_lines)

        local key = tui.read_key()
        if not key then break end

        -- Decision keys
        if key == "e" or key == "E" then
            return "execute"
        elseif key == "s" or key == "S" then
            return "skip"
        elseif key == "q" or key == "Q" or key == "CTRL_C" or key == "ESCAPE" then
            return "quit"

        -- Scroll keys
        elseif key == "j" or key == "DOWN" then
            state.scroll_offset = math.min(state.scroll_offset + 1, max_scroll)
        elseif key == "k" or key == "UP" then
            state.scroll_offset = math.max(state.scroll_offset - 1, 0)
        elseif key == "CTRL_D" or key == "PAGEDOWN" then
            -- Half page down
            state.scroll_offset = math.min(state.scroll_offset + math.floor(state.content_height / 2), max_scroll)
        elseif key == "CTRL_U" or key == "PAGEUP" then
            -- Half page up
            state.scroll_offset = math.max(state.scroll_offset - math.floor(state.content_height / 2), 0)
        elseif key == "g" then
            -- Go to top
            state.scroll_offset = 0
        elseif key == "G" then
            -- Go to bottom
            state.scroll_offset = max_scroll
        elseif key == "SPACE" then
            -- Page down
            state.scroll_offset = math.min(state.scroll_offset + state.content_height, max_scroll)
        end
    end

    return "quit"
end
-- }}}

-- {{{ main
local function main()
    parse_args()
    calculate_layout()

    state.rows, state.cols = tui.init()
    calculate_layout()  -- Recalculate with actual size

    local result = main_loop()

    tui.cleanup()

    io.write(result)
    os.exit(0)
end
-- }}}

main()
