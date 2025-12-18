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
    item_data = {},         -- item_id -> {label, type, value, description, config, disabled, default_value, shortcut, flag}
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
    -- Command preview configuration
    command_base = "",              -- Base command (e.g., "./script.sh")
    command_preview_item = nil,     -- item_id of the command preview text item
    command_file_section = nil,     -- section_id containing file selections
    -- Command preview inline editing state
    cmd_cursor = 0,                 -- Cursor position within command (0 = at end)
    cmd_invalid_ranges = {},        -- List of {start, end} for invalid flags to render red
    -- Input mode for command preview: "vim-nav", "insert", or "arrow"
    -- vim-nav: h/l move cursor, j/k navigate out, i/A enter insert mode
    -- insert: all printable chars insert, arrows move cursor, ESC exits
    -- arrow: arrows move cursor, vim keys insert text
    cmd_input_mode = "vim-nav",
    -- Status message to display in description area (e.g., error messages)
    status_message = nil,
    -- Track which menu items are in an invalid/conflicting state (item_id -> true)
    cmd_invalid_items = {},
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
    -- Command preview config
    state.command_base = config.command_base or ""
    state.command_preview_item = config.command_preview_item or nil
    state.command_file_section = config.command_file_section or nil
    -- Command preview inline editing init
    state.cmd_cursor = 0
    state.cmd_invalid_ranges = {}
    state.cmd_input_mode = "vim-nav"
    state.status_message = nil
    state.cmd_invalid_items = {}

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
                shortcut = item.shortcut or nil,   -- Optional keyboard shortcut
                flag = item.flag or nil            -- CLI flag (e.g., "--verbose")
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

local function is_on_command_preview()
    local item_id = get_current_item_id()
    return item_id and item_id == state.command_preview_item
end

local function get_command_text()
    if state.command_preview_item then
        return state.values[state.command_preview_item] or ""
    end
    return ""
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

-- Compute the command preview string based on current values
-- Iterates through sections in order, adding flags for enabled options
local function compute_command_preview()
    if not state.command_preview_item or state.command_base == "" then
        return nil
    end

    local parts = {state.command_base}

    -- Iterate through sections in menu order
    for _, sid in ipairs(state.sections) do
        -- Skip the file section (handled at the end) and command preview section
        if sid ~= state.command_file_section then
            local section_data = state.section_data[sid]
            for _, iid in ipairs(section_data.items) do
                local item = state.item_data[iid]
                local value = state.values[iid]
                local flag = item.flag

                -- Skip items without flags or the preview item itself
                if flag and iid ~= state.command_preview_item then
                    if item.type == "checkbox" then
                        -- Add flag if checkbox is checked
                        if value == "1" then
                            table.insert(parts, flag)
                        end
                    elseif item.type == "flag" then
                        -- Add flag with value if not default/empty
                        if value and value ~= "" and value ~= "0" then
                            table.insert(parts, flag .. " " .. value)
                        end
                    elseif item.type == "multistate" then
                        -- Add flag with current state value
                        if value and value ~= "" then
                            table.insert(parts, flag .. " " .. value)
                        end
                    end
                end
            end
        end
    end

    -- Add selected files at the end (from command_file_section)
    if state.command_file_section then
        local file_section = state.section_data[state.command_file_section]
        if file_section then
            local file_count = 0
            for _, iid in ipairs(file_section.items) do
                local item = state.item_data[iid]
                if item.type == "checkbox" and state.values[iid] == "1" then
                    file_count = file_count + 1
                end
            end
            if file_count > 0 then
                table.insert(parts, string.format("<%d files>", file_count))
            end
        end
    end

    return table.concat(parts, " ")
end

-- Build a lookup table of all known flags -> item info
-- {{{ local function build_flag_lookup
local function build_flag_lookup()
    local lookup = {}
    for _, sid in ipairs(state.sections) do
        if sid ~= state.command_file_section then
            for _, iid in ipairs(state.section_data[sid].items) do
                local item = state.item_data[iid]
                if item.flag and iid ~= state.command_preview_item then
                    lookup[item.flag] = {
                        section_id = sid,
                        item_id = iid,
                        type = item.type
                    }
                end
            end
        end
    end
    return lookup
end
-- }}}

-- Parse command text into tokens (words separated by spaces)
-- Returns: {tokens = {text, start, end}, flag_lookup = {...}}
-- {{{ local function parse_command_tokens
local function parse_command_tokens(cmd_text)
    local tokens = {}
    local pos = 1

    for word in cmd_text:gmatch("%S+") do
        local start_pos = cmd_text:find(word, pos, true)
        if start_pos then
            table.insert(tokens, {
                text = word,
                start_pos = start_pos,
                end_pos = start_pos + #word - 1
            })
            pos = start_pos + #word
        end
    end

    return tokens
end
-- }}}

-- Sync checkbox states based on parsed command
-- Returns list of invalid ranges {start, end} for flags that don't exist
-- Also updates cmd_invalid_items for conflicting radio buttons
-- {{{ local function sync_checkboxes_from_command
local function sync_checkboxes_from_command(cmd_text)
    local flag_lookup = build_flag_lookup()
    local tokens = parse_command_tokens(cmd_text)
    local invalid_ranges = {}
    local found_flags = {}  -- Track which flags were found in command
    local found_by_section = {}  -- Track which flags found per section (for conflict detection)

    -- Skip the base command (first token if it matches)
    local start_idx = 1
    if #tokens > 0 and tokens[1].text == state.command_base then
        start_idx = 2
    end

    -- Process each token as a potential flag
    for i = start_idx, #tokens do
        local token = tokens[i]
        local flag_info = flag_lookup[token.text]

        if flag_info then
            -- Valid flag found
            found_flags[flag_info.item_id] = true
            -- Track by section for conflict detection
            local sid = flag_info.section_id
            if not found_by_section[sid] then
                found_by_section[sid] = {}
            end
            table.insert(found_by_section[sid], flag_info.item_id)
        elseif not token.text:match("^<.*>$") then
            -- Not a valid flag and not a file placeholder - mark as invalid
            table.insert(invalid_ranges, {
                start_pos = token.start_pos,
                end_pos = token.end_pos
            })
        end
    end

    -- Clear previous invalid items
    state.cmd_invalid_items = {}

    -- Detect conflicts in single-select sections (radio buttons)
    -- If multiple flags from the same single-select section are present, mark all as conflicting
    for _, sid in ipairs(state.sections) do
        local section_data = state.section_data[sid]
        if section_data.type == "single" and found_by_section[sid] and #found_by_section[sid] > 1 then
            -- Conflict: multiple radio buttons selected
            for _, iid in ipairs(found_by_section[sid]) do
                state.cmd_invalid_items[iid] = true
            end
        end
    end

    -- Update checkbox states: check found flags, uncheck others
    for _, sid in ipairs(state.sections) do
        if sid ~= state.command_file_section then
            local section_data = state.section_data[sid]
            for _, iid in ipairs(section_data.items) do
                local item = state.item_data[iid]
                if item.flag and item.type == "checkbox" and iid ~= state.command_preview_item then
                    if found_flags[iid] then
                        state.values[iid] = "1"
                    else
                        state.values[iid] = "0"
                    end
                end
            end
        end
    end

    return invalid_ranges
end
-- }}}

-- Reconcile command preview with checkbox states
-- Instead of full recompute, incrementally add/remove flags to preserve other content
-- This enables true bidirectional binding between checkboxes and command text
local function reconcile_command_preview()
    if not state.command_preview_item then return end
    if is_on_command_preview() then return end

    local cmd_text = state.values[state.command_preview_item] or ""

    -- If command is empty, do a full compute
    if cmd_text == "" then
        local cmd = compute_command_preview()
        if cmd then
            state.values[state.command_preview_item] = cmd
            state.cmd_invalid_ranges = {}
        end
        return
    end

    local flag_lookup = build_flag_lookup()
    local tokens = parse_command_tokens(cmd_text)

    -- Build set of flags currently in command
    local flags_in_cmd = {}
    for _, token in ipairs(tokens) do
        if flag_lookup[token.text] then
            flags_in_cmd[token.text] = true
        end
    end

    -- Determine what flags SHOULD be in command based on checkbox states
    local flags_should_have = {}
    for _, sid in ipairs(state.sections) do
        if sid ~= state.command_file_section then
            for _, iid in ipairs(state.section_data[sid].items) do
                local item = state.item_data[iid]
                local flag = item.flag
                if flag and iid ~= state.command_preview_item then
                    if item.type == "checkbox" and state.values[iid] == "1" then
                        flags_should_have[flag] = true
                    end
                end
            end
        end
    end

    -- Find flags to add (should have but don't)
    local flags_to_add = {}
    for flag, _ in pairs(flags_should_have) do
        if not flags_in_cmd[flag] then
            table.insert(flags_to_add, flag)
        end
    end

    -- Find flags to remove (have but shouldn't)
    local flags_to_remove = {}
    for flag, _ in pairs(flags_in_cmd) do
        if not flags_should_have[flag] then
            flags_to_remove[flag] = true
        end
    end

    -- Remove flags that shouldn't be there
    -- Work backwards through tokens to preserve positions
    local new_cmd = cmd_text
    for i = #tokens, 1, -1 do
        local token = tokens[i]
        if flags_to_remove[token.text] then
            -- Remove this token (and trailing space if any)
            local before = new_cmd:sub(1, token.start_pos - 1)
            local after = new_cmd:sub(token.end_pos + 1)
            -- Trim extra space
            if before:sub(-1) == " " and (after == "" or after:sub(1, 1) == " ") then
                before = before:sub(1, -2)
            elseif after:sub(1, 1) == " " then
                after = after:sub(2)
            end
            new_cmd = before .. after
        end
    end

    -- Add flags that should be there (insert after base command)
    if #flags_to_add > 0 then
        -- Find position after base command
        local insert_pos = #state.command_base + 1
        if new_cmd:sub(insert_pos, insert_pos) == " " then
            insert_pos = insert_pos + 1
        end
        local flags_str = table.concat(flags_to_add, " ")
        local before = new_cmd:sub(1, insert_pos - 1)
        local after = new_cmd:sub(insert_pos)
        -- Add space if needed
        if before ~= "" and before:sub(-1) ~= " " then
            before = before .. " "
        end
        if after ~= "" and after:sub(1, 1) ~= " " then
            flags_str = flags_str .. " "
        end
        new_cmd = before .. flags_str .. after
    end

    -- Update command and re-validate
    if new_cmd ~= cmd_text then
        state.values[state.command_preview_item] = new_cmd
        state.cmd_invalid_ranges = sync_checkboxes_from_command(new_cmd)
    end
end

-- Update the command preview (alias for reconcile for backward compatibility)
local function update_command_preview()
    reconcile_command_preview()
end

-- Get the start and end positions of the <N files> placeholder in command text
-- Returns start_pos, end_pos or nil if not found
local function get_file_placeholder_range(cmd_text)
    local start_pos, end_pos = cmd_text:find("<%d+ files>")
    return start_pos, end_pos
end

-- Get list of selected file labels from the file section
local function get_selected_files()
    local files = {}
    if state.command_file_section then
        local file_section = state.section_data[state.command_file_section]
        if file_section then
            for _, iid in ipairs(file_section.items) do
                local item = state.item_data[iid]
                if item.type == "checkbox" and state.values[iid] == "1" then
                    table.insert(files, item.label)
                end
            end
        end
    end
    return files
end

-- Expand the <N files> placeholder in command text to show actual files
-- Format: space-separated with shell escaping for safe copy-paste
local function expand_files_in_command()
    local cmd_text = get_command_text()
    local start_pos, end_pos = get_file_placeholder_range(cmd_text)
    if not start_pos then return false end

    local files = get_selected_files()
    if #files == 0 then return false end

    -- Build file list with shell escaping
    local file_parts = {}
    for _, file in ipairs(files) do
        -- Escape special shell characters in filename
        local escaped = file:gsub("([%s'\"\\$`!#&*?|<>(){}%[%];])", "\\%1")
        table.insert(file_parts, escaped)
    end

    -- Join with spaces (single-line for TUI display)
    local files_str = table.concat(file_parts, " ")

    -- Replace placeholder with expanded files
    local before = cmd_text:sub(1, start_pos - 1)
    local after = cmd_text:sub(end_pos + 1)
    local new_text = before .. files_str .. after

    state.values[state.command_preview_item] = new_text
    -- Update cursor to after the expanded section
    state.cmd_cursor = start_pos + #files_str

    -- Re-sync checkboxes (files aren't flags, so this should work fine)
    state.cmd_invalid_ranges = sync_checkboxes_from_command(new_text)

    return true
end

-- Check if there are any invalid states (invalid flags in command or conflicting menu items)
local function has_invalid_state()
    -- Check for invalid ranges in command text
    if #state.cmd_invalid_ranges > 0 then
        return true
    end
    -- Check for conflicting/invalid menu items
    for _, _ in pairs(state.cmd_invalid_items) do
        return true
    end
    return false
end

-- Check if cursor position is within the <N files> placeholder
local function is_cursor_in_file_placeholder()
    local cmd_text = get_command_text()
    local start_pos, end_pos = get_file_placeholder_range(cmd_text)
    if not start_pos then return false end

    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #cmd_text + 1 end

    return cursor >= start_pos and cursor <= end_pos + 1
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
    local is_invalid = state.cmd_invalid_items[item_id]  -- Item is in conflicting/invalid state

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
    -- Invalid/conflicting items are shown in red
    tui.reset_style()
    if item_type == "checkbox" then
        if disabled then
            tui.set_attrs(tui.ATTR_DIM)
            tui.write_str(row, col, is_radio and "(o)" or "[o]")
        elseif is_invalid then
            -- Conflicting/invalid state - show in red
            tui.set_fg(tui.FG_RED)
            tui.set_attrs(tui.ATTR_BOLD)
            tui.write_str(row, col, is_radio and "(!)" or "[!]")
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
    if is_invalid then
        -- Conflicting/invalid state - show label in red
        tui.set_fg(tui.FG_RED)
        if highlight then
            tui.set_attrs(tui.ATTR_INVERSE)
        end
    elseif highlight then
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
    elseif item_type == "text" then
        -- Text items display content (like command preview)
        -- When highlighted and is command preview, show with cursor for inline editing
        local max_len = state.cols - col - 2
        local display_val = value
        local is_cmd_preview = (item_id == state.command_preview_item)

        if highlight and is_cmd_preview then
            -- Inline editing mode: show with cursor and red invalid flags
            local truncated = false

            if #display_val > max_len then
                display_val = display_val:sub(1, max_len - 3)
                truncated = true
            end

            -- Render character by character to support coloring and cursor
            local char_col = col
            for i = 1, #display_val do
                local c = display_val:sub(i, i)
                local in_invalid = false

                -- Check if this position is in an invalid range
                for _, range in ipairs(state.cmd_invalid_ranges) do
                    if i >= range.start_pos and i <= range.end_pos then
                        in_invalid = true
                        break
                    end
                end

                -- Set color
                tui.reset_style()
                if in_invalid then
                    tui.set_fg(tui.FG_RED)
                    tui.set_attrs(tui.ATTR_BOLD)
                else
                    tui.set_fg(tui.FG_CYAN)
                end

                -- Show cursor (inverse video at cursor position)
                if i == state.cmd_cursor then
                    tui.set_attrs(tui.ATTR_INVERSE)
                end

                tui.write_str(row, char_col, c)
                char_col = char_col + 1
            end

            -- Show cursor at end if cursor is past last character
            if state.cmd_cursor > #display_val or state.cmd_cursor == 0 then
                tui.reset_style()
                tui.set_attrs(tui.ATTR_INVERSE)
                tui.write_str(row, char_col, " ")
                char_col = char_col + 1
            end

            if truncated then
                tui.reset_style()
                tui.set_attrs(tui.ATTR_DIM)
                tui.write_str(row, char_col, "...")
            end
        else
            -- Normal display mode
            tui.set_attrs(tui.ATTR_DIM)
            tui.set_fg(tui.FG_CYAN)
            if #display_val > max_len then
                display_val = display_val:sub(1, max_len - 3) .. "..."
            end
            tui.write_str(row, col, display_val)
        end
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

    -- Show status message if set (e.g., error messages), otherwise show item description
    if state.status_message then
        tui.set_fg(tui.FG_RED)
        tui.set_attrs(tui.ATTR_BOLD)
        local max_len = state.cols - 4
        local msg = state.status_message
        if #msg > max_len then
            msg = msg:sub(1, max_len - 3) .. "..."
        end
        tui.write_str(row, 3, msg)
        tui.reset_style()
    else
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

    -- Build base help text - show different help when on command preview
    local base_help
    local on_cmd = is_on_command_preview()
    if on_cmd then
        if state.cmd_input_mode == "vim-nav" then
            base_help = "h/l:cursor  j/k:nav  i:insert  A:append  ENTER:run  q:quit"
        elseif state.cmd_input_mode == "insert" then
            base_help = "-- INSERT --  arrows:move  type:edit  ESC:exit  ENTER:run"
        else  -- arrow mode
            base_help = "arrows:cursor  type:edit  ENTER:run  q:quit"
        end
    else
        base_help = "j/k:nav  space:toggle  `:action  q:quit"
    end
    local has_shortcuts = #shortcuts_parts > 0 and not on_cmd

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
    -- Update command preview before rendering
    update_command_preview()

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

-- {{{ menu.cycle_radio_prev
-- Cycle to previous radio button in the current section (with looping)
-- Does not move cursor, just changes which option is selected
function menu.cycle_radio_prev()
    local section_type = get_current_section_type()
    if section_type ~= "single" then return false end

    local sid = state.sections[state.current_section]
    local items = state.section_data[sid].items

    -- Find which checkbox items exist and which is currently selected
    local checkbox_items = {}
    local selected_idx = nil
    for i, iid in ipairs(items) do
        if state.item_data[iid].type == "checkbox" and not state.item_data[iid].disabled then
            table.insert(checkbox_items, iid)
            if state.values[iid] == "1" then
                selected_idx = #checkbox_items
            end
        end
    end

    if #checkbox_items == 0 then return false end
    if not selected_idx then selected_idx = 1 end

    -- Calculate previous index with looping
    local new_idx = selected_idx - 1
    if new_idx < 1 then new_idx = #checkbox_items end

    -- Unselect current, select new
    for i, iid in ipairs(checkbox_items) do
        state.values[iid] = (i == new_idx) and "1" or "0"
    end

    menu.render()
    return true
end
-- }}}

-- {{{ menu.cycle_radio_next
-- Cycle to next radio button in the current section (with looping)
-- Does not move cursor, just changes which option is selected
function menu.cycle_radio_next()
    local section_type = get_current_section_type()
    if section_type ~= "single" then return false end

    local sid = state.sections[state.current_section]
    local items = state.section_data[sid].items

    -- Find which checkbox items exist and which is currently selected
    local checkbox_items = {}
    local selected_idx = nil
    for i, iid in ipairs(items) do
        if state.item_data[iid].type == "checkbox" and not state.item_data[iid].disabled then
            table.insert(checkbox_items, iid)
            if state.values[iid] == "1" then
                selected_idx = #checkbox_items
            end
        end
    end

    if #checkbox_items == 0 then return false end
    if not selected_idx then selected_idx = 1 end

    -- Calculate next index with looping
    local new_idx = (selected_idx % #checkbox_items) + 1

    -- Unselect current, select new
    for i, iid in ipairs(checkbox_items) do
        state.values[iid] = (i == new_idx) and "1" or "0"
    end

    menu.render()
    return true
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

-- {{{ Command preview inline editing functions
-- These work directly on the command preview value when cursor is on that item

-- {{{ menu.cmd_insert_char
-- Insert a character at cursor position in command preview
-- If cursor is within <N files> placeholder, expand files instead
function menu.cmd_insert_char(char)
    if not is_on_command_preview() then return false end

    -- Check if cursor is within file placeholder - expand instead of insert
    if is_cursor_in_file_placeholder() then
        if expand_files_in_command() then
            menu.render()
            return true
        end
    end

    local text = get_command_text()
    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #text + 1 end

    -- Insert character at cursor position
    local before = text:sub(1, cursor - 1)
    local after = text:sub(cursor)
    local new_text = before .. char .. after
    state.values[state.command_preview_item] = new_text
    state.cmd_cursor = cursor + 1

    -- Re-sync checkboxes and detect invalid flags
    state.cmd_invalid_ranges = sync_checkboxes_from_command(new_text)

    menu.render()
    return true
end
-- }}}

-- {{{ menu.cmd_backspace
-- Delete character before cursor in command preview
-- If cursor is within <N files> placeholder, expand files instead
function menu.cmd_backspace()
    if not is_on_command_preview() then return false end

    -- Check if cursor is within file placeholder - expand instead of delete
    if is_cursor_in_file_placeholder() then
        if expand_files_in_command() then
            menu.render()
            return true
        end
    end

    local text = get_command_text()
    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #text + 1 end
    if cursor <= 1 then return false end

    local before = text:sub(1, cursor - 2)
    local after = text:sub(cursor)
    local new_text = before .. after
    state.values[state.command_preview_item] = new_text
    state.cmd_cursor = cursor - 1

    -- Re-sync checkboxes and detect invalid flags
    state.cmd_invalid_ranges = sync_checkboxes_from_command(new_text)

    menu.render()
    return true
end
-- }}}

-- {{{ menu.cmd_delete
-- Delete character at cursor in command preview
-- If cursor is within <N files> placeholder, expand files instead
function menu.cmd_delete()
    if not is_on_command_preview() then return false end

    -- Check if cursor is within file placeholder - expand instead of delete
    if is_cursor_in_file_placeholder() then
        if expand_files_in_command() then
            menu.render()
            return true
        end
    end

    local text = get_command_text()
    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #text + 1 end
    if cursor > #text then return false end

    local before = text:sub(1, cursor - 1)
    local after = text:sub(cursor + 1)
    local new_text = before .. after
    state.values[state.command_preview_item] = new_text

    -- Re-sync checkboxes and detect invalid flags
    state.cmd_invalid_ranges = sync_checkboxes_from_command(new_text)

    menu.render()
    return true
end
-- }}}

-- {{{ menu.cmd_cursor_left
-- Move cursor left in command preview
function menu.cmd_cursor_left()
    if not is_on_command_preview() then return false end

    local text = get_command_text()
    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #text + 1 end

    if cursor > 1 then
        state.cmd_cursor = cursor - 1
        menu.render()
    end
    return true
end
-- }}}

-- {{{ menu.cmd_cursor_right
-- Move cursor right in command preview
function menu.cmd_cursor_right()
    if not is_on_command_preview() then return false end

    local text = get_command_text()
    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #text + 1 end

    if cursor <= #text then
        state.cmd_cursor = cursor + 1
        menu.render()
    end
    return true
end
-- }}}

-- {{{ menu.cmd_cursor_start
-- Move cursor to beginning of command
function menu.cmd_cursor_start()
    if not is_on_command_preview() then return false end
    state.cmd_cursor = 1
    menu.render()
    return true
end
-- }}}

-- {{{ menu.cmd_cursor_end
-- Move cursor to end of command
function menu.cmd_cursor_end()
    if not is_on_command_preview() then return false end
    local text = get_command_text()
    state.cmd_cursor = #text + 1
    menu.render()
    return true
end
-- }}}

-- {{{ menu.cmd_is_cursor_at_start
-- Check if cursor is at start of command
function menu.cmd_is_cursor_at_start()
    local cursor = state.cmd_cursor
    return cursor == 0 or cursor == 1
end
-- }}}

-- {{{ menu.cmd_is_cursor_at_end
-- Check if cursor is at end of command
function menu.cmd_is_cursor_at_end()
    local text = get_command_text()
    local cursor = state.cmd_cursor
    return cursor == 0 or cursor > #text
end
-- }}}

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
    local section_type = get_current_section_type()

    if data.type == "flag" then
        return menu.handle_flag_left()
    elseif data.type == "checkbox" then
        if section_type == "single" then
            -- Radio buttons: cycle to previous option
            return menu.cycle_radio_prev()
        else
            -- Regular checkboxes: uncheck
            return menu.unset_checkbox()
        end
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
    local section_type = get_current_section_type()

    if data.type == "flag" then
        return menu.handle_flag_right()
    elseif data.type == "checkbox" then
        if section_type == "single" then
            -- Radio buttons: cycle to next option
            return menu.cycle_radio_next()
        else
            -- Regular checkboxes: check
            return menu.set_checkbox()
        end
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
    -- DEBUG: Write state to file (won't interfere with TUI)
    local dbg = io.open("/tmp/menu_debug.log", "w")
    if dbg then
        dbg:write("command_base: '" .. tostring(state.command_base) .. "'\n")
        dbg:write("command_preview_item: '" .. tostring(state.command_preview_item) .. "'\n")
        dbg:write("command_file_section: '" .. tostring(state.command_file_section) .. "'\n")
        dbg:write("initial cmd_preview value: '" .. tostring(state.values[state.command_preview_item]) .. "'\n")
        dbg:write("sections: " .. table.concat(state.sections, ", ") .. "\n")
        dbg:close()
    end

    menu.render()

    while true do
        local key = tui.read_key()

        -- Handle nil key (EOF or read error)
        if not key then
            return "quit", state.values
        end

        -- Clear status message on any keypress (it will be re-set if needed)
        state.status_message = nil

        -- Check if we're on the command preview item
        local on_cmd_preview = is_on_command_preview()

        -- === Command preview with modal editing ===
        if on_cmd_preview then
            local mode = state.cmd_input_mode

            -- Global quit (q only in vim-nav mode, always for Q/Ctrl+C)
            if key == "Q" or key == "CTRL_C" then
                return "quit", state.values
            end
            if key == "q" and mode == "vim-nav" then
                return "quit", state.values
            end

            -- Mode-specific handling
            if mode == "vim-nav" then
                -- === VIM-NAV MODE ===
                -- h/l move cursor, j/k navigate out, i enters insert, A appends
                -- ENTER navigates to action item (run option)

                if key == "ENTER" then
                    -- Navigate to the Run action item
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    menu.nav_to_action()
                elseif key == "h" then
                    menu.cmd_cursor_left()
                elseif key == "l" then
                    menu.cmd_cursor_right()
                elseif key == "j" then
                    -- Navigate down, reset mode for next time
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    menu.nav_down()
                elseif key == "k" then
                    -- Navigate up, reset mode for next time
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    menu.nav_up()
                elseif key == "i" then
                    -- Enter insert mode at current cursor position
                    -- If cursor is in file placeholder, expand it first
                    if is_cursor_in_file_placeholder() then
                        expand_files_in_command()
                    end
                    state.cmd_input_mode = "insert"
                    menu.render()
                elseif key == "A" then
                    -- Enter insert mode at end of line (append)
                    menu.cmd_cursor_end()
                    -- If cursor is now in/at file placeholder, expand it first
                    if is_cursor_in_file_placeholder() then
                        expand_files_in_command()
                    end
                    state.cmd_input_mode = "insert"
                    menu.render()
                elseif key == "0" then
                    -- Go to start of line (vim)
                    menu.cmd_cursor_start()
                elseif key == "$" then
                    -- Go to end of line (vim)
                    menu.cmd_cursor_end()
                elseif key == "LEFT" or key == "RIGHT" or key == "UP" or key == "DOWN" then
                    -- Arrow keys switch to arrow mode
                    state.cmd_input_mode = "arrow"
                    if key == "LEFT" then
                        menu.cmd_cursor_left()
                    elseif key == "RIGHT" then
                        menu.cmd_cursor_right()
                    elseif key == "UP" then
                        state.cmd_cursor = 0
                        state.cmd_input_mode = "vim-nav"
                        menu.nav_up()
                    elseif key == "DOWN" then
                        state.cmd_cursor = 0
                        state.cmd_input_mode = "vim-nav"
                        menu.nav_down()
                    end
                elseif key == "HOME" or key == "CTRL_A" then
                    menu.cmd_cursor_start()
                elseif key == "END" or key == "CTRL_E" then
                    menu.cmd_cursor_end()
                elseif key == "`" or key == "~" then
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    menu.nav_to_action()
                elseif key == "x" then
                    -- Delete char at cursor (vim x)
                    menu.cmd_delete()
                elseif key == "BACKSPACE" or key == "DELETE" then
                    menu.cmd_backspace()
                end
                -- Other keys ignored in vim-nav mode

            elseif mode == "insert" then
                -- === INSERT MODE ===
                -- All printable chars insert, arrows move cursor, ESC exits

                if key == "ENTER" then
                    -- Navigate to the Run action item
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    menu.nav_to_action()
                elseif key == "ESCAPE" then
                    -- Exit insert mode back to vim-nav
                    state.cmd_input_mode = "vim-nav"
                    menu.render()
                elseif key == "LEFT" then
                    menu.cmd_cursor_left()
                elseif key == "RIGHT" then
                    menu.cmd_cursor_right()
                elseif key == "UP" then
                    -- Navigate up, exit insert mode
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    menu.nav_up()
                elseif key == "DOWN" then
                    -- Navigate down, exit insert mode
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    menu.nav_down()
                elseif key == "HOME" or key == "CTRL_A" then
                    menu.cmd_cursor_start()
                elseif key == "END" or key == "CTRL_E" then
                    menu.cmd_cursor_end()
                elseif key == "BACKSPACE" then
                    menu.cmd_backspace()
                elseif key == "DELETE" then
                    menu.cmd_delete()
                elseif type(key) == "string" and #key == 1 and key:byte() >= 32 and key:byte() <= 126 then
                    -- Insert printable character (including h/j/k/l)
                    menu.cmd_insert_char(key)
                end

            else  -- mode == "arrow"
                -- === ARROW MODE ===
                -- Arrows move cursor, vim keys (and other printable) insert text

                if key == "ENTER" then
                    -- Navigate to the Run action item
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    menu.nav_to_action()
                elseif key == "LEFT" then
                    menu.cmd_cursor_left()
                elseif key == "RIGHT" then
                    menu.cmd_cursor_right()
                elseif key == "UP" then
                    -- Navigate up, reset to vim-nav
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    menu.nav_up()
                elseif key == "DOWN" then
                    -- Navigate down, reset to vim-nav
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    menu.nav_down()
                elseif key == "HOME" or key == "CTRL_A" then
                    menu.cmd_cursor_start()
                elseif key == "END" or key == "CTRL_E" then
                    menu.cmd_cursor_end()
                elseif key == "BACKSPACE" then
                    menu.cmd_backspace()
                elseif key == "DELETE" then
                    menu.cmd_delete()
                elseif key == "ESCAPE" then
                    -- ESC resets to vim-nav mode
                    state.cmd_input_mode = "vim-nav"
                    menu.render()
                elseif type(key) == "string" and #key == 1 and key:byte() >= 32 and key:byte() <= 126 then
                    -- Insert printable character (including h/j/k/l/q)
                    menu.cmd_insert_char(key)
                end
            end

        else
            -- === Normal menu mode (not on command preview) ===

            -- Reset command input mode when we leave the command preview
            state.cmd_input_mode = "vim-nav"

            -- Global quit keys
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
                    -- Check for invalid states before allowing run
                    if has_invalid_state() then
                        state.status_message = "Invalid options! Please fix the conflicts before running."
                        menu.render()
                    else
                        return "run", state.values
                    end
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
        end  -- end of normal mode
    end  -- end of while loop
end
-- }}}

-- {{{ menu.cleanup
function menu.cleanup()
    tui.cleanup()
end
-- }}}

return menu
