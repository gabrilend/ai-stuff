-- menu.lua - Interactive menu component using framebuffer TUI
-- Provides multi-section menus with vim keybindings, checkbox/flag/multistate items.
-- LuaJIT compatible. All rendering goes through the TUI framebuffer for clean updates.

local tui = require("tui")
local bit = require("bit")

-- {{{ Menu module
local menu = {}

-- Menu state
local state = {
    title = "",
    subtitle = "",
    sections = {},          -- Ordered list of section IDs
    section_data = {},      -- section_id -> {title, type, items}
    item_data = {},         -- item_id -> {label, type, value, description, config, disabled, default_value}
    values = {},            -- item_id -> current value
    current_section = 1,
    current_item = 1,
    rows = 24,
    cols = 80,
    items_end_row = 0,
    flag_edit_started = {}, -- item_id -> true if user started typing (first keystroke clears)
}
-- }}}

-- {{{ menu.init
-- Initialize menu from config table
function menu.init(config)
    state.title = config.title or "Menu"
    state.subtitle = config.subtitle or ""
    state.sections = {}
    state.section_data = {}
    state.item_data = {}
    state.values = {}
    state.current_section = 1
    state.current_item = 1
    state.flag_edit_started = {}

    -- Process sections
    for _, section in ipairs(config.sections or {}) do
        local sid = section.id
        table.insert(state.sections, sid)
        state.section_data[sid] = {
            title = section.title or sid,
            type = section.type or "single",  -- single or multi
            items = {}
        }

        -- Process items
        for _, item in ipairs(section.items or {}) do
            local iid = item.id
            table.insert(state.section_data[sid].items, iid)
            state.item_data[iid] = {
                label = item.label or iid,
                type = item.type or "checkbox",
                value = item.value or "",
                description = item.description or "",
                config = item.config or "",
                disabled = item.disabled or false,
                default_value = item.value or ""  -- Store original as default for flag items
            }
            state.values[iid] = item.value or (item.type == "checkbox" and "0" or "")
        end
    end

    -- Initialize TUI
    state.rows, state.cols = tui.init()
end
-- }}}

-- {{{ Helper functions
local function get_section_item_count(section_idx)
    local sid = state.sections[section_idx]
    if not sid then return 0 end
    return #(state.section_data[sid].items or {})
end

local function get_current_item_id()
    local sid = state.sections[state.current_section]
    if not sid then return nil end
    local items = state.section_data[sid].items
    return items[state.current_item]
end

local function get_total_items()
    local total = 0
    for i = 1, #state.sections do
        total = total + get_section_item_count(i)
    end
    return total
end

-- Reset the edit state when navigating away from an item
local function reset_flag_edit_state()
    state.flag_edit_started = {}
end
-- }}}

-- {{{ Rendering functions
local function render_header()
    local cols = state.cols

    -- Box top
    tui.reset_style()
    tui.draw_box_top(1, 1, cols, "double")

    -- Title line
    tui.draw_box_line(2, 1, cols, "double")
    tui.set_attrs(tui.ATTR_BOLD)
    local title_start = math.floor((cols - #state.title) / 2)
    tui.write_str(2, title_start, state.title)

    -- Subtitle line (if present)
    if state.subtitle ~= "" then
        tui.reset_style()
        tui.draw_box_line(3, 1, cols, "double")
        tui.set_attrs(tui.ATTR_DIM)
        local sub_start = math.floor((cols - #state.subtitle) / 2)
        tui.write_str(3, sub_start, state.subtitle)
    end

    -- Separator
    tui.reset_style()
    tui.draw_box_separator(4, 1, cols, "double")

    return 5  -- Next row (1-indexed)
end

local function render_item(row, item_id, highlight, item_num)
    local data = state.item_data[item_id]
    if not data then return end

    local value = state.values[item_id] or ""
    local label = data.label
    local item_type = data.type
    local disabled = data.disabled

    -- Clear the row first
    tui.clear_row(row)

    local col = 1

    -- Item number (1-9, then *)
    tui.set_attrs(tui.ATTR_DIM)
    if item_num then
        if item_num <= 9 then
            tui.write_str(row, col, tostring(item_num))
        else
            tui.write_str(row, col, "*")
        end
    end
    col = col + 1

    -- Cursor indicator
    tui.reset_style()
    if highlight then
        tui.set_attrs(tui.ATTR_BOLD)
        tui.write_str(row, col, ">")  -- Using > instead of ▸ for simplicity
    else
        tui.write_str(row, col, " ")
    end
    col = col + 1

    -- Type-specific prefix (checkbox indicator)
    tui.reset_style()
    if item_type == "checkbox" then
        if disabled then
            tui.set_attrs(tui.ATTR_DIM)
            tui.write_str(row, col, "[o]")
        elseif value == "1" then
            tui.set_fg(tui.FG_GREEN)
            tui.write_str(row, col, "[*]")
        else
            tui.write_str(row, col, "[ ]")
        end
        col = col + 4
    else
        tui.write_str(row, col, "  ")
        col = col + 2
    end

    -- Label
    tui.reset_style()
    if highlight then
        if disabled then
            tui.set_attrs(bit.bor(tui.ATTR_DIM, tui.ATTR_INVERSE))
        else
            tui.set_attrs(tui.ATTR_INVERSE)
        end
    else
        if disabled then
            tui.set_attrs(tui.ATTR_DIM)
        end
    end
    col = tui.write_str(row, col, label)

    -- Type-specific suffix
    tui.reset_style()
    if item_type == "flag" then
        local width = tonumber(data.config) or 10
        local suffix = string.format(": [%" .. width .. "s]", value)
        tui.write_str(row, col, suffix)
    elseif item_type == "multistate" then
        tui.set_attrs(highlight and tui.ATTR_NONE or tui.ATTR_DIM)
        tui.set_fg(highlight and tui.FG_CYAN or tui.FG_DEFAULT)
        col = tui.write_str(row, col, " <")
        tui.reset_style()
        col = tui.write_str(row, col, "[" .. string.upper(value) .. "]")
        tui.set_attrs(highlight and tui.ATTR_NONE or tui.ATTR_DIM)
        tui.set_fg(highlight and tui.FG_CYAN or tui.FG_DEFAULT)
        tui.write_str(row, col, ">")
    elseif item_type == "action" then
        -- Action items show an arrow indicator
        tui.set_fg(highlight and tui.FG_YELLOW or tui.FG_DEFAULT)
        tui.set_attrs(highlight and tui.ATTR_BOLD or tui.ATTR_DIM)
        tui.write_str(row, col, " -->")
    end

    tui.reset_style()
end

local function render_section(section_idx, start_row)
    local sid = state.sections[section_idx]
    local data = state.section_data[sid]
    local row = start_row
    local is_current = (section_idx == state.current_section)
    local global_idx = 0

    -- Calculate global index offset
    for i = 1, section_idx - 1 do
        global_idx = global_idx + get_section_item_count(i)
    end

    -- Section title
    tui.clear_row(row)
    tui.set_attrs(tui.ATTR_BOLD)
    tui.write_str(row, 3, data.title)
    row = row + 1

    -- Underline
    tui.clear_row(row)
    tui.reset_style()
    tui.draw_hline(row, 3, 3 + #data.title - 1)
    row = row + 1

    -- Items
    for i, item_id in ipairs(data.items) do
        global_idx = global_idx + 1
        local highlight = is_current and (i == state.current_item)
        render_item(row, item_id, highlight, global_idx)
        row = row + 1
    end

    return row
end

local function render_description(start_row)
    local row = start_row

    -- Separator line
    tui.clear_row(row)
    tui.reset_style()
    tui.draw_hline(row, 1, state.cols)
    row = row + 1

    -- Clear description area (2 lines)
    tui.clear_row(row)
    tui.clear_row(row + 1)

    -- Get current item description
    local item_id = get_current_item_id()
    if item_id then
        local desc = state.item_data[item_id].description
        if desc and desc ~= "" then
            local max_len = state.cols - 4
            if #desc > max_len then
                desc = desc:sub(1, max_len - 3) .. "..."
            end
            tui.write_str(row, 3, desc)
        end
    end

    return row + 2
end

local function render_footer()
    local row = state.rows - 1

    -- Separator
    tui.reset_style()
    tui.draw_box_separator(row, 1, state.cols, "double")

    -- Help text
    tui.clear_row(row + 1)
    tui.draw_box_line(row + 1, 1, state.cols, "double")
    tui.set_attrs(tui.ATTR_DIM)
    local help = "j/k:nav  space:toggle  `:action  q:quit"
    local help_start = math.floor((state.cols - #help) / 2)
    tui.write_str(row + 1, help_start, help)
    tui.reset_style()
end
-- }}}

-- {{{ menu.render
-- Full render of the menu (writes to back buffer, then presents)
function menu.render()
    tui.clear_back_buffer()

    local row = render_header()

    -- Sections
    for i, _ in ipairs(state.sections) do
        row = render_section(i, row)
        row = row + 1  -- Space between sections
    end

    state.items_end_row = row

    render_description(row)
    render_footer()

    tui.present()
end
-- }}}

-- {{{ Navigation functions
function menu.nav_up()
    reset_flag_edit_state()
    if state.current_item > 1 then
        state.current_item = state.current_item - 1
    elseif state.current_section > 1 then
        state.current_section = state.current_section - 1
        state.current_item = get_section_item_count(state.current_section)
    end
    menu.render()
end

function menu.nav_down()
    reset_flag_edit_state()
    local item_count = get_section_item_count(state.current_section)

    if state.current_item < item_count then
        state.current_item = state.current_item + 1
    elseif state.current_section < #state.sections then
        state.current_section = state.current_section + 1
        state.current_item = 1
    end
    menu.render()
end

function menu.nav_top()
    reset_flag_edit_state()
    state.current_section = 1
    state.current_item = 1
    menu.render()
end

function menu.nav_bottom()
    reset_flag_edit_state()
    state.current_section = #state.sections
    state.current_item = get_section_item_count(state.current_section)
    menu.render()
end

function menu.nav_to_index(target)
    reset_flag_edit_state()
    local current = 0
    for si, sid in ipairs(state.sections) do
        for ii, _ in ipairs(state.section_data[sid].items) do
            current = current + 1
            if current == target then
                state.current_section = si
                state.current_item = ii
                menu.render()
                return
            end
        end
    end
end

function menu.nav_to_action()
    -- Navigate to the first action item (usually at bottom)
    reset_flag_edit_state()
    for si, sid in ipairs(state.sections) do
        local items = state.section_data[sid].items
        for ii, item_id in ipairs(items) do
            if state.item_data[item_id].type == "action" then
                state.current_section = si
                state.current_item = ii
                menu.render()
                return true
            end
        end
    end
    return false
end
-- }}}

-- {{{ menu.toggle
-- Returns "action" if an action item was activated, nil otherwise
function menu.toggle()
    local item_id = get_current_item_id()
    if not item_id then return nil end

    local data = state.item_data[item_id]
    if data.disabled then return nil end

    local sid = state.sections[state.current_section]
    local section_type = state.section_data[sid].type

    if data.type == "action" then
        -- Action items trigger immediate execution
        return "action"
    elseif data.type == "checkbox" then
        if section_type == "single" then
            -- Radio button behavior: unselect all others in section
            for _, iid in ipairs(state.section_data[sid].items) do
                if state.item_data[iid].type == "checkbox" then
                    state.values[iid] = "0"
                end
            end
            state.values[item_id] = "1"
        else
            -- Toggle
            state.values[item_id] = state.values[item_id] == "1" and "0" or "1"
        end
    elseif data.type == "multistate" then
        -- Cycle through states (stored as comma-separated in config)
        local options = {}
        for opt in data.config:gmatch("[^,]+") do
            table.insert(options, opt)
        end
        local current_idx = 1
        for i, opt in ipairs(options) do
            if opt == state.values[item_id] then
                current_idx = i
                break
            end
        end
        current_idx = (current_idx % #options) + 1
        state.values[item_id] = options[current_idx]
    end

    menu.render()
    return nil
end
-- }}}

-- {{{ menu.set_checkbox
-- Explicitly set checkbox to checked (1)
function menu.set_checkbox()
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.disabled then return false end

    local sid = state.sections[state.current_section]
    local section_type = state.section_data[sid].type

    if data.type == "checkbox" then
        if section_type == "single" then
            -- Radio button behavior: unselect all others in section
            for _, iid in ipairs(state.section_data[sid].items) do
                if state.item_data[iid].type == "checkbox" then
                    state.values[iid] = "0"
                end
            end
        end
        state.values[item_id] = "1"
        menu.render()
        return true
    end
    return false
end
-- }}}

-- {{{ menu.unset_checkbox
-- Explicitly unset checkbox to unchecked (0)
function menu.unset_checkbox()
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.disabled then return false end

    if data.type == "checkbox" then
        state.values[item_id] = "0"
        menu.render()
        return true
    end
    return false
end
-- }}}

-- {{{ menu.handle_flag_left
-- Set flag value to 0 (off)
function menu.handle_flag_left()
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.type ~= "flag" or data.disabled then return false end

    state.values[item_id] = "0"
    state.flag_edit_started[item_id] = true  -- Mark as edited
    menu.render()
    return true
end
-- }}}

-- {{{ menu.handle_flag_right
-- Set flag value to default
function menu.handle_flag_right()
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.type ~= "flag" or data.disabled then return false end

    state.values[item_id] = data.default_value or "0"
    state.flag_edit_started[item_id] = true  -- Mark as edited
    menu.render()
    return true
end
-- }}}

-- {{{ menu.handle_flag_digit
-- Handle digit input for flag fields
-- First digit clears the field and starts fresh, subsequent digits append
function menu.handle_flag_digit(digit)
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.type ~= "flag" or data.disabled then return false end

    -- Validate digit (0-9)
    if not digit:match("^%d$") then return false end

    if not state.flag_edit_started[item_id] then
        -- First keystroke: clear and start fresh
        state.values[item_id] = digit
        state.flag_edit_started[item_id] = true
    else
        -- Subsequent keystrokes: append (but respect reasonable limits)
        local current = state.values[item_id] or ""
        -- Limit to reasonable length (e.g., 5 digits)
        if #current < 5 then
            state.values[item_id] = current .. digit
        end
    end

    menu.render()
    return true
end
-- }}}

-- {{{ menu.handle_flag_backspace
-- Handle backspace for flag fields
function menu.handle_flag_backspace()
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.type ~= "flag" or data.disabled then return false end

    local current = state.values[item_id] or ""
    if #current > 0 then
        state.values[item_id] = current:sub(1, -2)
        if #state.values[item_id] == 0 then
            state.values[item_id] = "0"
        end
    end

    menu.render()
    return true
end
-- }}}

-- {{{ menu.get_values
function menu.get_values()
    return state.values
end
-- }}}

-- {{{ menu.handle_left
-- Handle LEFT/h key - unset checkbox or set flag to 0
function menu.handle_left()
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.type == "flag" then
        return menu.handle_flag_left()
    elseif data.type == "checkbox" then
        return menu.unset_checkbox()
    elseif data.type == "multistate" then
        -- Cycle backwards through states
        local options = {}
        for opt in data.config:gmatch("[^,]+") do
            table.insert(options, opt)
        end
        local current_idx = 1
        for i, opt in ipairs(options) do
            if opt == state.values[item_id] then
                current_idx = i
                break
            end
        end
        current_idx = current_idx - 1
        if current_idx < 1 then current_idx = #options end
        state.values[item_id] = options[current_idx]
        menu.render()
        return true
    end
    return false
end
-- }}}

-- {{{ menu.handle_right
-- Handle RIGHT/l key - set checkbox or set flag to default
function menu.handle_right()
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.type == "flag" then
        return menu.handle_flag_right()
    elseif data.type == "checkbox" then
        return menu.set_checkbox()
    elseif data.type == "multistate" then
        -- Cycle forwards through states (same as toggle)
        local options = {}
        for opt in data.config:gmatch("[^,]+") do
            table.insert(options, opt)
        end
        local current_idx = 1
        for i, opt in ipairs(options) do
            if opt == state.values[item_id] then
                current_idx = i
                break
            end
        end
        current_idx = (current_idx % #options) + 1
        state.values[item_id] = options[current_idx]
        menu.render()
        return true
    end
    return false
end
-- }}}

-- {{{ menu.run
-- Main event loop
function menu.run()
    menu.render()

    while true do
        local key = tui.read_key()

        -- Handle nil key (EOF or read error)
        if not key then
            return "quit", state.values
        end

        -- Quit keys
        if key == "q" or key == "Q" or key == "ESCAPE" or key == "CTRL_C" then
            return "quit", state.values
        end

        -- Navigation: UP/k
        if key == "UP" or key == "k" then
            menu.nav_up()
        -- Navigation: DOWN/j
        elseif key == "DOWN" or key == "j" then
            menu.nav_down()
        -- LEFT/h: unset checkbox, set flag to 0, cycle multistate backwards
        elseif key == "LEFT" or key == "h" then
            menu.handle_left()
        -- RIGHT/l: set checkbox, set flag to default, cycle multistate forwards
        elseif key == "RIGHT" or key == "l" then
            menu.handle_right()
        -- Toggle/Activate: SPACE/i/ENTER
        elseif key == "SPACE" or key == "i" or key == "ENTER" then
            local result = menu.toggle()
            if result == "action" then
                return "run", state.values
            end
        -- Go to top
        elseif key == "g" then
            menu.nav_top()
        -- Go to bottom
        elseif key == "G" then
            menu.nav_bottom()
        -- Jump to action item: ` or ~
        elseif key == "`" or key == "~" then
            menu.nav_to_action()
        -- Digit keys 0-9: for flag fields or jump to item 1-9
        elseif type(key) == "string" and #key == 1 and key >= "0" and key <= "9" then
            -- Check if current item is a flag field
            local item_id = get_current_item_id()
            local is_flag = item_id and state.item_data[item_id] and state.item_data[item_id].type == "flag"
            if is_flag then
                menu.handle_flag_digit(key)
            elseif key >= "1" then
                -- Jump to item by number (only 1-9, not 0)
                menu.nav_to_index(tonumber(key))
            end
        -- Backspace: for flag fields
        elseif key == "BACKSPACE" or key == "DELETE" then
            menu.handle_flag_backspace()
        end
    end
end
-- }}}

-- {{{ menu.cleanup
function menu.cleanup()
    tui.cleanup()
end
-- }}}

return menu
