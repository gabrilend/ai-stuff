#!/usr/bin/env lua

-- Page-template substitution: fills {UPPERCASE_NAME} markers in a plain-text
-- template with live values, so the *words* of a generated page can live in an
-- editable input/ file while the *numbers* are still computed in code. This is
-- the same idea report-generator.lua already used with {PLACEHOLDER} markers,
-- generalized into one small reusable piece and made strict: an unresolved
-- marker is an error (a typo on a page is worse than a loud failure at build),
-- not a thing to silently leave on the page.
--
-- Why a separate module: the explore pages (Issue 11-005) read their prose from
-- input/pages/*.txt. Keeping the substitutor here, with no dependency on the
-- rest of the generator, means it can be unit-tested on its own and reused by
-- any future page that wants editable copy.

local M = {}

-- A marker name is one or more UPPERCASE letters, digits, or underscores wrapped
-- in braces: {TOTAL_POEMS}. Restricting to uppercase is deliberate -- prose and
-- HTML never contain "{WORD}" in that exact shape, so ordinary text in the
-- template is never mistaken for a marker. (Lowercase {x} is left untouched.)
local MARKER = "{([A-Z0-9_]+)}"

-- {{{ M.OMIT
-- Sentinel value. Assign it to a marker (e.g. values.DATE_SPAN = M.OMIT) to make
-- the ENTIRE template line that mentions that marker disappear -- no blank gap
-- left behind. This reproduces the old "only show this stat line when the fact
-- exists" behavior that bare string substitution cannot express. tostring() on
-- it yields "" so an accidental render is harmless rather than printing a table.
M.OMIT = setmetatable({}, { __tostring = function() return "" end })
-- }}}

-- {{{ local function line_mentions_omit()
-- True when any marker on this single line resolves to the OMIT sentinel. A line
-- "about" an omitted fact is dropped whole, which is what you want: the label and
-- the (missing) value go together.
local function line_mentions_omit(line, values)
    for key in line:gmatch(MARKER) do
        if values[key] == M.OMIT then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ function M.substitute()
-- Fill `template` from `values` (a table of NAME -> string/number, or M.OMIT).
-- Returns the filled string, or (nil, error_message) if the template names a
-- marker that `values` has no entry for. Pass 1 removes OMIT lines; pass 2
-- replaces the rest. % in a value is NOT special here because gsub's replacement
-- is a function (function returns are used verbatim), so values can safely carry
-- percent signs, which the old hand-escaped version had to guard against.
function M.substitute(template, values)
    -- Two real errors worth catching at the door rather than producing a
    -- mangled page: a non-string template, or no value table at all.
    if type(template) ~= "string" then
        return nil, "page-template: template must be a string, got " .. type(template)
    end
    if type(values) ~= "table" then
        return nil, "page-template: values must be a table, got " .. type(values)
    end

    -- Pass 1: drop every line that mentions an OMIT-valued marker. Appending a
    -- trailing newline before splitting, then re-joining with newlines, leaves
    -- the original line structure intact (including a final no-newline line).
    local kept = {}
    for line in (template .. "\n"):gmatch("(.-)\n") do
        if not line_mentions_omit(line, values) then
            kept[#kept + 1] = line
        end
    end
    local body = table.concat(kept, "\n")

    -- Pass 2: replace each surviving marker. Any marker with no value is recorded
    -- and, once the whole pass is done, reported as an error. We collect them all
    -- so a person fixing a template sees every typo at once, not one per rebuild.
    local missing, seen = {}, {}
    local filled = body:gsub(MARKER, function(key)
        local value = values[key]
        if value == nil then
            if not seen[key] then
                seen[key] = true
                missing[#missing + 1] = key
            end
            return "{" .. key .. "}"  -- leave it; we are about to error anyway
        end
        if value == M.OMIT then
            return ""  -- a stray OMIT marker not alone on its line; render empty
        end
        return tostring(value)
    end)

    if #missing > 0 then
        table.sort(missing)
        return nil, "page-template: no value for placeholder(s): {"
            .. table.concat(missing, "}, {") .. "}"
    end

    return filled
end
-- }}}

-- {{{ function M.render_file()
-- Read a template from `path` and substitute. Uses io.open directly so the
-- module carries no dependency on the project's utils. Returns the filled
-- string, or (nil, error_message) on a missing file or any unresolved marker.
function M.render_file(path, values)
    local file = io.open(path, "r")
    if not file then
        return nil, "page-template: could not open template file: " .. tostring(path)
    end
    local content = file:read("*a")
    file:close()
    return M.substitute(content, values)
end
-- }}}

return M
