-- menu.lua - Interactive menu component using framebuffer TUI
-- Provides multi-section menus with vim keybindings, checkbox/flag/multistate items.
-- LuaJIT compatible. All rendering goes through the TUI framebuffer for clean updates.

local tui = require("tui")
local bit = require("bit")

-- {{{ Menu module
local menu = {}

-- Forward declaration for dependency update function
local update_disabled_states

-- Menu state
local state = {
    title = "",
    subtitle = "",
    sections = {},          -- Ordered list of section IDs
    section_data = {},      -- section_id -> {title, type, items}
    item_data = {},         -- item_id -> {label, type, value, description, config, disabled, default_value, shortcut, flag, filepath}
    values = {},            -- item_id -> current value
    shortcuts = {},         -- key -> item_id (custom shortcut keys)
    dependencies = {},      -- item_id -> {depends_on, required_values, invert, reason, color}
    disabled_reasons = {},  -- item_id -> {reason=string, color=string} when disabled by dependency
    prerequisites = {},     -- item_id -> {prerequisite_id, ...} - auto-enable prereqs when selected
    suggested_deps = {},    -- item_id -> {depends_on, required_values, reason} - yellow highlight
    flash_items = {},       -- item_id -> color - currently flashing items
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
    -- Content sources for preview panel - array of {type, label, content}
    -- Types: "text" (static), "file" (read from path), "item_file" (use current item's filepath)
    -- The last source gets remaining available space
    content_sources = {},
    -- Content panel scrolling state
    content_scroll_offset = 0,
    content_total_lines = 0,
    content_cached_lines = nil,
    content_cached_filepath = nil,
    content_visible_lines = 0,
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
    state.dependencies = {}
    state.disabled_reasons = {}
    state.prerequisites = {}
    state.suggested_deps = {}
    state.flash_items = {}
    state.current_section = 1
    state.current_item = 1
    state.flag_edit_started = {}
    state.last_digit = nil
    state.digit_count = 0
    -- Command preview config
    state.command_base = config.command_base or ""
    state.command_base_absolute = config.command_base_absolute or config.command_base or ""  -- Absolute path version
    state.command_preview_item = config.command_preview_item or nil
    state.command_file_section = config.command_file_section or nil
    -- Command preview inline editing init
    state.cmd_cursor = 0
    state.cmd_invalid_ranges = {}
    state.cmd_input_mode = "vim-nav"
    state.status_message = nil
    state.cmd_invalid_items = {}
    state.cmd_was_on_preview = false  -- Track when leaving command preview to sync checkboxes
    state.cmd_on_placeholder = false  -- Track when cursor is on the <N files> placeholder
    state.cmd_files_expanded = false  -- Track when files are expanded in command preview
    -- Content sources for preview panel
    state.content_sources = config.content_sources or {}
    -- Content panel scrolling state
    state.content_scroll_offset = 0
    state.content_total_lines = 0
    state.content_cached_lines = nil  -- Cache file content to avoid re-reading
    state.content_cached_filepath = nil  -- Track which file is cached
    state.content_visible_lines = 0  -- How many lines are visible

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
                flag = item.flag or nil,           -- CLI flag (e.g., "--verbose")
                filepath = item.filepath or nil    -- Optional file path for preview
            }
            state.values[iid] = item.value or (item.type == "checkbox" and "0" or "")

            -- Build shortcuts lookup table
            if item.shortcut and #item.shortcut == 1 then
                state.shortcuts[item.shortcut] = iid
            end
        end
    end

    -- Process dependencies from config
    for _, dep in ipairs(config.dependencies or {}) do
        local item_id = dep.item_id
        if state.item_data[item_id] then
            if dep.multi then
                -- Multi-dependency: enabled if ANY condition matches
                state.dependencies[item_id] = {
                    multi = true,
                    depends_on_list = dep.depends_on_list or {},
                    invert = dep.invert or false,
                    reason = dep.reason or nil,
                    color = dep.color or "yellow"
                }
            else
                -- Single dependency
                state.dependencies[item_id] = {
                    depends_on = dep.depends_on,
                    required_values = dep.required_values or {"1"},
                    invert = dep.invert or false,
                    reason = dep.reason or nil,
                    color = dep.color or "yellow"
                }
            end
        end
    end

    -- Process prerequisites from config
    -- Prerequisites: when item_id is selected, prerequisite_id auto-enables with flash
    for _, prereq in ipairs(config.prerequisites or {}) do
        local item_id = prereq.item_id
        local prereq_id = prereq.prerequisite_id
        if state.item_data[item_id] and state.item_data[prereq_id] then
            state.prerequisites = state.prerequisites or {}
            state.prerequisites[item_id] = state.prerequisites[item_id] or {}
            table.insert(state.prerequisites[item_id], prereq_id)
        end
    end

    -- Process suggested dependencies from config
    -- Suggested deps: show yellow highlight when trigger is active but item not selected
    for _, suggest in ipairs(config.suggested_deps or {}) do
        local item_id = suggest.item_id
        if state.item_data[item_id] then
            state.suggested_deps = state.suggested_deps or {}
            state.suggested_deps[item_id] = {
                depends_on = suggest.depends_on,
                required_values = suggest.required_values or {"1"},
                reason = suggest.reason or nil
            }
        end
    end

    -- Initialize TUI
    state.rows, state.cols = tui.init()

    -- Apply initial dependency states after TUI init
    update_disabled_states()
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

-- {{{ parse_flag_value
-- Parses a flag value that may be in "value:width" format
-- Returns: display_value, width (or nil if no width specified)
-- Examples:
--   "3:2" -> "3", 2
--   "100:4" -> "100", 4
--   "hello" -> "hello", nil
--   "" -> "", nil
local function parse_flag_value(flag_str)
    if not flag_str or flag_str == "" then
        return "", nil
    end
    -- Match pattern: everything before the last colon, followed by digits
    local value, width_str = string.match(flag_str, "^(.+):(%d+)$")
    if value and width_str then
        return value, tonumber(width_str)
    end
    -- No width suffix found, return original value
    return flag_str, nil
end
-- }}}

-- {{{ read_file_lines
-- Read first N lines from a file, returns array of lines
-- Returns empty array if file doesn't exist or can't be read
local function read_file_lines(filepath, max_lines)
    max_lines = max_lines or 10
    local lines = {}
    local file = io.open(filepath, "r")
    if not file then return lines end

    local count = 0
    for line in file:lines() do
        count = count + 1
        if count > max_lines then break end
        -- Truncate very long lines
        if #line > 200 then
            line = line:sub(1, 197) .. "..."
        end
        table.insert(lines, line)
    end
    file:close()
    return lines
end
-- }}}

-- {{{ get_cached_file_content
-- Read all lines from a file with caching for scrolling
-- Returns cached lines if same filepath, otherwise reads and caches
-- Caps at 1000 lines to avoid memory issues
local function get_cached_file_content(filepath)
    local max_lines = 1000

    -- Return cached if same file
    if state.content_cached_filepath == filepath and state.content_cached_lines then
        return state.content_cached_lines
    end

    -- Read new file
    local lines = {}
    local file = io.open(filepath, "r")
    if not file then
        state.content_cached_lines = lines
        state.content_cached_filepath = filepath
        state.content_total_lines = 0
        return lines
    end

    local count = 0
    for line in file:lines() do
        count = count + 1
        if count > max_lines then break end
        -- Truncate very long lines
        if #line > 200 then
            line = line:sub(1, 197) .. "..."
        end
        table.insert(lines, line)
    end
    file:close()

    -- Cache and update state
    state.content_cached_lines = lines
    state.content_cached_filepath = filepath
    state.content_total_lines = #lines
    state.content_scroll_offset = 0  -- Reset scroll when file changes

    return lines
end
-- }}}

-- {{{ render_scrollbar
-- Render a vertical scrollbar in the rightmost column
-- Returns nothing, draws directly to framebuffer
local function render_scrollbar(start_row, height, total_items, visible_start, visible_count)
    if total_items <= visible_count then return end  -- No scrollbar needed

    local scroll_col = state.cols - 1

    -- Calculate scrollbar thumb position and size
    local thumb_size = math.max(1, math.floor(visible_count / total_items * height))
    local thumb_pos = math.floor(visible_start / total_items * height)

    -- Ensure thumb doesn't go past end
    if thumb_pos + thumb_size > height then
        thumb_pos = height - thumb_size
    end

    tui.reset_style()
    tui.set_fg(tui.FG_WHITE)
    tui.set_attrs(tui.ATTR_DIM)

    for i = 0, height - 1 do
        local row = start_row + i
        local char
        if i >= thumb_pos and i < thumb_pos + thumb_size then
            char = "█"  -- Thumb (filled)
        else
            char = "░"  -- Track (empty)
        end
        tui.write_str(row, scroll_col, char)
    end

    tui.reset_style()
end
-- }}}

-- {{{ get_current_item_filepath
-- Get the filepath associated with the currently selected item
local function get_current_item_filepath()
    local item_id = get_current_item_id()
    if not item_id then return nil end
    local data = state.item_data[item_id]
    if data and data.filepath then
        return data.filepath
    end
    return nil
end
-- }}}

-- {{{ update_disabled_states
-- Check all dependencies and update disabled flags accordingly
-- Called after any value change to keep dependent items in sync
-- Also tracks the reason for disabling (shown in description area)
update_disabled_states = function()
    for item_id, dep in pairs(state.dependencies) do
        local satisfied = false

        if dep.multi then
            -- Multi-dependency: enabled if ANY of the conditions match
            for _, condition in ipairs(dep.depends_on_list or {}) do
                local depends_on = condition[1]
                local required_values = condition[2] or {"1"}
                local dep_value = state.values[depends_on]

                for _, req_val in ipairs(required_values) do
                    if dep_value == req_val then
                        satisfied = true
                        break
                    end
                end
                if satisfied then break end
            end
        else
            -- Single dependency
            local depends_on = dep.depends_on
            local required_values = dep.required_values or {}
            local dep_value = state.values[depends_on]

            for _, req_val in ipairs(required_values) do
                if dep_value == req_val then
                    satisfied = true
                    break
                end
            end
        end

        -- Invert if requested (e.g., "enable when X is NOT selected")
        if dep.invert then
            satisfied = not satisfied
        end

        -- Update disabled state and reason
        if state.item_data[item_id] then
            local was_disabled = state.item_data[item_id].disabled
            state.item_data[item_id].disabled = not satisfied

            -- Track reason for disabling (cleared when enabled)
            if not satisfied and dep.reason then
                state.disabled_reasons[item_id] = {
                    reason = dep.reason,
                    color = dep.color or "yellow"
                }
            else
                state.disabled_reasons[item_id] = nil
            end
        end
    end
end
-- }}}

-- {{{ get_suggested_state
-- Check if an item is in "suggested" state (yellow highlight when not yet selected)
-- Returns true if the item should be highlighted yellow as a suggestion
local function get_suggested_state(item_id)
    if not state.suggested_deps or not state.suggested_deps[item_id] then
        return false
    end

    local dep = state.suggested_deps[item_id]
    local dep_value = state.values[dep.depends_on]

    -- Check if trigger condition is met
    local triggered = false
    for _, req_val in ipairs(dep.required_values) do
        if dep_value == req_val then
            triggered = true
            break
        end
    end

    -- Only suggest if triggered AND item is not yet selected
    return triggered and state.values[item_id] ~= "1"
end
-- }}}

-- {{{ get_blocker_color_for_item
-- Check if an item is blocking the currently selected disabled item
-- Returns the color if it's a blocker, nil otherwise
--
-- An item is considered a "blocker" if:
-- - The current item is disabled due to a dependency
-- - This item is part of the dependency (in depends_on or depends_on_list)
-- - This item's current value is contributing to the disabled state
local function get_blocker_color_for_item(item_id)
    local current_id = get_current_item_id()
    if not current_id then return nil end

    -- Only highlight blockers when the current item is disabled
    local reason_info = state.disabled_reasons[current_id]
    if not reason_info then return nil end

    local dep = state.dependencies[current_id]
    if not dep then return nil end

    local color = reason_info.color

    if dep.multi then
        -- Multi-dependency (OR logic): enabled if ANY condition matches
        -- When disabled (invert=false): none of the conditions match, so highlight all
        -- When disabled (invert=true): at least one condition matches, highlight the matching ones
        for _, condition in ipairs(dep.depends_on_list or {}) do
            local depends_on = condition[1]
            if depends_on == item_id then
                local required_values = condition[2] or {"1"}
                local item_value = state.values[item_id]

                -- Check if this item matches its required value
                local matches = false
                for _, req_val in ipairs(required_values) do
                    if item_value == req_val then
                        matches = true
                        break
                    end
                end

                if dep.invert then
                    -- invert=true: disabled when ANY matches, so highlight matching items
                    if matches then return color end
                else
                    -- invert=false: disabled when NONE match, so highlight all dependency items
                    -- (they're all potential "unblockers")
                    return color
                end
            end
        end
    else
        -- Single dependency: simple check
        if dep.depends_on == item_id then
            return color
        end
    end

    return nil
end
-- }}}

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

                -- Skip items without flags, disabled items, or the preview item itself
                -- Disabled items (due to dependencies) should not add their flags
                if flag and iid ~= state.command_preview_item and not item.disabled then
                    if item.type == "checkbox" then
                        -- Add flag if checkbox is checked
                        if value == "1" then
                            table.insert(parts, flag)
                        end
                    elseif item.type == "flag" then
                        -- Add flag with value if not default/empty
                        -- Parse value:width format to extract just the value
                        local display_value = parse_flag_value(value)
                        if display_value and display_value ~= "" and display_value ~= "0" then
                            table.insert(parts, flag .. " " .. display_value)
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
                table.insert(parts, string.format("<%d-files>", file_count))
            end
        end
    end

    return table.concat(parts, " ")
end

-- Build a lookup table of all known flags -> item info
-- Includes section_type to distinguish radio buttons from checkboxes
-- {{{ local function build_flag_lookup
local function build_flag_lookup()
    local lookup = {}
    for _, sid in ipairs(state.sections) do
        if sid ~= state.command_file_section then
            local section_type = state.section_data[sid].type
            for _, iid in ipairs(state.section_data[sid].items) do
                local item = state.item_data[iid]
                if item.flag and iid ~= state.command_preview_item then
                    lookup[item.flag] = {
                        section_id = sid,
                        item_id = iid,
                        type = item.type,
                        is_radio = (section_type == "single")  -- true for radio buttons
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

-- Sync checkbox and flag states based on parsed command
-- Returns list of invalid ranges {start, end} for flags that don't exist
-- Also updates cmd_invalid_items for conflicting radio buttons
-- Also updates flag item values (e.g., --parallel 3 updates the parallel field to 3)
-- {{{ local function sync_checkboxes_from_command
local function sync_checkboxes_from_command(cmd_text)
    local flag_lookup = build_flag_lookup()
    local tokens = parse_command_tokens(cmd_text)
    local invalid_ranges = {}
    local found_flags = {}  -- Track which flags were found in command
    local found_by_section = {}  -- Track which flags found per section (for conflict detection)
    local flag_values = {}  -- Track flag values (for flag-type items like --parallel 3)

    -- Skip the base command (first token if it matches)
    local start_idx = 1
    if #tokens > 0 then
        -- Match base command (could be relative or absolute path)
        local base = tokens[1].text
        if base == state.command_base or base == state.command_base_absolute then
            start_idx = 2
        end
    end

    -- Process each token as a potential flag
    local i = start_idx
    while i <= #tokens do
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

            -- For flag-type items, the next token is the value
            local item = state.item_data[flag_info.item_id]
            if item and item.type == "flag" and i < #tokens then
                local next_token = tokens[i + 1]
                -- Check that next token isn't another flag
                if not flag_lookup[next_token.text] and not next_token.text:match("^<.*>$") then
                    flag_values[flag_info.item_id] = next_token.text
                    i = i + 1  -- Skip the value token
                end
            end
        elseif not token.text:match("^<.*>$") then
            -- Check if this might be a flag value (follows a flag)
            -- If not preceded by a flag, mark as invalid
            local is_flag_value = false
            if i > start_idx then
                local prev_token = tokens[i - 1]
                local prev_flag_info = flag_lookup[prev_token.text]
                if prev_flag_info and state.item_data[prev_flag_info.item_id].type == "flag" then
                    is_flag_value = true
                end
            end
            if not is_flag_value then
                table.insert(invalid_ranges, {
                    start_pos = token.start_pos,
                    end_pos = token.end_pos
                })
            end
        end
        i = i + 1
    end

    -- Update flag item values for found flags
    for item_id, value in pairs(flag_values) do
        state.values[item_id] = value
    end

    -- Reset flag-type items that are NOT found in command to "0"
    for _, sid in ipairs(state.sections) do
        if sid ~= state.command_file_section then
            for _, iid in ipairs(state.section_data[sid].items) do
                local item = state.item_data[iid]
                if item.flag and item.type == "flag" and iid ~= state.command_preview_item then
                    if not found_flags[iid] then
                        -- Flag not in command - reset to 0
                        state.values[iid] = "0"
                    end
                end
            end
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
    -- For single-select (radio) sections, ensure at least one item remains selected
    -- NOTE: Items without flags (flag=nil) can still be part of radio groups!
    --       They just can't be "found" in the command text.
    for _, sid in ipairs(state.sections) do
        if sid ~= state.command_file_section then
            local section_data = state.section_data[sid]
            local is_single = (section_data.type == "single")
            local has_flag_selection = false  -- A flagged item was found in command
            local first_checkbox_id = nil     -- First checkbox in section (for fallback)
            local flagless_selected = nil     -- Currently selected item without a flag

            -- First pass: update based on found flags, track selections
            for _, iid in ipairs(section_data.items) do
                local item = state.item_data[iid]
                if item.type == "checkbox" and iid ~= state.command_preview_item then
                    -- Track first checkbox (including flagless ones) for radio group fallback
                    if not first_checkbox_id then
                        first_checkbox_id = iid
                    end

                    if item.flag then
                        -- Item has a flag - can be found/not found in command
                        if found_flags[iid] then
                            state.values[iid] = "1"
                            has_flag_selection = true
                        else
                            -- For single-select, don't uncheck yet - we need to ensure one stays selected
                            if not is_single then
                                state.values[iid] = "0"
                            end
                        end
                    else
                        -- Item has no flag - track if it's currently selected
                        -- (flagless items can't be found in command, but can be the current selection)
                        if state.values[iid] == "1" then
                            flagless_selected = iid
                        end
                    end
                end
            end

            -- For single-select sections: handle selection preservation
            if is_single then
                if has_flag_selection then
                    -- A flagged item was found - uncheck all others (including flagless)
                    for _, iid in ipairs(section_data.items) do
                        local item = state.item_data[iid]
                        if item.type == "checkbox" and iid ~= state.command_preview_item then
                            if not found_flags[iid] then
                                state.values[iid] = "0"
                            end
                        end
                    end
                elseif flagless_selected then
                    -- No flag found, but a flagless item is selected - keep it, uncheck others
                    for _, iid in ipairs(section_data.items) do
                        local item = state.item_data[iid]
                        if item.type == "checkbox" and iid ~= state.command_preview_item then
                            if iid ~= flagless_selected then
                                state.values[iid] = "0"
                            end
                        end
                    end
                else
                    -- No flag found and no flagless selection - keep first currently selected
                    local kept_selection = false
                    for _, iid in ipairs(section_data.items) do
                        local item = state.item_data[iid]
                        if item.type == "checkbox" and iid ~= state.command_preview_item then
                            if state.values[iid] == "1" and not kept_selection then
                                kept_selection = true  -- Keep this one selected
                            else
                                state.values[iid] = "0"
                            end
                        end
                    end
                    -- If nothing was selected, select the first checkbox
                    if not kept_selection and first_checkbox_id then
                        state.values[first_checkbox_id] = "1"
                    end
                end
            end
        end
    end

    return invalid_ranges
end
-- }}}

-- Reconcile command preview with menu item states
-- Bidirectional binding: when leaving command preview, sync checkboxes FROM command
-- When on other items, sync command FROM checkboxes (unless we just left preview)
-- {{{ local function reconcile_command_preview
local function reconcile_command_preview()
    if not state.command_preview_item then return end

    local on_preview = is_on_command_preview()

    if on_preview then
        -- User is on command preview - mark it for syncing when they leave
        state.cmd_was_on_preview = true
        return  -- Don't update while user is editing
    end

    -- Check if we just left the command preview
    if state.cmd_was_on_preview then
        -- User just left command preview - sync checkboxes FROM their edited command
        -- This preserves their manual edits
        state.cmd_was_on_preview = false
        local cmd_text = state.values[state.command_preview_item] or ""
        if cmd_text ~= "" then
            state.cmd_invalid_ranges = sync_checkboxes_from_command(cmd_text)
        end
        return
    end

    -- Normal case: recompute command from checkbox/flag states
    local cmd = compute_command_preview()
    if cmd then
        state.values[state.command_preview_item] = cmd
        state.cmd_invalid_ranges = {}
    end
end
-- }}}

-- Update the command preview (alias for reconcile for backward compatibility)
local function update_command_preview()
    reconcile_command_preview()
end

-- Get the start and end positions of the <N-files> placeholder in command text
-- Returns start_pos, end_pos or nil if not found
local function get_file_placeholder_range(cmd_text)
    local start_pos, end_pos = cmd_text:find("<%d+-files>")
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
    -- Mark files as expanded (for auto-collapse when leaving)
    state.cmd_files_expanded = true
    state.cmd_on_placeholder = false

    -- Re-sync checkboxes (files aren't flags, so this should work fine)
    state.cmd_invalid_ranges = sync_checkboxes_from_command(new_text)

    return true
end

-- Collapse expanded files back to <N files> placeholder
-- Called when leaving command preview
local function collapse_files_in_command()
    if not state.cmd_files_expanded then return false end

    local files = get_selected_files()
    if #files == 0 then
        state.cmd_files_expanded = false
        return false
    end

    -- Rebuild command with placeholder instead of expanded files
    local cmd_text = state.values[state.command_preview_item] or ""

    -- Find all file occurrences and replace with placeholder
    -- This is tricky - we need to identify which part is the expanded files
    -- For now, rebuild the entire command from menu state
    local new_text = state.command_base or ""

    -- Add flags from menu items (skip disabled items)
    for _, sid in ipairs(state.sections) do
        if sid ~= state.command_file_section then
            local section_data = state.section_data[sid]
            for _, iid in ipairs(section_data.items) do
                local item = state.item_data[iid]
                if item and item.flag and iid ~= state.command_preview_item and not item.disabled then
                    if item.type == "checkbox" and state.values[iid] == "1" then
                        new_text = new_text .. " " .. item.flag
                    elseif item.type == "flag" then
                        local val = state.values[iid]
                        -- Parse value:width format to extract just the value
                        local display_val = parse_flag_value(val)
                        if display_val and display_val ~= "" and display_val ~= "0" then
                            new_text = new_text .. " " .. item.flag .. " " .. display_val
                        end
                    end
                end
            end
        end
    end

    -- Add file placeholder (no spaces to avoid tokenization issues)
    new_text = new_text .. " <" .. #files .. "-files>"

    state.values[state.command_preview_item] = new_text
    state.cmd_files_expanded = false
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

-- Get the command with <N files> placeholder expanded to actual filenames
-- If use_absolute is true, replace relative base command with absolute path
-- If use_backslash_newlines is true, format files with backslash-newlines for readability
-- Returns the expanded command string (does not modify state)
-- {{{ local function get_expanded_command
local function get_expanded_command(use_absolute, use_backslash_newlines)
    local cmd_text = get_command_text()

    -- Replace base command with absolute path if requested
    if use_absolute and state.command_base ~= state.command_base_absolute then
        -- Replace the first occurrence of the relative base with absolute
        local base_start = cmd_text:find(state.command_base, 1, true)
        if base_start == 1 then
            cmd_text = state.command_base_absolute .. cmd_text:sub(#state.command_base + 1)
        end
    end

    local start_pos, end_pos = get_file_placeholder_range(cmd_text)
    if not start_pos then return cmd_text end

    local files = get_selected_files()
    if #files == 0 then return cmd_text end

    -- Build file list with shell escaping
    local file_parts = {}
    for _, file in ipairs(files) do
        -- Escape special shell characters in filename
        local escaped = file:gsub("([%s'\"\\$`!#&*?|<>(){}%[%];])", "\\%1")
        table.insert(file_parts, escaped)
    end

    local files_str
    if use_backslash_newlines and #file_parts > 1 then
        -- Format with backslash-newlines for multi-file commands
        -- Calculate indentation based on where placeholder starts
        local indent = string.rep(" ", start_pos - 1)
        files_str = "\\\n" .. indent .. table.concat(file_parts, " \\\n" .. indent)
    else
        -- Join with spaces (single line)
        files_str = table.concat(file_parts, " ")
    end

    -- Replace placeholder with expanded files
    local before = cmd_text:sub(1, start_pos - 1)
    local after = cmd_text:sub(end_pos + 1)
    return before .. files_str .. after
end
-- }}}

-- Copy text to system clipboard using xclip or xsel
-- Copies to both PRIMARY (middle-click) and CLIPBOARD (Ctrl+V) selections
-- Returns true on success, false with error message on failure
-- {{{ local function copy_to_clipboard
local function copy_to_clipboard(text)
    -- Try xclip first (most common on Linux)
    local handle = io.popen("which xclip >/dev/null 2>&1 && echo 'xclip'", "r")
    local result = handle:read("*a")
    handle:close()

    local tool = nil
    if result:match("xclip") then
        tool = "xclip"
    else
        -- Try xsel as fallback
        handle = io.popen("which xsel >/dev/null 2>&1 && echo 'xsel'", "r")
        result = handle:read("*a")
        handle:close()
        if result:match("xsel") then
            tool = "xsel"
        else
            return false, "No clipboard tool found (install xclip or xsel)"
        end
    end

    -- Copy to both PRIMARY (middle-click) and CLIPBOARD (Ctrl+V)
    local selections = {"primary", "clipboard"}
    for _, sel in ipairs(selections) do
        local cmd
        if tool == "xclip" then
            cmd = "xclip -selection " .. sel
        else
            cmd = "xsel --" .. sel .. " --input"
        end

        handle = io.popen(cmd, "w")
        if not handle then
            return false, "Failed to open clipboard"
        end
        handle:write(text)
        handle:close()
    end

    return true, ""
end
-- }}}

-- Check if a position is within a radio button flag in the command text
-- Returns true if the position would affect a radio button flag
-- {{{ local function is_position_in_radio_flag
local function is_position_in_radio_flag(pos, cmd_text)
    local flag_lookup = build_flag_lookup()
    local tokens = parse_command_tokens(cmd_text)

    for _, token in ipairs(tokens) do
        local flag_info = flag_lookup[token.text]
        if flag_info and flag_info.is_radio then
            -- Check if position is within this radio flag (or adjacent space that would merge tokens)
            if pos >= token.start_pos and pos <= token.end_pos + 1 then
                return true
            end
        end
    end
    return false
end
-- }}}

-- Check if a position is within the base command in the command text
-- Returns true if the position would affect the base command (required element)
-- {{{ local function is_position_in_base_command
local function is_position_in_base_command(pos, cmd_text)
    local tokens = parse_command_tokens(cmd_text)
    if #tokens == 0 then return false end

    local first_token = tokens[1]
    -- Check if first token matches base command
    if first_token.text == state.command_base or first_token.text == state.command_base_absolute then
        -- Check if position is within the base command (or adjacent space that would merge)
        if pos >= first_token.start_pos and pos <= first_token.end_pos + 1 then
            return true
        end
    end
    return false
end
-- }}}

-- Find all editable value positions in the command text
-- Editable values are the values following flag-type items (e.g., the "3" in "--parallel 3")
-- Returns a list of {start_pos, end_pos, item_id} sorted by start_pos
-- {{{ local function find_editable_values
local function find_editable_values(cmd_text)
    local flag_lookup = build_flag_lookup()
    local tokens = parse_command_tokens(cmd_text)
    local editable_values = {}

    -- Iterate through tokens to find flag + value pairs
    local i = 1
    while i <= #tokens do
        local token = tokens[i]
        local flag_info = flag_lookup[token.text]

        if flag_info then
            local item = state.item_data[flag_info.item_id]
            -- Check if this is a flag-type item (has a value following it)
            if item and item.type == "flag" and i < #tokens then
                local next_token = tokens[i + 1]
                -- Make sure the next token isn't another flag
                if not flag_lookup[next_token.text] and not next_token.text:match("^<.*>$") then
                    table.insert(editable_values, {
                        start_pos = next_token.start_pos,
                        end_pos = next_token.end_pos,
                        item_id = flag_info.item_id
                    })
                    i = i + 1  -- Skip the value token
                end
            end
        end
        i = i + 1
    end

    -- Sort by start position
    table.sort(editable_values, function(a, b)
        return a.start_pos < b.start_pos
    end)

    return editable_values
end
-- }}}

-- Navigate cursor to the next editable value in command preview
-- Returns true if navigation occurred, false if at end or no editable values
-- {{{ local function cmd_nav_next_editable
local function cmd_nav_next_editable()
    local text = get_command_text()
    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #text + 1 end

    local editable_values = find_editable_values(text)
    if #editable_values == 0 then return false end

    -- Find the first editable value that starts after current cursor position
    for _, ev in ipairs(editable_values) do
        if ev.start_pos > cursor then
            state.cmd_cursor = ev.start_pos
            return true
        end
    end

    -- If no value found after cursor, wrap to the first one
    state.cmd_cursor = editable_values[1].start_pos
    return true
end
-- }}}

-- Navigate cursor to the previous editable value in command preview
-- Returns true if navigation occurred, false if at start or no editable values
-- {{{ local function cmd_nav_prev_editable
local function cmd_nav_prev_editable()
    local text = get_command_text()
    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #text + 1 end

    local editable_values = find_editable_values(text)
    if #editable_values == 0 then return false end

    -- Find the last editable value that starts before current cursor position
    for i = #editable_values, 1, -1 do
        local ev = editable_values[i]
        if ev.start_pos < cursor then
            state.cmd_cursor = ev.start_pos
            return true
        end
    end

    -- If no value found before cursor, wrap to the last one
    state.cmd_cursor = editable_values[#editable_values].start_pos
    return true
end
-- }}}

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
    -- Selected radio buttons are yellow (required, can't be deselected)
    -- Selected checkboxes are green (optional, can be toggled)
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
            -- Selected: yellow for radio (required), green for checkbox (optional)
            if is_radio then
                tui.set_fg(tui.FG_YELLOW)  -- Radio: yellow indicates required/locked
            else
                tui.set_fg(tui.FG_GREEN)   -- Checkbox: green indicates optional/togglable
            end
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

    -- Check if this item is being flashed
    local flash_color = state.flash_items and state.flash_items[item_id]

    -- Check if this item is in "suggested" state (yellow highlight when not selected)
    local is_suggested = get_suggested_state and get_suggested_state(item_id)

    -- Check if this item is blocking the currently selected disabled item
    local blocker_color = get_blocker_color_for_item(item_id)

    if flash_color then
        -- Flash overrides all other coloring
        if flash_color == "red" then
            tui.set_fg(tui.FG_RED)
        elseif flash_color == "green" then
            tui.set_fg(tui.FG_GREEN)
        elseif flash_color == "yellow" then
            tui.set_fg(tui.FG_YELLOW)
        elseif flash_color == "cyan" then
            tui.set_fg(tui.FG_CYAN)
        end
        tui.set_attrs(tui.ATTR_BOLD)
    elseif is_invalid then
        -- Conflicting/invalid state - show label in red
        tui.set_fg(tui.FG_RED)
        if highlight then
            tui.set_attrs(tui.ATTR_INVERSE)
        end
    elseif is_suggested and not highlight then
        -- Suggested state - yellow highlight to indicate "you probably want this"
        tui.set_fg(tui.FG_YELLOW)
    elseif blocker_color and not highlight then
        -- This item is blocking the selected disabled item - highlight in the dependency's color
        if blocker_color == "red" then
            tui.set_fg(tui.FG_RED)
        elseif blocker_color == "green" then
            tui.set_fg(tui.FG_GREEN)
        elseif blocker_color == "orange" then
            tui.set_fg(tui.FG_YELLOW)
            tui.set_attrs(tui.ATTR_DIM)
        else  -- yellow (default)
            tui.set_fg(tui.FG_YELLOW)
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
        -- Parse value:width format - display only the value part
        -- Width from data.config takes precedence, then parsed width, then default 10
        local display_value, parsed_width = parse_flag_value(value)
        local width = tonumber(data.config) or parsed_width or 10
        local suffix = string.format(": [%" .. width .. "s]", display_value)
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
            -- Inline editing mode: show with cursor and colored flags
            -- Radio button flags are yellow, checkbox flags are cyan, invalid are red
            local truncated = false

            if #display_val > max_len then
                display_val = display_val:sub(1, max_len - 3)
                truncated = true
            end

            -- Build flag position map for coloring
            local flag_lookup = build_flag_lookup()
            local tokens = parse_command_tokens(value)  -- Use original value for accurate positions
            local radio_ranges = {}  -- Positions that are radio button flags (yellow)
            local checkbox_ranges = {}  -- Positions that are checkbox flags (green)
            local base_range = nil  -- Base command position (yellow, required)

            for _, token in ipairs(tokens) do
                local flag_info = flag_lookup[token.text]
                if flag_info then
                    if flag_info.is_radio then
                        table.insert(radio_ranges, {start_pos = token.start_pos, end_pos = token.end_pos})
                    else
                        table.insert(checkbox_ranges, {start_pos = token.start_pos, end_pos = token.end_pos})
                    end
                elseif token.text == state.command_base or token.text == state.command_base_absolute then
                    -- Base command is required (yellow)
                    base_range = {start_pos = token.start_pos, end_pos = token.end_pos}
                end
            end

            -- Helper to check if position is in a range list
            local function in_ranges(pos, ranges)
                for _, range in ipairs(ranges) do
                    if pos >= range.start_pos and pos <= range.end_pos then
                        return true
                    end
                end
                return false
            end

            -- Helper to check if position is in a single range
            local function in_range(pos, range)
                if not range then return false end
                return pos >= range.start_pos and pos <= range.end_pos
            end

            -- Get placeholder range for highlighting
            local placeholder_start, placeholder_end = get_file_placeholder_range(value)

            -- Render character by character to support coloring and cursor
            local char_col = col
            for i = 1, #display_val do
                local c = display_val:sub(i, i)
                local in_invalid = in_ranges(i, state.cmd_invalid_ranges)
                local in_radio = in_ranges(i, radio_ranges)
                local in_checkbox = in_ranges(i, checkbox_ranges)
                local in_base = in_range(i, base_range)
                local in_placeholder = placeholder_start and i >= placeholder_start and i <= placeholder_end

                -- Set color based on flag type
                tui.reset_style()
                if in_invalid then
                    tui.set_fg(tui.FG_RED)
                    tui.set_attrs(tui.ATTR_BOLD)
                elseif in_radio or in_base then
                    tui.set_fg(tui.FG_YELLOW)  -- Radio button flags and base command in yellow (required)
                elseif in_checkbox then
                    tui.set_fg(tui.FG_GREEN)   -- Checkbox flags in green
                elseif in_placeholder then
                    tui.set_fg(tui.FG_MAGENTA)  -- Placeholder in magenta
                else
                    tui.set_fg(tui.FG_CYAN)    -- Other text in cyan
                end

                -- Show cursor (inverse video at cursor position or entire placeholder)
                if state.cmd_on_placeholder and in_placeholder then
                    tui.set_attrs(tui.ATTR_INVERSE)
                elseif i == state.cmd_cursor then
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
            -- Normal display mode (not highlighted) - still show colored flags
            local truncated = false
            if #display_val > max_len then
                display_val = display_val:sub(1, max_len - 3)
                truncated = true
            end

            -- Build flag position map for coloring
            local flag_lookup = build_flag_lookup()
            local tokens = parse_command_tokens(value)
            local radio_ranges = {}
            local checkbox_ranges = {}
            local base_range = nil

            for _, token in ipairs(tokens) do
                local flag_info = flag_lookup[token.text]
                if flag_info then
                    if flag_info.is_radio then
                        table.insert(radio_ranges, {start_pos = token.start_pos, end_pos = token.end_pos})
                    else
                        table.insert(checkbox_ranges, {start_pos = token.start_pos, end_pos = token.end_pos})
                    end
                elseif token.text == state.command_base or token.text == state.command_base_absolute then
                    base_range = {start_pos = token.start_pos, end_pos = token.end_pos}
                end
            end

            local function in_ranges(pos, ranges)
                for _, range in ipairs(ranges) do
                    if pos >= range.start_pos and pos <= range.end_pos then
                        return true
                    end
                end
                return false
            end

            local function in_range(pos, range)
                if not range then return false end
                return pos >= range.start_pos and pos <= range.end_pos
            end

            -- Render character by character for colored flags
            local char_col = col
            for i = 1, #display_val do
                local c = display_val:sub(i, i)
                local in_radio = in_ranges(i, radio_ranges)
                local in_checkbox = in_ranges(i, checkbox_ranges)
                local in_base = in_range(i, base_range)

                tui.reset_style()
                tui.set_attrs(tui.ATTR_DIM)
                if in_radio or in_base then
                    tui.set_fg(tui.FG_YELLOW)  -- Required (radio/base) in yellow
                elseif in_checkbox then
                    tui.set_fg(tui.FG_GREEN)
                else
                    tui.set_fg(tui.FG_CYAN)
                end

                tui.write_str(row, char_col, c)
                char_col = char_col + 1
            end

            if truncated then
                tui.reset_style()
                tui.set_attrs(tui.ATTR_DIM)
                tui.write_str(row, char_col, "...")
            end
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

-- {{{ render_content_separator
-- Draw a dashed separator line using box-drawing characters
-- Uses light dashed line: ┄ (U+2504)
local function render_content_separator(row)
    tui.clear_row(row)
    tui.reset_style()
    tui.set_attrs(tui.ATTR_DIM)
    -- Draw dashed line using ╌ (U+254C light double dash) or ┄ (U+2504 light triple dash)
    local dash = "\226\148\132"  -- ─ (solid line for now, simpler)
    for x = 1, state.cols do
        tui.set_cell(row, x, dash)
    end
    tui.reset_style()
end
-- }}}

-- {{{ render_content_source
-- Render a single content source, returns next row
-- available_lines: max lines this source can use
-- Supports scrolling for item_file type content
local function render_content_source(row, source, available_lines)
    if available_lines <= 0 then return row end

    local content_lines = {}
    local label = source.label or ""
    local use_scrolling = false  -- Only enable scrolling for item_file type
    local filepath = nil

    -- Get content based on source type
    if source.type == "item_file" then
        -- Use current item's filepath - with caching and scrolling support
        filepath = get_current_item_filepath()
        if filepath then
            content_lines = get_cached_file_content(filepath)
            use_scrolling = true
            if label == "" then
                -- Default label: filename
                label = filepath:match("([^/]+)$") or ""
            end
        end
    elseif source.type == "file" then
        -- Read from specified file path
        if source.content and source.content ~= "" then
            content_lines = read_file_lines(source.content, available_lines)
        end
    elseif source.type == "text" then
        -- Static text content - split by newlines
        if source.content then
            for line in source.content:gmatch("[^\n]+") do
                table.insert(content_lines, line)
                if #content_lines >= available_lines then break end
            end
        end
    end

    -- If no content, skip this source
    if #content_lines == 0 then return row end

    -- Render label if present (uses 1 line)
    -- For scrolling content, include line range indicator
    local content_start = row
    if label ~= "" then
        tui.clear_row(row)
        tui.set_fg(tui.FG_CYAN)
        tui.set_attrs(tui.ATTR_DIM)

        local range_indicator = ""
        if use_scrolling and #content_lines > available_lines - 1 then
            local start_line = state.content_scroll_offset + 1
            local end_line = math.min(state.content_scroll_offset + available_lines - 1, #content_lines)
            range_indicator = string.format(" [%d-%d of %d]", start_line, end_line, #content_lines)
        end

        local max_label = state.cols - 4 - #range_indicator
        local display_label = label
        if #display_label > max_label then
            display_label = display_label:sub(1, max_label - 3) .. "..."
        end
        tui.write_str(row, 2, display_label)

        -- Show range indicator on the right
        if range_indicator ~= "" then
            tui.write_str(row, state.cols - #range_indicator - 1, range_indicator)
        end

        tui.reset_style()
        row = row + 1
        content_start = row
    end

    -- Calculate how many lines we can show
    local lines_available = available_lines - (row - content_start + 1) + 1
    local lines_to_show = math.min(#content_lines, lines_available)

    -- Apply scroll offset for scrollable content
    local scroll_offset = 0
    if use_scrolling then
        scroll_offset = state.content_scroll_offset
        -- Clamp scroll offset to valid range
        if scroll_offset > #content_lines - lines_to_show then
            scroll_offset = math.max(0, #content_lines - lines_to_show)
            state.content_scroll_offset = scroll_offset
        end
        -- Store visible lines count for scrollbar and navigation
        state.content_visible_lines = lines_to_show
    end

    -- Reserve space for scrollbar if needed
    local has_scrollbar = use_scrolling and #content_lines > lines_to_show
    local max_len = state.cols - 4
    if has_scrollbar then
        max_len = max_len - 2  -- Leave space for scrollbar
    end

    -- Render content lines
    local content_row_start = row
    for i = 1, lines_to_show do
        if row > state.rows - 3 then break end  -- Leave room for footer
        tui.clear_row(row)
        local line_idx = i + scroll_offset
        local line = content_lines[line_idx] or ""
        if #line > max_len then
            line = line:sub(1, max_len - 3) .. "..."
        end
        tui.set_attrs(tui.ATTR_DIM)
        tui.write_str(row, 3, line)
        tui.reset_style()
        row = row + 1
    end

    -- Render scrollbar if content is scrollable
    if has_scrollbar then
        local scrollbar_height = row - content_row_start
        render_scrollbar(content_row_start, scrollbar_height, #content_lines, scroll_offset, lines_to_show)
    end

    return row
end
-- }}}

local function render_description(start_row)
    local row = start_row

    -- Separator line between items and description
    tui.clear_row(row)
    tui.reset_style()
    tui.draw_hline(row, 1, state.cols)
    row = row + 1

    -- Calculate available space (leave 3 rows for footer)
    local footer_rows = 3
    local available_rows = state.rows - row - footer_rows

    -- Show status message if set (e.g., error messages), otherwise show item description
    tui.clear_row(row)
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
        row = row + 1
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
        row = row + 1

        -- Show disabled reason if item is disabled due to dependency
        if item_id and state.disabled_reasons[item_id] then
            tui.clear_row(row)
            local reason_info = state.disabled_reasons[item_id]
            local reason = reason_info.reason
            local color = reason_info.color or "yellow"

            -- Set color based on configured color
            if color == "red" then
                tui.set_fg(tui.FG_RED)
            elseif color == "green" then
                tui.set_fg(tui.FG_GREEN)
            elseif color == "orange" then
                -- Orange approximated with yellow + dim or just yellow
                tui.set_fg(tui.FG_YELLOW)
                tui.set_attrs(tui.ATTR_DIM)
            else  -- yellow (default)
                tui.set_fg(tui.FG_YELLOW)
            end

            local max_len = state.cols - 6
            if #reason > max_len then
                reason = reason:sub(1, max_len - 3) .. "..."
            end
            tui.write_str(row, 5, "-> " .. reason)
            tui.reset_style()
            row = row + 1
        end
    end

    -- Render content sources if any and space available
    local num_sources = #state.content_sources
    if num_sources > 0 and available_rows > 2 then
        -- Calculate space for each source
        -- All sources except last get fixed space (3 lines each: separator + label + 1 content)
        -- Last source gets remaining space
        local remaining = available_rows - 1  -- Account for description row already used

        for idx, source in ipairs(state.content_sources) do
            if remaining <= 1 then break end

            -- Draw separator before each content source (dashed line with newlines)
            tui.clear_row(row)
            row = row + 1
            remaining = remaining - 1

            render_content_separator(row)
            row = row + 1
            remaining = remaining - 1

            tui.clear_row(row)
            row = row + 1
            remaining = remaining - 1

            if remaining <= 0 then break end

            -- Determine lines for this source
            local source_lines
            if idx == num_sources then
                -- Last source gets all remaining space
                source_lines = remaining
            else
                -- Non-last sources get minimal space (5 lines: label + 4 content)
                source_lines = math.min(5, remaining)
            end

            row = render_content_source(row, source, source_lines)
            remaining = available_rows - (row - start_row)
        end
    end

    -- Clear any remaining rows until footer
    while row < state.rows - footer_rows do
        tui.clear_row(row)
        row = row + 1
    end

    return row
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
            base_help = "h/l:move  0-9:digit  spc:space  n/N:vals  i:ins  ~:copy  `:run  q:quit"
        elseif state.cmd_input_mode == "insert" then
            base_help = "-- INSERT --  type:edit  ENTER:next val  ESC:exit"
        else  -- arrow mode
            base_help = "arrows:cursor  type:edit  ENTER:next val  q:quit"
        end
    else
        base_help = "j/k:nav  space:toggle  ~:copy  `:action  q:quit"
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

-- {{{ trigger_prerequisites
-- Internal function: called when an item is selected to trigger its prerequisites
-- Moved here from later in file because Lua requires functions to be defined before use
local function trigger_prerequisites(item_id)
    if not state.prerequisites or not state.prerequisites[item_id] then
        return
    end

    for _, prereq_id in ipairs(state.prerequisites[item_id]) do
        local prereq_data = state.item_data[prereq_id]
        if prereq_data and prereq_data.type == "checkbox" then
            -- Only enable if not already enabled
            if state.values[prereq_id] ~= "1" then
                menu.force_enable(prereq_id, 3, "red")
            end
        end
    end
end
-- }}}

-- {{{ menu.toggle
-- Returns "action" if an action item was activated, nil otherwise
function menu.toggle()
    local item_id = get_current_item_id()
    if not item_id then return nil end

    local data = state.item_data[item_id]
    if data.disabled then
        -- Flash red to indicate rejected interaction
        menu.flash_item(item_id, 2, "red", 100)
        return nil
    end

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
            -- Trigger any prerequisites when item is selected
            trigger_prerequisites(item_id)
        else
            -- Toggle
            state.values[item_id] = state.values[item_id] == "1" and "0" or "1"
            -- Trigger prerequisites when item becomes enabled
            if state.values[item_id] == "1" then
                trigger_prerequisites(item_id)
            end
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

    update_disabled_states()
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
    if data.disabled then
        -- Flash red to indicate rejected interaction
        menu.flash_item(item_id, 2, "red", 100)
        return false
    end

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
        -- Trigger any prerequisites when item is selected
        trigger_prerequisites(item_id)
        update_disabled_states()
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
    if data.disabled then
        -- Flash red to indicate rejected interaction
        menu.flash_item(item_id, 2, "red", 100)
        return false
    end

    -- Prevent unchecking radio buttons (single-select sections)
    local section_type = get_current_section_type()
    if section_type == "single" then
        return false  -- Radio buttons cannot be unchecked
    end

    if data.type == "checkbox" then
        state.values[item_id] = "0"
        update_disabled_states()
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

    update_disabled_states()
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

    update_disabled_states()
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
    if data.type ~= "flag" then return false end
    if data.disabled then
        -- Flash red to indicate rejected interaction
        menu.flash_item(item_id, 2, "red", 100)
        return false
    end

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
    if data.type ~= "flag" then return false end
    if data.disabled then
        -- Flash red to indicate rejected interaction
        menu.flash_item(item_id, 2, "red", 100)
        return false
    end

    state.values[item_id] = data.default_value or "0"
    state.flag_edit_started[item_id] = nil  -- Reset so next digit overwrites
    menu.render()
    return true
end
-- }}}

-- {{{ menu.handle_flag_digit
-- Handle digit input for flag fields
-- First digit clears the field and starts fresh, subsequent digits append
-- Also handles period (.) for decimal values
function menu.handle_flag_digit(digit)
    local item_id = get_current_item_id()
    if not item_id then return false end

    local data = state.item_data[item_id]
    if data.type ~= "flag" then return false end
    if data.disabled then
        -- Flash red to indicate rejected interaction
        menu.flash_item(item_id, 2, "red", 100)
        return false
    end

    -- Validate digit (0-9) or period (.)
    local is_digit = digit:match("^%d$")
    local is_period = digit == "."

    if not is_digit and not is_period then return false end

    -- Don't allow multiple periods
    local current = state.values[item_id] or ""
    if is_period and current:find("%.") then
        return false
    end

    if not state.flag_edit_started[item_id] then
        -- First keystroke: clear and start fresh
        if is_period then
            -- Period as first char becomes "0."
            state.values[item_id] = "0."
        else
            state.values[item_id] = digit
        end
        state.flag_edit_started[item_id] = true
    else
        -- Subsequent keystrokes: append (but respect reasonable limits)
        -- Limit to reasonable length (e.g., 8 chars for decimals like "0.00001")
        if #current < 8 then
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
    if data.type ~= "flag" then return false end
    if data.disabled then
        -- Flash red to indicate rejected interaction
        menu.flash_item(item_id, 2, "red", 100)
        return false
    end

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
-- If cursor is on the <N files> placeholder (highlighted), delete it and uncheck all files
-- Protected: cannot delete radio button flags (required options)
-- Atomic deletion for FLAG NAMES only (like --parallel), values delete char-by-char
function menu.cmd_backspace()
    if not is_on_command_preview() then return false end

    local text = get_command_text()

    -- Check if cursor is on the placeholder (highlighted state)
    if state.cmd_on_placeholder then
        local start_pos, end_pos = get_file_placeholder_range(text)
        if start_pos then
            -- Delete the placeholder (and leading space if present)
            local delete_start = start_pos
            if delete_start > 1 and text:sub(delete_start - 1, delete_start - 1) == " " then
                delete_start = delete_start - 1  -- Include leading space
            end
            local before = text:sub(1, delete_start - 1)
            local after = text:sub(end_pos + 1)
            local new_text = before .. after

            -- Uncheck all files in the file section
            if state.command_file_section then
                local section_data = state.section_data[state.command_file_section]
                if section_data then
                    for _, iid in ipairs(section_data.items) do
                        state.values[iid] = "0"
                    end
                end
            end

            state.values[state.command_preview_item] = new_text
            state.cmd_cursor = delete_start
            if state.cmd_cursor < 1 then state.cmd_cursor = 1 end
            state.cmd_on_placeholder = false
            state.cmd_invalid_ranges = sync_checkboxes_from_command(new_text)
            menu.render()
            return true
        end
    end

    -- Reuse text from above, get cursor position
    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #text + 1 end
    if cursor <= 1 then return false end

    -- Check if deleting would affect a required element (radio button or base command)
    local delete_pos = cursor - 1
    if is_position_in_radio_flag(delete_pos, text) then
        state.status_message = "Cannot delete required option! Use menu to change mode."
        menu.render()
        return false
    end
    if is_position_in_base_command(delete_pos, text) then
        state.status_message = "Cannot delete base command!"
        menu.render()
        return false
    end

    local new_text = text
    local new_cursor = cursor

    -- Parse tokens and build lookup for flag detection
    local tokens = parse_command_tokens(text)
    local flag_lookup = build_flag_lookup()

    -- Check if cursor is right after a space
    local char_before = text:sub(cursor - 1, cursor - 1)
    if char_before == " " then
        -- Check if this space follows a valid flag name that takes a value
        -- If so, delete the space AND the flag name together (atomic)
        local space_follows_flag_with_value = false
        for i, token in ipairs(tokens) do
            -- Check if this token ends right before the space we're about to delete
            if token.end_pos == cursor - 2 then
                local flag_info = flag_lookup[token.text]
                if flag_info then
                    local item = state.item_data[flag_info.item_id]
                    if item and item.type == "flag" then
                        -- This is a flag that takes a value - delete flag + space atomically
                        local before_token = text:sub(1, token.start_pos - 1)
                        local after_token = text:sub(cursor)  -- Keep everything after cursor
                        new_text = before_token .. after_token
                        new_cursor = token.start_pos
                        space_follows_flag_with_value = true
                        break
                    end
                end
            end
        end

        if not space_follows_flag_with_value then
            -- Simple space deletion
            new_text = text:sub(1, cursor - 2) .. text:sub(cursor)
            new_cursor = cursor - 1
        end
    else
        -- Check if we're at the end of a VALID FLAG NAME token - delete atomically
        -- Invalid flags, values, and other tokens delete character-by-character
        local deleted_flag_name = false

        for i, token in ipairs(tokens) do
            -- Check if cursor is right after this token
            if cursor == token.end_pos + 1 then
                -- Check if this is a VALID flag name (recognized in our flag lookup)
                local flag_info = flag_lookup[token.text]

                if flag_info then
                    -- Valid flag - check if it's a flag-with-value type
                    local item = state.item_data[flag_info.item_id]
                    if item and item.type == "flag" then
                        -- Flag that takes a value - check if there's a space after it
                        -- If so, include the space in the deletion
                        local after_pos = token.end_pos + 1
                        if text:sub(after_pos, after_pos) == " " then
                            -- Delete flag + trailing space
                            local before_token = text:sub(1, token.start_pos - 1)
                            local after_token = text:sub(after_pos + 1)
                            new_text = before_token .. after_token
                            new_cursor = token.start_pos
                        else
                            -- Delete just the flag
                            local before_token = text:sub(1, token.start_pos - 1)
                            local after_token = text:sub(token.end_pos + 1)
                            new_text = before_token .. after_token
                            new_cursor = token.start_pos
                        end
                    else
                        -- Checkbox-style flag (no value) - delete just the flag
                        local before_token = text:sub(1, token.start_pos - 1)
                        local after_token = text:sub(token.end_pos + 1)
                        new_text = before_token .. after_token
                        new_cursor = token.start_pos
                    end
                    deleted_flag_name = true
                end
                -- If it's a value, invalid flag, or other token, fall through to single-char delete
                break
            end
        end

        if not deleted_flag_name then
            -- Delete single character (for values, invalid flags, middle of tokens, etc.)
            new_text = text:sub(1, cursor - 2) .. text:sub(cursor)
            new_cursor = cursor - 1
        end
    end

    -- Don't auto-cleanup spaces - let user manage spacing manually
    -- This preserves the space after flag names so user can immediately type new values

    state.values[state.command_preview_item] = new_text
    state.cmd_cursor = new_cursor

    -- Re-sync checkboxes and detect invalid flags
    state.cmd_invalid_ranges = sync_checkboxes_from_command(new_text)

    menu.render()
    return true
end
-- }}}

-- {{{ menu.cmd_delete
-- Delete character at cursor in command preview
-- If cursor is within <N files> placeholder, expand files instead
-- Protected: cannot delete radio button flags (required options)
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

    -- Check if deleting would affect a required element (radio button or base command)
    if is_position_in_radio_flag(cursor, text) then
        state.status_message = "Cannot delete required option! Use menu to change mode."
        menu.render()
        return false
    end
    if is_position_in_base_command(cursor, text) then
        state.status_message = "Cannot delete base command!"
        menu.render()
        return false
    end

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
-- Treats <N files> placeholder as a single unit
function menu.cmd_cursor_left()
    if not is_on_command_preview() then return false end

    local text = get_command_text()
    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #text + 1 end

    if cursor <= 1 then return true end

    -- Check if we're currently on the placeholder
    if state.cmd_on_placeholder then
        -- Move to position before the placeholder
        local start_pos, _ = get_file_placeholder_range(text)
        if start_pos then
            state.cmd_cursor = start_pos - 1
            if state.cmd_cursor < 1 then state.cmd_cursor = 1 end
            state.cmd_on_placeholder = false
        else
            state.cmd_cursor = cursor - 1
        end
        menu.render()
        return true
    end

    -- Check if moving left would enter the placeholder (cursor right after '>')
    local start_pos, end_pos = get_file_placeholder_range(text)
    if start_pos and cursor == end_pos + 1 then
        -- Enter the placeholder (highlight entire section)
        state.cmd_on_placeholder = true
        state.cmd_cursor = cursor  -- Keep cursor position for reference
        menu.render()
        return true
    end

    -- Normal movement
    state.cmd_cursor = cursor - 1
    menu.render()
    return true
end
-- }}}

-- {{{ menu.cmd_cursor_right
-- Move cursor right in command preview
-- Treats <N files> placeholder as a single unit
function menu.cmd_cursor_right()
    if not is_on_command_preview() then return false end

    local text = get_command_text()
    local cursor = state.cmd_cursor
    if cursor == 0 then cursor = #text + 1 end

    if cursor > #text then return true end

    -- Check if we're currently on the placeholder
    if state.cmd_on_placeholder then
        -- Move to position after the placeholder
        local _, end_pos = get_file_placeholder_range(text)
        if end_pos then
            state.cmd_cursor = end_pos + 1
            state.cmd_on_placeholder = false
        else
            state.cmd_cursor = cursor + 1
        end
        menu.render()
        return true
    end

    -- Check if moving right would enter the placeholder (cursor right before '<')
    local start_pos, end_pos = get_file_placeholder_range(text)
    if start_pos and cursor == start_pos - 1 then
        -- Enter the placeholder (highlight entire section)
        state.cmd_on_placeholder = true
        state.cmd_cursor = cursor  -- Keep cursor position for reference
        menu.render()
        return true
    end

    -- Normal movement
    state.cmd_cursor = cursor + 1
    menu.render()
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
                -- ENTER/n moves to next editable value, SHIFT_ENTER/N moves to previous
                -- ` or ~ jumps to action item (run option)

                if key == "ENTER" or key == "n" then
                    -- If on placeholder, expand files; otherwise navigate to next editable value
                    if state.cmd_on_placeholder then
                        expand_files_in_command()
                        menu.render()
                    elseif not cmd_nav_next_editable() then
                        -- No editable values found, go to action
                        state.cmd_cursor = 0
                        state.cmd_input_mode = "vim-nav"
                        collapse_files_in_command()  -- Auto-collapse when leaving command preview
                        menu.nav_to_action()
                    else
                        menu.render()
                    end
                elseif key == "SHIFT_ENTER" or key == "N" then
                    -- Navigate to previous editable value
                    if cmd_nav_prev_editable() then
                        menu.render()
                    end
                elseif key == "h" then
                    menu.cmd_cursor_left()
                elseif key == "l" then
                    menu.cmd_cursor_right()
                elseif key == "j" then
                    -- Navigate down, reset mode for next time
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    collapse_files_in_command()  -- Auto-collapse when leaving command preview
                    menu.nav_down()
                elseif key == "k" then
                    -- Navigate up, reset mode for next time
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    collapse_files_in_command()  -- Auto-collapse when leaving command preview
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
                elseif key >= "0" and key <= "9" then
                    -- Insert digit (for editing values like --parallel 3)
                    menu.cmd_insert_char(key)
                elseif key == "^" then
                    -- Go to start of line (vim) - use ^ instead of 0 since 0 inserts digit
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
                        collapse_files_in_command()  -- Auto-collapse when leaving
                        menu.nav_up()
                    elseif key == "DOWN" then
                        state.cmd_cursor = 0
                        state.cmd_input_mode = "vim-nav"
                        collapse_files_in_command()  -- Auto-collapse when leaving
                        menu.nav_down()
                    end
                elseif key == "HOME" or key == "CTRL_A" then
                    menu.cmd_cursor_start()
                elseif key == "END" or key == "CTRL_E" then
                    menu.cmd_cursor_end()
                elseif key == "`" then
                    -- Jump to action item (run)
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    collapse_files_in_command()  -- Auto-collapse when leaving command preview
                    menu.nav_to_action()
                elseif key == "~" then
                    -- Copy expanded command to clipboard with backslash-newlines
                    local expanded = get_expanded_command(true, true)  -- absolute path, backslash-newlines
                    local success, err = copy_to_clipboard(expanded)
                    if success then
                        state.status_message = "Command copied to clipboard!"
                    else
                        state.status_message = "Clipboard error: " .. (err or "unknown")
                    end
                    menu.render()
                elseif key == "x" then
                    -- Delete char at cursor (vim x)
                    menu.cmd_delete()
                elseif key == "BACKSPACE" or key == "DELETE" then
                    menu.cmd_backspace()
                elseif key == "SPACE" then
                    -- If on placeholder, expand files; otherwise insert a space
                    if state.cmd_on_placeholder then
                        expand_files_in_command()
                        menu.render()
                    else
                        -- Insert a space at cursor position (useful for fixing merged tokens)
                        menu.cmd_insert_char(" ")
                    end
                end
                -- Other keys ignored in vim-nav mode

            elseif mode == "insert" then
                -- === INSERT MODE ===
                -- All printable chars insert, arrows move cursor, ESC exits
                -- ENTER/SHIFT_ENTER navigate between editable values (same as vim-nav)

                if key == "ENTER" then
                    -- Navigate to next editable value, or to action if no more values
                    if not cmd_nav_next_editable() then
                        state.cmd_cursor = 0
                        state.cmd_input_mode = "vim-nav"
                        collapse_files_in_command()  -- Auto-collapse when leaving
                        menu.nav_to_action()
                    else
                        menu.render()
                    end
                elseif key == "SHIFT_ENTER" then
                    -- Navigate to previous editable value
                    if cmd_nav_prev_editable() then
                        menu.render()
                    end
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
                    collapse_files_in_command()  -- Auto-collapse when leaving
                    menu.nav_up()
                elseif key == "DOWN" then
                    -- Navigate down, exit insert mode
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    collapse_files_in_command()  -- Auto-collapse when leaving
                    menu.nav_down()
                elseif key == "HOME" or key == "CTRL_A" then
                    menu.cmd_cursor_start()
                elseif key == "END" or key == "CTRL_E" then
                    menu.cmd_cursor_end()
                elseif key == "BACKSPACE" then
                    menu.cmd_backspace()
                elseif key == "DELETE" then
                    menu.cmd_delete()
                elseif key == "SPACE" then
                    -- Insert a space
                    menu.cmd_insert_char(" ")
                elseif type(key) == "string" and #key == 1 and key:byte() >= 32 and key:byte() <= 126 then
                    -- Insert printable character (including h/j/k/l)
                    menu.cmd_insert_char(key)
                end

            else  -- mode == "arrow"
                -- === ARROW MODE ===
                -- Arrows move cursor, vim keys (and other printable) insert text
                -- ENTER/SHIFT_ENTER navigate between editable values (same as vim-nav)

                if key == "ENTER" then
                    -- Navigate to next editable value, or to action if no more values
                    if not cmd_nav_next_editable() then
                        state.cmd_cursor = 0
                        state.cmd_input_mode = "vim-nav"
                        collapse_files_in_command()  -- Auto-collapse when leaving
                        menu.nav_to_action()
                    else
                        menu.render()
                    end
                elseif key == "SHIFT_ENTER" then
                    -- Navigate to previous editable value
                    if cmd_nav_prev_editable() then
                        menu.render()
                    end
                elseif key == "LEFT" then
                    menu.cmd_cursor_left()
                elseif key == "RIGHT" then
                    menu.cmd_cursor_right()
                elseif key == "UP" then
                    -- Navigate up, reset to vim-nav
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    collapse_files_in_command()  -- Auto-collapse when leaving
                    menu.nav_up()
                elseif key == "DOWN" then
                    -- Navigate down, reset to vim-nav
                    state.cmd_cursor = 0
                    state.cmd_input_mode = "vim-nav"
                    collapse_files_in_command()  -- Auto-collapse when leaving
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
                elseif key == "SPACE" then
                    -- Insert a space
                    menu.cmd_insert_char(" ")
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
            -- Tab/Shift+Tab: reserved for future (e.g., page switching)
            elseif key == "TAB" or key == "SHIFT_TAB" then
                -- No-op for now, reserved for future menu pages
            -- LEFT/h: unset checkbox, set flag to 0, cycle multistate backwards
            elseif key == "LEFT" or key == "h" then
                menu.handle_left()
            -- RIGHT/l: set checkbox, set flag to default, cycle multistate forwards
            elseif key == "RIGHT" or key == "l" then
                menu.handle_right()
            -- Toggle/Activate: SPACE/i/ENTER
            elseif key == "SPACE" or key == "i" or key == "ENTER" then
                -- For text/flag items (not command preview), Enter/Space navigates down
                local item_id = get_current_item_id()
                local item_type = item_id and state.item_data[item_id] and state.item_data[item_id].type
                if item_type == "text" or item_type == "flag" then
                    menu.nav_down()
                else
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
                end
            -- Go to top
            elseif key == "g" then
                menu.nav_top()
            -- Go to bottom (uppercase G)
            elseif key == "G" then
                menu.nav_bottom()
            -- Shift+J: Scroll content panel down
            elseif key == "J" then
                menu.content_scroll_down()
            -- Shift+K: Scroll content panel up
            elseif key == "K" then
                menu.content_scroll_up()
            -- Page Down: Scroll content panel down by page
            elseif key == "PAGE_DOWN" or key == "CTRL_D" then
                menu.content_scroll_page_down()
            -- Page Up: Scroll content panel up by page
            elseif key == "PAGE_UP" or key == "CTRL_U" then
                menu.content_scroll_page_up()
            -- Jump to action item: `
            elseif key == "`" then
                menu.nav_to_action()
            -- Copy expanded command to clipboard: ~
            -- Always uses absolute path and backslash-newlines for clipboard
            elseif key == "~" then
                local expanded = get_expanded_command(true, true)  -- absolute path, backslash-newlines
                local success, err = copy_to_clipboard(expanded)
                if success then
                    state.status_message = "Command copied to clipboard!"
                else
                    state.status_message = "Clipboard error: " .. (err or "unknown")
                end
                menu.render()
            -- Period key for decimal input in flag fields
            elseif key == "." then
                local item_id = get_current_item_id()
                local is_flag = item_id and state.item_data[item_id] and state.item_data[item_id].type == "flag"
                if is_flag then
                    menu.handle_flag_digit(key)
                end
                -- Period does nothing if not on a flag field
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

-- {{{ menu.add_dependency
-- Add a dependency rule: item_id is enabled/disabled based on depends_on's value
--
-- Parameters:
--   item_id: The item that will be enabled/disabled
--   depends_on: The item_id whose value controls the dependency
--   required_values: Table of values that ENABLE item_id (e.g., {"1"} for checkbox)
--   invert: If true, item is enabled when depends_on is NOT in required_values
--   reason: Optional message shown when item is disabled (e.g., "Requires X mode")
--   color: Optional color for reason ("yellow", "orange", "green", "red")
--
-- Examples:
--   -- "session" disabled when "streaming" is selected (incompatible)
--   menu.add_dependency("session", "streaming", {"1"}, true,
--       "Incompatible with Streaming mode", "orange")
--
function menu.add_dependency(item_id, depends_on, required_values, invert, reason, color)
    if not state.item_data[item_id] then
        return false  -- Item doesn't exist
    end

    state.dependencies[item_id] = {
        depends_on = depends_on,
        required_values = required_values or {"1"},
        invert = invert or false,
        reason = reason or nil,
        color = color or "yellow"
    }

    -- Apply the dependency immediately
    update_disabled_states()
    return true
end
-- }}}

-- {{{ menu.add_dependency_multi
-- Add a dependency where item is enabled if ANY of the depends_on items match
--
-- Parameters:
--   item_id: The item that will be enabled/disabled
--   depends_on_list: Table of {item_id, required_values} pairs
--   invert: If true, item is enabled when NONE of the conditions match
--   reason: Optional message shown when item is disabled
--   color: Optional color for reason ("yellow", "orange", "green", "red")
--
-- Example:
--   menu.add_dependency_multi("no_confirm", {
--       {"execute", {"1"}},
--       {"implement", {"1"}}
--   }, false, "Only applies to Execute or Implement modes", "yellow")
function menu.add_dependency_multi(item_id, depends_on_list, invert, reason, color)
    if not state.item_data[item_id] then
        return false
    end

    state.dependencies[item_id] = {
        multi = true,
        depends_on_list = depends_on_list,
        invert = invert or false,
        reason = reason or nil,
        color = color or "yellow"
    }

    update_disabled_states()
    return true
end
-- }}}

-- {{{ menu.flash_item
-- Flash an item's color for visual feedback
-- Used for rejection feedback (red), auto-enable feedback (red), success (green)
--
-- Parameters:
--   item_id: The item to flash
--   count: Number of flashes (default 2)
--   color: Flash color - "red", "yellow", "green", "cyan" (default "red")
--   interval_ms: Milliseconds per flash pulse (default 100)
--
-- Example:
--   menu.flash_item("session", 3, "red", 100)
function menu.flash_item(item_id, count, color, interval_ms)
    count = count or 2
    color = color or "red"
    interval_ms = interval_ms or 100

    local data = state.item_data[item_id]
    if not data then return false end

    -- Store original flash state
    local original_flash = state.flash_items and state.flash_items[item_id]

    -- Initialize flash_items table if needed
    state.flash_items = state.flash_items or {}

    -- Convert interval to seconds for os.execute sleep
    local sleep_sec = interval_ms / 1000

    for i = 1, count do
        -- Flash on
        state.flash_items[item_id] = color
        menu.render()
        tui.present()
        os.execute(string.format("sleep %.3f", sleep_sec))

        -- Flash off
        state.flash_items[item_id] = nil
        menu.render()
        tui.present()
        os.execute(string.format("sleep %.3f", sleep_sec))
    end

    -- Restore original flash state
    if original_flash then
        state.flash_items[item_id] = original_flash
    end

    return true
end
-- }}}

-- {{{ menu.force_enable
-- Programmatically enable an item and flash it to draw attention
-- Used when selecting one option requires enabling another (e.g., prerequisites)
--
-- Parameters:
--   item_id: The item to enable
--   flash_count: Number of flashes (default 3)
--   flash_color: Color of flash (default "red")
--
-- Example:
--   menu.force_enable("session", 3, "red")
function menu.force_enable(item_id, flash_count, flash_color)
    flash_count = flash_count or 3
    flash_color = flash_color or "red"

    local data = state.item_data[item_id]
    if not data then return false end

    -- Enable the item (set checkbox to 1)
    if data.type == "checkbox" then
        state.values[item_id] = "1"
        update_disabled_states()
    end

    -- Flash to draw attention
    menu.flash_item(item_id, flash_count, flash_color)

    return true
end
-- }}}

-- {{{ menu.add_prerequisite
-- Add a prerequisite relationship: when item_id is selected, prerequisite_id is auto-enabled
-- Prerequisite will flash red when auto-enabled
--
-- Parameters:
--   item_id: The item that triggers the prerequisite
--   prerequisite_id: The item that will be auto-enabled
--
-- Example:
--   menu.add_prerequisite("generate_complete", "session")
--   -- When "generate_complete" is selected, "session" is auto-enabled with flash
function menu.add_prerequisite(item_id, prerequisite_id)
    local data = state.item_data[item_id]
    if not data then return false end

    -- Initialize prerequisites table for this item
    state.prerequisites = state.prerequisites or {}
    state.prerequisites[item_id] = state.prerequisites[item_id] or {}

    -- Add prerequisite
    table.insert(state.prerequisites[item_id], prerequisite_id)

    return true
end
-- }}}

-- trigger_prerequisites moved earlier in file (before menu.toggle where it's first called)

-- {{{ menu.add_dependency_suggest
-- Add a "suggested" dependency: item is highlighted yellow when trigger condition is met
-- but item is not yet selected. Indicates "you probably want this" without forcing.
--
-- Parameters:
--   item_id: The item to highlight as suggested
--   depends_on: The item whose value triggers the suggestion
--   required_values: Values of depends_on that trigger suggestion (default {"1"})
--   reason: Optional message shown in description
--
-- Example:
--   menu.add_dependency_suggest("elaborate", "execute", {"1"}, "Recommended for complete specs")
function menu.add_dependency_suggest(item_id, depends_on, required_values, reason)
    if not state.item_data[item_id] then return false end

    state.suggested_deps = state.suggested_deps or {}
    state.suggested_deps[item_id] = {
        depends_on = depends_on,
        required_values = required_values or {"1"},
        reason = reason
    }

    return true
end
-- }}}

-- {{{ menu.batch_pause
-- Display a mid-process prompt during batch operations
-- Returns the key pressed by the user
--
-- Parameters:
--   options: Table mapping keys to labels, e.g., {c = "continue", r = "read file", s = "skip"}
--
-- Example:
--   local choice = menu.batch_pause({c = "continue", r = "read file", s = "skip"})
--   if choice == "r" then ... end
function menu.batch_pause(options)
    if not options or next(options) == nil then
        return nil
    end

    -- Build prompt string: "[c]ontinue | [r]ead file | [s]kip"
    local parts = {}
    local valid_keys = {}
    for key, label in pairs(options) do
        table.insert(parts, string.format("[%s]%s", key, label))
        valid_keys[key] = true
    end
    local prompt = table.concat(parts, " | ")

    -- Clear a row and display the prompt
    local prompt_row = state.rows - 1
    tui.reset_style()
    tui.clear_row(prompt_row)
    tui.set_fg(tui.FG_YELLOW)
    tui.set_attrs(tui.ATTR_BOLD)
    tui.write_str(prompt_row, 2, prompt)
    tui.present()

    -- Wait for valid key
    while true do
        local key = tui.read_key()
        if key and valid_keys[key] then
            -- Clear the prompt
            tui.clear_row(prompt_row)
            tui.present()
            return key
        end
        -- ESC or q to cancel
        if key == "ESCAPE" or key == "q" then
            tui.clear_row(prompt_row)
            tui.present()
            return nil
        end
    end
end
-- }}}

-- {{{ menu.content_scroll_down
-- Scroll content panel down by specified number of lines
-- Used with Shift+J or other scroll key bindings
function menu.content_scroll_down(lines)
    lines = lines or 1
    if state.content_total_lines == 0 then return false end

    local max_offset = math.max(0, state.content_total_lines - state.content_visible_lines)
    local new_offset = math.min(state.content_scroll_offset + lines, max_offset)

    if new_offset ~= state.content_scroll_offset then
        state.content_scroll_offset = new_offset
        menu.render()
        return true
    end
    return false
end
-- }}}

-- {{{ menu.content_scroll_up
-- Scroll content panel up by specified number of lines
-- Used with Shift+K or other scroll key bindings
function menu.content_scroll_up(lines)
    lines = lines or 1
    if state.content_total_lines == 0 then return false end

    local new_offset = math.max(0, state.content_scroll_offset - lines)

    if new_offset ~= state.content_scroll_offset then
        state.content_scroll_offset = new_offset
        menu.render()
        return true
    end
    return false
end
-- }}}

-- {{{ menu.content_scroll_page_down
-- Scroll content panel down by one page (visible lines)
function menu.content_scroll_page_down()
    if state.content_visible_lines > 0 then
        return menu.content_scroll_down(state.content_visible_lines - 1)
    end
    return false
end
-- }}}

-- {{{ menu.content_scroll_page_up
-- Scroll content panel up by one page (visible lines)
function menu.content_scroll_page_up()
    if state.content_visible_lines > 0 then
        return menu.content_scroll_up(state.content_visible_lines - 1)
    end
    return false
end
-- }}}

-- {{{ menu.content_scroll_top
-- Scroll content panel to the top
function menu.content_scroll_top()
    if state.content_scroll_offset ~= 0 then
        state.content_scroll_offset = 0
        menu.render()
        return true
    end
    return false
end
-- }}}

-- {{{ menu.content_scroll_bottom
-- Scroll content panel to the bottom
function menu.content_scroll_bottom()
    if state.content_total_lines == 0 then return false end

    local max_offset = math.max(0, state.content_total_lines - state.content_visible_lines)
    if state.content_scroll_offset ~= max_offset then
        state.content_scroll_offset = max_offset
        menu.render()
        return true
    end
    return false
end
-- }}}

return menu
