#!/usr/bin/env luajit
-- 053-endpoint-tools.lua - switch a role's endpoint, and list the endpoints.
--
-- In plain terms: the project-root `endpoints` file says which llama.cpp
-- server each part of guide-feature uses (docs/endpoints.md). It is read
-- again at the start of every turn, so switching a role is one edited line.
-- This makes that edit safely, and shows what is there (issue 402):
--
--   use(root, role, name)  checks the endpoint first: it is in the file, it is
--                          the kind the role needs, it has a timeout, its key
--                          file (if any) can be read, it answers now and takes
--                          the key. Only then is the one use.ROLE line
--                          rewritten (its comment kept), into endpoints.part,
--                          which is read back and checked as a whole before it
--                          is renamed over endpoints. Nothing is written when
--                          any check fails. Returns the old name (or nil) and
--                          the new one.
--   list(root)             every endpoint: its name, kind, address, whether it
--                          answers now, and which roles use it.
--
-- Run on kuvalu, where the endpoints file lives. Every voice is told its
-- endpoint in the canvas kuvalu sends (docs/canvas-format.md), so a switch
-- reaches a voice with the next version kuvalu sends it.
--
-- usage (scripts/use-endpoint, scripts/list-endpoints):
--   luajit 053-endpoint-tools.lua --dir ROOT use ROLE NAME
--   luajit 053-endpoint-tools.lua --dir ROOT list
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local settings = dofile(DIR .. "/src/001-settings.lua")
local caller = dofile(DIR .. "/src/046-model-caller.lua")

local M = {}

-- {{{ local function slurp()
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

-- {{{ local function needs()
-- The kind of endpoint a role needs: the embedder an embedding one, every
-- other role (each voice, the distiller) a chat one. The same rule 001's
-- read_endpoints holds every use. line to.
local function needs(role)
    return role == "embedder" and "embedding" or "chat"
end
-- }}}

-- {{{ local function record()
-- An endpoint from the file as the model caller takes it: a copy, with its
-- name, so loading a key never changes the file's table.
local function record(file, name, role)
    local endpoint = { name = name, role = role }
    for field, value in pairs(file.endpoints[name]) do endpoint[field] = value end
    return endpoint
end
-- }}}

-- {{{ function M.check()
-- Whether `name` can serve `role` now. Returns the endpoint record (its key
-- loaded), or nil and why not, in words naming the endpoint.
function M.check(root, file, role, name)
    local one = file.endpoints[name]
    if not one then
        local names = {}
        for known in pairs(file.endpoints) do names[#names + 1] = known end
        table.sort(names)
        return nil, "there is no endpoint '" .. name .. "' in endpoints; the endpoints are: "
            .. table.concat(names, ", ")
    end
    if one.kind ~= needs(role) then
        return nil, "'" .. name .. "' is a" .. (one.kind == "embedding" and "n " or " ")
            .. one.kind .. " endpoint, and " .. role .. " needs a"
            .. (needs(role) == "embedding" and "n " or " ") .. needs(role) .. " one"
    end
    if not one.timeout then
        return nil, "'" .. name .. "' has no " .. name .. ".timeout; every endpoint a role uses "
            .. "needs one, in seconds"
    end
    local endpoint = record(file, name, role)
    local kok, problem = pcall(caller.load_key, endpoint, root)
    if not kok then return nil, problem end
    if not caller.reachable(endpoint) then
        return nil, "endpoint " .. caller.describe(endpoint) .. " does not answer now"
    end
    -- /v1/models answers without a key, as llama-server's does; a token
    -- count does not, so it shows the key is taken. Every turn counts tokens.
    local tok, taken = pcall(caller.count_tokens, endpoint, "ready")
    if not tok then return nil, taken end
    return endpoint
end
-- }}}

-- {{{ local function escape()
local function escape(text)
    return (string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end
-- }}}

-- {{{ function M.rewrite()
-- The endpoints text with use.ROLE naming `name`: the one line's quoted value
-- replaced, its spacing and comment kept, or a line added at the end when
-- the role has none. Pure, so the tests can call it.
function M.rewrite(text, role, name)
    local found = false
    local lines = {}
    for line in string.gmatch(text, "([^\n]*)\n?") do lines[#lines + 1] = line end
    if lines[#lines] == "" then lines[#lines] = nil end
    local pattern = "^(%s*use%." .. escape(role) .. "%s*=%s*)\"[^\"]*\"(.*)$"
    for index, line in ipairs(lines) do
        local head, tail = string.match(line, pattern)
        if head then
            lines[index] = head .. '"' .. name .. '"' .. tail
            found = true
        end
    end
    if not found then lines[#lines + 1] = "use." .. role .. ' = "' .. name .. '"' end
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ function M.use()
-- Points `role` at the endpoint `name`, after checking it (M.check). The new
-- file goes to endpoints.part, is read back and checked whole by 001's
-- read_endpoints, then is renamed over endpoints, so a turn starting now reads
-- either the old file or the new one, never half of one. Returns old, new.
function M.use(root, role, name)
    if not string.match(role, "^[%w_%-]+$") then
        error("use-endpoint: '" .. role .. "' is not a role name (a voice's name, distiller "
            .. "or embedder)", 0)
    end
    local file = settings.read_endpoints({ root = root })
    local old = file.use[role]
    local endpoint, problem = M.check(root, file, role, name)
    if not endpoint then
        error("use-endpoint: use." .. role .. " stays " .. tostring(old or "unset") .. ": "
            .. problem, 0)
    end
    if old == name then return old, name end

    local path = root .. "/endpoints"
    local text = assert(slurp(path), "endpoints: cannot be read")
    local handle = assert(io.open(path .. ".part", "wb"))
    handle:write(M.rewrite(text, role, name))
    handle:close()
    local rok, again = pcall(settings.read_endpoints, { root = root, file = "endpoints.part" })
    if not rok or again.use[role] ~= name then
        os.remove(path .. ".part")
        error("use-endpoint: use." .. role .. " stays " .. tostring(old or "unset")
            .. ": the rewritten file did not read back as it should: "
            .. tostring(rok and ("use." .. role .. " reads " .. tostring(again.use[role])) or again), 0)
    end
    local moved, why = os.rename(path .. ".part", path)
    if not moved then
        os.remove(path .. ".part")
        error("use-endpoint: use." .. role .. " stays " .. tostring(old or "unset") .. ": " .. why, 0)
    end
    return old, name
end
-- }}}

-- {{{ function M.list()
-- Every endpoint, sorted by name: { name, kind, url, answers, problem,
-- roles }. `answers` is whether it answers now; `problem` says why not, or
-- names a key file that cannot be used.
function M.list(root)
    local file = settings.read_endpoints({ root = root })
    local roles = {}
    for role, name in pairs(file.use) do
        roles[name] = roles[name] or {}
        table.insert(roles[name], role)
    end
    local rows = {}
    for name, one in pairs(file.endpoints) do
        local endpoint = record(file, name, nil)
        local row = { name = name, kind = one.kind, url = one.url, roles = roles[name] or {} }
        table.sort(row.roles)
        local kok, problem = pcall(caller.load_key, endpoint, root)
        if not one.timeout then
            row.answers, row.problem = false, "no " .. name .. ".timeout"
        elseif not kok then
            row.answers, row.problem = false, problem
        else
            row.answers = caller.reachable(endpoint)
            if not row.answers then row.problem = "does not answer now" end
        end
        rows[#rows + 1] = row
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    return rows
end
-- }}}

-- {{{ function M.format()
-- The list as lines for a person: name, kind, whether it answers, address,
-- then its roles; and under it, any problem.
function M.format(rows)
    local width = 4
    for _, row in ipairs(rows) do width = math.max(width, #row.name) end
    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = string.format("%-" .. width .. "s  %-9s  %-11s  %s  used by: %s",
            row.name, row.kind, row.answers and "answers" or "no answer", row.url,
            #row.roles > 0 and table.concat(row.roles, ", ") or "nothing")
        if row.problem then out[#out + 1] = string.rep(" ", width + 2) .. row.problem end
    end
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ command line
if arg and arg[0] and string.match(arg[0], "053%-endpoint%-tools%.lua$") then
    local root, words = DIR, {}
    local index = 1
    while arg[index] do
        if arg[index] == "--dir" then
            root = arg[index + 1]
            index = index + 2
        else
            words[#words + 1] = arg[index]
            index = index + 1
        end
    end
    local usage = "usage: use-endpoint ROLE NAME | list-endpoints\n"
    local ok, problem = pcall(function()
        if words[1] == "use" and #words == 3 then
            local old, new = M.use(root, words[2], words[3])
            if old == new then
                io.write("use.", words[2], ": ", new, " (already)\n")
            else
                io.write("use.", words[2], ": ", tostring(old or "unset"), " -> ", new, "\n")
            end
        elseif words[1] == "list" and #words == 1 then
            io.write(M.format(M.list(root)))
        else
            io.stderr:write(usage)
            os.exit(2)
        end
    end)
    if not ok then
        io.stderr:write(tostring(problem), "\n")
        os.exit(1)
    end
end
-- }}}

return M
