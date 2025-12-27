-- war3map.j Parser
-- Extracts and analyzes JASS script files from WC3 maps.
-- Identifies structural sections (globals, functions, entry points).
-- Validates basic JASS structure without full lexing/parsing.
-- Full parsing handled by issues 304-305 (lexer/parser).

local j = {}

-- {{{ Constants
-- Known generated identifier prefixes
j.PREFIXES = {
    TRIGGER = "gg_trg_",     -- Generated trigger handles
    TIMER = "gg_tim_",       -- Generated timer handles
    UNIT = "gg_unit_",       -- Generated unit handles
    REGION = "gg_rct_",      -- Generated rect handles
    SOUND = "gg_snd_",       -- Generated sound handles
    USER = "udg_",           -- User-defined globals
}

-- Required entry points
j.REQUIRED_FUNCTIONS = {
    "main",
    "config",
}
-- }}}

-- {{{ extract
-- Extracts war3map.j content from an MPQ archive.
-- Returns the raw JASS text as a string, or nil and error message.
-- @param archive: An opened MPQ archive object
-- @return string|nil: Raw JASS text or nil on failure
-- @return string|nil: Error message if extraction failed
function j.extract(archive)
    if not archive then
        return nil, "No archive provided"
    end

    if not archive:has("war3map.j") then
        return nil, "war3map.j not found in archive"
    end

    local data = archive:extract("war3map.j")
    if not data then
        return nil, "Failed to extract war3map.j"
    end

    return data, nil
end
-- }}}

-- {{{ find_globals_section
-- Finds the globals/endglobals block in JASS text.
-- Returns start/end positions and the content.
-- @param text: Raw JASS text
-- @return table|nil: { start, finish, content } or nil if not found
local function find_globals_section(text)
    -- Find "globals" keyword at start of a line
    local start_pos = nil
    local search_pos = 1

    -- Try matching at start of file first
    if text:match("^globals%s*[\r\n]") then
        start_pos = 1
    else
        -- Find "globals" after a newline
        local match_start = text:find("[\r\n]globals%s*[\r\n]", search_pos)
        if match_start then
            start_pos = match_start + 1  -- Skip the leading newline
        end
    end

    if not start_pos then
        return nil
    end

    -- Find matching "endglobals"
    local end_match = text:find("[\r\n]endglobals", start_pos)
    if not end_match then
        -- Try at end of text without trailing newline
        if text:match("endglobals%s*$") then
            end_match = text:find("endglobals%s*$")
        end
    end

    if not end_match then
        return nil
    end

    -- Calculate end position (include "endglobals" word)
    local block_end = end_match + 1 + #"endglobals"  -- +1 for newline

    return {
        start = start_pos,
        finish = block_end,
        content = text:sub(start_pos, block_end),
    }
end
-- }}}

-- {{{ find_functions
-- Finds all function declarations in JASS text.
-- Returns a table of function metadata.
-- Note: Lua %w only matches alphanumeric, not underscore.
-- JASS identifiers use underscores, so we use [%w_]+ pattern.
-- @param text: Raw JASS text
-- @return table: Array of { name, start, finish, takes, returns }
local function find_functions(text)
    local functions = {}

    -- Iterate through all lines to find function declarations
    local line_start = 1
    local line_num = 0

    for line in text:gmatch("([^\n]*)\n?") do
        line_num = line_num + 1

        -- Match function declaration pattern:
        -- function <name> takes <args> returns <type>
        local name, takes, returns = line:match("^function%s+([%w_]+)%s+takes%s+(.-)%s+returns%s+([%w_]+)%s*$")

        if name then
            -- Find the matching endfunction
            local func_start = line_start
            local search_start = line_start + #line + 1

            local end_pos = text:find("\nendfunction", search_start)
            if not end_pos then
                -- Try without leading newline (at start of text)
                end_pos = text:find("endfunction", search_start)
            end

            if end_pos then
                local func_end = end_pos + #"\nendfunction"
                if text:sub(end_pos, end_pos) ~= "\n" then
                    func_end = end_pos + #"endfunction"
                end

                local func = {
                    name = name,
                    start = func_start,
                    finish = func_end,
                    takes = takes,
                    returns = returns,
                }

                -- Determine function type
                if name == "main" then
                    func.type = "entry_main"
                elseif name == "config" then
                    func.type = "entry_config"
                elseif name:match("^Trig_") then
                    if name:match("_Conditions$") then
                        func.type = "trigger_condition"
                    elseif name:match("_Actions$") then
                        func.type = "trigger_action"
                    else
                        func.type = "trigger_helper"
                    end
                elseif name:match("^InitTrig_") then
                    func.type = "trigger_init"
                else
                    func.type = "custom"
                end

                functions[#functions + 1] = func
            end
        end

        line_start = line_start + #line + 1
    end

    return functions
end
-- }}}

-- {{{ find_global_variables
-- Extracts global variable declarations from the globals block.
-- @param globals_content: Content of the globals...endglobals block
-- @return table: Array of { type, name, is_array, initial_value }
local function find_global_variables(globals_content)
    local variables = {}

    if not globals_content then
        return variables
    end

    -- Note: Lua %w only matches alphanumeric, not underscore.
    -- JASS identifiers use underscores, so we use [%w_]+ pattern.

    -- Match variable declaration lines:
    -- <type> [array] <name> [= value]
    for line in globals_content:gmatch("[^\n]+") do
        -- Skip comments and empty lines
        if not line:match("^%s*//") and not line:match("^%s*$")
           and not line:match("^%s*globals") and not line:match("^%s*endglobals") then

            local var_type, name, initial, is_array

            -- Try array pattern first: type array name
            var_type, name = line:match("^%s*([%w_]+)%s+array%s+([%w_]+)%s*$")
            if var_type then
                is_array = true
                initial = nil
            else
                -- Try non-array with initializer: type name = value
                var_type, name, initial = line:match("^%s*([%w_]+)%s+([%w_]+)%s*=%s*(.-)%s*$")
                if var_type then
                    is_array = false
                else
                    -- Try non-array without initializer: type name
                    var_type, name = line:match("^%s*([%w_]+)%s+([%w_]+)%s*$")
                    if var_type then
                        is_array = false
                        initial = nil
                    end
                end
            end

            if var_type and name then
                variables[#variables + 1] = {
                    type = var_type,
                    name = name,
                    is_array = is_array,
                    initial_value = initial,
                }
            end
        end
    end

    return variables
end
-- }}}

-- {{{ parse
-- Parses JASS text and returns structured metadata.
-- @param text: Raw JASS text content
-- @return table: Parsed JASS structure
function j.parse(text)
    if not text or #text == 0 then
        return {
            raw = "",
            globals = nil,
            functions = {},
            variables = {},
            has_main = false,
            has_config = false,
            line_count = 0,
            errors = { "Empty JASS content" },
        }
    end

    local result = {
        raw = text,
        line_count = select(2, text:gsub("\n", "\n")) + 1,
        errors = {},
    }

    -- Find globals section
    result.globals = find_globals_section(text)

    -- Find all functions
    result.functions = find_functions(text)

    -- Parse global variables
    if result.globals then
        result.variables = find_global_variables(result.globals.content)
    else
        result.variables = {}
    end

    -- Check for required entry points
    result.has_main = false
    result.has_config = false

    for _, func in ipairs(result.functions) do
        if func.name == "main" then
            result.has_main = true
        elseif func.name == "config" then
            result.has_config = true
        end
    end

    return result
end
-- }}}

-- {{{ validate
-- Validates JASS structure and returns any errors found.
-- @param parsed: Result from j.parse()
-- @return boolean: true if valid, false if errors found
-- @return table: Array of error messages
function j.validate(parsed)
    local errors = {}

    -- Check for empty content
    if not parsed.raw or #parsed.raw == 0 then
        errors[#errors + 1] = "Empty JASS content"
        return false, errors
    end

    -- Check for globals block
    if not parsed.globals then
        errors[#errors + 1] = "Missing globals/endglobals block"
    end

    -- Check for main() entry point
    if not parsed.has_main then
        errors[#errors + 1] = "Missing main() entry point"
    end

    -- Check for config() entry point
    if not parsed.has_config then
        errors[#errors + 1] = "Missing config() entry point"
    end

    -- Check for balanced blocks (basic check)
    -- Count "globals" at start of line (either start of text or after newline)
    local globals_count = 0
    if parsed.raw:match("^globals%s*[\r\n]") then
        globals_count = globals_count + 1
    end
    globals_count = globals_count + select(2, parsed.raw:gsub("[\r\n]globals%s*[\r\n]", ""))

    -- Count "endglobals" at start of line
    local endglobals_count = 0
    if parsed.raw:match("^endglobals") then
        endglobals_count = endglobals_count + 1
    end
    endglobals_count = endglobals_count + select(2, parsed.raw:gsub("[\r\n]endglobals", ""))

    if globals_count ~= endglobals_count then
        errors[#errors + 1] = string.format(
            "Unbalanced globals blocks: %d globals, %d endglobals",
            globals_count, endglobals_count)
    end

    -- Count "function" at start of line
    local func_count = 0
    if parsed.raw:match("^function%s+") then
        func_count = func_count + 1
    end
    func_count = func_count + select(2, parsed.raw:gsub("[\r\n]function%s+", ""))

    -- Count "endfunction" at start of line
    local endfunc_count = 0
    if parsed.raw:match("^endfunction") then
        endfunc_count = endfunc_count + 1
    end
    endfunc_count = endfunc_count + select(2, parsed.raw:gsub("[\r\n]endfunction", ""))
    if func_count ~= endfunc_count then
        errors[#errors + 1] = string.format(
            "Unbalanced function blocks: %d function, %d endfunction",
            func_count, endfunc_count)
    end

    return #errors == 0, errors
end
-- }}}

-- {{{ get_function_by_name
-- Finds a function by name from parsed JASS.
-- @param parsed: Result from j.parse()
-- @param name: Function name to find
-- @return table|nil: Function metadata or nil if not found
function j.get_function_by_name(parsed, name)
    for _, func in ipairs(parsed.functions) do
        if func.name == name then
            return func
        end
    end
    return nil
end
-- }}}

-- {{{ get_functions_by_type
-- Gets all functions of a specific type.
-- @param parsed: Result from j.parse()
-- @param func_type: One of: entry_main, entry_config, trigger_condition,
--                   trigger_action, trigger_init, trigger_helper, custom
-- @return table: Array of matching functions
function j.get_functions_by_type(parsed, func_type)
    local result = {}
    for _, func in ipairs(parsed.functions) do
        if func.type == func_type then
            result[#result + 1] = func
        end
    end
    return result
end
-- }}}

-- {{{ get_user_globals
-- Gets all user-defined global variables (udg_* prefix).
-- @param parsed: Result from j.parse()
-- @return table: Array of user-defined variable declarations
function j.get_user_globals(parsed)
    local result = {}
    for _, var in ipairs(parsed.variables) do
        if var.name:match("^udg_") then
            result[#result + 1] = var
        end
    end
    return result
end
-- }}}

-- {{{ get_trigger_globals
-- Gets all generated trigger handle variables (gg_trg_* prefix).
-- @param parsed: Result from j.parse()
-- @return table: Array of trigger handle variable declarations
function j.get_trigger_globals(parsed)
    local result = {}
    for _, var in ipairs(parsed.variables) do
        if var.name:match("^gg_trg_") then
            result[#result + 1] = var
        end
    end
    return result
end
-- }}}

-- {{{ format
-- Returns a human-readable summary of parsed JASS.
-- @param parsed: Result from j.parse()
-- @return string: Formatted summary
function j.format(parsed)
    local lines = {}

    lines[#lines + 1] = "=== JASS Script Summary ==="
    lines[#lines + 1] = string.format("Lines: %d", parsed.line_count)
    lines[#lines + 1] = string.format("Size: %d bytes", #parsed.raw)
    lines[#lines + 1] = ""

    -- Globals info
    if parsed.globals then
        lines[#lines + 1] = string.format("Globals block: lines %d-%d",
            select(2, parsed.raw:sub(1, parsed.globals.start):gsub("\n", "")) + 1,
            select(2, parsed.raw:sub(1, parsed.globals.finish):gsub("\n", "")) + 1)
        lines[#lines + 1] = string.format("  Variables: %d", #parsed.variables)

        -- Count by type
        local user_count = 0
        local trigger_count = 0
        for _, var in ipairs(parsed.variables) do
            if var.name:match("^udg_") then
                user_count = user_count + 1
            elseif var.name:match("^gg_") then
                trigger_count = trigger_count + 1
            end
        end
        lines[#lines + 1] = string.format("    User-defined (udg_*): %d", user_count)
        lines[#lines + 1] = string.format("    Generated (gg_*): %d", trigger_count)
    else
        lines[#lines + 1] = "Globals block: NOT FOUND"
    end
    lines[#lines + 1] = ""

    -- Functions info
    lines[#lines + 1] = string.format("Functions: %d", #parsed.functions)

    -- Count by type
    local type_counts = {}
    for _, func in ipairs(parsed.functions) do
        type_counts[func.type] = (type_counts[func.type] or 0) + 1
    end

    for type_name, count in pairs(type_counts) do
        lines[#lines + 1] = string.format("  %s: %d", type_name, count)
    end
    lines[#lines + 1] = ""

    -- Entry points
    lines[#lines + 1] = "Entry Points:"
    lines[#lines + 1] = string.format("  main(): %s", parsed.has_main and "FOUND" or "MISSING")
    lines[#lines + 1] = string.format("  config(): %s", parsed.has_config and "FOUND" or "MISSING")

    -- Validation
    local valid, errors = j.validate(parsed)
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Validation: %s", valid and "PASSED" or "FAILED")
    if not valid then
        for _, err in ipairs(errors) do
            lines[#lines + 1] = "  ERROR: " .. err
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

return j
