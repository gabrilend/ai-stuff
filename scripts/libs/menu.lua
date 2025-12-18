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
    item_data = {},         -- item_id -> {label, type, value, description, config, disabled, default_value, shortcut}
    values = {},            -- item_id -> current value
    shortcuts = {},         -- key -> item_id (custom shortcut keys)
    current_section = 1,
    current_item = 1,
    rows = 24,
    cols = 80,
    items_end_row = 0,
    flag_edit_started = {}, -- item_id -> true if user started typing (first keystroke clears)
    last_digit = nil,       -- Last digit pressed for index navigation
    digit_count = 0,        -- How many times same digit pressed consecutively
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
    state.shortcuts = {}
    state.current_section = 1
    state.current_item = 1
    state.flag_edit_started = {}
    state.last_digit = nil
    state.digit_count = 0

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
                default_value = item.value or "",  -- Store original as default for flag items
                shortcut = item.shortcut or nil    -- Optional keyboard shortcut
            }
            state.values[iid] = item.value or (item.type == "checkbox" and "0" or "")

            -- Build shortcuts lookup table
            if item.shortcut and #item.shortcut == 1 then
                state.shortcuts[item.shortcut] = iid
            end
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

local function get_current_section_type()
    local sid = state.sections[state.current_section]
    if not sid then return nil end
    return state.section_data[sid].type
end

local function get_total_items()
    local total = 0
    for i = 1, #state.sections do
        total = total + get_section_item_count(i)
    end
    return total
end

-- Count only checkbox items (for index numbering)
local function get_checkbox_count()
    local count = 0
    for _, sid in ipairs(state.sections) do
        for _, item_id in ipairs(state.section_data[sid].items) do
            if state.item_data[item_id].type == "checkbox" then
                count = count + 1
            end
        end
    end
    return count
end

-- Get the Nth checkbox item's section and item indices (1-based)
-- Returns section_idx, item_idx, item_id or nil if not found
local function get_checkbox_by_index(target_idx)
    local count = 0
    for si, sid in ipairs(state.sections) do
        for ii, item_id in ipairs(state.section_data[sid].items) do
            if state.item_data[item_id].type == "checkbox" then
                count = count + 1
                if count == target_idx then
                    return si, ii, item_id
                end
            end
        end
    end
    return nil, nil, nil
end

-- Calculate the tier (number of digit repetitions) for an item number
-- Items 1-10: tier 1, Items 11-20: tier 2, etc.
local function get_item_tier(item_num)
    return math.ceil(item_num / 10)
end

-- Get the max tier needed for displaying checkbox items
local function get_max_tier()
    local total = get_checkbox_count()
    if total == 0 then return 1 end
    return get_item_tier(total)
end

-- Convert item number (1-based) to index string
-- 1-9 -> "1"-"9", 10 -> "0", 11-19 -> "11"-"99", 20 -> "00", etc.
local function item_to_index_str(item_num)
    local tier = get_item_tier(item_num)
    local position = ((item_num - 1) % 10) + 1  -- 1-10
    local digit = position % 10  -- 1-9, then 0
    return string.rep(tostring(digit), tier)
end

-- Convert digit and repeat count to checkbox index
-- digit=1, count=1 -> 1, digit=0, count=1 -> 10
-- digit=1, count=2 -> 11, digit=0, count=2 -> 20
local function index_to_checkbox(digit, repeat_count)
    local position = (digit == 0) and 10 or digit
    return (repeat_count - 1) * 10 + position
end

-- Reset the edit state when navigating away from an item
local function reset_flag_edit_state()
    state.flag_edit_started = {}
end

-- Reset digit input state for index navigation
local function reset_digit_input_state()
    state.last_digit = nil
    state.digit_count = 0
end

-- Find an item's section and item indices by item_id
-- Returns section_idx, item_idx or nil if not found
local function find_item_position(target_item_id)
    for si, sid in ipairs(state.sections) do
        for ii, item_id in ipairs(state.section_data[sid].items) do
            if item_id == target_item_id then
                return si, ii
            end
        end
    end
    return nil, nil
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

local function render_item(row, item_id, highlight, item_num, section_type)
    local data = state.item_data[item_id]
    if not data then return end

    local value = state.values[item_id] or ""
    local label = data.label
    local item_type = data.type
    local disabled = data.disabled
    local is_radio = (section_type == "single")  -- Radio button in single-select section

    -- Clear the row first
    tui.clear_row(row)

    local col = 1

    -- Item number with repeated digit pattern (1-9, 0, 11-99, 00, 111-999, 000, ...)
    -- Only shown for checkbox items (not flag/action/multistate)
    -- Padded to max tier width for alignment
    local max_tier = get_max_tier()
    tui.set_attrs(tui.ATTR_DIM)
    if item_num and item_type == "checkbox" then
        local index_str = item_to_index_str(item_num)
        -- Right-pad to max_tier width
        local padded = string.format("%-" .. max_tier .. "s", index_str)
        tui.write_str(row, col, padded)
    else
        -- No index for non-checkbox items, just spaces
        tui.write_str(row, col, string.rep(" ", max_tier))
    end
    col = col + max_tier

    -- Cursor indicator
    tui.reset_style()
    if highlight then
        tui.set_attrs(tui.ATTR_BOLD)
        tui.write_str(row, col, ">")  -- Using > instead of ▸ for simplicity
    else
        tui.write_str(row, col, " ")
    end
    col = col + 1

    -- Type-specific prefix (checkbox/radio indicator)
    -- Radio buttons use ( ) parentheses, checkboxes use [ ] brackets
    tui.reset_style()
    if item_type == "checkbox" then
        if disabled then
            tui.set_attrs(tui.ATTR_DIM)
            tui.write_str(row, col, is_radio and "(o)" or "[o]")
        elseif value == "1" then
            tui.set_fg(tui.FG_GREEN)
            tui.write_str(row, col, is_radio and "(*)" or "[*]")
        else
            tui.write_str(row, col, is_radio and "( )" or "[ ]")
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

local function render_section(section_idx, start_row, checkbox_idx_start)
    local sid = state.sections[section_idx]
    local data = state.section_data[sid]
    local row = start_row
    local is_current = (section_idx == state.current_section)
    local checkbox_idx = checkbox_idx_start or 0

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
    local section_type = data.type
    for i, item_id in ipairs(data.items) do
        local item_type = state.item_data[item_id].type
        local highlight = is_current and (i == state.current_item)

        -- Only increment and pass checkbox index for checkbox items
        if item_type == "checkbox" then
            checkbox_idx = checkbox_idx + 1
            render_item(row, item_id, highlight, checkbox_idx, section_type)
        else
            render_item(row, item_id, highlight, nil, section_type)
        end
        row = row + 1
    end

    return row, checkbox_idx
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
    -- Build custom shortcuts string
    local shortcuts_parts = {}
    for key, item_id in pairs(state.shortcuts) do
        local data = state.item_data[item_id]
        if data then
            -- Use first word of label or short version
            local short_label = data.label:match("^(%S+)") or data.label
            if #short_label > 12 then
                short_label = short_label:sub(1, 10) .. ".."
            end
            table.insert(shortcuts_parts, key .. ":" .. short_label:lower())
        end
    end
    local shortcuts_str = table.concat(shortcuts_parts, "  ")

    -- Determine if we need extra rows for shortcuts
    local base_help = "j/k:nav  space:toggle  `:action  q:quit"
    local has_shortcuts = #shortcuts_parts > 0

    local row
    if has_shortcuts then
        row = state.rows - 2
    else
        row = state.rows - 1
    end

    -- Separator
    tui.reset_style()
    tui.draw_box_separator(row, 1, state.cols, "double")

    -- Help text
    tui.clear_row(row + 1)
    tui.draw_box_line(row + 1, 1, state.cols, "double")
    tui.set_attrs(tui.ATTR_DIM)
    local help_start = math.floor((state.cols - #base_help) / 2)
    tui.write_str(row + 1, help_start, base_help)

    -- Shortcuts line (if any)
    if has_shortcuts then
        tui.clear_row(row + 2)
        tui.draw_box_line(row + 2, 1, state.cols, "double")
        tui.set_fg(tui.FG_CYAN)
        tui.set_attrs(tui.ATTR_DIM)
        local sc_start = math.floor((state.cols - #shortcuts_str) / 2)
        tui.write_str(row + 2, sc_start, shortcuts_str)
    end

    tui.reset_style()
end
-- }}}

-- {{{ menu.render
-- Full render of the menu (writes to back buffer, then presents)
function menu.render()
    tui.clear_back_buffer()

    local row = render_header()
    local checkbox_idx = 0

    -- Sections
    for i, _ in ipairs(state.sections) do
        row, checkbox_idx = render_section(i, row, checkbox_idx)
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
    reset_digit_input_state()
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
    reset_digit_input_state()
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
    reset_digit_input_state()
    state.current_section = 1
    state.current_item = 1
    menu.render()
end

function menu.nav_bottom()
    reset_flag_edit_state()
    reset_digit_input_state()
    state.current_section = #state.sections
    state.current_item = get_section_item_count(state.current_section)
    menu.render()
end

function menu.nav_to_index(target)
    reset_flag_edit_state()
    -- Note: don't reset digit state here, caller handles it
    local current = 0
    for si, sid in ipairs(state.sections) do
        for ii, _ in ipairs(state.section_data[sid].items) do
            current = current + 1
            if current == target then
                state.current_section = si
                state.current_item = ii
                menu.render()
                return true
            end
        end
    end
    return false
end

function menu.nav_to_action()
    -- Navigate to the first action item (usually at bottom)
    reset_flag_edit_state()
    reset_digit_input_state()
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

function menu.nav_to_checkbox(target_idx)
    -- Navigate to the Nth checkbox item (1-based index)
    reset_flag_edit_state()
    -- Note: don't reset digit state here, caller handles it
    local si, ii, _ = get_checkbox_by_index(target_idx)
    if si and ii then
        state.current_section = si
        state.current_item = ii
        menu.render()
        return true
    end
    return false
end

function menu.nav_to_item(item_id)
    -- Navigate to a specific item by its ID
    reset_flag_edit_state()
    reset_digit_input_state()
    local si, ii = find_item_position(item_id)
    if si and ii then
        state.current_section = si
        state.current_item = ii
        menu.render()
        return true
    end
    return false
end

function menu.handle_shortcut(key)
    -- Handle custom shortcut key
    -- If already on the item, toggle it; otherwise navigate to it
    local target_item_id = state.shortcuts[key]
    if not target_item_id then return false end

    local current_item_id = get_current_item_id()

    if current_item_id == target_item_id then
        -- Already on this item, toggle it
        return menu.toggle()
    else
        -- Navigate to this item
        menu.nav_to_item(target_item_id)
        return nil
    end
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
-- Radio buttons (single sections) cannot be unchecked - one must always be selected
function menu.unset_checkbox()
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.disabled then return false end

    -- Prevent unchecking radio buttons (single-select sections)
    local section_type = get_current_section_type()
    if section_type == "single" then
        return false  -- Radio buttons cannot be unchecked
    end

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
-- Does NOT mark as edited, so next digit will overwrite
function menu.handle_flag_left()
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.type ~= "flag" or data.disabled then return false end

    state.values[item_id] = "0"
    state.flag_edit_started[item_id] = nil  -- Reset so next digit overwrites
    menu.render()
    return true
end
-- }}}

-- {{{ menu.handle_flag_right
-- Set flag value to default
-- Does NOT mark as edited, so next digit will overwrite
function menu.handle_flag_right()
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.type ~= "flag" or data.disabled then return false end

    state.values[item_id] = data.default_value or "0"
    state.flag_edit_started[item_id] = nil  -- Reset so next digit overwrites
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
        -- Digit keys 0-9: for flag fields or jump to checkbox by index
        elseif type(key) == "string" and #key == 1 and key >= "0" and key <= "9" then
            -- Check if current item is a flag field
            local item_id = get_current_item_id()
            local is_flag = item_id and state.item_data[item_id] and state.item_data[item_id].type == "flag"
            if is_flag then
                menu.handle_flag_digit(key)
            else
                -- Index navigation with consecutive digit tracking (checkbox items only)
                local digit = tonumber(key)

                -- Track consecutive presses of same digit
                if digit == state.last_digit then
                    state.digit_count = state.digit_count + 1
                else
                    state.last_digit = digit
                    state.digit_count = 1
                end

                -- Calculate target checkbox from digit and repeat count
                local target = index_to_checkbox(digit, state.digit_count)
                local total = get_checkbox_count()

                -- Only navigate if target checkbox exists
                if target <= total then
                    menu.nav_to_checkbox(target)
                else
                    -- Target doesn't exist, reset to single press
                    state.digit_count = 1
                    target = index_to_checkbox(digit, 1)
                    if target <= total then
                        menu.nav_to_checkbox(target)
                    end
                end
            end
        -- SHIFT+digit (!@#$%^&*()): go back one tier in index navigation
        -- Also handles custom shortcuts for other single characters
        elseif type(key) == "string" and #key == 1 then
            -- Map shifted digits to their base digit
            local shift_map = {
                ["!"] = 1, ["@"] = 2, ["#"] = 3, ["$"] = 4, ["%"] = 5,
                ["^"] = 6, ["&"] = 7, ["*"] = 8, ["("] = 9, [")"] = 0
            }
            local digit = shift_map[key]
            if digit ~= nil then
                -- SHIFT+digit: go back one tier
                if digit == state.last_digit and state.digit_count > 1 then
                    state.digit_count = state.digit_count - 1
                    local target = index_to_checkbox(digit, state.digit_count)
                    local total = get_checkbox_count()
                    if target <= total then
                        menu.nav_to_checkbox(target)
                    end
                elseif digit == state.last_digit and state.digit_count == 1 then
                    -- Already at tier 1, can't go back further - just stay
                elseif state.last_digit == nil then
                    -- No previous digit, treat as starting fresh at tier 1
                    state.last_digit = digit
                    state.digit_count = 1
                    local target = index_to_checkbox(digit, 1)
                    local total = get_checkbox_count()
                    if target <= total then
                        menu.nav_to_checkbox(target)
                    end
                end
            elseif state.shortcuts[key] then
                -- Custom shortcut key: jump to item, or toggle if already there
                local result = menu.handle_shortcut(key)
                if result == "action" then
                    return "run", state.values
                end
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
