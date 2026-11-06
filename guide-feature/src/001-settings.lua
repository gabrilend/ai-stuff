-- 001-settings.lua - every guide-feature program's settings, read from input/.
--
-- In plain terms: a program says which settings it has (their names, what kind
-- of value each holds, and which must be there), and this reads them from its
-- file in input/ - input/blitter for the blitter, input/turn for the turn - or
-- refuses with the file and line that is wrong. Nothing has a default hidden in
-- code, so every value a program runs with can be seen in its input file.
--
-- The file is `name = value` lines, the same as rmail's contacts file and this
-- project's endpoints file, so there is one format to learn:
--
--   # the blitter's settings
--   canvas-size   = 80x24             # columns x rows, bare
--   mark-lifetime = 12                # a whole number, bare
--   merge-mode    = "newest"          # text is always in quotes
--   voices        = "fg-sora-1 fg-sora-2 fg-sora-3"
--
--   local settings = dofile(DIR .. "/src/001-settings.lua")
--   local s = settings.read("blitter", {
--       ["canvas-size"]   = { type = "WxH", required = true },
--       ["mark-lifetime"] = { type = "whole", required = true },
--       ["merge-mode"]    = { type = "choice", of = { "newest", "distill" }, required = true },
--       ["voices"]        = { type = "names" },
--   }, { root = DIR })
--   s["canvas-size"].width, s["merge-mode"], s.voices[2]
--
--   settings.read_endpoints({ root = DIR })   -- the project-root endpoints file
--
-- A program that must notice a change while running (the blitter's merge mode)
-- simply calls read again. Every refusal is a Lua error whose message starts
-- with the file, and the line where there is one: "input/blitter:4: ...".
-- LuaJIT-compatible.

-- {{{ local DIR
-- The project root, hard-coded the house way; every function takes opts.root
-- to work on another copy (the tests do).
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local M = {}

-- {{{ NAME_PATTERN
-- What a setting's name, a list entry and a program's name may be made of.
-- Dots let one file hold grouped names, as endpoints does (kuvalu-qwen.url).
local NAME_PATTERN = "^[%w%._%-]+$"
M.NAME_PATTERN = NAME_PATTERN
-- }}}

-- {{{ local function fail()
-- Every refusal goes through here, so they all read the same way: where, then
-- what. Level 0 keeps Lua from prefixing this file's own name and line.
local function fail(where, text)
    error(where .. ": " .. text, 0)
end
-- }}}

-- {{{ local function shown()
-- A value as the person wrote it, for error messages.
local function shown(value, kind)
    if kind == "quoted" then
        return '"' .. value .. '"'
    end
    return value
end
-- }}}

-- {{{ M.TYPES
-- The kinds of value a setting can hold: a dispatch table from the type's name
-- to a function that takes the written value and how it was written ("quoted"
-- or "bare") and returns the parsed value, or nil and why not.
--
-- Text is always quoted and numbers and sizes never are. Being strict about
-- that means a mistyped number cannot quietly become text, or the other way.
M.TYPES = {}

-- {{{ whole
-- A whole number, bare: 12, -3.
M.TYPES.whole = function(value, kind)
    if kind ~= "bare" or not string.match(value, "^%-?%d+$") then
        return nil, "must be a whole number, written bare (like 12)"
    end
    return tonumber(value)
end
-- }}}

-- {{{ decimal
-- A number that may have a fraction, bare: 0.5, 2, -1.25, .5.
M.TYPES.decimal = function(value, kind)
    if kind ~= "bare"
        or not (string.match(value, "^%-?%d+%.?%d*$")
                or string.match(value, "^%-?%.%d+$")) then
        return nil, "must be a number, written bare (like 0.5)"
    end
    return tonumber(value)
end
-- }}}

-- {{{ text
-- Any text, in double quotes. Inside, \" is a quote and \\ a backslash.
M.TYPES.text = function(value, kind)
    if kind ~= "quoted" then
        return nil, 'must be text in double quotes (like "' .. value .. '")'
    end
    return value
end
-- }}}

-- {{{ WxH
-- A size in characters, bare, columns first: 80x24. Both at least 1.
-- Written the way the canvas's own size header is (docs/canvas-format.md).
M.TYPES.WxH = function(value, kind)
    local width, height
    if kind == "bare" then
        width, height = string.match(value, "^(%d+)x(%d+)$")
    end
    width, height = tonumber(width), tonumber(height)
    if not width or width < 1 or height < 1 then
        return nil, "must be a size written bare as columns x rows (like 80x24)"
    end
    return { width = width, height = height }
end
-- }}}

-- {{{ names
-- A list of names in one quoted text, separated by spaces or commas:
-- "fg-sora-1 fg-sora-2". "" is the empty list. A name may not appear twice.
M.TYPES.names = function(value, kind)
    if kind ~= "quoted" then
        return nil, 'must be names in double quotes, separated by spaces (like "a b c")'
    end
    local list, seen = {}, {}
    for name in string.gmatch(value, "[^%s,]+") do
        if not string.match(name, NAME_PATTERN) then
            return nil, "has '" .. name .. "', which is not a name "
                .. "(letters, digits, '.', '_' and '-' only)"
        end
        if seen[name] then
            return nil, "names '" .. name .. "' twice"
        end
        seen[name] = true
        list[#list + 1] = name
    end
    return list
end
-- }}}

-- {{{ choice
-- One of a fixed set of words, quoted: "newest". The declaration lists them
-- in `of`. Merge modes, collision rules and endpoint kinds are all this.
M.TYPES.choice = function(value, kind, declared)
    for _, allowed in ipairs(declared.of) do
        if kind == "quoted" and value == allowed then
            return value
        end
    end
    return nil, 'must be one of "' .. table.concat(declared.of, '", "')
        .. '", in double quotes'
end
-- }}}
-- }}}

-- {{{ local function check_declarations()
-- A program's own table of settings is checked before its file is, so a typo
-- in the program reads as the program's fault and not the person's.
local function check_declarations(declared, program)
    if type(declared) ~= "table" then
        error("settings: " .. program .. " declared no settings table", 3)
    end
    for name, one in pairs(declared) do
        if type(one) ~= "table" or not M.TYPES[one.type] then
            error("settings: " .. program .. " declares '" .. tostring(name)
                .. "' with an unknown type '" .. tostring(one and one.type) .. "'", 3)
        end
        if one.type == "choice" and (type(one.of) ~= "table" or #one.of == 0) then
            error("settings: " .. program .. " declares the choice '" .. name
                .. "' without its words (of = { ... })", 3)
        end
        if string.find(name, "*", 1, true) and one.required then
            error("settings: " .. program .. " declares the pattern '" .. name
                .. "' as required; only a fixed name can be", 3)
        end
    end
end
-- }}}

-- {{{ local function read_value()
-- Reads the value part of a line (everything after the '='): a quoted text or
-- one bare word, then nothing but an optional # comment. Returns the value and
-- how it was written.
local function read_value(rest, where)
    rest = string.match(rest, "^%s*(.-)$")
    if rest == "" or string.sub(rest, 1, 1) == "#" then
        fail(where, "there is no value after '='")
    end

    local value, kind, after
    if string.sub(rest, 1, 1) == '"' then
        local parts, at = {}, 2
        while true do
            local char = string.sub(rest, at, at)
            if char == "" then
                fail(where, "the quoted text has no closing quote")
            elseif char == '"' then
                break
            elseif char == "\\" then
                local next_char = string.sub(rest, at + 1, at + 1)
                if next_char ~= '"' and next_char ~= "\\" then
                    fail(where, "\\" .. next_char .. ' is not an escape here; '
                        .. 'only \\" and \\\\ are')
                end
                parts[#parts + 1] = next_char
                at = at + 2
            else
                parts[#parts + 1] = char
                at = at + 1
            end
        end
        value, kind, after = table.concat(parts), "quoted", string.sub(rest, at + 1)
    else
        value = string.match(rest, "^[^%s#]+")
        kind, after = "bare", string.sub(rest, #value + 1)
    end

    after = string.match(after, "^%s*(.-)$")
    if after ~= "" and string.sub(after, 1, 1) ~= "#" then
        fail(where, "there is more after the value: " .. after
            .. " (text with spaces goes in double quotes)")
    end
    return value, kind
end
-- }}}

-- {{{ function M.parse()
-- Text in, a list of the lines that set something out: { name, value, kind,
-- line }, in file order. Knows nothing of any program's settings, so it is
-- also what reads the endpoints file. `source` names the file in errors.
function M.parse(text, source)
    local entries, line_number = {}, 0
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        line_number = line_number + 1
        line = string.gsub(line, "\r$", "")
        local where = source .. ":" .. line_number
        local trimmed = string.match(line, "^%s*(.-)%s*$")
        if trimmed ~= "" and string.sub(trimmed, 1, 1) ~= "#" then
            local name, rest = string.match(trimmed, "^([^%s=]+)%s*=(.*)$")
            if not name then
                fail(where, "expected `name = value`, found: " .. trimmed)
            end
            if not string.match(name, NAME_PATTERN) then
                fail(where, "'" .. name .. "' is not a setting's name "
                    .. "(letters, digits, '.', '_' and '-' only)")
            end
            local value, kind = read_value(rest, where)
            entries[#entries + 1] =
                { name = name, value = value, kind = kind, line = line_number }
        end
    end
    return entries
end
-- }}}

-- {{{ local function pattern_of()
-- A declared name with a * in it stands for many names: "*.url" is any one
-- name-part followed by .url. Returns the Lua pattern, or nil for a fixed name.
local function pattern_of(name)
    if not string.find(name, "*", 1, true) then
        return nil
    end
    local escaped = string.gsub(name, "[%.%-]", "%%%0")
    return "^" .. string.gsub(escaped, "%*", "[%%w_%%-]+") .. "$"
end
-- }}}

-- {{{ local function claim_of()
-- How strongly a declared pattern claims a name: first by how much of its start
-- is fixed, then by how much of it is fixed in all. So "use.url" is the role
-- "url" under "use.*", not the address of an endpoint called "use" under
-- "*.url"; an endpoint therefore cannot be called "use".
local function claim_of(name)
    local star = string.find(name, "*", 1, true)
    return star - 1, #(string.gsub(name, "%*", ""))
end
-- }}}

-- {{{ local function find_declaration()
local function find_declaration(declared, patterns, name)
    if declared[name] then
        return declared[name]
    end
    for _, pattern in ipairs(patterns) do
        if string.match(name, pattern.lua) then
            return declared[pattern.name]
        end
    end
    return nil
end
-- }}}

-- {{{ function M.check()
-- The parsed lines against a program's declarations. Returns the settings
-- (name to parsed value) and, beside them, the line each was set on, so a
-- caller that checks further (the endpoints' cross-references) can name it.
function M.check(entries, declared, source, program)
    check_declarations(declared, program or source)

    local patterns = {}
    for name in pairs(declared) do
        local lua = pattern_of(name)
        if lua then
            patterns[#patterns + 1] = { name = name, lua = lua }
        end
    end
    table.sort(patterns, function(a, b)
        local a_start, a_fixed = claim_of(a.name)
        local b_start, b_fixed = claim_of(b.name)
        if a_start ~= b_start then return a_start > b_start end
        if a_fixed ~= b_fixed then return a_fixed > b_fixed end
        return a.name < b.name
    end)

    local values, lines = {}, {}
    for _, entry in ipairs(entries) do
        local where = source .. ":" .. entry.line
        local one = find_declaration(declared, patterns, entry.name)
        if not one then
            local known = {}
            for name in pairs(declared) do known[#known + 1] = name end
            table.sort(known)
            fail(where, "'" .. entry.name .. "' is not one of this file's settings ("
                .. table.concat(known, ", ") .. ")")
        end
        if lines[entry.name] then
            fail(where, "'" .. entry.name .. "' is set again (first on line "
                .. lines[entry.name] .. ")")
        end
        local value, why = M.TYPES[one.type](entry.value, entry.kind, one)
        if value == nil then
            fail(where, "'" .. entry.name .. "' " .. why .. "; found "
                .. shown(entry.value, entry.kind))
        end
        values[entry.name], lines[entry.name] = value, entry.line
    end

    local missing = {}
    for name, one in pairs(declared) do
        if one.required and values[name] == nil then
            missing[#missing + 1] = name
        end
    end
    if #missing > 0 then
        table.sort(missing)
        fail(source, "'" .. table.concat(missing, "', '") .. "' "
            .. (#missing == 1 and "is" or "are") .. " required and not set")
    end
    return values, lines
end
-- }}}

-- {{{ local tiers
-- The RAM tiers (tmp/ and tmp/shared-memory/) are made sure of once per
-- project root per process, through this project's own copy of the house
-- library (libs/ensure-ram-tiers.lua, docs/vendored-code.md). Once, because
-- the blitter reads its settings on every arrival and the check runs a shell.
local tiers_ready = {}

function M.ensure_tiers(root)
    if tiers_ready[root] then
        return
    end
    local tiers = dofile(root .. "/libs/ensure-ram-tiers.lua")
    tiers.ensure(root, root)
    tiers_ready[root] = true
end
-- }}}

-- {{{ local function read_file()
local function read_file(path, source, why_missing)
    local handle = io.open(path, "r")
    if not handle then
        fail(source, why_missing)
    end
    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

-- {{{ function M.read()
-- A program's settings from input/<program>. opts.root is the project root.
function M.read(program, declared, opts)
    opts = opts or {}
    local root = opts.root or DIR
    if type(program) ~= "string" or not string.match(program, NAME_PATTERN) then
        error("settings: '" .. tostring(program) .. "' is not a program's name", 2)
    end
    M.ensure_tiers(root)
    local source = "input/" .. program
    local text = read_file(root .. "/" .. source, source,
        "there is no settings file; every program reads its settings from "
        .. "input/<its name>, and nothing has a default in code")
    return M.check(M.parse(text, source), declared, source, program)
end
-- }}}

-- {{{ M.ENDPOINT_FIELDS
-- The endpoints file's lines (docs/endpoints.md). NAME is any endpoint's name.
M.ENDPOINT_FIELDS = {
    ["*.url"]      = { type = "text" },
    ["*.kind"]     = { type = "choice", of = { "chat", "embedding" } },
    ["*.timeout"]  = { type = "whole" },
    ["*.model"]    = { type = "text" },
    ["*.port"]     = { type = "whole" },
    ["*.key-file"] = { type = "text" },
    ["use.*"]      = { type = "text" },
}
-- }}}

-- {{{ function M.read_endpoints()
-- The project-root endpoints file, grouped:
--   { endpoints = { [name] = { url, kind, timeout, ... } },
--     use = { [role] = endpoint name } }
-- Each endpoint must have a url and a kind. Each use. line must name an
-- endpoint that is there, of the kind its role needs: the embedder an
-- embedding endpoint, every other role (the voices, the distiller) a chat one.
-- Whether an endpoint answers is not checked here; that is the client's (401b).
function M.read_endpoints(opts)
    opts = opts or {}
    local root = opts.root or DIR
    M.ensure_tiers(root)
    local source = "endpoints"
    local text = read_file(root .. "/" .. source, source,
        "there is no endpoints file in the project root (docs/endpoints.md)")
    local values, lines = M.check(M.parse(text, source), M.ENDPOINT_FIELDS, source)

    local result, first_line = { endpoints = {}, use = {} }, {}
    for name, value in pairs(values) do
        local role = string.match(name, "^use%.(.+)$")
        if role then
            result.use[role] = value
        else
            local endpoint, field = string.match(name, "^(.+)%.([^%.]+)$")
            result.endpoints[endpoint] = result.endpoints[endpoint] or {}
            result.endpoints[endpoint][field] = value
            if not first_line[endpoint] or lines[name] < first_line[endpoint] then
                first_line[endpoint] = lines[name]
            end
        end
    end

    local names = {}
    for name in pairs(result.endpoints) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local one = result.endpoints[name]
        for _, field in ipairs({ "url", "kind" }) do
            if one[field] == nil then
                fail(source .. ":" .. first_line[name], "the endpoint '" .. name
                    .. "' has no " .. name .. "." .. field)
            end
        end
    end

    local roles = {}
    for role in pairs(result.use) do roles[#roles + 1] = role end
    table.sort(roles)
    for _, role in ipairs(roles) do
        local where = source .. ":" .. lines["use." .. role]
        local target = result.endpoints[result.use[role]]
        if not target then
            fail(where, "use." .. role .. " names '" .. result.use[role]
                .. "', which is not an endpoint in this file")
        end
        local needs = (role == "embedder") and "embedding" or "chat"
        if target.kind ~= needs then
            fail(where, "use." .. role .. " needs a " .. needs .. " endpoint, and '"
                .. result.use[role] .. "' is " .. target.kind)
        end
    end
    return result
end
-- }}}

return M
