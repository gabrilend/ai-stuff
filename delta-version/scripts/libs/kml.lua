#!/usr/bin/env luajit
-- kml.lua - the Keyword Markup Language engine: fills a ticket template's
-- ][keyword[] placeholders with what a shell command says about a project.
--
-- In plain terms: a template is ordinary text with placeholders in it, like
--
--     # Report for ][project_name[]
--     Lua files mentioning main: ][function_usage[main,lua][]
--
-- A configuration file (config/ticket-keywords.conf) says, for each keyword
-- name, which bash command produces its value; parameters in the placeholder
-- replace PARAM1..PARAM5 in that command. This library reads the
-- configuration, finds the placeholders, runs each distinct command once in
-- the project's folder with a time limit, and writes the output in place of
-- the placeholder. Specification: docs/keyword-markup-language-spec.md (KML
-- 1.0, issue 016); this is issue 017.
--
-- What it guarantees, and why:
--   * A parameter may hold only letters, digits, "_", "-", "." and "/" (the
--     specification's character set). It is pasted into a shell command, so
--     anything wider -- a quote, a space, a semicolon -- could run something
--     the template writer did not mean; such a placeholder is an error, never
--     a command.
--   * Something that starts like a placeholder but breaks the rules
--     (][Project_Name[], ][x[], a sixth parameter) is reported as invalid
--     rather than left in the output looking like text, so a typo in a
--     template is seen. "][" not followed directly by a name (as in the
--     "][ name ][" markers other tools use) is plain text.
--   * \][ keeps a placeholder as literal text; \\][ is a literal backslash
--     followed by a placeholder that is filled.
--   * Every failure -- unknown keyword, wrong number of parameters, a command
--     that exits non-zero or runs past its time -- is handled by the error
--     mode: placeholder "[ERROR: name]", remove "", verbose
--     "[ERROR: name - why]", or fail (stop, nothing written).
--   * kml_version, template_name, ticket_id and generation_date are filled by
--     the engine itself and cannot be redefined; error and debug are reserved.
--
-- Library use:
--   local kml = dofile(".../scripts/libs/kml.lua")
--   local config = kml.load_config({ default_path, project_path })
--   local out, report = kml.process(text, {
--       config = config, project_dir = dir, template_name = "x.md",
--       error_mode = nil, timeout = nil, ticket_id = nil })
--   -- out is nil when error_mode is "fail" and something failed
--   -- report = { keywords = n, commands = n, errors = { {name, message} } }
--   kml.scan(text) -> text pieces and placeholders
--   kml.problem(placeholder, config) -> why it cannot be filled, or nil

local M = {}

M.VERSION = "1.0"
M.MAX_PARAMS = 5
M.ERROR_MODES = { placeholder = true, remove = true, verbose = true, fail = true }

-- Filled by the engine; a configuration entry with one of these names is
-- ignored.
local INTERNAL = {
    kml_version = true, template_name = true, ticket_id = true, generation_date = true,
}
-- May not be used at all.
local RESERVED = { error = true, debug = true }

-- {{{ local function shell_quote
local function shell_quote(word)
    return "'" .. tostring(word):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function trim
local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
-- }}}

-- {{{ function M.valid_name
-- A keyword name: lower-case letters, digits and "_", starting with a letter,
-- 2 to 32 characters.
function M.valid_name(name)
    return #name >= 2 and #name <= 32 and name:match("^[a-z][a-z0-9_]*$") ~= nil
end
-- }}}

-- {{{ function M.valid_param
function M.valid_param(param)
    return param ~= "" and param:match("^[%w_%./%-]+$") ~= nil
end
-- }}}

-- {{{ function M.load_config
-- Reads one or more configuration files, each layered over the ones before
-- it, into { keywords = { name = { command, section } }, settings = {} }.
-- Within the files, [custom_keywords] entries win over any other section's.
-- Missing files in the list are skipped; returns nil and a reason when none
-- could be read.
function M.load_config(paths)
    local config = { keywords = {}, settings = {}, sources = {} }
    local custom = {}
    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            config.sources[#config.sources + 1] = path
            local section = ""
            for line in f:lines() do
                local stripped = trim(line)
                if stripped ~= "" and not stripped:match("^[#;]") then
                    local header = stripped:match("^%[([%w_]+)%]$")
                    if header then
                        section = header
                    else
                        local key, value = line:match("^%s*([^=]-)%s*=(.*)$")
                        if key and key ~= "" then
                            value = trim(value)
                            if section == "metadata" then
                                config.settings[key] = value
                            elseif not INTERNAL[key] then
                                local entry = { command = value, section = section }
                                if section == "custom_keywords" then
                                    custom[key] = entry
                                else
                                    config.keywords[key] = entry
                                end
                            end
                        end
                    end
                end
            end
            f:close()
        end
    end
    if #config.sources == 0 then
        return nil, "no configuration file could be read"
    end
    for key, entry in pairs(custom) do config.keywords[key] = entry end
    return config
end
-- }}}

-- {{{ function M.params_needed
-- The highest PARAMn a command uses: how many parameters it expects.
function M.params_needed(command)
    local most = 0
    for n in command:gmatch("PARAM(%d)") do
        most = math.max(most, tonumber(n))
    end
    return most
end
-- }}}

-- {{{ local function read_placeholder
-- Reads a placeholder starting at text position i (at its "]["). Returns a
-- table { name, params, raw, valid, why } and the position after it, or nil
-- when this "][" does not start a placeholder at all.
local function read_placeholder(text, i)
    -- A name-like run straight after "][", then "[".
    local name, after = text:match("^%]%[([%w_%-]+)%[()", i)
    if not name then return nil end
    local params, stop
    if text:sub(after, after) == "]" then
        -- ][name[]
        params, stop = {}, after + 1
    else
        -- ][name[p1,p2][]
        local inner, finish = text:match("^([^%[%]\n]*)%]%[%]()", after)
        if not inner then return nil end
        params = {}
        for p in (inner .. ","):gmatch("([^,]*),") do params[#params + 1] = p end
        stop = finish
    end
    local raw = text:sub(i, stop - 1)
    local item = { name = name, params = params, raw = raw, valid = true }
    if not M.valid_name(name) then
        item.valid, item.why = false, "invalid keyword name"
    elseif #params > M.MAX_PARAMS then
        item.valid, item.why = false, "more than " .. M.MAX_PARAMS .. " parameters"
    else
        for _, p in ipairs(params) do
            if not M.valid_param(p) then
                item.valid, item.why = false, "invalid parameter '" .. p .. "'"
                break
            end
        end
    end
    return item, stop
end
-- }}}

-- {{{ function M.scan
-- Splits a template into pieces: plain text strings and placeholder tables,
-- with escapes already applied to the text. Returns the list of pieces.
function M.scan(text)
    local pieces = {}
    local buffer = {}
    local i, n = 1, #text
    local function flush()
        if #buffer > 0 then
            pieces[#pieces + 1] = table.concat(buffer)
            buffer = {}
        end
    end
    while i <= n do
        local start = text:find("][", i, true)
        if not start then
            buffer[#buffer + 1] = text:sub(i)
            break
        end
        -- Count the backslashes right before "][".
        local slashes = 0
        while start - slashes - 1 >= i and text:sub(start - slashes - 1, start - slashes - 1) == "\\" do
            slashes = slashes + 1
        end
        buffer[#buffer + 1] = text:sub(i, start - slashes - 1)
        local item, stop = read_placeholder(text, start)
        if not item then
            -- Not a placeholder: the backslashes and "][" are plain text.
            buffer[#buffer + 1] = string.rep("\\", slashes) .. "]["
            i = start + 2
        else
            -- Each pair of backslashes is one literal backslash; an odd one
            -- left over escapes the placeholder.
            buffer[#buffer + 1] = string.rep("\\", math.floor(slashes / 2))
            if slashes % 2 == 1 then
                buffer[#buffer + 1] = item.raw
            else
                flush()
                pieces[#pieces + 1] = item
            end
            i = stop
        end
    end
    flush()
    return pieces
end
-- }}}

-- {{{ function M.substitute_params
-- The command with PARAM1..PARAM5 replaced; highest numbers first so PARAM1
-- never eats the front of a PARAM10.
function M.substitute_params(command, params)
    local out = command
    for k = #params, 1, -1 do
        out = out:gsub("PARAM" .. k, (params[k]:gsub("%%", "%%%%")))
    end
    return out
end
-- }}}

-- {{{ function M.run_command
-- Runs a command with bash in a folder, with a time limit. Returns the output
-- (trailing newlines removed), or nil and why it failed.
function M.run_command(command, dir, timeout)
    local errfile = os.tmpname()
    local line = "cd " .. shell_quote(dir) .. " 2>/dev/null && timeout " .. tonumber(timeout)
        .. " bash -c " .. shell_quote("set +e; " .. command)
        .. " 2>" .. shell_quote(errfile) .. " </dev/null; echo \"__kml_status=$?\""
    local pipe = io.popen(line)
    local out = pipe:read("*a")
    pipe:close()
    local f = io.open(errfile, "r")
    local err = f and f:read("*a") or ""
    if f then f:close() end
    os.remove(errfile)
    local body, status = out:match("^(.-)__kml_status=(%d+)\n?$")
    status = tonumber(status)
    if not status then return nil, "could not run the command" end
    if status == 124 then return nil, "timed out after " .. timeout .. "s" end
    if status ~= 0 then
        local first = trim(err):match("^[^\n]*") or ""
        return nil, "exit " .. status .. (first ~= "" and (": " .. first) or "")
    end
    return (body:gsub("\n+$", ""))
end
-- }}}

-- {{{ local function new_ticket_id
local function new_ticket_id()
    math.randomseed(os.time() + math.floor(os.clock() * 1e6))
    return string.format("T-%s-%04x", os.date("%Y%m%d-%H%M%S"), math.random(0, 0xffff))
end
-- }}}

-- {{{ function M.problem
-- Why a placeholder from scan() cannot be filled with this configuration, or
-- nil when it can. Runs nothing, so it also serves to check a template.
function M.problem(item, config)
    if not item.valid then return item.why end
    if RESERVED[item.name] then return "reserved keyword" end
    if INTERNAL[item.name] then
        if #item.params > 0 then return "takes no parameters" end
        return nil
    end
    local entry = config.keywords[item.name]
    if not entry then return "unknown keyword" end
    local needed = M.params_needed(entry.command)
    if #item.params ~= needed then
        return "expects " .. needed .. " parameter" .. (needed == 1 and "" or "s")
            .. ", got " .. #item.params
    end
    return nil
end
-- }}}

-- {{{ function M.process
-- Fills a template. See the header for the options. Returns the filled text
-- and a report; the text is nil when the error mode is "fail" and anything
-- failed (the report says what).
function M.process(text, options)
    local config = options.config
    local settings = config.settings or {}
    local mode = options.error_mode or settings.error_mode or "placeholder"
    if not M.ERROR_MODES[mode] then
        return nil, { keywords = 0, commands = 0,
            errors = { { name = "error_mode", message = "unknown error mode " .. tostring(mode) } } }
    end
    local timeout = tonumber(options.timeout or settings.timeout) or 10
    local dir = options.project_dir or "."

    local internal = {
        kml_version = M.VERSION,
        template_name = options.template_name or "",
        ticket_id = options.ticket_id or new_ticket_id(),
        generation_date = os.date("%Y-%m-%d %H:%M:%S"),
    }

    local report = { keywords = 0, commands = 0, errors = {} }
    local cache = {}
    local out = {}

    -- One placeholder's value, or nil and why.
    local function resolve(item)
        local problem = M.problem(item, config)
        if problem then return nil, problem end
        if internal[item.name] then return internal[item.name] end
        local entry = config.keywords[item.name]
        local command = M.substitute_params(entry.command, item.params)
        local key = command
        if cache[key] == nil then
            report.commands = report.commands + 1
            local value, why = M.run_command(command, dir, timeout)
            cache[key] = value and { value = value } or { why = why }
        end
        return cache[key].value, cache[key].why
    end

    for _, piece in ipairs(M.scan(text)) do
        if type(piece) == "string" then
            out[#out + 1] = piece
        else
            report.keywords = report.keywords + 1
            local value, why = resolve(piece)
            if value then
                out[#out + 1] = value
            else
                report.errors[#report.errors + 1] = { name = piece.name, raw = piece.raw, message = why }
                if mode == "placeholder" then
                    out[#out + 1] = "[ERROR: " .. piece.name .. "]"
                elseif mode == "verbose" then
                    out[#out + 1] = "[ERROR: " .. piece.name .. " - " .. why .. "]"
                end
                -- "remove" writes nothing; "fail" is decided below
            end
        end
    end

    if mode == "fail" and #report.errors > 0 then return nil, report end
    return table.concat(out), report
end
-- }}}

return M
