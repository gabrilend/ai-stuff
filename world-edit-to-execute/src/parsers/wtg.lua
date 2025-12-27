-- war3map.wtg Parser
-- Parses WC3 trigger definition files containing GUI trigger structures.
-- The WTG format stores trigger categories, variables, trigger metadata,
-- and ECA (Event/Condition/Action) function trees.
--
-- This parser is implemented incrementally across issues 301a-301e:
-- 301a: Header and categories (this initial implementation)
-- 301b: Variable definitions
-- 301c: Trigger metadata
-- 301d: ECA function structures
-- 301e: Parameter parsing

local compat = require("compat")

local wtg = {}

-- {{{ Constants
-- WTG format versions
-- Version 4: Reign of Chaos (pre-TFT)
-- Version 7: The Frozen Throne (most common)
local SUPPORTED_VERSIONS = { [4] = true, [7] = true }

-- Category types
local CATEGORY_TYPE = {
    NORMAL = 0,
    COMMENT = 1,
}

local CATEGORY_TYPE_NAMES = {
    [0] = "normal",
    [1] = "comment",
}
-- }}}

-- {{{ Binary reading utilities
local function read_int32(data, pos)
    return compat.unpack_int32(data, pos)
end

local function read_uint32(data, pos)
    return compat.unpack_uint32(data, pos)
end

-- {{{ read_string
-- Reads a null-terminated string from data starting at pos.
-- Returns: string, new_position, error_message
local function read_string(data, pos)
    local str_end = data:find("\0", pos, true)
    if not str_end then
        return nil, pos, "Unterminated string at offset " .. pos
    end
    return data:sub(pos, str_end - 1), str_end + 1, nil
end
-- }}}
-- }}}

-- {{{ parse_header
-- Parses the WTG file header and validates magic bytes and version.
-- Returns: { version, _offset }, error_message
local function parse_header(data, offset)
    offset = offset or 1

    -- Check minimum size for header
    if #data < offset + 7 then
        return nil, "Invalid WTG file: too short (need at least 8 bytes for header)"
    end

    -- Validate magic bytes "WTG!"
    local magic = data:sub(offset, offset + 3)
    if magic ~= "WTG!" then
        return nil, "Invalid WTG file: expected 'WTG!' magic, got '" .. magic .. "'"
    end
    offset = offset + 4

    -- Extract version (int32 little-endian)
    local version = read_uint32(data, offset)
    offset = offset + 4

    -- Validate supported version
    if not SUPPORTED_VERSIONS[version] then
        return nil, "Unsupported WTG version: " .. version .. " (expected 4 or 7)"
    end

    return {
        version = version,
        _offset = offset,
    }, nil
end
-- }}}

-- {{{ Common WC3 variable types
-- These are the type strings stored in WTG files
local VARIABLE_TYPES = {
    "unit", "integer", "real", "string", "boolean",
    "location", "rect", "group", "timer", "trigger",
    "player", "force", "effect", "sound", "item",
    "ability", "buff", "destructable", "unitcode",
    "itemcode", "abilcode", "quest", "questitem",
    "defeatcondition", "timerdialog", "leaderboard",
    "multiboard", "multiboarditem", "trackable",
    "dialog", "button", "texttag", "lightning",
    "image", "ubersplat", "region", "fogstate",
    "fogmodifier", "hashtable", "camerasetup",
}
-- }}}

-- {{{ parse_categories
-- Parses the trigger category definitions.
-- Categories provide organizational structure for triggers in the World Editor.
-- Returns: categories_array, new_offset, error_message
local function parse_categories(data, offset)
    -- Check we have enough data for count
    if #data < offset + 3 then
        return nil, offset, "Unexpected end of data while reading category count"
    end

    -- Read category count
    local count = read_uint32(data, offset)
    offset = offset + 4

    local categories = {}

    for i = 1, count do
        -- Check we have enough data for category index
        if #data < offset + 3 then
            return nil, offset, "Unexpected end of data while parsing category " .. i
        end

        -- Category index (int32)
        local index = read_uint32(data, offset)
        offset = offset + 4

        -- Category name (null-terminated string)
        local name, new_offset, err = read_string(data, offset)
        if err then
            return nil, offset, "Error reading category " .. i .. " name: " .. err
        end
        offset = new_offset

        -- Check we have enough data for category type
        if #data < offset + 3 then
            return nil, offset, "Unexpected end of data while reading category " .. i .. " type"
        end

        -- Category type (int32): 0 = normal, 1 = comment
        local cat_type_num = read_uint32(data, offset)
        offset = offset + 4

        local cat_type = CATEGORY_TYPE_NAMES[cat_type_num] or "unknown"

        categories[#categories + 1] = {
            index = index,
            name = name,
            type = cat_type,
        }
    end

    return categories, offset, nil
end
-- }}}

-- {{{ parse_variables
-- Parses the variable definitions section (301b).
-- Variables are user-defined globals (udg_*) that triggers reference.
-- Returns: variables_array, new_offset, error_message
local function parse_variables(data, offset)
    -- Check we have enough data for count
    if #data < offset + 3 then
        return nil, offset, "Unexpected end of data while reading variable count"
    end

    -- Read variable count
    local count = read_uint32(data, offset)
    offset = offset + 4

    local variables = {}

    for i = 1, count do
        local var = {}

        -- Variable name (null-terminated)
        local name, new_offset, err = read_string(data, offset)
        if err then
            return nil, offset, "Error reading variable " .. i .. " name: " .. err
        end
        var.name = name
        offset = new_offset

        -- Variable type (null-terminated)
        local var_type
        var_type, new_offset, err = read_string(data, offset)
        if err then
            return nil, offset, "Error reading variable " .. i .. " type: " .. err
        end
        var.type = var_type
        offset = new_offset

        -- Check we have enough data for remaining fields (unknown + is_array + array_size + is_initialized = 16 bytes)
        if #data < offset + 15 then
            return nil, offset, "Unexpected end of data while parsing variable " .. i .. " fields"
        end

        -- Unknown field (always 1?) - read and discard
        -- Its purpose is unclear - possibly a version marker or reserved field
        local _unknown = read_uint32(data, offset)
        offset = offset + 4

        -- Is array (int32: 0 or 1)
        local is_array_num = read_uint32(data, offset)
        var.is_array = (is_array_num == 1)
        offset = offset + 4

        -- Array size (int32, only meaningful if is_array)
        local array_size = read_uint32(data, offset)
        if var.is_array then
            var.array_size = array_size
        else
            var.array_size = 0
        end
        offset = offset + 4

        -- Is initialized (int32: 0 or 1)
        local is_init_num = read_uint32(data, offset)
        var.is_initialized = (is_init_num == 1)
        offset = offset + 4

        -- Initial value (null-terminated, only present if initialized)
        if var.is_initialized then
            var.initial_value, new_offset, err = read_string(data, offset)
            if err then
                return nil, offset, "Error reading variable " .. i .. " initial value: " .. err
            end
            offset = new_offset
        else
            var.initial_value = nil
        end

        variables[#variables + 1] = var
    end

    return variables, offset, nil
end
-- }}}

-- {{{ ECA type constants (for 301c/301d)
local ECA_TYPE = {
    EVENT = 0,
    CONDITION = 1,
    ACTION = 2,
}

local ECA_TYPE_NAMES = {
    [0] = "event",
    [1] = "condition",
    [2] = "action",
}
-- }}}

-- {{{ Parameter type constants (for 301e)
-- Parameter types stored in WTG files
-- Type -1 indicates an invalid/disabled parameter
local PARAM_TYPE = {
    INVALID = -1,
    PRESET = 0,     -- Predefined value from trigger data (e.g., "OperatorAdd")
    VARIABLE = 1,   -- Variable reference (e.g., "udg_Counter")
    FUNCTION = 2,   -- Function call with sub-parameters
    STRING = 3,     -- String literal (including numbers as strings)
}

local PARAM_TYPE_NAMES = {
    [-1] = "invalid",
    [0] = "preset",
    [1] = "variable",
    [2] = "function",
    [3] = "string",
}
-- }}}

-- {{{ parse_parameter
-- Parses a single parameter from ECA data (301e).
-- Parameters can contain sub-parameters (for function calls) and array indices.
-- Returns: parameter_table, new_offset, error_message
local function parse_parameter(data, offset, depth)
    depth = depth or 0

    -- Prevent infinite recursion on malformed data
    if depth > 50 then
        return nil, offset, "Parameter nesting too deep (>50 levels)"
    end

    local param = {}

    -- Check minimum data for type field
    if #data < offset + 3 then
        return nil, offset, "Unexpected end of data in parameter type"
    end

    -- Parameter type (int32, SIGNED - can be -1 for invalid/disabled)
    local type_id = read_int32(data, offset)
    offset = offset + 4
    param.type = type_id
    param.type_name = PARAM_TYPE_NAMES[type_id] or "unknown"

    -- Parameter value (null-terminated string)
    local value, new_offset, err = read_string(data, offset)
    if err then
        return nil, offset, "Error in parameter value: " .. err
    end
    param.value = value
    offset = new_offset

    -- Check for has_sub field
    if #data < offset + 3 then
        return nil, offset, "Unexpected end of data in parameter has_sub"
    end

    -- Has sub-parameters (int32: 0 or 1)
    local has_sub = read_uint32(data, offset) == 1
    offset = offset + 4

    if has_sub then
        param.has_sub = true
        param.sub_function = {}

        -- Check for sub-parameter header
        if #data < offset + 3 then
            return nil, offset, "Unexpected end of data in sub-parameter header"
        end

        -- Function type
        param.sub_function.type = read_int32(data, offset)
        offset = offset + 4

        -- Function name
        local func_name
        func_name, new_offset, err = read_string(data, offset)
        if err then
            return nil, offset, "Error in sub-parameter function name: " .. err
        end
        param.sub_function.name = func_name
        offset = new_offset

        -- Begin flag
        if #data < offset + 7 then
            return nil, offset, "Unexpected end of data in sub-parameter begin/count"
        end
        param.sub_function.begin_flag = read_uint32(data, offset)
        offset = offset + 4

        -- Sub-parameter count
        local sub_count = read_uint32(data, offset)
        offset = offset + 4

        -- Recursively parse sub-parameters
        param.sub_function.parameters = {}
        for s = 1, sub_count do
            local sub_param, sub_err
            sub_param, offset, sub_err = parse_parameter(data, offset, depth + 1)
            if sub_err then
                return nil, offset, sub_err
            end
            param.sub_function.parameters[#param.sub_function.parameters + 1] = sub_param
        end
    else
        param.has_sub = false
    end

    -- Check for array index field
    if #data < offset + 3 then
        return nil, offset, "Unexpected end of data in parameter is_array"
    end

    -- Is array index (int32: 0 or 1)
    local is_array = read_uint32(data, offset) == 1
    offset = offset + 4

    if is_array then
        param.is_array = true
        -- Array index is itself a parameter (recursive)
        local index_param, idx_err
        index_param, offset, idx_err = parse_parameter(data, offset, depth + 1)
        if idx_err then
            return nil, offset, idx_err
        end
        param.array_index = index_param
    else
        param.is_array = false
    end

    return param, offset, nil
end

-- Alias for backwards compatibility
local parse_parameter_placeholder = parse_parameter
-- }}}

-- {{{ skip_parameter
-- Skips over a single parameter in the ECA structure.
-- Parameters have a recursive structure (sub-parameters, array indices).
-- This is a lightweight skipper that doesn't extract values - used by 301c.
-- 301e will implement full parameter parsing.
-- Returns: new_offset, error_message
local function skip_parameter(data, offset, depth)
    depth = depth or 0

    -- Prevent infinite recursion on malformed data
    if depth > 50 then
        return offset, "Parameter nesting too deep (>50 levels)"
    end

    -- Check minimum data for type field
    if #data < offset + 3 then
        return offset, "Unexpected end of data in parameter type"
    end

    -- Parameter type (int32, SIGNED - can be -1 for invalid/disabled)
    local _param_type = read_int32(data, offset)
    offset = offset + 4

    -- Parameter value (null-terminated string)
    local _, new_offset, err = read_string(data, offset)
    if err then
        return offset, "Error in parameter value: " .. err
    end
    offset = new_offset

    -- Check for has_sub field
    if #data < offset + 3 then
        return offset, "Unexpected end of data in parameter has_sub"
    end

    -- Has sub-parameters (int32: 0 or 1)
    local has_sub = read_uint32(data, offset) == 1
    offset = offset + 4

    if has_sub then
        -- Sub-parameters have additional structure:
        -- Function type (int32) + function name (string) + begin flag (int32) + count (int32)
        if #data < offset + 3 then
            return offset, "Unexpected end of data in sub-parameter header"
        end

        -- Function type
        offset = offset + 4

        -- Function name
        _, new_offset, err = read_string(data, offset)
        if err then
            return offset, "Error in sub-parameter function name: " .. err
        end
        offset = new_offset

        -- Begin flag
        if #data < offset + 7 then
            return offset, "Unexpected end of data in sub-parameter begin/count"
        end
        offset = offset + 4

        -- Sub-parameter count
        local sub_count = read_uint32(data, offset)
        offset = offset + 4

        -- Recursively skip sub-parameters
        for s = 1, sub_count do
            local skip_err
            offset, skip_err = skip_parameter(data, offset, depth + 1)
            if skip_err then
                return offset, skip_err
            end
        end
    end

    -- Check for array index field
    if #data < offset + 3 then
        return offset, "Unexpected end of data in parameter is_array"
    end

    -- Is array index (int32: 0 or 1)
    local is_array = read_uint32(data, offset) == 1
    offset = offset + 4

    if is_array then
        -- Array index is itself a parameter (recursive)
        local skip_err
        offset, skip_err = skip_parameter(data, offset, depth + 1)
        if skip_err then
            return offset, skip_err
        end
    end

    return offset, nil
end
-- }}}

-- {{{ skip_single_eca
-- Skips over a single ECA (Event/Condition/Action) function.
-- ECAs are recursive - they can contain nested ECAs (for control flow).
-- Returns: new_offset, error_message
local function skip_single_eca(data, offset, depth)
    depth = depth or 0

    -- Prevent stack overflow on malformed data
    if depth > 100 then
        return offset, "ECA nesting too deep (>100 levels)"
    end

    -- Check minimum data for type field
    if #data < offset + 3 then
        return offset, "Unexpected end of data in ECA type"
    end

    -- Function type (int32: 0=event, 1=condition, 2=action)
    offset = offset + 4

    -- Function name (null-terminated)
    local _, new_offset, err = read_string(data, offset)
    if err then
        return offset, "Error in ECA function name: " .. err
    end
    offset = new_offset

    -- Check for is_enabled and param_count fields
    if #data < offset + 7 then
        return offset, "Unexpected end of data in ECA is_enabled/param_count"
    end

    -- Is enabled (int32)
    offset = offset + 4

    -- Parameter count
    local param_count = read_uint32(data, offset)
    offset = offset + 4

    -- Skip all parameters
    for p = 1, param_count do
        local skip_err
        offset, skip_err = skip_parameter(data, offset, 0)
        if skip_err then
            return offset, "Error skipping parameter " .. p .. ": " .. skip_err
        end
    end

    -- Check for nested ECA count
    if #data < offset + 3 then
        return offset, "Unexpected end of data in ECA nested count"
    end

    -- Nested ECA count (for control flow structures like IfThenElse, loops)
    local nested_count = read_uint32(data, offset)
    offset = offset + 4

    -- Recursively skip nested ECAs
    for n = 1, nested_count do
        local skip_err
        offset, skip_err = skip_single_eca(data, offset, depth + 1)
        if skip_err then
            return offset, "Error skipping nested ECA " .. n .. ": " .. skip_err
        end
    end

    return offset, nil
end
-- }}}

-- {{{ skip_eca_section
-- Skips over multiple ECAs for a trigger.
-- count: number of top-level ECAs to skip
-- Returns: new_offset, error_message
local function skip_eca_section(data, offset, count)
    for i = 1, count do
        local err
        offset, err = skip_single_eca(data, offset, 0)
        if err then
            return offset, "Error skipping ECA " .. i .. ": " .. err
        end
    end
    return offset, nil
end
-- }}}

-- {{{ parse_single_eca
-- Parses a single ECA (Event/Condition/Action) function (301d).
-- ECAs are recursive - they can contain nested ECAs (for control flow).
-- Returns: eca_table, new_offset, error_message
local function parse_single_eca(data, offset, depth)
    depth = depth or 0

    -- Prevent stack overflow on malformed data
    if depth > 100 then
        return nil, offset, "ECA nesting too deep (>100 levels)"
    end

    local eca = {}

    -- Check minimum data for type field
    if #data < offset + 3 then
        return nil, offset, "Unexpected end of data in ECA type"
    end

    -- Function type (int32: 0=event, 1=condition, 2=action)
    local type_num = read_uint32(data, offset)
    offset = offset + 4
    eca.type = ECA_TYPE_NAMES[type_num] or "unknown"
    eca.type_id = type_num

    -- Function name (null-terminated)
    local name, new_offset, err = read_string(data, offset)
    if err then
        return nil, offset, "Error in ECA function name: " .. err
    end
    eca.name = name
    offset = new_offset

    -- Check for is_enabled and param_count fields
    if #data < offset + 7 then
        return nil, offset, "Unexpected end of data in ECA is_enabled/param_count"
    end

    -- Is enabled (int32)
    eca.is_enabled = read_uint32(data, offset) == 1
    offset = offset + 4

    -- Parameter count
    local param_count = read_uint32(data, offset)
    offset = offset + 4

    -- Parse all parameters (using placeholder from 301d, full parsing in 301e)
    eca.parameters = {}
    for p = 1, param_count do
        local param, param_err
        param, offset, param_err = parse_parameter_placeholder(data, offset, 0)
        if param_err then
            return nil, offset, "Error parsing parameter " .. p .. ": " .. param_err
        end
        eca.parameters[#eca.parameters + 1] = param
    end

    -- Check for nested ECA count
    if #data < offset + 3 then
        return nil, offset, "Unexpected end of data in ECA nested count"
    end

    -- Nested ECA count (for control flow structures like IfThenElse, loops)
    local nested_count = read_uint32(data, offset)
    offset = offset + 4

    -- Recursively parse nested ECAs
    eca.children = {}
    for n = 1, nested_count do
        local child, child_err
        child, offset, child_err = parse_single_eca(data, offset, depth + 1)
        if child_err then
            return nil, offset, "Error parsing nested ECA " .. n .. ": " .. child_err
        end
        eca.children[#eca.children + 1] = child
    end

    return eca, offset, nil
end
-- }}}

-- {{{ parse_trigger_ecas
-- Parses all ECAs for a single trigger, sorting them into categories (301d).
-- Returns: events, conditions, actions, new_offset, error_message
local function parse_trigger_ecas(data, offset, eca_count)
    local events = {}
    local conditions = {}
    local actions = {}

    for i = 1, eca_count do
        local eca, new_offset, err = parse_single_eca(data, offset, 0)
        if err then
            return nil, nil, nil, new_offset, "Error parsing ECA " .. i .. ": " .. err
        end
        offset = new_offset

        -- Sort into appropriate category based on type
        if eca.type == "event" then
            events[#events + 1] = eca
        elseif eca.type == "condition" then
            conditions[#conditions + 1] = eca
        elseif eca.type == "action" then
            actions[#actions + 1] = eca
        end
        -- Unknown types are silently dropped
    end

    return events, conditions, actions, offset, nil
end
-- }}}

-- {{{ parse_triggers
-- Parses trigger metadata for all triggers (301c).
-- Extracts metadata (name, flags, category) but skips ECA content.
-- ECA parsing is deferred to 301d using the stored offsets.
-- Returns: triggers_array, eca_offsets_array, new_offset, error_message
local function parse_triggers(data, offset)
    -- Check we have enough data for count
    if #data < offset + 3 then
        return nil, nil, offset, "Unexpected end of data while reading trigger count"
    end

    -- Read trigger count
    local count = read_uint32(data, offset)
    offset = offset + 4

    local triggers = {}
    local eca_offsets = {}

    for i = 1, count do
        local trigger = {}

        -- Trigger name (null-terminated)
        local name, new_offset, err = read_string(data, offset)
        if err then
            return nil, nil, offset, "Error reading trigger " .. i .. " name: " .. err
        end
        trigger.name = name
        offset = new_offset

        -- Trigger description (null-terminated)
        local desc
        desc, new_offset, err = read_string(data, offset)
        if err then
            return nil, nil, offset, "Error reading trigger " .. i .. " description: " .. err
        end
        trigger.description = desc
        offset = new_offset

        -- Check we have enough data for the boolean flags and counts
        -- is_comment + is_enabled + is_custom_text + is_initially_on + run_on_init + category_index + eca_count = 28 bytes
        if #data < offset + 27 then
            return nil, nil, offset, "Unexpected end of data while parsing trigger " .. i .. " flags"
        end

        -- Is comment trigger (int32: 0 or 1)
        trigger.is_comment = read_uint32(data, offset) == 1
        offset = offset + 4

        -- Is enabled (int32: 0 or 1)
        trigger.is_enabled = read_uint32(data, offset) == 1
        offset = offset + 4

        -- Is custom text (int32: 0 or 1)
        trigger.is_custom_text = read_uint32(data, offset) == 1
        offset = offset + 4

        -- Is initially on (int32: 0 or 1)
        trigger.is_initially_on = read_uint32(data, offset) == 1
        offset = offset + 4

        -- Run on map init (int32: 0 or 1)
        trigger.run_on_init = read_uint32(data, offset) == 1
        offset = offset + 4

        -- Category index (int32)
        trigger.category_index = read_uint32(data, offset)
        offset = offset + 4

        -- ECA count (int32) - number of top-level ECA functions
        trigger.eca_count = read_uint32(data, offset)
        offset = offset + 4

        -- Record where ECA data starts for this trigger (for 301d)
        eca_offsets[#eca_offsets + 1] = offset

        -- Initialize empty ECA arrays (to be populated by 301d)
        trigger.events = {}
        trigger.conditions = {}
        trigger.actions = {}

        -- Skip ECA data - 301d will parse it using stored offsets
        local skip_err
        offset, skip_err = skip_eca_section(data, offset, trigger.eca_count)
        if skip_err then
            return nil, nil, offset, "Error skipping ECAs for trigger '" .. trigger.name .. "': " .. skip_err
        end

        triggers[#triggers + 1] = trigger
    end

    return triggers, eca_offsets, offset, nil
end
-- }}}

-- {{{ wtg.validate_categories
-- Validates that all trigger category_index values reference valid categories.
-- Returns: is_valid (boolean), errors (array of error strings)
function wtg.validate_categories(parsed)
    if not parsed or not parsed.categories or not parsed.triggers then
        return false, {"Missing categories or triggers in parsed data"}
    end

    -- Build lookup of valid category indices
    local category_indices = {}
    for _, cat in ipairs(parsed.categories) do
        category_indices[cat.index] = true
    end

    local errors = {}
    for i, trigger in ipairs(parsed.triggers) do
        if not category_indices[trigger.category_index] then
            errors[#errors + 1] = string.format(
                "Trigger '%s' references invalid category %d",
                trigger.name, trigger.category_index
            )
        end
    end

    return #errors == 0, errors
end
-- }}}

-- {{{ wtg.parse_eca_pass
-- Second pass: populates trigger ECA arrays using stored offsets (301d).
-- This separates metadata parsing (fast) from ECA parsing (potentially slow).
-- Call after wtg.parse() with parse_eca=false, then call this with the result.
-- Returns: modified parsed result, or nil and error message
function wtg.parse_eca_pass(data, parsed)
    if not parsed or not parsed.triggers then
        return nil, "Invalid parsed data: missing triggers"
    end

    if not parsed._trigger_eca_offsets then
        return nil, "No ECA offsets stored - was parse_eca already run?"
    end

    for i, trigger in ipairs(parsed.triggers) do
        local offset = parsed._trigger_eca_offsets[i]

        if trigger.eca_count > 0 then
            local events, conditions, actions, new_offset, err =
                parse_trigger_ecas(data, offset, trigger.eca_count)

            if err then
                return nil, string.format(
                    "Error parsing trigger '%s': %s",
                    trigger.name, err
                )
            end

            trigger.events = events
            trigger.conditions = conditions
            trigger.actions = actions
        end
    end

    -- Clean up internal tracking - ECA offsets no longer needed
    parsed._trigger_eca_offsets = nil

    return parsed, nil
end
-- }}}

-- {{{ wtg.parse
-- Main entry point: parses a war3map.wtg file.
-- Implements 301a (header + categories), 301b (variables), 301c (trigger metadata),
-- and optionally 301d (ECA parsing).
--
-- data: raw binary data string
-- options: optional table with parsing options
--   - parse_eca: boolean, whether to parse ECA structures (default: true)
--
-- Returns: structured trigger data table, or nil and error message
function wtg.parse(data, options)
    options = options or {}

    if not data or #data < 8 then
        return nil, "Invalid data: too short or nil"
    end

    -- Parse header (301a)
    local result, err = parse_header(data)
    if err then
        return nil, err
    end

    -- Parse categories (301a)
    local categories, offset, cat_err = parse_categories(data, result._offset)
    if cat_err then
        return nil, cat_err
    end

    result.categories = categories
    result._offset = offset

    -- Parse variables (301b)
    local variables, var_offset, var_err = parse_variables(data, result._offset)
    if var_err then
        return nil, var_err
    end

    result.variables = variables
    result._offset = var_offset

    -- Parse triggers (301c) - metadata only, ECAs are skipped
    local triggers, eca_offsets, trig_offset, trig_err = parse_triggers(data, result._offset)
    if trig_err then
        return nil, trig_err
    end

    result.triggers = triggers
    result._trigger_eca_offsets = eca_offsets
    result._offset = trig_offset

    -- Parse ECAs (301d) - optional, enabled by default
    if options.parse_eca ~= false then
        result, err = wtg.parse_eca_pass(data, result)
        if err then
            return nil, err
        end
    end

    return result, nil
end
-- }}}

-- {{{ wtg.format_parameter
-- Returns a human-readable string representation of a parameter (301e).
-- Useful for debugging and displaying parameter trees.
function wtg.format_parameter(param, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    local lines = {}

    -- Format main parameter
    local type_str = param.type_name or PARAM_TYPE_NAMES[param.type] or "unknown"
    local value_str = param.value or "(none)"
    lines[#lines + 1] = string.format("%s[%s] %s", prefix, type_str, value_str)

    -- Format sub-function parameters
    if param.has_sub and param.sub_function then
        lines[#lines + 1] = prefix .. "  sub-function: " .. (param.sub_function.name or "?")
        for _, sub in ipairs(param.sub_function.parameters or {}) do
            lines[#lines + 1] = wtg.format_parameter(sub, indent + 2)
        end
    end

    -- Format array index
    if param.is_array and param.array_index then
        lines[#lines + 1] = prefix .. "  [index]:"
        lines[#lines + 1] = wtg.format_parameter(param.array_index, indent + 2)
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ wtg.validate_parameter
-- Validates a parameter structure for common issues (301e).
-- Returns: is_valid (boolean), issues (array of issue strings)
function wtg.validate_parameter(param, path)
    path = path or "param"
    local issues = {}

    if not param then
        issues[#issues + 1] = path .. ": parameter is nil"
        return false, issues
    end

    -- Check type is valid
    if param.type == nil then
        issues[#issues + 1] = path .. ": missing type field"
    elseif param.type < -1 or param.type > 3 then
        issues[#issues + 1] = string.format("%s: unknown type %d", path, param.type)
    end

    -- Variable parameters should have a name
    if param.type == PARAM_TYPE.VARIABLE then
        if not param.value or param.value == "" then
            issues[#issues + 1] = path .. ": variable parameter has empty name"
        end
    end

    -- Invalid parameters should not have complex content
    if param.type == PARAM_TYPE.INVALID then
        if param.has_sub then
            issues[#issues + 1] = path .. ": invalid parameter has sub-parameters"
        end
        if param.is_array then
            issues[#issues + 1] = path .. ": invalid parameter has array index"
        end
    end

    -- Recursively validate sub-function parameters
    if param.has_sub and param.sub_function then
        for i, sub in ipairs(param.sub_function.parameters or {}) do
            local sub_path = string.format("%s.sub[%d]", path, i)
            local _, sub_issues = wtg.validate_parameter(sub, sub_path)
            for _, issue in ipairs(sub_issues) do
                issues[#issues + 1] = issue
            end
        end
    end

    -- Recursively validate array index
    if param.is_array and param.array_index then
        local _, idx_issues = wtg.validate_parameter(param.array_index, path .. ".index")
        for _, issue in ipairs(idx_issues) do
            issues[#issues + 1] = issue
        end
    end

    return #issues == 0, issues
end
-- }}}

-- {{{ wtg.format
-- Returns a human-readable summary of the parsed WTG data.
function wtg.format(result)
    local lines = {}

    lines[#lines + 1] = "=== Trigger Definitions (wtg) ==="
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Version: " .. result.version
    lines[#lines + 1] = "Category Count: " .. #result.categories
    lines[#lines + 1] = ""

    if #result.categories == 0 then
        lines[#lines + 1] = "(No categories defined)"
    else
        lines[#lines + 1] = "Categories:"
        for i, cat in ipairs(result.categories) do
            local type_marker = ""
            if cat.type == "comment" then
                type_marker = " [comment]"
            end
            lines[#lines + 1] = string.format("  [%d] %s%s",
                cat.index, cat.name, type_marker)
        end
    end

    -- Variables section
    if result.variables then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Variable Count: " .. #result.variables
        if #result.variables > 0 then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Variables:"
            for i, var in ipairs(result.variables) do
                local array_marker = ""
                if var.is_array then
                    array_marker = string.format("[%d]", var.array_size)
                end
                local init_marker = ""
                if var.is_initialized then
                    init_marker = string.format(" = %q", var.initial_value or "")
                end
                lines[#lines + 1] = string.format("  %s: %s%s%s",
                    var.name, var.type, array_marker, init_marker)
            end
        end
    end

    -- Triggers section (301c)
    if result.triggers then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Trigger Count: " .. #result.triggers
        if #result.triggers > 0 then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Triggers:"
            for i, trig in ipairs(result.triggers) do
                local flags = {}
                if trig.is_comment then flags[#flags + 1] = "comment" end
                if not trig.is_enabled then flags[#flags + 1] = "disabled" end
                if trig.is_custom_text then flags[#flags + 1] = "custom" end
                if trig.run_on_init then flags[#flags + 1] = "init" end
                if not trig.is_initially_on then flags[#flags + 1] = "off" end

                local flag_str = ""
                if #flags > 0 then
                    flag_str = " [" .. table.concat(flags, ", ") .. "]"
                end

                -- Show ECA counts if parsed (301d)
                local eca_info = string.format("eca=%d", trig.eca_count)
                if #trig.events > 0 or #trig.conditions > 0 or #trig.actions > 0 then
                    eca_info = string.format("E=%d C=%d A=%d",
                        #trig.events, #trig.conditions, #trig.actions)
                end

                lines[#lines + 1] = string.format("  %s (cat=%d, %s)%s",
                    trig.name, trig.category_index, eca_info, flag_str)

                if trig.description and trig.description ~= "" then
                    lines[#lines + 1] = "    " .. trig.description
                end

                -- Show ECA function names if parsed (301d)
                if #trig.events > 0 then
                    for _, ev in ipairs(trig.events) do
                        local disabled = ev.is_enabled and "" or " [disabled]"
                        lines[#lines + 1] = "      Event: " .. ev.name .. disabled
                    end
                end
                if #trig.conditions > 0 then
                    for _, cond in ipairs(trig.conditions) do
                        local disabled = cond.is_enabled and "" or " [disabled]"
                        lines[#lines + 1] = "      Condition: " .. cond.name .. disabled
                    end
                end
                if #trig.actions > 0 then
                    for _, act in ipairs(trig.actions) do
                        local disabled = act.is_enabled and "" or " [disabled]"
                        local children = #act.children > 0 and string.format(" (%d children)", #act.children) or ""
                        lines[#lines + 1] = "      Action: " .. act.name .. disabled .. children
                    end
                end
            end
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ Expose internal functions for sub-issues and testing
-- These internal functions are exposed for use by 301b-301e implementations
-- and for unit testing. They should be considered semi-private.
wtg._read_string = read_string
wtg._read_int32 = read_int32
wtg._read_uint32 = read_uint32
wtg._parse_header = parse_header
wtg._parse_categories = parse_categories
wtg._parse_variables = parse_variables
wtg._parse_triggers = parse_triggers
wtg._skip_parameter = skip_parameter
wtg._skip_single_eca = skip_single_eca
wtg._skip_eca_section = skip_eca_section
wtg._parse_parameter = parse_parameter
wtg._parse_parameter_placeholder = parse_parameter_placeholder  -- alias
wtg._parse_single_eca = parse_single_eca
wtg._parse_trigger_ecas = parse_trigger_ecas
-- }}}

-- {{{ Constants exports
wtg.SUPPORTED_VERSIONS = SUPPORTED_VERSIONS
wtg.CATEGORY_TYPE = CATEGORY_TYPE
wtg.CATEGORY_TYPE_NAMES = CATEGORY_TYPE_NAMES
wtg.VARIABLE_TYPES = VARIABLE_TYPES
wtg.ECA_TYPE = ECA_TYPE
wtg.ECA_TYPE_NAMES = ECA_TYPE_NAMES
wtg.PARAM_TYPE = PARAM_TYPE
wtg.PARAM_TYPE_NAMES = PARAM_TYPE_NAMES
-- }}}

return wtg
