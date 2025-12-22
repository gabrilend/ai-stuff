-- input-dialog.lua - Multi-line input dialog with submit button
-- Allows user to enter multi-line text, then navigate to submit button.
-- LuaJIT compatible. Uses tui.lua for rendering.
--
-- Usage: luajit input-dialog.lua <title> <prompt_file>
-- Reads prompt/questions from prompt_file, displays them, captures response.
-- Outputs the user's response to stdout on submit.
-- Exit code 0 = submitted, 1 = cancelled

local tui = require("tui")
local bit = require("bit")

-- {{{ State
local state = {
    title = "Response",
    prompt_lines = {},      -- Lines of prompt text to display
    input_lines = {""},     -- User's input (array of lines)
    cursor_row = 1,         -- Current line in input (1-indexed)
    cursor_col = 1,         -- Current column in line (1-indexed)
    scroll_offset = 0,      -- Scroll offset for input area
    focus = "input",        -- "input" or "button"
    rows = 24,
    cols = 80,
    prompt_height = 0,      -- Calculated height of prompt area
    input_height = 0,       -- Calculated height of input area
    input_start_row = 0,    -- Row where input area starts
}
-- }}}

-- {{{ parse_args
local function parse_args()
    if #arg < 2 then
        io.stderr:write("Usage: luajit input-dialog.lua <title> <prompt_file>\n")
        os.exit(1)
    end

    state.title = arg[1]

    -- Read prompt from file
    local f = io.open(arg[2], "r")
    if not f then
        io.stderr:write("Error: Cannot open prompt file: " .. arg[2] .. "\n")
        os.exit(1)
    end

    for line in f:lines() do
        table.insert(state.prompt_lines, line)
    end
    f:close()
end
-- }}}

-- {{{ calculate_layout
local function calculate_layout()
    state.rows, state.cols = tui.get_size()

    -- Layout:
    -- Row 1: Title bar
    -- Row 2: Separator
    -- Rows 3-N: Prompt text (scrollable if needed, max 40% of screen)
    -- Row N+1: Separator
    -- Rows N+2 to M: Input area (at least 5 lines)
    -- Row M+1: Empty
    -- Row M+2: Submit button
    -- Row M+3: Help text

    local max_prompt_height = math.floor(state.rows * 0.4)
    state.prompt_height = math.min(#state.prompt_lines, max_prompt_height)

    -- Reserve: title(1) + sep(1) + prompt + sep(1) + input(min 5) + empty(1) + button(1) + help(1)
    local reserved = 1 + 1 + state.prompt_height + 1 + 1 + 1 + 1
    state.input_height = math.max(5, state.rows - reserved)
    state.input_start_row = 1 + 1 + state.prompt_height + 1 + 1  -- After title, sep, prompt, sep
end
-- }}}

-- {{{ render_title
local function render_title()
    tui.clear_row(1)
    tui.set_fg(tui.FG_CYAN)
    tui.set_attrs(tui.ATTR_BOLD)

    local title = " " .. state.title .. " "
    local start_col = math.floor((state.cols - #title) / 2)
    tui.write_str(1, start_col, title)

    tui.reset_style()

    -- Separator
    tui.clear_row(2)
    tui.draw_hline(2, 1, state.cols)
end
-- }}}

-- {{{ render_prompt
local function render_prompt()
    local start_row = 3

    tui.set_attrs(tui.ATTR_DIM)
    for i = 1, state.prompt_height do
        tui.clear_row(start_row + i - 1)
        local line = state.prompt_lines[i] or ""
        if #line > state.cols - 2 then
            line = line:sub(1, state.cols - 5) .. "..."
        end
        tui.write_str(start_row + i - 1, 2, line)
    end
    tui.reset_style()

    -- Separator after prompt
    local sep_row = start_row + state.prompt_height
    tui.clear_row(sep_row)
    tui.draw_hline(sep_row, 1, state.cols)
end
-- }}}

-- {{{ wrap_line
-- Wrap a line at word boundaries to fit within max_width
-- Returns table of {text=string, is_continuation=bool}
-- Continuation lines get a tab prefix (4 spaces visual)
local function wrap_line(line, max_width)
    local CONTINUATION_PREFIX = "    "  -- 4 spaces for continuation
    local first_line_width = max_width
    local cont_line_width = max_width - #CONTINUATION_PREFIX

    if #line <= first_line_width then
        return {{text = line, is_continuation = false, start_col = 1}}
    end

    local result = {}
    local remaining = line
    local is_first = true
    local col_offset = 1  -- Track position in original line

    while #remaining > 0 do
        local width = is_first and first_line_width or cont_line_width

        if #remaining <= width then
            table.insert(result, {
                text = remaining,
                is_continuation = not is_first,
                start_col = col_offset
            })
            break
        end

        -- Find word boundary to break at
        local break_at = width
        -- Look backwards for a space
        for i = width, 1, -1 do
            if remaining:sub(i, i) == " " then
                break_at = i
                break
            end
        end

        -- If no space found in reasonable range, just hard-break at width
        if break_at < width * 0.5 then
            break_at = width
        end

        local segment = remaining:sub(1, break_at)
        table.insert(result, {
            text = segment,
            is_continuation = not is_first,
            start_col = col_offset
        })

        -- Skip the space if we broke at one
        local skip = (remaining:sub(break_at, break_at) == " ") and 1 or 0
        col_offset = col_offset + break_at + skip
        remaining = remaining:sub(break_at + 1 + skip)
        is_first = false
    end

    -- Handle empty line
    if #result == 0 then
        table.insert(result, {text = "", is_continuation = false, start_col = 1})
    end

    return result
end
-- }}}

-- {{{ build_visual_lines
-- Build a table of all visual lines with metadata for rendering
-- Returns table of {text, is_continuation, logical_row, start_col, end_col}
local function build_visual_lines()
    local visual = {}
    local max_width = state.cols - 4  -- Leave margin for border

    for logical_row, line in ipairs(state.input_lines) do
        local wrapped = wrap_line(line, max_width)
        for _, seg in ipairs(wrapped) do
            local end_col = seg.start_col + #seg.text - 1
            if #seg.text == 0 then end_col = seg.start_col end
            table.insert(visual, {
                text = seg.text,
                is_continuation = seg.is_continuation,
                logical_row = logical_row,
                start_col = seg.start_col,
                end_col = end_col
            })
        end
    end

    return visual
end
-- }}}

-- {{{ find_cursor_visual_row
-- Find which visual row the cursor is on
local function find_cursor_visual_row(visual_lines)
    for i, vline in ipairs(visual_lines) do
        if vline.logical_row == state.cursor_row then
            -- Check if cursor_col falls within this visual line's range
            if state.cursor_col >= vline.start_col and
               (state.cursor_col <= vline.end_col + 1 or
                (i == #visual_lines or visual_lines[i+1].logical_row ~= state.cursor_row)) then
                return i
            end
        end
    end
    return 1
end
-- }}}

-- {{{ render_input
local function render_input()
    local start_row = state.input_start_row
    local CONTINUATION_PREFIX = "    "  -- Must match wrap_line

    -- Input area border indicator
    tui.clear_row(start_row - 1)
    if state.focus == "input" then
        tui.set_fg(tui.FG_GREEN)
        tui.set_attrs(tui.ATTR_BOLD)
        tui.write_str(start_row - 1, 2, "Your Response (Enter=newline, Tab=go to button):")
    else
        tui.set_attrs(tui.ATTR_DIM)
        tui.write_str(start_row - 1, 2, "Your Response:")
    end
    tui.reset_style()

    -- Build visual lines and find cursor position
    local visual_lines = build_visual_lines()
    local cursor_visual_row = find_cursor_visual_row(visual_lines)

    -- Adjust scroll to keep cursor visible (in visual line space)
    if cursor_visual_row <= state.scroll_offset then
        state.scroll_offset = cursor_visual_row - 1
    elseif cursor_visual_row > state.scroll_offset + state.input_height then
        state.scroll_offset = cursor_visual_row - state.input_height
    end

    -- Render visual lines with scroll
    for i = 1, state.input_height do
        local row = start_row + i - 1
        tui.clear_row(row)

        local vline_idx = state.scroll_offset + i
        local vline = visual_lines[vline_idx]

        if vline then
            -- Highlight current logical line if focused
            if state.focus == "input" and vline.logical_row == state.cursor_row then
                tui.set_bg(tui.BG_BLUE)
                -- Fill the line background
                for x = 2, state.cols - 1 do
                    tui.set_cell(row, x, " ")
                end
            end

            -- Add continuation prefix if wrapped
            local display_text = vline.text
            local text_start_col = 3
            if vline.is_continuation then
                tui.set_fg(tui.FG_YELLOW)
                tui.set_attrs(tui.ATTR_DIM)
                tui.write_str(row, 3, CONTINUATION_PREFIX)
                tui.reset_style()
                if state.focus == "input" and vline.logical_row == state.cursor_row then
                    tui.set_bg(tui.BG_BLUE)
                end
                text_start_col = 3 + #CONTINUATION_PREFIX
            end

            tui.write_str(row, text_start_col, display_text)

            -- Draw cursor if this is the cursor's visual line
            if state.focus == "input" and vline_idx == cursor_visual_row then
                -- Calculate cursor X position within this visual segment
                local cursor_offset = state.cursor_col - vline.start_col
                local cursor_x = text_start_col + cursor_offset
                if cursor_x >= text_start_col and cursor_x <= state.cols - 1 then
                    tui.set_bg(tui.BG_WHITE)
                    tui.set_fg(tui.FG_BLACK)
                    local char_idx = state.cursor_col - vline.start_col + 1
                    local char_under_cursor = vline.text:sub(char_idx, char_idx)
                    if char_under_cursor == "" then char_under_cursor = " " end
                    tui.set_cell(row, cursor_x, char_under_cursor)
                end
            end

            tui.reset_style()
        end
    end

    -- Line count indicator (logical lines / visual lines)
    local indicator = string.format(" Line %d/%d ", state.cursor_row, #state.input_lines)
    tui.set_attrs(tui.ATTR_DIM)
    tui.write_str(start_row + state.input_height, state.cols - #indicator - 1, indicator)
    tui.reset_style()
end
-- }}}

-- {{{ render_button
local function render_button()
    local button_row = state.input_start_row + state.input_height + 1
    tui.clear_row(button_row)

    local button_text = "[ Submit Response ]"
    local start_col = math.floor((state.cols - #button_text) / 2)

    if state.focus == "button" then
        tui.set_bg(tui.BG_GREEN)
        tui.set_fg(tui.FG_BLACK)
        tui.set_attrs(tui.ATTR_BOLD)
    else
        tui.set_attrs(tui.ATTR_DIM)
    end

    tui.write_str(button_row, start_col, button_text)
    tui.reset_style()
end
-- }}}

-- {{{ render_help
local function render_help()
    local help_row = state.rows
    tui.clear_row(help_row)

    local help_text
    if state.focus == "input" then
        help_text = "Tab/↓↓:button  Enter:newline  Ctrl-C/Esc:cancel"
    else
        help_text = "Tab/↑:edit  Enter/Space:submit  Ctrl-C/Esc:cancel"
    end

    tui.set_attrs(tui.ATTR_DIM)
    local start_col = math.floor((state.cols - #help_text) / 2)
    tui.write_str(help_row, start_col, help_text)
    tui.reset_style()
end
-- }}}

-- {{{ render
local function render()
    tui.clear_back_buffer()
    render_title()
    render_prompt()
    render_input()
    render_button()
    render_help()
    tui.present()
end
-- }}}

-- {{{ handle_input_key
local function handle_input_key(key)
    local line = state.input_lines[state.cursor_row] or ""

    if key == "UP" then
        if state.cursor_row > 1 then
            state.cursor_row = state.cursor_row - 1
            -- Clamp cursor_col to new line length
            local new_line = state.input_lines[state.cursor_row] or ""
            state.cursor_col = math.min(state.cursor_col, #new_line + 1)
        end
    elseif key == "DOWN" then
        if state.cursor_row < #state.input_lines then
            state.cursor_row = state.cursor_row + 1
            local new_line = state.input_lines[state.cursor_row] or ""
            state.cursor_col = math.min(state.cursor_col, #new_line + 1)
        else
            -- At last line, down goes to button
            state.focus = "button"
        end
    elseif key == "LEFT" then
        if state.cursor_col > 1 then
            state.cursor_col = state.cursor_col - 1
        elseif state.cursor_row > 1 then
            -- Move to end of previous line
            state.cursor_row = state.cursor_row - 1
            state.cursor_col = #(state.input_lines[state.cursor_row] or "") + 1
        end
    elseif key == "RIGHT" then
        if state.cursor_col <= #line then
            state.cursor_col = state.cursor_col + 1
        elseif state.cursor_row < #state.input_lines then
            -- Move to start of next line
            state.cursor_row = state.cursor_row + 1
            state.cursor_col = 1
        end
    elseif key == "HOME" then
        state.cursor_col = 1
    elseif key == "END" then
        state.cursor_col = #line + 1
    elseif key == "ENTER" then
        -- Split line at cursor
        local before = line:sub(1, state.cursor_col - 1)
        local after = line:sub(state.cursor_col)
        state.input_lines[state.cursor_row] = before
        table.insert(state.input_lines, state.cursor_row + 1, after)
        state.cursor_row = state.cursor_row + 1
        state.cursor_col = 1
    elseif key == "BACKSPACE" then
        if state.cursor_col > 1 then
            -- Delete char before cursor
            local before = line:sub(1, state.cursor_col - 2)
            local after = line:sub(state.cursor_col)
            state.input_lines[state.cursor_row] = before .. after
            state.cursor_col = state.cursor_col - 1
        elseif state.cursor_row > 1 then
            -- Join with previous line
            local prev_line = state.input_lines[state.cursor_row - 1] or ""
            local new_col = #prev_line + 1
            state.input_lines[state.cursor_row - 1] = prev_line .. line
            table.remove(state.input_lines, state.cursor_row)
            state.cursor_row = state.cursor_row - 1
            state.cursor_col = new_col
        end
    elseif key == "DELETE" then
        if state.cursor_col <= #line then
            -- Delete char at cursor
            local before = line:sub(1, state.cursor_col - 1)
            local after = line:sub(state.cursor_col + 1)
            state.input_lines[state.cursor_row] = before .. after
        elseif state.cursor_row < #state.input_lines then
            -- Join with next line
            local next_line = state.input_lines[state.cursor_row + 1] or ""
            state.input_lines[state.cursor_row] = line .. next_line
            table.remove(state.input_lines, state.cursor_row + 1)
        end
    elseif key == "TAB" or key == "SHIFT_TAB" then
        state.focus = "button"
    elseif #key == 1 and key:match("[%g ]") then
        -- Printable character - insert at cursor
        local before = line:sub(1, state.cursor_col - 1)
        local after = line:sub(state.cursor_col)
        state.input_lines[state.cursor_row] = before .. key .. after
        state.cursor_col = state.cursor_col + 1
    end
    -- Note: scroll adjustment is handled in render_input() based on visual lines
end
-- }}}

-- {{{ handle_button_key
local function handle_button_key(key)
    if key == "UP" or key == "TAB" or key == "SHIFT_TAB" then
        state.focus = "input"
    elseif key == "ENTER" or key == "SPACE" then
        return "submit"
    end
    return nil
end
-- }}}

-- {{{ main_loop
local function main_loop()
    while true do
        render()

        local key = tui.read_key()
        if not key then break end

        -- Global keys
        if key == "CTRL_C" or key == "ESCAPE" then
            return nil  -- Cancelled
        end

        -- Handle based on focus
        local action = nil
        if state.focus == "input" then
            handle_input_key(key)
        else
            action = handle_button_key(key)
        end

        if action == "submit" then
            return table.concat(state.input_lines, "\n")
        end
    end

    return nil
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

    if result then
        io.write(result)
        os.exit(0)
    else
        os.exit(1)
    end
end
-- }}}

main()
