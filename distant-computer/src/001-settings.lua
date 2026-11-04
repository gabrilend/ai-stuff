-- 001-settings.lua - reads a program's settings out of input/, and refuses
-- anything it was not told to expect.
--
-- In plain terms: every distant-computer program begins here. It names the
-- settings it needs (what they are called, what kind of value each is, and
-- which must be present), and this reads the program's file in input/ and
-- hands back the values. A typo, a missing line or a word where a number
-- belongs stops the program before it starts, naming the file and the line.
-- There are no hidden defaults: whatever a program uses is written in its
-- input file, so reading that file tells you how the program will run.
--
-- The line format is shared with the house rmail contacts file and with
-- guide-feature's settings, so the owner learns one format
-- (docs/settings-files.md):
--
--     # comment                   name = 12          name = 0.5
--     name = "quoted text"        name = bare-word   name = a, b, c
--
-- LuaJIT-compatible: no goto, no integer division, no 5.3 string functions.

local M = {}

-- {{{ local function fail()
-- Every refusal goes through here so they all read the same way:
-- "<file>:<line>: <what was wrong>". Line 0 means the file as a whole.
-- Level 0 keeps Lua from prefixing its own position; the file and line of
-- the settings file are the position that matters to the reader.
local function fail(path, line_number, message)
    error(path .. ":" .. line_number .. ": " .. message, 0)
end
-- }}}

-- {{{ local function strip_comment()
-- Removes a # comment, but not a # inside double quotes, since "issue #4"
-- is a reasonable thing to write in a reason. Walks the line once, keeping
-- track of whether it is inside quotes; a backslash inside quotes skips the
-- character after it, so \" does not end the quotes.
local function strip_comment(line)
    local inside_quotes = false
    local index = 1
    while index <= #line do
        local character = string.sub(line, index, index)
        if inside_quotes and character == "\\" then
            -- skip the escaped character: it can be neither a quote nor a #
            index = index + 1
        elseif character == '"' then
            inside_quotes = not inside_quotes
        elseif character == "#" and not inside_quotes then
            return string.sub(line, 1, index - 1)
        end
        index = index + 1
    end
    return line
end
-- }}}

-- A bare word is letters, digits and - _ . / : and nothing else, so that a
-- path or an address can be written without quotes, but a sentence cannot
-- (a sentence with a stray comma would otherwise turn into a list).
local BARE_WORD = "^[%w%-_%./:]+$"

-- {{{ local function parse_quoted()
-- "text with \"quotes\" and \\ backslashes" -> the text inside, unescaped.
-- Only \" and \\ are escapes; any other backslash is refused rather than
-- guessed at, so a Windows-style path cannot be silently mangled.
local function parse_quoted(raw)
    if not string.match(raw, '^".*"$') or #raw < 2 then
        return nil, "text must be one bare word or in double quotes"
    end
    local inner = string.sub(raw, 2, -2)
    local out = {}
    local index = 1
    while index <= #inner do
        local character = string.sub(inner, index, index)
        if character == "\\" then
            local next_character = string.sub(inner, index + 1, index + 1)
            if next_character ~= '"' and next_character ~= "\\" then
                return nil, "only \\\" and \\\\ may follow a backslash"
            end
            out[#out + 1] = next_character
            index = index + 2
        elseif character == '"' then
            return nil, "a quote inside quoted text must be written \\\""
        else
            out[#out + 1] = character
            index = index + 1
        end
    end
    return table.concat(out)
end
-- }}}

-- {{{ local VALUE_TYPES
-- One entry per kind of value: the parse-and-check function for it. Each
-- takes the raw text after "=" and gives the value, or nil and a reason.
-- A dispatch table rather than an if-chain, so adding a type is adding a
-- line, and an unknown type in a declaration is caught by a single lookup.
local VALUE_TYPES = {
    -- a whole number: optional minus sign, digits only
    whole = function(raw)
        if not string.match(raw, "^%-?%d+$") then
            return nil, "expected a whole number, found '" .. raw .. "'"
        end
        return tonumber(raw)
    end,
    -- a decimal: a whole number, or digits with one point
    decimal = function(raw)
        if not (string.match(raw, "^%-?%d+$") or string.match(raw, "^%-?%d*%.%d+$")) then
            return nil, "expected a decimal number, found '" .. raw .. "'"
        end
        return tonumber(raw)
    end,
    -- text: one bare word, or anything in double quotes
    text = function(raw)
        if string.match(raw, BARE_WORD) then return raw end
        return parse_quoted(raw)
    end,
    -- a list of bare words, separated by commas
    words = function(raw)
        local list = {}
        for item in string.gmatch(raw .. ",", "([^,]*),") do
            item = string.match(item, "^%s*(.-)%s*$")
            if not string.match(item, BARE_WORD) then
                return nil, "each item of a list must be a bare word, found '" .. item .. "'"
            end
            list[#list + 1] = item
        end
        return list
    end,
}
-- }}}

-- {{{ local function check_declaration()
-- A mistake in a program's own declaration is the program's bug, not the
-- settings file's, so it is reported against the program and before the
-- file is even opened.
local function check_declaration(declaration)
    for name, wanted in pairs(declaration) do
        if type(wanted) ~= "table" or VALUE_TYPES[wanted.type] == nil then
            error("settings: the declaration of '" .. tostring(name)
                .. "' names no known type (whole, decimal, text, words)", 3)
        end
        if type(wanted.required) ~= "boolean" then
            error("settings: the declaration of '" .. tostring(name)
                .. "' must say required = true or false", 3)
        end
    end
end
-- }}}

-- {{{ function M.read()
-- Reads one settings file against a declaration and returns a table of
-- name -> value. A declared, not-required name that the file leaves out is
-- simply absent from the table: the program asked for "optional", so it
-- also asked to check for absence itself.
--
-- declaration: { <name> = { type = "whole"|"decimal"|"text"|"words",
--                           required = true|false }, ... }
function M.read(path, declaration)
    check_declaration(declaration)
    local file, open_error = io.open(path, "r")
    if file == nil then
        fail(path, 0, "cannot open the settings file (" .. tostring(open_error) .. ")")
    end

    local values = {}
    local seen_on_line = {}
    local line_number = 0
    for line in file:lines() do
        line_number = line_number + 1
        local content = string.match(strip_comment(line), "^%s*(.-)%s*$")
        -- an empty line (or one that was only a comment) says nothing
        if content ~= "" then
            local name, raw = string.match(content, "^([%w%-_]+)%s*=%s*(.-)$")
            if name == nil then
                file:close()
                fail(path, line_number, "expected 'name = value'")
            end
            local wanted = declaration[name]
            if wanted == nil then
                file:close()
                fail(path, line_number, "'" .. name .. "' is not a setting this program reads")
            end
            if seen_on_line[name] then
                file:close()
                fail(path, line_number, "'" .. name .. "' was already given on line "
                    .. seen_on_line[name])
            end
            if raw == "" then
                file:close()
                fail(path, line_number, "'" .. name .. "' has no value")
            end
            local value, reason = VALUE_TYPES[wanted.type](raw)
            if value == nil then
                file:close()
                fail(path, line_number, name .. ": " .. reason)
            end
            values[name] = value
            seen_on_line[name] = line_number
        end
    end
    file:close()

    -- Missing required names are gathered and reported together, sorted, so
    -- fixing a new file is one round trip and not one per missing line.
    local missing = {}
    for name, wanted in pairs(declaration) do
        if wanted.required and values[name] == nil then
            missing[#missing + 1] = name
        end
    end
    if #missing > 0 then
        table.sort(missing)
        fail(path, 0, "missing required setting(s): " .. table.concat(missing, ", "))
    end
    return values
end
-- }}}

-- {{{ function M.read_program()
-- The usual case: the file is input/<program> under the project folder.
function M.read_program(project_dir, program, declaration)
    return M.read(project_dir .. "/input/" .. program, declaration)
end
-- }}}

return M
